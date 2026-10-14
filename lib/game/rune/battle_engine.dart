/// 배틀 엔진: Turn / Resolve / Monster Turn / Ultimate (RPT-97 ~ RPT-151)
library;

import 'dart:math';

import 'battle_resolve.dart';
import 'battle_damage_stats.dart';
import 'battle_state.dart';
import 'damage.dart';
import 'hero_pool.dart';
import 'hero_roster.dart';
import 'puzzle_board.dart';
import 'puzzle_engine.dart';
import 'hero_skill.dart';
import 'hero_stats.dart';
import 'rune_element.dart';
import 'stage.dart';

class BattleEngine {
  BattleEngine({
    required this.state,
    required this.engine,
    required this.damageCalc,
    Random? rng,
  }) : rng = rng ?? Random();

  /// 테스트/제어를 위한 편의 생성. 보드는 초기 규칙에 맞게 생성한다.
  factory BattleEngine.create({
    required StageConfig stage,
    required HeroRoster roster,
    int baseAttack = 100,
    int partyMaxHp = 100,
    PuzzleBoard? board,
    Random? rng,
    List<RuneHeroDef> partyHeroes = const [],
    List<HeroCombatStats>? heroStats,
  }) {
    final engine = PuzzleEngine(rng: rng);
    // 스크립트 보드(튜토리얼 등)가 주어지면 그대로 사용 (RPT-405).
    final initialBoard =
        board ?? PuzzleBoard.generate(rng: rng);
    // Match-free generation can still produce a board with no legal swap.
    if (board == null && !engine.hasAvailableMove(initialBoard)) {
      engine.shuffleBoard(initialBoard);
    }
    final state = BattleState(
      stage: stage,
      party: roster,
      board: initialBoard,
      partyMaxHp: partyMaxHp,
      baseAttack: baseAttack,
      heroStats: heroStats,
    );
    // 사양 2-1: 1x4 영웅 포트레이트 HUD 를 위한 실제 heroId 유닛 주입.
    // 비어 있으면 [BattleState.units] 가 [roster] 에서 합성 id 로 파생한다.
    // 영웅별 스탯을 주입했다면 그쪽이 정본이므로 여기서 덮어쓰지 않는다.
    if (partyHeroes.isNotEmpty && (heroStats?.isEmpty ?? true)) {
      state.partyUnits = [
        for (final h in partyHeroes)
          PartyHeroUnit(
            heroId: h.heroId,
            element: h.element,
            stats: HeroCombatStats(
              heroId: h.heroId,
              element: h.element,
              hp: h.hp,
              attack: h.attack,
              defense: h.defense,
            ),
          ),
      ];
    }
    return BattleEngine(
      state: state,
      engine: engine,
      damageCalc: const DamageCalculator(),
      // 몬스터 타겟 랜덤도 같은 시드를 쓴다 — 테스트가 결정성을 유지한다.
      rng: rng,
    );
  }

  final BattleState state;
  final PuzzleEngine engine;
  final DamageCalculator damageCalc;

  /// 몬스터/Black 룬의 공격 대상 선정용 RNG.
  ///
  /// 테스트는 시드를 주어 **누가 맞는지까지** 결정적으로 만든다.
  final Random rng;

  /// 파도 몬스터 처치 보상: 살아있는 영웅 전원이 최대 HP의 이 비율만큼 회복한다.
  static const double waveHealRatio = 0.20;

  /// 직전에 몬스터 반격을 맞은 영웅 id (연속 타겟 방지).
  String? _lastTargetHeroId;

  /// UI 연출/로그 참고용 (디버그 포함).
  CascadeResult? lastCascade;

  /// **사양 결정 5**: 유저 1회 Swap에 대한 단일 해석 결과.
  ///
  /// Flame(프레젠테이션)은 이 객체를 받아 `cascadeSteps → heroSkillEvents →
  /// playerDamage → monsterAttackEvent → finalState` 순서로
  /// **재생만** 한다. 자체 계산은 하지 않는다.
  BattleResolveResult? lastResolve;

  bool canUseHeroSkill(String heroId) {
    if (state.paused) return false;
    if (state.phase != BattlePhase.plan && state.phase != BattlePhase.action) {
      return false;
    }
    for (final unit in state.units) {
      if (unit.heroId == heroId) {
        // 쓰러진 영웅은 스킬을 쓸 수 없다 — 회복 스킬도 자기 자신은 못 되살린다.
        if (unit.isDown) return false;
        // 스킬은 영웅 고유다 (속성이 아니라 heroId 기준).
        //
        // **스테이지당 1회.** 전투마다 [BattleState] 가 새로 만들어지므로 스테이지가
        // 바뀌면 자동으로 풀린다. 예전엔 "턴당 1회"로 바꾼 적이 있었는데, 그러면
        // 매 턴 리셋되어 사실상 무한정 쓸 수 있었다.
        return !unit.skillUsed && unit.skill != null;
      }
    }
    return false;
  }

  int get partyHp => state.partyHp;
  int get monsterHp => state.monsterHp;

  // ── Turn ──

  /// 배틀 시작: [1단계] 플레이어 턴 개시.
  void startBattle() => _startPlayerTurn();

  /// 플레이어 턴을 개시한다.
  void _startPlayerTurn() {
    state.phase = BattlePhase.plan;
    state.inputLocked = false;
  }

  /// 몬스터 턴 공격 연출이 끝난 뒤 다음 플레이어 턴을 시작한다.
  void startPlayerTurn() {
    if (state.paused) return;
    _startPlayerTurn();
  }

  // ── 파도 처치 보상 (wave kill reward) ──

