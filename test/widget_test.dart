// Basic smoke test for FinFlow.

import 'package:finflow/main.dart';
import 'package:finflow/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru', null);
  });

  testWidgets('App launches and shows welcome screen on first run',
      (WidgetTester tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(FinFlowApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Начать путь'), findsOneWidget);
  });

  testWidgets('Welcome screen advances onboarding into main shell',
      (WidgetTester tester) async {
    final state = AppState();
    await state.load();
    await tester.pumpWidget(FinFlowApp(state: state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Анна');
    await tester.tap(find.text('Начать путь'));
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Бюджет'), findsOneWidget);
    expect(state.userName, 'Анна');
  });
}
