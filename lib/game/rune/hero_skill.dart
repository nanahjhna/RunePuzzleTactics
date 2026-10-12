/// Rune Puzzle Tactics — **요소별** 영웅 스킬 정의 (요소별 스킬 재설계).
///
/// 스킬은 **요소**가 정하는 단 하나의 규칙이다. 같은 요소의 영웅은 같은
/// 스킬을 쓰며, 수치 차이는 보드 상태(몇 칸이 변환됐는지, 독 스택이 몇 개
/// 붙었는지)와 보드 규모에서 나온다.
///
/// 요소는 5개이고 각 요소가 효과 하나로 대응한다. 각 효과가 한 요소의 정체성을
/// 그대로 나타내므로, "이 스킬이 왜 이 요소인지"를 따로 설명할 필요가 없다.
///
/// | 요소 | 효과 | 정체성 |
/// |---|---|---|
/// | Fire   | [convertColor]  | 고른 **색**의 룬을 전부 불로 — 보드를 재편한다 |
/// | Water  | [damagePerRune] | 보드의 파란 룬 개수만큼 피해 — 개수 비례 |
/// | Grass  | [healPerRune]   | 보드의 초록 룬 개수만큼 회복 — 개수 비례 |
/// | Light  | [blastArea]     | 지정 칸 3×3 폭발 — 범위 |
/// | Poison | [venomBurst]    | 독 룬을 태워 없애고 개수만큼 즉시 피해 |
///
/// [poisonStacks](지속 피해)는 **지금 쓰는 영웅이 없는 예약 효과**다. 현행 독
/// 영웅(Nyx)은 [venomBurst] 를 쓰며, 다른 독 영웅을 도입할 때 재사용할 수 있다.
///
/// **요소 키 공유에 대한historical note** — 이전 구현은 heroId 를 키로
/// 썼고, 그 이전에는 `Map<RuneElement, HeroSkillSpec>` 로 요소를 키로
/// 썼다. 지금은 다시 요소가 스킬을 정하지만, 데이터 구조는 heroId 맵을
/// 유지한다. 영웅 전원이 같은 스킬을 갖기 때문에 현재는 요소별 1종이지만,
/// 영입 순서별 수치 차별화가 필요해지면 `amount` 값만 바꿔도 되도록
/// heroId 단위 키를 버리지 않는다.
library;

import 'rune_element.dart';

/// 영웅 스킬 효과 종류.
///
/// 요소 5개에 각각 대응하는 **현행 5종**([convertColor]·[damagePerRune]·
/// [healPerRune]·[blastArea]·[venomBurst])과, 지금은 쓰지 않는 예약 효과
/// [poisonStacks] 로 이루어진다.
enum HeroSkillEffect {
  /// **Fire** — 지정한 칸의 룬과 **같은 색의 룬을 보드 전량**을
  /// [HeroSkillSpec.convertTo] 속성으로 변환한다. 제거가 아니므로 매칭은
  /// 발생하지 않고, 다음 턴의 매칭을 준비하는 축이다.
  convertColor,

  /// **Water** — 보드 내 [HeroSkillSpec.countElement] 룬 **개수 × amount**
  /// 만큼 직접 피해. 상성/공격력 미적용(고정 피해).
  damagePerRune,

  /// **Grass** — 보드 내 [HeroSkillSpec.countElement] 룬 **개수 × amount**
  /// 만큼 파티 회복(합산). 최대 HP 는 넘지 못한다.
  healPerRune,

  /// **Light** — 지정한 칸의 **3×3 영역**(중심 + 주변 8칸)을 제거하고
  /// 낙하/리필/연쇄 매칭을 잇는다. 대상은 **빈칸을 제외한 모든 칸**
  /// (Black 룬 포함 — 이게 보드상 Black 을 없앨 유일한 수단이다).
  blastArea,

