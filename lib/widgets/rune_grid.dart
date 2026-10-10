/// Rune Puzzle Tactics — 공용 그리드 규격/타일 (요구사항 2 / 5 / 6 / 7)
///
/// 네 개 화면이 **같은 규격**을 공유한다:
///  - 2번: 로비 `+` → 영웅 선택 시트
///  - 5번: 파티 탭 `+` → (동일한 [PartySlots] 경로라 같은 시트가 열린다)
///  - 6번: 파티 탭 영웅도감
///  - 7번: 상점 탭 아이템 목록
///
/// 규격은 **6열 × 3행 = 18칸**이다. 18칸을 넘으면 행 수가 늘어나고 아래로
/// 스크롤된다(페이지 넘김은 택하지 않았다 — 스크롤이 더 예측 가능하다).
///
/// 타일은 이름 길이(CJK)와 폰트가 제각각이라 고정 텍스트 줄 수를 쓰지 않고
/// [FittedBox] + [TextOverflow.ellipsis] 로 방어한다.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import '../theme/ui_sprites.dart';
import 'hero_portrait.dart';
import 'pixel_sprite.dart';
import 'ui_pill.dart';

/// 그리드 열 수 — 요구사항 스케치(`ㅁㅂㅁㅁㅁㅁ` × 3행) 고정.
const int kRuneGridColumns = 6;

/// 그리드 행 수 — 화면에 우선 노출되는 행 수(초과분은 아래로 스크롤).
const int kRuneGridRows = 3;

/// 화면당 우선 노출 칸 수 (6 × 3).
const int kRuneGridVisibleCells = kRuneGridColumns * kRuneGridRows; // 18

/// 기본 타일 비율. 6열이라 폭이 좁으므로 세로로 약간 긴 직사각형.
const double kRuneGridTileAspect = 0.68;

/// [crossAxisCount]열 고정 그리드 delegate.
///
/// [childAspectRatio] 을 호출부마다 조정할 수 있게 감친다 — 시트(좁은 폭)와
/// 도감(넓은 폭)은 같은 비율을 써도 타일이 각각 54px / 57px 정도로 비슷하다.
///
/// [crossAxisCount] 를 생략하면 전역 규격([kRuneGridColumns])을 쓴다.
/// 영웅도감만 **5열**을 넘긴다 — 도감이 노출하는 영웅이 속성당 1명, 즉
/// [HeroPool.oneStarHeroes] 5명이라 6열이면 마지막 한 칸이 영영 비기 때문이다.
SliverGridDelegateWithFixedCrossAxisCount runeGridDelegate({
  int crossAxisCount = kRuneGridColumns,
  double crossAxisSpacing = 6,
  double mainAxisSpacing = 6,
  double childAspectRatio = kRuneGridTileAspect,
}) => SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: crossAxisCount,
  crossAxisSpacing: crossAxisSpacing,
  mainAxisSpacing: mainAxisSpacing,
  childAspectRatio: childAspectRatio,
);

/// 타일 라벨/배지 공통 폰트 크기.
///
/// 그리드 타일이 6열로 좁아서 이름(7px)과 상태 배지(6px) 두 크기밖에 없다.
/// 상수화해 둬서 값이 바뀌면 한 곳만 고치면 된다.
const double _kTileLabelFont = 7;
const double _kTileBadgeFont = 6;

/// 타일 이름 라벨 (CJK 안전 — 폭이 부족하면 축소).
///
/// 6열 그리드에서는 태블릿/접힌 화면에서도 폭이 40px 아래로 떨어질 수 있다.
/// [FittedBox] 가 알아서 줄이므로 폰트는 고정 크기([_kTileLabelFont])로 둔다
/// — 타일 한 칸에 두 줄(영웅 이름 + 등급)만 들어가면 크기를 바꿀 이유가 없다.
class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTileLabelFont + 3,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color ?? Colors.white70,
            fontSize: _kTileLabelFont,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

