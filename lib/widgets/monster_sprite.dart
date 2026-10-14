/// Rune Puzzle Tactics — 몬스터(슬라임) 스프라이트 위젯.
///
/// `assets/sprites/monster/slime/` 의 상태별 10프레임 애니메이션을
/// 배틀 상황(BattleState/BattleEngine)에 맞춰 재생한다.
/// 상황 판정은 모두 BattleState의 단일 소스에서 읽는다 (RPT-126).
///  - idle  : 플레이어 턴(대기/액션) 동안 루프
///  - attack: 몬스터 턴(monsterTurn) 동안 루프
///  - damage: 몬스터가 피격(HP 감소) 시 1회 재생
///  - death : 몬스터 HP 0(victory) 시 1회 재생 후 마지막 프레임 유지
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../services/game_audio_service.dart';

/// 슬라임 몬스터 스프라이트.
/// [battle] 상태와 [hud] 알림(ValueNotifier 등 Listenable)을 구독해 상황을 판정한다.
class MonsterSprite extends StatefulWidget {
  const MonsterSprite({
    super.key,
    required this.battle,
    required this.hud,
    this.audioService,
  });

  final BattleEngine battle;
  final Listenable hud;
  final GameAudioService? audioService;

  @override
  State<MonsterSprite> createState() => _MonsterSpriteState();
}

class _MonsterSpriteState extends State<MonsterSprite>
    with SingleTickerProviderStateMixin {
  static const int _frameCount = 10;

  /// 슬라임 프레임 파일 접두어. 각 상태 폴더에 1~40 전체 번호로 나열되어 있다.
  static const String _base = 'assets/sprites/monster/slime';
  static const String _prefix =
      'Gemini_Generated_Image_mqz1aemqz1aemqz1_(1)_10_4_';

  /// 상태별 시작 프레임 번호 오프셋 (idle=1~10, attack=11~20, damage=21~30, death=31~40).
  static const Map<String, int> _offsets = {
    'idle': 0,
    'attack': 10,
    'damage': 20,
    'death': 30,
  };

  /// 상태별 1 사이클(10프레임) 길이.
  static const Map<String, Duration> _durations = {
    'idle': Duration(milliseconds: 700), // ~14fps 루프
    'attack': Duration(milliseconds: 830), // ~12fps 원샷
    'damage': Duration(milliseconds: 620), // ~16fps 원샷
    'death': Duration(milliseconds: 830), // ~12fps 원샷
  };

  late final Map<String, List<Image>> _frames;
  late final AnimationController _controller;

  String _cur = 'idle';
  int _frame = 0;
  int _lastHp = 0;
  bool _precached = false;

  static String _asset(String state, int frame) =>
      '$_base/$state/$_prefix${_offsets[state]! + frame + 1}.png';

  @override
  void initState() {
    super.initState();
    final s = widget.battle.state;
    _lastHp = _monsterHp(s);
    _frames = {
      for (final s in ['idle', 'attack', 'damage', 'death'])
        s: List.generate(
          _frameCount,
          (i) => Image.asset(_asset(s, i), fit: BoxFit.contain),
        ),
    };
    _controller = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    widget.hud.addListener(_onHud);
    _controller.duration = _durations['idle'];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // 첫 진입 시 프레임을 미리 로드해 전환 시 빈 화면을 방지한다.
    for (final state in ['idle', 'attack', 'damage', 'death']) {
      for (final img in _frames[state]!) {
        unawaited(precacheImage(img.image, context));
      }
    }
    // 최초 진입 시 idle 상태로 시작
    _onHud();
  }

  @override
  void dispose() {
    widget.hud.removeListener(_onHud);
    _controller.removeStatusListener(_onStatus);
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  // ── 상황 판정 ──

  /// 스프라이트가 따라갈 **현재 몬스터 HP**.
  ///
  /// 피해는 [MonsterSlot] 에만 쌓이고 `state.monsterHp` 필드는 갱신되지 않는다
  /// (보스 등장 시 1회만 대입). 그래서 슬롯을 단일 소스로 읽는다.
  /// - 슬롯 1개(페이즈2 보스 / 레거시 단일): 그 슬롯의 HP
  /// - 슬롯 3개(페이즈1): 합계 — 공용 스프라이트라 개별 구분은 못 하지만
  ///   "무언가 맞았다 / 전멸했다"는 정확히 전달된다
  int _monsterHp(BattleState s) => s.monsterHpTotal;

  void _onHud() {
    if (!mounted) return;
    final s = widget.battle.state;
    final hp = _monsterHp(s);
    final dead = hp <= 0;
    final hurt = hp < _lastHp;
    _lastHp = hp;

    if (dead) {
      // 사망 우선: 1회 재생 후 마지막 프레임 유지.
      if (_cur != 'death') {
        _cur = 'death';
        _frame = 0;
        _playSound(GameSound.monsterDeath);
        _controller
          ..stop()
          ..duration = _durations['death']
          ..forward(from: 0);
        if (mounted) setState(() {});
      }
      return;
    }
    if (hurt) {
      // 피격 우선. damage 1회 재생 후 idle 루프로 복귀
      _playSound(GameSound.monsterHit);
      _play('damage', oneShot: true);
      return;
    }
    // 몬스터 턴일 때 attack 애니메이션 (루프)
    if (s.phase == BattlePhase.monsterTurn) {
      if (_cur != 'attack') _playSound(GameSound.monsterAttack);
      _play('attack', oneShot: false); // 루프 재생
      return;
    }

    // 그 외에는 idle 루프 유지
    _play('idle');
  }

  void _playSound(GameSound sound) {
    (widget.audioService ?? GameAudioService.instance).playEffect(sound);
  }

  // ── 애니메이션 ──

  void _play(String state, {bool oneShot = false}) {
    // 같은 상태 재진입 방지 (oneShot 아닐 때)
    if (!_oneShotGuard(state, oneShot)) return;
    _cur = state;
    _frame = 0;
    _controller
      ..stop()
      ..duration = _durations[state];
    if (oneShot) {
      _controller.forward(from: 0);
    } else {
      _controller.repeat();
    }
    if (mounted) setState(() {});
  }

  bool _oneShotGuard(String state, bool oneShot) {
    // 사망 중인데 non-oneShot로 호출하면 무시
    if (state == 'death' && !oneShot && _cur == 'death') return false;
    // 같은 non-oneShot 루프 재진입 방지
    if (!oneShot && _cur == state) return false;
    return true;
  }

  void _onTick() {
    final f = (_controller.value * _frameCount).floor().clamp(
      0,
      _frameCount - 1,
    );
    if (f == _frame) return;
    _frame = f;
    if (mounted) setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    // completed 이벤트만 처리
    if (status != AnimationStatus.completed) return;

    // 사망은 completed 후 멈춤 유지 (아무것도 안 함, _controller.stop() 이미 _onHud에서 호출됨)
    if (_cur == 'death') return;

    // 그 외(attack, damage 등) completed 후 idle로 복귀
    _play('idle');
  }

  // ── 렌더링 ──

  @override
  Widget build(BuildContext context) {
    final stage = widget.battle.state.stage;
    final isBoss = stage.type == StageType.boss;
    final scale = isBoss ? 1.25 : 1.0; // 보스는 25% 확대

    return Center(
      key: ValueKey('monster_sprite_$_cur'),
      child: AspectRatio(
        aspectRatio: 141 / 192 * scale, // 스케일 적용
        child: IndexedStack(index: _frame, children: _frames[_cur]!),
      ),
    );
  }
}