  /// **Poison** — 보드 내 [HeroSkillSpec.countElement] 룬 개수만큼 몬스터에
  /// 독 스택을 붙인다. 스택은 매 몬스터 턴마다 `스택 × amount` 만큼
  /// 지속 피해를 주고 **유지된다** (폭발형과 달리 시간이 쌓일수록 위험).
  ///
  /// **현재 쓰는 영웅이 없는 예약 효과**다 — 현행 독 영웅은 [venomBurst] 를 쓴다.
  poisonStacks,

  /// **Poison (현행)** — 보드 내 [HeroSkillSpec.countElement] 독 룬을 **전부
  /// 태워 없애고**, 없앤 개수 × amount 만큼 **즉시** 고정 피해를 준다. 제거로
  /// 빈 칸이 생기므로 낙하/연쇄 매칭이 이어진다.
  ///
  /// [damagePerRune] 가 룬을 **세기만** 하고 보드를 그대로 두는 것과 달리,
  /// 독은 보드를 **소모**한다 — 같은 "개수 비례"라도 읽는 맛이 다르다.
  venomBurst;

  /// **보드 타일을 표적으로 지정해야 하는 스킬인가.**
  ///
  /// true 면 포트레이트 탭은 즉시 발동하지 않고 **조준 모드**로 들어간다.
  /// 플레이어가 보드의 룬을 누른 뒤에야 발동한다.
  bool get needsTarget =>
      this == HeroSkillEffect.convertColor || this == HeroSkillEffect.blastArea;

  /// 포트레이트 HUD 라벨 l10n 키 (`battle_hero_skill_<suffix>`).
  String get l10nKey => 'battle_hero_skill_$l10nSuffix';

  /// 포트레이트 HUD 라벨 l10n 키 접미사.
  String get l10nSuffix => switch (this) {
    HeroSkillEffect.convertColor => 'convert',
    HeroSkillEffect.damagePerRune => 'damage',
    HeroSkillEffect.healPerRune => 'heal',
    HeroSkillEffect.blastArea => 'blast',
    HeroSkillEffect.poisonStacks => 'poison',
    HeroSkillEffect.venomBurst => 'venom',
  };

  /// 연출용 이모지. [battle_engine] 의 플로터 표기에 쓴다.
  String get floaterEmoji => switch (this) {
    HeroSkillEffect.convertColor => '🔥',
    HeroSkillEffect.damagePerRune => '💧',
    HeroSkillEffect.healPerRune => '🌿',
    HeroSkillEffect.blastArea => '💥',
    HeroSkillEffect.poisonStacks => '☠️',
    HeroSkillEffect.venomBurst => '☠️',
  };
}

/// 영웅 스킬 1건의 정의.
///
/// 스킬의 정체성은 [effect] 하나로 정해지고, 수치만 [amount]로 조정한다.
/// 요소가 스킬을 정하므로 요소마다 필드 쓰임이 다르다.
class HeroSkillSpec {
  const HeroSkillSpec({
    required this.element,
    required this.effect,
    this.amount = 0,
    this.countElement,
    this.convertTo,
  });

  /// 발동 영웅의 요소. 플로터 색·HUD 라벨의 기준이다.
  final RuneElement element;

  /// 적용 효과.
  final HeroSkillEffect effect;

  /// **개수당** 수치 — Water/Grass 는 룬 1개당 피해·회복량(10),
  /// Poison([venomBurst])은 태운 독 룬 1개당 즉시 피해(10),
  /// Poison([poisonStacks], 예약)은 스택 1개당 지속 피해.
  ///
  /// Fire/Light 는 개수를 세지 않으므로 0 이다.
  final int amount;

  /// **개수를 세는 요소** — Water=water / Grass=grass / Poison=poison.
  ///
  /// Fire(Light 도)는 변환/제거만 하므로 null 이다.
  final RuneElement? countElement;

  /// [HeroSkillEffect.convertColor] 의 변환 결과 요소. Fire 뿐이다.
  final RuneElement? convertTo;

  /// 보드 타일을 표적으로 지정해야 하는가 ([HeroSkillEffect.needsTarget]).
  bool get needsTarget => effect.needsTarget;

