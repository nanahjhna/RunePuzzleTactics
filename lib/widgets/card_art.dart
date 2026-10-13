/// Rune Puzzle Tactics — 카드 아트(더미 배경/헤더) 레이어.
///
/// `tool/gen_card_art.py` 가 만든 더미 이미지를 **카드형 섹션**에 매치한다.
/// 이미지는 카드 배경색 위 / 콘텐츠 아래에 들어간다:
///
/// ```
/// 카드 배경색 → [CardArt] → 9-slice 프레임 → 콘텐츠
/// ```
///
/// ## 두 자리
///
///  1. **프레임 안쪽** — [UiFrame] / [GlassSurface] / [GlassBottomSheet] 의
///     `art:` 인자로 넘긴다. 프레임 스프라이트가 아트를 위에서 덮으므로
///     테두리·글로우가 아트보다 앞에 그려진다.
///  2. **프레임이 없는 자리** — 다이얼로그 본체는 [CardArtBackdrop] 로 감싼다.
///     스택 특성상 아트는 자식(내용 또는 `AlertDialog`) **뒤**에 놓인다.
///     [showHeroDetailDialog] 는 Material 색 위, [showHeroGachaDialog] 는
///     반투명 Material 아래에서 각각 보인다.
///
/// ## 매치표
///
/// | 자리 | 상수 | 형태 |
/// |---|---|---|
/// | 로비 스테이지 카드 / 파티 요약 | [kCardArtLobbyStage] / [kCardArtLobbyParty] | fill |
/// | 결과 보상 / 파티 요약 / 데미지 / 스탯 | [kCardArtResultReward] … [kCardArtResultStats] | fill |
/// | 설정 그룹 / 상점 뽑기 패널 / 하단 탭 바 | [kCardArtSettings] / [kCardArtShopGacha] / [kCardArtMainNav] | fill |
/// | 영웅 상세 / 가차 결과 다이얼로그 | [kCardArtHeroDetail] / [kCardArtGachaDialog] | backdrop |
/// | 파티·도감 프레임 / 튜토리얼 / 출격 준비 / 선택 시트 | [kCardArtHeaderParty] … [kCardArtHeaderSheet] | header |
///
/// ## 실아트 교체
///
/// `assets/ui_dummy/cardart_*.png` 를 같은 **비율**의 실아트로 덮어쓴다.
/// 9-slice 가 아니므로 슬라이스 재측정이 필요 없다. 알파·라운드 마스크가
/// 이미지에 굽혀 있으므로, 알파가 없는 실아트를 넣을 경우 모서리만 따로
/// 페이드 처리해야 카드 모서리가 각져 보이지 않는다.
library;

import 'package:flutter/material.dart';

/// 카드 섹션에 깔리는 아트 레이어. [PixelSprite.art] 자리(Stack 자식)로 들어간다.
///
/// [PixelSprite] 는 이 위젯을 [Positioned.fill] 로 감싸므로 **자식 크기와
/// 무관하게 프레임 전체**를 덮는다. [CardArt.header] 는 그 안에서 상단 정렬 +
/// 고정 높이로만 그려 상단 밴드를 만든다.
class CardArt extends StatelessWidget {
  /// 전체를 덮는 배경 아트.
  const CardArt.fill(this.asset, {super.key, this.opacity = 1}) : height = null;

  /// 상단 헤더 밴드 아트. 이미지 아래쪽 알파가 0 으로 굽혀 있어 경계가 없다.
  const CardArt.header(
    this.asset, {
    this.height = 96,
    this.opacity = 1,
    super.key,
  });

  /// `assets/ui_dummy/cardart_*` 경로 ([ui_sprites.dart] 의 `kCardArt*`).
  final String asset;

  /// 헤더 밴드 높이. [CardArt.fill] 에서는 무시된다.
  final double? height;

  /// 아트 불투명도. 카드별로 텍스트 가독성을 맞추기 위해 조정할 때 쓴다.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: BoxFit.cover,
      // 9-slice 스프라이트가 아니라 픽셀아트 선명도 규칙(FilterQuality.none)의
      // 적용 대상이 아니다. 카드 배경이므로 부드럽게 늘린다.
      filterQuality: FilterQuality.low,
    );
    final body = opacity >= 1 ? image : Opacity(opacity: opacity, child: image);

    final band = height;
    if (band == null) return body;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: band,
        child: body,
      ),
    );
  }
}

/// 프레임이 없는 자리(다이얼로그 본체)에 카드 아트를 까는 스택.
///
/// **아트는 [child] 뒤에** 놓인다 — 내용(또는 `AlertDialog`)이 아트 위에
/// 그려지는 층위를 [GlassSurface] 와 동일하게 만든다. [child] 는 크기를
/// 결정하는 유일한 자식이고, 아트는 [Positioned.fill] 로 그 크기를 덮는다.
///
/// [Clip.none] 인 이유: `AlertDialog` 같은 자식은 자기 경계 밖으로 **그림자**
/// 를 그린다. 스택이 클립하면 다이얼로그 그림자가 잘린다. 아트가 카드
/// 모서리에서 삐져나가지 않는 것은 이미지에 굽힌 라운드 마스크 덕이다.
class CardArtBackdrop extends StatelessWidget {
  /// 전체를 덮는 배경 아트를 [child] 뒤에 깐다.
  const CardArtBackdrop({
    super.key,
    required this.asset,
    required this.child,
    this.opacity = 1,
  });

  /// `assets/ui_dummy/cardart_*` 경로.
  final String asset;

  /// 아트 위에 그려질 자식. 크기를 결정한다.
  final Widget child;

  /// 아트 불투명도.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.loose,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CardArt.fill(asset, opacity: opacity),
        ),
        child,
      ],
    );
  }
}
