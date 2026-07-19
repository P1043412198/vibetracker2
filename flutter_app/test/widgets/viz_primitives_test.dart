import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibesight_tracker/widgets/viz/viz.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  test('heatColor stays on the base tone for (near-)zero intensity', () {
    const base = Color(0xFF222222);
    expect(heatColor(0, base), base);
    expect(heatColor(0.01, base), base);
    // Non-trivial intensity leaves the base tone.
    expect(heatColor(0.6, base) == base, isFalse);
  });

  test('vizStatusColor maps ratio to green/amber/red', () {
    expect(vizStatusColor(0.5), vizGood);
    expect(vizStatusColor(0.9), vizWarn);
    expect(vizStatusColor(1.2), vizBad);
  });

  testWidgets('StatusHero renders value, caption and trend', (tester) async {
    await tester.pumpWidget(_host(const StatusHero(
      value: '1 200 кг',
      caption: 'Тоннаж за неделю',
      delta: 18,
      deltaSuffix: '%',
      spark: [1, 2, 3, 4],
    )));
    expect(find.text('1 200 кг'), findsOneWidget);
    expect(find.text('Тоннаж за неделю'), findsOneWidget);
    expect(find.textContaining('18'), findsOneWidget);
  });

  testWidgets('HeatCalendar builds for a sparse year of values',
      (tester) async {
    final now = DateTime(2025, 6, 1);
    await tester.pumpWidget(_host(SizedBox(
      width: 360,
      child: HeatCalendar(
        endDate: now,
        values: {
          DateTime(2025, 5, 20): 100,
          DateTime(2025, 5, 27): 50,
        },
      ),
    )));
    expect(find.byType(HeatCalendar), findsOneWidget);
  });

  testWidgets('SplitBar shows a legend entry per non-zero segment',
      (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 300,
      child: SplitBar(segments: [
        SplitSegment(label: 'A', value: 3, color: Colors.red),
        SplitSegment(label: 'B', value: 1, color: Colors.blue),
        SplitSegment(label: 'C', value: 0, color: Colors.green),
      ]),
    )));
    // 3 + 1 = 4 total → A 75%, B 25%; zero-value C is dropped.
    expect(find.textContaining('A · 75%'), findsOneWidget);
    expect(find.textContaining('B · 25%'), findsOneWidget);
    expect(find.textContaining('C'), findsNothing);
  });

  testWidgets('RadialGauge shows a default percentage label', (tester) async {
    await tester.pumpWidget(_host(const RadialGauge(
      progress: 0.42,
      label: 'Цель',
    )));
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Цель'), findsOneWidget);
  });
}
