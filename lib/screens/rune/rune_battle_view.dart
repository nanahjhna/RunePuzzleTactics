/// Rune Puzzle Tactics — 배틀 화면 (PHASE 4 UI + PHASE 5 저장/분석)
///
/// Flutter HUD(HP/영웅 스킬) + Flame GameWidget(보드)를 합성한다.
/// 상태는 모두 BattleEngine의 BattleState에서 읽는다 (RPT-126).
///  - 레인보우 오브 선택 (RPT-73 ~ RPT-76)
///  - 승리/패배/일시정지/이탈 다이얼로그 (RPT-123, RPT-146 ~ RPT-148)
///  - 진행도 저장/분석 이벤트 (PHASE 5, RPT-316 / RPT-308 ~ RPT-309)
///  - 콤보 연출 훅: HapticFeedback(티어별) + SystemSound (RPT-81 강화)
///
/// 화면 골격(배경/SafeArea/세로 배치)과 HUD(상단바·몬스터 영역·영웅 포트레이트 행)는
/// [battle_hud.dart]에 있고, 튜토리얼 화면과 **공유**한다(요구사항 9). 여기 남는
/// 것은 전투 특유의 것뿐이다: ReadyGO/승패/일시정지 오버레이, 결과 라우트, 진입 비용.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../l10n/language_controller.dart';
import '../../services/game_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/hero_hit_flash.dart';
import '../../widgets/play_shortage_dialog.dart';
import '../../widgets/rewarded_ad_helper.dart';
import 'battle_hud.dart';
import 'rune_battle_game.dart';
import 'package:rune_puzzle_tactics/widgets/monster_sprite.dart';
import 'rune_result_screen.dart';

/// Rune 배틀 진입 화면. 연속 스테이지를 이어서 플레이한다.
class RuneBattleView extends StatefulWidget {
  const RuneBattleView({
    super.key,
    this.startStage = 1,
    this.engine,
    this.rng,
    this.store,
    this.analytics,
    this.audioService,
    this.roster,
    this.onShopRequested,
  });

  final int startStage;

  /// 테스트/디버그 주입용 (null이면 StageGenerator + 파티 기반 생성).
  final BattleEngine? engine;

  /// 보드 생성용 RNG (테스트 결정성).
  final math.Random? rng;

  /// 진행도 저장소 (null이면 저장 비활성 — 직접 진입/테스트).
  final RuneProgressStore? store;

  /// 분석 이벤트 (null이면 no-op).
  final RuneAnalytics? analytics;
  final GameAudioService? audioService;

  /// 초기 파티 오버라이드 (디버그/테스트용).
  final HeroRoster? roster;

  /// 요구사항 6.4: 결과 화면이 popUntil로 배틀 라우트까지 정리할 때
  /// '상점으로' 의도를 메인 허브로 전달하는 콜백(라우터 플래그).
  final VoidCallback? onShopRequested;

  @override
  State<RuneBattleView> createState() => _RuneBattleViewState();
}

class _RuneBattleViewState extends State<RuneBattleView> {
  int _stage = 1;
  int _runId = 0;
  HeroRoster? _roster;
  RuneProgress? _progress;
  bool _loading = true;

  /// 직전 전투에서 오른 레벨(결과 화면 알림용). 승리 확정 시 채워진다.
  List<HeroLevelUp> _lastLevelUps = const [];

  /// 승리 EXP 반영 후의 영웅별 전투 스탯(결과 화면 표시용).
  ///
  /// 전투 시작 시 주입한 스탯은 레벨업 이전 값이므로, 결과 화면에는 이 값을 쓴다.
  List<HeroCombatStats> _lastPostBattleStats = const [];

  @override
  void initState() {
    super.initState();
    _stage = widget.startStage;
    _roster = widget.roster;
    _bootstrap();
  }

  /// 저장된 진행도가 있으면 파티/다음 스테이지를 복원한다 (RPT-316).
  Future<void> _bootstrap() async {
    var roster = widget.roster;
    var stage = widget.startStage;
    final store = widget.store;
    if (store != null) {
      try {
        final progress = await store.load();
        roster ??= progress.toRoster();
        _progress = progress;
        // 사양 1-1 Stage Selector: 호출부가 **선택한** 스테이지를 존중한다.
        // "최고 클리어 + 1 로 이어가기" 폴백은 아무것도 클리어하지 않은
        // 진짜 최초 진입(最高 클리어 0)에만 적용한다 — 그래야 로비에서
        // 1스테이지를 일부러 골라 재플레이할 수 있다.
        if (widget.startStage == 1 && progress.highestCleared == 0) {
          stage = progress.nextStage;
        }
      } catch (e, st) {
        widget.analytics?.recordError(e, st, context: 'rune progress load');
      }
    }
    if (!mounted) return;
    setState(() {
      _roster = roster ?? HeroRoster.initial();
      _stage = stage.clamp(1, RuneMeta.maxStage);
      _loading = false;
    });
  }

