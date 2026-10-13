/// Rune Puzzle Tactics — 게이지 바 (HP/XP/확률/피 진행률).
///
/// 예전에 `ClipRRect(radius) > LinearProgressIndicator(...)` 로 그리고 있던
/// 바 5곳을 하나로 모은다. Material 의 `LinearProgressIndicator` 를 안 쓰는
/// 이유는 두 가지다:
///
///  1. `LinearProgressIndicator` 는 **테두리를 그릴 수 없다.** 위젯 하나로
///     바를 표현하려면 바깥 테두리를 또 다른 위젯으로 겹쳐야 했고, 그러면
///     테두리 모양이 바의 모양과 어긋날 수 있었다. 지금은 껍데기/트랙/채움
///     스프라이트 3장을 층으로 쌓아 한 위젯에서 끝난다.
///  2. 라운드 반경을 이미지에 굽는다. `LinearProgressIndicator` 는 반경이
///     고정값이라 높이 3px 피 바와 높이 12px HP 바를 같은 코드로 못 그린다.
///
/// **층 순서**
/// ```
///   트랙(배경)  →  채움(value)  →  껍데기(테두리)
/// ```
/// 껍데기를 **맨 위**에 깔아야 짧은 값이어도 테두리가 안 가려진다.
///
/// **알파**
///
/// 세 장 모두 흰색 단색 스프라이트라 `srcIn` 틴트로 각각 다른 색을 입힌다.
/// 색에 알파를 담아 넘기면 그대로 반영된다 — 옛
/// `backgroundColor: Colors.black38` 는 `trackColor` 에 그대로 넣는다.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/ui_sprites.dart';

/// 값 바 하나.
///
/// ```dart
/// UiBar(
///   value: hp / maxHp,          // 0..1 로 클램프된다
///   fillColor: AppColors.green,
///   trackColor: Colors.black38,
///   height: 6,
/// )
/// ```
class UiBar extends StatelessWidget {
  const UiBar({
    super.key,
    required this.value,
    required this.fillColor,
    this.trackColor = const Color(0x61000000),
    this.borderColor = AppColors.glassBorder,
    this.height = 6,
    this.duration = const Duration(milliseconds: 260),
  });

  /// 0..1. 범위 밖이면 클램프한다.
  final double value;

  /// 채움색.
  final Color fillColor;

  /// 바 배경색. 옛 `backgroundColor`.
  final Color trackColor;

  /// 바 테두리색. 옛 바에는 테두리가 없었는데, 스프라이트 크롬으로 통일하려고
  /// [AppColors.glassBorder] 기본값을 넣었다. 테두리를 아예 없애려면
  /// `Colors.transparent` 을 넘긴다.
  final Color borderColor;

  /// 바 높이(px). 3~12 범위.
  final double height;

  /// 값 변화 애니메이션. 세그먼트 바의 옛 `AnimatedContainer(260ms)` 와 같다.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // `Tween(begin: null)` 이면 [TweenAnimationBuilder] 가 **이전 값**에서
    // 출발하므로 첫 빌드에서도 0 → value 로 자연스럽게 올라간다. `begin: 0` 을
    // 주면 리빌드마다 0 에서 다시 올라와 깜빡인다.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: duration,
      builder: (context, v, _) {
        return SizedBox(
          height: height,
          // 바는 항상 가로로 부모를 꽉 채운다. 옛 `LinearProgressIndicator` 도
          // `constraints.maxWidth` 로 폭을 정했으므로 같은 동작이다 — 그래서
          // `Column(crossAxisAlignment: start)` 안에 두면 화면 끝까지 뻗는다.
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.hasBoundedWidth ? box.maxWidth : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _plate(kUiBarTrack, trackColor, w),
                  // 왼쪽 정렬로 `value` 비율만큼만 채운다. 0 이면 폭 0 이라
                  // 아무것도 안 그려진다.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: w * v,
                      height: height,
                      // 트랙과 **같은 반경·같은 분할**이라 실루엣이 일치한다.
                      // 각지게 그렸으면 값이 작을 때 좌측 코너가 트랙의 둥근
                      // 모서리를 2px 뚫고 나간다.
                      child: _plate(kUiBarFill, fillColor, w * v),
                    ),
                  ),
                  _plate(kUiBarShell, borderColor, w),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 바 판 1장.
  ///
  /// [width] 는 이 판이 실제로 그려질 폭이다. 트랙/껍데기는 바 전체 폭이지만
  /// **채움 판은 `w × value` 만큼만 좁다** — 값이 작으면 몇 px 밖에 안 된다.
  ///
  /// 그래서 판이 [kUiBarBorder] 보다 작으면 **9-slice 를 쓰지 않는다.** Flutter
  /// 의 `paintImage` 은 `centerSlice` 를 쓰면 "그림 − 슬라이스" 만큼을 양쪽
  /// 여백으로 소비하는데, 그 여백이 판 크기를 넘으면 아래 assert 로 죽는다:
  ///
  /// ```
  /// 'sourceSize == inputSize': centerSlice was used with a BoxFit that
  /// does not guarantee that the image is fully visible.
  /// ```
  ///
  /// 이 경계는 사람이 읽기 어렵다 — 슬라이스 상수를 바꾸거나 `height` 를
  /// 조정하는 것만으로 아무 예고 없이 터진다. 그래서 **크기부터 확인한다.**
  /// 작은 판(수 px 폭의 채움, 3px 피티 바)은 통째로 늘려도 반경 2 스프라이트
  /// 라 눈에 띄지 않는다.
  Widget _plate(String asset, Color color, double width) {
    final sliceable =
        width > kUiBarBorder.width && height > kUiBarBorder.height;
    return Image.asset(
      asset,
      fit: BoxFit.fill,
      centerSlice: sliceable ? kUiBarSlice : null,
      filterQuality: FilterQuality.none,
      color: color,
    );
  }
}