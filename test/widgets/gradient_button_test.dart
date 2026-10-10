import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/widgets/gradient_button.dart';

void main() {
  testWidgets('sprite button remains fully tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: GradientButton(
                key: const ValueKey('sprite-button'),
                onPressed: () => taps++,
                label: 'Continue',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('sprite-button'))).height,
      52,
    );
    await tester.tap(find.byKey(const ValueKey('sprite-button')));
    expect(taps, 1);
  });
}
