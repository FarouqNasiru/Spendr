import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/transaction_provider.dart';
import '../core/providers/currency_provider.dart';
import '../models/transaction_model.dart';

class TransfersPage extends StatelessWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final transactionProvider = context.watch<TransactionProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final transactions = transactionProvider.recentTransactions;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildHeaderButton(
          context,
          Icons.arrow_back_ios_new,
          () => Navigator.pop(context),
          colorScheme,
        ),
        title: Hero(
          tag: 'recent-transfers',
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              'Transactions',
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // HEADER CARD WITH NOTCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                ClipPath(
                  clipper: TransfersHeaderClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(25, 30, 25, 30),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? colorScheme.surface
                          : colorScheme.secondary,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Transactions",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${transactions.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 90,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary, // Lime
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(30),
                        bottomLeft: Radius.circular(25),
                      ),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text("No transactions recorded"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return _buildTransactionItem(
                        context,
                        tx,
                        textTheme,
                        currencyProvider.currencySymbol,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction transaction,
    TextTheme textTheme,
    String currencySymbol,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transaction.isExpense
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.icon,
              color: transaction.isExpense ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${transaction.date.day}/${transaction.date.month}/${transaction.date.year}",
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            "${transaction.isExpense ? '-' : '+'}$currencySymbol${transaction.amount.toStringAsFixed(2)}",
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: transaction.isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDark ? Colors.white : colorScheme.secondary,
          size: 18,
        ),
        onPressed: onTap,
      ),
    );
  }
}

class TransfersHeaderClipper extends CustomClipper<Path> {
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
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
