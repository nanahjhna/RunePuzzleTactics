/// Rune 진행도(Meta) 모델 — 3-재화 경제 + Hero Pool + 멱등 원장 (감사 기반 재설계)
///
/// 배틀 코어와 분리된 순수 Dart 모델로, 스테이지 클리어/재화/파티/통계/업그레이드를
/// 하나의 불변 스냅샷으로 표현한다. 저장 방식(SharedPreferences/SQLite 등)은
/// [RuneProgressStore] 인터페이스 뒤로 숨겨 UI/엔진과 분리한다.
///
///  - 재화 3종: Game(승리/업그레이드), Play(배틀 입장), Hero(영웅 뽑기).
///    서로 환전 불가 (프롬프트 §19 3-재화).
///  - 모든 재화 변동은 [CurrencyTransaction] 원장에 남고 id 기반 멱등 적용
///    (중복 지급·중복 차감 방지, 프롬프트 §6 idempotent ledger).
///  - 영웅은 Hero Pool의 heroId로 보유/편성 (프롬프트 §29 HeroPool).
///    영입(뽑기) 시 자동 편성하지 않는다 (프롬프트 §1 no auto party-assign).
///  - 영웅은 [HeroRarity] 등급을 가진다(초기 등급 = 영입 순서). 중복은
///    **최고 등급 영웅**이 흡수해 1등급 승급한다. 등급은 전투 수치에 영향 없음
///    ([heroGrade] / [topGradeHero] / [tryPullHeroes]).
///    등급은 현재 ★ 1단계뿐이라 승급이 일어나지 않고 중복은 항상 최고 등급으로
///    떨어진다 (2성 이상 추가 시 승급이 다시 살아난다).
///  - 배틀 입장은 Play 재화를 소모한다 (프롬프트 §19 stageEntryCost).
///  - 일일 보상은 날짜(yyyy-MM-dd) 단위 1회 (프롬프트 §20 Daily Reward).
///  - JSON v3 (v1/v2는 자동 마이그레이션; 구버전의 제거된 필드는 무시).
library;

import 'dart:math';

import 'currency.dart';
import 'hero_gacha.dart';
import 'hero_pool.dart';
import 'hero_rarity.dart';
import 'hero_roster.dart';
import 'hero_level.dart';
import 'hero_stat_upgrade.dart';
import 'hero_stats.dart';
import 'rune_element.dart';

/// 메타 진행도 경제 규칙.
class RuneMeta {
  RuneMeta._();

  /// 배틀 입장 1회 비용 (Play Currency).
  static const int stageEntryCost = 1;

  /// 최대 클리어 스테이지 상한 (MVP 기준 30). highestCleared가 30이면 더 이상 진행 불가.
  static const int maxStage = 30;

  /// 일일 보상: Play +1, Hero +1 (하루 1회).
  static const int dailyRewardPlay = 10;
  static const int dailyRewardHero = 10;

  /// 보상형 광고 1회: Play +1 (1회 재시청 키), Hero +1 (별도 키).
  static const int rewardedAdPlay = 10;
  static const int rewardedAdHero = 10;

  /// 기초 파티 스탯은 영웅 및 영구 강화 스탯에 별도로 더하지 않는다.
  static const int baseAttack = 0;

  static const int basePartyMaxHp = 0;

  /// 새 게임 시작 시 보유 구성: 스타터 Fire Hero #1 (fire_a), 편성 포함.
  ///
  /// 시작 Play Currency를 5 지급해 첫 배틀 진입이 항상 가능하도록 한다
  /// (입장 비용 §19를 잠그지 않기 위한 설계; Game/Hero는 0에서 시작).
  static RuneProgress initial() => RuneProgress(
    playCurrency: 5,
    heroOwned: {HeroPool.starter.heroId},
    heroParty: [HeroPool.starter.heroId],
  );
}

/// Rune 진행도 저장소 인터페이스.
///
/// UI/엔진은 이 인터페이스만 의존한다. 테스트는 [InMemoryRuneProgressStore],
/// 실제 앱은 services의 SharedPreferences/SQLite 구현을 사용한다.
abstract class RuneProgressStore {
  /// 저장된 진행도를 읽는다. 데이터가 없으면 초기 구성(RPT-25)을 반환.
  Future<RuneProgress> load();

  /// 진행도를 기기에 저장한다.
  Future<void> save(RuneProgress progress);
}

/// 테스트/디버그용 인메모리 저장소 (canonical 구현).
class InMemoryRuneProgressStore implements RuneProgressStore {
  InMemoryRuneProgressStore([RuneProgress? progress])
    : _progress = progress ?? RuneMeta.initial();

  RuneProgress _progress;

  @override
  Future<RuneProgress> load() async => _progress;

  @override
  Future<void> save(RuneProgress progress) async => _progress = progress;
}

/// Rune 모드 진행 스냅샷 (불변).
class RuneProgress {
  RuneProgress({
    this.highestCleared = 0,
    this.gameCurrency = 0,
    this.playCurrency = 0,
    this.heroCurrency = 0,
    this.wins = 0,
    this.losses = 0,
    this.tutorialCompleted = false,
    this.lastDailyRewardDate,
    this.lastPlayedStage,
    this.lastStageVictory,
    this.heroPityCount = 0,
    Set<String>? heroOwned,
    List<String>? heroParty,
    Map<String, int>? heroGrades,
    Map<String, Map<HeroStatKind, int>>? heroStatLevels,
    Map<String, int>? heroLevels,
    Map<String, int>? heroExp,
    List<CurrencyTransaction>? ledger,
  }) : _heroOwned = {...?heroOwned},
       // 정원 초과 마이그레이션: 정원이 5 → 4 로 줄어 이전 저장 데이터에 5명이
       // 남아 있어도 앞 4명만 유지한다(나머지는 Owned 로 되돌려지므로 잃지 않는다).
       // 생성자 한 곳에서 막아 fromJson / fromRoster / copyWith 이 모두 보호된다.
       _heroParty = List.of(
         (heroParty ?? const <String>[]).take(HeroRoster.maxPartySize),
       ),
       _heroGrades = {...?heroGrades},
       _heroStatLevels = {
         for (final e in (heroStatLevels ?? const {}).entries)
           e.key: Map<HeroStatKind, int>.of(e.value),
       },
       // 레벨은 1 미만을 담지 않는다(기록 없음 = Lv.1). EXP 는 0 초과만 담는다.
       _heroLevels = {
         for (final e in (heroLevels ?? const {}).entries)
           if (e.value > HeroLevel.minLevel)
             e.key: e.value.clamp(HeroLevel.minLevel, HeroLevel.maxLevel),
       },
       _heroExp = {
         for (final e in (heroExp ?? const {}).entries)
           if (e.value > 0) e.key: e.value,
       },
       _ledger = List.of(ledger ?? const []);

  /// 최고 클리어 스테이지. 0 = 아직 클리어 없음.
  final int highestCleared;

  /// Game Currency (승리 보상/업그레이드 구매).
  final int gameCurrency;

