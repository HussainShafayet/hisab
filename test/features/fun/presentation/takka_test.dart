import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';
import 'package:hishab/features/fun/presentation/widgets/takka.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('draws every mood without a problem', (tester) async {
    for (final mood in TakkaMood.values) {
      await tester.pumpWidget(host(Takka(mood: mood, size: 80)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: mood.name);
      expect(tester.getSize(find.byType(Takka)), const Size(80, 80));
    }
  });

  testWidgets('has a name for a screen reader', (tester) async {
    await tester.pumpWidget(host(const Takka()));

    expect(find.bySemanticsLabel('Takka the coin'), findsOneWidget);
  });

  testWidgets('hops when it shows, then stands still', (tester) async {
    await tester.pumpWidget(host(const Takka()));
    await tester.pump(const Duration(milliseconds: 150));
    final moving = tester.getTopLeft(find.byType(CustomPaint).last);
    await tester.pumpAndSettle();
    final still = tester.getTopLeft(find.byType(CustomPaint).last);

    // It was off the ground while hopping; at the end it is back, and
    // pumpAndSettle came back, so nothing keeps animating.
    expect(moving.dy, lessThan(still.dy));
  });

  testWidgets('stands still at once when animations are off', (tester) async {
    await tester.pumpWidget(host(const Takka(), disableAnimations: true));
    final first = tester.getTopLeft(find.byType(CustomPaint).last);
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getTopLeft(find.byType(CustomPaint).last), first);
  });

  testWidgets('tells when it is tapped, and hops again', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(Takka(onTap: () => taps++)));
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(find.byType(CustomPaint).last);

    await tester.tap(find.byType(Takka));
    // The first frame only starts the clock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    expect(taps, 1);
    expect(
      tester.getTopLeft(find.byType(CustomPaint).last).dy,
      lessThan(rest.dy),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('is not a button without onTap', (tester) async {
    await tester.pumpWidget(host(const Takka()));

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Takka the coin'),
    );
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
  });

  testWidgets('hops when its mood changes', (tester) async {
    await tester.pumpWidget(host(const Takka()));
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(find.byType(CustomPaint).last);

    await tester.pumpWidget(host(const Takka(mood: TakkaMood.worried)));
    await tester.pump(const Duration(milliseconds: 110));

    expect(
      tester.getTopLeft(find.byType(CustomPaint).last).dy,
      lessThan(rest.dy),
    );
    await tester.pumpAndSettle();
  });
}
