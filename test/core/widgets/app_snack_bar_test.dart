import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';

/// A screen with buttons that show the snack bars.
Widget host({required VoidCallback Function(ScaffoldMessengerState) onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onTap(ScaffoldMessenger.of(context))(),
            child: const Text('Go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a message goes away by itself', (tester) async {
    await tester.pumpWidget(
      host(
        onTap: (m) =>
            () => m.showMessage('Saved'),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(messageDuration);
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a message with Undo also goes away by itself', (tester) async {
    await tester.pumpWidget(
      host(
        onTap: (m) =>
            () => m.showMessage(
              'Deleted',
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
            ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(messageDuration);
    await tester.pumpAndSettle();

    expect(find.text('Deleted'), findsNothing);
  });

  testWidgets('a message has a close button that closes it', (tester) async {
    await tester.pumpWidget(
      host(
        onTap: (m) =>
            () => m.showMessage('Saved'),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('an error has a warning icon and stays longer', (tester) async {
    await tester.pumpWidget(
      host(
        onTap: (m) =>
            () => m.showError('It broke'),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('It broke'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.pump(messageDuration + const Duration(seconds: 1));
    expect(find.text('It broke'), findsOneWidget);

    await tester.pump(errorDuration);
    await tester.pumpAndSettle();
    expect(find.text('It broke'), findsNothing);
  });

  testWidgets('a new message replaces the one on screen', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      host(
        onTap: (m) =>
            () => m.showMessage('Message ${++count}'),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Message 1'), findsNothing);
    expect(find.text('Message 2'), findsOneWidget);
  });
}
