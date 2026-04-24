import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'utils/app_settings.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/add_income_screen.dart';
import 'screens/add_investment_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/restore_screen.dart';
import 'screens/settings_screen.dart';
import 'models/investment_holding.dart';
import 'models/transaction.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(InvestmentHoldingAdapter());
  await Hive.openBox<Transaction>('transactions');
  await Hive.openBox<InvestmentHolding>('investments');
  await Hive.openBox('settings');
  AppSettings.getInstallDate();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance Management App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1124),
        primaryColor: const Color(0xFF5D6CFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0F1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0C0F1E),
          selectedItemColor: Color(0xFF5D6CFF),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const MainScreen(),
        '/add-expense': (context) => const AddExpenseScreen(),
        '/add-income': (context) => const AddIncomeScreen(),
        '/add-investment': (context) => const AddInvestmentScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/backup': (context) => const BackupScreen(),
        '/restore': (context) => const RestoreScreen(),
      },
    );
  }
}
