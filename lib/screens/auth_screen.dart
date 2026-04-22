import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spendr/core/providers/auth_provider.dart';
import 'package:spendr/screens/activitypage.dart';
import 'package:spendr/screens/enter_name.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/firestore_service.dart';
import '../core/providers/transaction_provider.dart';
import '../core/providers/category_provider.dart';
import '../core/providers/currency_provider.dart';
import '../core/providers/category_mapping_provider.dart';

class AuthScreen extends StatefulWidget {
  final bool isLoginInitial;
  const AuthScreen({super.key, this.isLoginInitial = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLoginInitial;
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? error;

    if (_isLogin) {
      error = await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Passwords do not match";
        });
        return;
      }
      error = await authProvider.signup(
        _emailController.text,
        _passwordController.text,
      );
    }

    if (mounted) {
      if (error == null) {
        await FirestoreService.downloadAndRestoreData();
        if (!_isLogin) {
          final prefs = await SharedPreferences.getInstance();
          final name = prefs.getString('user_name');
          if (name != null) FirestoreService.uploadData('user_name', name);
          final trans = prefs.getString('transactions');
          if (trans != null) FirestoreService.uploadData('transactions', trans);
        }
        
        if (mounted) {
          Provider.of<TransactionProvider>(context, listen: false).refresh();
          Provider.of<CategoryProvider>(context, listen: false).refresh();
          Provider.of<CurrencyProvider>(context, listen: false).refresh();
          Provider.of<CategoryMappingProvider>(context, listen: false).refresh();
          
          setState(() => _isLoading = false);
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ActivityPage()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black,
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              } else {
                // If it's the root screen (loaded first), route back to Name setup
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const EnterNamePage()),
                );
              }
            },
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Heading Text
                          Text(
                            _isLogin
                                ? "Welcome\nBack!"
                                : "Create your\nAccount",
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1B2A), // Navy
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _isLogin
                                ? "Log in to continue your journey"
                                : "Start managing your finances today",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),

                    // Notched Input Card
                    Expanded(
                      child: Stack(
                        children: [
                          ClipPath(
                            clipper: AuthInputClipper(),
                            child: Container(
                              width: double.infinity,
                              // Ensure this container fills the expanded stack
                              constraints: const BoxConstraints(
                                minHeight: double.infinity,
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                25,
                                60,
                                25,
                                50,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D1B2A), // Dark Navy
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                    controller: _emailController,
                                    hintText: "Email Address",
                                    icon: Icons.email_outlined,
                                  ),
                                  const SizedBox(height: 20),

                                  _buildTextField(
                                    controller: _passwordController,
                                    hintText: "Password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                  ),

                                  if (!_isLogin) ...[
                                    const SizedBox(height: 20),
                                    _buildTextField(
                                      controller: _confirmPasswordController,
                                      hintText: "Confirm Password",
                                      icon: Icons.lock_reset_outlined,
                                      isPassword: true,
                                    ),
                                  ],

                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 15),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],

                                  const Spacer(),

                                  // Toggle Login/Signup
                                  Center(
                                    child: TextButton(
                                      onPressed: () => setState(() {
                                        _isLogin = !_isLogin;
                                        _errorMessage = null;
                                        _confirmPasswordController.clear();
                                      }),
                                      child: Text.rich(
                                        TextSpan(
                                          text: _isLogin
                                              ? "Don't have an account? "
                                              : "Already have an account? ",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: _isLogin
                                                  ? "Sign Up"
                                                  : "Login",
                                              style: const TextStyle(
                                                color: Color(
                                                  0xFFE2F163,
                                                ), // lime
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Bottom Action Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Skip for now
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            await prefs.setBool(
                                              'has_skipped_auth',
                                              true,
                                            );
                                            if (mounted) {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ActivityPage(),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white12,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: const Text(
                                            "Skip for now",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      // Google Sign In
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            setState(() {
                                              _isLoading = true;
                                              _errorMessage = null;
                                            });
                                            final authProvider =
                                                Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            final String? error =
                                                await authProvider
                                                    .signInWithGoogle();
                                            if (mounted) {
                                              if (error == null) {
                                                await FirestoreService.downloadAndRestoreData();
                                                final prefs = await SharedPreferences.getInstance();
                                                final name = prefs.getString('user_name');
                                                if (name != null) FirestoreService.uploadData('user_name', name);
                                                
                                                if (mounted) {
                                                  Provider.of<TransactionProvider>(context, listen: false).refresh();
                                                  Provider.of<CategoryProvider>(context, listen: false).refresh();
                                                  Provider.of<CurrencyProvider>(context, listen: false).refresh();
                                                  Provider.of<CategoryMappingProvider>(context, listen: false).refresh();
                                                  
                                                  setState(() => _isLoading = false);
                                                  Navigator.pushAndRemoveUntil(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ActivityPage(),
                                                    ),
                                                    (route) => false,
                                                  );
                                                }
                                              } else {
                                                setState(() {
                                                  _isLoading = false;
                                                  _errorMessage = error;
                                                });
                                              }
                                            }
                                          },
                                          icon: Image.asset(
                                            'lib/assets/images/google.png',
                                            height: 20,
                                            width: 20,
                                          ),
                                          label: const Text(
                                            "Google",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),

                          // The "Next" Button sitting in the notch
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _buildNextButton(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hintText,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          cursorColor: const Color(0xFFE2F163), // Lime Green Cursor
          decoration: const InputDecoration(
            hintText: "Enter Here",
            hintStyle: TextStyle(color: Colors.white24, fontSize: 18),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const Divider(color: Colors.white24, height: 20),
      ],
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleAuth,
      child: Container(
        width: 90,
        height: 50,
        decoration: const BoxDecoration(
          color: Color(0xFFE2F163), // Lime Green
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(25),
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            : const Icon(Icons.arrow_forward, color: Colors.black, size: 28),
      ),
    );
  }
}

class AuthInputClipper extends CustomClipper<Path> {
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

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, cornerRadius);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
