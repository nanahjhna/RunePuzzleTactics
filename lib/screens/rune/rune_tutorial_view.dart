/// Rune Puzzle Tactics — 인터랙티브 튜토리얼 화면 (RPT-427 ~ RPT-431)
///
/// [TutorialScript]의 6개 섹션을 순서대로 진행한다 (프롬프트 §40~§42).
/// - 섹션별 스크립트 보드: 목표 달성 시 다음 섹션 자동 전환
/// - 안내 카드(제목/메시지/STEP) + 스킵 다이얼로그
/// - 완료/스킵 시 [RuneProgress.recordTutorialDone] 저장 후 메인 허브로 복귀
/// - Android Back → 스킵 확인 다이얼로그
///
/// **요구사항 9 — 튜토리얼 = 실제 전투 화면.**
/// 예전에는 그라데이션 배경 + 파티/몬스터 합계 HP 바 2개 + 별도 스킬 버튼을 그려
/// "다른 게임"처럼 보여줬다. 사용자는 배워야 할 조작을 다른 화면에서 연습하게 된다.
///
/// 이제 [BattleStageScaffold] 하나로 **실제 전투와 같은 골격**을 쓴다 — 같은
/// 배경 이미지, 같은 세로 배치/규격([BattleStageMetrics]), 같은 상단바·몬스터
/// 영역·영웅 포트레이트 HUD(초상화 탭 = 스킬). 남는 차이는 셋뿐이다:
///  1. 상단바에 [tutorial_step] 진행 표시,
///  2. 보드 아래 안내 카드,
///  3. 좌측 상단 X = 스킵(실제 전투는 제거됐지만 튜토리얼엔 반드시 필요).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/language_controller.dart';
import '../../services/game_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/ui_frame.dart';
import '../../widgets/ui_pill.dart';
import 'battle_hud.dart';
import 'rune_battle_game.dart';
import 'package:rune_puzzle_tactics/widgets/monster_sprite.dart';

/// 튜토리얼 화면. [store]가 없으면 완료 기록 저장 없이 진행한다(테스트/미리보기).
class RuneTutorialView extends StatefulWidget {
  const RuneTutorialView({
    super.key,
    this.store,
    this.analytics,
    this.audioService,
  });

  final RuneProgressStore? store;
  final RuneAnalytics? analytics;
  final GameAudioService? audioService;

  @override
  State<RuneTutorialView> createState() => _RuneTutorialViewState();
}

class _RuneTutorialViewState extends State<RuneTutorialView> {
  bool _loading = true;
  RuneProgress? _progress;

  int _sectionIndex = 0;
  late TutorialSection _section;
  late BattleEngine _battle;
  late RuneBattleGame _game;

  final ValueNotifier<int> _hud = ValueNotifier<int>(0);
  bool _advancing = false;
  bool _skipDialogOpen = false;

  /// HUD 위젯([BattleHudRows])이 **생성자 인자로 캡처**하는 값들의 마지막 스냅샷.
  ///
  /// [BattleHudRows] 는 내부에서 `_hud` 를 구독해 스스로 다시 그리지만,
  /// `isPlayerTurn`/`canUseSkill`/`armedSkillHeroId`/`hintHeroId` 는 이 화면의
  /// `build()` 가 만들어 넘기는 값이라 값이 바뀌면 `setState` 로 한 번 더 밀어야
  /// 갱신된다. 값이 그대로면 건너뛴다(재생 중 매 프레임이 아니라 전환 순간만).
  bool? _lastPlayerTurn;
  bool? _lastIdle;
  String? _lastArmedSkill;

  GameAudioService get _audioService =>
      widget.audioService ?? GameAudioService.instance;

  @override
  void initState() {
    super.initState();
    widget.analytics?.logTutorialStart();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    RuneProgress? p;
    if (widget.store != null) {
      try {
        p = await widget.store!.load();
      } catch (_) {
        p = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _progress = p;
      _loading = false;
    });
    _loadSection(0);
  }

  @override
  void dispose() {
    _hud.dispose();
    super.dispose();
  }

