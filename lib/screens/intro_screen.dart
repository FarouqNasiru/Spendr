import 'package:flutter/material.dart';
import 'package:spendr/core/constants/app_text_styles.dart';
import 'package:spendr/widgets/button1.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

// Imports- [x] Comprehensive Notification Audit (all Android versions)
// - [x] Apply Dark Mode to Intro Screen
import 'package:spendr/screens/pin_lock_page.dart';
import 'package:spendr/screens/activitypage.dart';
import 'package:spendr/screens/enter_name.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendr/screens/auth_screen.dart';

// 1. Change to StatefulWidget
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  // 2. Paste your security check function here
  Future<void> _checkSecurity() async {
    final prefs = await SharedPreferences.getInstance();
    final isProtected = prefs.getBool('is_biometric_enabled') ?? false;
    // Check if user already exists (so we don't ask for name again)
    final hasUser = prefs.containsKey('user_name');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final hasSkipped = prefs.getBool('has_skipped_auth') ?? false;

    if (isProtected) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PinLockPage(
            mode: PinPageMode.unlock,
            onAuthenticated: () {
              _navigateBasedOnAuth(hasUser, firebaseUser, hasSkipped);
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      _navigateBasedOnAuth(hasUser, firebaseUser, hasSkipped);
    }
  }

  void _navigateBasedOnAuth(bool hasUser, User? firebaseUser, bool hasSkipped) {
    if (firebaseUser != null || (hasUser && hasSkipped)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActivityPage()),
      );
    } else if (hasUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen(isLoginInitial: true)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterNamePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double h = constraints.maxHeight;
          final double w = constraints.maxWidth;

          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // --- TOP LOGO SECTION ---
                Positioned(
                  top: h * 0.06,
                  left: w * 0.05,
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/assets/images/spendr_logo.png',
                        height: h * 0.05,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: w * 0.03),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Spend',
                              style: AppTextStyles.heading2.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: 'r',
                              style: AppTextStyles.heading2.copyWith(
                                color: colorScheme.primary, // Lime
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- DECORATIVE ELEMENTS ---
                Positioned(
                  top: h * 0.40,
                  right: -w * 0.3,
                  child: Transform.rotate(
                    angle: 20 * math.pi / 180,
                    child: Opacity(
                      opacity: 0.4,
                      child: Icon(
                        Icons.circle,
                        size: w * 0.6,
                        color: colorScheme.primary, // Lime
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -h * 0.1,
                  right: w * 0.70,
                  child: Transform.rotate(
                    angle: -20 * math.pi / 180,
                    child: Opacity(
                      opacity: theme.brightness == Brightness.dark ? 0.1 : 0.2,
                      child: Icon(
                        Icons.circle,
                        size: w * 0.5,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : colorScheme.secondary, // Navy/White
                      ),
                    ),
                  ),
                ),

                // --- CARDS ---
                Positioned(
                  top: h * 0.18,
                  left: -w * 0.12,
                  child: _buildShadowContainer(
                    child: Transform.rotate(
                      angle: -10 * math.pi / 180,
                      child: Image.asset(
                        'lib/assets/images/card11.png',
                        width: w * 0.7,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: h * 0.26,
                  left: w * 0.25,
                  child: _buildShadowContainer(
                    child: Image.asset(
                      'lib/assets/images/card.png',
                      width: w * 0.7,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: h * 0.09,
                  right: -w * 0.28,
                  child: _buildShadowContainer(
                    child: Image.asset(
                      'lib/assets/images/card21.png',
                      width: w * 0.7,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: h * 0.16,
                  right: w * 0.18,
                  child: _buildShadowContainer(
                    child: Image.asset(
                      'lib/assets/images/plus.png',
                      width: w * 0.45,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // --- BOTTOM CONTENT SECTION ---
                Positioned(
                  bottom: h * 0.04,
                  left: w * 0.05,
                  right: w * 0.05,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Good \nfinances,\n'),
                            TextSpan(
                              text: 'better life!',
                              style: TextStyle(
                                color: colorScheme.primary.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        style: AppTextStyles.heading3.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : colorScheme.secondary,
                          height: 1.1,
                          fontSize: 62,
                        ),
                      ),
                      SizedBox(height: h * 0.02),
                      Text(
                        'Manage your expenses and incomes all in one place with Spendr.',
                        style: AppTextStyles.body.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white70
                              : null,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      SizedBox(height: h * 0.03),

                      // 3. Wrap your Button in GestureDetector
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: Button1(onPressed: _checkSecurity),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShadowContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(107, 0, 0, 0).withOpacity(0.05),
            spreadRadius: 0.1,
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: child,
    );
  }
}
