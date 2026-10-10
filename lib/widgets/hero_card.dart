/// Element-themed hero card used by the roster, codex, details, and gacha.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../l10n/language_controller.dart';
import 'hero_portrait.dart';
import 'ui_frame.dart';

/// Card artwork is deliberately explicit so unrelated card assets stay unbundled.
const Map<RuneElement, String> heroCardAssets = {
  RuneElement.fire: 'assets/images/card/card_red.jpg',
  RuneElement.water: 'assets/images/card/card_blue.jpg',
  RuneElement.grass: 'assets/images/card/card_green.jpg',
  RuneElement.light: 'assets/images/card/card_yellow.jpg',
  RuneElement.poison: 'assets/images/card/card_puple.jpg',
};

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.hero,
    required this.name,
    this.dimmed = false,
    this.hidden = false,
  });

  final RuneHeroDef hero;
  final String name;
  final bool dimmed;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final element = hero.element;
    final spec = HeroSkills.specFor(hero.heroId);
    final skillName = spec == null
        ? null
        : l10n.tr(spec.l10nKeyFor(hero.heroId));
    final skillDescription = spec == null
        ? l10n.tr('hero_skill_none')
        : l10n.tr(spec.descriptionKeyFor(hero.heroId));

    return AspectRatio(
      // 실제 카드 이미지 규격(848×1264). 이전 값(1230)은 이미지보다 짧아
      // 아래쪽 판테인이 위쪽으로 당겨져 있었다.
      aspectRatio: 848 / 1264,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final portraitSize = width * 0.44;
          final fontScale = width.clamp(120.0, 240.0) / 180;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                heroCardAssets[element]!,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    '영웅 카드 이미지 로드 실패 '
                    '(${heroCardAssets[element]}): $error',
                  );
                  return _CardArtworkFallback(element: element);
                },
              ),
              // ── 이름: 카드 이미지의 이름 판(plate) 정중앙 ──
              //
              // `card_*.jpg` 848×1264 를 **세로로 스캔해서 실측한** 구간:
              //
              // ```
              // 55.9~56.7%  밝은 구분선        (lum 5 → 98 → 61, 프레임 라인)
              // 57.5~60.8%  균일한 어두운 판   (lum ≈ 30~32)  ← 이름 슬롯
              // 61.0~61.3%  very dark 테두리   (lum 0.2)
              // 61.4~61.6%  밝은 아래 테두리   (lum 68)
              // ```
              //
              // 즉 이름 판은 **56.5% ~ 61.3%**, 정중앙은 **0.590h** 다.
              // 이전 값(중심 0.569h)은 판의 **위쪽 테두리선에 걸쳐** 있어
              // "이름칸에 안 들어간" 인상이 남았다. 판 안에 딱 맞게 내린다.
              //
              // 등급/상태 배지는 삭제했다 — 판이 좁아서 이름과 겹쳤고,
              // 별(★) 표시는 전 화면에서 지워졌다.
              Positioned(
                left: width * 0.14,
                right: width * 0.14,
                top: height * 0.567,
                height: height * 0.046,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hidden ? '???' : name,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20 * fontScale,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 0.4,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (width - portraitSize) / 2,
                // 초상화 창(12.4~55%) 안에서 살짝 위로 올려 중앙 이름을 위한
                // 공간을 확보한다.
                top: height * 0.325 - portraitSize / 2,
                width: portraitSize,
                height: portraitSize,
                child: hidden
                    ? Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: portraitSize * 0.7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : Opacity(
                        opacity: dimmed ? 0.4 : 1,
                        child: HeroPortrait(
                          hero: hero,
                          size: portraitSize,
                          borderColor: heroElementColor(element),
                        ),
                      ),
              ),
              if (!hidden)
                Positioned(
                  left: width * 0.19,
                  right: width * 0.19,
                  top: height * 0.646,
                  height: height * 0.239,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.025),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (skillName != null)
                          Text(
                            skillName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: heroElementColor(element),
                              fontSize: 8 * fontScale,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 2),
                              ],
                            ),
                          ),
                        SizedBox(height: height * 0.008),
                        Expanded(
                          child: Text(
                            skillDescription,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9 * fontScale,
                              height: 1.15,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardArtworkFallback extends StatelessWidget {
  const _CardArtworkFallback({required this.element});

  final RuneElement element;

  @override
  Widget build(BuildContext context) {
    final color = heroElementColor(element);
    // 테두리 2겹(외 4px / 내 2px)을 9-slice 스프라이트로 옮긴다. 그라데이션
    // 채움은 스프라이트 `background` 로 못 옮기므로(`Color` 가 아니라
    // `Gradient`) `DecoratedBox` 로 그대로 두고 그 위에 프레임을 겹친다.
    //
    // `Border.all` 은 레이아웃에 여백을 주지 않는다. 원래 안쪽 링은
    // `Padding(all: 5)` 덕분에 바깥 테두리에서 5px 떨어져 있었다. 그 간격을
    // 안쪽 프레임의 `insets`(=4, 두께)가 아니라 **바깥 프레임의 insets** 로
    // 줘야 같은 위치가 된다(5px). 그래서 outer insets = 5, inner insets = 0.
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.72),
                const Color(0xFF171622),
                color.withValues(alpha: 0.28),
              ],
              stops: const [0, 0.58, 1],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        UiFrame.square4(
          insets: const EdgeInsets.all(5),
          color: color,
          child: UiFrame.square2(
            insets: EdgeInsets.zero,
            color: color.withValues(alpha: 0.65),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