  /// 플레이어가 파도 처치 보상으로 스킬을 충전할 영웅을 골랐다.
  ///
  /// [BattleState.skillRechargeCandidates] 에 없는 영웅(안 쓴/쓰러진/스킬 없는
  /// 영웅)이면 아무 일도 하지 않고 false 를 돌려준다. 충전되면 해당 유닛의
  /// [PartyHeroUnit.skillUsed] 를 false 로 되돌려 남은 스테이지에서 다시 쓸 수
  /// 있게 한다 — 스테이지당 1회 제한을 **보상으로만** 푸는 유일한 경로다.
  bool resolveSkillRecharge(String heroId) {
    if (!state.skillRechargePending) return false;
    for (final unit in state.units) {
      if (unit.heroId != heroId) continue;
      if (unit.isDown || !unit.skillUsed || unit.skill == null) return false;
      unit.skillUsed = false;
      state.skillRechargePending = false;
      return true;
    }
    return false;
  }

  /// 플레이어가 파도 처치 보상의 스킬 충전을 건너뛴다.
  void skipSkillRecharge() => state.skillRechargePending = false;

  /// 첫 조작 보조: PLAN → ACTION 전환만 한다.
  void onFirstTouch() {
    if (state.paused) return;
    if (state.phase == BattlePhase.plan) state.phase = BattlePhase.action;
  }

  /// Pointer Down: ACTION → INPUT RESOLVING. (RPT-101 ~ RPT-103)
  ///
  void onDragStart(int tileIndex) {
    if (state.paused) return;
    if (state.phase == BattlePhase.plan) onFirstTouch();
    if (state.phase != BattlePhase.action) return;
    state.phase = BattlePhase.inputResolving;
  }

  /// Pointer Up: Swap 확정 (RPT-103 ~ RPT-111).
  void onDragEnd(PuzzleMove move) {
    if (state.paused) return;
    if (state.phase != BattlePhase.inputResolving &&
        state.phase != BattlePhase.action) {
      return;
    }
    _resolveMove(move);
  }

  /// **Pure Dart Authority 진입점** (사양 결정 5): 유저 1회 Swap을 완전히 해석하고
  /// [BattleResolveResult] 를 반환한다. Flame은 반환된 시퀀스를 재생만 한다.
  ///
  BattleResolveResult resolve(PuzzleMove move) {
    if (state.paused) {
      return _emptyResult(BattleResolveOutcome.invalidSwap);
    }
    if (state.phase != BattlePhase.inputResolving &&
        state.phase != BattlePhase.action &&
        state.phase != BattlePhase.plan) {
      return _emptyResult(BattleResolveOutcome.invalidSwap);
    }
    _resolveMove(move);
    return lastResolve!;
  }

  void pause() {
    if (state.paused) return;
    state.paused = true;
  }

  void resume() {
    if (!state.paused) return;
    state.paused = false;
  }

  /// Player Turn 종료(포기) → Monster Turn.
  ///
  /// 몬스터 반격을 [lastResolve] 에 담아 Flame이 재생하도록 한다 (사양 결정 5).
  void endTurn() {
    if (state.paused) return;
    _beginHeroDamageTracking();
    state.combo = 0;
    _pendMonsterTurn();
    lastResolve = BattleResolveResult(
      outcome: _lastOutcome,
      cascadeSteps: const [],
      heroSkillEvents: const [],
      playerDamage: 0,
      monsterAttackEvent: _lastMonsterAttack,
      finalState: state.snapshot,
      board: state.board,
      // 포기로 엔딩되는 턴이어도 독 틱은 [_runMonsterTurn] 맨 앞에서 이미 돈다.
      // 몬스터 HP 가 실제로 깎였으므로 기록에도 남겨야 "피해 분석"이 어긋나지 않는다.
      monsterHits: _withPoisonTick(const [], _poisonTickHit),
      heroDamageEvents: _pendingHeroDamage,
    );
  }

  void retreat() {
    if (state.paused) return;
    state.phase = BattlePhase.retreat;
  }

  /// 영웅 스킬 실행. **영웅별로 스테이지당 1회.**
  ///
  /// [HeroSkillEffect.needsTarget] 인 스킬(Fire/Light)은 `target` 이 있어야
  /// 발동한다. `target` 이 없거나 그 칸이 유효 타겟이 아니면 **아무 일도 하지
  /// 않고 false** 를 돌린다 — 조준 모드에서 잘못 찍었을 때 턴을 소비하지 않고
  /// 스왑으로 되돌아가게 하기 위함이다.
  bool useHeroSkill(String heroId, {int? target}) {
    if (!canUseHeroSkill(heroId)) return false;
    _beginHeroDamageTracking();
    final unit = state.units.firstWhere(
      (candidate) => candidate.heroId == heroId,
    );
    final spec = unit.skill;
    if (spec == null) return false;

    // 표적 지정 스킬은 대상 칸을 먼저 확정한다. 유효하지 않으면 여기서 끊는다.
    if (spec.needsTarget && !isValidSkillTarget(spec, target)) return false;

    // **스테이지 사용으로 기록** — 횟수 제한의 기준이다. 전투마다 [BattleState] 가
    // 새로 만들어지므로 스테이지가 바뀌면 자동으로 풀린다.
    unit.skillUsed = true;
    state.phase = BattlePhase.resolving;
    state.inputLocked = true;
    state.combo = 0;

    final fired = _fireHeroSkill(spec, heroId: heroId, target: target);
    final rollup = _applyCascadeDamages(
      fired.waves,
      firstWaveSource: MatchSource.cascade,
    );
    state.combo = fired.waves.isEmpty ? 0 : fired.waves.last.combo;
    state.inputLocked = false;
    final outcome = _finishTurnResolve();
    lastCascade = null;
    lastResolve = BattleResolveResult(
      outcome: outcome,
      cascadeSteps: const [],
      heroSkillEvents: [fired.event],
      heroSkillWaves: fired.waves,
      playerDamage: rollup.monsterDamage,
      monsterAttackEvent: _lastMonsterAttack,
      finalState: state.snapshot,
      board: state.board,
      monsterHits: _withPoisonTick(rollup.monsterHits, _poisonTickHit),
      heroDamageEvents: _pendingHeroDamage,
    );
    return true;
  }

