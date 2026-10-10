/// Rune Puzzle Tactics — 공통 파티 슬롯 스트립 (1x4)
///
/// **모든 파티 편성 화면이 이 위젯 하나를 공유한다** (로비 / 파티 탭 / 전투 준비).
/// 편성 슬롯만 각 화면마다 따로 그리지 않고, "빈 자리는 🔒 가 아니라 `+` 버튼"이라는
/// 규칙도 여기 한 곳에 모아둔다.
///
/// 규칙:
/// - 편성된 자리는 [HeroPortrait] + 속성 단위 시너지 배지(`N·1.2x`)를 보여준다.
///   - 탭 → [onHeroTap] (호출부가 영웅 상세 팝업을 넘긴다)
///   - **롱프레스** → [onHeroLongPress] (호출부가 [showUnassignHeroDialog] 를 넘긴다)
/// - 빈 자리는 `+` 카드다. 탭 → [showHeroPickerSheet](기본 동작, [onEmptyTap] 으로
///   덮어쓸 수 있다).
/// - 파티가 가득 차면 `+` 는 **비활성**이 된다(탭해도 아무 일도 일어나지 않는다).
/// - 파티에 자리가 남아도 **보유 영웅을 전원 편성했다면** `+` 는 비활성이다
///   (요구사항 5). 판정 단위는 [RuneProgress.availableHeroIds] 하나.
/// - 비활성이라도 탭을 받아 "왜 안 되지" 를 스낵바로 알려준다 — 아무 반응 없는
///   죽은 버튼이 되지 않도록.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import 'hero_portrait.dart';
import 'party_editor.dart';
import 'ui_frame.dart';

/// 공통 파티 슬롯 스트립.
class PartySlots extends StatelessWidget {
  const PartySlots({
    super.key,
    required this.progress,
    required this.onChanged,
    this.size = 52,
    this.spacing = 6,
    this.onHeroTap,
    this.onHeroLongPress,
    this.onEmptyTap,
  });

  /// 현재 진행 상태. 편성/해제는 여기서 일어나 [onChanged] 로 위로 전파한다.
  final RuneProgress progress;

  /// 편성 변경 알림. 메인 화면이 이걸 받아 영장 저장까지 이어서 한다.
  final ValueChanged<RuneProgress> onChanged;

  /// 슬롯 한 변 길이.
  final double size;

  /// 슬롯 간격.
  final double spacing;

  /// 편성 영웅 탭. null이면 상세 팝업이 열리지 않는다(읽기 전용).
  final void Function(BuildContext context, RuneHeroDef hero)? onHeroTap;

  /// 편성 영웅 롱프레스. null이면 확인 다이얼로그 없이 아무 일도 없다.
  final void Function(BuildContext context, RuneHeroDef hero)? onHeroLongPress;

  /// 빈 슬롯 탭을 **덮어쓸 때만** 넘긴다.
  ///
  /// null(기본)이면 [showHeroPickerSheet] 가 자동으로 붙는다 — 호출부가 이걸
  /// 넘기지 않아도 `+` 가 동작한다.
  ///
  /// 이전 구현은 이 값을 "`+` 를 쓸 수 있게 하는 스위치"로 썼는데, 세 호출부
  /// (로비 / 파티 탭 / 전투 준비) 모두 넘겨주지 않아 `+` 가 동작하지 않았다.
  /// **읽기 전용** 스트립이 필요하면 이 위젯 대신 직접 그린다.
  final VoidCallback? onEmptyTap;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final partyHeroes = progress.partyHeroDefs;
    final total = HeroRoster.maxPartySize;
    final full = partyHeroes.length >= total;
    // 요구사항 5: "소유하고 있는 캐릭터가 더 있으면" `+` 가 살아난다.
    final hasAvailable = progress.availableHeroIds.isNotEmpty;
    final canAdd = !full && hasAvailable;

    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i < partyHeroes.length) {
        children.add(
          _FilledSlot(
            hero: partyHeroes[i],
            partyHeroes: partyHeroes,
            size: size,
            onTap: onHeroTap == null
                ? null
                : () => onHeroTap!(context, partyHeroes[i]),
            onLongPress: onHeroLongPress == null
                ? null
                : () => onHeroLongPress!(context, partyHeroes[i]),
          ),
        );
      } else {
        children.add(
          _EmptySlot(
            size: size,
            enabled: canAdd,
            // 비활성이어도 `+` 를 탭하면 그 이유를 스낵바로 알려준다 — 아무 반응이
            // 없는 죽은 버튼이 되지 않도록.
            hint: full
                ? l10n.tr('party_slots_full')
                : hasAvailable
                ? null
                : l10n.tr('party_slots_nothing_to_add'),
            onTap:
                onEmptyTap ??
                () => showHeroPickerSheet(
                  context,
                  progress: progress,
                  onChanged: onChanged,
                ),
          ),
        );
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          children[i],
        ],
      ],
    );
  }
}

/// 편성된 영웅 한 칸.
class _FilledSlot extends StatelessWidget {
  const _FilledSlot({
    required this.hero,
    required this.partyHeroes,
    required this.size,
    this.onTap,
    this.onLongPress,
  });

  final RuneHeroDef hero;

  /// 같은 속성의 파티 편성 수 N (속성 카운트 배지 표기용).
  final List<RuneHeroDef> partyHeroes;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final n = partyHeroes.where((e) => e.element == hero.element).length;
    final portrait = HeroPortrait(
      hero: hero,
      size: size,
      showElementBadge: true,
      overlay: _ElementCountBadge(count: n),
    );
    if (onTap == null && onLongPress == null) return portrait;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: portrait),
    );
  }
}

/// 빈 파티 자리의 `+` 카드.
///
/// 🔒 잠금 아이콘을 쓰지 않는다 — "여기를 눌러서 영웅을 넣는다"가 곧 편성
/// 진입점이므로, 잠금 표식은 오히려 화면이 닫혀 보인다.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.size,
    required this.enabled,
    required this.onTap,
    this.hint,
  });

  final double size;
  final bool enabled;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final radius = BorderRadius.circular(6);
    return Tooltip(
      message: hint ?? l10n.tr('party_slot_add_tooltip'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // 비활성이어도 탭을 받는다 — "아무 반응 없음" 대신 이유를 알려준다.
          onTap: enabled
              ? onTap
              : hint == null
              ? null
              : () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(hint!)));
                },
          borderRadius: radius,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.35,
            // 테두리(반경 6, 2px)는 스프라이트, 채움은 색.
            child: UiFrame.round6(
              width: size,
              height: size,
              color: AppColors.glassBorder,
              background: Colors.white.withValues(alpha: 0.06),
              child: const Center(
                child: Icon(
                  Icons.add_circle_outline,
                  color: Colors.white54,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 초상화 하단 속성 카운트 배지: `3` (같은 속성 파티 편성 수).
///
/// 배율 숫자는 삭제했다. 데미지는 이 **인원수의 공격력 합**으로 이미 반영되므로
/// (`[BattleState.attackForElement]`), 배율표를 곱하면 같은 정보를 두 번 쓰는 셈이라
/// 플레이어가 숫자를 잘못 읽게 된다. 여기서는 인원수만 알린다.
class _ElementCountBadge extends StatelessWidget {
  const _ElementCountBadge({required this.count});

  /// 해당 속성의 파티 편성 수 N.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(999)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: count > 0 ? AppColors.accentGold : Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}
