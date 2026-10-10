/// 배틀 상태 (RPT-94, RPT-126: Single Source of Truth)
library;

import 'dart:math';

import 'battle_resolve.dart';
import 'battle_damage_stats.dart';
import 'hero_roster.dart';
import 'hero_skill.dart';
import 'hero_stats.dart';
import 'puzzle_board.dart';
import 'rune_element.dart';
import 'stage.dart';

/// 파티 영웅 1명의 스테이지 내 전투 유닛 (HP 포함).
///
/// 스킬·스탯·**체력**은 모두 **영웅 id 에 귀속**된다. 같은 속성이어도 영웅마다
/// 수치가 다르므로, 엔진은 [element] 로 유추하지 않고 이 유닛이 들고 있는
/// 값들을 그대로 신뢰한다.
class PartyHeroUnit {
  PartyHeroUnit({
    required this.heroId,
    required this.element,
    HeroSkillSpec? skill,
    HeroCombatStats? stats,
    int? hp,
  }) : skill = skill ?? HeroSkills.specFor(heroId),
       maxHp = stats?.hp ?? 0,
       hp = hp ?? stats?.hp ?? 0,
       attack = stats?.attack ?? 0,
       defense = stats?.defense ?? 0;

  /// 영웅 id (예: 'fire_a'). 포트레이트/하이라이트용.
  final String heroId;

  /// 속성 (상성 계산·색상 표시용).
  final RuneElement element;

  /// 이 영웅 고유의 스킬. 스킬이 없는 영웅이면 null.
  final HeroSkillSpec? skill;

  /// 이 영웅의 최대 HP (파티 보너스 분배 반영).
  final int maxHp;

  /// 현재 남은 HP. 쓰러지면 0 이다.
  int hp;

  /// 이 영웅의 공격력 (스킬 수치·매칭 데미지 밑 계산용).
  final int attack;

  /// 이 영웅의 방어력 (몬스터 반격을 받을 때만 쓰인다).
  final int defense;

  /// 쓰러졌는가 (HP 0 이하). 쓰러진 영웅은 스킬을 쓸 수 없고 데미지 계산의
  /// 공격력 합에서도 빠진다.
  bool get isDown => hp <= 0;

  /// HP 비율 (0~1). HUD 게이지용.
  double get hpRatio => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  /// 살아있는 이 영웅에게 피해를 준다. 실제로 깎인 HP 를 반환한다(0 이하면 0).
  int applyDamage(int amount) {
    if (amount <= 0 || isDown) return 0;
    final before = hp;
    hp = max(0, hp - amount);
    return before - hp;
  }

  /// 회복한다. 최대 HP 를 넘지 못한다. 실제 회복량을 반환한다.
  ///
  /// 쓰러진 영웅은 회복하지 않는다 — 전투 중 부활은 없다.
  int heal(int amount) {
    if (amount <= 0 || isDown) return 0;
    final before = hp;
    hp = min(maxHp, hp + amount);
    return hp - before;
  }

  /// 전멸 처리(보스 궁극기). HP 를 0 으로 만든다.
  void zeroOut() => hp = 0;

  /// 이 유닛의 **개인** 스탯을 값 객체로 되돌린다.
  ///
  /// 주입된 [HeroCombatStats] 를 그대로 들고 있지 않은 폴백 경로에서도 UI
  /// (결과 화면 등)에 영웅별 스탯을 보여줄 수 있게 한다.
  HeroCombatStats toCombatStats() => HeroCombatStats(
    heroId: heroId,
    element: element,
    hp: maxHp,
    attack: attack,
    defense: defense,
  );

  /// 현재 스테이지 전투에서 스킬을 한 번이라도 사용했는가.
  ///
  /// **스킬 횟수 제한의 기준이다.** 스킬은 **스테이지당 1회**다 — 전투마다
  /// [BattleState] 가 새로 만들어지므로 스테이지가 바뀌면 자동으로 풀린다.
  ///
  /// 예전엔 "턴당 1회"로 바꾼 적이 있었는데, 그러면 매 턴 리셋되어 사실상
  /// 무한정 쓸 수 있었다. 플레이어가 원하는 건 "한 스테이지에서 한 번"이다.
  ///
  /// 튜토리얼의 "스킬 사용" 단계 판정도 이 값을 읽는다
  /// (`lib/game/rune/tutorial.dart` 의 `_heroSkillUsed`).
  bool skillUsed = false;

