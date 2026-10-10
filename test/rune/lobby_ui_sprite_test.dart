import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_lobby_tab.dart';
import 'package:rune_puzzle_tactics/widgets/ui_pill.dart';

void main() {
  testWidgets('lobby currency and daily reward chips use pill sprites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(
          persist: false,
          initialLanguage: AppLanguage.ko,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: RuneLobbyTab(
              progress: RuneProgress(
                gameCurrency: 500,
                playCurrency: 5,
                heroOwned: {HeroPool.starter.heroId},
                heroParty: [HeroPool.starter.heroId],
              ),
              onStartBattle: (_) {},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in ['⚡ 500', '🎟 5', '⭐ 0']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(UiPill)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-reward-chip')),
        matching: find.byType(UiPill),
      ),
      findsOneWidget,
    );
  });
}
