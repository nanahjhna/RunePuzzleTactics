/// Rune Puzzle Tactics — 영웅 랜덤 영입(뽑기) 규칙
///
/// 상점의 "직접 영입 리스트"를 랜덤 뽑기로 대체한다.
///
/// 규칙:
/// - 재화(Hero Currency ⭐) 1회 차감 → 1~10장 추첨.
/// - 등장 확률은 **등급별** 가중 (rates). 등급 = [HeroRarity] 사다리.
///   현재는 ★ 1단계만 있어 어떤 스테이지든 확률이 100%로 정규화된다.
/// - 가용 풀은 `unlockStage <= nextStage` 인 영웅뿐이다. `HeroPool.unlockStages`
///   가 [1] 이라 시작부터 전원이 풀에 들어온다. 2성 이상을 추가하면 풀이
///   "하위 등급부터 접두 구간"이 되고, 확률은 **가용 등급에 정규화**한다.
/// - 중복은 보유에 쌓이지 않고 그 영웅의 **기존 카드 레벨업**으로 소진된다
///   (기본 +1 레벨, 만렙이면 무효 — [RuneProgress.tryPullHeroes]).
library;

import 'dart:math';

import 'hero_pool.dart';
import 'hero_rarity.dart';

/// 1회 추첨 결과의 성격.
enum GachaOutcome {
  /// 미보유 영웅 신규 획득.
  newHero,

  /// 중복 → 최고 등급 영웅이 1등급 승급.
  ///
  /// 등급 사다리가 ★ 1단계뿐인 동안에는 발생하지 않는다 ([HeroRarity.next] 가
  /// 자기 자신을 반환). 2성 이상을 추가하면 다시 쓰인다.
  promoted,

  /// 중복이지만 이미 최고 등급이라 승급 없음.
  maxed,

  /// 중복 → 뽑힌 영웅의 **기존 카드가 레벨업** (기본 +1 레벨).
  ///
  /// 만렙(Lv.30) 영웅은 더 오를 수 없어 [maxed] 로 남는다.
  levelUp,
}

/// 1회 추첨 결과 (결과 팝업이 그대로 소비).
class GachaResult {
  const GachaResult({
    required this.hero,
    required this.outcome,
    required this.gradeBefore,
    required this.gradeAfter,
    this.levelBefore = 0,
    this.levelAfter = 0,
  });

  final RuneHeroDef hero;
  final GachaOutcome outcome;

  /// 승급 전/후 등급 ([GachaOutcome.maxed] 이면 동일).
  final HeroRarity gradeBefore;
  final HeroRarity gradeAfter;

  /// 레벨 변화 ([GachaOutcome.levelUp] 이면 before < after). 그 외엔 동일값.
  final int levelBefore;
  final int levelAfter;
}

/// 뽑기 카탈로그/추첨 엔진.
class HeroGacha {
  HeroGacha._();

  /// 1연 비용 (Hero Currency).
  static const int singleCost = 10;

  /// 10연 비용 (1연 10회분 대비 10% 할인).
  static const int tenCost = 90;

  /// 10연 장수.
  static const int tenCount = 10;

  /// 등급별 등장 가중치(%). 합이 클수록 높은 등급이 어렵다.
  ///
  /// 현재는 ★ 1단계뿐이라 [HeroRarity.r] 하나만 있다(가용 등급 정규화 → 100%).
  /// ★ 2성 이상을 다시 추가할 때 아래에 항목을 이어 붙인다.
  static const Map<HeroRarity, int> rates = {HeroRarity.r: 50};

  /// [nextStage] 기준 가용 풀 ([HeroPool.heroes] 순서 = 속성 → recruitOrder).
  ///
  /// 풀은 비어 있지 않다(스타터가 항상 해금)지만, 안전하게 빈 목록을 반환할 수 있다.
  static List<RuneHeroDef> poolFor(int nextStage) => HeroPool.heroes
      .where((h) => h.recruitCost == 0 || h.unlockStage <= nextStage)
      .toList(growable: false);

  /// 현재 가용 등급 목록 (사다리 순).
  static List<HeroRarity> availableRarities(int nextStage) {
    final pool = poolFor(nextStage);
    return [
      for (final r in HeroRarity.values)
        if (pool.any((h) => h.rarity == r)) r,
    ];
  }

  /// 가용 등급만으로 정규화한 실제 등장 확률.
  ///
  /// - [rate] = 0.0~1.0 정규화 확률 (화면 표기용).
  /// - [percent] = [rates] 원본 가중치(밸런스 기준값, 정규화 전).
  static List<({HeroRarity rarity, int percent, double rate})> rateTable(
    int nextStage,
  ) {
    final available = availableRarities(nextStage);
    final total = available.fold<int>(0, (s, r) => s + rates[r]!);
    return [
      for (final r in available)
        (
          rarity: r,
          percent: rates[r]!,
          rate: total == 0 ? 0.0 : rates[r]! / total,
        ),
    ];
  }

  /// 1회 추첨. 가용 풀이 비면 null.
  ///
  /// RNG 를 주입할 수 있어 테스트 결정성을 보장한다 ([PuzzleEngine] 와 동일 패턴).
  static RuneHeroDef? draw({required int nextStage, Random? rng}) {
    final pool = poolFor(nextStage);
    if (pool.isEmpty) return null;
    final random = rng ?? Random();

    // 1) 가용 등급 가중 추첨
    final weights = <HeroRarity, int>{};
    for (final r in HeroRarity.values) {
      final has = pool.any((h) => h.rarity == r);
      if (has) weights[r] = rates[r]!;
    }
    final total = weights.values.fold<int>(0, (s, w) => s + w);
    var roll = random.nextInt(total);
    var picked = HeroRarity.r;
    for (final entry in weights.entries) {
      if (roll < entry.value) {
        picked = entry.key;
        break;
      }
      roll -= entry.value;
    }

    // 2) 해당 등급 안에서 균등 선택
    final tier = pool.where((h) => h.rarity == picked).toList(growable: false);
    return tier[random.nextInt(tier.length)];
  }
}
