/// Rune Puzzle Tactics — 테두리 9-slice 스프라이트 표면.
///
/// 예전에는 `Container(decoration: BoxDecoration(border: Border.all(...)))` 로
/// 그리고 있던 UI 크롬의 **테두리만** PNG 스프라이트로 바꾼다. 채움색·그림자·
/// 블러는 그대로 Flutter `Color` 다.
///
/// **무엇을 이 위젯으로 옮기고 무엇을 남기는가**
///
/// 옮김(스프라이트):
/// ```
///   Container(decoration: BoxDecoration(
///     color: fill,                                  → background
///     border: Border.all(color: c, width: w),       → asset + color
///     borderRadius: BorderRadius.circular(r),        → asset (반경이 들어 있다)
///   ))
/// ```
/// 남김(그대로 `Color`):
///  - [shadows] (`BoxShadow`) — 9-slice 로 늘리면 상하좌우로 늘어진 그림자가
///    테두리 굵이만큼 부풀어 오간다. 스프라이트로 표현할 수 없다.
///  - 그라데이션, `BackdropFilter` — 애초에 색이 아니라 효과.
///
/// **왜 색을 스프라이트 뒤에 두는가**
///
/// 스프라이트는 `ColorFilter(srcIn)` 틴트로 인스턴스한다. `srcIn` 은 치환이라
/// 내부가 채워진 그림을 넣으면 그림 전체가 한 색으로 죽는다. 그래서
/// 테두리 전용 스프라이트(흰색 선 + 투명 내부) + 뒤쪽 배경색으로 나누고,
/// 틴트에는 테두리 색만 준다.
///
/// **테두리 굵기가 1px 로 남는 이유**
///
/// 9-slice 는 코너/엣지 타일을 항상 1:1 로 그린다. 그래서 스프라이트를
/// 요소보다 **작게** 잡으면 화면이 아무리 커도(초상화 130px 등) 테두리 굵기가
/// 안 변한다. `kUiFrameSquare1` 을 16x16 으로 잡은 이유다.
library;

import 'package:flutter/material.dart';

import '../theme/ui_sprites.dart';
import 'pixel_sprite.dart';

/// 테두리 스프라이트 표면.
///
/// 일반 생성자는 `asset` + `slice` 짝을 직접 넘긴다. 짝이 틀리면 화면이 깨지므로
/// 평소에는 규격별 이름 생성자([UiFrame.square1] 등)를 쓰는 게 낫다 — 슬라이스가
/// 경로와 자동으로 따라간다.
///
/// ```dart
/// // 일반
/// UiFrame(
///   asset: kUiFrameSquare2, slice: kUiFrameSquareSlice,
///   color: borderColor, background: AppColors.cardDark,
///   insets: EdgeInsets.all(2), width: 48, height: 60,
///   child: ...,
/// )
/// ```
class UiFrame extends StatelessWidget {
  const UiFrame({
    super.key,
    required this.asset,
    required this.slice,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = EdgeInsets.zero,
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  });