  /// Play Currency (배틀 입장 비용).
  final int playCurrency;

  /// Hero Currency (영웅 영입).
  final int heroCurrency;

  final int wins;
  final int losses;

  /// 인터랙티브 튜토리얼 완료 여부 (RPT-406).
  final bool tutorialCompleted;

  /// 마지막 일일 보상 수령일 ('yyyy-MM-dd'). null = 아직 미수령.
  final String? lastDailyRewardDate;

  /// **마지막으로 플레이(입장)한 스테이지**. null = 아직 전투한 적 없음.
  ///
  /// 로비의 "마지막 플레이" 카드([LastPlayedStageCard])가 이 값을 읽는다.
  /// [selectableMaxStage] 로 클램핑하지 않는다 — 클리어하지 못한 스테이지도
  /// 사용자가 "다시 도전"하려고 보는 대상이므로 원본 값을 보존한다.
  final int? lastPlayedStage;

  /// 마지막 스테이지의 승패. null = [lastPlayedStage] 와 짝을 이루는 값 없음.
  final bool? lastStageVictory;

  /// 영웅 영입 **천상(피티) 카운터** — 연속 중복 횟수.
  ///
  /// 중복이 나면 +1, 신규 영웅이 나오면 0 으로 리셋한다.
  /// [heroPityThreshold] 에 도달하면 다음 **1연** 은 미보유 영웅이 확정된다
  /// (등급이 ★1단일이라 "등급 천상"은 무의미하므로 신규 등장 보장으로 정의).
  final int heroPityCount;

  /// 천상 확정까지 필요한 연속 중복 횟수.
  static const int heroPityThreshold = 10;

  /// 천상 발동 조건 — [heroPityCount] 가 임계값 이상이고 아직 미보유 영웅이 있다.
  bool get pityReady {
    if (heroPityCount < heroPityThreshold) return false;
    // 풀 고갈(전 영웅 보유) 시 천상이 무의미하다.
    for (final h in HeroPool.heroes) {
      if (_heroOwned.contains(h.heroId)) continue;
      if (h.recruitCost == 0 || h.unlockStage <= nextStage) return true;
    }
    return false;
  }

  /// 천상까지 남은 중복 횟수 (UI 진행바 표기용).
  int get pityRemaining =>
      (heroPityThreshold - heroPityCount).clamp(0, heroPityThreshold);

  final Set<String> _heroOwned;
  final List<String> _heroParty;

  /// 영웅 id → 현재 등급 인덱스([HeroRarity] 사다리).
  ///
  /// 기록되지 않은 영웅은 [RuneHeroDef.rarity] (영입 순서 기반 초기 등급)이다.
  ///
  /// 등급이 ★ 1단계뿐인 동안에는 항상 비어 있는 상태로 남는다(2성 이상 추가 시
  /// 승급 기록이 쌓인다). 구 세이브의 오래된 등급 값은 [_decodeHeroGrades] 가
  /// 사다리 범위 밖으로 보고 버린다.
  final Map<String, int> _heroGrades;

  /// 영웅 id → 그 영웅의 스탯별 강화 레벨.
  ///
  /// 파티 공통 보너스(마도서)를 없애고 **영웅 1인 기준**으로 쌓는 축이다.
  /// 키가 없으면 그 영웅은 레벨 0 (= 강화 없음). [_decodeHeroStatLevels] 가
  /// 알 수 없는 영웅/스탯/범위 밖 값을 버린다.
  final Map<String, Map<HeroStatKind, int>> _heroStatLevels;

  /// 영웅 id → 현재 레벨. 기록이 없으면 [HeroLevel.minLevel] (= Lv.1).
  ///
  /// 유료 스탯 강화([_heroStatLevels])와 달리 **재화를 쓰지 않는다** — 전투 승리
  /// 보상 EXP 로만 오른다. 레벨이 오르면 [heroLevelBonus] 만큼 스탯이 자동 상승한다.
  final Map<String, int> _heroLevels;

  /// 영웅 id → 현재 EXP (다음 레벨까지의 진행분). 기록 없으면 0.
  ///
  /// 만렙 영웅은 0 으로 유지한다([grantPartyExp] 참고).
  final Map<String, int> _heroExp;

  final List<CurrencyTransaction> _ledger;

  // ── 영웅/파티 ──

  /// 보유 영웅 id (불변 뷰).
  Set<String> get heroOwned => Set.unmodifiable(_heroOwned);

  /// 편성 영웅 id 순서 (불변 뷰).
  List<String> get heroParty => List.unmodifiable(_heroParty);

  /// 보유 영웅 정의 목록 (HeroPool 순서: 속성 → recruitOrder).
  List<RuneHeroDef> get ownedHeroes => _heroesOf(_heroOwned);

  /// 편성 영웅 정의 목록 (파티 순서 유지).
  List<RuneHeroDef> get partyHeroes => _heroesOf(_heroParty.toSet());

  List<RuneHeroDef> _heroesOf(Set<String> ids) {
    return HeroPool.heroes.where((h) => ids.contains(h.heroId)).toList();
  }

  /// 보유 영웅 수 (속성별).
  int ownedCount(RuneElement e) =>
      HeroPool.forElement(e).where((h) => _heroOwned.contains(h.heroId)).length;

  /// 편성 영웅 수 (속성별).
  int partyCount(RuneElement e) =>
      HeroPool.forElement(e).where((h) => _heroParty.contains(h.heroId)).length;

  int get ownedTotal => _heroOwned.length;
  int get partyTotal => _heroParty.length;

  /// 편성된 파티 영웅 정의 목록(heroId 단위, 결정론적 순서).
  ///
  /// 사양 1-1/1-2의 1x4 포트레이트 그리드와 전투 HUD가 소비한다.
  /// [HeroPool.heroes] 순서(속성 → recruitOrder)를 따르므로 재시작해도
  /// 슬롯 배치가 흔들리지 않는다.
  List<RuneHeroDef> get partyHeroDefs => [
    for (final h in HeroPool.heroes)
      if (_heroParty.contains(h.heroId)) h,
  ];

  /// 편성된 파티 영웅 id 목록([partyHeroDefs] 와 동일 순서).
  List<String> get partyHeroIds => [for (final h in partyHeroDefs) h.heroId];

  bool isHeroOwned(String heroId) => _heroOwned.contains(heroId);
  bool isHeroInParty(String heroId) => _heroParty.contains(heroId);

  /// **보유했지만 아직 파티에 없는** 영웅 id (요구사항 5의 `+` 버튼 활성화 조건).
  ///
  /// 파티 정원과 무관하게 "더 넣을 수 있는가"를 판정하기 위한 단일 권위다.
  /// [party_slots] 의 `+` 활성 여부가 `ownedTotal > partyTotal` 대신 이
  /// 리스트의 비어 있지 않음을 확인한다(해제 직후에도 정확하게 반영된다).
  Set<String> get availableHeroIds =>
      _heroOwned.toSet().difference(_heroParty.toSet());