  @override
  String toString() =>
      'PartyHeroUnit($heroId ${element.name} $hp/$maxHp atk=$attack '
      'used=$skillUsed)';
}

/// 배틀 단계 (RPT-94, RPT-97: BattlePhase)
enum BattlePhase {
  plan,
  action,
  inputResolving,
  resolving,
  monsterTurn,
  victory,
  defeat,
  retreat,
}

/// 하나의 전투 상태. Flutter/Flame 모두 이 상태만 바라본다 (RPT-126).
class BattleState {
  BattleState({
    required this.stage,
    required this.party,
    required this.board,
    required int partyMaxHp,
    required int baseAttack,
    List<HeroCombatStats>? heroStats,
  }) : baseAttack = baseAttack,
       _fallbackHp = partyMaxHp,
       _fallbackAtk = baseAttack,
       heroStats = heroStats == null ? const [] : List.of(heroStats),
       monsterHp = stage.monsterHp,
       monsterMaxHp = stage.monsterHp,
       bossCountdown = stage.bossCountdown;

  final StageConfig stage;
  final HeroRoster party;
  final PuzzleBoard board;
  final int baseAttack;

  /// 폴백용 합산 HP/ATK. 영웅별 스탯이 주입되지 않은 경로에서만 쓴다.
  final int _fallbackHp;
  final int _fallbackAtk;

  /// 전투 중 **영웅별** 스탯 (파티 보너스를 균등 분배한 값).
  ///
  /// 비어 있으면 [units] 가 폴백 합산값을 유닛 수로 균등 분배한다
  /// (테스트·직접 진입 경로). 실제 전투 진입은 항상 이 값을 주입한다.
  final List<HeroCombatStats> heroStats;

  /// 파티 유닛. `skillUsed`/`hp` 는 전투가 끝날 때까지 유지된다.
  ///
  /// 비어 있으면 [party]의 편성 heroId 로부터 파생된다([units] 접근 시).
  List<PartyHeroUnit> partyUnits = [];

  int monsterHp;
  int monsterMaxHp;

  /// 파티 **합계** 남은 HP (살아있는 영웅만). 쓰러진 영웅은 0 이므로 합에서 빠진다.
  int get partyHp => units.fold(0, (sum, u) => sum + u.hp);

  /// 파티 **합계** 최대 HP (편성 전원 기준, 전투 중에는 변하지 않는다).
  int get partyMaxHp => units.fold(0, (sum, u) => sum + u.maxHp);

  /// 살아있는 영웅의 공격력 합. **쓰러진 영웅의 ATK 는 제외된다.**
  ///
  /// 드래곤퀘스트식 "기여도" 규칙 — 쓰러진 영웅이 보드 매칭으로 몬스터를 계속
  /// 때리면 전멸이 무의미해진다.
  int get livingAttack =>
      units.fold(0, (sum, u) => sum + (u.isDown ? 0 : u.attack));

  /// 매칭 속성이 [element] 일 때 **그 색 살아있는 영웅들의 공격력 합**.
  ///
  /// 이 값이 매칭 데미지의 **밑**이다 ([DamageCalculator.matchDamage]).
  /// 예전에는 "그 색 영웅이 몇 명인가"를 배율표(시너지 0.6 ~ 1.6)로 바꿔
  /// 곱했는데, 그러면 같은 정보를 두 번 계산하게 된다 — 인원수를 몰라도
  /// 공격력 합이 이미 커지도록. 그래서 배율표를 삭제했다.
  ///
  /// - 살아있는 영웅이 없거나 Black 매칭이면 0 이고, 그대로 데미지 0 이 된다.
  /// - 다른 색 룬을 매치하면 이 색 영웅의 공격력은 전혀 반영되지 않는다.
  int attackForElement(RuneElement element) => units
      .where((u) => !u.isDown && u.element == element)
      .fold(0, (sum, u) => sum + u.attack);

  /// 살아있는 유닛 (파티 순서 유지).
  List<PartyHeroUnit> get livingUnits => [
    for (final u in units)
      if (!u.isDown) u,
  ];

