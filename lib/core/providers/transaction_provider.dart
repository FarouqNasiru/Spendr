import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction_model.dart';

import '../services/firestore_service.dart';

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];

  List<Transaction> get transactions => _transactions;

  // Get recent transactions sorted by date (newest first)
  List<Transaction> get recentTransactions {
    List<Transaction> sorted = List.from(_transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  TransactionProvider() {
    _loadTransactions();
  }

  Future<void> refresh() async {
    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? transactionsString = prefs.getString('transactions');
    if (transactionsString != null) {
      final List<dynamic> decodedList = jsonDecode(transactionsString);
      _transactions = decodedList
          .map((item) => Transaction.fromJson(item))
          .toList();
      notifyListeners();
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction); // Add to beginning of list
    notifyListeners();
    _saveTransactions();
  }

  double get totalIncome {
    return _transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalSavings => totalIncome - totalExpense;

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(
      _transactions.map((t) => t.toJson()).toList(),
    );
    await prefs.setString('transactions', encodedList);
    FirestoreService.uploadData('transactions', encodedList);
  }
}
