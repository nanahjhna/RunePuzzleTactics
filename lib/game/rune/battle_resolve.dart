/// Rune Puzzle Tactics — 단일 입력 해석 결과 (사양 결정 5: `BattleResolveResult`)
///
/// **Pure Dart Authority ("Resolve First → Animate Second")** 의 결과 객체.
/// Flame(프레젠테이션)은 이 구조체 시퀀스를 받아 **순서대로 재생만** 한다.
/// 전투/퍼즐 계산은 전부 [BattleEngine]이 여기서 끝낸다.
///
/// 한 유저 Swap에 대해 다음 순서로 담긴다:
/// ```text
/// 1. cascadeSteps          유저 Swap → 룬 Match → Drop/Refill (Cascade 콤보)
/// 2. heroSkillEvents       플레이어가 발동한 영웅 스킬 연출 이벤트
/// 3. playerDamageEvent     콤보 + 속성 시너지 최종 타격 데미지
/// 4. blackRuneDamageEvent  Black 룬 매칭에 의한 파티 피해 (발생 시)
/// 5. monsterAttackEvent    몬스터 반격 카운트 0 도달 시 반격 연출
/// 6. finalState            위 모든 과정이 반영된 최종 BattleState 스냅샷
/// ```
library;

import 'hero_skill.dart';
import 'damage.dart';
import 'puzzle_board.dart';
import 'puzzle_engine.dart';
import 'rune_element.dart';

/// 영웅 스킬 발동 1건.
class HeroSkillEvent {
  HeroSkillEvent({
    required this.spec,
    required this.heroId,
    required this.amount,
    Set<int> cells = const <int>{},
  }) : cells = Set.unmodifiable(cells);

  /// 발동한 스킬 정의.
  final HeroSkillSpec spec;

  /// 발동한 영웅 id (HUD 하이라이트용).
  final String heroId;

  /// 발동한 속성.
  RuneElement get element => spec.element;

  /// 효과 종류.
  HeroSkillEffect get effect => spec.effect;

  /// 효과 수치 (피해량/회복량/연장초/변환 칸 수 등). 효과에 따라 0일 수 있다.
  final int amount;

  /// 보드 영향 칸(폭발 오브 변환 칸, 정화된 Black 칸 등).
  final Set<int> cells;

  @override
  String toString() =>
      'HeroSkillEvent(${element.name}/${effect.name} hero=$heroId amt=$amount)';
}

/// 데미지 1건의 출처 ([BattleResolveResult.monsterHits] / [partyHits] 항목).
enum DamageSource {
  /// 일반 매칭 1그룹 (칸 3~5개).
  match,

  /// Black 룬 매칭 (파티 피해, 매칭 개수 5 이상이면 피해 0).
  blackMatch,

  /// 영웅 스킬 즉시 피해 (Water/Grass 등).
  heroSkill,

  /// **독 스택 지속 피해** — 몬스터 턴마다 스택만큼 깎이는 틱 피해.
  ///
  /// 시전 즉시 터지는 게 아니라 매 턴 반복되므로 별도 출처로 분리한다. HUD 가
  /// 스킬 칩과 별개로 표기하고, 합계에는 [BattleResolveResult.monsterHits] 를
  /// 통해 정상 편입된다.
  poisonTick,
}

/// **데미지 1건의 확정 수치 + 배율 내역** (연출 계층 설명용).
///
/// 매칭 1그룹 = 1건으로 [BattleEngine] 가 확정한다. 총합만 넘기면 플레이어가
/// `12 → 60` 같은 도약의 원인을 확인할 수 없으므로, 연출 계층이 플로터 숫자 +
/// 배율 캡션으로 그대로 재현할 수 있게 한다 (Resolve-first: **계산은 엔진**,
/// 표시는 Flame).
class DamageHit {
  DamageHit({
    required this.source,
    required this.element,
    required this.damage,
    this.waveNumber = 0,
    List<int> cells = const <int>[],
    this.combo = 1,
    this.weaknessHit = false,
    this.affinityMultiplier = 1,
    this.heroId,
    this.noElementHero = false,
  }) : cells = List.unmodifiable(cells),
       assert(damage >= 0, 'damage는 음수가 될 수 없다');

