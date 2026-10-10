/// Rune Puzzle Tactics — 영웅 초상화 위젯 (사양 1-1 / 1-2: 1x4 Portrait Grid)
///
/// 폴백 정책:
/// 1. [fullBody]가 true면 [RuneHeroDef.portraitFullAssetPath]를 먼저 시도하고,
///    없으면 [RuneHeroDef.portraitAssetPath]로 내려온다.
/// 2. 그래도 경로가 null이거나 **에셋 로드가 실패하면** 속성 고유 색상 원형 배경 +
///    속성 이모지로 폴백한다. (이미지 에셋을 새로 만들지 않아도 즉시 동작한다.)
/// 3. [HeroPortrait.locked] 는 **전투 중 HUD**의 빈 자리 전용이다. 편성 가능한
///    빈 자리는 [PartySlots] 의 `+` 카드다 (로비/파티탭/전투 준비 공용).
///
/// 테두리 색은 속성 고유 색([RuneElement.argb])을 사용해 속성이 한눈에 보이게 한다.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../theme/app_theme.dart';
import 'ui_frame.dart';

/// 속성별 테두리/배경 팔레트.
Color heroElementColor(RuneElement e) => Color(e.argb);

/// 등급별 색상 팔레트.
Color heroRarityColor(HeroRarity r) => Color(r.argb);

/// 영웅 초상화 1칸.
///
/// - [hero]: 표시할 영웅 정의. [locked]가 true면 무시된다.
/// - [locked]: 빈 슬롯(🔒) 표시.
/// - [size]: 초상화 너비. [height]가 없으면 정사각형으로 표시한다.
/// - [height]: 초상화 높이.
/// - [dimmed]: 비활성(파티 미편성) 표현. 불투명도 45%로 낮춘다.
/// - [grayscale]: 완전 무채색. "이 영웅은 쓰러졌다" 를 색으로 알린다.
/// - [overlay]: 하단 오버레이(예: 스킬 사용 완료 표시).
/// - [borderColor]: 테두리 색 오버라이드. null이면 속성 고유 색.
/// - [showElementBadge]: 우상단 속성 아이콘 뱃지 노출 여부.
/// - [fullBody]: 전신 초상화 사용 여부. **세로로 긴 슬롯에만** true 를 준다.
class HeroPortrait extends StatelessWidget {
  const HeroPortrait({
    super.key,
    required this.hero,
    this.size = 48,
    this.height,
    this.locked = false,
    this.dimmed = false,
    this.grayscale = false,
    this.overlay,
    this.borderColor,
    this.showElementBadge = false,
    this.fullBody = false,
  });

  /// 잠금 슬롯(편성 가능한 자리) 생성용.
  const HeroPortrait.locked({
    super.key,
    this.size = 48,
    this.height,
    this.overlay,
  }) : hero = null,
       locked = true,
       dimmed = false,
       grayscale = false,
       borderColor = null,
       showElementBadge = false,
       fullBody = false;

  final RuneHeroDef? hero;
  final double size;
  final double? height;
  final bool locked;
  final bool dimmed;

  /// 초상화 이미지를 완전 무채색으로 바꾼다.
  ///
  /// [dimmed](불투명도)와는 목적이 다르다 — dimmed 는 "지금은 조작 불가" 라는
  /// 잠깐의 상태고, grayscale 은 "이 영웅은 이번 전투에서 쓰러졌다" 라는 확정 상태다. 그래서 **둘을 동시에 켜지 않는다.**
  ///
  /// 테두리와 [overlay] 는 그대로 둔다 — "사용 완료" 표식까지 함께 무채가 되면
  /// 상태를 읽을 수단이 사라진다.
  final bool grayscale;
  final Widget? overlay;
  final Color? borderColor;
  final bool showElementBadge;

  /// 전신 초상화([RuneHeroDef.portraitFullAssetPath])를 쓸지 여부.
  ///
  /// true인 슬롯은 세로로 긴 비율이어야 한다. [BoxFit.cover] 는 짧은 축을
  /// 기준으로 잘라내므로, 정사각형 슬롯에 전신을 넣으면 얼굴이 잘린다.
  /// 전신이 없으면 자동으로 [portraitAssetPath] 로 폴백한다.
  final bool fullBody;