  /// [heroId] 영입 해금 여부 (nextStage 기준).
  bool isHeroUnlocked(String heroId) {
    final def = HeroPool.byId(heroId);
    if (def == null) return false;
    return def.recruitCost == 0 || nextStage >= def.unlockStage;
  }

  /// 다음 진행 스테이지 = `min(highestCleared + 1, RuneMeta.maxStage)` (사양 결정 1).
  ///
  /// [RuneMeta.maxStage] 상한은 "내부 DB 최댓값" 하드 제한이다. 상한에 닿으면
  /// 30스테이지를 반복 플레이(마지막 스테이지 재도전)만 가능하며, 무한 스테이지로
  /// 넘어가지 않는다.
  int get nextStage => (highestCleared + 1).clamp(1, RuneMeta.maxStage);

  /// 스테이지 선택 UI에서 [◀ 이전]/[다음 ▶] 버튼으로 도달 가능한 상한.
  ///
  /// 명세 "내부 DB의 최댓값 기반으로 다음 스테이지 제한"의 구현 지점.
  int get selectableMaxStage => nextStage;

  /// 마지막 스테이지(상한) 클리어 여부 — UI 배너/버튼 비활성 판정용.
  bool get isMaxStageReached => highestCleared >= RuneMeta.maxStage;

  // ── 원장 (idempotent) ──

  /// 재화 거래 원장 (최신순으로 불변 뷰).
  List<CurrencyTransaction> get ledger => List.unmodifiable(_ledger);

  /// [txId]가 원장에 기록되어 있는지 여부.
  bool hasTransaction(String txId) => _ledger.any((t) => t.id == txId);

  /// 재화 [type] 현재 잔액.
  int currencyOf(CurrencyType type) => switch (type) {
    CurrencyType.game => gameCurrency,
    CurrencyType.play => playCurrency,
    CurrencyType.hero => heroCurrency,
  };

