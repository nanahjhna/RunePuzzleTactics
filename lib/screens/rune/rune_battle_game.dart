/// Rune Puzzle Tactics — Flame 배틀 보드 (PHASE 4 UI)
///
/// BattleEngine(순수 Dart)을 합성(Composition)한다 (RPT-126: UI는 상태만 바라본다).
///  - 6×6 보드 렌더링 (RPT-65 ~ RPT-68, 6×6 개편)
///  - 드래그/탭 입력 → engine.onDragStart / onDragEnd (RPT-98 ~ RPT-111)
///  - Swap → 매칭 인지(0.35초) → Wave 플래시 → 파도별 낙하/리필 → 연쇄 대기
///    연출 파이프라인 (Resolve-first / Animate-second, RPT-112/116/132 개편)
///  - 영웅 스킬 연출
///  - 콤보 팝업/스파크/쉐이크 연출 (RPT-81 강화)
library;

import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart';

/// UI 연출 단계. 로직 단계(BattlePhase)와 분리해 둔다 (Resolve-first, RPT-132).
enum RunePlayPhase {
  idle,
  swapAnim, // 교환
  bounceBack, // 무효 교환 시 원위치 복귀 (RPT-108/109)
  matchHold, // 매칭 인지 지연(약 0.35초) — 파괴 연출 전 배치를 보여준다
  waveFlash, // 캐스케이드 파도별 플래시 (RPT-116)
  settle, // 중력 낙하 + 리필 (RPT-67/78)
  cascadePause, // 연쇄 파도 사이 배치 확인 대기 (콤보 인지)
  resultReveal, // 모든 룬 정지 확인 후 데미지 결과 표기 (합계/반격 포함)
  shuffleFade, // 유효한 수가 없을 때 보드 재배열
}

/// 화면에 그리는 타일 (애니메이션 오프셋/플래시/스케일 포함).
class _VisTile {
  _VisTile(this.rune);

  RuneElement rune;

  /// 픽셀 오프셋 (보드 로컬 좌표 기준).
  Vector2 offset = Vector2.zero();
  double scale = 1;
  double alpha = 1;
  double flash = 0;

  static _VisTile fromTile(BoardTile t) => _VisTile(t.rune);
}

/// 플로터 기본 수명(초). 개별 [_FloatingText] 이 더 길게 가져갈 수 있다.
const double _kFloaterDur = 1.0;

class _FloatingText {
  _FloatingText(
    this.text,
    this.center,
    this.paint, {
    this.sub,
    this.subPaint,
    this.duration = _kFloaterDur,
  });

  final String text;
  final Vector2 center; // 보드 로컬 좌표
  final TextPaint paint;

  /// 배율/사유 캡션 (예: `C3 ×2.25`). null 이면 미표기.
  ///
  /// 데미지는 원인이 여러 개(약점 ×1.5 / 속성 시너지 / 콤보 배율)라서 숫자만
  /// 띄우면 "20 인데 왜 60 이지" 를 설명할 수 없다.
  final String? sub;
  final TextPaint? subPaint;

  /// 수명(초). 데미지는 합계 판독 시간을 줘서 길게 둔다.
  final double duration;

  double age = 0;

  double get progress => (age / duration).clamp(0.0, 1.0);
}

/// 콤보 카운트업 팝업 (스케일 업/다운 + 페이드 아웃).
class _ComboPop {
  _ComboPop(this.combo, this.center, this.paint);

  final int combo;
  final Vector2 center; // 보드 로컬 좌표
  final TextPaint paint;
  double age = 0;
  static const double duration = 0.9;

  double get progress => age / duration;
}

/// 콤보 임팩트 스파크 파티클 (방사형 + 중력 + 페이드).
class _Spark {
  _Spark(this.pos, this.vel, this.color, this.size);

  Vector2 pos;
  Vector2 vel;
  final Color color;
  double size;
  double age = 0;
  static const double duration = 0.55;
}

/// Rune 배틀 Flame 게임. [battle] 엔진과 1:1로 연결된다.
class RuneBattleGame extends FlameGame {
  RuneBattleGame({
    required this.battle,
    this.onHudChanged,
    this.onComboEffect,
    this.onMonsterDamage,
    this.onMonsterDamageTotal,
    this.onMonsterAttack,
    this.onHeroDamage,
    this.onNoElementHero,
  });

  final BattleEngine battle;
  VoidCallback? onHudChanged;

  /// 몬스터 위 개별 데미지 라벨 1건. 보드 플로터와 달리 개수 상한이 없다 —
  /// 화면에 몇 개까지 띄울지는 레이아웃을 소유한 뷰가 정한다.
  ValueChanged<DamageHit>? onMonsterDamage;

  /// 마지막 파도에서 매칭 피해 **합계** 1회 ([BattleResolveResult.summedMonsterDamage]).
  ///
  /// 연쇄 전체를 한눈에 정산하기 위한 값이다. 개별 라벨은 파도마다 1.9초 이상
  /// 간격으로 생겼다가 사라지므로, 총합은 마지막에 한 번만 따로 보여준다.
  ValueChanged<int>? onMonsterDamageTotal;

  /// 영웅 피격 이벤트 시그널 (배틀뷰에서 수신).
  ///
  /// [BattleEngine] 의 [_pendingHeroDamage] 를 받아 UI 연출로 넘긴다.
  ValueChanged<List<HeroDamageEvent>>? onHeroDamage;

  ValueChanged<MonsterAttackEvent>? onMonsterAttack;

  /// 콤보 발생 시 연출 훅 (촉각/사운드 등 — 뷰가 HapticFeedback을 연결).
  ValueChanged<int>? onComboEffect;

  /// **속성 영웅 없음 경고** — 매치는 했는데 그 색 살아있는 영웅이 없어
  /// 데미지가 0이었을 때 발화한다. 뷰가 몬스터 중앙에 경고를 띄운다.
  ValueChanged<RuneElement>? onNoElementHero;

  late RuneBoardLayer boardLayer;

  final List<_VisTile?> _vis = List.filled(PuzzleBoard.size, null);
  final List<_FloatingText> _floaters = [];
  final List<_ComboPop> _combos = [];
  final List<_Spark> _sparks = [];
  final math.Random _fxRandom = math.Random();

  // 재생(연출) 상태
  RunePlayPhase _play = RunePlayPhase.idle;
  bool get playbackActive => _play != RunePlayPhase.idle;

  // 몬스터 턴 연출 카운트다운(≈0.8초, [3단계]→[4단계]).
  // 연출 동안 phase를 monsterTurn으로 표시하고 입력을 잠근다.
  double _monsterTurnT = 0;
  static const double _monsterTurnDuration = 0.8;
  bool get _monsterAnimating => _monsterTurnT > 0;

  /// 턴 해석 완료 후 몬스터 턴 연출을 시작할지 판별하는 플래그.
  ///
  /// 공격을 발생시킨 Swap을 [_kickPlayback]이 재생할 때 세운다.
  bool _pendingMonsterTurn = false;

  bool get isIdle =>
      !playbackActive &&
      !battle.state.inputLocked &&
      !battle.state.paused &&
      !_monsterAnimating;

  double _playT = 0;
  PuzzleMove? _swapMove;
  List<WaveResult> _waves = [];
  Set<int> _removedSet = {};
  int _waveIndex = 0;

  /// 재생 중인 턴의 해석 결과 (데미지 1건 단위 내역 보유).
  ///
  /// 데미지 표기는 [_kickPlayback] 이 아니라 캐스케이드 종료(모든 룬 정지) 뒤
  /// [_revealWaveDamage] 에서만 소비한다 — 계산은 이미 끝났으므로 재생 순서
  /// 만 바꾸면 "떨어지는 중에 숫자/HP 가 먼저 바뀌는" 어색함을 없앨 수 있다.
  BattleResolveResult? _resolve;

  /// 현재 파도 낙하 시간 (최대 낙하 거리 비례, [_settleDurMin]~[_settleDurMax]).
  double _settleDurCur = _settleDurMax;