  /// 재시도/다음 스테이지 진입: Play Currency(입장 비용, §19)를 1회 소모 후 재생.
  /// 소모 성공 시 true, Play 부족 시 false를 반환한다 (호출부가 안내 처리).
  Future<bool> _newRun({required bool nextStage}) async {
    final store = widget.store;
    if (store != null) {
      final current = _progress ?? RuneProgress();
      final entry = current.tryStageEntry(
        RuneMeta.stageEntryCost,
        txId: 'entry_run_${current.nextStage}_run$_runId',
      );
      if (!entry.ok) return false;
      _progress = entry.progress;
      try {
        await store.save(entry.progress);
      } catch (e, st) {
        widget.analytics?.recordError(e, st, context: 'rune progress save');
        widget.analytics?.logSaveError('rune_progress_save', e);
        return false;
      }
    }
    if (!mounted) return false;
    setState(() {
      _runId++;
      // 사양 결정 1: 절대 상한(RuneMeta.maxStage)을 넘지 않도록 클램핑한다.
      if (nextStage) _stage = (_stage + 1).clamp(1, RuneMeta.maxStage);
    });
    return true;
  }

  /// 승/패 확정 시: 진행도 갱신(+승리 EXP/레벨업) → 저장 → 분석 (RPT-316, RPT-308).
  Future<void> _applyBattleResult({
    required bool win,
    required int stageNumber,
    required int gameReward,
  }) async {
    final store = widget.store;
    if (store != null) {
      final current = _progress ?? RuneProgress();
      var updated = win
          ? current.recordClear(
              stageNumber,
              gameReward,
              txId: 'stage_clear_${stageNumber}_run$_runId',
            )
          : current.recordDefeat(stageNumber: stageNumber);
      // 승리 보상 EXP: 편성 영웅 전원에게 스테이지 비례 지급(패배는 없음).
      // 같은 전투에서 여러 레벨이 오를 수 있고, 그 결과를 결과 화면에 넘긴다.
      var levelUps = const <HeroLevelUp>[];
      if (win) {
        final granted = updated.grantPartyExp(
          HeroLevel.expForVictory(stageNumber),
        );
        updated = granted.progress;
        levelUps = granted.levelUps;
      }
      _progress = updated;
      // 결과 화면은 레벨업 반영 후 스탯을 보여줘야 하므로 여기서 미리 계산해 둔다.
      _lastLevelUps = levelUps;
      _lastPostBattleStats = [
        for (final h in updated.partyHeroDefs)
          updated.heroCombatStatsOf(h.heroId),
      ];
      try {
        await store.save(updated);
      } catch (e, st) {
        widget.analytics?.recordError(e, st, context: 'rune progress save');
        widget.analytics?.logSaveError('rune_progress_save', e);
      }
      if (mounted) setState(() {});
    }
    final an = widget.analytics;
    if (an != null) {
      if (win) {
        an.logVictory(stage: stageNumber, gameReward: gameReward);
      } else {
        an.logDefeat(stage: stageNumber);
      }
    }
  }

  /// 재화 부족 팝업의 [보상형 광고 보기]용 Play 충전 (요구사항 3.1).
  ///
  /// 멱등 txId('ad_dialog_play_' + 타임스탬프)로 중복 지급을 차단하고, 이후
  /// [newRun]의 원장 기록/저장에 자연스럽게 반영되도록 `_progress`만 갱신한다.
  bool _grantRewardedAdPlay() {
    final store = widget.store;
    if (store == null) return false;
    final current = _progress ?? RuneProgress();
    final r = current.claimRewardedAd(
      txId: 'ad_dialog_play_${DateTime.now().millisecondsSinceEpoch}',
      type: CurrencyType.play,
      amount: RuneMeta.rewardedAdPlay,
    );
    if (!r.applied) return false;
    _progress = r.progress;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 영웅 **개별** 스탯에서 파티 전투력을 낸다 (RPT-397 ~ RPT-399).
    // 합산 컨테이너를 없앴으므로 영웅별 HP/ATK 를 더해 합계를 얻는다.
    final perHero = _progress?.heroCombatStats ?? const <HeroCombatStats>[];
    final baseAttack = perHero.fold<int>(0, (sum, h) => sum + h.attack);
    final partyMaxHp = perHero.fold<int>(0, (sum, h) => sum + h.hp);
    return _RuneBattleScreen(
      key: ValueKey('rune-run-$_runId'),
      stageNumber: _stage,
      engine: widget.engine,
      rng: widget.rng,
      roster: _roster,
      // 사양 2-1: 1x4 포트레이트 HUD용 실제 영웅 목록(저장된 파티 편성).
      partyHeroes: _progress?.partyHeroDefs ?? const [],
      // 영웅 **개별** 스탯 (파티 보너스 균등 분배 반영) — 몬스터 타겟팅에 쓰인다.
      heroStats: perHero,
      baseAttack: baseAttack,
      partyMaxHp: partyMaxHp,
      // 요구사항 6.3: 결과 화면에서 [다음]/[다시 도전] 시 Play 재화 사전 검증용
      // 현재 잔액(입장 비용 소모 후 기준). store가 없으면(직접 진입/테스트)
      // 검증을 생략하도록 null을 전달한다.
      playCurrency: _progress?.playCurrency,
      onShopRequested: widget.onShopRequested,
      analytics: widget.analytics,
      audioService: widget.audioService,
      onRetry: () => _newRun(nextStage: false),
      onNextStage: () => _newRun(nextStage: true),
      onRewardAdPlay: _grantRewardedAdPlay,
      onBattleResult: _applyBattleResult,
      levelUps: _lastLevelUps,
      postBattleHeroStats: _lastPostBattleStats,
    );
  }
}

