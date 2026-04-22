import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spendr/screens/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnterNamePage extends StatefulWidget {
  const EnterNamePage({super.key});

  @override
  State<EnterNamePage> createState() => _EnterNamePageState();
}

class _EnterNamePageState extends State<EnterNamePage> {
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // 1. Heading Text
            const Text(
              "Let's get\nstarted!",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D1B2A), // Navy
                height: 1.1,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "What should we call you?",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // 2. Notched Input Card
            Stack(
              children: [
                ClipPath(
                  clipper: NameInputClipper(), // Custom Clipper defined below
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 60, 25, 50),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A), // Dark Navy
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Name",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          cursorColor: const Color(
                            0xFFE2F163,
                          ), // Lime Green Cursor
                          decoration: const InputDecoration(
                            hintText: "Enter Here",
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. The "Next" Button sitting in the notch
                Positioned(top: 0, right: 0, child: _buildNextButton()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () async {
        // Handle navigation to next page
        if (_nameController.text.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', _nameController.text);

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AuthScreen(isLoginInitial: false),
              ),
            );
          }
        }
      },
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
        child: const Icon(Icons.arrow_forward, color: Colors.black, size: 28),
      ),
    );
  }
}

// Reuse the Clipper logic to maintain consistent shape
class NameInputClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    // Dimensions for the cutout to fit the button (100x60)
    double cutoutWidth = 100;
    double cutoutHeight = 60;
    double cornerRadius = 30;

    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Top line up to the notch
    path.lineTo(size.width - cutoutWidth - cornerRadius, 0);

    // The Notch Curve logic
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

    // Bottom of the notch
    path.lineTo(size.width - cornerRadius, cutoutHeight);
    path.quadraticBezierTo(
      size.width,
      cutoutHeight,
      size.width,
      cutoutHeight + cornerRadius,
    );

    // Rest of the box
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