  /// 전신 이미지 속성별 상단 투명 밴드 비율 (얼굴 정렬 계산용).
  ///
  /// 에셋을 측정해 얻은 값이다 — 이미지는 409×610 이고 아래 여백은 0.2% 뿐이라
  /// **위쪽만** 밴드가 있다. 밴드가 없으면 정렬을 계산할 게 없다.
  static const Map<RuneElement, double> _topPads = {
    RuneElement.fire: 0.043,
    RuneElement.water: 0.090,
    RuneElement.grass: 0.115,
    RuneElement.light: 0.092,
    RuneElement.poison: 0.080,
  };

  /// **얼굴이 보이도록** 계산한 `BoxFit.cover` 정렬.
  ///
  /// 슬롯은 세로로 길다(종횡비 0.8 전후)해서 `cover` 가 위아래를 20% 넘게 잘라
  /// 낸다. `Alignment.bottomCenter` 를 고르면 상단 21.5%가 통째로 사라지는데
  /// 머리는 이미지 높이의 4~20% 에만 있다 — **다섯 속성 전부 머리가 없는 그림**이
  /// 된다. 그래서 밴드만 걷어내는 고정 정렬 대신, 잘리는 비율(`overflow`)을 먼저
  /// 구하고 그만큼을 밴드 비율로 나눠 "밴드는 보존하고 머리 위를 조금 더 자른"
  /// 위치를 정한다.
  ///
  /// ```
  /// overflow  = 1 - (전신 종횡비 / 슬롯 종횡비)   // 잘리는 세로 비율
  /// topFrac   = 상단 밴드 / overflow               // 밴드가 차지할 잘린 영역
  /// alignment = Alignment(0, 1 - 2 × topFrac)
  /// ```
  ///
  /// 밴드가 잘리는 영역보다 크면 `clamp` 이 0 에 붙어 자연히 `bottomCenter` 와
  /// 같아진다(슬롯이 아주 작아 밴드를 감당 못 하는 경우의 안전장치).
  static Alignment alignmentForFullBody({
    required RuneElement element,
    required double width,
    required double height,
  }) {
    const fullBodyAspect = 409 / 610;
    final slotAspect = width <= 0 || height <= 0 ? fullBodyAspect : width / height;
    final overflow = 1.0 - fullBodyAspect / slotAspect;
    if (overflow <= 0) return Alignment.bottomCenter;
    final pad = _topPads[element] ?? 0.08;
    final topFraction = (pad / overflow).clamp(0.0, 1.0);
    return Alignment(0.0, 1.0 - 2.0 * topFraction);
  }

  /// 완전 무채색 필터 (Rec.709 luminance — R·G·B 가 모두 같은 가중치로 합쳐진다).
  ///
  /// [BlendMode.saturation] 과 달리 색상뿐 아니라 채도가 낮은 픽셀(회색 배경)도
  /// 밝기를 유지한 채 그대로 남으므로, 원본 대비가 무너지지 않는다.
  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final portraitHeight = height ?? size;
    final element = hero?.element;
    final base = element != null ? heroElementColor(element) : Colors.white30;

    // 전신을 우선 요청하되, 없으면 얼굴 크롭으로 폴백한다.
    final path =
        (fullBody ? hero?.portraitFullAssetPath : null) ??
        hero?.portraitAssetPath;
    Widget content;
    if (locked) {
      content = _CenteredGlyph(
        glyph: '🔒',
        fontSize: size * 0.42,
        background: Colors.white.withValues(alpha: 0.06),
      );
    } else if (path != null && path.isNotEmpty) {
      // 1) 전용 초상화 에셋 시도 (로딩 실패 시 2번 폴백)
      //
      // [alignment] 이 핵심이다. 세로 슬롯은 종횡비가 이미지보다 넓어서
      // `cover` 가 위아래를 20% 넘게 자른다. 정렬을 하나로 못 정하면
      // "투명 밴드가 화면에 남는가"와 "머리가 잘리는가" 중 하나를 반드시 잃는다.
      // [HeroPortrait.alignmentForFullBody] 이 두 조건을 같이 만족시키는 위치를
      // 계산한다.
      //
      // 정사각형 슬롯(도감/파티 그리드/카드)은 이미지가 딱 맞게 들어가 잘림이
      // 없어 alignment 이 무의미하다. 그래서 [fullBody] 세로 슬롯에만 건다.
      content = FittedBox(
        fit: BoxFit.cover,
        alignment:
            (fullBody && element != null)
            ? alignmentForFullBody(
                element: element,
                width: size,
                height: portraitHeight,
              )
            : Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: Image.asset(
          path,
          errorBuilder: (_, _, _) => _emojiFallback(element!, size),
        ),
      );
    } else {
      // 2) 속성 이모지 폴백
      content = _emojiFallback(element!, size);
    }