/// 한 번의 배틀(단일 스테이지)을 소유하고 재생한다.
class _RuneBattleScreen extends StatefulWidget {
  const _RuneBattleScreen({
    super.key,
    required this.stageNumber,
    this.engine,
    this.rng,
    this.roster,
    this.partyHeroes = const [],
    this.heroStats = const [],
    this.baseAttack = RuneMeta.baseAttack,
    this.partyMaxHp = RuneMeta.basePartyMaxHp,
    this.playCurrency,
    this.onShopRequested,
    this.analytics,
    this.audioService,
    this.onRetry,
    this.onNextStage,
    this.onRewardAdPlay,
    this.onBattleResult,
    this.levelUps = const [],
    this.postBattleHeroStats = const [],
  });

  final int stageNumber;
  final BattleEngine? engine;
  final math.Random? rng;
  final HeroRoster? roster;

  /// 편성된 파티 영웅(heroId 단위) — 1x4 포트레이트 HUD 용 (사양 2-1).
  final List<RuneHeroDef> partyHeroes;

  /// 영웅별 개인 전투 스탯 (파티 보너스 균등 분배 반영).
  ///
  /// 비어 있으면 엔진이 [partyHeroes] 의 원본 능력치를 쓰고, 그것도 없으면
  /// 합산 스탯을 균등 분배한 폴백 수치를 쓴다.
  final List<HeroCombatStats> heroStats;

  /// 영구 업그레이드 반영 파티 공격력 (RPT-397).
  final int baseAttack;

  /// 편성 영웅 개별 강화 반영 파티 최대 체력.
  final int partyMaxHp;

  /// 요구사항 6.3: 결과 화면의 [다음]/[다시 도전] 사전 검증용 Play 잔액.
  /// null이면(저장소 없는 직접 진입/테스트) 검증을 생략한다.
  final int? playCurrency;

  /// 요구사항 6.4: '상점으로' 의도를 허브로 전달하는 콜백 (popUntil 대량 정리 시).
  final VoidCallback? onShopRequested;

  final RuneAnalytics? analytics;
  final GameAudioService? audioService;

  /// 재시도/다음 스테이지 진입. Play Currency 입장 비용 소모 여부를 반환한다.
  final Future<bool> Function()? onRetry;
  final Future<bool> Function()? onNextStage;

  /// 재화 부족 팝업의 [보상형 광고 보기]에서 Play를 충전한다 (요구사항 3.1).
  final bool Function()? onRewardAdPlay;

  /// 승/패가 확정되는 시점(다이얼로그 표시 직전)에 1회 호출.
  final void Function({
    required bool win,
    required int stageNumber,
    required int gameReward,
  })?
  onBattleResult;

  /// 이번 전투에서 오른 레벨(결과 화면 알림). 승리 아니면 빈 목록.
  final List<HeroLevelUp> levelUps;

  /// 승리 EXP/레벨업 반영 후의 영웅별 스탯(결과 화면 표시). 비면 전투 스탯 폴백.
  final List<HeroCombatStats> postBattleHeroStats;

  @override
  State<_RuneBattleScreen> createState() => _RuneBattleScreenState();
}

