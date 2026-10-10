/// Rune Puzzle Tactics — 프레임 시퀀스 스프라이트 재생 (요구사항 9 연출용)
///
/// `assets/effects/` 에는 파이어워크/스파클 시퀀스가 5543장 있지만 pubspec에
/// 선언돼 있지 않아 Historically 미사용 상태였다. 이 위젯은 **선택한 소수의
/// 폴더만** 번들에 올리고, 프레임 시퀀스를 순차 재생한다.
///
/// 설계상 주의점:
/// - `BackdropFilter`(글래스 서피스) 위에 올려도 프레임이 죽지 않게, 이 위젯
///   자체는 blur 를 쓰지 않는다.
/// - 로드/디코드는 `initState` 에서 비동기로 ��고, 완료 전까지 빈 박스를 그린다.
///   (효과가 없는 프리임 프레임이 결과 렌더를 막지 않는다.)
/// - `RawImage` + `ui.Image` 로 그려서 Flutter 이미지 캐시(키 기반 LRU)의
///   1000장 상한에 걸리지 않게 한다. 이 경로는 캐시를 거치지 않는다.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

/// 프레임 시퀀스 이펙트 하나.
///
/// [assetDir] 은 `pubspec.yaml` 의 assets 항목과 **정확히 일치**해야 한다
/// (경로에 공백이 있어도 YAML 문자열로는 정상 동작한다).
class SpriteEffect {
  const SpriteEffect({
    required this.assetDir,
    required this.frameCount,
    this.startFrame = 0,
    this.fps = 24,
  });

  /// 프레임 파일 디렉터리. 예: `assets/effects/Magic Bursts/.../xxx_large_red`.
  final String assetDir;

  /// 순환할 프레임 수.
  final int frameCount;

  /// 시작 프레임 오프셋 — 첫 1~2장이 거의 빈(alpha≈0)인 시퀀스를 건너뛴다.
  final int startFrame;

  /// 재생 속도(frames per second).
  final double fps;

  /// i번째 프레임의 자산 경로.
  String assetAt(int index) =>
      '$assetDir/frame${(startFrame + index).toString().padLeft(4, '0')}.png';

  /// 공개 이펙트 카탈로그.
  ///
  /// 번들 비용을 아끼기 위해 **뽑기 연출에 필요한 2종만** pubspec 에 올린다.
  /// 총 약 35KB.
  static const SpriteEffect sparkle =
      // alpha 프로파일상 0000~0001 이 거의 비어 있어 0002 부터 시작한다.
      SpriteEffect(
        assetDir:
            'assets/effects/Magic Bursts/round_sparkle_burst_003/'
            'round_sparkle_burst_003_large_red',
        frameCount: 15,
        startFrame: 2,
        fps: 26,
      );

  /// 신규 영웅 공개 시 사용하는 대형 파이어워크.
  static const SpriteEffect firework = SpriteEffect(
    assetDir:
        'assets/effects/Magic Bursts/round_firework_burst_002/'
        'round_firework_burst_002_large_yellow',
    frameCount: 25,
    fps: 22,
  );
}

/// [SpriteEffect] 를 한 번 재생하고 끝내는 오버레이.
///
/// 재생이 끝나면 [onDone] 을 부르고 **스스로 사라진다**(부모가 상태를 관리하지
/// 않아도 되도록 함). 재생 중 부모가 rebuild 되면 중단 없이 이어간다.
class SpriteBurst extends StatefulWidget {
  const SpriteBurst({
    super.key,
    required this.effect,
    this.size = 220,
    this.onDone,
    this.playCount = 1,
  });

  final SpriteEffect effect;

  /// 표시 크기(정사각형 기준).
  final double size;

  /// 재생 완료 콜백. ��_called_ 이 재진입을 막지 않도록 내부에서 1회만 부른다.
  final VoidCallback? onDone;

  /// 반복 횟수.
  final int playCount;

  @override
  State<SpriteBurst> createState() => _SpriteBurstState();
}

class _SpriteBurstState extends State<SpriteBurst>
    with SingleTickerProviderStateMixin {
  final List<ui.Image> _frames = [];
  late final Ticker _ticker;
  late final Duration _frameDuration;

  bool _loading = true;
  bool _finished = false;

  /// 현재 표시 중인 프레임 인덱스.
  int _index = 0;

  /// 남은 반복 횟수.
  late int _playsLeft;

  /// 프레임 누적 시간.
  Duration _accumulated = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playsLeft = widget.playCount;
    _frameDuration = Duration(
      microseconds: (1000000 / widget.effect.fps).round(),
    );
    _ticker = createTicker(_onTick)..start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final image in _frames) {
      image.dispose();
    }
    super.dispose();
  }

  /// 모든 프레임을 비동기로 선로드한다.
  Future<void> _load() async {
    final effect = widget.effect;
    final loaded = <ui.Image>[];
    for (var i = 0; i < effect.frameCount; i++) {
      try {
        final data = await rootBundle.load(effect.assetAt(i));
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        loaded.add(frame.image);
      } catch (error) {
        // 프레임 하나가 깨져도 시퀀스는 계속 재생한다(빠진 프레임만 건너뜀).
        debugPrint('SpriteBurst 프레임 로드 실패 (${effect.assetAt(i)}): $error');
      }
    }
    if (!mounted) {
      for (final image in loaded) {
        image.dispose();
      }
      return;
    }
    if (loaded.isEmpty) {
      // 번들에 없거나 전부 실패 — 연출 없이 조용히 사라진다.
      setState(() {
        _loading = false;
        _finished = true;
      });
      return;
    }
    setState(() {
      _frames
        ..clear()
        ..addAll(loaded);
      _loading = false;
    });
  }

  void _onTick(Duration elapsed) {
    if (_loading || _finished) return;
    final step = elapsed - _accumulated;
    if (step < _frameDuration) return;
    _accumulated = elapsed;
    if (_index + 1 < _frames.length) {
      setState(() => _index++);
      return;
    }
    // 마지막 프레임 도달 → 다음 반복 or 종료.
    _playsLeft--;
    if (_playsLeft <= 0) {
      setState(() => _finished = true);
      widget.onDone?.call();
      return;
    }
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished || _frames.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RawImage(
        image: _frames[_index],
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}

/// [SpriteBurst] 를 중앙에 띄우는 오버레이 헬퍼.
///
/// Dialog 의 `Stack` 위에 올릴 때 씁니다. [BackdropFilter] 를 쓰지 않으므로
/// Android 저사양에서 프레임이 튀지 않는다.
class CenteredSpriteBurst extends StatelessWidget {
  const CenteredSpriteBurst({
    super.key,
    required this.child,
    this.effect,
    this.size = 240,
    this.onDone,
  });

  /// [effect] 가 null 이면 아무것도 그리지 않는다(연출 끄기 용).
  final Widget child;
  final SpriteEffect? effect;
  final double size;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final e = effect;
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        if (e != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SpriteBurst(effect: e, size: size, onDone: onDone),
              ),
            ),
          ),
      ],
    );
  }
}
