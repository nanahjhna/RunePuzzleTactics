/// Rune Puzzle Tactics — 영웅 등급 (Hero Rarity)
///
/// 랜덤 영입(뽑기) 개편에서 추가된 등급 축이다.
///
/// **현재는 ★ 1단계(R)만 존재한다.** 2~5성급은 제거된 상태이며 나중에 다시
/// 추가될 예정이다. 사다리 구조(enum 순서 = 성급 순서, [next] / [isMax] /
/// [forRecruitOrder])는 그대로 보존했으므로, 2성 이상을 되살리려면 아래 enum에
/// 값을 추가하기만 하면 된다 (`HeroGacha.rates` 항목도 함께).
///
/// - 초기 등급은 **영입 순서(recruitOrder)** 로 고정된다 (1→R). 등급을 추가하면
///   2→SR, 3→SSR, 4→UR 처럼 순서가 곧 성급이 된다.
///   따라서 `HeroPool.unlockStages` [1] 이 등급 등장 게이트로 작동한다.
/// - 중복(중복 영웅)은 **강화 재료**로 소진된다 → 보유 영웅 중 현재 등급이 가장
///   높은 영웅이 1등급 승급한다 ([RuneProgress.tryPullHeroes]).
///   등급이 1단계뿐인 동안은 `next == this` 이므로 항상 최고 등급으로 떨어진다.
/// - 등급은 보유 풀의 가치/Prestige 를 나타내며 **전투 수치에는 영향을 주지 않는다**
///   (영웅 개별 스탯이 없고 파티 공격력/HP는 공통값이다).
library;

/// 영웅 등급 사다리 (낮은 순 → 높은 순).
///
/// ★ 2성 이상을 다시 추가할 때는 낮은 등급부터 순서대로 삽입한다.
enum HeroRarity {
  r('R', 0xFFB0BEC5);

  const HeroRarity(this.badge, this.argb);

  /// 표시용 배지 문자열. 게임 관용 표기라 번역하지 않는다.
  final String badge;

  /// UI 등급 표기: 낮은 등급부터 별 1개씩 늘어난다 (R → `★`, UR → `★★★★`).
  String get stars => List<String>.filled(index + 1, '★').join();

  /// 등급 고유 색 0xAARRGGBB (UI에서 `Color(argb)` 로 변환).
  final int argb;

  /// 최고 등급 여부. 최고 등급은 더 이상 승급할 수 없다.
  bool get isMax => index == values.length - 1;

  /// 다음 등급. 최고 등급이면 자기 자신.
  HeroRarity get next {
    final i = index + 1;
    return i >= values.length ? this : values[i];
  }

  /// 영입 순서(1~4) → 초기 등급. 범위 밖은 보정한다.
  static HeroRarity forRecruitOrder(int order) {
    final i = order - 1;
    if (i < 0) return HeroRarity.values.first;
    return i >= values.length ? HeroRarity.values.last : values[i];
  }
}
