/// Rune Puzzle Tactics — 허브 [Party] 탭 (PHASE 7, RPT-414 / HeroPool 개편)
///
/// 보유(Hero Pool)와 편성(Party ≤ 5)을 관리한다 (RPT-289, RPT-293).
/// - 영웅 단위(heroId) 편성/해제 (프롬프트 §29)
/// - **파티 페이지(전체)**: 공통 [PartySlots] 1x5 스트립. 빈 자리는 `+` 이고,
///   탭하면 [showHeroPickerSheet] 이 열린다 (로비 · 전투 준비와 같은 위젯).
///   그 아래에 파티 시너지 한 줄.
/// - 영웅 슬롯/도감 타일 탭 → 영웅 상세 팝업(설명 + 스킬)
/// - 탭 하단 영웅도감: **6열 그리드** (속성 아코디언 폐기, 요구사항 6)
/// - 영입(Recruit)은 상점 탭에서 담당 (프롬프트 §30)
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter/material.dart';

import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/party_editor.dart';
import '../../widgets/party_slots.dart';
import '../../widgets/rune_grid.dart';
import '../../widgets/ui_frame.dart';
import 'hero_detail_dialog.dart';

/// Party 탭 (메인 허브 탭 1).
class RunePartyTab extends StatefulWidget {
  const RunePartyTab({
    super.key,
    required this.progress,
    required this.onChanged,
  });

  final RuneProgress progress;
  final ValueChanged<RuneProgress> onChanged;

  @override
  State<RunePartyTab> createState() => _RunePartyTabState();
}

class _RunePartyTabState extends State<RunePartyTab> {
  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final l10n = LanguageScope.of(context).strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _InventoryFrame(
          art: const CardArt.header(kCardArtHeaderParty),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tr('party_title'),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    l10n.trp('party_counter', {
                      'total': p.partyTotal,
                      'max': HeroRoster.maxPartySize,
                    }),
                    style: TextStyle(
                      color: p.partyTotal >= HeroRoster.maxPartySize
                          ? AppColors.orange
                          : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr('party_desc'),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 12),
              _PartyInventory(progress: p, onChanged: widget.onChanged),
              const SizedBox(height: 8),
              Text(
                l10n.tr('party_summary'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.tr('party_recruit_hint'),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // ── 영웅도감: 속성당 1번 영웅 전량 일람 (보유 여부와 무관 공개) ──
        // 속성별 아코디언(접기/펼치기)을 없애고 **5열 그리드**로 통일한다.
        // 노출 대상은 [HeroPool.oneStarHeroes] = `fire_a` `water_a` `grass_a`
        // `light_a` `poison_a` **5명뿐**이라 5열이면 딱 한 행이 차곡차곡 차고,
        // 6열이었을 때 남던 빈 한 칸이 사라진다.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tr('hero_codex_title'),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              l10n.trp('codex_owned_count', {
                'owned': _codexOwnedTotal(p),
                'total': HeroPool.oneStarHeroes.length,
              }),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l10n.tr('hero_codex_desc'),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        _InventoryFrame(
          art: const CardArt.header(kCardArtHeaderCodex),
          child: _CodexGrid(progress: p, onChanged: widget.onChanged),
        ),
      ],
    );
  }
}

/// 도감이 **노출하는**(속성당 1번 영웅) 영웅 중 보유 수.
///
/// 전체 보유 수([RuneProgress.ownedTotal])를 그대로 쓰면 분모 5 / 분자 20 처럼
/// "보유 2 / 20" 이 찍혀 도감이 20칸인 것처럼 보인다.
int _codexOwnedTotal(RuneProgress p) =>
    HeroPool.oneStarHeroes.where((h) => p.isHeroOwned(h.heroId)).length;

/// 영웅도감 그리드 — **5열** 고정, **속성당 1번 영웅만** 노출.
///
/// 열 수를 5로 한 이유는 [HeroPool.oneStarHeroes] 가 속성당 1명, 총 5명이라
/// 공용 규격([kRuneGridColumns] = 6)을 쓰면 마지막 한 칸이 영영 비기 때문이다.
/// 상점 아이템 목록·영웅 선택 시트는 20명을 모두 다루므로 6열을 그대로 쓴다.
const int _kCodexColumns = 5;

