import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/icon_mapper.dart';

import '../services/firestore_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _incomeCategories = [];

  CategoryProvider() {
    _loadCategories();
  }

  Future<void> refresh() async {
    await _loadCategories();
  }

  List<Map<String, dynamic>> get expenseCategories => _expenseCategories;
  List<Map<String, dynamic>> get incomeCategories => _incomeCategories;

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final expStr = prefs.getString('expense_categories');
    final incStr = prefs.getString('income_categories');

    if (expStr != null) {
      _expenseCategories = _decodeCategories(expStr);
    } else {
      _expenseCategories = [
        {'name': 'Travelling', 'icon': Icons.directions_car},
        {'name': 'Food', 'icon': Icons.restaurant},
        {'name': 'Subs', 'icon': Icons.subscriptions},
        {'name': 'Health', 'icon': Icons.medical_services},
      ];
    }

    if (incStr != null) {
      _incomeCategories = _decodeCategories(incStr);
    } else {
      _incomeCategories = [
        {'name': 'Salary', 'icon': Icons.work},
        {'name': 'Invest', 'icon': Icons.account_balance},
        {'name': 'Bonus', 'icon': Icons.redeem},
        {'name': 'Gift', 'icon': Icons.card_giftcard},
      ];
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> _decodeCategories(String encoded) {
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.map((item) {
      return {
        'name': item['name'],
        'icon': IconMapper.getIcon(item['iconCode']),
      };
    }).toList();
  }

  Future<void> addCategory(String name, bool isExpense, IconData icon) async {
    // Prevent duplicates
    final list = isExpense ? _expenseCategories : _incomeCategories;
    if (list.any((c) => c['name'].toLowerCase() == name.toLowerCase())) {
      return;
    }

    final newCategory = {'name': name, 'icon': icon};

    if (isExpense) {
      _expenseCategories.add(newCategory);
    } else {
      _incomeCategories.add(newCategory);
    }

    notifyListeners();
    await _saveCategories();
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final expEncoded = jsonEncode(
      _expenseCategories
          .map(
            (c) => {
              'name': c['name'],
              'iconCode': (c['icon'] as IconData).codePoint,
            },
          )
          .toList(),
    );

    final incEncoded = jsonEncode(
      _incomeCategories
          .map(
            (c) => {
              'name': c['name'],
              'iconCode': (c['icon'] as IconData).codePoint,
            },
          )
          .toList(),
    );

    await prefs.setString('expense_categories', expEncoded);
    await prefs.setString('income_categories', incEncoded);
    
    FirestoreService.uploadData('expense_categories', expEncoded);
    FirestoreService.uploadData('income_categories', incEncoded);
  }
}
