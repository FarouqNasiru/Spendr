import 'package:flutter/material.dart';
import 'package:spendr/core/constants/app_text_styles.dart'; // Assuming you have this
// If you don't use the text styles constant, you can remove the import and use standard TextStyles

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController _nameController = TextEditingController();
  bool isExpense = true;
  IconData selectedIcon = Icons.shopping_bag; // Default icon

  // A curated list of icons suitable for a finance app
  final List<IconData> availableIcons = [
    Icons.shopping_bag,
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.movie,
    Icons.medical_services,
    Icons.school,
    Icons.flight,
    Icons.pets,
    Icons.sports_esports,
    Icons.work,
    Icons.attach_money,
    Icons.savings,
    Icons.card_giftcard,
    Icons.fitness_center,
    Icons.coffee,
    Icons.build,
    Icons.local_taxi,
    Icons.phone_iphone,
    Icons.wifi,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // Background handled by theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildHeaderButton(
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
          colorScheme,
        ),
        title: Text(
          'New Category',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 1. NOTCHED NAME INPUT (Design consistency)
            Stack(
              children: [
                ClipPath(
                  clipper: CategoryHeaderClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 60, 25, 40),
                    decoration: BoxDecoration(
                      color: colorScheme.brightness == Brightness.dark
                          ? colorScheme.surface
                          : colorScheme.secondary, // NAVY BLUE
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Category Name",
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextField(
                          controller: _nameController,
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          cursorColor: colorScheme.primary,
                          decoration: const InputDecoration(
                            hintText: "e.g. Groceries",
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // SAVE BUTTON IN NOTCH
                Positioned(
                  top: 5,
                  right: 5,
                  child: _buildSaveButton(colorScheme),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 2. TYPE TOGGLE
            Row(
              children: [
                _buildTypeToggle(
                  "Expense",
                  isExpense,
                  () => setState(() => isExpense = true),
                  colorScheme,
                ),
                const SizedBox(width: 15),
                _buildTypeToggle(
                  "Income",
                  !isExpense,
                  () => setState(() => isExpense = false),
                  colorScheme,
                ),
              ],
            ),

            const SizedBox(height: 30),
            Text(
              "Choose Icon",
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            // 3. ICON GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 5 icons per row
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: availableIcons.length,
              itemBuilder: (context, index) {
                final icon = availableIcons[index];
                final isSelected = selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = icon),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : (colorScheme.brightness == Brightness.dark
                                ? colorScheme.surface
                                : Colors.white),
                      borderRadius: BorderRadius.circular(15),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.black12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.black
                          : (colorScheme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.grey),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        if (_nameController.text.isNotEmpty) {
          // Return the new category data to the previous screen
          // You can also call your Provider here to save it directly
          Navigator.pop(context, {
            'name': _nameController.text,
            'isExpense': isExpense,
            'icon': selectedIcon,
          });
        }
      },
      child: Container(
        width: 85,
        height: 45,
        decoration: BoxDecoration(
          color: colorScheme.primary, // LIME GREEN
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(25),
          ),
        ),
        child: Icon(Icons.check, color: colorScheme.onPrimary, size: 28),
      ),
    );
  }

  Widget _buildTypeToggle(
    String title,
    bool isActive,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: Colors.black12),
          ),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
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

// Reuse the clipper logic for consistency
class CategoryHeaderClipper extends CustomClipper<Path> {
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
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
