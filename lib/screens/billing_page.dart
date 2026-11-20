import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/paystack_service.dart';
import '../core/providers/premium_provider.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _pendingReference;

  @override
  void initState() {
    super.initState();
    PaystackService.warmUpBackend();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User just came back to the app from the payment browser
    if (state == AppLifecycleState.resumed && _pendingReference != null && !_isVerifying) {
      _verifyAndClose(_pendingReference!);
    }
  }

  Future<void> _verifyAndClose(String reference) async {
    if (!mounted) return;
    setState(() => _isVerifying = true);

    final success = await PaystackService.verifyPayment(reference);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      // Payment not confirmed yet — user can retry verification manually
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment not confirmed yet. Try "I have paid" again in a moment.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handlePurchase(
    BuildContext context,
    String planName,
    int amountNgn,
  ) async {
    setState(() => _isLoading = true);

    // Launches in-app WebView, returns transaction reference
    final reference = await PaystackService.checkout(
      context: context,
      amountNgn: amountNgn,
      planType: planName,
    );

    if (!mounted) return;

    if (reference != null) {
      // Payment completed in WebView! Verify immediately.
      _pendingReference = reference;
      await _verifyAndClose(reference);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final premium = Provider.of<PremiumProvider>(context);

    // For demonstration, we use Navy/Lime branding from the Spendr theme.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Go Premium"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildHeaderButton(
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
        ),
      ),
      body: _isLoading || _isVerifying
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isVerifying
                        ? 'Verifying payment...'
                        : 'Connecting to payment portal...',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : _pendingReference != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_browser, size: 80, color: Colors.blue),
                        const SizedBox(height: 20),
                        Text(
                          "Payment Launched!",
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Complete your payment in the browser.\n\nWhen done, tap the button below or just come back to the app — we'll verify automatically.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("I have paid"),
                          onPressed: () => _verifyAndClose(_pendingReference!),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Supercharge Your Experience 🚀",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Say goodbye to ads and automate your entire financial life with our AI-powered statement scanner.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // Current Status
                  if (premium.isPremiumActive)
                    Container(
                      padding: const EdgeInsets.all(15),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You are an active Premium member! Expires: ${premium.premiumExpiryDate?.toString().substring(0, 10)}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // PLAN 1: SINGLE PACK
                  _buildPlanCard(
                    context: context,
                    title: "1 Statement Upload",
                    price: "₦500",
                    description:
                        "No expiration! Scan 1 statement whenever you want.",
                    color: colorScheme.surface,
                    onTap: () => _handlePurchase(context, "1 Statement Upload", 500),
                  ),
                  const SizedBox(height: 15),

                  // PLAN 2: MONTHLY
                  _buildPlanCard(
                    context: context,
                    title: "Monthly Pro",
                    price: "₦2,500 / month",
                    description: "Unlimited uploads and zero ads for 30 days.",
                    isHighlight: true, // Lime colored
                    color: colorScheme.primary,
                    textColor: Colors.black, // Dark text on lime
                    onTap: () => _handlePurchase(context, "Monthly Pro", 2500),
                  ),
                  const SizedBox(height: 15),

                  // PLAN 3: YEARLY
                  _buildPlanCard(
                    context: context,
                    title: "Yearly Pro",
                    price: "₦25,000 / year",
                    description:
                        "Unlimited uploads and zero ads for a full year. Save 16%!",
                    color: colorScheme.surface,
                    onTap: () => _handlePurchase(context, "Yearly Pro", 25000),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String title,
    required String price,
    required String description,
    required Color color,
    Color? textColor,
    bool isHighlight = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tColor = textColor ?? (isDark ? Colors.white : Colors.black);

    return Stack(
      children: [
        // Using PhysicalShape for Shadow + Clip
        PhysicalShape(
          color: color,
          clipBehavior: Clip.antiAlias,
          clipper: _PlanCardClipper(),
          elevation: isDark ? 0 : 5,
          shadowColor: isDark ? Colors.transparent : Colors.black26,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 25, 30),
                decoration: BoxDecoration(
                  border: isHighlight
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHighlight)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "MOST POPULAR",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: tColor,
                            ),
                          ),
                        ),
                        // The space where the 'Get' cutout will be placed visually
                        const SizedBox(width: 80),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        color: tColor.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Cutout Get Button
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 70,
              height: 40,
              decoration: BoxDecoration(
                color: isHighlight
                    ? Colors.black
                    : theme.colorScheme.primary, // Lime Get button or Black
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "Get",
                style: TextStyle(
                  color: isHighlight ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
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

class _PlanCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 80;
    double cutoutHeight = 50;
    double cornerRadius = 20;

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

    path.lineTo(0, cornerRadius);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