  final DamageSource source;

  /// 공격에 사용한 원소.
  final RuneElement element;

  /// 확정 데미지. 피해 0인 경우(Black 5+)도 0으로 기록한다.
  final int damage;

  /// **피해를 받은 영웅** id (파티 피해 항목 전용).
  ///
  /// Black 룬 피해는 살아있는 영웅 중 랜덤 1명에게 들어간다. 연출이 이 id 로
  /// 해당 초상화만 반응하면 "누가 맞았는지"를 읽을 수 있다. 몬스터 반격은
  /// 별도 이벤트([MonsterAttackEvent.targetHeroId])를 쓴다.
  final String? heroId;

  /// 캐스케이드 파도 번호(1부터). 직접 타격은 0.
  final int waveNumber;

  /// 발생 칸(플로터 위치·섬광 대상). 비어 있으면 화면 중앙 표기.
  final List<int> cells;

  /// 발생 시점 콤보.
  final int combo;

  /// 이 타격이 몬스터 약점 속성이었는가.
  final bool weaknessHit;

  /// 상성 배율 (단일 권위는 [StageConfig.affinityFor] — 약점 1.5 / 중립 1.0 /
  /// 열세 0.5).
  final double affinityMultiplier;

  /// 이 매치의 속성 영웅이 파티에 **없어서** 데미지가 0이었는가.
  ///
  /// 엔진이 매치 데미지를 계산할 때 [BattleState.attackForElement] 이 0 이면
  /// (그 색 살아있는 영웅이 없으면) 데미지가 0 이 된다. 이때 뷰에 "그 색 영웅의
  /// 룬을 매치하세요" 경고를 몬스터 중앙에 띄우기 위한 플래그다.
  final bool noElementHero;

  /// 콤보 배율 (단일 권위는 [DamageCalculator]).
  double get comboMultiplier => DamageCalculator.comboMultiplier(combo);

  /// 실제 적용된 총 배율 (상성 × 콤보).
  double get totalMultiplier => affinityMultiplier * comboMultiplier;

  /// 표시용 배율 캡션 (예: `C3 ×2.25`).
  ///
  /// 데미지 = (그 색 ATK 합) × 상성 × 콤보 배율이라 배율이 겹치면 값이 크게
  /// 튄다. 캡션으로 배율을 노출해 "20 인데 60" 같은 의문을 없앤다.
  ///
  /// **보드 플로터와 몬스터 위 라벨이 같은 문자열을 써야 한다.** 두 곳이 따로
  /// 만들면 한쪽만 갱신돼 표기가 어긋나고, 사용자는 숫자를 못 믿게 된다.
  String get caption {
    if (damage <= 0) return '';
    final buf = StringBuffer();
    if (combo > 1) buf.write('C$combo ');
    final m = totalMultiplier;
    if ((m - 1).abs() > 0.001) buf.write('×${m.toStringAsFixed(2)}');
    return buf.toString();
  }

  @override
  String toString() =>
      'DamageHit(${source.name}/${element.name} dmg=$damage wave=$waveNumber '
      'combo=$combo aff=$affinityMultiplier weak=$weaknessHit)';
}

/// 몬스터 반격 1건 (사양 결정 5 `monsterAttackEvent`).
class MonsterAttackEvent {
  MonsterAttackEvent({
    required this.damage,
    required this.bossCountdownAfter,
    required this.isBossUltimate,
    this.breakdown,
    this.targetHeroId,
    this.targetHpBefore,
    this.targetHpAfter,
    this.targetMaxHp,
  });

  /// 파티가 받은 피해.
  final int damage;

  /// 반격 후 남은 보스 카운트(0이면 곧 보스 궁극기).
  final int bossCountdownAfter;