  /// [spec] 이 요구하는 표적 지정 대상으로 [target] 칸이 유효한가.
  ///
  /// 조준 모드에서 하이라이트할 대상 목록도 이 규칙으로 산출한다
  /// ([validSkillTargets]) — 유효 판정과 표시가 갈라지면 안 된다.
  bool isValidSkillTarget(HeroSkillSpec spec, int? target) {
    if (!spec.needsTarget) return true;
    if (target == null || target < 0 || target >= PuzzleBoard.size) {
      return false;
    }
    final tile = state.board.cell(target);
    if (tile == null) return false;
    return switch (spec.effect) {
      // Fire: 아무 색이나 골라 그 색 전체를 불로 바꾸되, 이미 불이거나
      // 폭발 오브인 칸은 "굽이 없다"가 아니라 **의미가 없다** — 무효로 막는다.
      HeroSkillEffect.convertColor =>
        tile.rune != spec.convertTo && !tile.isExplosionOrb,
      // Light: 빈칸만 빼고 전부 허용한다.
      HeroSkillEffect.blastArea => true,
      _ => false,
    };
  }

  /// 현재 지정 가능한 표적 칸 목록 (조준 모드 하이라이트용).
  List<int> validSkillTargets(HeroSkillSpec spec) => [
    for (var i = 0; i < PuzzleBoard.size; i++)
      if (isValidSkillTarget(spec, i)) i,
  ];

  // ── 내부 ──

  /// 결과 객체 없이 "아무 일도 없음" 결과 반환용.
  BattleResolveResult _emptyResult(BattleResolveOutcome outcome) =>
      BattleResolveResult(
        outcome: outcome,
        cascadeSteps: const [],
        heroSkillEvents: const [],
        playerDamage: 0,
        monsterAttackEvent: null,
        finalState: state.snapshot,
        board: state.board,
        heroDamageEvents: const [],
      );

  void _resolveMove(PuzzleMove move) {
    state.phase = BattlePhase.resolving;
    state.inputLocked = true;
    _beginHeroDamageTracking();

    lastCascade = engine.resolveSwap(state.board, from: move.from, to: move.to);

    if (lastCascade!.isEmpty) {
      // Invalid Swap: Reverse(엔진이 복원) + Turn 소비 없음 (RPT-108 ~ RPT-109)
      state.phase = BattlePhase.action;
      state.inputLocked = false;
      lastResolve = _emptyResult(BattleResolveOutcome.invalidSwap);
      return;
    }

    // 1) cascadeSteps + 데미지 (콤보 + 속성 시너지)
    final rollup = _applyCascadeDamages(
      lastCascade!.waves,
      firstWaveSource: MatchSource.direct,
    );
    // 요소별 스킬 재설계로 bonusCombo 가 없어져 콤보 가산 버퍼도 제거됐다.
    // 콤보는 캐스케이드가 만든 값을 그대로 쓴다.
    state.combo = lastCascade!.finalCombo;

    final outcome = _finishTurnResolve();

    lastResolve = BattleResolveResult(
      outcome: outcome,
      cascadeSteps: lastCascade!.waves,
      heroSkillEvents: const [],
      playerDamage: rollup.monsterDamage,
      monsterAttackEvent: _lastMonsterAttack,
      finalState: state.snapshot,
      board: state.board,
      monsterHits: _withPoisonTick(rollup.monsterHits, _poisonTickHit),
      heroDamageEvents: _pendingHeroDamage,
    );

    state.inputLocked = false;
  }

  /// 파도별 데미지 누적 결과.
  _DamageRollup _applyCascadeDamages(
    List<WaveResult> waves, {
    required MatchSource firstWaveSource,
  }) {
    var monsterDmg = 0;
    final monsterHits = <DamageHit>[];

    for (var i = 0; i < waves.length; i++) {
      final wave = waves[i];

      for (final run in wave.runs) {
        // 데미지 밑은 **매칭한 색의 살아있는 영웅 ATK 합**이다. 시너지 배율표가
        // 없어도 단색/다색 편성이 자연스럽게 반영된다 — 같은 색 영웅이 많을수록
        // 합이 크고, 다른 색 룬을 맞히면 이 색의 공격력은 전혀 반영되지 않는다.
        final elementAtk = state.attackForElement(run.element);

        // 2페이즈 구조: 매치 위치에 따라 존별 데미지 분배
        final zoneDistribution = _calculateZoneDistribution(run.cells);
        for (final zoneInfo in zoneDistribution) {
          final slot = _slotForZone(zoneInfo.zone);
          if (slot == null || !slot.isAlive) continue;

          final affinity = slot.monster.affinityFor(run.element);
          final dmg = damageCalc.matchDamage(
            elementAttackSum: elementAtk,
            combo: wave.combo,
            affinity: affinity,
          );
          final splitDmg = (dmg * zoneInfo.damageRatio).round();
          if (splitDmg <= 0) continue;

          monsterDmg += splitDmg;
          slot.applyDamage(splitDmg);

          monsterHits.add(
            DamageHit(
              source: DamageSource.match,
              element: run.element,
              damage: splitDmg,
              waveNumber: wave.waveNumber,
              cells: run.cells,
              combo: wave.combo,
              weaknessHit: slot.monster.isWeakAgainst(run.element),
              affinityMultiplier: affinity,
              noElementHero: elementAtk == 0,
            ),
          );
          state.damageStats.record(
            BattleDamageRecord(
              source: BattleDamageSource.runeMatch,
              element: run.element,
              damage: splitDmg,
            ),
          );
        }
      }
    }

    // 페이즈1: 몬스터 3마리 전멸 시 페이즈2(보스) 전환
    if (state.stagePhase == StagePhase.phase1) {
      final allDead = state.monsterSlots.every((s) => !s.isAlive);
      if (allDead) {
        _advanceToPhase2();
      }
    }

    return _DamageRollup(
      monsterDamage: monsterDmg,
      monsterHits: monsterHits,
    );
  }

