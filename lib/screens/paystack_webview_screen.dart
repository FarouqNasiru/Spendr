import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// An in-app WebView screen that loads the Paystack payment page.
/// It intercepts the [callbackUrl] to detect a successful redirect and
/// returns the transaction reference automatically.
class PaystackWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String callbackUrl;

  const PaystackWebViewScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.callbackUrl,
  });

  @override
  State<PaystackWebViewScreen> createState() => _PaystackWebViewScreenState();
}

class _PaystackWebViewScreenState extends State<PaystackWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final url = request.url;

            // --- Auto-detect payment success/cancel ---
            // Paystack redirects to the callback_url after success
            if (url.startsWith(widget.callbackUrl)) {
              // Pop and return the reference — BillingPage will verify it
              if (mounted) Navigator.pop(context, widget.reference);
              return NavigationDecision.prevent;
            }

            // Allow all other Paystack / bank pages within the WebView
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel payment',
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
