import 'package:flutter/material.dart';

class Transaction {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final int iconCode; // Store icon code point

  Transaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.iconCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'isExpense': isExpense,
      'iconCode': iconCode,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      category: json['category'] ?? json['title'], // Fallback for old data
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      isExpense: json['isExpense'],
      iconCode: json['iconCode'],
    );
  }

  // Static map to prevent tree-shaking errors during build
  static final Map<int, IconData> _iconMap = {
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.subscriptions.codePoint: Icons.subscriptions,
    Icons.medical_services.codePoint: Icons.medical_services,
    Icons.work.codePoint: Icons.work,
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.redeem.codePoint: Icons.redeem,
    Icons.category.codePoint: Icons.category,
    Icons.help_outline.codePoint: Icons.help_outline,
  };

  IconData get icon => _iconMap[iconCode] ?? Icons.category;
}