  // ── 섹션 진행 ──

  void _loadSection(int index) {
    final spec = TutorialScript.sections[index];
    // 실제 플레이와 같은 입력을 만든다: 진행도에 편성된 파티/스탯을 그대로 쓴다.
    // (파티를 튜토리얼 전용으로 따로 만들면 시너지 배율이 달라 "배운 것"이
    //  실제 전투의 숫자와 어긋난다.)
    final p = _progress;
    final heroStats = p?.heroCombatStats ?? const <HeroCombatStats>[];
    final baseAttack = heroStats.fold<int>(0, (sum, h) => sum + h.attack);
    final partyMaxHp = heroStats.fold<int>(0, (sum, h) => sum + h.hp);
    final battle = BattleEngine.create(
      stage: spec.stage,
      roster: p?.toRoster() ?? HeroRoster.initial(),
      baseAttack: baseAttack,
      partyMaxHp: partyMaxHp,
      rng: math.Random(42),
      board: PuzzleBoard.fromRows(spec.boardRows),
      partyHeroes: p?.partyHeroDefs ?? const [],
      heroStats: heroStats,
    );
    battle.startBattle();
    final game = RuneBattleGame(
      battle: battle,
      onHudChanged: _onHud,
      onComboEffect: _onComboEffect,
    );
    // 보드 위에 "어느 룬을 어느 방향으로 미는지"를 시각화한다(좌표 텍스트만으로는
    // 그 칸을 눈으로 찾아야 한다). 플레이어가 조작을 시작하면 게임이 스스로 숨긴다.
    game.setHintMove(spec.hintMove);

    if (!mounted) return;
    setState(() {
      _sectionIndex = index;
      _section = spec;
      _battle = battle;
      _game = game;
      _advancing = false;
      // 새 게임/섹션이므로 HUD 인자 스냅샷을 초기화한다.
      _lastPlayerTurn = null;
      _lastIdle = null;
      _lastArmedSkill = null;
    });
  }

  void _onHud() {
    if (!mounted) return;
    _hud.value++;
    // HUD 슬롯이 받는 값들이 바뀌면 `build()` 를 한 번 더 돌려 다시 캡처한다
    // (특히 스킬 힌트: 초상화 탭 → 조준 → 발동 전환에서 힌트가 꺼져야 한다).
    final playerTurn = _isPlayerTurn;
    final idle = _game.isIdle;
    final armed = _game.armedSkillHeroId;
    if (playerTurn != _lastPlayerTurn ||
        idle != _lastIdle ||
        armed != _lastArmedSkill) {
      _lastPlayerTurn = playerTurn;
      _lastIdle = idle;
      _lastArmedSkill = armed;
      setState(() {});
    }
    _maybeAdvance(_section, _battle);
  }

  /// 콤보 시 촉각/사운드 훅 (콤보 인지 보조).
  void _onComboEffect(int combo) {
    if (combo >= 3) {
      HapticFeedback.heavyImpact();
    } else if (combo == 2) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _audioService.playEffect(GameSound.match);
  }

