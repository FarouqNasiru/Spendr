import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spendr/core/theme/theme_provider.dart';
import 'package:spendr/core/providers/currency_provider.dart';
import 'package:spendr/core/providers/transaction_provider.dart';
import 'package:spendr/screens/intro_screen.dart';
import 'package:flutter/services.dart';
import 'package:spendr/core/services/notification_service.dart';
import 'package:spendr/core/services/smart_reminder_service.dart';
import 'package:spendr/core/services/ad_service.dart';
import 'package:spendr/core/services/iap_service.dart';
import 'package:spendr/core/providers/category_provider.dart';
import 'package:spendr/core/providers/category_mapping_provider.dart';
import 'package:spendr/core/providers/auth_provider.dart';
import 'package:spendr/core/providers/premium_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spendr/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize notifications and wait for timezone config
  await NotificationService().init();
  SmartReminderService().init();
  
  // Initialize AdMob and In-App Purchases
  await AdService().init();
  await IAPService().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => CategoryMappingProvider()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spendr',
      theme: themeProvider.themeData,
      home: const IntroScreen(),
    );
  }
}
