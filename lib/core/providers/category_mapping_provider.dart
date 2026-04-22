import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';

class CategoryMappingProvider extends ChangeNotifier {
  Map<String, String> _mappings = {};

  CategoryMappingProvider() {
    _loadMappings();
  }

  Map<String, String> get mappings => _mappings;

  Future<void> refresh() async {
    await _loadMappings();
  }

  Future<void> _loadMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mappingsString = prefs.getString('category_mappings');
    if (mappingsString != null) {
      _mappings = Map<String, String>.from(jsonDecode(mappingsString));
      notifyListeners();
    }
  }

  Future<void> saveMapping(String description, String category) async {
    _mappings[description] = category;
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_mappings);
    await prefs.setString('category_mappings', encoded);
    FirestoreService.uploadData('category_mappings', encoded);
  }

  String? getCategoryFor(String description) {
    return _mappings[description];
  }
}