  /// HUD 라벨용 l10n 키 (영웅 id 기준 → 영웅마다 고유 문구).
  String l10nKeyFor(String heroId) => 'battle_hero_skill_$heroId';

  /// 상세 설명용 l10n 키.
  String descriptionKeyFor(String heroId) => 'hero_skill_$heroId';

  /// 표시용 간단 설명 (폴백/디버그용 — UI 는 l10n 을 쓴다).
  String get description => switch (effect) {
    HeroSkillEffect.convertColor => '$element: 고른 색의 룬 전량 → $convertTo',
    HeroSkillEffect.damagePerRune =>
      '$element: $countElement 룬 개수 × $amount 피해',
    HeroSkillEffect.healPerRune => '$element: $countElement 룬 개수 × $amount 회복',
    HeroSkillEffect.blastArea => '$element: 지정 칸 3×3 폭발',
    HeroSkillEffect.poisonStacks => '$element: 독 룬 개수만큼 스택, 스택당 턴마다 $amount 피해',
    HeroSkillEffect.venomBurst => '$element: 독 룬 전량 제거 + 개수 × $amount 즉시 피해',
  };
}

/// 영웅 id → 스킬 카탈로그.
///
/// 키는 heroId 다. Light 를 포함한 **모든 영웅이 스킬을 가진다**.
/// 같은 요소의 4명은 같은 스킬을 쓰지만 heroId 맵으로 저장한다 —
/// 영입 순서별 수치 차별화 지점을 남기기 위해서다.
class HeroSkills {
  HeroSkills._();

  /// 독 스택 상한 ([HeroSkillEffect.poisonStacks], 예약 효과).
  ///
  /// 풀스택(10)에서 매 턴 50 피해로, 오프라인 리듬으로 누적된다.
  /// 현재 독 영웅은 [HeroSkillEffect.venomBurst] 를 쓰므로 도달하지 않는다.
  static const int maxPoisonStacks = 10;

  /// heroId → 스킬 정의. 미등록 영웅(스킬 없음)은 맵에 없다.
  static final Map<String, HeroSkillSpec> _specs = _build();

  static Map<String, HeroSkillSpec> _build() {
    // 요소별 스킬 1건. heroId 맵이라 4개 id 에 같은 값을 넣는다.
    const fire = HeroSkillSpec(
      element: RuneElement.fire,
      effect: HeroSkillEffect.convertColor,
      convertTo: RuneElement.fire,
    );
    const water = HeroSkillSpec(
      element: RuneElement.water,
      effect: HeroSkillEffect.damagePerRune,
      amount: 10,
      countElement: RuneElement.water,
    );
    const grass = HeroSkillSpec(
      element: RuneElement.grass,
      effect: HeroSkillEffect.healPerRune,
      amount: 10,
      countElement: RuneElement.grass,
    );
    const light = HeroSkillSpec(
      element: RuneElement.light,
      effect: HeroSkillEffect.blastArea,
    );
    const poison = HeroSkillSpec(
      element: RuneElement.poison,
      effect: HeroSkillEffect.venomBurst,
      amount: 10,
      countElement: RuneElement.poison,
    );

    return {
      // ── Fire : 고른 색의 룬을 전부 불로 ──
      'fire_a': fire,

      // ── Water : 보드 파란 룬 개수 × 10 피해 ──
      'water_a': water,

      // ── Grass : 보드 초록 룬 개수 × 10 회복 ──
      'grass_a': grass,

      // ── Light : 지정 칸 3×3 폭발 ──
      'light_a': light,

      // ── Poison : 독 룬 전량 제거 + 개수×10 즉시 피해 ──
      'poison_a': poison,
    };
  }

  /// [heroId] 의 스킬 정의. 스킬이 없는 영웅이면 null.
  static HeroSkillSpec? specFor(String heroId) => _specs[heroId];

  /// [heroId] 가 스킬을 가지는지.
  static bool hasSkill(String heroId) => _specs.containsKey(heroId);

  /// 스킬을 가진 모든 영웅 id (읽기 전용).
  static Iterable<String> get heroIdsWithSkill => _specs.keys;
}