/// 그리드 타일 외곽 프레임 — 9-slice 스프라이트로 그린다.
///
/// 예전에는 `BoxDecoration` + `Border.all` 로 라운드 사각형을 그렸는데,
/// 게임의 나머지 크롬(카드/버튼)이 픽셀아트 9-slice 라 톤이 튀었다.
///
/// **층 순서가 중요하다** ([PixelSprite] 의 `Stack` 기준):
/// ```
///   배경색(상태)  ->  스프라이트(이미지)  ->  insets 안쪽 child(내용)
/// ```
/// 배경색을 스프라이트 **뒤**에 두는 게 요점이다 — 지금은
/// [PixelSprite.background] 이 그 자리를 맡는다:
///  - 현재 더미처럼 내부가 반투명이면 상태 색(편성중 초록 / 보유 보라)이 비쳐 보인다.
///  - 나중에 불투명 실아트로 교체하면 내부가 배경을 자연스럽게 가린다.
///    → 교체 시 이 코드를 손뛸 필요가 없다.
///
/// **색칠(`PixelSprite.color`)을 쓰지 않는 이유**: `srcIn` 블렌드는 불투명한
/// 모든 픽셀을 그 색으로 *치환*한다. 내부가 채워진 그림이라면 그림 전체가 상태색
/// 평면으로 죽는다. 그래서 상태 구분은 스프라이트 2벌 + 배지로 옮겼고
/// ([HeroGridTile] 의 "편성중"/`🔒`/등급 별, [ShopItemTile] 의 `MAX`).
///
/// 교체는 `lib/theme/ui_sprites.dart` 의 경로 상수만 바꾸면 된다.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.child,
    this.selected = false,
    this.background,
  });

  final Widget child;

  /// 선택/편성중 — 2px 스프라이트로 바꾼다(테두리 두께로 상태를 나누던 것).
  final bool selected;

  /// 스프라이트 뒤로 보내는 배경색(상태 표시용). null 이면 [AppColors.glassCard].
  final Color? background;

  @override
  Widget build(BuildContext context) {
    // 2px 스프라이트는 안쪽 여백도 2px 이어야 테두리 위에 내용이 올라가지 않는다.
    return PixelSprite(
      asset: selected ? kUiTileFrameSel : kUiTileFrame,
      centerSlice: kUiTileSlice,
      insets: EdgeInsets.all(selected ? 2 : 1),
      // child 안에 Expanded 가 있어(초상화) 높이가 확정돼야 한다.
      fit: StackFit.expand,
      background: background ?? AppColors.glassCard,
      child: child,
    );
  }
}

/// 타일 우상단 상태 배지 (편성 중 / 미보유 / 등급 별).
class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return UiPill(
      size: UiPillSize.small,
      borderColor: color.withValues(alpha: 0.75),
      background: Colors.black.withValues(alpha: 0.62),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: _kTileBadgeFont,
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
      ),
    );
  }
}

/// 6×3 그리드 1칸 — **영웅 타일**.
///
/// 편성 선택 시트(2/5번)와 영웅도감(6번)이 공유한다. 두 화면의 차이는
/// 미보유 영웅의 탭 동작뿐이라 [owned] / [inParty] 플래그로 갈라 처리한다.
class HeroGridTile extends StatelessWidget {
  const HeroGridTile({
    super.key,
    required this.hero,
    required this.owned,
    required this.inParty,
    this.onTap,
    this.tapKey,
  });

  final RuneHeroDef hero;

  /// 보유 여부. 미보유면 초상화가 흐려지고 🔒 배지가 뜬다(도감 스포일러 규칙).
  final bool owned;

  /// 현재 파티 편성 여부. 편성 중이면 초록 테두리 + "편성중" 배지.
  final bool inParty;

  /// 탭 동작. null 이면 비활성(탭해도 아무 일도 없다).
  final VoidCallback? onTap;

  /// 테스트/디버깅용 키.
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final name = l10n.tr('hero_name_${hero.heroId}');

    // 테두리 색으로 상태를 알던 시대를 정리했다 — 9-slice 스프라이트는 srcIn
    // 색칠을 쓰면 그림을 죽이므로, 상태는 2벌 스프라이트 + 아래 배지로 알린다.
    final body = _TileFrame(
      selected: inParty,
      background: inParty
          ? const Color(0xFF26352F)
          : owned
          ? AppColors.cardDark
          : AppColors.glassCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 3, 2, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 9,
              // 편성 중 / 🔒 만 남긴다. 등급 별(★) 표시는 전 화면에서 삭제했다.
              child: inParty
                  ? _TileBadge(
                      text: l10n.tr('party_picker_assigned'),
                      color: AppColors.green,
                    )
                  : owned
                  ? const SizedBox.shrink()
                  : const Text(
                      '🔒',
                      style: TextStyle(fontSize: 7, height: 1.1),
                    ),
            ),
            Expanded(
              child: Opacity(
                opacity: owned ? 1.0 : 0.32,
                child: Center(
                  // [HeroPortrait] 는 size 로 배지/이모지 fontSize 를 계산하므로
                  // `double.infinity` 를 넣으면 안 된다. LayoutBuilder 로 타일 폭에
                  // 맞춰 크기를 산출한다.
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final side = box.maxWidth.isFinite
                          ? box.maxWidth.clamp(18.0, 48.0)
                          : 30.0;
                      return HeroPortrait(hero: hero, size: side);
                    },
                  ),
                ),
              ),
            ),
            _TileLabel(name, color: owned ? Colors.white70 : Colors.white30),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return body;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tapKey,
        onTap: onTap,
        // 프레임이 각진 9-slice 라 물방울도 각지게 맞춘다(둥근 하이라이트가
        // 직각 프레임 위에 걸치면 결이 어긋난다).
        borderRadius: BorderRadius.zero,
        child: body,
      ),
    );
  }
}