/// 미보유 영웅도 스포일러 규칙대로 보이되 흐리게 + 🔒 배지를 단다.
/// 탭 → 영웅 상세 팝업([showHeroDetailDialog]).
class _CodexGrid extends StatelessWidget {
  const _CodexGrid({required this.progress, required this.onChanged});

  final RuneProgress progress;

  /// 영웅 상세 팝업의 강화 결과를 밖으로 내보낸다.
  final ValueChanged<RuneProgress> onChanged;

  @override
  Widget build(BuildContext context) {
    final heroes = HeroPool.oneStarHeroes;
    // 5칸(5×1)이므로 한 행이 들어간다. 프레임 안에서만 스크롤시키고
    // 바깥 ListView 와 스크롤이 겹치지 않도록 크기를 고정한다.
    final rows = (heroes.length / _kCodexColumns).ceil();
    final tileWidth =
        (MediaQuery.sizeOf(context).width - 44 - 5 * (_kCodexColumns - 1)) /
        _kCodexColumns;
    final tileHeight = tileWidth / kRuneGridTileAspect;

    return SizedBox(
      height: rows * tileHeight + (rows - 1) * 5,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: heroes.length,
        gridDelegate: runeGridDelegate(
          crossAxisCount: _kCodexColumns,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          final hero = heroes[index];
          return HeroGridTile(
            hero: hero,
            owned: progress.isHeroOwned(hero.heroId),
            inParty: progress.isHeroInParty(hero.heroId),
            tapKey: ValueKey('codex-hero-${hero.heroId}'),
            onTap: () => showHeroDetailDialog(
              context,
              hero: hero,
              progress: progress,
              onChanged: onChanged,
            ),
          );
        },
      ),
    );
  }
}

class _PartyInventory extends StatelessWidget {
  const _PartyInventory({required this.progress, required this.onChanged});

  final RuneProgress progress;
  final ValueChanged<RuneProgress> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    // 보유 영웅이 0명이면 빈 슬롯만 남는 것보다 안내 문구가 낫다.
    if (progress.ownedTotal == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          l10n.tr('party_empty_hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }
    // 공통 1x5 슬롯 스트립 — 빈 자리는 `+` (로비/전투 준비와 동일한 위젯).
    // 영웅 목록은 속성 페이지([_ElementInventory])가 맡는다. 여기서 또 그리드를
    // 그리면 같은 정보가 두 번 보인다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PartySlots(
          progress: progress,
          onChanged: onChanged,
          onHeroTap: (ctx, hero) => showHeroDetailDialog(
            ctx,
            hero: hero,
            progress: progress,
            onChanged: onChanged,
          ),
          onHeroLongPress: (ctx, hero) => showUnassignHeroDialog(
            ctx,
            hero: hero,
            progress: progress,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          partyElementLine(l10n, progress),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _InventoryFrame extends StatelessWidget {
  const _InventoryFrame({required this.child, this.art});

  final Widget child;

  /// 상단 헤더 아트 ([CardArt.header]). 내부 패널이 반투명이라 뒤로 비친다.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    // 단일 프레임 시스템: UiFrame.round4 로 통일.
    // 예전에는 바깥에 UI_Flat_Frame01a 를 깔았지만, 이제 모든 카드가 같은
    // 테두리 토큰을 써야 화면마다 다르게 보이지 않는다.
    return UiFrame.round4(
      fit: StackFit.loose,
      background: const Color(0xFF20262A),
      color: AppColors.glassBorder,
      insets: const EdgeInsets.all(10),
      art: art,
      child: Container(
        padding: const EdgeInsets.all(8),
        // 60% 불투명 — 뒤의 헤더 아트가 패널을 뚫고 비친다.
        // 100% 면 카드가 평평한 단색 패널로 보여 헤더 아트가 10px 테두리로
        // 죽어 버린다. 그리드 타일은 각자 불투명 배경을 가져 가독성과 무관하다.
        decoration: const BoxDecoration(color: Color(0x99151A1D)),
        child: child,
      ),
    );
  }
}

// ── 파티 탭 파일 끝 ──