  const UiFrame.square1({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameSquare1,
       slice = kUiFrameSquare1Slice;

  /// 각진 테두리 2px. 선택/편성중/강조 상태.
  const UiFrame.square2({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(2),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameSquare2,
       slice = kUiFrameSquare2Slice;

  /// 각진 테두리 3px. 가차 공개 카드의 공개 상태.
  const UiFrame.square3({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(3),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameSquare3,
       slice = kUiFrameSquare3Slice;

  /// 라운드 테두리 — 반경 6, 2px. `PartySlots` 빈 `+` 슬롯.
  const UiFrame.round6({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(2),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameRound6,
       slice = kUiFrameRound6Slice;

  /// 라운드 테두리 — 반경 4, 1px. `GlassSurface` 내부 프레임(호출부 8장).
  const UiFrame.round4({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameRound4,
       slice = kUiFrameRound4Slice;

  /// 라운드 테두리 — 반경 12, 1px. 입 재화 칩 / 상점 뽑기 버튼.
  const UiFrame.round12({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameRound12,
       slice = kUiFrameRound12Slice;

  /// 라운드 테두리 — 반경 14, 1px. 튜토리얼 안내 카드.
  const UiFrame.round14({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameRound14,
       slice = kUiFrameRound14Slice;

  /// 라운드 테두리 — 반경 24, 1px. 출격준비 다이얼로그 / 하단 네비바 /
  /// AdMob 배널 패널 (`appDialogRadius` 계열).
  const UiFrame.round24({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameRound24,
       slice = kUiFrameRound24Slice;

  /// 각진 테두리 — 4px. 카드 아트워크 폴백의 외측 링.
  const UiFrame.square4({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(4),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiFrameSquare4,
       slice = kUiFrameSquare4Slice;

  /// **위쪽에만** 테두리가 있는 캡 — 반경 24, 1px. 바텀시트.
  ///
  /// 반경은 시트 라운드(`appSheetTopRadius`)와 같다. 아래는 열려 있다 — 옛
  /// `Border(top:)` 대체. 좌우 세로선은 **새로 생긴 것**이다(옛 테두리는 위쪽
  /// 한 줄뿐이었다).
  ///
  /// [fit] 은 보통 `StackFit.loose` 가 맞다. 시트 높이는 콘텐츠로 결정되는데,
  /// `expand` 면 높이가 무한대 제약을 받아 `Column` 이 터진다.
  const UiFrame.sheetCap({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color,
    this.background,
    this.art,
    this.insets = const EdgeInsets.only(top: 1),
    this.width,
    this.height,
    this.shadows,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiSheetCapTop,
       slice = kUiSheetCapSlice;

  /// 원형 테두리 — 38x38 고정 크기, 1px.
  ///
  /// **9-slice 가 아니다.** 원은 크기가 고정이라 자를 이유가 없고, 크기까지
  /// 지정해야 테두리가 1px 로 유지된다(가변 크기로 두면 잘린다).
  const UiFrame.circle38({
    super.key,
    this.child = const SizedBox.shrink(),
    this.color = const Color(0xFFFFFFFF),
    this.background,
    this.art,
    this.insets = const EdgeInsets.all(1),
    this.width = 38,
    this.height = 38,
    this.shadows,
    this.fit = StackFit.expand,
    this.clipBehavior = Clip.hardEdge,
  }) : asset = kUiCircleRing38,
       slice = kUiCircleRingSlice;

  /// 테두리 스프라이트 경로. `ui_sprites.dart` 의 `kUiFrame*` 상수를 쓴다.
  final String asset;

  /// [asset] 의 9-slice 분할. 경로마다 규격이 다르므로 **반드시 함께 넘긴다**.
  final Rect slice;

  /// 테두리 색. 알파를 담아도 그대로 반영된다(옛 `Border.all(color:)` 와 동일).
  final Color? color;

  /// 스프라이트 뒤 채움색. 옛 `BoxDecoration.color` 를 그대로 옮긴다.
  final Color? background;

  /// 배경색 **위**, 프레임 **아래**에 깔리는 카드 아트 ([PixelSprite.art]).
  ///
  /// [CardArt.fill] / [CardArt.header] 를 넣는다. `GlassSurface` 도 이 값을
  /// 그대로 전달한다. 배경색 위/테두리 아래 층위 때문에 카드 뒤로 보이고
  /// 텍스트 가독성은 [CardArt] 의 굽힌 알파가 지킨다.
  final Widget? art;

  /// 테두리 안쪽 여백. contents 가 테두리 위에 올라가지 않게 한다.
  ///
  /// **테두리 두께와 같게 주는 게 기본이다** (1px 프레임 → 1, 2px → 2). 원래
  /// `Border.all` 은 레이아웃에 영향을 주지 않으므로 여백을 안 주면 내용이
  /// 테두리 위로 1~2px 걸친다.
  final EdgeInsetsGeometry insets;

  final double? width;
  final double? height;

  /// [BoxShadow]. 스프라이트로 옮길 수 없어 그대로 `Color` 다(위 문서 참조).
  final List<BoxShadow>? shadows;

  /// `Stack` 이 [child] 에 주는 제약. 기본 [StackFit.expand] 는 안쪽을 꽉 채운다.
  ///
  /// **[StackFit.loose] 로 내려야 할 때**: [child] 가 콘텐츠 크기로 자기 크기를
  /// 정해야 할 때. `StackFit.expand` 를 주면 `Positioned(right:.., top:..)` 안의
  /// 자식이 **느슨한 제약을 받았는데도 최대 크기로 강제 확장**되어 프레임 전체를
  /// 덮는다(초상화 속성 배지가 프레임을 통째로 덮는 사고).
  final StackFit fit;

  /// `Stack` 클립 정책. [child] 가 프레임 밖으로 넘쳐도 자를지.
  ///
  /// `HeroPortrait` 는 속성 배기가 `right: -size*0.08` 로 **프레임 밖으로**
  /// 삐져나가므로 `Clip.none` 이 필요하다.
  final Clip clipBehavior;

  /// 테두리 안쪽에 놓일 [child].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = PixelSprite(
      asset: asset,
      centerSlice: slice,
      insets: insets,
      fit: fit,
      clipBehavior: clipBehavior,
      color: color,
      background: background,
      art: art,
      child: child,
    );
    if (width == null && height == null && shadows == null) return frame;
    return Container(
      width: width,
      height: height,
      decoration: shadows == null ? null : BoxDecoration(boxShadow: shadows),
      child: frame,
    );
  }

  /// [child] 만 갈아 끼운 복사본.
  ///
  /// 상태에 따라 프레임(1px/2px, 색)만 달라지고 안쪽 내용은 같은 상황에서 쓴다:
  /// ```dart
  /// final frame = inParty ? UiFrame.square2(...) : UiFrame.square1(...);
  /// return frame.withChild(const BodyWidget(...));
  /// ```
  /// 이게 없으면 본문이 크거나 분기가 많을 때 `child` 를 통째로 복제해야 한다.
  UiFrame withChild(Widget child) => UiFrame(
    asset: asset,
    slice: slice,
    color: color,
    background: background,
    art: art,
    insets: insets,
    width: width,
    height: height,
    shadows: shadows,
    fit: fit,
    clipBehavior: clipBehavior,
    child: child,
  );
}