    // 이미지(와 이모지 폴백)에만 필터를 건다. 테두리·overlay 는 그대로 둬야
    // "사용 완료" 표식이 무채색에 묻혀 안 읽힌다. false 면 위젯을 추가하지
    // 않아 다른 화면의 렌더 트리가 바뀌지 않는다.
    if (grayscale) {
      content = ColorFiltered(colorFilter: _grayscaleFilter, child: content);
    }

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      // 테두리는 스프라이트, 채움은 색. `dimmed` 는 테두리 굵기로도 신호가
      // 됐는데(2px → 1px) 이제 스프라이트 2벌로 같은 정보를 준다.
      child: dimmed
          ? UiFrame.square1(
              width: size,
              height: portraitHeight,
              color: borderColor ?? base,
              background: AppColors.cardDark,
              // 속성 배기가 프레임 밖으로 삐져나가므로 클립하면 안 된다.
              clipBehavior: Clip.none,
              child: _frameContent(
                content: content,
                overlay: overlay,
                size: size,
                showElementBadge: showElementBadge,
                element: element,
                base: base,
              ),
            )
          : UiFrame.square2(
              width: size,
              height: portraitHeight,
              color: borderColor ?? base,
              background: AppColors.cardDark,
              clipBehavior: Clip.none,
              child: _frameContent(
                content: content,
                overlay: overlay,
                size: size,
                showElementBadge: showElementBadge,
                element: element,
                base: base,
              ),
            ),
    );
  }

  /// 프레임 안쪽 내용. [UiFrame] 이 테두리 여백을 안으로 밀어 넣으므로
  /// 여기선 그것을 더하지 않는다.
  Widget _frameContent({
    required Widget content,
    required Widget? overlay,
    required double size,
    required bool showElementBadge,
    required RuneElement? element,
    required Color base,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                if (overlay != null)
                  Positioned(left: 0, right: 0, bottom: 0, child: overlay),
              ],
            ),
          ),
        ),
        if (showElementBadge && element != null)
          Positioned(
            right: -size * 0.08,
            top: size * 0.04,
            child: UiFrame.square1(
              color: base,
              background: AppColors.cardDark,
              // 이 배지는 콘텐츠 크기 그대로라 `expand` 로 강제하면
              // 느슨한 제약을 받은 `Positioned` 자식이 프레임 전체를 덮는다.
              fit: StackFit.loose,
              // 옛 `padding: all(1)` 이 프레임 안쪽 여백이 됐다.
              child: Text(
                element.emoji,
                style: TextStyle(fontSize: size * 0.24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emojiFallback(RuneElement element, double size) {
    final c = heroElementColor(element);
    return _CenteredGlyph(
      glyph: element.emoji,
      fontSize: size * 0.52,
      background: c.withValues(alpha: 0.22),
    );
  }
}

/// 이모지 + 단색 배경 가운데 정렬 헬퍼.
class _CenteredGlyph extends StatelessWidget {
  const _CenteredGlyph({
    required this.glyph,
    required this.fontSize,
    required this.background,
  });

  final String glyph;
  final double fontSize;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: Text(glyph, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }
}

/// 파티 1x4 슬롯 스트립은 [PartySlots] 로 옮겨갔다 (`lib/widgets/party_slots.dart`).
///
/// 이전에는 여기 🔒 잠금 슬롯을 그렸지만, 잠긴 자리는 "파티가 못 채우는 자리"가
/// 아니라 "지금 편성할 수 있는 자리"이므로 `+` 버튼이 되어야 한다. 로비 ·
/// 파티 탭 · 전투 준비가 같은 위젯을 공유한다.