  /// 보스 궁극기였는지.
  final bool isBossUltimate;

  /// Exact inputs used for a normal monster hit; null for a boss ultimate.
  final IncomingDamageResult? breakdown;

  /// **맞은 영웅** id. 몬스터는 살아있는 영웅 중 랜덤 1명을 고른다.
  ///
  /// 연출이 이 id 의 초상화만 반응하는 근거다. 보스 궁극기에는 대상이 없어도
  /// (직전에 맞은 영웅 기준으로 채운다) 값이 들어갈 수 있다.
  final String? targetHeroId;

  /// 대상 영웅 HP — 반격 직전/직후와 최대치.
  final int? targetHpBefore;
  final int? targetHpAfter;
  final int? targetMaxHp;
}

/// 영웅이 **피해를 입은** 출처 ([HeroDamageEvent.source]).
enum HeroDamageSource {
  /// Black 룬 매칭 — 캐스케이드 파도 중에 발생.
  blackRune,

  /// 몬스터 반격 — 살아있는 영웅 1명에게 들어간다.
  monsterAttack,

  /// 보스 궁극기 — 살아있는 **전원**에게 광역 피해 (생존 가능, 전멸 시에만 패배).
  bossUltimate,
}

/// 영웅 1명이 **실제로 HP 를 잃은** 1건.
///
/// [MonsterAttackEvent] 가 "몬스터가 때렸다" 라는 **예고/총량** 레벨이라면
/// 이건 "그 영웅의 HP 가 N 만큼 실제로 줄었다" 라는 **확정** 레벨이다.
/// 아래 두 값을 구분하지 않으면 연출 숫자가 HP 바 델타와 어긋난다:
///
/// - [DamageHit.damage] 는 HP 차감 **전 예측값**이고, [_applyPartyHits] 는
///   대상이 먼저 쓰러졌으면 살아있는 영웅으로 **대체**한다.
/// - 몬스터 반격도 잔여 HP 가 피해보다 작으면 초과분이 evaporate 된다.
///
/// 그래서 값의 출처를 [PartyHeroUnit.applyDamage] 반환값("실제로 깎인 HP")으로
/// 삼는다. 단일 권위는 엔진이며, 연출 계층은 이 리스트를 재생만 한다.
///
/// [heroId] 와 [damage] 는 **항상** 그 영웅의 HP 바와 일치한다.
class HeroDamageEvent {
  const HeroDamageEvent({
    required this.heroId,
    required this.damage,
    required this.source,
    required this.element,
    required this.waveNumber,
  });

  /// HP 를 잃은 영웅 id — 연출은 이 영웅의 초상화만 반응한다.
  final String heroId;

  /// 실제 깎인 HP. [PartyHeroUnit.applyDamage] 반환값이라 **0 이하면 이벤트
  /// 자체가 만들어지지 않는다**(방어막 전량 상쇄, 이미 쓰러진 영웅 등).
  final int damage;

  /// 피해 출처.
  final HeroDamageSource source;

  /// 피해를 입은 속성. 몬스터 반격은 몬스터의 공격 속성(보스의 경우
  /// [BattleSnapshot] 단계에서 이미 확정된 스테이지 속성), 블랙 룬은 매칭된
  /// Black 속성. 무속성 몬스터 공격이면 null 이다.
  final RuneElement? element;

  /// 이 피해가 발생한 캐스케이드 파도 번호(1부터, 직접 타격은 0).
  ///
  /// 몬스터 턴 효과(반격/보스 궁극기)는 캐스케이드와 절대 겹치지 않도록
  /// [monsterTurnWave] 로 환일해 둔다 — 덕분에 연출 계층은 보드 플로터와
  /// **같은 시점**에 같은 조건으로 걸어낼 수 있다.
  final int waveNumber;

  /// 몬스터 턴 효과의 [waveNumber] 예약값.
  static const int monsterTurnWave = -1;