  /// 캐스케이드 재생 중 HUD 갱신 보류 여부 (정지 확인 뒤 한 번에 반영).
  bool _hudDeferred = false;
  bool _hudPending = false;

  /// 셔플 연출 중 페이드아웃 → 재배열 전환 완료 여부.
  bool _shuffleSwapped = false;
  bool _autoShuffleAfterPlayback = false;

  // 낙하 애니메이션
  Map<int, double> _fallFrom = {};
  Map<int, Vector2> _settleStart = {};
  Map<int, bool> _settleNew = {};

  // 보드 쉐이크 (콤보 임팩트)
  double _shakeT = 0;
  double _shakeAmp = 0;
  double get shakeMag => _shakeT > 0 ? _shakeAmp : 0;

  /// 게임 시작 후 누적 시간(초). 조준 하이라이트의 **맥동** 같은 "시간에 의존한
  /// purely 시각 효과" 전용이다.
  ///
  /// 로직(몇 초 남았는지 등)은 절대 이 값을 쓰지 않는다 — 연출 계층이 계산
  /// 결정을 대신해야 하면 규칙이 갈라진다.
  double _clock = 0;
  double get now => _clock;

  int? _dragFrom;
  int? _hover;
  int? _selectedTile;

  /// 드래그 최근 보드 로컬 위치 (보드 밖 오버슛 시 인접 보정용).
  Vector2? _lastDragLocal;

  // 연출 타이밍 (매칭 인지·낙하 속도 개선)
  static const double _swapDur = 0.18;
  static const double _bounceDur = 0.26;
  static const double _matchHoldDur = 0.35; // 매칭 파괴 전 인지 지연
  static const double _waveDur = 0.42;
  static const double _settleDurMin = 0.24; // 낙하 1칸 기준
  static const double _settleDurMax = 0.6; // 낙하 6칸 이상 기준
  static const double _cascadePauseDur = 0.4; // 연쇄 사이 배치 확인 대기
  static const double _resultRevealDur = 0.9; // 결과(스킬/합계/반격) 체류
  static const double _shuffleFadeDur = 0.5; // 보드 재배열 페이드 연출

  /// 보드 플로터(Black 매칭) 1파도당 상한.
  ///
  /// 보드 위라 겹치면 읽을 수 없다. **HUD 라벨은 이 상한의 영향을 받지 않는다** —
  /// 상한은 뷰가 갖고, 초과분은 `+N건 합계` 칩으로 집계된다.
  static const int _maxBoardFloaters = 6;

  double _tile = 40;
  double _boardPx = 280;

  /// 보드 최대 축 길이 (사양 2-1 Board Width Clamp 상한 450px).
  static const double _boardMaxPx = 450;

  bool _layoutReady = false;

  TextPaint? _emojiPaint;
  double _paintFontSize = -1;

  // 룬 아이콘 시트 스프라이트 (보드 타일).
  // 시트 로드 전/실패 시 비어 있으면 기존 이모지 렌더링으로 폴백한다.
  final Map<RuneElement, Sprite> _runeSprites = {};

  // ── Layout / 초기화 ──

  int? tileAtLocal(Vector2 p) {
    if (p.x < 0 || p.y < 0 || p.x >= _boardPx || p.y >= _boardPx) return null;
    final x = (p.x / _tile).floor();
    final y = (p.y / _tile).floor();
    if (x >= PuzzleBoard.cols || y >= PuzzleBoard.rows) return null;
    return y * PuzzleBoard.cols + x;
  }

  /// [from] 칸 중심에서 [localPos]까지의 드래그 벡터 방향에 있는 인접 칸.
  ///
  /// 손가락이 보드 밖이나 2칸 이상으로 오버슛해도 "슬라이드한 방향"의 인접 칸을
  /// 반환해 Swap을 놓치지 않게 한다. 방향이 거의 없으면 null.
  int? _neighborToward(int from, Vector2 localPos) {
    if (localPos.x < 0 || localPos.y < 0) return null;
    final cx = (from % PuzzleBoard.cols) * _tile + _tile / 2;
    final cy = (from ~/ PuzzleBoard.cols) * _tile + _tile / 2;
    final dx = localPos.x - cx;
    final dy = localPos.y - cy;
    final ax = dx.abs();
    final ay = dy.abs();
    if (ax < 2 && ay < 2) return null; // 거의 움직이지 않음
    var nx = from % PuzzleBoard.cols;
    var ny = from ~/ PuzzleBoard.cols;
    if (ax >= ay) {
      nx += dx > 0 ? 1 : -1;
    } else {
      ny += dy > 0 ? 1 : -1;
    }
    final ni = ny * PuzzleBoard.cols + nx;
    if (!PuzzleBoard.isAdjacent(from, ni)) return null;
    return ni;
  }

  void _refreshTextPaints() {
    if (_paintFontSize == _tile) return;
    _paintFontSize = _tile;
    _emojiPaint = TextPaint(
      style: TextStyle(
        fontSize: _tile * 0.52,
        fontWeight: FontWeight.w800,
        color: const Color(0xFFFFFFFF),
        shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 2)],
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 사양 2-1 "Board Width Clamp (420–450px)":
    // 보드는 420~450px 밴드를 목표로 하되, 탭릿/좁은 기기에서 화면을 벗어나지
    // 않도록 가용 폭을 넘지 않게 한다. 상한 450px는 넓은 화면에서 보드가 과도하게
    // 커지는 것을 막는다.
    final avail = math.max(64.0, math.min(size.x, size.y) - 24);
    _boardPx = math.min(avail, _boardMaxPx);
    _tile = _boardPx / PuzzleBoard.cols;
    _refreshTextPaints();
    _prepareLayer();
    boardLayer.size = Vector2(_boardPx, _boardPx);
    boardLayer.position = Vector2(
      (size.x - _boardPx) / 2,
      (size.y - _boardPx) / 2,
    );
  }

