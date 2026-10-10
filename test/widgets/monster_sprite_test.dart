import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/widgets/monster_sprite.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('MonsterSprite 상태 전환 테스트', (tester) async {
    final battle = BattleEngine.create(
      stage: StageGenerator().generate(1),
      roster: HeroRoster.initial(),
    );
    final hud = ValueNotifier<int>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: MonsterSprite(battle: battle, hud: hud),
      ),
    );

    // 1. 초기 상태 확인
    expect(find.byKey(const ValueKey('monster_sprite_idle')), findsOneWidget);

    // 2. 몬스터 턴으로 전환 (Attack 상태가 되어야 함)
    battle.state.phase = BattlePhase.monsterTurn;
    hud.value++;
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('monster_sprite_attack')), findsOneWidget);

    // 3. 다시 플레이어 턴으로 전환 (Idle 상태가 되어야 함)
    battle.state.phase = BattlePhase.plan;
    hud.value++;
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('monster_sprite_idle')), findsOneWidget);
  });
}