  /// 재화 변동 (멱등 적용).
  ///
  /// - [txId]가 이미 원장에 있으면 아무것도 바꾸지 않고 `applied: false`.
  /// - [amount]가 음수일 때 잔액이 부족하면 (음수가 되면) 적용하지 않는다.
  /// - 성공 시 원장에 [CurrencyTransaction]을 기록하고 새 스냅샷을 반환.
  ({RuneProgress progress, bool applied}) applyCurrency({
    required String txId,
    required CurrencyType type,
    required int amount,
    CurrencyTxType txType = CurrencyTxType.stageReward,
    String source = 'system',
  }) {
    if (_ledger.any((t) => t.id == txId)) {
      return (progress: this, applied: false);
    }
    final balance = currencyOf(type);
    final next = balance + amount;
    if (next < 0) return (progress: this, applied: false);
    final tx = CurrencyTransaction(
      id: txId,
      type: type,
      amount: amount,
      txType: txType,
      source: source,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = _withCurrency(type, next)._withLedgerAppend(tx);
    return (progress: updated, applied: true);
  }

  RuneProgress _withCurrency(CurrencyType type, int value) => switch (type) {
    CurrencyType.game => copyWith(gameCurrency: value),
    CurrencyType.play => copyWith(playCurrency: value),
    CurrencyType.hero => copyWith(heroCurrency: value),
  };

  RuneProgress _withLedgerAppend(CurrencyTransaction tx) {
    final list = [..._ledger, tx];
    // 원장 크기 상한 (메모리 안정성).
    if (list.length > 256) {
      list.removeRange(0, list.length - 256);
    }
    return copyWith(ledger: List.unmodifiable(list));
  }

  // ── 배틀 진입 (Play Currency 소모) ──

  /// 스테이지 입장 비용 차감 (RPT-316 개편).
  ///
  /// Play Currency가 [cost] 미만이면 실패(변화 없음).
  ({RuneProgress progress, bool ok}) tryStageEntry(int cost, {String? txId}) {
    final id = txId ?? 'stage_entry_${DateTime.now().millisecondsSinceEpoch}';
    // 이미 같은 입장 트랜잭션을 소모한 경우(재시도) 중복 차감하지 않는다.
    if (_ledger.any((t) => t.id == id)) {
      return (progress: this, ok: true);
    }
    final r = applyCurrency(
      txId: id,
      type: CurrencyType.play,
      amount: -cost,
      txType: CurrencyTxType.stageEntry,
      source: 'battle',
    );
    return (progress: r.progress, ok: r.applied);
  }

  // ── 영웅 랜덤 영입(뽑기) / 파티 편성 ──

  /// [heroId] 영웅의 현재 등급. 기록이 없으면 초기 등급([RuneHeroDef.rarity]).
  ///
  /// 등급이 ★ 1단계뿐이라 사다리 범위가 0 하나뿐이다. 구 세이브에 남아 있던
  /// 2~4성 값은 [_decodeHeroGrades] 단계에서 이미 버려졌으므로 여기서는 항상 `r`.
  HeroRarity heroGrade(String heroId) {
    final def = HeroPool.byId(heroId);
    if (def == null) return HeroRarity.r;
    final saved = _heroGrades[heroId];
    if (saved == null) return def.rarity;
    return HeroRarity.values[saved.clamp(0, HeroRarity.values.length - 1)];
  }

  /// 보유 영웅 중 현재 등급이 가장 높은 영웅 (강화 흡수 대상).
  ///
  /// 동률이면 heroId 사전순으로 결정한다(저장/표시 흔들림 방지).
  ///
  /// 등급이 1단계뿐인 동안에는 전부 동률이라 heroId 사전순 첫 영웅이 잡힌다.
  /// **현재 중복 처리는 등급 승급 대신 뽑힌 영웅의 레벨업([grantHeroLevel])을
  /// 쓰므로 이 getter 는 쓰이지 않는다** — ★ 2성 이상 재도입 대비로 남겨 둔다.
  RuneHeroDef? get topGradeHero {
    RuneHeroDef? best;
    var bestGrade = -1;
    for (final h in HeroPool.heroes) {
      if (!_heroOwned.contains(h.heroId)) continue;
      final g = heroGrade(h.heroId).index;
      if (g > bestGrade ||
          (g == bestGrade &&
              (best == null || h.heroId.compareTo(best.heroId) < 0))) {
        best = h;
        bestGrade = g;
      }
    }
    return best;
  }

  /// 랜덤 영입(뽑기) 시도 (Hero Currency 차감 + 보상 반영, 원자적).
  ///
  /// - [count] 회 추첨. 결과는 [GachaResult] 리스트로 반환되어 결과 팝업이 소비한다.
  /// - 중복은 보유에 쌓이지 않고 **뽑힌 영웅 자신의 카드 레벨업**으로 소진된다
  ///   (`+[HeroLevel.levelsPerDuplicate]` 레벨). 만렙이면 [GachaOutcome.maxed].
  /// - 자동 파티 편성은 하지 않는다 (프롬프트 §1).
  /// - [reason]: 'insufficient'(재화 부족), 'empty_pool'(가용 영웅 없음),
  ///   'invalid_count'(장수 1~10 아님).
  ({RuneProgress progress, bool ok, String? reason, List<GachaResult> results})
  tryPullHeroes({int count = 1, Random? rng, String? txId}) {
    if (count < 1 || count > 10) {
      return (
        progress: this,
        ok: false,
        reason: 'invalid_count',
        results: const <GachaResult>[],
      );
    }
    final pool = HeroGacha.poolFor(nextStage);
    if (pool.isEmpty) {
      return (
        progress: this,
        ok: false,
        reason: 'empty_pool',
        results: const <GachaResult>[],
      );
    }
    final cost = count == HeroGacha.tenCount
        ? HeroGacha.tenCost
        : count * HeroGacha.singleCost;
    final id = txId ?? 'gacha_${DateTime.now().microsecondsSinceEpoch}_$count';
    if (_ledger.any((t) => t.id == id)) {
      return (
        progress: this,
        ok: false,
        reason: 'duplicate',
        results: const <GachaResult>[],
      );
    }
    final paid = applyCurrency(
      txId: id,
      type: CurrencyType.hero,
      amount: -cost,
      txType: CurrencyTxType.heroRecruit,
      source: 'shop',
    );
    if (!paid.applied) {
      return (
        progress: this,
        ok: false,
        reason: 'insufficient',
        results: const <GachaResult>[],
      );
    }

    // 추첨 → 보유/강화 반영 (불변 스냅샷 재사용)
    var p = paid.progress;
    final results = <GachaResult>[];
    // 천상(요구사항 9): 임계값 도달 + **1연**이면 미보유 영웅 확정.
    //
    // 10연에는 적용하지 않는다 — 1연 10회의 보장이라 표기("10연 신규 1명
    // 보장")와 어긋나고, 중복 폭발이 오히려 국내 체감을 깎는다.
    final pityActive = count == 1 && p.pityReady;
    for (var i = 0; i < count; i++) {
      final hero = pityActive
          ? _drawUnownedHero(p, rng: rng)
          : HeroGacha.draw(nextStage: p.nextStage, rng: rng);
      if (hero == null) continue;

      if (!p._heroOwned.contains(hero.heroId)) {
        p = p.copyWith(
          heroOwned: {...p._heroOwned, hero.heroId},
          // 신규가 떴으면 천상 카운터 리셋.
          heroPityCount: 0,
        );
        results.add(
          GachaResult(
            hero: hero,
            outcome: GachaOutcome.newHero,
            gradeBefore: hero.rarity,
            gradeAfter: hero.rarity,
          ),
        );
        continue;
      }

      // 중복 → 천상 카운터 +1 (신규가 이미 떨어졌으면 리셋된 상태 유지).
      p = p.copyWith(
        heroPityCount: (p.heroPityCount + 1).clamp(0, heroPityThreshold),
      );

      // 중복 → 뽑힌 그 영웅의 기존 카드가 레벨업한다(기본 +1).
      //
      // 만렙이면 더 오를 수 없어 maxed 로 남긴다. 같은 heroId 가 10연에서
      // 반복되면 매 반복마다 갱신된 p 의 현재 레벨을 기준으로 누적된다.
      final before = p.heroGrade(hero.heroId);
      final fromLevel = p.heroLevel(hero.heroId);
      if (fromLevel >= HeroLevel.maxLevel) {
        results.add(
          GachaResult(
            hero: hero,
            outcome: GachaOutcome.maxed,
            gradeBefore: before,
            gradeAfter: before,
            levelBefore: fromLevel,
            levelAfter: fromLevel,
          ),
        );
        continue;
      }
      final granted = p.grantHeroLevel(
        hero.heroId,
        levels: HeroLevel.levelsPerDuplicate,
      );
      p = granted.progress;
      results.add(
        GachaResult(
          hero: hero,
          outcome: GachaOutcome.levelUp,
          gradeBefore: before,
          gradeAfter: before,
          levelBefore: granted.fromLevel,
          levelAfter: granted.toLevel,
        ),
      );
    }
    return (progress: p, ok: true, reason: null, results: results);
  }

  /// 천상용 추첨: 현재 풀에서 **미보유** 영웅 중 균등 선택. 없으면 null.
  RuneHeroDef? _drawUnownedHero(RuneProgress p, {Random? rng}) {
    final pool = HeroGacha.poolFor(
      p.nextStage,
    ).where((h) => !p._heroOwned.contains(h.heroId)).toList(growable: false);
    if (pool.isEmpty) return null;
    return pool[(rng ?? Random()).nextInt(pool.length)];
  }

  /// 파티 편성 시도 (heroId 단위): 정원 ≤ [HeroRoster.maxPartySize].
  ({RuneProgress progress, bool ok}) tryAssignHero(String heroId) {
    if (!_heroOwned.contains(heroId)) return (progress: this, ok: false);
    if (_heroParty.contains(heroId)) return (progress: this, ok: false);
    if (_heroParty.length >= HeroRoster.maxPartySize) {
      return (progress: this, ok: false);
    }
    return (progress: copyWith(heroParty: [..._heroParty, heroId]), ok: true);
  }

  /// 파티 해제 시도 (heroId 단위).
  ({RuneProgress progress, bool ok}) tryUnassignHero(String heroId) {
    if (!_heroParty.contains(heroId)) return (progress: this, ok: false);
    return (
      progress: copyWith(heroParty: [..._heroParty]..remove(heroId)),
      ok: true,
    );
  }

  /// 속성 단위 편성 편의 헬퍼: 해당 속성 보유 영웅 중 미편성 1명을 편성.
  ({RuneProgress progress, bool ok}) tryAssignParty(RuneElement e) {
    final candidate = HeroPool.forElement(e)
        .where(
          (h) =>
              _heroOwned.contains(h.heroId) && !_heroParty.contains(h.heroId),
        )
        .firstOrNull;
    if (candidate == null) return (progress: this, ok: false);
    return tryAssignHero(candidate.heroId);
  }

  /// 속성 단위 해제 편의 헬퍼: 해당 속성 편성 영웅 중 마지막 1명을 해제.
  ({RuneProgress progress, bool ok}) tryUnassignParty(RuneElement e) {
    final hero = _heroParty.reversed
        .where((id) => HeroPool.byId(id)?.element == e)
        .firstOrNull;
    if (hero == null) return (progress: this, ok: false);
    return tryUnassignHero(hero);
  }

  // ── 영웅 개별 스탯 강화 ──

  /// [heroId] 영웅의 스탯별 강화 레벨. 기록 없으면 전부 0.
  Map<HeroStatKind, int> heroStatLevels(String heroId) =>
      Map.unmodifiable(_heroStatLevels[heroId] ?? const {});

  /// [heroId] 영웅의 [kind] 스탯 강화 레벨.
  int heroStatLevel(String heroId, HeroStatKind kind) =>
      _heroStatLevels[heroId]?[kind] ?? 0;

  /// [heroId] 영웅의 강화 누적량 (파티 공통 보너스 없음 — 이 영웅만의 값).
  HeroStatUpgradeLevels heroStatUpgrade(String heroId) =>
      HeroStatUpgradeLevels(_heroStatLevels[heroId] ?? const {});

  // ── 영웅 레벨 / 경험치 ──

  /// [heroId] 영웅의 현재 레벨 ([HeroLevel.minLevel] ~ [HeroLevel.maxLevel]).
  int heroLevel(String heroId) =>
      (_heroLevels[heroId] ?? HeroLevel.minLevel).clamp(
        HeroLevel.minLevel,
        HeroLevel.maxLevel,
      );

  /// [heroId] 영웅의 현재 EXP (다음 레벨까지의 진행분). 만렙이면 0.
  int heroExp(String heroId) {
    if (heroLevel(heroId) >= HeroLevel.maxLevel) return 0;
    return _heroExp[heroId] ?? 0;
  }

  /// [heroId] 가 최대 레벨인가.
  bool isHeroMaxLevel(String heroId) => heroLevel(heroId) >= HeroLevel.maxLevel;

  /// 다음 레벨까지 필요한 EXP. 만렙이면 0.
  int heroExpToNext(String heroId) =>
      isHeroMaxLevel(heroId) ? 0 : HeroLevel.expToNext(heroLevel(heroId));

  /// 다음 레벨까지 진행 비율 (0.0 ~ 1.0). 만렙이면 1.0.
  double heroExpRatio(String heroId) {
    final need = heroExpToNext(heroId);
    if (need <= 0) return 1.0;
    return (heroExp(heroId) / need).clamp(0.0, 1.0);
  }

  /// [heroId] 레벨이 주는 자동 스탯 보너스 (Lv.1 = 0). 강화와 별개로 합산된다.
  HeroStatBonuses heroLevelBonus(String heroId) =>
      HeroLevel.statBonusAt(heroLevel(heroId));

  /// 파티 전원에게 [amount] EXP 를 지급하고, 이번에 오른 레벨을 돌려준다.
  ///
  /// - **승리 1회당 1번** 호출한다(패배는 지급하지 않음). 편성 영웅 전원이 대상.
  /// - 만렙 영웅에게는 쌓지 않는다(EXP 낭비 방지) — 그 영웅은 건너뛴다.
  /// - 한 번에 여러 레벨이 오를 수 있다(연속 루프).
  ///
  /// 결과 화면의 "레벨 업" 알림은 [levelUps] 를 그대로 쓴다. 진행도는 [progress].
  ({RuneProgress progress, List<HeroLevelUp> levelUps}) grantPartyExp(int amount) {
    if (amount <= 0 || _heroParty.isEmpty) {
      return (progress: this, levelUps: const <HeroLevelUp>[]);
    }
    final levels = {..._heroLevels};
    final exps = {..._heroExp};
    final ups = <HeroLevelUp>[];
    for (final heroId in _heroParty) {
      final from = heroLevel(heroId);
      if (from >= HeroLevel.maxLevel) continue; // 만렙은 더 쌓지 않는다.
      var level = from;
      var exp = (_heroExp[heroId] ?? 0) + amount;
      while (level < HeroLevel.maxLevel && exp >= HeroLevel.expToNext(level)) {
        exp -= HeroLevel.expToNext(level);
        level++;
      }
      if (level >= HeroLevel.maxLevel) exp = 0; // 만렙 도달 시 잔여 EXP 정리.
      levels[heroId] = level;
      exps[heroId] = exp;
      if (level > from) {
        ups.add(HeroLevelUp(heroId: heroId, fromLevel: from, toLevel: level));
      }
    }
    return (
      progress: copyWith(heroLevels: levels, heroExp: exps),
      levelUps: ups,
    );
  }

  /// [heroId] 영웅의 레벨을 [levels] 만큼 올린다 (중복 영입 보상). EXP 는 건드리지 않는다.
  ///
  /// 최대 [HeroLevel.maxLevel] 로 클램프한다. 만렙이라 오를 수 없으면 아무 변화 없이
  /// 같은 진행도를 돌려준다(from == to). 반환된 from/to 는 결과 팝업의
  /// `Lv.from → Lv.to` 표시에 쓴다.
  ({RuneProgress progress, int fromLevel, int toLevel}) grantHeroLevel(
    String heroId, {
    int levels = 1,
  }) {
    final from = heroLevel(heroId);
    final to = (from + levels).clamp(HeroLevel.minLevel, HeroLevel.maxLevel);
    if (to <= from) return (progress: this, fromLevel: from, toLevel: from);
    return (
      progress: copyWith(heroLevels: {..._heroLevels, heroId: to}),
      fromLevel: from,
      toLevel: to,
    );
  }

  /// [heroId] 영웅의 강화 반영 **개인** 전투 스탯.
  ///
  /// 파티 보너스 분배가 사라졌으므로 [RuneHeroDef] 의 기본치에 그 영웅만의
  /// 누적 강화량을 그냥 더한다. 미보유/미편성 영웅이어도 값은 계산된다
  /// (상세 팝업 미리보기용).
  HeroCombatStats heroCombatStatsOf(String heroId) {
    final def = HeroPool.byId(heroId);
    if (def == null) {
      return HeroCombatStats(
        heroId: heroId,
        element: RuneElement.normal.first,
        hp: 0,
        attack: 0,
        defense: 0,
      );
    }
    final bonus = heroStatUpgrade(heroId);
    final levelBonus = heroLevelBonus(heroId);
    return HeroCombatStats(
      heroId: def.heroId,
      element: def.element,
      hp: def.hp + bonus.hp + levelBonus.hp,
      attack: def.attack + bonus.attack + levelBonus.attack,
      defense: def.defense + bonus.defense + levelBonus.defense,
    );
  }

  /// 편성 영웅 **개별** 전투 스탯 (각자의 강화 반영).
  ///
  /// 몬스터가 "누구를 때릴지" 정하려면 영웅별 방어력이 있어야 하므로
  /// 전투 진입 시 이 목록을 엔진에 주입한다. 합계는 [totalPartyHp] /
  /// [totalPartyAtk] 와 같다.
  List<HeroCombatStats> get heroCombatStats => [
    for (final h in partyHeroDefs) heroCombatStatsOf(h.heroId),
  ];

  /// 편성 영웅 개인치 + 각자 강화 + 레벨 보너스 = 편성 **합계** HP.
  int get totalPartyHp =>
      partyHeroDefs.fold(0, (sum, h) => sum + heroCombatStatsOf(h.heroId).hp);

  /// 편성 **합계** 공격력.
  int get totalPartyAtk => partyHeroDefs.fold(
    0,
    (sum, h) => sum + heroCombatStatsOf(h.heroId).attack,
  );

  /// 편성 **합계** 방어력.
  int get totalPartyDef => partyHeroDefs.fold(
    0,
    (sum, h) => sum + heroCombatStatsOf(h.heroId).defense,
  );

  /// 전투 진입 시 사용할 파티 공격력.
  int get baseAttackForBattle => totalPartyAtk;

  /// 전투 진입 시 사용할 파티 최대 체력.
  int get partyMaxHpForBattle => totalPartyHp;

  /// 영웅 개별 스탯 강화 1레벨 구매 시도 (Game Currency 차감).
  ///
  /// - **미보유 영웅** / max 레벨 도달 → 실패(변화 없음).
  /// - 재화 부족 → 실패(변화 없음).
  /// - 성공 시 Game Currency 차감 + 해당 영웅의 해당 스탯 레벨 1 증가.
  ///   차감과 레벨 변경은 **단일 불변 스냅샷**으로 반영한다(부분 반영 없음).
  ///
  /// `cost` 는 실패해도 필요한 금액(최대 레벨이면 null)을 돌려준다 — 호출부가
  /// "얼마가 모자란지" / "최대 레벨" 스낵바를 고를 수 있게 하기 위함.
  ({RuneProgress progress, bool ok, int? cost, int? level}) tryUpgradeHeroStat(
    String heroId,
    HeroStatKind kind,
  ) {
    if (!isHeroOwned(heroId)) {
      return (progress: this, ok: false, cost: null, level: null);
    }
    final config = HeroStatUpgrades.of(kind);
    final level = heroStatLevel(heroId, kind);
    if (level >= config.maxLevel) {
      return (progress: this, ok: false, cost: null, level: level);
    }
    final cost = config.costForLevel(level);
    final txId = 'hero_stat_${heroId}_${kind.name}_${level + 1}';
    if (_ledger.any((t) => t.id == txId) || gameCurrency < cost) {
      return (progress: this, ok: false, cost: cost, level: level);
    }
    final payment = applyCurrency(
      txId: txId,
      type: CurrencyType.game,
      amount: -cost,
      txType: CurrencyTxType.upgradePurchase,
      source: 'hero_detail',
    );
    if (!payment.applied) {
      return (progress: this, ok: false, cost: cost, level: level);
    }
    final next = payment.progress._heroStatLevels[heroId] ?? const {};
    return (
      progress: payment.progress.copyWith(
        heroStatLevels: {
          ...payment.progress._heroStatLevels,
          heroId: {...next, kind: level + 1},
        },
      ),
      ok: true,
      cost: cost,
      level: level + 1,
    );
  }

  // ── 통계 / 튜토리얼 ──

  /// 스테이지 클리어 기록: 최고 스테이지 갱신 + Game Currency 보상 (멱등).
  ///
  /// 같은 [txId]의 클리어 보상은 두 번 지급되지 않는다. 기본 id는
  /// `stage_clear_$stageNumber`이며, 같은 스테이지 재도전 승리 구분이 필요하면
  /// 호출부가 [txId]를 새로 지정한다.
  RuneProgress recordClear(int stageNumber, int gameReward, {String? txId}) {
    final id = txId ?? 'stage_clear_$stageNumber';
    if (_ledger.any((t) => t.id == id)) return this; // 멱등
    final r = applyCurrency(
      txId: id,
      type: CurrencyType.game,
      amount: gameReward,
      txType: CurrencyTxType.stageReward,
      source: 'battle',
    );
    // 로비 "마지막 플레이" 카드용 기록 (요구사항 1).
    return r.progress
        ._withLastStage(stageNumber, victory: true)
        .copyWith(
          // 사양 결정 1: 상한(30)을 넘겨 기록되지 않도록 클램핑.
          highestCleared: max(
            stageNumber,
            r.progress.highestCleared,
          ).clamp(1, RuneMeta.maxStage),
          wins: r.progress.wins + 1,
        );
  }

  /// 패배 기록 (Play Currency는 유지 — 입장 비용만 소모).
  ///
  /// [stageNumber] 를 넘기면 로비 "마지막 플레이" 카드에 함께 기록된다.
  RuneProgress recordDefeat({int? stageNumber}) =>
      copyWith(losses: losses + 1)._withLastStage(stageNumber, victory: false);

  /// 마지막 플레이 스테이지/승패 기록.
  ///
  /// [stageNumber] 가 null 이면 아무것도 바꾸지 않는다 (수치 이력이 중요하므로
  /// `recordDefeat()` 만 호출된 경로에서 기존 값이 지워지지 않게).
  RuneProgress _withLastStage(int? stageNumber, {required bool victory}) {
    if (stageNumber == null) return this;
    final clamped = stageNumber.clamp(1, RuneMeta.maxStage);
    return copyWith(lastPlayedStage: clamped, lastStageVictory: victory);
  }

  /// 튜토리얼 완료/스킵 기록 (RPT-406).
  RuneProgress recordTutorialDone() => copyWith(tutorialCompleted: true);

  // ── 일일 보상 / 광고 (멱등) ──

  /// 일일 보상 수령 가능 여부 (오늘 미수령).
  bool dailyRewardAvailable(DateTime now) =>
      lastDailyRewardDate != _dateKey(now);

  /// 일일 보상 수령 (하루 1회, Play + [playAmount], Hero + [heroAmount]).
  ({RuneProgress progress, bool ok}) claimDailyReward({
    required DateTime now,
    int playAmount = RuneMeta.dailyRewardPlay,
    int heroAmount = RuneMeta.dailyRewardHero,
  }) {
    final today = _dateKey(now);
    if (lastDailyRewardDate == today) return (progress: this, ok: false);
    final r1 = applyCurrency(
      txId: 'daily_play_$today',
      type: CurrencyType.play,
      amount: playAmount,
      txType: CurrencyTxType.dailyReward,
      source: 'daily',
    );
    final r2 = r1.progress.applyCurrency(
      txId: 'daily_hero_$today',
      type: CurrencyType.hero,
      amount: heroAmount,
      txType: CurrencyTxType.dailyReward,
      source: 'daily',
    );
    return (
      progress: r2.progress.copyWith(lastDailyRewardDate: today),
      ok: r1.applied && r2.applied,
    );
  }

  /// 영웅 재화 광고의 일일 멱등 txId ('ad_hero_yyyy-MM-dd').
  ///
  /// [canClaimHeroAd]가 이 키로 오늘 수령 여부를 판별하므로, 히어로 광고 지급 시
  /// 반드시 이 키를 트랜잭션 id로 사용해야 일일 1회 제한이 적용된다.
  static String heroAdTxId(DateTime now) {
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'ad_hero_${now.year}-$m-$d';
  }

  /// 영웅 재화 광고 충전 가능 여부 (오늘 자정 00:00 기준 이미 수령했는지 확인)
  bool canClaimHeroAd(DateTime now) {
    return !_ledger.any((t) => t.id == heroAdTxId(now));
  }

  /// 보상형 광고 보상 수령 (+Play 또는 +Hero, 멱등 [txId]).
  ///
  /// 같은 [txId]는 두 번 지급되지 않으므로 광고 콜백이 중복 호출되어도 안전.
  ({RuneProgress progress, bool applied}) claimRewardedAd({
    required String txId,
    required CurrencyType type,
    required int amount,
  }) {
    return applyCurrency(
      txId: txId,
      type: type,
      amount: amount,
      txType: CurrencyTxType.rewardedAd,
      source: 'ad',
    );
  }

  String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  // ── 변환 ──

  /// 스냅샷 → [HeroRoster] (엔진 전달용). heroId 집합을 그대로 넘긴다.
  HeroRoster toRoster() =>
      HeroRoster.fromIds(partyHeroIds, ownedIds: _heroOwned);

  /// [HeroRoster] → 스냅샷. heroId는 recruitOrder 오름차순(결정적)으로 대응.
  static RuneProgress fromRoster(
    HeroRoster roster, {
    int highestCleared = 0,
    int gameCurrency = 0,
    int playCurrency = 0,
    int heroCurrency = 0,
    int wins = 0,
    int losses = 0,
    bool tutorialCompleted = false,
    String? lastDailyRewardDate,
    Map<String, Map<HeroStatKind, int>>? heroStatLevels,
    Map<String, int>? heroGrades,
    Map<String, int>? heroLevels,
    Map<String, int>? heroExp,
    List<CurrencyTransaction>? ledger,
  }) {
    // heroId 는 이미 [HeroRoster] 가 정본으로 삼으므로 그대로 옮긴다.
    final owned = roster.ownedIds.toSet();
    final party = roster.partyIds;
    return RuneProgress(
      highestCleared: highestCleared,
      gameCurrency: gameCurrency,
      playCurrency: playCurrency,
      heroCurrency: heroCurrency,
      wins: wins,
      losses: losses,
      tutorialCompleted: tutorialCompleted,
      lastDailyRewardDate: lastDailyRewardDate,
      heroOwned: owned,
      heroParty: party,
      // 등급·스탯 강화는 RuneRoster 가 알지 못하므로 호출자가 그대로 넘긴다.
      heroGrades: {...?heroGrades},
      heroStatLevels: {...?heroStatLevels},
      heroLevels: {...?heroLevels},
      heroExp: {...?heroExp},
      ledger: List.of(ledger ?? const []),
    );
  }

  RuneProgress copyWith({
    int? highestCleared,
    int? gameCurrency,
    int? playCurrency,
    int? heroCurrency,
    int? wins,
    int? losses,
    bool? tutorialCompleted,
    String? lastDailyRewardDate,
    int? lastPlayedStage,
    bool? lastStageVictory,
    int? heroPityCount,
    Set<String>? heroOwned,
    List<String>? heroParty,
    Map<String, int>? heroGrades,
    Map<String, Map<HeroStatKind, int>>? heroStatLevels,
    Map<String, int>? heroLevels,
    Map<String, int>? heroExp,
    List<CurrencyTransaction>? ledger,
  }) {
    return RuneProgress(
      highestCleared: highestCleared ?? this.highestCleared,
      gameCurrency: gameCurrency ?? this.gameCurrency,
      playCurrency: playCurrency ?? this.playCurrency,
      heroCurrency: heroCurrency ?? this.heroCurrency,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      lastDailyRewardDate: lastDailyRewardDate ?? this.lastDailyRewardDate,
      lastPlayedStage: lastPlayedStage ?? this.lastPlayedStage,
      lastStageVictory: lastStageVictory ?? this.lastStageVictory,
      heroPityCount: heroPityCount ?? this.heroPityCount,
      heroOwned: {...(heroOwned ?? _heroOwned)},
      heroParty: List.of(heroParty ?? _heroParty),
      heroGrades: {...(heroGrades ?? _heroGrades)},
      // 생성자가 안쪽 맵까지 복사하므로 여기서는 바깥 맵만 넘기면 된다.
      heroStatLevels: {...(heroStatLevels ?? _heroStatLevels)},
      heroLevels: {...(heroLevels ?? _heroLevels)},
      heroExp: {...(heroExp ?? _heroExp)},
      ledger: List.of(ledger ?? _ledger),
    );
  }

  // ── JSON (v3) ──

  Map<String, dynamic> toJson() {
    return {
      'v': 3,
      'highestCleared': highestCleared,
      'gameCurrency': gameCurrency,
      'playCurrency': playCurrency,
      'heroCurrency': heroCurrency,
      'wins': wins,
      'losses': losses,
      'tutorialCompleted': tutorialCompleted,
      'lastDailyRewardDate': lastDailyRewardDate,
      // v3 스키마에 선택적 키로 추가했다. 값이 null 로도 직렬화하므로 구버전
      // 세이브는 그대로 읽히고(키 부재 → null 폴백) 스키마 버전 bump도 불필요.
      'lastPlayedStage': lastPlayedStage,
      'lastStageVictory': lastStageVictory,
      'heroPityCount': heroPityCount,
      'heroOwned': _heroOwned.toList(),
      'heroParty': _heroParty,
      // 등급은 영웅 id → HeroRarity 인덱스. 없는 영웅은 초기 등급(영입 순서)이다.
      'heroGrades': Map<String, int>.from(_heroGrades),
      // 영웅 개별 스탯 강화: 영웅 id → { 스탯명 → 레벨 }.
      // 옛 `upgrades`(파티 공통 영구 업그레이드) / `bookLevels`(마도서) 를 대체한다.
      // 레벨 0 항목은 저장하지 않는다(구버전 세이브 키 부재 → 전부 0 폴백).
      'heroStats': {
        for (final e in _heroStatLevels.entries)
          if (e.value.isNotEmpty)
            e.key: {
              for (final s in e.value.entries)
                if (s.value > 0) s.key.name: s.value,
            },
      },
      // 영웅 레벨 / 경험치. Lv.1(기본)과 EXP 0 은 저장하지 않는다(구버전 세이브
      // 키 부재 → 기본값 폴백과 같은 결과라 스키마 bump 불필요).
      'heroLevels': {
        for (final e in _heroLevels.entries)
          if (e.value > HeroLevel.minLevel) e.key: e.value,
      },
      'heroExp': {
        for (final e in _heroExp.entries)
          if (e.value > 0) e.key: e.value,
      },
      'ledger': [for (final t in _ledger) t.toJson()],
    };
  }

  /// v3 JSON 역직렬화 + v1/v2 자동 마이그레이션.
  ///
  /// - v1/v2: `gold` → gameCurrency, `owned`/`party`(element count) →
  ///   recruitOrder 오름차순 heroId 집합.
  /// - 손상/미지원 버전 데이터는 초기 구성으로 폴백 (RPT-316 안전 복원).
  static RuneProgress fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    if (version == 3) return _fromV3(json);
    if (version == 1 || version == 2) return _fromV1V2(json);
    return RuneMeta.initial();
  }

