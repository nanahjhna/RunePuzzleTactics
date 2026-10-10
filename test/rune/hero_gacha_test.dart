/// 영웅 랜덤 영입(뽑기) 엔진 테스트 (RPT-306 개편)
///
/// **등급은 ★ 1단계(R)만 존재한다.** 2~5성급이 제거됐으므로:
/// - 모든 영웅의 초기 등급이 R 이고
/// - `next == this` (승급 없음) 이며
/// - `availableRarities` 는 스테이지와 무관하게 `[HeroRarity.r]` 이다.
///
/// ★ 2성 이상을 되살리면 아래 "사다리" 테스트들을 등급 수에 맞춰 늘리면 된다.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

void main() {
  group('HeroRarity (★ 1단계)', () {
    test('영입 순서가 초기 등급을 결정 (사다리가 1칸이면 전부 R)', () {
      for (var order = 1; order <= 4; order++) {
        expect(HeroRarity.forRecruitOrder(order), HeroRarity.r);
      }
      // 범위 밖 보정도 살아 있다.
      expect(HeroRarity.forRecruitOrder(0), HeroRarity.r);
      expect(HeroRarity.forRecruitOrder(99), HeroRarity.r);
    });

    test('UI 별 표기는 ★ 1개', () {
      expect(HeroRarity.r.stars, '★');
    });

    test('사다리: next 는 자기 자신(승급 없음), 전부 최고 등급', () {
      expect(HeroRarity.r.next, HeroRarity.r);
      expect(HeroRarity.r.isMax, isTrue);
    });

    test('RuneHeroDef.rarity == forRecruitOrder(recruitOrder)', () {
      for (final h in HeroPool.heroes) {
        expect(h.rarity, HeroRarity.forRecruitOrder(h.recruitOrder));
        expect(h.rarity, HeroRarity.r);
      }
    });

    test('해금 스테이지는 [1] (전 영웅 시작부터 해금)', () {
      final byStage = HeroPool.heroes.map((h) => h.unlockStage).toSet().toList()
        ..sort();
      expect(byStage, [1]);
    });
  });

  group('HeroGacha 풀 (해금 게이트)', () {
    test('풀은 5명 전원 (스테이지와 무관)', () {
      for (final stage in [1, 2, 3, 5, 8]) {
        expect(HeroGacha.poolFor(stage).length, 5);
      }
    });

    test('풀에 미해금 영웅은 없다', () {
      final pool = HeroGacha.poolFor(1);
      expect(pool.any((h) => h.recruitOrder > 1), isFalse);
      expect(pool.every((h) => h.unlockStage <= 1 || h.isStarter), isTrue);
    });

    test('가용 등급은 사다리 순 (사다리 1칸 → 전 스테이지 [R])', () {
      for (final stage in [1, 3, 5, 8]) {
        expect(HeroGacha.availableRarities(stage), [HeroRarity.r]);
      }
    });
  });

  group('HeroGacha 확률', () {
    test('정규화된 확률 합 = 1.0', () {
      for (final stage in [1, 3, 5, 8]) {
        final table = HeroGacha.rateTable(stage);
        expect(table.length, HeroGacha.availableRarities(stage).length);
        expect(table.fold<double>(0, (s, e) => s + e.rate), closeTo(1.0, 1e-9));
      }
    });

    test('★ 1단계뿐이라 정규화 전 합계는 50 (화면에는 100%로 보인다)', () {
      // ★ 2성 이상을 추가하면 100이 되도록 값을 맞춰야 한다.
      expect(HeroGacha.rates.values.reduce((a, b) => a + b), 50);
      expect(HeroGacha.rateTable(1).single.percent, 50);
      expect(HeroGacha.rateTable(1).single.rate, 1.0);
    });

    test('전 스테이지 R 100%', () {
      for (final stage in [1, 3, 5, 8]) {
        final table = HeroGacha.rateTable(stage);
        expect(table.single.rarity, HeroRarity.r);
        expect(table.single.rate, 1.0);
      }
    });

    test('시드 고정 시 추첨 결과 재현 가능', () {
      final a = HeroGacha.draw(nextStage: 8, rng: Random(42));
      final b = HeroGacha.draw(nextStage: 8, rng: Random(42));
      expect(a?.heroId, b?.heroId);
    });

    test('추첨 결과는 항상 풀 안의 영웅', () {
      for (var seed = 0; seed < 200; seed++) {
        final h = HeroGacha.draw(nextStage: 4, rng: Random(seed));
        expect(h, isNotNull);
        expect(HeroGacha.poolFor(4).map((e) => e.heroId), contains(h!.heroId));
      }
    });

    test('분포: 전 스테이지 R 100%', () {
      for (final stage in [1, 8]) {
        final counts = <HeroRarity, int>{for (final r in HeroRarity.values) r: 0};
        for (var seed = 0; seed < 300; seed++) {
          final h = HeroGacha.draw(nextStage: stage, rng: Random(seed))!;
          counts[h.rarity] = counts[h.rarity]! + 1;
        }
        expect(counts[HeroRarity.r], 300);
      }
    });

    test('풀 크기가 커지면 분산된다 (확률축은 사라져도 등급 내 균등선택은 유지)', () {
      final ids = <String>{};
      for (var seed = 0; seed < 400; seed++) {
        ids.add(HeroGacha.draw(nextStage: 8, rng: Random(seed))!.heroId);
      }
      expect(ids.length, greaterThan(1));
    });

    test('비용: 1연 ⭐10 / 10연 ⭐90', () {
      expect(HeroGacha.singleCost, 10);
      expect(HeroGacha.tenCost, 90);
      expect(HeroGacha.tenCount, 10);
      expect(
        HeroGacha.tenCost,
        lessThan(HeroGacha.singleCost * HeroGacha.tenCount),
      );
    });
  });
}
