import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/widgets/confetti.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

String shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('amount'))).data!;

void main() {
  group('AnimatedAmount', () {
    testWidgets('counts up to the amount when it first shows', (tester) async {
      await tester.pumpWidget(
        host(const AnimatedAmount(poisha: 120000, textKey: ValueKey('amount'))),
      );
      expect(shown(tester), '৳0.00');

      await tester.pump(const Duration(milliseconds: 300));
      final middle = shown(tester);
      expect(middle, isNot('৳0.00'));
      expect(middle, isNot('৳1,200.00'));

      await tester.pumpAndSettle();
      expect(shown(tester), '৳1,200.00');
    });

    testWidgets('goes from the old amount to the new one', (tester) async {
      await tester.pumpWidget(
        host(const AnimatedAmount(poisha: 100000, textKey: ValueKey('amount'))),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(const AnimatedAmount(poisha: 150000, textKey: ValueKey('amount'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final middle = shown(tester);
      expect(middle, isNot('৳1,000.00'));
      expect(middle, isNot('৳1,500.00'));

      await tester.pumpAndSettle();
      expect(shown(tester), '৳1,500.00');
    });

    testWidgets('shows a negative amount', (tester) async {
      await tester.pumpWidget(
        host(const AnimatedAmount(poisha: -25000, textKey: ValueKey('amount'))),
      );
      await tester.pumpAndSettle();

      expect(shown(tester), '-৳250.00');
    });

    testWidgets('shows the amount at once when animations are off', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AnimatedAmount(poisha: 120000, textKey: ValueKey('amount')),
          disableAnimations: true,
        ),
      );

      expect(shown(tester), '৳1,200.00');
    });
  });

  group('AnimatedFraction', () {
    Widget bar(double value, {bool off = false}) => host(
      AnimatedFraction(
        value: value,
        builder: (context, v) => Text('$v', key: const ValueKey('v')),
      ),
      disableAnimations: off,
    );
    String value(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('v'))).data!;

    testWidgets('fills up from nothing', (tester) async {
      await tester.pumpWidget(bar(0.8));
      expect(double.parse(value(tester)), 0);

      await tester.pumpAndSettle();
      expect(double.parse(value(tester)), closeTo(0.8, 1e-9));
    });

    testWidgets('is full at once when animations are off', (tester) async {
      await tester.pumpWidget(bar(0.8, off: true));

      expect(double.parse(value(tester)), 0.8);
    });
  });

  group('FadeSlideIn', () {
    Widget card(int index, {bool off = false}) => host(
      FadeSlideIn(index: index, child: const Text('card')),
      disableAnimations: off,
    );
    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('fades in and ends fully shown', (tester) async {
      await tester.pumpWidget(card(0));
      expect(opacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester), inInclusiveRange(0.01, 0.99));

      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(find.text('card'), findsOneWidget);
    });

    testWidgets('a later card starts a little later', (tester) async {
      await tester.pumpWidget(card(5));
      await tester.pump(const Duration(milliseconds: 100));

      expect(opacity(tester), 0);
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('is there at once when animations are off', (tester) async {
      await tester.pumpWidget(card(3, off: true));

      expect(opacity(tester), 1);
    });
  });

  group('Fun mode', () {
    Widget app(Widget child, {required bool fun}) => ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(AppPreferences(funMode: fun)),
      ],
      child: host(child),
    );
    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('on: a card still arrives and an amount still counts up', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              FadeSlideIn(child: Text('card')),
              AnimatedAmount(poisha: 120000, textKey: ValueKey('amount')),
            ],
          ),
          fun: true,
        ),
      );

      expect(opacity(tester), 0);
      expect(shown(tester), '৳0.00');
      await tester.pumpAndSettle();
    });

    testWidgets('off: the card is there and the amount shown at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              FadeSlideIn(child: Text('card')),
              AnimatedAmount(poisha: 120000, textKey: ValueKey('amount')),
            ],
          ),
          fun: false,
        ),
      );

      expect(opacity(tester), 1);
      expect(shown(tester), '৳1,200.00');
    });
  });

  group('arriving', () {
    testWidgets('animates the first cards and leaves the rest plain', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              for (var i = 0; i < arrivingCount + 2; i++)
                arriving(i, Text('card $i')),
            ],
          ),
        ),
      );

      expect(find.byType(FadeSlideIn), findsNWidgets(arrivingCount));
      expect(find.text('card ${arrivingCount + 1}'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('showConfetti', () {
    Widget button({bool off = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: off),
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showConfetti(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    Finder confetti() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString().contains('Confetti'),
    );

    testWidgets('falls over the screen, then takes itself away', (
      tester,
    ) async {
      await tester.pumpWidget(button());
      expect(confetti(), findsNothing);

      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(confetti(), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(confetti(), findsNothing);
    });

    testWidgets('does not block taps underneath', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showConfetti(context),
                    child: const Text('go'),
                  ),
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('under'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('under'));

      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('does nothing when animations are off', (tester) async {
      await tester.pumpWidget(button(off: true));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(confetti(), findsNothing);
    });
  });
}