  /// 매치 위치 → 존 분배 계산
  List<_MatchZoneInfo> _calculateZoneDistribution(List<int> cells) {
    final zoneCount = <ColumnZone, int>{};

    for (final cell in cells) {
      final col = cell % PuzzleBoard.cols;
      final zone = col <= 1
          ? ColumnZone.left
          : col <= 3
              ? ColumnZone.middle
              : ColumnZone.right;
      zoneCount[zone] = (zoneCount[zone] ?? 0) + 1;
    }

    final total = cells.length;
    return zoneCount.entries
        .map((e) => _MatchZoneInfo(
              zone: e.key,
              runeCount: e.value,
              damageRatio: e.value / total,
            ))
        .toList();
  }

  /// 존에 해당하는 몬스터 슬롯 찾기
  MonsterSlot? _slotForZone(ColumnZone zone) {
    for (final slot in state.monsterSlots) {
      if (slot.zone == zone) return slot;
    }
    // **페이즈2(보스 1마리)는 열과 무관하다** — 보드 어디에서 맞혀도 같은 상대
    // 여야 하므로 전부 그 보스에게 보낸다.
    //
    // 페이즈1(좌/중/우 3마리)에서는 이 fallback이 **반드시 없어야 한다**. 있으면
    // "왼쪽 열로 때렸으니 가운데 몬스터는 멀쩡"이라는 보드 규칙이 깨지고,
    // 어느 열을 노려도 같은 몬스터가 맞는 것처럼 보여 세 마리의 상성을 못 쓴다.
    if (state.stagePhase == StagePhase.phase2 && state.monsterSlots.length == 1) {
      return state.monsterSlots.first;
    }
    return null;
  }

  /// 페이즈1 → 페이즈2 전환 (보스 등장)
  void _advanceToPhase2() {
    state.stagePhase = StagePhase.phase2;
    final bossMonster = WaveMonster(
      name: state.stage.monsterName,
      hp: state.stage.monsterHp,
      attack: state.stage.monsterAttack,
      weakElement: state.stage.weakElement,
      resistElement: state.stage.resistElement,
    );
    final bossSlot = MonsterSlot(
      monster: bossMonster,
      zone: ColumnZone.middle,
    );
    bossSlot.initHp();
    state.monsterSlots.clear();
    state.monsterSlots.add(bossSlot);
    state.monsterHp = bossSlot.hp;
    state.monsterMaxHp = bossSlot.maxHp;
    state.bossCountdown = state.stage.bossCountdown;
    // 파도(페이즈1 3마리)를 전멸시킨 보상 — 생존 영웅 회복 + 스킬 1명 충전 대기.
    // 이 전환은 정확히 1회만 일어나므로 보상도 1회다.
    _applyWaveKillReward();
  }

  /// 파도(페이즈) 처치 보상 — 살아있는 영웅 전원 회복 + 스킬 1명 충전 대기.
  ///
  /// 스킬을 이미 쓴 살아있는 영웅이 있을 때만 충전 선택을 대기시킨다
  /// ([BattleState.skillRechargePending]). UI 가 [resolveSkillRecharge] 또는
  /// [skipSkillRecharge] 로 해제한다. [BattleState.waveKillSerial] 을 올려
  /// 화면이 보상을 **한 번만** 처리하게 한다.
  void _applyWaveKillReward() {
    var healed = 0;
    for (final unit in state.livingUnits) {
      healed += unit.heal((unit.maxHp * waveHealRatio).round());
    }
    state.waveKillHeal = healed;
    state.skillRechargePending = state.skillRechargeCandidates.isNotEmpty;
    state.waveKillSerial++;
  }

  /// 살아있는 영웅 중 1명을 **균등 랜덤**으로 고른다.
  ///
  /// 몬스터 반격은 [avoidLast] 를 켜면 직전에 맞은 영웅([_lastTargetHeroId])을
  /// 후보에서 뺀다 — 같은 영웅이 연속으로 맞는 걸 보면 "랜덤"이 아니라 고정
  /// 타겟처럼 읽힌다. 후보가 1명이 되면 그 영웅을 강제한다. 모두 쓰러졌으면 null.
  PartyHeroUnit? _pickLivingUnit({bool avoidLast = false}) {
    final alive = state.livingUnits;
    if (alive.isEmpty) return null;
    if (alive.length == 1) return alive.first;
    if (avoidLast) {
      final prev = _lastTargetHeroId;
      if (prev != null) {
        final pool = alive
            .where((u) => u.heroId != prev)
            .toList(growable: false);
        if (pool.isNotEmpty) return pool[rng.nextInt(pool.length)];
      }
    }
    return alive[rng.nextInt(alive.length)];
  }

