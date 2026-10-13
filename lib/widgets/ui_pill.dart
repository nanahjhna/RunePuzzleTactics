/// Rune Puzzle Tactics — 칩(pill) / 배지 스프라이트.
///
/// 예전에 `Container(decoration: BoxDecoration(borderRadius: circular(999),
/// border: Border.all(...)))` 로 그리고 있던 칩·배지 7곳을 하나로 모은다.
///
/// **왜 크기가 3벌인가**
///
/// 9-slice 의 모서리 반경은 **늘어나지 않는다**. 옛 `circular(999)` 는 높이 9px
/// 인 그리드 타일 배지부터 높이 35px 인 가차 신정합계까지 모두 완전 둥근
/// 스테디움이었다. 스프라이트 한 장으로 통일하면 큰 칩이 각진 직사각형으로
/// degrade 된다. 그래서 실제 사용 높이 3단계에 맞춰 스프라이트를 3벌 만들고
/// [UiPillSize] 로 고르게 했다.
///
/// ** tier별 반경**
/// ```
///   [UiPillSize.small]   24x12  반경 5.5   1px  (실제 높이 약 9px)
///   [UiPillSize.medium]  32x20  반경 9.5   1px  (실제 높이 약 20px)
///   [UiPillSize.large]   48x36  반경 17.5  2px  (실제 높이 약 35px)
/// ```
///
/// **alpha 를 따로 안 받는 이유**
///
/// 스프라이트 틴트는 `ColorFilter(srcIn)` 이고, `srcIn` 결과의 알파는
/// `이미지알파 × 색알파` 다. 그래서 [borderColor] 에 알파를 그대로 담아 넘기면
/// 옛 `Border.all(color: c.withValues(alpha: 0.45))` 와 픽셀 단위로 똑같이
/// 나온다. 별도 파라미터가 필요 없다.
library;

import 'package:flutter/material.dart';

import '../theme/ui_sprites.dart';
import 'pixel_sprite.dart';

/// 칩 높이 티어. 값이 클수록 스프라이트가 크고 반경/테두리가 굵다.
enum UiPillSize {
  small('assets/ui_dummy/frame_pill_s.png'),
  medium('assets/ui_dummy/frame_pill_m.png'),
  large('assets/ui_dummy/frame_pill_l.png');

  const UiPillSize(this.asset);

  final String asset;

  /// [asset] 의 9-slice 분할.
  Rect get slice => switch (this) {
    UiPillSize.small => kUiPillSmallSlice,
    UiPillSize.medium => kUiPillMediumSlice,
    UiPillSize.large => kUiPillLargeSlice,
  };

  /// 이 티어의 **기준 높이**(px). 대략적인 크기 힌트로만 쓴다.
  double get intrinsicHeight => switch (this) {
    UiPillSize.small => 12,
    UiPillSize.medium => 20,
    UiPillSize.large => 36,
  };
}

/// 칩(pill) / 배지.
///
/// ```dart
/// UiPill(
///   size: UiPillSize.medium,
///   borderColor: color.withValues(alpha: 0.45),   // 옛 Border.all(color:)
///   background: color.withValues(alpha: 0.12),    // 옛 BoxDecoration.color
///   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
///   child: Row(...),
/// )
/// ```
class UiPill extends StatelessWidget {
  const UiPill({
    super.key,
    required this.child,
    required this.size,
    this.borderColor,
    this.background,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  /// 칩 높이 티어. **텍스트 실제 높이에 가장 가까운 걸 고른다.** — 반경이
  /// 티어에 고정이라 너무 작은 티어를 고르면 둥근 캡이 납작해 보인다.
  final UiPillSize size;

  /// 테두리 색. 알파를 담아도 그대로 반영된다.
  final Color? borderColor;

  /// 스프라이트 뒤 채움색.
  final Color? background;

  final EdgeInsetsGeometry padding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PixelSprite(
      asset: size.asset,
      centerSlice: size.slice,
      // 테두리 안쪽 여백. 원래 `Border.all` 은 레이아웃에 영향이 없었으니
      // 여백을 안 주면 내용이 테두리 위로 걸친다.
      insets: padding,
      color: borderColor,
      background: background,
      child: child,
    );
  }
}