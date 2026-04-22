import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/paystack_webview_screen.dart';

class PaystackService {
  /// The URL our backend /generate-payment sends as callback_url to Paystack.
  /// After payment, Paystack redirects to this URL — we intercept it in the WebView.
  static const String _callbackUrl = 'https://spendr.app/payment-callback';

  // Replace with your Render URL once deployed.
  // Use 'http://10.0.2.2:3000' for Android emulator, 'http://localhost:3000' for iOS simulator.
  static const String backendUrl = "https://spendr-backend-07gy.onrender.com";

  /// Opens the Paystack payment page in an in-app WebView.
  /// Returns the transaction [reference] if the user completes payment, or null if cancelled.
  static Future<String?> checkout({
    required BuildContext context,
    required int amountNgn,
    required String planType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // 1. Initialize payment with our backend
      final response = await http.post(
        Uri.parse("$backendUrl/initialize-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": user.email,
          "amount": amountNgn * 100, // Kobo
          "userId": user.uid,
          "planType": planType,
        }),
      );

      if (response.statusCode != 200) {
        throw "Backend returned ${response.statusCode}: ${response.body}";
      }

      final data = jsonDecode(response.body);
      final authUrl = data['data']['authorization_url'] as String?;
      final reference = data['data']['reference'] as String?;

      if (authUrl == null || reference == null) {
        throw "Invalid response from backend";
      }

      // 2. Open in-app WebView — it intercepts the callback and returns the reference
      if (!context.mounted) return null;
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackWebViewScreen(
            authorizationUrl: authUrl,
            reference: reference,
            callbackUrl: _callbackUrl,
          ),
        ),
      );

      return result; // null if cancelled, reference string if payment was completed
    } catch (e) {
      debugPrint("Paystack Error: $e");
      return null;
    }
  }

  /// Verifies a payment by its reference. Updates Firestore on success.
  static Future<bool> verifyPayment(String reference) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/verify-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"reference": reference}),
      );

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint("Verify Error: $e");
      return false;
    }
  }
}
