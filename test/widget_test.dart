import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:finance_management_app/main.dart';
import 'package:finance_management_app/models/transaction.dart';

void main() {
  setUpAll(() async {
    final directory = await Directory.systemTemp.createTemp('finance_management_app_test');
    Hive.init(directory.path);
    Hive.registerAdapter(TransactionAdapter());
    await Hive.openBox<Transaction>('transactions');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('app shows splash screen before navigating to main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Finance Management App'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
