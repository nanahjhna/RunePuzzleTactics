/// Rune Puzzle Tactics — Rune 요소 정의.
///
/// 총 5종 Rune (Fire/Grass/Water/Lightning/Poison)
///
/// **속성의 역할**
/// - 속성은 **영웅과 룬**에만 있다. 몬스터는 무속성이므로 "누가 누구를 이긴다"의
///   순환은 없다.
/// - 데미지에 영향을 주는 속성 축은 두 개뿐이다.
///   1. **매칭 속성의 살아있는 영웅 ATK 합** — 같은 색 영웅을 많이 넣을수록 그 색
///      룬의 데미지가 자동으로 커진다 ([BattleState.attackForElement]).
///      별도의 시너지 배율표를 두지 않는 이유다.
///   2. **스테이지 상성 배율** — 약점 1.5 / 중립 1.0 / 열세 0.5
///      ([StageConfig.affinityFor]).
/// - 예전에 있던 5속성 순환과, 영웅 개인 `affinityBonus` / `affinityResistance`
///   증폭축은 삭제했다. 몬스터가 무속성이어서 증폭축은 항상 0 이었다.
library;

/// 퍼즐/배틀에서 사용하는 Rune 종류.
///
/// - [fire] ~ [poison]: 공격 Rune 5종
enum RuneElement {
  fire('🔥', 'Fire', 0xFFFF5722, 18),
  grass('🌿', 'Grass', 0xFF4CAF50, 270),
  water('💧', 'Water', 0xFF2196F3, 350),
  light('⚡', 'Lightning', 0xFFFFC107, 188),
  poison('☠️', 'Poison', 0xFF9C27B0, 104);

  const RuneElement(this.emoji, this.label, this.argb, this.spriteSrcX);

  /// Placeholder 표시용 이모지.
  final String emoji;

  /// 영문 라벨.
  final String label;

  /// 0xAARRGGBB. UI 테두리/배경 팔레트에 사용한다.
  final int argb;

  /// 룬 아이콘 시트([runeSpriteAsset])에서 이 룬 아이콘의 좌측 X 좌표.
  ///
  /// 시트는 [runeSpriteWidth]×[runeSpriteHeight]이며, 원본 5행 시트의 4행 부분을
  /// 잘라낸 것으로 6개 아이콘이 각각 [runeSpriteIconWidth]×[runeSpriteIconHeight]
  /// 크기로 배치되어 있다 (인접 아이콘 간 투명 간격이 달라 균등 분할 불가).
  final int spriteSrcX;

  // ── 룬 아이콘 시트 상수 (assets/images/runes/rune_row4.png, 512×59) ──
  // Flame 기본 이미지 prefix('assets/images/') 아래에 두므로 경로는 'runes/...'.
  static const String runeSpriteAsset = 'runes/rune_row4.png';
  static const double runeSpriteWidth = 512;
  static const double runeSpriteHeight = 59;
  static const double runeSpriteIconWidth = 54;
  static const double runeSpriteIconHeight = 59;

  /// 공격 Rune 5종.
  static const List<RuneElement> normal = [
    RuneElement.fire,
    RuneElement.grass,
    RuneElement.water,
    RuneElement.light,
    RuneElement.poison,
  ];
}