  void _maybeAdvance(TutorialSection spec, BattleEngine battle) {
    if (_advancing || battle.state.paused) return;
    if (!spec.isDone(battle)) return;
    _advancing = true;
    final isLast = _sectionIndex >= TutorialScript.sections.length - 1;
    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (isLast) {
        _finishTutorial();
      } else {
        _loadSection(_sectionIndex + 1);
      }
    });
  }

  Future<void> _finishTutorial({bool skipped = false}) async {
    final store = widget.store;
    if (store != null) {
      final updated = (_progress ?? RuneMeta.initial()).recordTutorialDone();
      _progress = updated;
      await store.save(updated);
    }
    widget.analytics?.logTutorialComplete(skipped: skipped);
    if (mounted) Navigator.of(context).pop();
  }

  // ── 스킵 / Back ──

  Future<void> _openSkipDialog() async {
    if (_skipDialogOpen || !mounted) return;
    final l10n = LanguageScope.of(context).strings;
    _skipDialogOpen = true;
    // 요구사항 2.1: 스킵 확인 다이얼로그가 떠 있는 동안 배틀 로직과
    // Flame 엔진을 함께 일시정지한다 (game.pauseEngine()).
    _batchPause();
    _hud.value++;
    final skip = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          l10n.tr('tutorial_skip_dialog_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.tr('tutorial_skip_dialog_msg'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.tr('tutorial_continue')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(l10n.tr('tutorial_skip')),
          ),
        ],
      ),
    );
    _skipDialogOpen = false;
    if (!mounted) return;
    if (skip == true) {
      await _finishTutorial(skipped: true);
      return;
    }
    // 요구사항 2.2: 계속하기 → 오버레이 해제 시 배틀 로직과 Flame 엔진 재개.
    _batchResume();
    _hud.value++;
  }

  /// 배틀 로직(BattleEngine)과 Flame 엔진(RuneBattleGame)을 함께 일시정지한다.
  void _batchPause() {
    _battle.pause();
    _game.pauseEngine();
  }

  /// 배틀 로직과 Flame 엔진을 함께 재개한다.
  void _batchResume() {
    _battle.resume();
    _game.resumeEngine();
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _openSkipDialog();
      },
      child: Scaffold(
        body: _loading
            ? DecoratedBox(
                decoration: battleStageBackdrop,
                child: const Center(child: CircularProgressIndicator()),
              )
            // 실제 전투 화면과 **같은 골격**. 남는 차이는 안내 카드/스킵 바뿐.
            : BattleStageScaffold(
                topBar: _buildTopBar(),
                hudRows: (metrics) => BattleHudRows(
                  metrics: metrics,
                  battle: _battle,
                  hud: _hud,
                  audioService: _audioService,
                  // 전투와 동일: 몬스터 턴·결과 전환은 포인터/그레이아웃으로 막고,
                  // 스킬은 **초상화 탭**으로 쓴다(별도 스킬 버튼 없음).
                  isPlayerTurn: _isPlayerTurn,
                  canUseSkill: _game.isIdle,
                  onUseSkill: _game.useHeroSkill,
                  armedSkillHeroId: _game.armedSkillHeroId,
                  // 스킬 섹션: 초상화를 눌러야 한다는 사실을 보드 안내 카드 텍스트
                  // 밖에서도 보여준다(초상화 자체에 맥동 링).
                  hintHeroId: _hintHeroId,
                  sprite: MonsterSprite(
                    battle: _battle,
                    hud: _hud,
                    audioService: _audioService,
                  ),
                ),
                board: _buildBoard(),
                footer: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_buildInstructionCard(), _buildBottomBar()],
                ),
              ),
      ),
    );
  }

  /// 보드. 몬스터 턴/결과 전환은 실제 전투와 똑같이 **그레이아웃 + 입력 차단**으로
  /// 알린다(별도 턴 인디케이터 없음).
  Widget _buildBoard() {
    final board = GameWidget(
      key: ValueKey('tutorial-game-$_sectionIndex'),
      game: _game,
    );
    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) {
        final absorbing = !_isPlayerTurn || _game.playbackActive;
        return AbsorbPointer(absorbing: absorbing, child: board);
      },
    );
  }

  /// 플레이어 턴 여부 — 실제 전투와 동일한 판정.
  bool get _isPlayerTurn => switch (_battle.state.phase) {
    BattlePhase.plan ||
    BattlePhase.action ||
    BattlePhase.inputResolving ||
    BattlePhase.resolving => true,
    _ => false,
  };

  /// 스킬 섹션에서 "초상화를 눌러 스킬 사용" 힌트를 줄 영웅 id.
  ///
  /// - 스킬 섹션이 아니면 null.
  /// - 이미 스킬을 쓴 영웅이면 null(힌트 종료).
  /// - 조준 모드에 들어갔으면 null — 이미 초상화를 눌렀고, 이제는 보드의 조준
  ///   하이라이트가 다음 단계(룬 탭)를 안내한다.
  String? get _hintHeroId {
    if (_section.id != 'skill') return null;
    if (_game.armedSkillHeroId != null) return null;
    final units = _battle.state.units;
    if (units.isEmpty) return null;
    final unit = units.first;
    if (unit.skillUsed) return null;
    return unit.heroId;
  }

  /// 실제 전투 상단바 프레임을 그대로 쓴다 — 좌우 여백·일시정지 버튼 위치가 동일하다.
  /// 중앙 자리만 「튜토리얼 / STEP n/N」으로 갈아끼우고, 좌측 X = 스킵을 넣는다.
  Widget _buildTopBar() {
    final l10n = LanguageScope.of(context).strings;
    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) => BattleStageTopBar(
        stage: _battle.state.stage,
        bossUltimateWarning: _battle.state.bossUltimateWarning,
        // 실제 전투와 달리 일시정지 메뉴는 없다 — 스킵 확인이 같은 역할.
        onPause: _openSkipDialog,
        pauseTooltip: l10n.tr('tutorial_skip'),
        leading: IconButton(
          tooltip: l10n.tr('tutorial_skip'),
          onPressed: _openSkipDialog,
          icon: const Icon(Icons.close, color: Colors.white70),
        ),
        center: Column(
          children: [
            Text(
              l10n.tr('tutorial_title'),
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            Text(
              l10n.trp('tutorial_step', {
                'current': _sectionIndex + 1,
                'total': TutorialScript.sections.length,
              }),
              key: const ValueKey('tutorial-step-counter'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    final l10n = LanguageScope.of(context).strings;
    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: UiFrame.round14(
            // 부모 `Column(mainAxisSize: min)` 안이라 세로가 무한대다.
            fit: StackFit.loose,
            background: AppColors.cardDark2,
            color: AppColors.accent.withValues(alpha: 0.4),
            insets: const EdgeInsets.all(12),
            art: const CardArt.header(kCardArtHeaderTutorial),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: UiPill(
                        size: UiPillSize.small,
                        borderColor: AppColors.accent.withValues(alpha: 0.6),
                        background: AppColors.accent.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          l10n.trp('tutorial_step_tag', {
                            'current': _sectionIndex + 1,
                            'id': _section.id,
                          }),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr('tutorial_title_${_section.id}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tr('tutorial_msg_${_section.id}'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_section.hintMove case final m?) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.trp('tutorial_hint', {
                      'from': _tileLabel(m.from),
                      'to': _tileLabel(m.to),
                    }),
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 스킬 섹션 하단 힌트.
  ///
  /// 별도 스킬 버튼은 **두지 않는다**(요구사항 9) — 실제 전투처럼 HUD의 영웅
  /// 초상화를 탭하면 스킬이 나간다([BattleHeroPortraitHud]).
  ///
  /// 단 **표적 지정 스킬**(Fire/Light)은 포트레이트 한 번으로 끝나지 않는다 —
  /// 조준 모드에 든 뒤 보드의 룬을 눌러야 끝난다. 한 줄 힌트가 그 두 단계를
  /// 숨기면 "눌렀는데 아무 일도 없다"가 되므로, 현재 영웅의 스킬이 조준을 요구하는
  ///지에 따라 문구를 갈아친다.
  Widget _buildBottomBar() {
    final l10n = LanguageScope.of(context).strings;
    return AnimatedBuilder(
      animation: _hud,
      builder: (context, _) {
        if (_section.id != 'skill') return const SizedBox(height: 8);
        final unit = _battle.state.units.first;
        final ready = _battle.canUseHeroSkill(unit.heroId) && _game.isIdle;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            unit.skill?.needsTarget ?? false
                ? l10n.tr('tutorial_skill_tap_target')
                : l10n.tr('tutorial_skill_tap'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ready ? AppColors.accentGold : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }

  String _tileLabel(int index) {
    final l10n = LanguageScope.of(context).strings;
    return l10n.trp('tutorial_tile_label', {
      'col': index % PuzzleBoard.cols + 1,
      'row': index ~/ PuzzleBoard.rows + 1,
    });
  }
}
