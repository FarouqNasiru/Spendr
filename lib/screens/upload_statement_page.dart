import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spendr/core/providers/auth_provider.dart';
import 'package:spendr/core/providers/premium_provider.dart';
import 'package:spendr/screens/billing_page.dart';
import 'package:spendr/screens/auth_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart'; // For mime type lookup
import 'package:spendr/screens/review_transactions_page.dart';
import '../core/services/ad_service.dart';
import '../core/config/app_config.dart';

class UploadStatementPage extends StatefulWidget {
  const UploadStatementPage({super.key});

  @override
  State<UploadStatementPage> createState() => _UploadStatementPageState();
}

class _UploadStatementPageState extends State<UploadStatementPage> {
  bool _isAnalyzing = false;
  String? _statusMessage;

  Future<void> _pickAndAnalyzeFile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showLoginPrompt();
      return;
    }

    // Checking Premium and Ad flow FIRST
    bool canProceed = await _checkPremiumOrAd(context);
    if (!canProceed) {
      return;
    }

    // 1. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        _isAnalyzing = true;
        _statusMessage = "Reading bank statement...";
      });

      try {
        await _extractTransactions(file);
      } catch (e) {
        debugPrint("Error analyzing file: $e");
        setState(() {
          _isAnalyzing = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<bool> _checkPremiumOrAd(BuildContext context) async {
    final premium = Provider.of<PremiumProvider>(context, listen: false);

    if (premium.canUpload) {
      await premium.consumeUpload();
      return true;
    }

    bool wantsToWatchAd = false;
    bool wantsToBuyPremium = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Stack(
            children: [
              ClipPath(
                clipper: _UploadPopupClipper(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(25, 40, 25, 30),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 50, color: theme.colorScheme.primary),
                      const SizedBox(height: 15),
                      const Text(
                        "Upload Statement",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "To use the AI statement upload feature, you can either watch a quick ad or purchase Premium to remove ads forever.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                wantsToWatchAd = true;
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text("Watch Ad", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                wantsToBuyPremium = true;
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              child: const Text("Remove Ads", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 70,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (wantsToBuyPremium) {
      // BillingPage handles verification internally via direct Paystack API poll.
      // It pops with true only after payment is confirmed.
      bool? paymentConfirmed = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BillingPage()),
      );
      
      if (paymentConfirmed == true) {
        // Refresh local state from Firestore, then proceed
        await premium.refresh();
        if (premium.canUpload) {
          await premium.consumeUpload();
          return true;
        }
        // Subscription plans don't consume uploads — check again
        if (premium.isPremiumActive) return true;
      }
      return false;
    }

    if (wantsToWatchAd) {
      setState(() => _statusMessage = "Loading Ad...");
      bool earnedReward = await AdService().showRewardedAd();
      setState(() => _statusMessage = null);
      return earnedReward;
    }

    return false;
  }

  Future<void> _extractTransactions(File file) async {
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final bytes = await file.readAsBytes();
    final fileBase64 = base64Encode(bytes);

    final response = await http.post(
      Uri.parse("${AppConfig.backendUrl}/parse-statement"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fileBase64": fileBase64,
        "mimeType": mimeType,
      }),
    );

    if (response.statusCode != 200) {
      try {
        final err = jsonDecode(response.body)['error'];
        throw err ?? "Failed to parse statement (${response.statusCode})";
      } catch (e) {
        if (e is String) rethrow;
        throw "Failed to parse statement (${response.statusCode})";
      }
    }

    final data = jsonDecode(response.body);
    List<dynamic> parsedData = data['transactions'] ?? [];

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewTransactionsPage(extractedData: parsedData),
        ),
      );
      setState(() {
        _isAnalyzing = false;
        _statusMessage = null;
      });
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: const Text("Authentication Required", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("You need to be logged in to use the AI statement upload feature."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen(isLoginInitial: true)),
                );
              },
              child: const Text("Login / Sign Up"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Upload Statement",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        leading: _buildHeaderButton(
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isAnalyzing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE2F163)),
                  const SizedBox(height: 20),
                  Text(_statusMessage ?? "Processing...", style: theme.textTheme.bodyLarge),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 80,
                    color: isDark ? theme.colorScheme.primary : const Color(0xFF0D1B2A),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Upload a PDF or Image\nof your bank statement",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _pickAndAnalyzeFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F163),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Pick File",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    Text(_statusMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        shape: BoxShape.circle,
        border: isDark ? Border.all(color: Colors.white24) : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 18),
        onPressed: onTap,
      ),
    );
  }
}

class _UploadPopupClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 70;
    double cutoutHeight = 55;
    double cornerRadius = 30;
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);
    path.quadraticBezierTo(size.width - cutoutWidth, 0, size.width - cutoutWidth, cutoutHeight / 2);
    path.quadraticBezierTo(size.width - cutoutWidth, cutoutHeight, size.width - cutoutWidth + cornerRadius, cutoutHeight);
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(size.width, cutoutHeight, size.width, cutoutHeight + cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.lineTo(0, cornerRadius);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