  static RuneProgress _fromV3(Map<String, dynamic> json) {
    final owned = _sanitizeHeroIds(json['heroOwned']);
    final party = _sanitizeHeroIds(json['heroParty']);
    return RuneProgress(
      highestCleared: (json['highestCleared'] as num?)?.toInt() ?? 0,
      gameCurrency: (json['gameCurrency'] as num?)?.toInt() ?? 0,
      playCurrency: (json['playCurrency'] as num?)?.toInt() ?? 0,
      heroCurrency: (json['heroCurrency'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      tutorialCompleted: json['tutorialCompleted'] as bool? ?? false,
      lastDailyRewardDate: json['lastDailyRewardDate'] as String?,
      lastPlayedStage: _decodeStage(json['lastPlayedStage']),
      lastStageVictory: json['lastStageVictory'] as bool?,
      heroPityCount: _decodePity(json['heroPityCount']),
      heroOwned: owned.toSet(),
      heroParty: party,
      heroGrades: _decodeHeroGrades(json['heroGrades']),
      heroStatLevels: _decodeHeroStatLevels(json['heroStats']),
      heroLevels: _decodeHeroLevels(json['heroLevels']),
      heroExp: _decodeHeroExp(json['heroExp']),
      ledger: _decodeLedger(json['ledger']),
    );
  }

  /// `heroStats` (영웅 id → { 스탯명 → 레벨 }) 역직렬화.
  ///
  /// 구버전 세이브에는 키가 없으므로 빈 맵 = 전 영웅 레벨 0 (= 강화 없음).
  /// 알 수 없는 영웅 / 스탯 / 최대 레벨 초과·음수 값은 버린다(손상 세이브 복원).
  static Map<String, Map<HeroStatKind, int>> _decodeHeroStatLevels(
    dynamic raw,
  ) {
    if (raw is! Map) return <String, Map<HeroStatKind, int>>{};
    final map = <String, Map<HeroStatKind, int>>{};
    for (final entry in raw.entries) {
      final heroId = entry.key;
      if (heroId is! String || HeroPool.byId(heroId) == null) continue;
      final statsRaw = entry.value;
      if (statsRaw is! Map) continue;
      final stats = <HeroStatKind, int>{};
      for (final s in statsRaw.entries) {
        final kind = HeroStatKind.values
            .where((k) => k.name == s.key)
            .firstOrNull;
        final level = (s.value is num) ? s.value.toInt() : null;
        if (kind == null || level == null || level <= 0) continue;
        stats[kind] = level.clamp(1, HeroStatUpgrades.of(kind).maxLevel);
      }
      if (stats.isNotEmpty) map[heroId] = stats;
    }
    return map;
  }

  /// `heroGrades` (heroId → 등급 인덱스) 역직렬화.
  ///
  /// v3 저장 데이터에는 키가 없으므로(구버전 마이그레이션) 빈 맵이 되어 모든 영웅이
  /// 초기 등급을 유지한다. 알 수 없는 영웅/범위 밖 값은 버린다.
  static Map<String, int> _decodeHeroGrades(dynamic raw) {
    if (raw is! Map) return <String, int>{};
    final map = <String, int>{};
    for (final entry in raw.entries) {
      final id = entry.key;
      if (id is! String || HeroPool.byId(id) == null) continue;
      final v = (entry.value is num) ? entry.value.toInt() : null;
      if (v == null || v < 0 || v >= HeroRarity.values.length) continue;
      map[id] = v;
    }
    return map;
  }

  /// `heroLevels` (heroId → 레벨) 역직렬화.
  ///
  /// 구버전 세이브에는 키가 없으므로 빈 맵 = 전 영웅 Lv.1. 알 수 없는 영웅과
  /// 범위 밖 레벨은 버리거나 클램핑한다(손상 세이브 복원).
  static Map<String, int> _decodeHeroLevels(dynamic raw) {
    if (raw is! Map) return <String, int>{};
    final map = <String, int>{};
    for (final entry in raw.entries) {
      final id = entry.key;
      if (id is! String || HeroPool.byId(id) == null) continue;
      final v = (entry.value is num) ? entry.value.toInt() : null;
      if (v == null) continue;
      final level = v.clamp(HeroLevel.minLevel, HeroLevel.maxLevel);
      if (level > HeroLevel.minLevel) map[id] = level;
    }
    return map;
  }

  /// `heroExp` (heroId → 현재 EXP) 역직렬화. 0 이하/비정수 값은 버린다.
  static Map<String, int> _decodeHeroExp(dynamic raw) {
    if (raw is! Map) return <String, int>{};
    final map = <String, int>{};
    for (final entry in raw.entries) {
      final id = entry.key;
      if (id is! String || HeroPool.byId(id) == null) continue;
      final v = (entry.value is num) ? entry.value.toInt() : null;
      if (v == null || v <= 0) continue;
      map[id] = v;
    }
    return map;
  }

  static RuneProgress _fromV1V2(Map<String, dynamic> json) {
    final ownedMap = _decodeElements(json['owned']);
    final partyMap = _decodeElements(json['party']);
    return RuneProgress(
      highestCleared: (json['highestCleared'] as num?)?.toInt() ?? 0,
      gameCurrency: (json['gold'] as num?)?.toInt() ?? 0,
      playCurrency: 0,
      heroCurrency: 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      tutorialCompleted: json['tutorialCompleted'] as bool? ?? false,
      lastDailyRewardDate: null,
      lastPlayedStage: null,
      lastStageVictory: null,
      heroPityCount: 0,
      heroOwned: _idsFromCounts(ownedMap).toSet(),
      heroParty: _idsFromCounts(partyMap),
      ledger: const [],
    );
  }

  static List<String> _idsFromCounts(Map<RuneElement, int> counts) {
    final ids = <String>[];
    for (final e in RuneElement.normal) {
      final heroes = HeroPool.forElement(e);
      final n = (counts[e] ?? 0).clamp(0, heroes.length);
      for (var i = 0; i < n; i++) {
        ids.add(heroes[i].heroId);
      }
    }
    return ids;
  }

  static Map<RuneElement, int> _decodeElements(dynamic raw) {
    final map = <RuneElement, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final e = RuneElement.values
            .where((x) => x.name == entry.key && x.isNormal)
            .firstOrNull;
        if (e != null) map[e] = (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return map;
  }

  static List<String> _sanitizeHeroIds(dynamic raw) {
    if (raw is! List) return const [];
    final ids = <String>[];
    for (final v in raw) {
      final id = v is String ? v : null;
      if (id != null && HeroPool.byId(id) != null && !ids.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  /// `lastPlayedStage` 역직렬화. 키 부재(구 세이브) → null.
  ///
  /// 범위 밖/비정수 값은 버리고 [RuneMeta.maxStage] 로 클램핑한다(손상 세이브 복원).
  static int? _decodeStage(dynamic raw) {
    final v = (raw as num?)?.toInt();
    if (v == null) return null;
    return v.clamp(1, RuneMeta.maxStage);
  }

  /// `heroPityCount` 역직렬화. 음수/임계 초과 값은 클램핑한다.
  static int _decodePity(dynamic raw) {
    final v = (raw as num?)?.toInt() ?? 0;
    return v.clamp(0, heroPityThreshold);
  }

  static List<CurrencyTransaction> _decodeLedger(dynamic raw) {
    if (raw is! List) return const [];
    final list = <CurrencyTransaction>[];
    for (final v in raw) {
      if (v is Map) {
        list.add(CurrencyTransaction.fromJson(Map<String, dynamic>.from(v)));
      }
    }
    return list;
  }
}