class _RuneBattleScreenState extends State<_RuneBattleScreen>
    with WidgetsBindingObserver {
  late final BattleEngine _battle;
  late final RuneBattleGame _game;
  GameAudioService get _audioService =>
      widget.audioService ?? GameAudioService.instance;

  /// 몬스터 턴/결과 전환 시 보드 그레이아웃(요청: 턴 인디케이터 제거 대체) 필터.
  static final ColorFilter _grayFilter = ColorFilter.matrix(const <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  final ValueNotifier<int> _hud = ValueNotifier<int>(0);

  bool _dialogShown = false;
  bool _paused = false;

  /// 요구사항 6.1: 진입 직후 'Ready... GO!' 카운트다운(1.5초) 동안 false.
  /// false인 동안은 Flame 엔진과 보드 입력을 잠가 조작을 막는다.
  bool _ready = false;
  Timer? _readyTimer;

  /// 요구사항 6.2: 승/패 확정 후 1.5초 연출 버퍼 동안 표시할 phase
  /// (null이면 연출 버퍼 아님 / null로 돌아가면 결과 화면이 곧 열린다).
  BattlePhase? _resultPhase;

  /// 승/패 연출 버퍼(요구사항 6.2) 타이머. dispose 시 해제.
  Timer? _endBufferTimer;
  Timer? _partyDamageFlashTimer;

  int _lastPartyHp = 0;
  int _partyDamageFlashTicks = 0;
  bool _partyDamageFlashVisible = false;

  /// **속성 영웅 없음 경고** — 매치는 했는데 그 색 살아있는 영웅이 없어
  /// 데미지가 0이었을 때 몬스터 중앙에 띄운다. null 이면 표시 안 함.
  RuneElement? _noElementHeroWarning;
  Timer? _noElementHeroTimer;

  /// 마지막 [_onHud] 시점의 [_isPlayerTurn] / [_game.isIdle].
  ///
  /// HUD 는 이 두 값을 **생성자 인자로 캡처**한다
  /// ([BattleHudRows.isPlayerTurn] / [BattleHudRows.canUseSkill]).
  /// [_hud] 알림은 `BattleHudRows` 의 `AnimatedBuilder` 만 다시 그리므로
  /// 이 값들은 이 화면의 `build()` 가 다시 돌아야 갱신된다. 그런데 [_onHud]
  /// 가 `setState` 를 부르지 않으면, 몬스터 턴 중에 실행된 `setState`
  /// (`_pumpHitQueue` / `_flashPartyDamage`) 가 캡처한 `false` 가 그대로 남아
  /// **다음 플레이어 턴 전체가 톤 다운 + 스킬 비활성**으로 굳는다.
  ///
  /// 그래서 여기서 두 값이 바뀔 때마다 `setState` 로 한 번 더 밀어 준다.
  /// 값이 그대로면 `setState` 를 부르지 않는다 — 재생 중 매 프레임이 아니라
  /// "전환이 실제로 일어난 순간"에만 한 번이다.
  bool? _lastPlayerTurn;
  bool? _lastIdle;

  /// 영웅 피격 이벤트 큐. [BattleEngine] 에서 수집한 [HeroDamageEvent] 를
  ///_ui가 순차 재생할 때까지 버퍼링한다. 연속 피격은 [_hitGap] 간격, 마지막
  /// 피격은 [HeroHitFlash.animDuration] 만큼 재생한다.
  ///
  /// 520ms 는 [HeroHitFlash.impactHold] + 페이드 시작 구간을 확보한 값이다.
  /// 예전 380ms 는 연출이 900ms 인 시점에서 앞 42% 만 보여서, 보스 궁극기처럼
  /// 복수가 한꺼번에 맞을 때 "몇 명이 맞았는지"가 안 읽혔다.
  static const Duration _hitGap = Duration(milliseconds: 520);

  final List<HeroDamageEvent> _hitQueue = [];
  int _hitToken = 0;
  ({String heroId, int token, int damage})? _activeHit;
  Timer? _hitTimer;

  @override
  void initState() {
    super.initState();
    _battle =
        widget.engine ??
        BattleEngine.create(
          stage: StageGenerator().generate(widget.stageNumber),
          roster: widget.roster ?? HeroRoster.initial(),
          baseAttack: widget.baseAttack,
          partyMaxHp: widget.partyMaxHp,
          rng: widget.rng,
          partyHeroes: widget.partyHeroes,
          heroStats: widget.heroStats,
        );
    _battle.startBattle();
    _lastPartyHp = _battle.state.partyHp;
    _game = RuneBattleGame(
      battle: _battle,
      onHudChanged: _onHud,
      onComboEffect: _onComboEffect,
      onHeroDamage: _onHeroDamage,
      onNoElementHero: _onNoElementHero,
    );
    widget.analytics?.logBattleStart(_battle.state);
    WidgetsBinding.instance.addObserver(this);
    // 요구사항 6.1: 전투 화면 진입 직후 1.5초 'Ready... GO!' 카운트다운 시작.
    _startReadyCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readyTimer?.cancel();
    _endBufferTimer?.cancel();
    _partyDamageFlashTimer?.cancel();
    _hitTimer?.cancel();
    _noElementHeroTimer?.cancel();
    _hud.dispose();
    super.dispose();
  }

  /// 요구사항 6.1: 카운트다운 동안 Flame 엔진을 멈춘 뒤 1.5초 후 재개한다.
  /// 조작 잠금은 빌드의 IgnorePointer(!_ready)가 담당한다.
  void _startReadyCountdown() {
    _game.pauseEngine();
    _readyTimer = Timer(const Duration(milliseconds: 1500), () {
      _readyTimer = null;
      if (!mounted) return;
      // 일시정지 오버레이가 동시에 떠 있으면 엔진은 일시정지가 유지된다.
      if (!_paused) _game.resumeEngine();
      setState(() => _ready = true);
      _hud.value++;
    });
  }

  void _onHud() {
    if (!mounted) return;
    final partyHp = _battle.state.partyHp;
    if (partyHp < _lastPartyHp) _flashPartyDamage();
    _lastPartyHp = partyHp;
    _hud.value++;
    // HUD 슬롯이 받는 `active`(= [_isPlayerTurn]) 와 `canUseSkill`
    // (= `_ready && isIdle`) 는 이 화면 `build()` 가 만든 인자로 캡처되어 있다.
    // 이 둘이 바뀔 때마다 한 번 더 밀어 주지 않으면, 직전 몬스터 턴 중에 실행된
    // `setState` 가 캡처한 `false` 가 플레이어 턴 내내 고정된다 — 그 결과가
    // "파티 전원 톤 다운 + 스킬 탭 불가" 다.
    final playerTurn = _isPlayerTurn;
    final idle = _game.isIdle;
    if (playerTurn != _lastPlayerTurn || idle != _lastIdle) {
      _lastPlayerTurn = playerTurn;
      _lastIdle = idle;
      setState(() {});
    }
    _maybeShowEndResult();
  }

  /// 속성 영웅 없음 경고 발화 — 몬스터 중앙에 경고를 띄우고 일정 시간 뒤 숨긴다.
  void _onNoElementHero(RuneElement element) {
    if (!mounted) return;
    setState(() => _noElementHeroWarning = element);
    _noElementHeroTimer?.cancel();
    _noElementHeroTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _noElementHeroWarning = null);
    });
  }

  void _flashPartyDamage() {
    _partyDamageFlashTimer?.cancel();
    _partyDamageFlashTicks = 0;
    setState(() => _partyDamageFlashVisible = true);
    _partyDamageFlashTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _partyDamageFlashTicks++;
      if (_partyDamageFlashTicks >= 6) {
        timer.cancel();
        _partyDamageFlashTimer = null;
        setState(() => _partyDamageFlashVisible = false);
      } else {
        setState(
          () => _partyDamageFlashVisible = _partyDamageFlashTicks.isEven,
        );
      }
    });
  }

  /// 콤보 발생 시 촉각/효과음 피드백 (엔진 로직과 무관).
  void _onComboEffect(int combo) {
    if (combo >= 3) {
      HapticFeedback.heavyImpact();
    } else if (combo == 2) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _audioService.playEffect(combo > 1 ? GameSound.combo : GameSound.match);
  }

  /// 영웅 피격 이벤트 수신 (BattleEngine → UI).
  ///
  /// [BattleEngine] 의 `_pendingHeroDamage` 가 결과 객체에 담겨 오면,
  /// 큐에 추가 후 즉시 펌프하여 연출을 시작한다.
  void _onHeroDamage(List<HeroDamageEvent> events) {
    if (!mounted || events.isEmpty) return;
    _hitQueue.addAll(events);
    _pumpHitQueue();
  }

  /// 큐에서 1건의 피격 연출을 재생한다.
  ///
  /// 마지막 1건은 [HeroHitFlash.animDuration] 만큼 완전히 재생한 뒤에 끝내고,
  /// 연속 피격(보스 궁극기 전멸 등)은 [_hitGap] 만큼 겹쳐 재생한다.
  ///
  /// ```
  /// 마지막: 1150ms (연출 전체)
  /// 연속:   520ms (앞 연출의 타격 유지 구간이 지난 뒤 다음 시작)
  /// ```
  ///
  /// 예전 값(마지막 620ms)은 연출 길이(620ms)와 같아, 숫자가 읽힐 시간도 없이
  /// 이미지가 사라졌다. 두 값을 같은 상수로 묶지 않는다 — 연출 길이가 바뀌어도
  /// 큐 타이밍이 따라가야 한다.
  void _pumpHitQueue() {
    if (!mounted || _hitTimer != null) return;
    if (_hitQueue.isEmpty) {
      if (_activeHit != null) setState(() => _activeHit = null);
      return;
    }

    final event = _hitQueue.removeAt(0);
    setState(() {
      _activeHit = (
        heroId: event.heroId,
        token: ++_hitToken,
        damage: event.damage,
      );
    });
    _hitTimer = Timer(
      _hitQueue.isEmpty ? HeroHitFlash.animDuration : _hitGap,
      () {
        _hitTimer = null;
        if (!mounted) return;
        _pumpHitQueue();
      },
    );
  }

  // ── 승리/패배 결과 화면 (RPT-408 ~ RPT-410) ──

  /// Game Gain 업그레이드가 없어 배율은 고정이다 (1.0).
  ///
  /// 보상은 [StageConfig.goldReward] 그대로 지급한다. 파티 공통 재화 배율
  /// 업그레이드가 영웅 개별 스탯 강화로 대체되며 사라졌다.
  int get _gameReward => _battle.state.stage.goldReward;

  void _maybeShowEndResult() {
    if (_dialogShown || !_game.isIdle || _battle.state.paused) return;
    final phase = _battle.state.phase;
    if (phase != BattlePhase.victory && phase != BattlePhase.defeat) return;
    _dialogShown = true;
    _audioService.playEffect(
      phase == BattlePhase.victory ? GameSound.victory : GameSound.defeat,
    );
    // 승/패 확정: 진행도 저장/분석을 1회만 수행 (RPT-316, RPT-308)
    widget.onBattleResult?.call(
      win: phase == BattlePhase.victory,
      stageNumber: _battle.state.stage.stageNumber,
      gameReward: _gameReward,
    );
    // 요구사항 6.2: 승/패 확정 즉시 결과창을 띄우지 않고 1.5초 연출 후 오픈.
    _startEndBuffer(phase);
  }

  /// 요구사항 6.2: 승리/패배 애니메이션 연출 버퍼.
  /// 확정 직후 엔진을 멈추고 VICTORY/DEFEAT 오버레이를 1.5초 보여준 뒤
  /// 결과 화면(RuneResultScreen)을 전체 화면으로 연다.
  void _startEndBuffer(BattlePhase phase) {
    _game.pauseEngine();
    setState(() => _resultPhase = phase);
    _hud.value++;
    _endBufferTimer = Timer(const Duration(milliseconds: 1500), () {
      _endBufferTimer = null;
      if (!mounted) return;
      _showEndResult(phase);
    });
  }

  Future<void> _showEndResult(BattlePhase phase) async {
    final isWin = phase == BattlePhase.victory;
    final stage = _battle.state.stage;
    // 요구사항 2.1: 결과 오버레이(전체 화면 라우트)가 떠 있는 동안
    // Flame 엔진의 업데이트/렌더링 루프를 중단한다 (game.pauseEngine()).
    _game.pauseEngine();
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (ctx) => RuneResultScreen(
          win: isWin,
          stageNumber: stage.stageNumber,
          gameReward: _gameReward,
          party: _battle.state.party,
          baseAttack: _battle.state.baseAttack,
          damageSummary: _battle.state.damageStats.snapshot(),
          // 승리 EXP/레벨업 반영 스탯을 우선한다(있을 때). 없으면(패배/직접 진입)
          // 주입된 영웅별 스탯 → 폴백 유닛 값 순으로 내려간다.
          heroStats: widget.postBattleHeroStats.isNotEmpty
              ? widget.postBattleHeroStats
              : (_battle.state.heroStats.isNotEmpty
                    ? _battle.state.heroStats
                    : [for (final u in _battle.state.units) u.toCombatStats()]),
          levelUps: widget.levelUps,
          // 요구사항 6.3: 결과 화면에서 재화 사전 검증(다음/재도전)에 사용.
          playCurrency: widget.playCurrency,
          onRewardAdPlay: widget.onRewardAdPlay,
          // 요구사항 6.4: popUntil 대량 정리 시 '상점으로' 의도 전달.
          onShopRequested: widget.onShopRequested,
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'next':
        final ok = await widget.onNextStage?.call() ?? true;
        // 요구사항 3.1(방어): 결과 화면 사전 검증(6.3)을 통과했어도 Play 부족으로
        // 진입에 실패하면 재화 부족 팝업(광고/상점 단축 경로)을 띄운다.
        if (!ok && mounted) {
          await _showPlayShortageMenu(nextStage: true, phase: phase);
        }
      case 'retry':
        final ok = await widget.onRetry?.call() ?? true;
        if (!ok && mounted) {
          await _showPlayShortageMenu(nextStage: false, phase: phase);
        }
      case 'shop':
        // '상점으로': onShopRequested가 없는 직접 진입(테스트 등)의 폴백 —
        // 배틀 라우트를 pop 하면서 메인 허브에 Shop 탭 전환 요청 전달.
        Navigator.of(context).pop('shop');
      default:
        // '로비로'/뒤로가기(popUntil로 정리된 경우 등): mounted가 false면
        // 여기 도달하지 않는다. 그 외에는 배틀 pop → GameWidget dispose 시
        // 엔진 자동 정지.
        Navigator.of(context).pop();
    }
  }

  /// Play(전투 재화) 부족 안내 팝업 (요구사항 3.1).
  ///
  /// [다음 스테이지]/[다시 도전] 진입이 재화 부족으로 실패했을 때 표시되며
  /// - 'ad'   : 보상형 광고 시청 → Play 충전 후 같은 동작 자동 재시도.
  /// - 취소   : 결과 화면을 다시 열어 다른 경로(로비/상점)를 선택하게 한다.
  Future<void> _showPlayShortageMenu({
    required bool nextStage,
    required BattlePhase phase,
  }) async {
    // 요구사항 3.1/6.3 공용 팝업 (허브/배틀/결과 화면 동일 UI).
    final action = await showPlayShortageDialog(context);
    if (!mounted) return;
    switch (action) {
      case 'ad':
        // 광고 시청 → Play 충전 → 같은 동작(재도전/다음) 재시도 (요구사항 3.1).
        final rewarded = await showRewardedAdOnce();
        if (!mounted) return;
        if (!rewarded) {
          _showAdFailedSnackBar();
          return;
        }
        final granted = widget.onRewardAdPlay?.call() ?? false;
        if (!mounted) return;
        if (!granted) {
          _showAdFailedSnackBar();
          return;
        }
        final ok = nextStage
            ? (await widget.onNextStage?.call() ?? true)
            : (await widget.onRetry?.call() ?? true);
        if (!ok && mounted) {
          // 이론상 불가(+)지만 방어적으로 다시 팝업.
          await _showPlayShortageMenu(nextStage: nextStage, phase: phase);
        }
      default:
        // 취소/닫기 → 결과 화면을 다시 열어 사용자가 다른 경로를 고를 수 있게 한다.
        if (mounted) await _showEndResult(phase);
    }
  }

  /// 광고 로드/시청 실패 안내 (요구사항 3.2).
  void _showAdFailedSnackBar() {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('ad_load_failed'))));
  }

  // ── 일시정지 (RPT-123) ──

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 요구사항 2.3: 앱이 백그라운드(paused/inactive)로 전환되면 자동 일시정지.
    // _setPaused가 배틀 로직(BattleEngine.pause)과 함께
    // Flame 엔진(game.pauseEngine())도 중단시킨다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      _setPaused(false);
    }
  }

  void _setPaused(bool value) {
    if (!mounted || _battle.state.paused == value) return;
    if (value) {
      _battle.pause();
      // 요구사항 2.1: 일시정지 오버레이가 떠 있는 동안 Flame 엔진도 멈춘다.
      _game.pauseEngine();
    } else {
      _battle.resume();
      // 요구사항 2.2: 오버레이 해제/재개 시 엔진 재개를 동기화한다.
      _game.resumeEngine();
    }
    setState(() => _paused = value);
    _hud.value++;
  }

  /// 일시정지 [다시하기]: 입장 비용(Play 1)을 재차감하고 새 배틀을 시작한다.
  /// Play 부족 시 재화 부족 팝업(광고/상점 단축 경로)을 띄운다. 취소 시에는
  /// 일시정지가 풀린 상태로 배틀을 유지한다.
  Future<void> _onPauseRestart() async {
    _setPaused(false);
    final ok = await widget.onRetry?.call() ?? true;
    if (!mounted) return;
    if (ok) return; // 새 run(ValueKey)으로 재시작되어 이 State는 교체된다.
    final action = await showPlayShortageDialog(context);
    if (!mounted) return;
    switch (action) {
      case 'ad':
        final rewarded = await showRewardedAdOnce();
        if (!mounted) return;
        if (!rewarded) {
          _showAdFailedSnackBar();
          return;
        }
        final granted = widget.onRewardAdPlay?.call() ?? false;
        if (!mounted) return;
        if (!granted) {
          _showAdFailedSnackBar();
          return;
        }
        final ok2 = await widget.onRetry?.call() ?? true;
        if (!ok2 && mounted) _showAdFailedSnackBar();
      default:
        break; // 취소 → 배틀 유지(재개된 상태)
    }
  }

  /// 일시정지 [로비로]: 배틀을 퇴각 처리하고 허브(로비)로 복귀한다.
  void _onPauseGoLobby() {
    _battle.retreat();
    widget.analytics?.logRetreat(stage: _battle.state.stage.stageNumber);
    Navigator.of(context).pop();
  }

  /// 플레이어 턴 동안 보드가 활성 상태인지 (그 외 전환/결과는 그레이아웃).
  bool get _isPlayerTurn => switch (_battle.state.phase) {
    BattlePhase.plan ||
    BattlePhase.action ||
    BattlePhase.inputResolving ||
    BattlePhase.resolving => true,
    _ => false,
  };

  // ── UI ──

  /// Android Back: 일시정지 메뉴 열기/재개 토글 (프롬프트 §24, RPT-411).
  void _onAndroidBack() {
    if (_paused) {
      _setPaused(false);
    } else {
      _setPaused(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onAndroidBack();
      },
      child: Scaffold(
        body: BattleStageScaffold(
          topBar: BattleStageTopBar(
            stage: _battle.state.stage,
            bossUltimateWarning: _battle.state.bossUltimateWarning,
            onPause: () => _setPaused(true),
          ),
          hudRows: (metrics) => BattleHudRows(
            metrics: metrics,
            battle: _battle,
            hud: _hud,
            audioService: _audioService,
            isPlayerTurn: _isPlayerTurn,
            canUseSkill: _ready && _game.isIdle,
            onUseSkill: _game.useHeroSkill,
            armedSkillHeroId: _game.armedSkillHeroId,
            heroHit: _activeHit,
            sprite: MonsterSprite(
              battle: _battle,
              hud: _hud,
              audioService: _audioService,
            ),
          ),
          board: _buildBoardArea(),
          overlay: Stack(
            children: [
              // 요구사항 6.1: 진입 직후 'Ready... GO!' 카운트다운 오버레이.
              if (!_ready) _buildReadyOverlay(),
              // 요구사항 6.2: 승/패 연출 버퍼 오버레이 (결과 화면 직전).
              if (_resultPhase != null)
                _buildResultBufferOverlay(_resultPhase!),
              if (_partyDamageFlashVisible)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      key: ValueKey('party-damage-flash'),
                      color: Color(0x66FF0000),
                    ),
                  ),
                ),
              if (_paused) _buildPauseOverlay(),
              // 속성 영웅 없음 경고 — 몬스터 중앙에 표시.
              if (_noElementHeroWarning != null)
                _buildNoElementHeroOverlay(_noElementHeroWarning!),
            ],
          ),
        ),
      ),
    );
  }

  /// 보드 영역: 좌측 상단 X/턴 인디케이터를 제거하고, 몬스터 턴·결과 전환
  /// 동안에는 보드를 그레이아웃 + 입력 잠금으로 상태를 표현한다 (요청 1·3·10).
  ///
  /// 사양 2-3 입력 잠금 정책: `IgnorePointer(ignoring: !_ready)` →
  /// `AbsorbPointer(absorbing: ...)`. `AbsorbPointer` 는 **포인터 이벤트를
  ///absorbing** 하는 동안 스크롤/제스처에까지 전파를 차단하므로,
  /// RESOLVING / MONSTER_TURN 동안 보드가 미끄러지거나 탭이 새지 않는다.
  Widget _buildBoardArea() {
    final board = Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _hud,
          builder: (context, _) {
            final s = _battle.state;
            final absorbing =
                !_ready ||
                s.paused ||
                s.inputLocked ||
                s.phase == BattlePhase.resolving ||
                s.phase == BattlePhase.monsterTurn ||
                s.phase == BattlePhase.victory ||
                s.phase == BattlePhase.defeat ||
                s.phase == BattlePhase.retreat;
            return AbsorbPointer(
              absorbing: absorbing,
              child: GameWidget(game: _game),
            );
          },
        ),
        AnimatedBuilder(
          animation: _hud,
          builder: (context, _) => _buildBoardOverlay(),
        ),
      ],
    );
    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) {
        // 내 턴 콤보(캐스케이드 연출) 재생 중에는 phase가 승/패로 넘어가도
        // 그레이아웃/암전하지 않는다 — 처치 콤보 연출이 항상 밝게 보이도록.
        if (_isPlayerTurn || _game.playbackActive) return board;
        // 몬스터 턴/승/패/퇴각: 그레이아웃 + 어둡게 + 입력 차단
        return AbsorbPointer(
          key: const ValueKey('board-gray-overlay'),
          child: ColorFiltered(
            colorFilter: _grayFilter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                board,
                const ColoredBox(color: Colors.black45),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardOverlay() {
    // 정보 표시용 오버레이다. 요청 7: 포인터를 흡수하지 않도록 IgnorePointer로
    // 감싼다 (레인보우 힌트 제거 후 남는 내용은 없다).
    return const IgnorePointer(child: SizedBox.shrink());
  }

  Widget _buildPauseOverlay() {
    final l10n = LanguageScope.of(context).strings;
    return Positioned.fill(
      // 규칙 5: 일시정지 오버레이는 BackdropFilter(8)로 게임 화면이 스며드는 글래스 처리
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tr('battle_paused'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    // 규칙 1: Primary CTA — 네온 그라데이션 (재개)
                    child: GradientButton(
                      onPressed: () => _setPaused(false),
                      icon: Icons.play_arrow,
                      label: l10n.tr('battle_resume'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _onPauseRestart,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.tr('battle_restart')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _onPauseGoLobby,
                    icon: const Icon(Icons.home_outlined),
                    label: Text(l10n.tr('battle_go_lobby')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 요구사항 6.1: 진입 직후 'Ready... GO!' 카운트다운 연출.
  /// 전체 화면을 덮어 조작을 잠그고(ColoredBox가 포인터를 흡수), 1.5초 뒤
  /// [_startReadyCountdown]이 [_ready]를 true로 바꿔 이 오버레이를 치운다.
  Widget _buildReadyOverlay() {
    final l10n = LanguageScope.of(context).strings;
    return Positioned.fill(
      // 규칙 5: 카운트다운 오버레이도 BackdropFilter(8) 글래스 처리
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Text(
                  l10n.tr('battle_ready_go'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: AppColors.accent, blurRadius: 18)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// **속성 영웅 없음 경고** — 몬스터 중앙에 표시.
  ///
  /// 매치는 했는데 그 색 살아있는 영웅이 없어 데미지가 0이었을 때 띄운다.
  /// 몬스터 스프라이트 위에 검은 반투명 배경 + 안내 문구를 얹는다.
  Widget _buildNoElementHeroOverlay(RuneElement element) {
    final l10n = LanguageScope.of(context).strings;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(element.argb).withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${element.emoji} ${l10n.tr('element_${element.name}')}',
                    style: TextStyle(
                      color: Color(element.argb),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tr('battle_no_element_hero'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 요구사항 6.2: 승리/패배 애니메이션 연출 버퍼(1.5초).
  /// 결과 화면이 열리기 전 VICTORY/DEFEAT 문구를 크게 보여준다.
  Widget _buildResultBufferOverlay(BattlePhase phase) {
    final isWin = phase == BattlePhase.victory;
    final l10n = LanguageScope.of(context).strings;
    return Positioned.fill(
      // 규칙 5: 승/패 버퍼 오버레이도 BackdropFilter(8) 글래스 처리
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.65),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Text(
                  isWin ? l10n.tr('result_victory') : l10n.tr('result_defeat'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isWin ? AppColors.accent : AppColors.danger,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