  @override
  String toString() =>
      'HeroDamageEvent($heroId -$damage ${source.name} wave=$waveNumber)';
}

/// 파티 HP/몬스터 HP 등 최종 상태 스냅샷(불변).
class BattleSnapshot {
  const BattleSnapshot({
    required this.partyHp,
    required this.partyMaxHp,
    required this.monsterHp,
    required this.monsterMaxHp,
    required this.combo,
    required this.bossCountdown,
    this.monsterPoisonStacks = 0,
    this.bossUltimateWarning = false,
  });

  final int partyHp;
  final int partyMaxHp;
  final int monsterHp;
  final int monsterMaxHp;

  /// 최종 콤보.
  final int combo;

  final int bossCountdown;

  /// 몬스터에 걸린 독 스택 수 (HUD 뱃지용).
  ///
  /// 매 턴 유지되는 값이라 플레이어가 "언제까지 남았는가"를 볼 수 있어야 한다.
  final int monsterPoisonStacks;

  /// 보스 궁극기 경고 여부. true이면 다음 턴에 궁극기가 발동된다.
  final bool bossUltimateWarning;

  double get partyHpRatio =>
      partyMaxHp <= 0 ? 0 : (partyHp / partyMaxHp).clamp(0.0, 1.0);

  double get monsterHpRatio =>
      monsterMaxHp <= 0 ? 0 : (monsterHp / monsterMaxHp).clamp(0.0, 1.0);
}

/// 한 입력의 해석 결과 분류.
enum BattleResolveOutcome {
  /// 유효 매치 없음 (보드 복원, 데미지 0, 턴 미소비).
  invalidSwap,

  /// 정상 종료(몬스터 턴까지 진행).
  continued,

  /// 몬스터 처치.
  victory,

  /// 파티 전멸.
  defeat,
}

/// **유저 1회 Swap에 대한 단일 결과 객체** (사양 결정 5).
///
/// Flame은 [cascadeSteps] → [heroSkillEvents] → [playerDamage] →
/// [blackRuneDamage] → [monsterAttackEvent] → [finalState] 순서로 재생만 한다.
class BattleResolveResult {
  BattleResolveResult({
    required this.outcome,
    required List<WaveResult> cascadeSteps,
    required List<HeroSkillEvent> heroSkillEvents,
    required this.playerDamage,
    required this.blackRuneDamage,
    required this.monsterAttackEvent,
    required this.finalState,
    required this.board,
    List<WaveResult> heroSkillWaves = const [],
    List<DamageHit> monsterHits = const [],
    List<DamageHit> partyHits = const [],
    List<HeroDamageEvent> heroDamageEvents = const [],
  }) : cascadeSteps = List.unmodifiable(cascadeSteps),
       heroSkillEvents = List.unmodifiable(heroSkillEvents),
       heroSkillWaves = List.unmodifiable(heroSkillWaves),
       monsterHits = List.unmodifiable(monsterHits),
       partyHits = List.unmodifiable(partyHits),
       heroDamageEvents = List.unmodifiable(heroDamageEvents);

  /// 결과 분류.
  final BattleResolveOutcome outcome;

  /// 1) 캐스케이드 파도 (Swap → Match → Drop/Refill).
  final List<WaveResult> cascadeSteps;

  /// 2) 사용한 영웅 스킬 이벤트.
  final List<HeroSkillEvent> heroSkillEvents;

  /// 영웅 스킬이 보드를 변형해 유발한 캐스케이드 파도.
  ///
  /// Water 스킬(Black 정화)이 빈칸 → 낙하 → 리필 → 연쇄 매치로 이어질 때
  /// 발생한다. [cascadeSteps] 와 분리해 두어 Flame이
  /// "영웅 스킬 → 후속 캐스케이드" 순서로 재생하게 한다.
  final List<WaveResult> heroSkillWaves;

  /// 3) 유저 최종 타격 데미지 (콤보 + 속성 시너지 반영 합계).
  final int playerDamage;

