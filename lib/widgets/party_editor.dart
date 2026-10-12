/// Rune Puzzle Tactics — 파티 편성 보조 시트/다이얼로그 (공용)
///
/// [PartySlots] 의 `+` 슬롯과 롱프레스가 여는 진입점이다.
/// 로비 · 파티 탭 · 전투 준비 다이얼로그가 **같은 함수**를 호출하므로,
/// 어느 화면에서 편성하든 흐름·문구가 완전히 동일하다.
///
/// 편성 규칙(공통):
/// - `+` 탭 → [showHeroPickerSheet] — 6열 그리드에서 영웅을 고르고
///   **«영웅을 파티에 합류시키겠습니까?»** 확인을 받은 뒤 편성한다.
/// - 편성 슬롯 롱프레스 → [showUnassignHeroDialog] — 파티 정원이 작으므로
///   되돌리기 비용이 크다. 이것은 확인을 유지한다.
/// - 속성 페이지 목록에서의 편성도 [confirmAssignHero] 를 쓴다.
library;

import 'package:flutter/material.dart';

import 'package:rune_puzzle_tactics/game/rune.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import '../theme/ui_sprites.dart';
import 'card_art.dart';
import 'glass_bottom_sheet.dart';
import 'rune_grid.dart';
import 'ui_frame.dart';

/// 영웅 표시명. 목록/팝업/스니펫이 같은 이름을 쓴다.
String heroDisplayName(AppLocalizations l10n, RuneHeroDef hero) =>
    l10n.tr('hero_name_${hero.heroId}');

/// "🔥 Fire 3명  |  💧 Water 1명" 형태의 파티 속성 집계 한 줄.
///
/// **편성된 속성만** 노출한다 (0명 속성은 데미지에 기여하지 않으므로 잡음만 된다).
/// 배율은 붙이지 않는다 — 같은 속성 영웅이 많을수록 그 색 매칭 데미지의 밑인
/// **공격력 합**이 커지는 것으로 이미 반영된다 ([BattleState.attackForElement]).
/// 파티 탭 · 전투 준비 모달이 이 함수를 공유한다.
String partyElementLine(AppLocalizations l10n, RuneProgress progress) {
  final roster = progress.toRoster();
  final parts = <String>[
    for (final e in RuneElement.normal)
      if (roster.partyCount(e) > 0)
        '${e.emoji} ${l10n.tr('element_${e.name}')} '
            '${l10n.trp('party_count_unit', {'n': roster.partyCount(e)})}',
  ];
  return parts.isEmpty ? l10n.tr('party_synergy_none') : parts.join('  |  ');
}

/// `+` 슬롯이 여는 영웅 선택 바텀시트.
///
/// 시트를 닫고 «영웅을 파티에 합류시키겠습니까?» 확인을 받고 편성한다
/// (요구사항 2 / 5). 확인 문구와 편성 처리는 [confirmAssignHero] 로 통일한다.
///
/// [progress] 의 **최신 스냅샷**을 넘겨야 한다 (편성 후 화면이 갱신되므로
/// 호출 시점의 값을 들고 있어야 한다).
///
/// **시트가 완전히 닫힌 뒤에** [confirmAssignHero] 를 부르는 게 핵심이다.
/// `await showModalBottomSheet` 는 시트 라우트가 제거되고 나서야 완료되므로,
/// 여기서 쓰는 [context] 는 시트 안이 아니라 **살아있는 호출자 화면**이다.
/// 시트 내부 컨텍스트로 다이얼로그를 띄우면 pop 과 함께 사라져 아무 일도
/// 안 일어난 것처럼 보인다(지연 해킹 + `mounted` 가드로 버티려던 방식).
Future<void> showHeroPickerSheet(
  BuildContext context, {
  required RuneProgress progress,
  required ValueChanged<RuneProgress> onChanged,
}) async {
  final picked = await showModalBottomSheet<RuneHeroDef>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _HeroPickerSheet(progress: progress),
  );
  if (picked == null) return;
  // 시트가 열려 있는 동안 호출자 화면이 내려갔을 수 있다(뒤로가기 등).
  if (!context.mounted) return;
  await confirmAssignHero(
    context,
    hero: picked,
    progress: progress,
    onChanged: onChanged,
  );
}

/// `+` 슬롯이 여는 영웅 선택 시트 — **6열 × 3행 그리드** (요구사항 2 / 5).
///
/// 이미 편성된 영웅도 목록에 남긴다(초록 테두리 + "편성중"). 어디가 차 있는지를
/// 숨기면 "왜 안 들어가나" 를 예측할 수 없다. 그 칸만 탭이 막힌다.
///
/// 이 시트는 편성 자체를 하지 않는다. 고른 영웅을 `pop(hero)` 로 **돌려주고**,
/// 실제 편성은 [showHeroPickerSheet] 가 살아있는 컨텍스트에서 [confirmAssignHero]
/// 로 수행한다.
class _HeroPickerSheet extends StatefulWidget {
  const _HeroPickerSheet({required this.progress});

  final RuneProgress progress;

  @override
  State<_HeroPickerSheet> createState() => _HeroPickerSheetState();
}

class _HeroPickerSheetState extends State<_HeroPickerSheet> {
  /// 선택된 속성 탭. null = 전체.
  RuneElement? _selectedElement;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final owned = widget.progress.ownedHeroes;
    final canAssign = widget.progress.partyTotal < HeroRoster.maxPartySize;

