/// 데미지 계산 결정성 테스트.
///
/// 몬스터는 무속성이지만 상성은 **스테이지**가 정한다
/// ([StageConfig.affinityFor]). 시너지 배율표는 삭제됐고, 그 자리에
/// "그 색 살아있는 영웅의 공격력 합"이 들어간다
/// ([BattleState.attackForElement]).
///
/// ```
/// 매칭 데미지 = (매칭 속성의 살아있는 영웅 ATK 합) × combo × 상성
/// 스킬 데미지 = (시전 영웅 개인 ATK)             × ratio × 상성
/// 반격 데미지 = max(1, round(몬스터ATK × 100 / (100 + 대상DEF)))
/// ```
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DamageCalculator.comboMultiplier', () {
    test('1.0 + 0.20 × (combo - 1), 최소 1.0', () {
      expect(DamageCalculator.comboMultiplier(1), 1.0);
      expect(DamageCalculator.comboMultiplier(2), closeTo(1.2, 1e-9));
      expect(DamageCalculator.comboMultiplier(3), closeTo(1.4, 1e-9));
      expect(DamageCalculator.comboMultiplier(6), closeTo(2.0, 1e-9));
    });

    test('0 이나 음수 콤보는 정의상 불가능 — 방어적으로 1.0', () {
      expect(DamageCalculator.comboMultiplier(0), 1.0);
      expect(DamageCalculator.comboMultiplier(-3), 1.0);
    });
  });

  group('StageConfig.affinityFor', () {
    const stage = StageConfig(
      stageNumber: 1,
      type: StageType.normal,
      monsterHp: 100,
      monsterAttack: 10,
      weakElement: RuneElement.fire,
      resistElement: RuneElement.water,
      bossCountdown: 0,
      goldReward: 0,
    );

    test('약점 1.5 / 그 외 1.0 / 열세 0.5', () {
      expect(stage.affinityFor(RuneElement.fire), 1.5);
      expect(stage.affinityFor(RuneElement.grass), 1.0);
      expect(stage.affinityFor(RuneElement.light), 1.0);
      expect(stage.affinityFor(RuneElement.poison), 1.0);
      expect(stage.affinityFor(RuneElement.water), 0.5);
    });

    test('isWeakAgainst 은 약점 속성만 true', () {
      expect(stage.isWeakAgainst(RuneElement.fire), true);
      expect(stage.isWeakAgainst(RuneElement.water), false);
    });

    test('약점과 열세는 서로 다른 속성 (같은 속성이면 규칙이 충돌한다)', () {
      for (var n = 1; n <= 25; n++) {
        expect(
          StageGenerator.weakElementFor(n),
          isNot(StageGenerator.resistElementFor(n)),
          reason: 'stage $n 에서 약점과 열세가 겹친다',
        );
      }
    });

    test('생성기는 결정론적이다 (같은 스테이지 번호 → 같은 상성)', () {
      for (var n = 1; n <= 30; n++) {
        expect(
          StageGenerator.weakElementFor(n),
          StageGenerator.weakElementFor(n),
        );
        expect(
          StageGenerator.resistElementFor(n),
          StageGenerator.resistElementFor(n),
        );
      }
    });

    test('생성기는 약점을 5스테이지마다 순환시키고 열세는 그 다음 속성', () {
      // 약점: 불 → 풀 → 물 → 빛 → 독
      // 열세: 항상 약점의 바로 다음 속성 (겹치지 않음이 구조적으로 보장된다)
      const expected = [
        (RuneElement.fire, RuneElement.grass),
        (RuneElement.grass, RuneElement.water),
        (RuneElement.water, RuneElement.light),
        (RuneElement.light, RuneElement.poison),
        (RuneElement.poison, RuneElement.fire),
      ];
      for (var i = 0; i < expected.length; i++) {
        final n = i + 1;
        expect(
          StageGenerator.weakElementFor(n),
          expected[i].$1,
          reason: 'stage $n 약점',
        );
        expect(
          StageGenerator.resistElementFor(n),
          expected[i].$2,
          reason: 'stage $n 열세',
        );
      }
    });

    test('StageGenerator 가 만든 StageConfig 가 같은 값을 돌려준다', () {
      final gen = StageGenerator();
      final s = gen.generate(7);
      expect(s.weakElement, StageGenerator.weakElementFor(7));
      expect(s.resistElement, StageGenerator.resistElementFor(7));
      expect(s.affinityFor(s.weakElement), 1.5);
      expect(s.affinityFor(s.resistElement), 0.5);
    });
  });

  group('DamageCalculator.matchDamage', () {
    const calc = DamageCalculator();

    test('ATK 합 × 콤보 × 상성', () {
      expect(
        calc.matchDamage(elementAttackSum: 60, combo: 1, affinity: 1.0),
        60,
      );
      expect(
        calc.matchDamage(elementAttackSum: 60, combo: 2, affinity: 1.0),
        72,
      );
      expect(
        calc.matchDamage(elementAttackSum: 60, combo: 1, affinity: 1.5),
        90,
      );
      expect(
        calc.matchDamage(elementAttackSum: 60, combo: 1, affinity: 0.5),
        30,
      );
      // 60 × 1.4 × 1.5 = 126
      expect(
        calc.matchDamage(elementAttackSum: 60, combo: 3, affinity: 1.5),
        126,
      );
    });

    test('살아있는 영웅이 없으면(합 0) 데미지도 0', () {
      expect(calc.matchDamage(elementAttackSum: 0, combo: 5, affinity: 1.5), 0);
    });

    test('반올림한다', () {
      // 11 × 1.4 × 1.5 = 23.1 → 23
      expect(
        calc.matchDamage(elementAttackSum: 11, combo: 3, affinity: 1.5),
        23,
      );
      // 15 × 1.2 × 1.0 = 18.0 → 18
      expect(
        calc.matchDamage(elementAttackSum: 15, combo: 2, affinity: 1.0),
        18,
      );
    });

    test('음수/NaN 이 들어와도 음수 데미지는 내지 않는다', () {
      expect(
        calc.matchDamage(elementAttackSum: -50, combo: 1, affinity: 1.0),
        0,
      );
      expect(
        calc.matchDamage(elementAttackSum: 0, combo: -1, affinity: 1.0),
        0,
      );
    });
  });

  group('DamageCalculator.incomingDamage', () {
    const calc = DamageCalculator();

    test('감쇄형 방어력: max(1, round(ATK × 100 / (100 + DEF)))', () {
      // ATK 12, DEF 0 → 12
      expect(calc.incomingDamage(attack: 12, defenderDefense: 0).damage, 12);
      // ATK 12, DEF 8 → 12 × 100/108 = 11.11 → 11
      expect(calc.incomingDamage(attack: 12, defenderDefense: 8).damage, 11);
      // ATK 12, DEF 18 → 12 × 100/118 = 10.17 → 10
      expect(calc.incomingDamage(attack: 12, defenderDefense: 18).damage, 10);
      // ATK 100, DEF 100 → 50 (완전 반감)
      expect(calc.incomingDamage(attack: 100, defenderDefense: 100).damage, 50);
    });

    test('DEF 가 높을수록 단조 감소한다', () {
      var prev = 1 << 30;
      for (var def = 0; def <= 60; def += 5) {
        final dmg = calc
            .incomingDamage(attack: 30, defenderDefense: def)
            .damage;
        expect(dmg, lessThanOrEqualTo(prev), reason: 'DEF $def');
        prev = dmg;
      }
    });

    test('최소 1 — 반격을 맞았는데 아무도 안 다치는 일은 없다', () {
      expect(calc.incomingDamage(attack: 5, defenderDefense: 500).damage, 1);
      expect(calc.incomingDamage(attack: 0, defenderDefense: 0).damage, 1);
    });

    test('내역(공격력/방어력)이 결과 화면 공식 캡션에 쓰인다', () {
      final r = calc.incomingDamage(attack: 12, defenderDefense: 8);
      expect(r.attack, 12);
      expect(r.defense, 8);
      expect(r.damage, 11);
      expect(r.remainingRatio, closeTo(100 / 108, 1e-9));
    });

    test('incomingDamageValue 는 breakdown 의 damage 와 같다', () {
      expect(
        calc.incomingDamageValue(attack: 20, defenderDefense: 5),
        calc.incomingDamage(attack: 20, defenderDefense: 5).damage,
      );
    });
  });

  group('BattleState.attackForElement', () {
    test('매칭한 색의 살아있는 영웅 ATK 합만 더한다', () {
      final state = _stateFor(['fire_a', 'water_a']);

      // fire_a 15
      expect(state.attackForElement(RuneElement.fire), 15);
      // 파티에 없는 색 → 0 → 그 색 매칭은 데미지 0
      expect(state.attackForElement(RuneElement.grass), 0);
    });

    test('쓰러진 영웅의 공격력은 빠진다', () {
      final state = _stateFor(['fire_a', 'water_a']);
      expect(state.attackForElement(RuneElement.fire), 15);
      expect(state.attackForElement(RuneElement.water), 13);

      // fire_a(ATK 15) 쓰러뜨리기
      state.units.firstWhere((u) => u.heroId == 'fire_a').hp = 0;
      expect(state.attackForElement(RuneElement.fire), 0);
      // 다른 색 공격력에는 영향이 없다.
      expect(state.attackForElement(RuneElement.water), 13);
    });

    test('다른 색 영웅의 공격력은 그 색 매칭에 전혀 반영되지 않는다', () {
      final state = _stateFor(['fire_a', 'water_a']);
      expect(state.attackForElement(RuneElement.fire), 15); // fire_a
      expect(state.attackForElement(RuneElement.water), 13); // water_a
      expect(state.livingAttack, 28); // 전체 합은 별개 축
    });
  });

}

StageConfig _testStage() => const StageConfig(
  stageNumber: 1,
  type: StageType.normal,
  monsterHp: 100,
  monsterAttack: 10,
  weakElement: RuneElement.fire,
  resistElement: RuneElement.water,
  bossCountdown: 0,
  goldReward: 0,
);

/// [ids] 의 영웅을 모두 보유 + 편성하고, **정본 개인 스탯**을 주입한 BattleState.
///
/// 폴백 경로(합산값 균등 분배)를 쓰면 공격력이 인원수로만 결정되어 버려서
/// `attackForElement` 를 검증할 수 없다. 실제 전투 진입과 같은 경로를 쓴다.
BattleState _stateFor(List<String> ids) {
  final roster = HeroRoster.fromIds(ids, ownedIds: ids);
  return BattleState(
    stage: _testStage(),
    party: roster,
    board: PuzzleBoard(),
    partyMaxHp: 100,
    baseAttack: 0,
    heroStats: [
      for (final h in roster.partyHeroes)
        HeroCombatStats(
          heroId: h.heroId,
          element: h.element,
          hp: h.hp,
          attack: h.attack,
          defense: h.defense,
        ),
    ],
  );
}