  /// 스킬 1건 발동. 효과별 구현으로 분기한다.
  ///
  /// 모든 경로가 (`HeroSkillEvent`, 연쇄 파도) 를 돌려준다. 파도가 비면
  /// ("제거/변환만 하고 매칭이 없음") 연출 계층은 보드를 스냅하고 결과 표기로 넘어간다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _fireHeroSkill(
    HeroSkillSpec spec, {
    required String heroId,
    int? target,
  }) {
    final t = target;
    switch (spec.effect) {
      case HeroSkillEffect.convertColor:
        return t == null
            ? _noopSkill(spec, heroId: heroId)
            : _convertColorOfChosenRune(spec, heroId: heroId, target: t);

      case HeroSkillEffect.damagePerRune:
        return _damagePerRune(spec, heroId: heroId);

      case HeroSkillEffect.healPerRune:
        return _healPerRune(spec, heroId: heroId);

      case HeroSkillEffect.blastArea:
        return t == null
            ? _noopSkill(spec, heroId: heroId)
            : _blastArea(spec, heroId: heroId, target: t);

      case HeroSkillEffect.poisonStacks:
        return _applyPoisonStacks(spec, heroId: heroId);

      case HeroSkillEffect.venomBurst:
        return _venomBurst(spec, heroId: heroId);
    }
  }

  /// 아무 일도 하지 않은 스킬 이벤트 (방어적 폴백).
  ///
  /// [useHeroSkill] 이 표적 지정 스킬의 대상을 먼저 검증하므로 정상 경로에서는
  /// 도달하지 않는다. private 메서드가 스스로 안전하도록 둔다 — 검증이
  /// 빠졌을 때 `null` 역전파로 전투가 죽는 것보다 나쁘지 않다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _noopSkill(
    HeroSkillSpec spec, {
    required String heroId,
  }) => (
    event: HeroSkillEvent(spec: spec, heroId: heroId, amount: 0),
    waves: const [],
  );

  /// **Fire** — [target] 칸의 룬과 **같은 색의 룬을 보드 전량**
  /// [HeroSkillSpec.convertTo] 속성으로 변환한다.
  ///
  /// 누른 칸도 그 색이므로 자연히 포함된다. "전부"가 목적이므로 **상한을 두지
  /// 않는다** — 편향된 보드에서 한 색이 15칸이라도 그대로 태운다.
  ///
  /// **변환 직후 성립한 매칭은 연쇄로 잇는다.**
  ///
  /// 예전엔 `waves: const []` 로 끊어 "셋업 축"(다음 턴에 맞힐 불을 미리 만드는
  /// 값)으로 두었다. 그런데 플레이어 입장에서 결과가 설명되지 않았다 —
  /// 불 3개가 줄지어 있어도 아무 일도 일어나지 않으므로 "스킬이 안 먹혔다"로
  /// 읽힌다. 실제로 변환이 만들어낸 3매칭이 다음 입력에서 터지면서 **스킬을
  /// 쓴 사람이 아니라 다음에 룬을 움직인 사람이 파임을 받는** worse 한 경우도
  /// 생겼다.
  ///
  /// 그래서 변환 → 매칭 검출 → 연쇄를 잇는다. 다만 **데미지는 연쇄에서만 나오고
  /// 변환 자체는 0** 다 — "색을 바꿨다"는 사실과 "맞혀서 때렸다"는 사실을
  /// 분리해서 보여주기 위해 [HeroSkillEvent.amount] 은 계속 **변환한 칸 수**다.
  ///
  /// 칸을 안 지우므로 낙하/리필은 돌리지 않는다([cascadeExistingMatches]).
  ({HeroSkillEvent event, List<WaveResult> waves}) _convertColorOfChosenRune(
    HeroSkillSpec spec, {
    required String heroId,
    required int target,
  }) {
    final to = spec.convertTo;
    final chosen = state.board.cell(target)?.rune;
    if (to == null || chosen == null) return _noopSkill(spec, heroId: heroId);

    final picked = state.board.indicesOf(chosen);
    for (final i in picked) {
      state.board.setIndex(i, BoardTile.rune(to));
    }
    final follow = engine.cascadeExistingMatches(state.board);
    return (
      event: HeroSkillEvent(
        spec: spec,
        heroId: heroId,
        amount: picked.length,
        cells: picked.toSet(),
      ),
      waves: follow.waves,
    );
  }

  /// **Water** — 보드 내 [HeroSkillSpec.countElement] 룬 **개수 × amount** 만큼
  /// 직접 피해.
  ///
  /// **상성도 공격력도 곱하지 않는다.** 이 스킬의 값이 "그 색 룬이 보드에 얼마나
  /// 많이 있는가"이므로, 거기에 영웅 공격력이나 스테이지 상성을 얹으면 플레이어가
  /// 보게 되는 숫자가 "몇 개를 세는가"가 아니라 "영웅이 얼마나 강한가"가 되어
  /// 규칙이 흐려진다. 그래서 고정 피해다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _damagePerRune(
    HeroSkillSpec spec, {
    required String heroId,
  }) {
    final element = spec.countElement ?? spec.element;
    final dmg = state.board.indicesOf(element).length * spec.amount;
    if (dmg > 0) {
      // 페이즈1: 모든 살아있는 몬스터에게 분산 피해
      // 페이즈2: 보스에게 전체 피해
      if (state.stagePhase == StagePhase.phase1) {
        final aliveSlots = state.monsterSlots.where((s) => s.isAlive).toList();
        if (aliveSlots.isNotEmpty) {
          final perSlot = dmg ~/ aliveSlots.length;
          for (final slot in aliveSlots) {
            slot.applyDamage(perSlot);
          }
        }
      } else {
        for (final slot in state.monsterSlots) {
          if (slot.isAlive) {
            slot.applyDamage(dmg);
            break;
          }
        }
      }
      state.damageStats.record(
        BattleDamageRecord(
          source: BattleDamageSource.heroSkill,
          element: spec.element,
          damage: dmg,
          hpBefore: state.monsterHp,
          hpAfter: state.monsterHp,
          hpMax: state.monsterMaxHp,
        ),
      );
    }
    return (
      event: HeroSkillEvent(spec: spec, heroId: heroId, amount: dmg),
      waves: const [],
    );
  }

  /// **Grass** — 보드 내 [HeroSkillSpec.countElement] 룬 개수 × amount 만큼
  /// 파티를 회복시킨다(합산).
  ///
  /// 회복량은 살아있는 유닛에게 **균등 분배**한다(잔여는 파티 순서 앞쪽부터).
  /// [PartyHeroUnit.heal] 이 최대 HP 에서 잘라 주므로 이미 가득 찬 영웅의 몫이
  /// 새지는 않고, 회복 후 실제 깎인 HP 만 [HeroSkillEvent.amount] 에 담긴다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _healPerRune(
    HeroSkillSpec spec, {
    required String heroId,
  }) {
    final living = state.livingUnits;
    if (living.isEmpty) return _noopSkill(spec, heroId: heroId);

    final element = spec.countElement ?? spec.element;
    final pool = state.board.indicesOf(element).length * spec.amount;
    if (pool <= 0) return _noopSkill(spec, heroId: heroId);

    final share = pool ~/ living.length;
    final remainder = pool % living.length;
    var healed = 0;
    for (var i = 0; i < living.length; i++) {
      healed += living[i].heal(i < remainder ? share + 1 : share);
    }
    return (
      event: HeroSkillEvent(spec: spec, heroId: heroId, amount: healed),
      waves: const [],
    );
  }

  /// **Light** — [target] 칸의 **3×3 영역**을 제거하고 낙하/리필/연쇄 매칭을 잇는다.
  ///
  /// 영역 규칙은 폭발 오브 매칭과 **같은** [PuzzleBoard.area3x3] 이다
  /// (모서리 4칸 / 가장자리 6칸 / 중앙 9칸). 직접 피해는 없고 피해는 연쇄
  /// 매칭에서 나오므로, **보드 상태가 좋을수록 이 스킬이 강해진다**.
  ({HeroSkillEvent event, List<WaveResult> waves}) _blastArea(
    HeroSkillSpec spec, {
    required String heroId,
    required int target,
  }) {
    if (state.board.cell(target) == null) {
      return _noopSkill(spec, heroId: heroId);
    }
    final area = PuzzleBoard.area3x3(target);
    final follow = engine.removeAndCascade(state.board, area);
    return (
      event: HeroSkillEvent(
        spec: spec,
        heroId: heroId,
        amount: area.length,
        cells: area,
      ),
      waves: follow.waves,
    );
  }

  /// **Poison (현행)** — 보드 내 [HeroSkillSpec.countElement] 독 룬을 **전부
  /// 제거**하고, 없앤 개수 × amount 만큼 **즉시** 고정 피해를 준다.
  ///
  /// [damagePerRune] 가 룬을 **세기만** 하고 보드를 그대로 두는 것과 달리, 여기서는
  /// 독 룬을 **태워 없앤다** — 제거로 빈 칸이 생겨 낙하/연쇄 매칭이 이어지므로
  /// "개수 비례 즉시 피해 + 보드 재편"이 한 번에 일어난다. 피해는 고정(상성/공격력
  /// 미적용)이라 숫자가 "보드에 독이 몇 개 있었나"를 그대로 말한다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _venomBurst(
    HeroSkillSpec spec, {
    required String heroId,
  }) {
    final element = spec.countElement ?? spec.element;
    final cells = state.board.indicesOf(element).toSet();
    final dmg = cells.length * spec.amount;
    if (dmg > 0) {
      // 페이즈1: 모든 살아있는 몬스터에게 분산 피해
      // 페이즈2: 보스에게 전체 피해
      if (state.stagePhase == StagePhase.phase1) {
        final aliveSlots = state.monsterSlots.where((s) => s.isAlive).toList();
        if (aliveSlots.isNotEmpty) {
          final perSlot = dmg ~/ aliveSlots.length;
          for (final slot in aliveSlots) {
            slot.applyDamage(perSlot);
          }
        }
      } else {
        for (final slot in state.monsterSlots) {
          if (slot.isAlive) {
            slot.applyDamage(dmg);
            break;
          }
        }
      }
      state.damageStats.record(
        BattleDamageRecord(
          source: BattleDamageSource.heroSkill,
          element: spec.element,
          damage: dmg,
          hpBefore: state.monsterHp,
          hpAfter: state.monsterHp,
          hpMax: state.monsterMaxHp,
        ),
      );
    }
    // 독 룬을 태워 없애고 낙하/연쇄를 잇다 ([_blastArea] 와 같은 경로).
    // 태울 룬이 없으면 피해 0 이벤트만 남긴다 (Water 와 동일하게 소모는 된다).
    if (cells.isEmpty) {
      return (
        event: HeroSkillEvent(spec: spec, heroId: heroId, amount: dmg),
        waves: const [],
      );
    }
    final follow = engine.removeAndCascade(state.board, cells);
    return (
      event: HeroSkillEvent(
        spec: spec,
        heroId: heroId,
        amount: dmg,
        cells: cells,
      ),
      waves: follow.waves,
    );
  }

  /// **Poison (예약)** — 보드 내 독 룬 개수만큼 몬스터에 독 스택을 붙인다.
  ///
  /// 지금 쓰는 영웅이 없다(현행 독 영웅은 [_venomBurst]). 다른 독 영웅을 도입할 때
  /// 재사용할 수 있도록 구현만 남겨 둔다.
  ///
  /// 스택은 [_runMonsterTurn] 맨 앞에서 `스택 × [BattleState.poisonPerStack]`
  /// 만큼 계속 깎고 **소진되지 않는다**. 상한 [HeroSkills.maxPoisonStacks] 까지만
  /// 쌓인다 — 폭발형 스킬과 달리 시간이 쌓일수록 위험해지는 축이라 나머지 요소와
  /// 겹치지 않는다.
  ({HeroSkillEvent event, List<WaveResult> waves}) _applyPoisonStacks(
    HeroSkillSpec spec, {
    required String heroId,
  }) {
    final element = spec.countElement ?? spec.element;
    final before = state.poisonStacks;
    state.poisonStacks = min(
      HeroSkills.maxPoisonStacks,
      before + state.board.indicesOf(element).length,
    );
    // 스택당 피해는 **처음 걸릴 때만** 기록한다. 이미 걸린 스택의 피해가 나전
    // 시전으로 조용히 바뀌면 플레이어가 "왜 이번 턴엔 더 적게 맞았지"로 읽는다.
    if (before == 0) state.poisonPerStack = spec.amount;
    return (
      event: HeroSkillEvent(
        spec: spec,
        heroId: heroId,
        amount: state.poisonStacks - before,
      ),
      waves: const [],
    );
  }

  /// 최종 상태 판정 + 몬스터 턴 전이. [BattleResolveOutcome] 반환.
  BattleResolveOutcome _finishTurnResolve() {
    // 최종 상태 판정 (RPT-147). Monster 사망 Victory 우선 (RPT-146).
    // 페이즈1: 몬스터 3마리 전멸 시 페이즈2로 전환
    if (state.stagePhase == StagePhase.phase1) {
      final allDead = state.monsterSlots.every((s) => !s.isAlive);
      if (allDead) {
        _advanceToPhase2();
        state.combo = 0;
        state.phase = BattlePhase.plan;
        state.inputLocked = false;
        _lastMonsterAttack = null;
        _lastOutcome = BattleResolveOutcome.continued;
        return _lastOutcome;
      }
    }

    // 페이즈2: 보스 처치 시 승리
    if (state.stagePhase == StagePhase.phase2) {
      final bossDead = state.monsterSlots.every((s) => !s.isAlive);
      if (bossDead) {
        state.phase = BattlePhase.victory;
        _lastMonsterAttack = null;
        return BattleResolveOutcome.victory;
      }
    }

    if (state.partyWiped) {
      state.phase = BattlePhase.defeat;
      _lastMonsterAttack = null;
      return BattleResolveOutcome.defeat;
    }
    _pendMonsterTurn();
    return _lastOutcome;
  }

  void _pendMonsterTurn() {
    state.phase = BattlePhase.monsterTurn;
    _runMonsterTurn();
  }

  void _runMonsterTurn() {
    _lastMonsterAttack = null;
    _applyPoisonTick();

    // 독이 마지막 HP 를 깎았으면 **반격 없이** 처리한다. 보스 궁극기도 못 쓴다
    // — 지속 피해가 "늦어도 결국 죽는다"를 남겨야 독 스택이 아깝지 않다.
    final anyAlive = state.monsterSlots.any((s) => s.isAlive);
    if (!anyAlive) {
      if (state.stagePhase == StagePhase.phase1) {
        _advanceToPhase2();
        state.combo = 0;
        state.phase = BattlePhase.plan;
        state.inputLocked = false;
        _lastOutcome = BattleResolveOutcome.continued;
        return;
      }
      state.phase = BattlePhase.victory;
      _lastOutcome = BattleResolveOutcome.victory;
      return;
    }

    // 페이즈2(보스) 전용: 궁극기 카운트다운
    if (state.stagePhase == StagePhase.phase2 && state.stage.isBoss) {
      state.bossCountdown--;
      if (state.bossCountdown <= 0) {
        _executeBossUltimate();
        return;
      }
      if (state.bossCountdown == 1) {
        state.bossUltimateWarning = true;
      }
    }

    // 페이즈1: 살아있는 몬스터 3마리 각각 공격
    // 페이즈2: 보스 1마리 공격
    final aliveSlots = state.monsterSlots.where((s) => s.isAlive).toList();
    for (final slot in aliveSlots) {
      _executeMonsterAttack(slot);
      if (state.partyWiped) {
        state.phase = BattlePhase.defeat;
        _lastOutcome = BattleResolveOutcome.defeat;
        return;
      }
    }

    state.combo = 0;
    state.phase = BattlePhase.plan;
    state.inputLocked = false;
    _lastOutcome = BattleResolveOutcome.continued;
  }

  /// 보스 궁극기 실행
  void _executeBossUltimate() {
    final focus = _pickLivingUnit(avoidLast: true);
    for (final unit in state.livingUnits) {
      final hpBefore = unit.hp;
      final ultimateDamage = min(
        state.stage.bossUltimateDamage,
        (unit.maxHp * 0.8).round(),
      );
      final lost = unit.applyDamage(ultimateDamage);
      if (lost > 0) {
        _pendingHeroDamage.add(
          HeroDamageEvent(
            heroId: unit.heroId,
            damage: lost,
            source: HeroDamageSource.bossUltimate,
            element: null,
            waveNumber: HeroDamageEvent.monsterTurnWave,
          ),
        );
      }
      state.damageStats.record(
        BattleDamageRecord(
          source: BattleDamageSource.bossUltimate,
          element: null,
          damage: lost,
          hpBefore: hpBefore,
          hpAfter: unit.hp,
          hpMax: unit.maxHp,
        ),
      );
    }
    state.bossUltimateWarning = false;
    _lastMonsterAttack = MonsterAttackEvent(
      damage: 0,
      bossCountdownAfter: state.bossCountdown,
      isBossUltimate: true,
      targetHeroId: focus?.heroId,
    );
    if (state.partyWiped) {
      state.phase = BattlePhase.defeat;
      _lastOutcome = BattleResolveOutcome.defeat;
      return;
    }
    state.bossCountdown = state.stage.bossCountdown;
    state.combo = 0;
    state.phase = BattlePhase.plan;
    state.inputLocked = false;
    _lastOutcome = BattleResolveOutcome.continued;
  }

  /// 개별 몬스터 공격 실행
  void _executeMonsterAttack(MonsterSlot slot) {
    final target = _pickLivingUnit(avoidLast: true);
    if (target == null) {
      state.phase = BattlePhase.defeat;
      _lastOutcome = BattleResolveOutcome.defeat;
      return;
    }
    _lastTargetHeroId = target.heroId;
    final breakdown = damageCalc.incomingDamage(
      attack: slot.monster.attack,
      defenderDefense: target.defense,
    );
    final hpBefore = target.hp;

    final damage = state.stage.isBoss && state.stagePhase == StagePhase.phase2
        ? min(breakdown.damage, (target.maxHp * 0.8).round())
        : breakdown.damage;

    final lost = target.applyDamage(damage);
    if (lost > 0) {
      _pendingHeroDamage.add(
        HeroDamageEvent(
          heroId: target.heroId,
          damage: lost,
          source: HeroDamageSource.monsterAttack,
          element: null,
          waveNumber: HeroDamageEvent.monsterTurnWave,
        ),
      );
    }
    state.damageStats.record(
      BattleDamageRecord(
        source: BattleDamageSource.monsterAttack,
        element: null,
        damage: lost,
        incoming: breakdown,
        hpBefore: hpBefore,
        hpAfter: target.hp,
        hpMax: target.maxHp,
      ),
    );
    _lastMonsterAttack = MonsterAttackEvent(
      damage: lost,
      bossCountdownAfter: state.bossCountdown,
      isBossUltimate: false,
      breakdown: breakdown,
      targetHeroId: target.heroId,
      targetHpBefore: hpBefore,
      targetHpAfter: target.hp,
      targetMaxHp: target.maxHp,
    );
  }

  /// 직전 몬스터 반격/최종 판정(내부 전달용).
  MonsterAttackEvent? _lastMonsterAttack;
  BattleResolveOutcome _lastOutcome = BattleResolveOutcome.continued;

  /// 이번 해석(1회 입력) 동안 **실제로 HP 를 잃은** 영웅들의 피격 내역.
  ///
  /// HP 를 깎는 세 지점([_applyPartyHits] · [_runMonsterTurn] 반격 ·
  /// [_runMonsterTurn] 보스 궁극기)이 여기에 push 하고, 결과 객체를 만들 때
  /// [BattleResolveResult.heroDamageEvents] 로 넘긴 뒤 비운다.
  ///
  /// 예측값이 아니라 [PartyHeroUnit.applyDamage] 반환값만 담는다 — 직전 턴
  /// 이벤트가 새 턴에 새어 나오면 "떴는데 HP 가 안 줄었다" 는 버그가 된다.
  final List<HeroDamageEvent> _pendingHeroDamage = [];

  /// [_pendingHeroDamage] 를 이번 입력 기준으로 비운다.
  ///
  /// HP 차감은 전부 이 세 진입점(스왑/영웅 스킬/턴 종료) 아래에만 있으므로
  /// 여기서만 초기화해도 빠지는 경로가 없다. [_poisonTickHit] 도 함께 비운다 —
  /// 몬스터 턴이 돌지 않은 경로(무효 스왑)에서 지난 턴의 독 틱이 새 결과에 섞이면
  /// 안 된다.
  void _beginHeroDamageTracking() {
    _pendingHeroDamage.clear();
    _poisonTickHit = null;
  }

  /// 이번 몬스터 턴의 독 틱 타격 ([DamageSource.poisonTick]).
  ///
  /// [_applyPoisonTick] 이 채우고, 결과를 만드는 지점들이 읽어 버린다. 직접 피해
  /// 스킬과 달리 `monsterHits` 로 실려야 합계/기록에 정상 편입된다.
  DamageHit? _poisonTickHit;

  /// **독 스택 지속 피해** — 매 몬스터 턴 1회, [_runMonsterTurn] 맨 앞에서 돈다.
  ///
  /// ```
  /// 피해 = 독 스택 수 × 스택당 피해   (스택은 소진되지 않는다)
  /// ```
  ///
  /// 매칭/직접 피해와 달리 **반복형**이라 매 턴 새 타격 1건으로 쌓인다. 스택이
  /// 그대로 남아 있으므로 시간이 갈수록 누적 피해가 커진다 — Poison 의 정체성이다.
  void _applyPoisonTick() {
    final tick = state.poisonTickDamage;
    if (tick <= 0) return;

    // 페이즈1: 모든 살아있는 몬스터에게 분산
    // 페이즈2: 보스에게 전체
    if (state.stagePhase == StagePhase.phase1) {
      final aliveSlots = state.monsterSlots.where((s) => s.isAlive).toList();
      if (aliveSlots.isNotEmpty) {
        final perSlot = tick ~/ aliveSlots.length;
        for (final slot in aliveSlots) {
          slot.applyDamage(perSlot);
        }
      }
    } else {
      for (final slot in state.monsterSlots) {
        if (slot.isAlive) {
          slot.applyDamage(tick);
          break;
        }
      }
    }

    state.damageStats.record(
      BattleDamageRecord(
        source: BattleDamageSource.poisonTick,
        element: RuneElement.poison,
        damage: tick,
        hpBefore: state.monsterHp,
        hpAfter: state.monsterHp,
        hpMax: state.monsterMaxHp,
      ),
    );
    _poisonTickHit = DamageHit(
      source: DamageSource.poisonTick,
      element: RuneElement.poison,
      damage: tick,
    );
  }

  /// 캐스케이드 데미지 목록에 독 틱을 덧붙인다. 없으면 원본을 그대로 준다.
  static List<DamageHit> _withPoisonTick(
    List<DamageHit> hits,
    DamageHit? tick,
  ) => tick == null ? hits : [...hits, tick];
}

/// 파도 데미지 누적 결과.
class _DamageRollup {
  _DamageRollup({
    required this.monsterDamage,
    required this.monsterHits,
  });

  /// 유저가 준 피해(콤보 + 속성 시너지 반영).
  final int monsterDamage;

  /// [monsterDamage]의 1건 단위 내역.
  final List<DamageHit> monsterHits;
}

/// 매치의 존 분배 정보
class _MatchZoneInfo {
  _MatchZoneInfo({
    required this.zone,
    required this.runeCount,
    required this.damageRatio,
  });

  final ColumnZone zone;
  final int runeCount;
  final double damageRatio;
}
