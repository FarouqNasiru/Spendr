import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/providers/currency_provider.dart';
import 'pin_lock_page.dart';
import 'add_category.dart';
import '../../core/services/notification_service.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'auth_screen.dart';
import '../../core/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/services/smart_reminder_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isBiometricsEnabled = false;
  String reminderFrequency = 'Daily';
  TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _userName = '';
  bool isSmartRemindersEnabled = false;
  bool hasNotificationListenerPermission = false;
  bool hasUsageStatsPermission = false;
  List<MonitoredBank> _monitoredBanks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await SmartReminderService().checkPermissions();
    final banks = await SmartReminderService().getMonitoredBanks();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guest';
      isBiometricsEnabled = prefs.getBool('is_biometric_enabled') ?? false;
      reminderFrequency = prefs.getString('reminder_frequency') ?? 'Daily';
      final hour = prefs.getInt('reminder_hour') ?? 9;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      reminderTime = TimeOfDay(hour: hour, minute: minute);
      isSmartRemindersEnabled = status.isEnabled;
      hasNotificationListenerPermission = status.hasNotificationListenerPermission;
      hasUsageStatsPermission = status.hasUsageStatsPermission;
      _monitoredBanks = banks;
    });
  }

  // LOGIC TO HANDLE TOGGLE CHANGE
  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      // User wants to ENABLE.
      // 1. Check if PIN already exists? (Optional, but let's assume setup is needed)
      // 2. Open PIN Setup Page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PinLockPage(mode: PinPageMode.setup),
        ),
      );

      // If they completed setup successfully
      if (result == true) {
        setState(() => isBiometricsEnabled = true);
      }
    } else {
      // User wants to DISABLE.
      // Simply remove the flag. (Optionally clear the PIN from secure storage if desired)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_biometric_enabled', false);
      setState(() => isBiometricsEnabled = false);
    }
  }

  // LOGIC TO HANDLE REMINDER CHANGE
  Future<void> _handleReminderChange(String? newValue) async {
    if (newValue == null) return;

    // 1. If user selects something other than 'None', ask for permission first
    if (newValue != 'None') {
      bool granted = await NotificationService().requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission denied.')),
          );
        }
        setState(() => reminderFrequency = 'None');
        return;
      }
    }

    // 2. Apply UI State aggressively to feel instant
    setState(() => reminderFrequency = newValue);

    // 3. Fire and forget saving to preferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('reminder_frequency', newValue);
    });

    // 4. Schedule the actual notification in the background
    NotificationService().scheduleReminder(
      frequency: newValue,
      time: reminderTime,
    ).then((_) {
      // 5. Check for Exact Alarm permission and prompt if missing on Android 14+
      if (newValue != 'None' && mounted) {
        _checkAndPromptExactAlarms();
      }
    });
  }

  Future<void> _checkAndPromptExactAlarms() async {
    bool hasExact = await NotificationService().hasExactAlarmPermission();
    if (!hasExact && mounted) {
      final bool? openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exact Reminders'),
          content: const Text(
            'To receive reminders exactly at the set time, please allow "Alarms & Reminders" in settings. Otherwise, reminders may be slightly delayed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await NotificationService().openExactAlarmSettings();
      }
    }
  }

  Future<void> _handleTimeChange() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
    );
    if (picked != null && picked != reminderTime) {
      setState(() => reminderTime = picked);

      // Save to prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_hour', picked.hour);
      await prefs.setInt('reminder_minute', picked.minute);

      // Reschedule if frequency is not None
      if (reminderFrequency != 'None') {
        await NotificationService().scheduleReminder(
          frequency: reminderFrequency,
          time: picked,
        );
        // Prompt for exact alarms if missing
        if (mounted) {
          await _checkAndPromptExactAlarms();
        }
      }
    }
  }

  Future<void> _testNotification() async {
    bool granted = await NotificationService().requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission denied. Please enable in settings.',
            ),
          ),
        );
      }
      return;
    }

    await NotificationService().showInstantNotification(
      title: 'Spendr Test',
      body: 'Remember to log your transactions!',
    );
  }

  Future<void> _refreshSmartReminderStatus() async {
    final status = await SmartReminderService().checkPermissions();
    final banks = await SmartReminderService().getMonitoredBanks();
    if (mounted) {
      setState(() {
        isSmartRemindersEnabled = status.isEnabled;
        hasNotificationListenerPermission = status.hasNotificationListenerPermission;
        hasUsageStatsPermission = status.hasUsageStatsPermission;
        _monitoredBanks = banks;
      });
    }
  }

  Future<void> _handleSmartReminderMasterToggle(bool value) async {
    await SmartReminderService().setSmartRemindersEnabled(value);
    setState(() => isSmartRemindersEnabled = value);
    if (value && !hasUsageStatsPermission) {
      if (mounted) {
        _showSmartReminderModal();
      }
    }
  }

  Future<void> _requestNotificationAccess() async {
    final proceed = await _showPermissionDisclosure(
      title: "Bank Notification Access",
      icon: Icons.notifications_active_outlined,
      description:
          "Spendr uses Notification Access to detect debit and credit alerts from your banking apps so you can instantly log transactions.\n\n"
          "• All notification parsing happens 100% locally on your phone.\n"
          "• Spendr never reads personal messages, SMS, or private chats.\n"
          "• No financial data is ever collected or sent to external servers.",
    );

    if (proceed == true) {
      await SmartReminderService().requestNotificationListenerPermission();
      Future.delayed(const Duration(seconds: 1), _refreshSmartReminderStatus);
    }
  }

  Future<void> _requestUsageAccess() async {
    final proceed = await _showPermissionDisclosure(
      title: "Bank App Usage Access",
      icon: Icons.hourglass_top_outlined,
      description:
          "Spendr uses App Usage Access to detect when you open banking apps, serving as a backup reminder to record your transfers and payments.\n\n"
          "• App launch checks run 100% locally on your device.\n"
          "• Spendr only checks for registered banking apps.\n"
          "• No sensitive usage history or personal data is collected or shared.",
    );

    if (proceed == true) {
      await SmartReminderService().requestUsageStatsPermission();
      Future.delayed(const Duration(seconds: 1), _refreshSmartReminderStatus);
    }
  }

  Future<bool?> _showPermissionDisclosure({
    required String title,
    required IconData icon,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDark ? colorScheme.primary : colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Not Now",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "Continue to Settings",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSmartReminderModal() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Smart Bank Reminders",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : colorScheme.secondary,
                            ),
                          ),
                          Text(
                            "Auto-detect bank app launch & prompts to log",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(10) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "100% On-Device Privacy: App usage is checked entirely on your phone. Spendr only checks for registered banking apps. No financial data leaves your device.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "DETECTION METHOD",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionCard(
                          title: "Bank App Open Detector",
                          subtitle: "Reminds you to log your transaction after using your bank",
                          isGranted: hasUsageStatsPermission,
                          icon: Icons.hourglass_top_outlined,
                          onAction: () async {
                            await _requestUsageAccess();
                            setModalState(() {});
                          },
                          colorScheme: colorScheme,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await SmartReminderService().testBankReminder();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test bank notification triggered! Check your notification shade.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.bolt),
                          label: const Text("Test Bank Alert Notification Now"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? colorScheme.primary : colorScheme.secondary,
                            side: BorderSide(
                              color: isDark ? colorScheme.primary.withAlpha(120) : colorScheme.secondary.withAlpha(120),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "MONITORED BANKS",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: isDark ? Colors.white38 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              "${_monitoredBanks.where((b) => b.isEnabled).length} active",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._monitoredBanks.map((bank) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(8) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: SwitchListTile(
                              title: Text(
                                bank.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                bank.package,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                              ),
                              value: bank.isEnabled,
                              activeThumbColor: colorScheme.secondary,
                              activeTrackColor: colorScheme.primary,
                              onChanged: (val) async {
                                bank.isEnabled = val;
                                final enabledPackages = _monitoredBanks
                                    .where((b) => b.isEnabled)
                                    .map((b) => b.package)
                                    .toList();
                                await SmartReminderService().setMonitoredBanks(enabledPackages);
                                setModalState(() {});
                                setState(() {});
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onAction,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? Colors.green.withAlpha(120) : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withAlpha(40)
                  : (isDark ? Colors.white10 : Colors.black12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isGranted
                  ? Colors.green
                  : (isDark ? Colors.white70 : colorScheme.secondary),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    "Active",
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text("Enable", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartReminderCard(ColorScheme colorScheme, TextTheme textTheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConfigured = hasUsageStatsPermission;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSmartRemindersEnabled && isConfigured
              ? colorScheme.primary.withAlpha(120)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSmartRemindersEnabled
                      ? colorScheme.primary.withAlpha(50)
                      : (isDark ? Colors.white10 : Colors.black12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: isSmartRemindersEnabled
                      ? (isDark ? colorScheme.primary : colorScheme.secondary)
                      : (isDark ? Colors.white70 : Colors.grey),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Smart Bank Reminders",
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSmartRemindersEnabled
                          ? (isConfigured ? "Active & monitoring" : "Setup permissions")
                          : "Auto-detect banking app launch",
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSmartRemindersEnabled,
                onChanged: _handleSmartReminderMasterToggle,
                activeThumbColor: colorScheme.secondary,
                activeTrackColor: colorScheme.primary,
              ),
            ],
          ),
          if (isSmartRemindersEnabled) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showSmartReminderModal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConfigured ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: isConfigured ? Colors.greenAccent.shade700 : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConfigured
                              ? "${_monitoredBanks.where((b) => b.isEnabled).length} banks monitored"
                              : "Tap to grant Usage Access",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Configure",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? colorScheme.primary : colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: isDark ? colorScheme.primary : colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editDisplayName() async {
    final TextEditingController controller = TextEditingController(
      text: _userName,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            ClipPath(
              clipper: DialogCardClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(25, 45, 25, 30),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? colorScheme.surface
                      : colorScheme.secondary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Edit Display Name",
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Enter your name",
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, controller.text),
                child: Container(
                  width: 90,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colorScheme.primary, // Lime
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomLeft: Radius.circular(25),
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    color: colorScheme.onPrimary, // Black
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != _userName) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName.trim());
      FirestoreService.uploadData('user_name', newName.trim());
      setState(() {
        _userName = newName.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // backgroundColor handled by theme
      appBar: AppBar(
        // backgroundColor handled by theme
        leading: _buildHeaderButton(
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
          colorScheme,
        ),
        title: Text(
          'Settings',
          // Uses HeadlineMedium (Navy or White)
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. NOTCHED PROFILE HEADER
            Stack(
              children: [
                ClipPath(
                  clipper: SettingsHeaderClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                    decoration: BoxDecoration(
                      // Dark Mode: Surface (Lighter Navy). Light Mode: Secondary (Navy).
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.surface
                          : colorScheme.secondary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: colorScheme.primary, // Lime
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: colorScheme.onPrimary, // Black
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (FirebaseAuth.instance.currentUser?.email != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  FirebaseAuth.instance.currentUser!.email!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withAlpha(179), // ~70% opacity
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _buildEditButton(colorScheme, _editDisplayName),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 2. SECURITY & THEME (NOTCHED CARDS)
            _buildSettingToggle(
              "Dark Theme",
              Icons.dark_mode_outlined,
              themeProvider.isDarkMode,
              (v) => themeProvider.setTheme(v),
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 15),
            _buildSettingToggle(
              "Face ID / Touch ID",
              Icons.fingerprint,
              isBiometricsEnabled,
              _handleBiometricToggle, // Pass the new function
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 15),
            _buildSmartReminderCard(colorScheme, textTheme),

            const SizedBox(height: 30),

            // 3. DROPDOWN SELECTIONS
            _buildDropdownTile(
              "Currency",
              Icons.payments_outlined,
              currencyProvider.selectedCurrency,
              ['USD (\$)', 'EUR (€)', 'GBP (£)', 'NGN (₦)'],
              (v) => currencyProvider.setCurrency(v!),
              colorScheme,
              textTheme,
            ),
            _buildDropdownTile(
              "Reminders",
              Icons.notifications_active_outlined,
              reminderFrequency,
              ['None', 'Daily', 'Weekly', 'Monthly'],
              _handleReminderChange,
              colorScheme,
              textTheme,
            ),
            if (reminderFrequency != 'None')
              _buildSimpleTile(
                "Reminder Time",
                Icons.access_time,
                _handleTimeChange,
                textTheme,
                colorScheme,
                trailingText: reminderTime.format(context),
              ),

            if (reminderFrequency != 'None')
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _testNotification,
                    icon: Icon(
                      Icons.notifications_active,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : colorScheme.secondary,
                    ),
                    label: Text(
                      "Test Notification Now",
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white38
                            : Colors.black26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),
            _buildSimpleTile(
              "Add Category",
              Icons.category_outlined,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCategoryPage(),
                  ),
                ).then((value) {
                  // value contains {'name':..., 'icon':...} if user saved
                  if (value != null) {
                    final name = value['name'] as String;
                    final isExpense = value['isExpense'] as bool;
                    final icon = value['icon'] as IconData;

                    // Add to provider
                    Provider.of<CategoryProvider>(
                      context,
                      listen: false,
                    ).addCategory(name, isExpense, icon);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Category '$name' added!")),
                    );
                  }
                });
              },
              textTheme,
              colorScheme,
            ),

            // 4. SECONDARY LINKS
            _buildSimpleTile(
              "Privacy Policy",
              Icons.description_outlined,
              () {},
              textTheme,
              colorScheme,
            ),
            _buildSimpleTile(
              "Terms of Service",
              Icons.gavel_outlined,
              () {},
              textTheme,
              colorScheme,
            ),
            _buildSimpleTile(
              "Help & Support",
              Icons.help_outline,
              () {},
              textTheme,
              colorScheme,
            ),

            const SizedBox(height: 20),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  
                  // Clear skip flag
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('has_skipped_auth');

                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen(isLoginInitial: true)),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  "Sign Out",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
            Text(
              "App Version 1.0.2",
              style: textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(ColorScheme colorScheme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 50,
        decoration: BoxDecoration(
          color: colorScheme.primary, // Lime
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(25),
          ),
        ),
        child: Icon(
          Icons.edit_outlined,
          color: colorScheme.onPrimary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSettingToggle(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.surface, // Light: Light Green, Dark: Lighter Navy
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: colorScheme.brightness == Brightness.dark
                ? Colors.white
                : colorScheme.secondary,
          ), // Navy Icon or White
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.secondary, // Navy thumb
            activeTrackColor: colorScheme.primary, // Lime track
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? colorScheme
                  .surface // Use Surface in Dark Mode
            : Colors.white, // White in Light Mode
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          icon,
          color: colorScheme.brightness == Brightness.dark
              ? Colors.white
              : colorScheme.secondary,
        ),
        title: Text(
          title,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: colorScheme.brightness == Brightness.dark
                ? Colors.white
                : colorScheme.secondary,
          ),
          dropdownColor: colorScheme.surface,
          style: textTheme.bodyMedium, // Text inside dropdown
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSimpleTile(
    String title,
    IconData icon,
    VoidCallback onTap,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    String? trailingText,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: colorScheme.brightness == Brightness.dark
            ? Colors.white70
            : Colors.grey,
      ),
      title: Text(title, style: textTheme.bodyMedium),
      trailing: trailingText != null
          ? Text(
              trailingText,
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
            )
          : Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colorScheme.brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey,
            ),
    );
  }

  Widget _buildHeaderButton(
    IconData icon,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: colorScheme.brightness == Brightness.dark
              ? Colors.white
              : colorScheme.secondary,
          size: 18,
        ),
        onPressed: onTap,
      ),
    );
  }
}

// PROFILE HEADER CLIPPER
class SettingsHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 100;
    double cutoutHeight = 60;
    double cornerRadius = 30;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      0,
      size.width - cutoutWidth,
      cutoutHeight / 2,
    );
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      cutoutHeight,
      size.width - cutoutWidth + cornerRadius,
      cutoutHeight,
    );
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(
      size.width,
      cutoutHeight,
      size.width,
      cutoutHeight + cornerRadius,
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DialogCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 90;
    double cutoutHeight = 50;
    double cornerRadius = 30;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      0,
      size.width - cutoutWidth,
      cutoutHeight / 2,
    );
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      cutoutHeight,
      size.width - cutoutWidth + cornerRadius,
      cutoutHeight,
    );
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(
      size.width,
      cutoutHeight,
      size.width,
      cutoutHeight + cornerRadius,
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
