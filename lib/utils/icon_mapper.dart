import 'package:flutter/material.dart';

class IconMapper {
  static final Map<int, IconData> _iconMap = {
    Icons.shopping_bag.codePoint: Icons.shopping_bag,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.home.codePoint: Icons.home,
    Icons.movie.codePoint: Icons.movie,
    Icons.medical_services.codePoint: Icons.medical_services,
    Icons.school.codePoint: Icons.school,
    Icons.flight.codePoint: Icons.flight,
    Icons.pets.codePoint: Icons.pets,
    Icons.sports_esports.codePoint: Icons.sports_esports,
    Icons.work.codePoint: Icons.work,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.savings.codePoint: Icons.savings,
    Icons.card_giftcard.codePoint: Icons.card_giftcard,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.coffee.codePoint: Icons.coffee,
    Icons.build.codePoint: Icons.build,
    Icons.local_taxi.codePoint: Icons.local_taxi,
    Icons.phone_iphone.codePoint: Icons.phone_iphone,
    Icons.wifi.codePoint: Icons.wifi,
    Icons.subscriptions.codePoint: Icons.subscriptions,
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.redeem.codePoint: Icons.redeem,
    Icons.fastfood.codePoint: Icons.fastfood,
    Icons.local_grocery_store.codePoint: Icons.local_grocery_store,
    Icons.train.codePoint: Icons.train,
    Icons.receipt_long.codePoint: Icons.receipt_long,
    Icons.local_atm.codePoint: Icons.local_atm,
    Icons.category.codePoint: Icons.category,
    Icons.category_outlined.codePoint: Icons.category_outlined,
    Icons.help_outline.codePoint: Icons.help_outline,
    Icons.delete_outline.codePoint: Icons.delete_outline,
  };

  static IconData getIcon(int codePoint) {
    if (_iconMap.containsKey(codePoint)) {
      return _iconMap[codePoint]!;
    }
    // Fallback if the saved icon is not in our statically defined map
    return Icons.category_outlined;
  }
}
