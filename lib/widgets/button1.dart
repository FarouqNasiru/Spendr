import 'package:flutter/material.dart';
import 'package:spendr/core/constants/app_text_styles.dart';

class Button1 extends StatelessWidget {
  // Add this variable to accept a function from the parent
  final VoidCallback? onPressed;

  const Button1({
    super.key,
    this.onPressed, // Accept it in the constructor
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Use the function passed from the parent
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE2F163),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0, // Optional: Removes shadow for a flatter look
      ),
      child: Text(
        'Get Started',
        // Ensure text is black for contrast against Lime
        style: AppTextStyles.label.copyWith(color: Colors.black),
      ),
    );
  }
}
