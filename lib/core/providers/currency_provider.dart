import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';

class CurrencyProvider extends ChangeNotifier {
  String _selectedCurrency = 'USD (\$)';
  String _currencySymbol = '\$';

  String get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _currencySymbol;

  CurrencyProvider() {
    _loadCurrency();
  }

  Future<void> refresh() async {
    await _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedCurrency = prefs.getString('currency') ?? 'USD (\$)';
    _updateSymbol();
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    FirestoreService.uploadData('currency', currency);
    _selectedCurrency = currency;
    _updateSymbol();
    notifyListeners();
  }

  void _updateSymbol() {
    // Extract symbol from "USD ($)", "EUR (€)", etc.
    final RegExp regex = RegExp(r'\((.*?)\)');
    final Match? match = regex.firstMatch(_selectedCurrency);
    if (match != null && match.groupCount >= 1) {
      _currencySymbol = match.group(1) ?? '\$';
    } else {
      _currencySymbol = '\$';
    }
  }
}