    // 속성 필터 적용
    final filteredHeroes = _selectedElement == null
        ? owned
        : owned.where((h) => h.element == _selectedElement).toList();

    return GlassBottomSheet(
      art: const CardArt.header(kCardArtHeaderSheet),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 3행(18칸)이 먼저 보이도록 여유 있게 잡고, 넘치면 아래로 스크롤된다.
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tr('party_picker_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.trp('party_picker_counter', {
                'total': widget.progress.partyTotal,
                'max': HeroRoster.maxPartySize,
              }),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: canAssign ? Colors.white54 : AppColors.danger,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            // 속성 탭 추가
            _ElementTabs(
              selectedElement: _selectedElement,
              onSelected: (element) =>
                  setState(() => _selectedElement = element),
            ),
            const SizedBox(height: 12),
            if (filteredHeroes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  l10n.tr('party_picker_empty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filteredHeroes.length,
                  gridDelegate: runeGridDelegate(
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 5,
                    childAspectRatio: kRuneGridTileAspect,
                  ),
                  itemBuilder: (context, index) {
                    final hero = filteredHeroes[index];
                    final inParty = widget.progress.isHeroInParty(hero.heroId);
                    final enabled = !inParty && canAssign;
                    return HeroGridTile(
                      hero: hero,
                      owned: true,
                      inParty: inParty,
                      level: widget.progress.heroLevel(hero.heroId),
                      tapKey: ValueKey('picker-hero-${hero.heroId}'),
                      // 편성은 여기서 하지 않는다. 고른 영웅을 시트 밖으로
                      // 돌려주고 [showHeroPickerSheet] 이 살아있는 컨텍스트에서
                      // 확인창을 띄워 편성한다.
                      onTap: enabled
                          ? () => Navigator.of(context).pop(hero)
                          : null,
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.tr('party_picker_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// 속성 탭 바 — 전체 + 5개 속성.
class _ElementTabs extends StatelessWidget {
  const _ElementTabs({
    required this.selectedElement,
    required this.onSelected,
  });

  final RuneElement? selectedElement;
  final ValueChanged<RuneElement?> onSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <RuneElement?>[null, ...RuneElement.normal];

    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _ElementTab(
              element: tabs[i],
              selected: tabs[i] == selectedElement,
              onTap: () => onSelected(tabs[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ElementTab extends StatelessWidget {
  const _ElementTab({
    required this.element,
    required this.selected,
    required this.onTap,
  });

  final RuneElement? element;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final label = element == null
        ? l10n.tr('party_tab_all')
        : '${element!.emoji} ${l10n.tr('element_${element!.name}')}';
    final color = selected ? AppColors.accent : const Color(0xFF8A9298);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: selected
              ? UiFrame.square2(
                  height: 34,
                  color: AppColors.accent,
                  background: const Color(0xFF39434A),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x80000000),
                      offset: Offset(1, 2),
                      blurRadius: 2,
                    ),
                  ],
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              : UiFrame.square1(
                  height: 34,
                  color: const Color(0xFF596168),
                  background: const Color(0xFF252C31),
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 파티 해제 확인 → [RuneProgress.tryUnassignHero].
Future<void> showUnassignHeroDialog(
  BuildContext context, {
  required RuneHeroDef hero,
  required RuneProgress progress,
  required ValueChanged<RuneProgress> onChanged,
}) async {
  final l10n = LanguageScope.of(context).strings;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: ValueKey('party-unassign-confirm-${hero.heroId}'),
      backgroundColor: AppColors.glassCardStrong,
      title: Text(l10n.tr('party_unassign_confirm_title')),
      content: Text(
        l10n.trp('party_unassign_confirm_message', {
          'hero': heroDisplayName(l10n, hero),
        }),
      ),
      actions: [
        TextButton(
          key: ValueKey('party-unassign-no-${hero.heroId}'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.tr('party_assign_no')),
        ),
        FilledButton(
          key: ValueKey('party-unassign-yes-${hero.heroId}'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.tr('party_assign_yes')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final result = progress.tryUnassignHero(hero.heroId);
  if (result.ok) onChanged(result.progress);
}

/// 편성 확인 다이얼로그 → [RuneProgress.tryAssignHero].
///
/// `+` 슬롯 시트([showHeroPickerSheet])와 속성 페이지 그리드가 **공유**한다 —
/// 어느 경로로 영웅을 골라도 «영웅을 파티에 합류시키겠습니까?» 를 한 번 거친다.
Future<void> confirmAssignHero(
  BuildContext context, {
  required RuneHeroDef hero,
  required RuneProgress progress,
  required ValueChanged<RuneProgress> onChanged,
}) async {
  final l10n = LanguageScope.of(context).strings;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: ValueKey('party-assign-confirm-${hero.heroId}'),
      backgroundColor: AppColors.glassCardStrong,
      title: Text(l10n.tr('party_assign_confirm_title')),
      content: Text(
        l10n.trp('party_assign_confirm_message', {
          'hero': heroDisplayName(l10n, hero),
        }),
      ),
      actions: [
        TextButton(
          key: ValueKey('party-assign-no-${hero.heroId}'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.tr('party_assign_no')),
        ),
        FilledButton(
          key: ValueKey('party-assign-yes-${hero.heroId}'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.tr('party_assign_yes')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final result = progress.tryAssignHero(hero.heroId);
  if (result.ok) onChanged(result.progress);
}