  void _prepareLayer() {
    if (_layoutReady) return;
    _layoutReady = true;
    boardLayer = RuneBoardLayer(this);
    add(boardLayer);
    _syncBoardToVis(battle.state.board);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      // assets/images/runes/rune_row4.png (원본 5행 시트의 4행, 6개 아이콘 스트립).
      final img = await images.load(RuneElement.runeSpriteAsset);
      for (final e in RuneElement.values) {
        _runeSprites[e] = Sprite(
          img,
          srcPosition: Vector2(e.spriteSrcX.toDouble(), 0),
          srcSize: Vector2(
            RuneElement.runeSpriteIconWidth,
            RuneElement.runeSpriteIconHeight,
          ),
        );
      }
    } catch (_) {
      // 시트 로드 실패 시 이모지 렌더링으로 폴백 (테스트/에셋 누락 안전).
      _runeSprites.clear();
    }
  }

  void _syncBoardToVis(PuzzleBoard board) {
    for (var i = 0; i < PuzzleBoard.size; i++) {
      final t = board.cell(i);
      _vis[i] = t == null ? null : _VisTile.fromTile(t);
    }
  }

  // ── Game loop ──

  @override
  void update(double dt) {
    super.update(dt);
    // 레이아웃 전에도 흐른다 — 조준 맥동이 첫 프레임부터 살아 있어야 한다.
    _clock += dt;
    if (!_layoutReady) return;
    _advanceFloaters(dt);
    _advanceCombos(dt);
    _advanceSparks(dt);
    if (_shakeT > 0) {
      _shakeT -= dt;
      if (_shakeT <= 0) _shakeAmp = 0;
    }
    if (playbackActive) {
      _advancePlayback(dt);
    } else {
      _decayFlashes(dt);
    }
    _advanceMonsterTurn(dt);
  }

  /// 유휴 상태에서 남은 타일 섬광을 감쇠시킨다.
  ///
  /// 스킬 섬광(Water 정화 / Fire 오브)은 매칭 파도가 아니라
  /// [_playHeroSkillEvents] 가 직접 `flash` 를 켠다. [_RunePlayPhase.settle] 은
  /// 제거 대상 타일만 갱신하므로 이 감쇠가 없으면 타일에 흰색이 영구히 남는다.
  void _decayFlashes(double dt) {
    for (var i = 0; i < PuzzleBoard.size; i++) {
      final v = _vis[i];
      if (v == null || v.flash <= 0) continue;
      v.flash = math.max(0.0, v.flash - dt * 3.0);
    }
  }

  /// 몬스터 턴 연출: 약 0.8초 공격 애니메이션/피드백 대기 후 다음 플레이어 턴으로
  /// 이행한다 ([3단계]→[4단계]).
  ///
  /// 엔진은 몬스터 공격 피해를 동기로 반영한다. "턴 해석 완료 → 몬스터 턴 연출"은
  /// [_pendingMonsterTurn] 플래그로 판별한다 (배틀 시작 직후의 오발동 방지):
  ///  - 보드 연출(스왑→매칭→파도→낙하)이 끝나고 플래그가 서면 몬스터 턴 연출 시작
  ///  - 연출 동안 phase를 monsterTurn으로 표시(입력 잠금 + 스프라이트 + HUD)
  ///  - 연출 종료 시 [BattleEngine.startPlayerTurn]로 다음 플레이어 턴 개시
  void _advanceMonsterTurn(double dt) {
    if (battle.state.paused) return;
    final phase = battle.state.phase;

    // 플레이어 턴 궤도(plan/monsterTurn)를 벗어나면 연출 취소 (종료/퇴각 등).
    if (phase != BattlePhase.plan && phase != BattlePhase.monsterTurn) {
      _monsterTurnT = 0;
      return;
    }

    // 연출 진행: 0.8초 카운트다운 후 [4단계] 새 플레이어 턴.
    if (_monsterTurnT > 0) {
      _monsterTurnT -= dt;
      if (_monsterTurnT <= 0) {
        _monsterTurnT = 0;
        battle.startPlayerTurn();
        _clearSelectedTile();
        _hudChanged();
      }
      return;
    }

    // 턴 해석 완료(_kickPlayback에서 플래그 설정) 후 보드 연출 종료 → 몬스터 턴.
    if (_pendingMonsterTurn && !playbackActive) {
      _pendingMonsterTurn = false;
      _monsterTurnT = _monsterTurnDuration;
      _clearSelectedTile();
      battle.state.phase = BattlePhase.monsterTurn; // [3단계] 입력 잠금 + 공격 연출
      _hudChanged();
    }
  }

  void _advancePlayback(double dt) {
    _playT += dt;
    switch (_play) {
      case RunePlayPhase.swapAnim:
        final m = _swapMove!;
        final k = _easeInOut(math.min(1.0, _playT / _swapDur));
        final dx =
            ((m.to % PuzzleBoard.cols) - (m.from % PuzzleBoard.cols)) * _tile;
        final dy =
            ((m.to ~/ PuzzleBoard.cols) - (m.from ~/ PuzzleBoard.cols)) * _tile;
        final a = _vis[m.from]!;
        final b = _vis[m.to]!;
        a.offset = Vector2(dx * k, dy * k);
        b.offset = Vector2(-dx * k, -dy * k);
        if (_playT >= _swapDur) {
          _vis[m.from] = b;
          _vis[m.to] = a;
          a.offset = Vector2.zero();
          b.offset = Vector2.zero();
          _beginWave(0);
        }
        break;

      case RunePlayPhase.bounceBack:
        final m = _swapMove!;
        final half = _bounceDur / 2;
        final k = _playT < half
            ? _easeInOut(_playT / half)
            : 1 - _easeInOut((_playT - half) / half);
        final dx =
            ((m.to % PuzzleBoard.cols) - (m.from % PuzzleBoard.cols)) * _tile;
        final dy =
            ((m.to ~/ PuzzleBoard.cols) - (m.from ~/ PuzzleBoard.cols)) * _tile;
        _vis[m.from]!.offset = Vector2(dx * k, dy * k);
        _vis[m.to]!.offset = Vector2(-dx * k, -dy * k);
        if (_playT >= _bounceDur) {
          _vis[m.from]!.offset = Vector2.zero();
          _vis[m.to]!.offset = Vector2.zero();
          _finishPlayback();
        }
        break;

      // 매칭 인지 지연: 파괴 전 0.35초 동안 매칭 룬을 강조한다.
      case RunePlayPhase.matchHold:
        final wave = _waves[_waveIndex];
        final p = math.min(1.0, _playT / _matchHoldDur);
        final emphasize = 0.35 + 0.65 * math.sin(p * math.pi);
        for (final i in wave.removedCells) {
          final v = _vis[i];
          if (v == null) continue;
          v.flash = emphasize * 0.7;
          v.scale = 1.0 + 0.10 * emphasize;
        }
        if (p >= 1) {
          for (final i in wave.removedCells) {
            final v = _vis[i];
            if (v == null) continue;
            v.flash = 0;
            v.scale = 1;
          }
          _play = RunePlayPhase.waveFlash;
          _playT = 0;
        }
        break;

      case RunePlayPhase.waveFlash:
        final wave = _waves[_waveIndex];
        final p = math.min(1.0, _playT / _waveDur);
        final f = _wavePulse(p);
        for (final i in wave.removedCells) {
          _vis[i]?.flash = f;
        }
        if (p >= 1) {
          for (final i in wave.removedCells) {
            _vis[i]?.flash = 0;
            _vis[i]?.scale = 0.7; // 파도 소거 직전 축소 잔상
          }
          _removedSet = wave.removedCells;
          _beginWaveSettle(); // 이 파도만 반영한 중간 보드로 낙하
        }
        break;

      case RunePlayPhase.settle:
        final p = math.min(1.0, _playT / _settleDurCur);
        // 중력 낙하: 시작은 정지, 끝으로 갈수록 가속 (낙하 거리 ∝ t²).
        final g = p * p;
        for (var i = 0; i < PuzzleBoard.size; i++) {
          final v = _vis[i];
          final so = _settleStart[i];
          if (v == null || so == null) continue;
          v.offset = so * (1 - g);
          if (_settleNew[i] == true) {
            // 새로 채워진 룬: 위에서 떨어오며 나타난다. 화면에 들어오기
            // (p ≳ 0.8) 전에 페이지를 끝내야 "的出现"으로 보이지 않는다.
            v.alpha = ((p - 0.25) / 0.5).clamp(0.0, 1.0);
            v.scale = 0.55 + 0.45 * p;
          } else {
            v.alpha = 1;
            // 착지 임팩트 팝 (마지막 12% 구간).
            final land = p > 0.88 ? (1 - (p - 0.88) / 0.12) : 0.0;
            v.scale = 1 + 0.10 * land;
          }
        }
        if (_playT >= _settleDurCur) {
          // ── 정지 게이트 ──
          // 모든 룬이 완전 정지(오프셋 0)한 뒤에만 다음 파도 판정/결과 표기로
          // 넘어간다. 낙하가 덜 끝난 시점에 결과를 계산하면 화면과 로직이
          // 어긋나 다음 턴이 예측 불가능해진다.
          _snapSettled();
          if (_waveIndex + 1 < _waves.length) {
            // 다음 연쇄가 있으면 잠시 배치를 보여준 뒤 다음 파도로.
            _play = RunePlayPhase.cascadePause;
            _playT = 0;
          } else {
            _beginResultReveal();
          }
        }
        break;

      // 연쇄(캐스케이드) 사이: 파도별 중간 보드를 잠시 보여준다 (콤보 인지).
      case RunePlayPhase.cascadePause:
        if (_playT >= _cascadePauseDur) {
          _beginWave(_waveIndex + 1);
        }
        break;

      // 모든 룬 정지 확인 후: 이 파도 데미지 → 마지막 파도에서만 합계/반격.
      case RunePlayPhase.resultReveal:
        if (_playT >= _resultRevealDur) {
          if (_autoShuffleAfterPlayback) {
            _autoShuffleAfterPlayback = false;
            _shuffleSwapped = false;
            _play = RunePlayPhase.shuffleFade;
            _playT = 0;
          } else {
            _finishPlayback();
          }
        }
        break;

      // 셔플 아이템: 전체 페이드아웃 → 재배열 → 페이드 인 (턴 소모 없음).
      case RunePlayPhase.shuffleFade:
        final half = _shuffleFadeDur / 2;
        if (_playT < half) {
          final p = _easeInOut(math.min(1.0, _playT / half));
          for (final v in _vis) {
            if (v == null) continue;
            v.alpha = 1 - p;
            v.scale = 1 - 0.4 * p;
          }
        } else {
          if (!_shuffleSwapped) {
            _shuffleSwapped = true;
            _syncBoardToVis(battle.state.board); // 셔플 결과로 전환
          }
          final p = _easeInOut(math.min(1.0, (_playT - half) / half));
          for (final v in _vis) {
            if (v == null) continue;
            v.alpha = p;
            v.scale = 0.6 + 0.4 * p;
          }
        }
        if (_playT >= _shuffleFadeDur) {
          for (final v in _vis) {
            if (v == null) continue;
            v.alpha = 1;
            v.scale = 1;
          }
          _finishPlayback();
        }
        break;

      case RunePlayPhase.idle:
        break;
    }
  }

  void _advanceFloaters(double dt) {
    for (var i = _floaters.length - 1; i >= 0; i--) {
      _floaters[i].age += dt;
      if (_floaters[i].age >= _floaters[i].duration) _floaters.removeAt(i);
    }
  }

  void _advanceCombos(double dt) {
    for (var i = _combos.length - 1; i >= 0; i--) {
      _combos[i].age += dt;
      if (_combos[i].progress >= 1) _combos.removeAt(i);
    }
  }

  void _advanceSparks(double dt) {
    const g = 900.0; // 중력 가속 (px/s²)
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.age += dt;
      if (s.age >= _Spark.duration) {
        _sparks.removeAt(i);
        continue;
      }
      s.vel.y += g * dt;
      s.pos += s.vel * dt;
    }
  }

  // ── 입력 (RuneBoardLayer에서 호출) ──

  void _onBoardDragStart(int index) {
    _clearSelectedTile();
    // 드래그는 스왑 의도다 — 조준 중이었다면 그대로 무시하고 푼다. 조준 상태로
    // 드래그하다 놓으면 "표적을 놓친 줄 알고 교환" 되는 사고를 막는다.
    _disarmSkill();
    _dragFrom = index;
    _hover = null;
    battle.lastCascade = null; // 이전 턴 잔여 Cascade 무효화
    battle.onDragStart(index); // PLAN → ACTION → INPUT RESOLVING (RPT-98~103)
    _hudChanged();
  }

  void _onBoardDragUpdate(int? hoverIndex) {
    _hover = hoverIndex;
  }

  void _onBoardDragEnd({required int? from, required int? hover}) {
    _dragFrom = null;
    _hover = null;
    if (from == null) return;
    var target = hover;
    if (target == null) {
      // 최종 위치가 보드 밖/무효여도 마지막 드래그 방향 인접 칸으로 보정 (오버슛).
      final last = _lastDragLocal;
      if (last != null) target = _neighborToward(from, last);
    }
    _lastDragLocal = null;
    if (target != null) {
      submitMove(PuzzleMove(from, target));
    } else {
      // 드래그 종료 위치가 무효 → Swap 미실행 릴리즈
      battle.onDragEnd(PuzzleMove(from, from));
      _hudChanged();
    }
  }

  /// **조준 모드에 든 영웅** id. null 이면 조준 중이 아니다.
  ///
  /// [HeroSkillEffect.needsTarget] 스킬(Fire/Light)은 포트레이트만 눌러서는
  /// 발동하지 않는다 — 누른 뒤 **어떤 룬을 바꿀지/어디를 터뜨릴지**를 고르는
  /// 두 단계다. 이 필드가 그 "두 단계 사이" 상태다.
  ///
  /// 암 진입은 턴을 소비하지 않는다(영웅별 [PartyHeroUnit.skillUsed] 은 실제 발동
  /// 때만 세어진다). 그래서 잘못 조준한 뒤 취소해도 스킬 기회를 잃지 않는다.
  String? _armedSkillHeroId;

  /// 조준 중인 영웅의 스킬 (없으면 null — 이미 발동/취소된 경우).
  HeroSkillSpec? get _armedSkill {
    final id = _armedSkillHeroId;
    if (id == null) return null;
    for (final u in battle.state.units) {
      if (u.heroId == id) return u.skill;
    }
    return null;
  }

  /// 조준 모드에 든 영웅 id (HUD 뱃지용). 조준 중이 아니면 null.
  String? get armedSkillHeroId => _armedSkillHeroId;

  /// 조준 모드를 푼다. 턴/스킬 사용 횟수는 건드리지 않는다.
  void _disarmSkill() {
    if (_armedSkillHeroId == null) return;
    _armedSkillHeroId = null;
    _hudChanged();
  }

  /// 탭 입력: 룬을 선택하거나 선택한 룬과 인접한 룬을 교환한다.
  void _onBoardTap(int index) {
    if (battle.state.phase == BattlePhase.plan) {
      battle.onFirstTouch();
      _hudChanged();
    }

    // 조준 모드가 먼저다 — 스와프 예약보다 우선한다. 누른 칸이 유효 타겟이면
    // 즉시 발동하고, 아니면 조준을 푼다(스왑도 하지 않는다).
    final armedId = _armedSkillHeroId;
    final armedSpec = _armedSkill;
    if (armedId != null && armedSpec != null) {
      if (battle.isValidSkillTarget(armedSpec, index)) {
        useHeroSkill(armedId, target: index);
      } else {
        _disarmSkill();
      }
      return;
    }

    final selected = _selectedTile;
    if (selected == null || selected == index) {
      _selectedTile = selected == index ? null : index;
      _hudChanged();
      return;
    }
    if (PuzzleBoard.isAdjacent(selected, index)) {
      _clearSelectedTile();
      submitMove(PuzzleMove(selected, index));
      return;
    }
    _selectedTile = index;
    _hudChanged();
  }

  void _clearSelectedTile() {
    if (_selectedTile == null) return;
    _selectedTile = null;
  }

  // ── 공개 조작 API ──

  /// Swap 확정 (드래그 종료). Resolve-first 후 연출 재생.
  void submitMove(PuzzleMove move) {
    if (!isIdle) return;
    battle.onDragEnd(move);
    _kickPlayback(move: move);
  }

  /// 선택한 영웅의 스킬을 사용하고 결과 연출 후 몬스터 턴으로 넘긴다.
  ///
  /// [HeroSkillEffect.needsTarget] 스킬(Fire/Light)은 `target` 없이 호출하면
  /// **발동 대신 조준 모드로 들어간다**. 그 상태에서 보드의 룬을 누르면
  /// `target` 이 붙어서 다시 불려 발동한다.
  ///
  /// ```dart
  /// onUseSkill(heroId)          → Fire/Light: 조준 모드 진입
  /// onUseSkill(heroId)          → Water/Grass/Poison: 즉시 발동
  /// onUseSkill(heroId)          → 이미 조준 중이면: 취소
  /// onUseSkill(heroId, target)  → 조준 없이 바로 발동 (테스트/오토바이 전용)
  /// ```
  ///
  /// 취소 경로는 세 개다 — 포트레이트 재탭 / 유효하지 않은 칸 탭 / 드래그
  /// ([_onBoardDragStart]). 어느 쪽도 턴을 소비하지 않는다.
  bool useHeroSkill(String heroId, {int? target}) {
    if (!isIdle || !battle.canUseHeroSkill(heroId)) return false;

    final spec = battle.state.units.firstWhere((u) => u.heroId == heroId).skill;
    if (spec == null) return false;

    if (spec.needsTarget && target == null) {
      // 같은 영웅을 다시 누르면 조준 해제 (토글).
      final next = _armedSkillHeroId == heroId ? null : heroId;
      _armedSkillHeroId = next;
      if (next == null) _clearSelectedTile();
      _hudChanged();
      return false;
    }

    if (!battle.useHeroSkill(heroId, target: target)) return false;
    _armedSkillHeroId = null;
    _kickHeroSkillPlayback();
    return true;
  }

  /// HUD 강제 갱신 (테스트/디버그 포함).
  void refreshHud() => _hudChanged();

  // ── Playback 내부 ──

  /// 턴 연출 시작.
  ///
  /// 데미지 표기는 여기서 하지 않는다. [_revealWaveDamage] 가 **모든 룬이
  /// 정지한 뒤**에 파도별 내역을 재생한다 — 합계 하나만 미리 띄우면
  /// "떨어지는 중에 HP 가 빠지고 숫자가 뻥튀긴" 것처럼 보인다.
  void _kickPlayback({required PuzzleMove? move}) {
    final cascade = battle.lastCascade;
    if (cascade == null) {
      _resolve = null;
      _syncBoardToVis(battle.state.board);
      _hudChanged();
      return;
    }

    if (cascade.isEmpty) {
      // 무효 Swap: 원위치 복귀 (RPT-108/109). 턴 해석이 아니므로 몬스터 턴 없음.
      _resolve = null;
      _swapMove = move;
      _play = RunePlayPhase.bounceBack;
      _playT = 0;
      _hudChanged();
      return;
    }

    _waves = cascade.waves;
    _resolve = battle.lastResolve;
    _pendingMonsterTurn = true; // 턴 해석 완료 → 연출 종료 후 몬스터 턴
    _autoShuffleAfterPlayback = cascade.wasShuffled;

    // HP 바/파티 게이지 갱신은 캐스케이드가 끝난 뒤 한 번에. (HP 는 이미 엔진이
    // 깎았으므로, 지금 갱신하면 "룬이 멈추기 전에 결과가 보인다".)
    _hudDeferred = true;
    _hudPending = false;

    if (move != null) {
      _swapMove = move;
      _play = RunePlayPhase.swapAnim;
      _playT = 0;
    } else {
      // Swap 없이 발생한 결과 파도를 바로 연출한다.
      _beginWave(0);
    }
  }

  void _kickHeroSkillPlayback() {
    final result = battle.lastResolve;
    if (result == null) {
      throw StateError(
        'Hero skill activation did not produce a resolve result.',
      );
    }
    _waves = result.heroSkillWaves;
    _resolve = result;
    _pendingMonsterTurn = true;
    _autoShuffleAfterPlayback = false;
    _hudDeferred = true;
    _hudPending = false;

    // Fire(색 전량 변환)은 **연쇄가 아닌 변환이 본체**다. 그래서 연쇄
    // 파도를 바로 시작하면 보드가 "파도 결과"로 한 번에 넘어가 버린다 —
    // 플레이어는 빨간 칸으로 바뀐 걸 **처음부터 못 본** 채 연출이 시작된다.
    //
    // 그래서 연쇄보다 먼저, 아직 스킬 전 상태를 들고 있는 `_vis` 에 변환
    // 결과를 그대로 올린다. 변환은 칸을 **이동**시키지 않으므로 칸 인덱스는
    // 스킬 전 보드의 것과 그대로 일치한다 — `event.cells` 만 새 색으로
    // 바꿔 주면 그 단계가 화면에 그대로 드러난다.
    // [BattleResolveResult.heroSkillEvents] 는 항상 비어있지 않은 리스트를
    // 돌려주므로 null 분기는 두지 않는다.
    final skillEvents = result.heroSkillEvents;
    for (final e in skillEvents) {
      if (e.effect != HeroSkillEffect.convertColor) continue;
      for (final c in e.cells) {
        final v = _vis[c];
        if (v == null) continue;
        v.rune = e.element;
      }
    }

    if (_waves.isNotEmpty) {
      _beginWave(0);
    } else {
      _syncBoardToVis(battle.state.board);
      _beginResultReveal();
    }
  }

  /// 마지막 파도 정지 확인 → 결과 표기 시작.
  void _beginResultReveal() {
    _snapSettled();
    _play = RunePlayPhase.resultReveal;
    _playT = 0;
    _revealWaveDamage();
  }

  /// **모든 룬이 정지한 뒤** 캐스케이드 결과를 표기한다.
  ///
  /// 1) 방금 정지한 파도의 데미지를 매칭 칸 위에 1건씩 띄운다 (배율 캡션 포함).
  /// 2) 마지막 파도면 영웅 스킬 → 매칭 피해 합계 → 몬스터 반격 순으로 덧붙인다.
  ///
  /// 몬스터 반격은 Black 룬 피해와 **따로** 띄운다. 둘을 합치면 "Black 10 +
  /// 반격 13 = 23" 이 23 하나로 보여 피해 출처를 알 수 없다.
  ///
  /// 합계는 [BattleResolveResult.summedMonsterDamage] 이므로 개별 라벨을 다
  /// 더한 값과 일치한다. **영웅 스킬 독 피해는 포함되지 않는다** — 스킬은
  /// `monsterHits` 가 아니라 [HeroSkillEvent] 로 따로 기록되며, 몬스터 HP 를
  /// 직접 깎는다. 스킬 칩이 같은 자리에 따로 뜨므로 정보는 안 잃는다.
  void _revealWaveDamage() {
    final r = _resolve;
    if (r != null) {
      final waveNo = _waveIndex + 1;
      final last = _waveIndex >= _waves.length - 1;

      final heroDamageEvents = r.heroDamageEvents
          .where(
            (event) =>
                event.waveNumber == waveNo ||
                (last &&
                    (event.waveNumber == 0 ||
                        event.waveNumber == HeroDamageEvent.monsterTurnWave)),
          )
          .toList();
      if (heroDamageEvents.isNotEmpty) {
        onHeroDamage?.call(heroDamageEvents);
      }

      var shownFloaters = 0;
      for (final hit in <DamageHit>[...r.monsterHits, ...r.partyHits]) {
        // waveNumber 0(직접 타격)은 마지막 파도에만 표기.
        final isDirect = hit.waveNumber == 0;
        if (isDirect && !last) continue;
        if (!isDirect && hit.waveNumber != waveNo) continue;
        // Black 5+ 정화(피해 0)는 숫자를 띄우지 않는다 — "0" 플로터는 버그로
        // 읽힌다. 타일 섬광과 HP 변화로 정화 사실이 드러난다.
        if (hit.damage <= 0) continue;
        if (hit.source == DamageSource.blackMatch) {
          if (shownFloaters < _maxBoardFloaters) {
            _spawnHitFloater(hit);
            shownFloaters++;
          }
        } else {
          // 상한 없이 전량 전달 — 화면에 몇 개까지 띄울지는 뷰가 정한다.
          onMonsterDamage?.call(hit);
        }
      }

      // 속성 영웅 없음 경고: 매치는 했는데 그 색 살아있는 영웅이 없어 데미지가
      // 0이었던 경우. 몬스터 중앙에 "그 색 영웅의 룬을 매치하세요" 경고를
      // 띄우기 위해 뷰로 넘긴다. 중복 속성은 한 번만 알린다.
      if (last) {
        final noHeroElements = <RuneElement>{};
        for (final hit in r.monsterHits) {
          if (hit.noElementHero) noHeroElements.add(hit.element);
        }
        for (final e in noHeroElements) {
          onNoElementHero?.call(e);
        }
      }

      if (last) {
        // Pure Dart가 효과를 계산했고, 여기서는 영웅 스킬만 재생한다.
        _playHeroSkillEvents(r.heroSkillEvents);

        // 매칭 피해 합계 정산. 개별 라벨은 파도 간격(1.9초+) 때문에 절대
        // 겹치지 않아 연쇄 총량이 눈으로 안 들어온다 — 마지막에 한 번 보여준다.
        if (r.summedMonsterDamage > 0) {
          onMonsterDamageTotal?.call(r.summedMonsterDamage);
        }

        // 몬스터 반격은 Black 룬 피해와 분리 표기 (출처 구분).
        final atk = r.monsterAttackEvent;
        if (atk != null && atk.damage > 0) {
          if (!atk.isBossUltimate) onMonsterAttack?.call(atk);
          _spawnFloater(
            '-${atk.damage}',
            Vector2(_boardPx / 2, _tile * 5.3),
            const Color(0xFFFF6B6B),
            fontScale: 1.15,
            duration: 1.3,
          );
        }
      }
    }

    // 보류했던 HUD를 이 시점에 한 번에 반영.
    // 해석 결과가 없더라도 반드시 flush — 보류 상태로 남으면 HUD 가 멈춘다.
    _flushHud();
  }

  /// 매칭 1건의 데미지 표기: 발생 칸 위에 확정 수치 + 적용 배율 캡션.
  void _spawnHitFloater(DamageHit hit) {
    final toParty = hit.source == DamageSource.blackMatch;
    final color = toParty ? const Color(0xFFFF6B6B) : Color(hit.element.argb);
    final anchor = hit.cells.isEmpty
        ? Vector2(_boardPx / 2, _tile * 2.6)
        : _cellCenter(hit.cells.first);
    _spawnFloater(
      '-${hit.damage}',
      anchor,
      color,
      sub: hit.caption,
      fontScale: toParty ? 0.9 : 1.0,
      duration: 1.2,
    );
  }

  /// 칸 인덱스의 타일 위쪽 중앙 좌표 (플로터 배치 기준).
  Vector2 _cellCenter(int index) => Vector2(
    (index % PuzzleBoard.cols) * _tile + _tile / 2,
    (index ~/ PuzzleBoard.cols) * _tile + _tile * 0.34,
  );

  /// 모든 타일을 완전 정지 상태로 스냅한다.
  ///
  /// 다음 파도/결과 표기의 선행 조건. 오프셋/알파/스케일을 정확히 0/1로
  /// 고정해 "모든 룬이 멈춘 상태"를 보장한다.
  void _snapSettled() {
    for (var i = 0; i < PuzzleBoard.size; i++) {
      final v = _vis[i];
      if (v == null) continue;
      v.offset = Vector2.zero();
      v.alpha = 1;
      v.scale = 1;
      v.flash = 0;
    }
  }

  /// 영웅 스킬 연출 재생 전용 (Flame은 전투 계산을 하지 않는다).
  ///
  /// [BattleResolveResult.heroSkillEvents] 를 순서대로 소비해
  /// 플로터 텍스트 + 타일 섬광만 만든다. 보드/HP 변경은 이미 엔진이 끝냈다.
  /// 모든 룬이 정지한 뒤([_beginResultReveal]) 마지막 파도에서만 호출한다.
  ///
  /// 수치가 붙는 효과(Water 피해/Grass 회복/독 스택)는 수치까지 표기해, 같은
  /// 숫자가 나왔을 때 무엇이 바뀐 것인지 읽을 수 있게 한다.
  ///
  /// **독 스택은 여기서 숫자를 띄우지 않는다.** 스택은 붙는 것만 하고 데미지는
  /// 매 몬스터 턴 [DamageSource.poisonTick] 로 일어나므로, [_revealWaveDamage]
  /// 가 몬스터 HP 라벨로 보여 준다. 여기서 또 띄우면 같은 피해가 두 번 보인다.
  ///
  /// [BattleResolveResult.heroSkillWaves] (Light 폭발로 발생하는 캐스케이드
  /// 파도)는 **아직 프레임 단위로 재생하지 않는다** — 메인 [RunePlayPhase]
  /// 파이프라인이 [_waves] 하나만 처리하도록 되어 있어, 후속 파도는
  /// [_finishPlayback] 의 [_syncBoardToVis] 에서 최종 보드로 스냅된다.
  /// 효과 자체(HP/보드)는 엔진이 이미 확정했으므로 결과에는 영향이 없고,
  /// 연쇄 매칭 연출까지 넣으려면 [_advancePlayback] 에 2차 파도 상태를 추가해야 한다.
  void _playHeroSkillEvents(List<HeroSkillEvent>? events) {
    if (events == null || events.isEmpty) return;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final effect = e.effect;

      // Water 의 즉사는 몬스터 HP 라벨 경로로 보낸다 (플로터가 아니라).
      if (effect == HeroSkillEffect.damagePerRune) {
        if (e.amount > 0) {
          onMonsterDamage?.call(
            DamageHit(
              source: DamageSource.heroSkill,
              element: e.element,
              damage: e.amount,
            ),
          );
        }
        continue;
      }

      // 회복/스택은 수치까지 붙인다. 폭발·변환은 칸 수보다 "무엇이 일어났는가"가
      // 중요하므로 이모지만 띄운다.
      final showAmount =
          effect == HeroSkillEffect.healPerRune ||
          effect == HeroSkillEffect.poisonStacks;
      _spawnFloater(
        '${effect.floaterEmoji}${showAmount ? ' ${e.amount}' : ''}',
        Vector2(_boardPx / 2, _tile * (1.0 + i * 0.9)),
        Color(e.element.argb),
        fontScale: 0.85,
        duration: 1.1,
      );

      // Fire(색 전량 변환) / Light(3×3 제거) 는 칸이 바뀌는 스킬이다.
      // 변환 단계는 [_kickHeroSkillPlayback] 이 파도 시작 **전**에 `_vis` 에
      // 반영하므로 여기서 따로 점등하지 않는다 — 이 시점의 `_vis` 는 이미
      // 최종 보드라 e.cells 좌표의 타일이 바뀌어 있어, 여기다 다시 켜면
      // 엉뚱한 칸이 하얗게 번진다.
    }
  }

  /// 파도 인지 시작: 콤보 FX를 준비하고 매칭 강조 단계로 들어간다.
  void _beginWave(int index) {
    _waveIndex = index;
    final wave = _waves[_waveIndex];
    _armComboFX(wave.combo, wave.removedCells);
    _play = RunePlayPhase.matchHold;
    _playT = 0;
  }

  /// 파도별 낙하 준비: 이 파도의 제거 셀만 반영한 파도 종료 보드
  /// (`WaveResult.boardAfter`)를 목표로 중력 낙하 거리를 계산한다.
  void _beginWaveSettle() {
    final wave = _waves[_waveIndex];
    _buildSettleMapping();
    _settleStart = {};
    _settleNew = {};
    for (var i = 0; i < PuzzleBoard.size; i++) {
      final row = i ~/ PuzzleBoard.cols;
      final src = _fallFrom[i] ?? row.toDouble();
      if (src < 0) {
        _settleStart[i] = Vector2(0, (-1 - row) * _tile);
        _settleNew[i] = true;
      } else {
        _settleStart[i] = Vector2(0, (src - row) * _tile);
        _settleNew[i] = false;
      }
    }
    final target = wave.boardAfter ?? battle.state.board;
    _syncBoardToVis(target);
    // 낙하 시간 = 최대 낙하 거리 비례. 멀리 떨어지는 룬이 짧은 시간에 "붙지"
    // 않게 해서 정지 순간이 납득된다.
    var maxDrop = 1.0;
    for (final so in _settleStart.values) {
      final d = so.y.abs() / _tile;
      if (d > maxDrop) maxDrop = d;
    }
    _settleDurCur = (_settleDurMin + maxDrop * 0.06).clamp(
      _settleDurMin,
      _settleDurMax,
    );
    _play = RunePlayPhase.settle;
    _playT = 0;
  }

  void _buildSettleMapping() {
    _fallFrom = {};
    for (var c = 0; c < PuzzleBoard.cols; c++) {
      // 제거되지 않은 생존 타일 (아래→위 순서)
      final survivors = <int>[];
      for (var y = PuzzleBoard.rows - 1; y >= 0; y--) {
        final i = y * PuzzleBoard.cols + c;
        if (_vis[i] != null && !_removedSet.contains(i)) survivors.add(y);
      }
      for (var y = PuzzleBoard.rows - 1; y >= 0; y--) {
        final i = y * PuzzleBoard.cols + c;
        final depth = PuzzleBoard.rows - 1 - y; // 바닥부터 0
        _fallFrom[i] = depth < survivors.length
            ? survivors[depth].toDouble()
            : -1;
      }
    }
  }

  void _finishPlayback() {
    _play = RunePlayPhase.idle;
    _playT = 0;
    _waves = [];
    _removedSet = {};
    _fallFrom = {};
    _settleStart = {};
    _settleNew = {};
    _swapMove = null;
    _waveIndex = 0;
    _dragFrom = null;
    _hover = null;
    _clearSelectedTile();
    // 조준 모드는 한 턴의 입력에 속하므로 보드가 리셋되면 함께 사라진다.
    // 다음 턴에 조준 상태로 남아 있으면 "방금 쓴 스킬"이 다시 조준된다.
    _armedSkillHeroId = null;
    _resolve = null;
    _autoShuffleAfterPlayback = false;
    // 스킬(Water 정화 등) 후속 파도는 엔진에서 처리했으므로 최종 보드로
    // 스냅한다. 이 동기화가 없으면 화면과 로직 보드가 어긋나 다음 턴 낙하/연쇄가
    // 예측 불가능해진다.
    _syncBoardToVis(battle.state.board);
    _hudDeferred = false;
    _hudPending = false;
    _hudChanged();
  }

  void _spawnFloater(
    String text,
    Vector2 center,
    Color color, {
    String? sub,
    double fontScale = 1.0,
    double duration = _kFloaterDur,
  }) {
    final fontSize = _tile * 0.52 * fontScale;
    final caption = (sub == null || sub.isEmpty) ? null : sub;
    _floaters.add(
      _FloatingText(
        text,
        center,
        TextPaint(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 4)],
          ),
        ),
        sub: caption,
        subPaint: caption == null
            ? null
            : TextPaint(
                style: TextStyle(
                  fontSize: fontSize * 0.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xB3FFFFFF),
                  shadows: const [
                    Shadow(color: Color(0xFF000000), blurRadius: 3),
                  ],
                ),
              ),
        duration: duration,
      ),
    );
  }

  // ── 콤보 연출 (팝업 / 스파크 / 쉐이크) ──

  /// 콤보 Wave 시작 시 임팩트 연출을 배치하고 뷰 촉각 훅을 호출한다.
  void _armComboFX(int combo, Set<int> cells) {
    if (combo <= 0) return;
    _spawnComboPop(combo);
    _spawnSparks(combo, cells);
    // 콤보가 높을수록 쉐이크 강도가 커진다 (감쇠는 update에서).
    _shakeT = 0.38;
    _shakeAmp = math.min(3.0 + combo * 2.0, 13.0);
    onComboEffect?.call(combo);
  }

  void _spawnComboPop(int combo) {
    final isBig = combo >= 3;
    final isHuge = combo >= 5;
    final color = isHuge
        ? const Color(0xFFFF5252)
        : isBig
        ? const Color(0xFFFFB300)
        : const Color(0xFFFFD166);
    // 축소형 콤보 팝업: 기존(1.2+0.3c → 4.0t)보다 작고 보드 중앙에 위치.
    final fontSize = math.min(_tile * (0.85 + combo * 0.15), _tile * 2.0);
    _combos.add(
      _ComboPop(
        combo,
        Vector2(_boardPx / 2, _boardPx * 0.3),
        TextPaint(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const [
              Shadow(
                color: Color(0x99000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _spawnSparks(int combo, Set<int> cells) {
    final countPer = math.min(2 + combo, 7);
    final baseSpeed = 60.0 + combo * 30.0;
    for (final i in cells) {
      final ex = (i % PuzzleBoard.cols) * _tile + _tile / 2;
      final ey = (i ~/ PuzzleBoard.cols) * _tile + _tile / 2;
      final color = _sparkColor(_vis[i]?.rune);
      for (var k = 0; k < countPer; k++) {
        final ang = _fxRandom.nextDouble() * math.pi * 2;
        final spd = baseSpeed * (0.5 + _fxRandom.nextDouble());
        _sparks.add(
          _Spark(
            Vector2(ex, ey),
            Vector2(math.cos(ang), math.sin(ang)) * spd,
            color,
            _tile * (0.06 + _fxRandom.nextDouble() * 0.08),
          ),
        );
      }
    }
  }

  static Color _sparkColor(RuneElement? e) {
    switch (e) {
      case RuneElement.fire:
        return const Color(0xFFFF6B35);
      case RuneElement.grass:
        return const Color(0xFF7BC96F);
      case RuneElement.water:
        return const Color(0xFF4FC3F7);
      case RuneElement.light:
        return const Color(0xFFFFE082);
      case RuneElement.poison:
        return const Color(0xFFAA66CC);
      case RuneElement.black:
        return const Color(0xFF9E9E9E);
      case null:
        return const Color(0xFFF7F0D6);
    }
  }

  /// HUD 변경 통지.
  ///
  /// 캐스케이드 재생 중([_hudDeferred])에는 보류해서, 모든 룬이 정지하고
  /// 데미지 표기가 시작되는 시점에 HP 바/게이지가 한 번에 갱신되게 한다.
  void _hudChanged() {
    if (_hudDeferred) {
      _hudPending = true;
      return;
    }
    onHudChanged?.call();
  }

  /// 보류된 HUD 통지를 즉시 flush 한다.
  void _flushHud() {
    if (!_hudDeferred) return;
    _hudDeferred = false;
    if (!_hudPending) return;
    _hudPending = false;
    onHudChanged?.call();
  }

  static double _easeInOut(double t) => t * t * (3 - 2 * t);

  /// 파도 플래시: 0.25 / 0.75 시점 두 번 펄스.
  static double _wavePulse(double p) {
    final da = (p - 0.25).abs();
    final db = (p - 0.75).abs();
    return math.max(0.0, 1 - math.min(da, db) * 4);
  }
}

/// 6×6 보드를 그리며 탭/드래그 이벤트를 받는 레이어.
class RuneBoardLayer extends PositionComponent
    with TapCallbacks, DragCallbacks {
  RuneBoardLayer(this.game);

  final RuneBattleGame game;

  final Paint _bgPaint = Paint()..color = const Color(0xFF16142A);
  final Paint _gridPaint = Paint()
    ..color = const Color(0x18FFFFFF)
    ..strokeWidth = 1;
  final Paint _hoverPaint = Paint()..color = const Color(0x4DFFFFFF);

  Vector2 _local(Vector2 canvasPosition) => canvasPosition - position;

  // ── 입력 ──

  bool _inputAllowed() =>
      game.isIdle &&
      !game.battle.state.paused &&
      (game.battle.state.phase == BattlePhase.plan ||
          game.battle.state.phase == BattlePhase.action);

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!_inputAllowed()) return;
    final i = game.tileAtLocal(_local(event.canvasPosition));
    if (i == null) return;
    game._onBoardTap(i);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_inputAllowed()) return;
    final local = _local(event.canvasPosition);
    final i = game.tileAtLocal(local);
    if (i == null) return;
    game._lastDragLocal = local;
    game._onBoardDragStart(i);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final from = game._dragFrom;
    if (from == null) return;
    // 오버슛 보정 (요청 7): 손가락이 보드 밖/먼 칸으로 나가도
    // 드래그 벡터 방향의 인접 칸으로 hover를 유지한다.
    final local = _local(event.canvasEndPosition);
    game._lastDragLocal = local;
    final i = game.tileAtLocal(local);
    int? hover;
    if (i != null) {
      if (PuzzleBoard.isAdjacent(from, i)) {
        hover = i;
      } else if (game._hover != null) {
        // 비인접 칸으로 오버슛: 직전 인접 hover 유지
        hover = game._hover;
      }
    } else {
      // 보드 밖: 드래그 방향 기준 인접 칸으로 hover 유지
      hover = game._neighborToward(from, local);
    }
    game._onBoardDragUpdate(hover);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game._onBoardDragEnd(from: game._dragFrom, hover: game._hover);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    onDragEnd(event.toDragEnd());
  }

  // ── 렌더링 ──

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // 콤보 쉐이크: 전체 보드를 미세하게 진동시킨다 (감쇠하며 사라짐).
    canvas.save();
    final shake = game.shakeMag;
    if (shake > 0) {
      canvas.translate(
        (game._fxRandom.nextDouble() * 2 - 1) * shake,
        (game._fxRandom.nextDouble() * 2 - 1) * shake,
      );
    }

    final boardRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      _bgPaint,
    );

    for (var i = 1; i < PuzzleBoard.cols; i++) {
      final x = i * game._tile;
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
      canvas.drawLine(Offset(0, x), Offset(size.x, x), _gridPaint);
    }

    for (var i = 0; i < PuzzleBoard.size; i++) {
      final v = game._vis[i];
      if (v == null) continue;
      final x = i % PuzzleBoard.cols;
      final y = i ~/ PuzzleBoard.cols;
      _drawTile(
        canvas,
        v,
        x * game._tile + v.offset.x,
        y * game._tile + v.offset.y,
      );
    }

    if (game._hover != null && game._dragFrom != null) {
      final h = game._hover!;
      final rect = Rect.fromLTWH(
        (h % PuzzleBoard.cols) * game._tile,
        (h ~/ PuzzleBoard.cols) * game._tile,
        game._tile,
        game._tile,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(game._tile * 0.16)),
        _hoverPaint,
      );
    }
    if (game._selectedTile != null) {
      final selected = game._selectedTile!;
      final rect = Rect.fromLTWH(
        (selected % PuzzleBoard.cols) * game._tile,
        (selected ~/ PuzzleBoard.cols) * game._tile,
        game._tile,
        game._tile,
      ).deflate(game._tile * 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(game._tile * 0.16)),
        Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, game._tile * 0.06).toDouble(),
      );
    }

    // 조준 모드: 지정 가능한 칸만 발광시킨다. **유효 판정과 표시가 같은 규칙**
    // (BattleEngine.isValidSkillTarget) 을 써야 "빛나는 칸을 눌렀는데 안 된다"가
    // 생기지 않는다. 유효 타겟이 하나도 없으면(예: 화염 보드에 불만 남음) 붉은
    // X 로 "지금은 못 쓴다"를 알린다.
    //
    // **왜 스프라이트가 아닌 Canvas 직접 그리기인가**: 맥동(pulse) 효과는 시간에
    // 따라 알파가 변하는 동적 효과라 정적 9-slice 스프라이트로 표현할 수 없다.
    // 스프라이트 체계(`ui_dummy/`)는 정적 테두리 전용이며, 이 조준 링은 매 프레임
    // 다시 그려야 하므로 `Paint` + `drawRRect` 가 유일한 방법이다. 색상은 속성
    // 팔레트(`RuneElement.argb`)를 그대로 써서 스프라이트 틴트 규칙과 일치한다.
    final armedSpec = game._armedSkill;
    if (armedSpec != null) {
      final pulse = 0.55 + 0.45 * math.sin(game.now * 4.0).abs();
      final tint = Color(armedSpec.element.argb);
      final targets = game.battle.validSkillTargets(armedSpec);
      if (targets.isEmpty) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, game._boardPx, game._boardPx),
            Radius.circular(game._tile * 0.16),
          ),
          Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.22),
        );
      } else {
        for (final i in targets) {
          final rect = Rect.fromLTWH(
            (i % PuzzleBoard.cols) * game._tile,
            (i ~/ PuzzleBoard.cols) * game._tile,
            game._tile,
            game._tile,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(game._tile * 0.16)),
            Paint()..color = tint.withValues(alpha: 0.20 * pulse),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.deflate(game._tile * 0.05),
              Radius.circular(game._tile * 0.16),
            ),
            Paint()
              ..color = tint.withValues(alpha: 0.85 * pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, game._tile * 0.045).toDouble(),
          );
        }
      }
    }

    // 콤보 임팩트 스파크 (방사형 + 중력 + 페이드).
    for (final s in game._sparks) {
      final p = s.age / _Spark.duration;
      canvas.drawCircle(
        s.pos.toOffset(),
        math.max(0.5, s.size * (1 - p * 0.8)),
        Paint()..color = s.color.withValues(alpha: 1 - p),
      );
    }

    // 콤보 카운트업 팝업 (팝인 → 유지 → 페이드아웃).
    for (final c in game._combos) {
      final p = c.progress;
      // 스케일: 팝인(0→0.15) → 안정(→0.7) → 마지막 30% 확대며 페이드아웃.
      double scale;
      if (p < 0.15) {
        scale = 0.4 + (p / 0.15) * 0.75; // 0.4 → 1.15
      } else if (p < 0.35) {
        scale = 1.15 - ((p - 0.15) / 0.2) * 0.15; // 1.15 → 1.0
      } else if (p > 0.7) {
        scale = 1.0 + ((p - 0.7) / 0.3) * 0.2;
      } else {
        scale = 1.0;
      }
      final alpha = p > 0.7 ? 1 - ((p - 0.7) / 0.3) : 1.0;
      final bounce =
          math.sin(math.min(1.0, p * 2) * math.pi) * -game._tile * 0.14;
      canvas.save();
      canvas.translate(c.center.x, c.center.y + bounce);
      canvas.scale(scale);
      canvas.saveLayer(
        null,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
      c.paint.render(
        canvas,
        'COMBO x${c.combo}',
        Vector2.zero(),
        anchor: Anchor.center,
      );
      canvas.restore(); // alpha 레이어
      canvas.restore(); // 스케일/위치
    }

    for (final f in game._floaters) {
      final p = f.progress;
      // 마지막 30% 페이드아웃 — 겹친 숫자를 읽을 수 있게 하고 잔상을 지운다.
      final alpha = p > 0.7 ? 1 - ((p - 0.7) / 0.3) : 1.0;
      final y = f.center.y - p * game._tile * 1.1;
      canvas.saveLayer(
        null,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
      f.paint.render(
        canvas,
        f.text,
        Vector2(f.center.x, y),
        anchor: Anchor.center,
      );
      final sub = f.sub;
      final subPaint = f.subPaint;
      if (sub != null && subPaint != null) {
        subPaint.render(
          canvas,
          sub,
          Vector2(f.center.x, y + game._tile * 0.42),
          anchor: Anchor.center,
        );
      }
      canvas.restore();
    }
    canvas.restore(); // 쉐이크
  }

  void _drawTile(Canvas canvas, _VisTile v, double tx, double ty) {
    final inset = game._tile * 0.05;
    final s = game._tile * v.scale;
    final centered = (game._tile - s) / 2;
    final rect = Rect.fromLTWH(
      tx + centered + inset,
      ty + centered + inset,
      s - inset * 2,
      s - inset * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(game._tile * 0.15),
    );

    final base = Color(v.rune.argb);
    canvas.drawRRect(rrect, Paint()..color = base.withValues(alpha: v.alpha));

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x38000000).withValues(alpha: v.alpha),
    );

    if (v.flash > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(
            0xFFFFFFFF,
          ).withValues(alpha: v.flash * 0.85 * v.alpha),
      );
    }

    // 룬 아이콘: 시트 스프라이트가 준비되면 이미지로, 아니면 이모지로 폴백.
    final sprite = game._runeSprites[v.rune];
    final tp = game._emojiPaint;
    canvas.save();
    canvas.clipRRect(rrect);
    if (sprite != null) {
      canvas.drawImageRect(
        sprite.image,
        sprite.src,
        _runeIconDest(rect),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = const Color(0xFFFFFFFF).withValues(alpha: v.alpha),
      );
    } else if (tp != null) {
      tp.render(
        canvas,
        v.rune.emoji,
        rect.center.toVector2(),
        anchor: Anchor.center,
      );
    }
    canvas.restore();
  }

  /// 시트 아이콘(54×59, [RuneElement.runeSpriteIconWidth]×[…]Height)을
  /// 타일 rect 안에 원본 비율을 유지하며 여백을 두고 맞춘 목적지 사각형.
  Rect _runeIconDest(Rect box) {
    const aspect =
        RuneElement.runeSpriteIconWidth / RuneElement.runeSpriteIconHeight;
    var w = box.width * 0.9;
    var h = w / aspect;
    if (h > box.height * 0.9) {
      h = box.height * 0.9;
      w = h * aspect;
    }
    return Rect.fromCenter(center: box.center, width: w, height: h);
  }
}
