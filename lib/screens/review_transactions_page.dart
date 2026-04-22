import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/transaction_provider.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/category_mapping_provider.dart';
import '../../models/transaction_model.dart';

class ReviewTransactionsPage extends StatefulWidget {
  final List<dynamic> extractedData;

  const ReviewTransactionsPage({super.key, required this.extractedData});

  @override
  State<ReviewTransactionsPage> createState() => _ReviewTransactionsPageState();
}

class _ReviewTransactionsPageState extends State<ReviewTransactionsPage> {
  // Key: Description, Value: List of transactions
  late Map<String, List<Map<String, dynamic>>> _groupedTransactions;
  // Key: Description, Value: Assigned Category Name
  late Map<String, String> _assignedCategories;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _groupedTransactions = {};
    _assignedCategories = {};

    final mappingProvider = Provider.of<CategoryMappingProvider>(
      context,
      listen: false,
    );

    for (var item in widget.extractedData) {
      final tx = Map<String, dynamic>.from(item);
      final desc = tx['description'] ?? 'Unknown';

      if (!_groupedTransactions.containsKey(desc)) {
        _groupedTransactions[desc] = [];
        // Apply existing mapping if available, otherwise use extracted category
        _assignedCategories[desc] =
            mappingProvider.getCategoryFor(desc) ??
            tx['category'] ??
            'Travelling';
      }
      _groupedTransactions[desc]!.add(tx);
    }
  }

  Future<void> _saveAll() async {
    try {
      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final mappingProvider = Provider.of<CategoryMappingProvider>(
        context,
        listen: false,
      );

      int totalAdded = 0;

      for (var desc in _groupedTransactions.keys) {
        final categoryName = _assignedCategories[desc]!;
        final transactions = _groupedTransactions[desc]!;

        // Save mapping rule
        await mappingProvider.saveMapping(desc, categoryName);

        // Find category icon more robustly
        final allCats = categoryProvider.expenseCategories.followedBy(
          categoryProvider.incomeCategories,
        );

        var category = allCats.firstWhere(
          (c) => c['name'] == categoryName,
          orElse: () => {},
        );

        IconData iconData;
        bool isExpGroup = transactions.any((tx) => 
            tx['type'].toString().trim().toLowerCase() == 'expense');

        if (category.isEmpty) {
          // Auto-create category if it doesn't exist
          iconData = Icons.category_outlined;
          await categoryProvider.addCategory(
            categoryName,
            isExpGroup,
            iconData,
          );
        } else {
          iconData = category['icon'] as IconData;
        }

        for (var tx in transactions) {
          final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
          if (amount <= 0) continue;

          final newTx = Transaction(
            id: const Uuid().v4(),
            title: desc, // Description/Merchant
            category: categoryName, // Actual Category
            amount: amount,
            date: DateTime.tryParse(tx['date'].toString()) ?? DateTime.now(),
            isExpense: tx['type'].toString().trim().toLowerCase() == 'expense',
            iconCode: iconData.codePoint,
          );

          await transactionProvider.addTransaction(newTx);
          totalAdded++;
        }
      }

      if (mounted) {
        // Refresh TransactionProvider from SharedPreferences to ensure
        // the UI (graph, recent transactions) picks up every new transaction.
        await Provider.of<TransactionProvider>(context, listen: false).refresh();

        // Navigate back to ActivityPage. popUntil(isFirst) could jump too far
        // if ActivityPage is not the root. Using a named predicate is safer.
        Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/activity');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Added $totalAdded transactions! Check 'Year' view if dates are historical."),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving transactions: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: ${e.toString()}")),
        );
      }
    }
  }

  void _showCategoryPicker(String description) {
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final allCategories = categoryProvider.expenseCategories
        .followedBy(categoryProvider.incomeCategories)
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Select Category for $description",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final cat = allCategories[index];
                    return ListTile(
                      leading: Icon(cat['icon']),
                      title: Text(cat['name']),
                      onTap: () {
                        setState(() {
                          _assignedCategories[description] = cat['name'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final descriptions = _groupedTransactions.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Review & Map Categories",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton(
              onPressed: _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2F163),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text("SAVE ALL"),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: descriptions.length,
        itemBuilder: (context, index) {
          final desc = descriptions[index];
          final transactions = _groupedTransactions[desc]!;
          final assignedCat = _assignedCategories[desc]!;
          final count = transactions.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "$count transaction${count > 1 ? 's' : ''}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _groupedTransactions.remove(desc);
                          _assignedCategories.remove(desc);
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Map to Category:",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    GestureDetector(
                      onTap: () => _showCategoryPicker(desc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F163).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              assignedCat,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1B2A),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Small preview of transactions in this group
                ...transactions
                    .take(2)
                    .map(
                      (tx) => Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "• ${tx['date']}: \$${tx['amount']}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                if (count > 2)
                  Text(
                    "  and ${count - 2} more...",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
