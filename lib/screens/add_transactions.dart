import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction_model.dart';
import '../../core/providers/transaction_provider.dart';
import '../../core/providers/category_provider.dart';
import '../core/providers/currency_provider.dart';
import '../utils/constants.dart';
import 'add_category.dart';

class AddTransactionPage extends StatefulWidget {
  final double? initialAmount;
  final String? initialType; // 'Expense' or 'Income'
  final String? initialCategory;
  final String? initialNote;

  const AddTransactionPage({
    super.key,
    this.initialAmount,
    this.initialType,
    this.initialCategory,
    this.initialNote,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  bool isExpense = true;
  String selectedCategory = 'Travelling';
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      isExpense = widget.initialType == 'Expense';
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      final amt = widget.initialAmount!;
      _amountController.text = amt % 1.0 == 0.0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
    }
    if (widget.initialCategory != null) {
      selectedCategory = widget.initialCategory!;
    }
  }

  void _goToAddCategory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    ).then((value) {
      if (value != null && value is Map<String, dynamic>) {
        final name = value['name'] as String;
        final isExp = value['isExpense'] as bool;
        final icon = value['icon'] as IconData;

        // Add to provider
        Provider.of<CategoryProvider>(
          context,
          listen: false,
        ).addCategory(name, isExp, icon);

        // Auto-select if it matches current toggle
        if (isExp == isExpense) {
          setState(() {
            selectedCategory = name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. ACCESS THEME DATA
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final categoryProvider = context.watch<CategoryProvider>();
    List<Map<String, dynamic>> currentCategories = isExpense
        ? categoryProvider.expenseCategories
        : categoryProvider.incomeCategories;

    final currencyProvider = context.watch<CurrencyProvider>();
    final currencySymbol = currencyProvider.currencySymbol;

    return Scaffold(
      // Background handled by AppTheme.scaffoldBackgroundColor
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Explicitly transparent
        elevation: 0,
        leading: _buildHeaderButton(
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
        ),
        title: Text(
          'Add Transaction',
          // Use Navy text from theme
          style: textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 1. INPUT AREA WITH NOTCH
            Stack(
              children: [
                ClipPath(
                  clipper: TransactionHeaderClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 80, 25, 40),
                    decoration: BoxDecoration(
                      color: colorScheme.brightness == Brightness.dark
                          ? colorScheme.surface
                          : colorScheme.secondary, // Navy or Dark Surface
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enter Amount",
                          style: TextStyle(color: Colors.grey),
                        ),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: textTheme.headlineLarge?.copyWith(
                            color: Colors.white, // White text on Navy bg
                            fontSize: 40,
                          ),
                          decoration: InputDecoration(
                            hintText: "${currencySymbol}0.00",
                            hintStyle: const TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // The Save Button with a small offset for "breathing room"
                Positioned(
                  top: 5,
                  right: 5,
                  child: _buildSaveButton(colorScheme),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 2. TOGGLE INCOME/EXPENSE
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Category",
                  style: textTheme.headlineMedium?.copyWith(fontSize: 18),
                ),
                GestureDetector(
                  onTap: _goToAddCategory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 16, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          "New",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. CATEGORY GRID
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: currentCategories.length,
              itemBuilder: (context, index) {
                final cat = currentCategories[index];
                return _buildSelectableCategory(
                  cat['icon'],
                  cat['name'],
                  colorScheme,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () async {
        final amountText = _amountController.text.replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        final amount = double.tryParse(amountText);

        if (amount != null && amount > 0) {
          final transactionProvider = context.read<TransactionProvider>();
          final uuid = const Uuid().v4();

          // Find the icon for the selected category
          IconData iconData = Icons.help_outline;
          if (isExpense) {
            final cat = expenseCategories.firstWhere(
              (element) => element['name'] == selectedCategory,
              orElse: () => expenseCategories.first,
            );
            iconData = cat['icon'];
          } else {
            final cat = incomeCategories.firstWhere(
              (element) => element['name'] == selectedCategory,
              orElse: () => incomeCategories.first,
            );
            iconData = cat['icon'];
          }

          final newTransaction = Transaction(
            id: uuid,
            title: selectedCategory,
            category: selectedCategory,
            amount: amount,
            date: DateTime.now(),
            isExpense: isExpense,
            iconCode: iconData.codePoint,
          );

          await transactionProvider.addTransaction(newTransaction);

          // Update legacy total counters for backward compatibility if needed,
          // or rely on analyzing the list. For now, keep totals as well for simple dashboard stats.
          final prefs = await SharedPreferences.getInstance();
          if (isExpense) {
            final currentExpense = prefs.getDouble('total_expense') ?? 0.0;
            await prefs.setDouble('total_expense', currentExpense + amount);
          } else {
            final currentIncome = prefs.getDouble('total_income') ?? 0.0;
            await prefs.setDouble('total_income', currentIncome + amount);
          }

          if (mounted) {
            Navigator.pop(context, true);
          }
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
            color: isActive
                ? colorScheme.primary
                : Colors.white, // Active = Lime
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: Colors.black12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                // If active (Lime), text is black (onPrimary). If inactive (White), text is black.
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableCategory(
    IconData icon,
    String name,
    ColorScheme colorScheme,
  ) {
    bool isSelected = selectedCategory == name;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = name),
      child: ClipPath(
        clipper: CategoryCardClipper(),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme
                      .primary // Selected = Lime
                : colorScheme.surface, // Unselected = Light Green (cardLight)
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.black
                    : (colorScheme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black),
                size: 24,
              ),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.black
                      : (colorScheme.brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    // Access theme here or assume context available if methods are in state
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

// ---------------- CLIPPERS ----------------

class TransactionHeaderClipper extends CustomClipper<Path> {
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

class CategoryCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double cutoutWidth = 55;
    double cutoutHeight = 25;
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
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
