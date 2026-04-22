import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PinPageMode { setup, verify, unlock }

class PinLockPage extends StatefulWidget {
  final PinPageMode mode;
  final VoidCallback? onAuthenticated;

  const PinLockPage({super.key, required this.mode, this.onAuthenticated});

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends State<PinLockPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final TextEditingController _pinController = TextEditingController();

  String _headerText = "";
  String _subText = "";
  String? _tempPin;
  bool _isError = false;
  bool _canCheckBiometrics = false; // Track if device supports it

  @override
  void initState() {
    super.initState();
    _setupUI();
    _checkBiometrics(); // Check hardware support on load
  }

  void _setupUI() {
    setState(() {
      switch (widget.mode) {
        case PinPageMode.setup:
          _headerText = "Set PIN Code";
          _subText = "Create a 6-digit PIN for backup";
          break;
        case PinPageMode.verify:
          _headerText = "Confirm PIN";
          _subText = "Re-enter your 6-digit PIN";
          break;
        case PinPageMode.unlock:
          _headerText = "Welcome Back";
          _subText = "Enter PIN to unlock";
          break;
      }
    });
  }

  Future<void> _checkBiometrics() async {
    try {
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isDeviceSupported;
      });

      // If we are in unlock mode and hardware is supported, try auth immediately
      if (widget.mode == PinPageMode.unlock && _canCheckBiometrics) {
        _authenticateBiometric();
      }
    } catch (e) {
      debugPrint("Biometric check failed: $e");
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Scan your face or fingerprint to unlock',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly:
              true, // Force FaceID/TouchID (don't fallback to phone pattern)
        ),
      );

      if (didAuthenticate && widget.onAuthenticated != null) {
        widget.onAuthenticated!();
      } else if (!didAuthenticate) {
        // User cancelled or auth failed (and didn't throw)
        _triggerError("Authentication failed");
      }
    } catch (e) {
      debugPrint("Auth error: $e");
      // Show error to user so they know why nothing happened
      _triggerError("Auth Error: ${e.toString().split(']').last.trim()}");
    }
  }

  // NOTE: For the 'Verify' logic to work perfectly inside one widget during Setup,
  // we usually use a local state variable to track 'step'.
  // I updated the logic below to handle the step change properly.

  int _setupStep = 0; // 0 = Enter, 1 = Confirm

  Future<void> _handlePinInput(String pin) async {
    if (widget.mode == PinPageMode.setup) {
      if (_setupStep == 0) {
        _tempPin = pin;
        _pinController.clear();
        setState(() {
          _setupStep = 1;
          _headerText = "Confirm PIN";
          _subText = "Re-enter your 6-digit PIN";
        });
      } else {
        if (pin == _tempPin) {
          await storage.write(key: 'user_pin', value: pin);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_biometric_enabled', true);
          if (mounted) Navigator.pop(context, true);
        } else {
          _triggerError("PINs do not match. Start over.");
          setState(() {
            _setupStep = 0;
            _tempPin = null;
            _headerText = "Set PIN Code";
            _subText = "Create a 6-digit PIN for backup";
          });
        }
      }
    } else if (widget.mode == PinPageMode.unlock) {
      String? storedPin = await storage.read(key: 'user_pin');
      if (storedPin == pin) {
        if (widget.onAuthenticated != null) widget.onAuthenticated!();
      } else {
        _triggerError("Incorrect PIN");
      }
    }
  }

  void _triggerError(String msg) {
    setState(() {
      _isError = true;
      _subText = msg;
    });
    _pinController.clear();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isError = false;
          _subText = widget.mode == PinPageMode.unlock
              ? "Enter PIN to unlock"
              : (_setupStep == 1
                    ? "Re-enter your 6-digit PIN"
                    : "Create a 6-digit PIN for backup");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      // Handles background color from theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Only show back button if NOT unlocking
        leading: widget.mode == PinPageMode.unlock
            ? null
            : _buildHeaderButton(
                Icons.arrow_back_ios_new,
                () => Navigator.pop(context),
                colorScheme,
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // HEADER CARD
            Stack(
              children: [
                ClipPath(
                  clipper: PinHeaderClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 60, 25, 50),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary, // Navy
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerText,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _subText,
                          style: TextStyle(
                            color: _isError
                                ? colorScheme.error
                                : Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),

                        Center(
                          child: Pinput(
                            controller: _pinController,
                            length: 6,
                            defaultPinTheme: defaultPinTheme.copyWith(
                              decoration: defaultPinTheme.decoration!.copyWith(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            focusedPinTheme: defaultPinTheme.copyWith(
                              decoration: defaultPinTheme.decoration!.copyWith(
                                border: Border.all(color: colorScheme.primary),
                              ),
                            ),
                            onCompleted: _handlePinInput, // UPDATED FUNCTION
                            obscureText: true,
                            showCursor: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 80,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        bottomLeft: Radius.circular(25),
                      ),
                    ),
                    child: Icon(
                      widget.mode == PinPageMode.unlock
                          ? Icons.lock_open
                          : Icons.lock,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),

            // ONLY SHOW BIOMETRIC BUTTON IF UNLOCKING AND DEVICE SUPPORTS IT
            if (widget.mode == PinPageMode.unlock && _canCheckBiometrics) ...[
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _authenticateBiometric,
                icon: Icon(
                  Icons.fingerprint,
                  size: 40,
                  color: colorScheme.secondary,
                ),
                label: Text(
                  "Use Face ID / Touch ID",
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: colorScheme.secondary, size: 18),
        onPressed: onTap,
      ),
    );
  }
}

class PinHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 90;
    double cutoutHeight = 65;
    double cornerRadius = 30;
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth, 0);
    path.quadraticBezierTo(
      size.width - cutoutWidth,
      0,
      size.width - cutoutWidth,
      cornerRadius,
    );
    path.lineTo(size.width - cutoutWidth, cutoutHeight - cornerRadius);
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
