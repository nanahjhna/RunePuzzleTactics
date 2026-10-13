/// Rune Puzzle Tactics — 픽셀 프레임 표면 래퍼.
///
/// 9-slice 테두리 스프라이트와 어두운 콘텐츠 표면을 조합해 XP/HP 바, 요약 카드,
/// 리스트 카드의 테두리와 배경을 일관되게 표시한다.
///
/// **단일 프레임 시스템**: 예전에는 바깥에 `UI_Flat_Frame01a`(96×64 블루그레이
/// 단색 프레임)를 깔고 안쪽에 `UiFrame.round4`(흰 링)를 얹어 두 개의 경쟁
/// 프레임이 공존했다. 이제 `UiFrame.round4` 하나로 통일했다 — 테두리 토큰이
/// 갈라지면 같은 "카드"가 화면마다 다르게 보인다.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_frame.dart';

/// 픽셀 프레임 카드 표면. [blur]가 양수이면 배경에 BackdropFilter를 적용한다.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 8,
    this.padding,
    this.color = AppColors.cardDark2,
    this.blur = 12,
    this.borderColor = AppColors.glassBorder,
    this.art,
  });

  final Widget child;

  /// 바깥 클립 반경. **내부 테두리 반경은 스프라이트가 정한다(4 고정).**
  ///
  /// 예전에는 내부 `BoxDecoration` 이 `radius / 2` 를 써서 테두리 반경이
  /// 인자로 따라갔다. 이제는 반경 4짜리 스프라이트(`UiFrame.round4`)를 쓰므로
  /// [radius] 는 바깥 `ClipRRect` 에만 영향을 준다. 현재 8개 호출부 전부가
  /// 기본값 8(=내부 4)을 그대로 쓰고 있어 화면 변화는 없다.
  final double radius;

  /// 내부 패딩 (null이면 [child]가 자체 패딩을 가짐).
  final EdgeInsetsGeometry? padding;
  final Color color;

  /// BackdropFilter 블러 강도. 0 이하이면 BackdropFilter(saveLayer)를
  /// 통째로 생략한다. 정적 그라데이션 배경 위에서는 blur 효과가 없어 시각
  /// 변화 없이 GPU saveLayer 부담을 줄여 Android 실기기 전환 프레임
  /// 멈춤/검정 화면 리스크를 낮춘다.
  final double blur;
  final Color borderColor;

  /// 배경색 위 / 테두리 아래에 깔리는 카드 아트. [CardArt.fill] 또는
  /// [CardArt.header] 를 넣는다. 바깥 [ClipRRect] 가 아트를 카드 반경에
  /// 맞춰 잘라 주므로 [blur] 유무와 무관하게 모서리가 안전하다.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    // 단일 프레임: 반경 4 흰 링 스프라이트 + 배경색을 `background` 로 전달.
    // 예전의 2겹 구조(바깥 UI_Flat_Frame01a + 안쪽 UiFrame.round4)를 단일
    // 레이어로 합쳤다 — 테두리 토큰이 갈라지면 같은 카드가 화면마다 다르게 보인다.
    final surface = UiFrame.round4(
      fit: StackFit.loose,
      background: color,
      color: borderColor,
      insets: padding ?? EdgeInsets.zero,
      art: art,
      child: child,
    );
    if (blur <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      ),
    );
  }
}
