import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game29/engine/bot.dart';
import 'package:game29/net/session.dart';
import 'package:game29/ui/session_screen.dart';
import 'package:game29/ui/theme.dart';

void main() {
  for (final size in const [Size(412, 860), Size(360, 740)]) {
    testWidgets('offline table at ${size.width.toInt()}dp shows my four cards and bid controls', (tester) async {
      await _offlineTable(tester, size);
    });
  }
}

Future<void> _offlineTable(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final session = TableSession.offline(name: 'Asha', playerId: 'me', level: BotLevel.normal);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: SessionScreen(session: session),
    ),
  );

  // Let the in-process server welcome us, seat bots and deal.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(find.text('Us 0'), findsOneWidget);
  expect(find.bySemanticsLabel(RegExp(r'^card ')), findsNWidgets(4));

  // Play bots until it is my turn to bid, then make sure bid buttons are offered.
  for (var i = 0; i < 20 && session.view?.myTurn != true; i++) {
    await tester.pump(const Duration(milliseconds: 800));
  }
  expect(session.view!.myTurn, isTrue);
  expect(find.text('16').evaluate().isNotEmpty || find.text('Pass').evaluate().isNotEmpty, isTrue);

  // Leave so timers are cancelled before the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}
