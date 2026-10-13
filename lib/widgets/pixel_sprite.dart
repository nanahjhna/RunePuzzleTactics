import 'package:flutter/material.dart';

/// Scales a pixel-art UI sprite without softening its edges.
class PixelSprite extends StatelessWidget {
  const PixelSprite({
    super.key,
    required this.asset,
    required this.centerSlice,
    required this.child,
    this.insets = EdgeInsets.zero,
    this.fit = StackFit.loose,
    this.color,
    this.background,
    this.art,
    this.clipBehavior = Clip.hardEdge,
  });

  final String asset;
  final Rect centerSlice;
  final Widget child;
  final EdgeInsetsGeometry insets;

  /// [Stack] 이 자식에게 주는 제약 강도.
  ///
  /// 기본 [StackFit.loose] 는 기존 호출부(카드/CTA)의 동작을 그대로 유지한다.
  /// 반면 [child] 안에 `Expanded` 가 있으면 **loose 로는 터진다** — Stack 이
  /// 0..maxHeight 같은 느슨한 제약을 주므로 높이가 확정되지 않아 flex 가 계산이
  /// 안 된다. 그럴 땐 [StackFit.expand] 를 넘겨서 타일 전체를 채우게 한다.
  final StackFit fit;

  /// 스프라이트 틴트. null 이면 원본 색 그대로 쓴다.
  ///
  /// [Image.colorBlendMode] 기본값이 [BlendMode.srcIn] 이라 **투명 픽셀은 그대로
  /// 두고 불투명한 픽셀만** 이 색으로 치환하며 스프라이트의 알파는 보존된다.
  /// 색에 알파를 담아서 넘기면(`c.withValues(alpha: 0.45)`) 틴트 결과도 그 알파를
  /// 그대로 따라간다 — 그래서 옛 `Border.all(color: c.withValues(alpha: .45))` 는
  /// `color` 에 그대로 넣으면 된다.
  ///
  /// 다만 `srcIn` 은 *치환*이라 **내부가 채워진 그림을 넣으면 그림 전체가 이 색으로
  /// 죽는다.** 그래서 내부 색까지 스프라이트로 표현하려면 이 값을 쓰지 않고,
  /// 상태 색은 이미지 뒤에 깔린 배경([background])으로만 준다.
  final Color? color;

  /// 스프라이트 **뒤**에 깔리는 배경색. 테두리 전용 스프라이트의 채움색.
  ///
  /// **색은 스프라이트 뒤에 둔다** — 이게 요점이다:
  ///  - 지금처럼 내부가 반투명이면 상태 색(편성중 초록 / 보유 보라)이 비쳐 보인다.
  ///  - 나중에 불투명 실아트로 교체하면 내부가 배경을 자연스럽게 가린다.
  ///    → 교체 시 이 코드를 손뛸 필요가 없다.
  final Color? background;

  /// 배경색 **위**, 스프라이트 **아래**에 깔리는 카드 아트 (더미 배경/헤더).
  ///
  /// [CardArt.fill] / [CardArt.header] 를 넣는다. null 이 아니면
  /// [Positioned.fill] 로 감싸 [child] 크기와 무관하게 프레임 전체를 덮는다.
  ///
  /// 층위: `Container(background)` → **[art]** → 프레임 스프라이트 →
  /// `Padding(insets)` 콘텐츠. 프레임이 아트를 위에서 덮으므로 테두리·글로우가
  /// 아트보다 앞에 그려진다.
  final Widget? art;

  /// [Stack] 의 클립 정책.
  ///
  /// 기본 [Clip.hardEdge] 는 `child` 가 테두리 안쪽 밖으로 넘쳐도 잘라낸다.
  /// `HeroPortrait` 처럼 **속성 배기가 프레임 밖으로 삐져나가는** 요소는
  /// `Clip.none` 이 필요하다(옛 구현의 `Stack(clipBehavior: Clip.none)` 와 같다).
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      child: Stack(
        fit: fit,
        clipBehavior: clipBehavior,
        children: [
          if (art != null) Positioned.fill(child: art!),
          Positioned.fill(
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              centerSlice: centerSlice,
              // 픽셀아트 선명도 유지. 빠지면 9-slice 로 늘린 프레임이 뭉개진다.
              filterQuality: FilterQuality.none,
              color: color,
            ),
          ),
          Padding(padding: insets, child: child),
        ],
      ),
    );
  }
}