  /// 4) Black 룬으로 파티가 받은 피해 (발생 시 0 초과).
  final int blackRuneDamage;

  /// 5) 몬스터 반격 (미발생 시 null).
  final MonsterAttackEvent? monsterAttackEvent;

  /// 6) 최종 상태 스냅샷.
  final BattleSnapshot finalState;

  /// 해석이 끝난 보드(Flame이 이 상태로 리셋/리필 표시).
  final PuzzleBoard board;

  /// 캐스케이드 없이 즉시 끝났는지(무효 스왑).
  bool get isEmpty => cascadeSteps.isEmpty;

  /// 몬스터가 받은 데미지 **1건씩** ([DamageHit] 원본 목록).
  ///
  /// 합계 = [monsterHits] 의 [DamageHit.damage] 합이므로, 합계와 개별 수치가
  /// 항상 일치한다 (연출이 총합을 재계산할 필요가 없다).
  final List<DamageHit> monsterHits;

  /// Black 룬 매칭으로 파티가 받은 피해 **1건씩**.
  ///
  /// 몬스터 반격([monsterAttackEvent])은 별도 이벤트로 분리한다 — 둘을 합치면
  /// "Black 10 + 반격 13 = 23" 을 23 하나로 보여줘 피해 출처를 알 수 없다.
  final List<DamageHit> partyHits;

  /// **실제로 HP 를 잃은 영웅** 1건씩 — 세 출처(블랙 룬 / 몬스터 반격 /
  /// 보스 궁극기)를 전부 한 리스트로 모은다.
  ///
  /// [partyHits] 가 "Black 룬이 몇을 때렸나" 라는 **피해 예측** 레벨이고
  /// [monsterAttackEvent] 가 "몬스터가 반격했다" 는 **총량** 레벨인 것과 달리,
  /// 이건 영웅 1명 1건의 **확정 차감**이다. 초상화 연출(피격 이미지 + 숫자)은
  /// 오직 이 리스트를 보고 재생한다 — 그래야 "얼굴 밑 숫자 = HP 바가 줄어난 양"
  /// 이 항상 성립한다.
  ///
  /// [HeroDamageEvent.waveNumber] 로 발생 시점(캐스케이드 파도 / 몬스터 턴)을
  /// 구분하므로, 연출 계층은 보드 플로터와 같은 시점에 같은 조건으로 걸어낼 수
  /// 있다. 보스 궁극기는 `damage: 0` 인 [MonsterAttackEvent] 로는 잡히지 않는데
  /// 여기는 살아있던 전원이 각각 잡힌다.
  final List<HeroDamageEvent> heroDamageEvents;

  /// [monsterHits] 합계.
  ///
  /// **영웅 스킬의 즉시 피해**(Water/Grass)는 `monsterHits` 가 아니라
  /// [heroSkillEvents] 로만 실리므로 이 합계에 **포함되지 않는다**. 스킬 칩이 따로
  /// 뜨므로 정보는 안 잃는다. 반면 **독 스택 틱**([DamageSource.poisonTick])은
  /// 반복형이라 매 턴 `monsterHits` 로 들어가므로 합계에 포함된다 — 몬스터 HP 는
  /// 실제로 그만큼 깎였으니 합계가 총 피해와 어긋나면 안 된다.
  int get summedMonsterDamage => monsterHits.fold(0, (s, h) => s + h.damage);

  /// [partyHits] 합계.
  int get summedPartyDamage => partyHits.fold(0, (s, h) => s + h.damage);

  /// 총 타격량(플레이어 데미지 + 몬스터가 받은 부수 피해 합).
  int get totalDamage => playerDamage;

  @override
  String toString() =>
      'BattleResolveResult(${outcome.name} waves=${cascadeSteps.length} '
      'skills=${heroSkillEvents.length} dmg=$playerDamage black=$blackRuneDamage '
      'monsterAtk=${monsterAttackEvent?.damage})';
}