  /// 전멸 여부 — 파티 승패 판정 단일 권위.
  ///
  /// 한 명이라도 살아 있으면 계속 싸운다. 유닛이 아예 없는 상태는 전멸이 아니라
  /// "전투를 시작할 수 없는 상태"로 보아 false 를 돌려준다.
  bool get partyWiped => units.isNotEmpty && units.every((u) => u.isDown);

  int bossCountdown;

  /// 보스 궁극기 경고 여부. true이면 다음 턴에 궁극기가 발동된다.
  bool bossUltimateWarning = false;

  /// 마지막 Resolve의 Combo (RPT-79).
  int combo = 0;

  /// 몬스터에게 걸린 **독 스택** 수 (HeroSkillEffect.poisonStacks).
  ///
  /// Poison 영웅이 보드의 독 룬 개수만큼 붙이고, **매 몬스터 턴마다
  /// `스택 × 스택당 피해` 만큼 깎인 뒤에도 유지된다**. 폭발형 스킬과 달리 시간이
  /// 쌓일수록 위험해지는 축이라, 다른 요소와 겹치지 않게 한다.
  ///
  /// 상한은 [HeroSkills.maxPoisonStacks]. 스택당 피해는 스킬 시전 순간의
  /// [HeroSkillSpec.amount] 를 [poisonPerStack] 에 기록해 둔다 — 영웅마다 수치가
  /// 달라져도 붙은 뒤의 값이 뒤틀리지 않는다.
  int poisonStacks = 0;

  /// 독 스택 1개당 몬스터 턴 피해. Poison 스킬 시전 시 [HeroSkillSpec.amount] 로
  /// 설정된다. 0 이면 독이 걸린 적이 없다.
  int poisonPerStack = 0;

  /// 이번 몬스터 턴에 독이 깎을 피해. 스택이 없으면 0.
  int get poisonTickDamage => poisonStacks * poisonPerStack;

  BattlePhase phase = BattlePhase.plan;
  bool inputLocked = false;
  bool paused = false;

  final BattleDamageStats damageStats = BattleDamageStats();

  // ── 파티 유닛 접근 ──

  /// HUD용 파티 유닛 목록. 비어 있으면 [party]의 편성 영웅에서 파생해 캐시한다.
  ///
  /// [HeroRoster] 가 heroId 를 정본으로 삼으므로, 어떤 영웅이 편성되어 있는지가
  /// 그대로 반영된다. 스탯은 [heroStats] 에 있으면 그것을(파티 보너스 분배
  /// 반영), 없으면 폴백 합산값을 균등 분배한 수치를 쓴다.
  List<PartyHeroUnit> get units {
    if (partyUnits.isEmpty) {
      partyUnits = _buildUnits();
    }
    return partyUnits;
  }

  List<PartyHeroUnit> _buildUnits() {
    final heroes = party.partyHeroes;
    if (heroes.isEmpty) return const [];
    final rosterIds = party.partyIds.toSet();

    // 1) 전투 진입이 주입한 영웅별 스탯 (파티 보너스 분배 반영) — 정본.
    final injected = <PartyHeroUnit>[
      for (final s in heroStats)
        if (rosterIds.contains(s.heroId))
          PartyHeroUnit(heroId: s.heroId, element: s.element, stats: s),
    ];
    if (injected.isNotEmpty) return injected;

    // 2) 레거시 폴백: 합산값을 영웅 수로 균등 분배. 총합이 원본과 같아
    //    영웅별 능력치를 주입하지 않은 경로(테스트·직접 진입)의 기대값이 유지된다.
    final n = heroes.length;
    final hpEach = _fallbackHp ~/ n;
    final atkEach = _fallbackAtk ~/ n;
    return [
      for (final hero in heroes)
        PartyHeroUnit(
          heroId: hero.heroId,
          element: hero.element,
          stats: HeroCombatStats(
            heroId: hero.heroId,
            element: hero.element,
            hp: hpEach,
            attack: atkEach,
            defense: hero.defense,
          ),
        ),
    ];
  }

  /// 현재 상태 스냅샷(사양 결정 5 `finalState`).
  BattleSnapshot get snapshot => BattleSnapshot(
    partyHp: partyHp,
    partyMaxHp: partyMaxHp,
    monsterHp: monsterHp,
    monsterMaxHp: monsterMaxHp,
    combo: combo,
    bossCountdown: bossCountdown,
    monsterPoisonStacks: poisonStacks,
    bossUltimateWarning: bossUltimateWarning,
  );
}
