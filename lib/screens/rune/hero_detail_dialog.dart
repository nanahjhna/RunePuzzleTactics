/// Rune Puzzle Tactics — 영웅 상세 팝업 (파티 탭 그리드 / 영웅도감 공용)
///
/// 데이터 정책:
/// - **스킬은 영웅 단위**다 ([HeroSkills.specFor] 의 키는 heroId).
///   같은 속성이어도 스킬 효과/수치가 다르고, Lightning도 모두 스킬을 가진다.
/// - 스탯도 영웅마다 다르다 ([HeroPool] 의 `_stats` 테이블). 여기서는
///   합산 전 개인 기본치를 보여준다.
/// - 영웅별 소개문과 스킬 설명문은 l10n 키로 관리한다
///   (`hero_desc_<heroId>`, `hero_skill_<heroId>` / `hero_skill_none`).
/// - 미보유 영웅도 동일 정보를 공개한다 (영웅도감 스포일러 규칙과 동일).
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../../l10n/language_controller.dart';
import '../../services/rune_analytics.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/hero_card.dart';
import '../../widgets/hero_portrait.dart';
import '../../widgets/ui_pill.dart';

/// 영웅 상세 팝업 표시.
///
/// [hero] 를 눌러 설명/스킬을 확인하고 **스탯을 강화**한다. [progress] 로
/// 보유·편성 상태를 판정하므로 호출 시점의 최신 진행도를 넘겨야 한다.
///
/// **강화는 여기서 한다** — 상점의 마도서를 없애고 영웅 1명씩 쌓는 축으로
/// 바꿨다. 파티 공통 보너스가 사라졌으므로 이 창이 유일한 강화 진입점이 된다.
/// [onChanged] 로 진행도를 밖으로 내보내야 재화 차감/레벨 증가가 저장된다.
Future<void> showHeroDetailDialog(
  BuildContext context, {
  required RuneHeroDef hero,
  required RuneProgress progress,
  ValueChanged<RuneProgress>? onChanged,
  RuneAnalytics? analytics,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _HeroDetailDialog(
      hero: hero,
      progress: progress,
      onChanged: onChanged,
      analytics: analytics,
    ),
  );
}

class _HeroDetailDialog extends StatefulWidget {
  const _HeroDetailDialog({
    required this.hero,
    required this.progress,
    this.onChanged,
    this.analytics,
  });

  final RuneHeroDef hero;

  /// 호출 시점의 진행도 스냅샷.
  ///
  /// 파 immutable이라 강화하려면 **새 스냅샷**으로 갈아끼워야 한다.
  /// [State.progress] 가 그 역할을 한다 — 여기 값을 직접 바꾸지 않는다.
  final RuneProgress progress;

  /// 강화 성공 시 호출부로 진행도 전달 (호출부가 setState + 저장).
  final ValueChanged<RuneProgress>? onChanged;

  final RuneAnalytics? analytics;

  @override
  State<_HeroDetailDialog> createState() => _HeroDetailDialogState();
}

class _HeroDetailDialogState extends State<_HeroDetailDialog> {
  /// **지금 화면에 그려야 하는** 진행도.
  ///
  /// 초기에는 호출부가 넘긴 스냅샷이고, 강화에 성공할 때마다 새 스냅샷으로
  /// 갱신된다. [widget.progress] (호출부의 값) 을 직접 만지면 팝업이 닫힐 때
  /// 갱신 전 값으로 되돌아가 버전을 찾는 버그가 생긴다.
  late RuneProgress _progress = widget.progress;

  RuneHeroDef get hero => widget.hero;

  void _onChanged(RuneProgress next) {
    setState(() => _progress = next);
    widget.onChanged?.call(next);
  }

  /// 강화 실행 → 성공/실패 스낵바.
  void _upgrade(HeroStatKind kind) {
    final l10n = LanguageScope.of(context).strings;
    final r = _progress.tryUpgradeHeroStat(hero.heroId, kind);
    if (!r.ok) {
      final cost = r.cost;
      _toast(
        context,
        // cost 가 null 이면 최대 레벨(또는 미보유) — 필요한 금액이 없다.
        cost == null
            ? l10n.tr('shop_error_max_level')
            : l10n.trp('shop_error_game', {'n': cost}),
      );
      return;
    }
    // 성공이면 `level` 은 절대로 null 이 아니다 — 그래도 레코드 타입상 int 를
    // 요구하므로 폴백을 둔다.
    widget.analytics?.logHeroStatUpgrade(
      heroId: hero.heroId,
      stat: kind.name,
      level: r.level ?? 0,
    );
    _onChanged(r.progress);
    _toast(context, l10n.tr('book_purchase_success'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final progress = _progress;
    final element = hero.element;
    final spec = HeroSkills.specFor(hero.heroId);
    final owned = progress.isHeroOwned(hero.heroId);
    final heroName = l10n.tr('hero_name_${hero.heroId}');

    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      key: ValueKey('hero-detail-${hero.heroId}'),
      backgroundColor: AppColors.cardDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: CardArtBackdrop(
        asset: kCardArtHeroDetail,
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SizedBox(
                  width: 210,
                  child: HeroCard(
                    hero: hero,
                    name: heroName,
                    dimmed: !owned,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusBadge(
                    text:
                        '${element.emoji} ${l10n.tr('element_${element.name}')}',
                    color: heroElementColor(element),
                  ),
                  if (hero.isStarter)
                    _StatusBadge(
                      text: l10n.tr('hero_detail_starter'),
                      color: AppColors.playCoinBlue,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _HeroLevelPanel(hero: hero, progress: progress),
              const SizedBox(height: 12),
              _SectionTitle(text: l10n.tr('hero_detail_desc_label')),
              const SizedBox(height: 4),
              Text(
                l10n.tr('hero_desc_${hero.heroId}'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _SectionTitle(text: l10n.tr('hero_detail_skill_label')),
              const SizedBox(height: 4),
              // 스킬은 속성 공유가 아니라 **영웅 단위**다
              // (`HeroSkills.specFor(heroId)`).
              Text(
                spec == null
                    ? l10n.tr('hero_skill_none')
                    : l10n.tr(spec.descriptionKeyFor(hero.heroId)),
                style: TextStyle(
                  color: spec == null
                      ? Colors.white38
                      : heroElementColor(element),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              _SectionTitle(text: l10n.tr('hero_detail_stats_label')),
              const SizedBox(height: 6),
              // 상점의 마도서/파티 공통 업그레이드를 없애고 **영웅 1명씩** 쌓는
              // 축으로 옮겼다. 파티 공통 보너스 분배가 사라졌으므로 이 창이
              // 유일한 강화 진입점이다 — 값은 여기서 [RuneProgress] 로만 나간다.
              for (final config in HeroStatUpgrades.all)
                _HeroStatUpgradeRow(
                  hero: hero,
                  progress: progress,
                  config: config,
                  enabled: owned,
                  onUpgrade: () => _upgrade(config.kind),
                ),
              const SizedBox(height: 14),
              // 별(★) 등급 표시는 전 화면에서 제거했다 — 여기도 예외가 아니고,
              // 해금 스테이지 안내만 남긴다.
              Row(
                children: [
                  Icon(
                    Icons.lock_open,
                    size: 13,
                    color: progress.isHeroUnlocked(hero.heroId)
                        ? AppColors.green
                        : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.trp('shop_locked_unlock', {'n': hero.unlockStage}),
                      style: TextStyle(
                        color: progress.isHeroUnlocked(hero.heroId)
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.tr('common_cancel')),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// 영웅 레벨 + 경험치 바 + 레벨 보너스 한 줄.
///
/// 레벨은 재화가 아니라 **승리 EXP** 로만 오른다. 바는 다음 레벨까지의 진행이고,
/// 만렙이면 MAX 로 잠근다. 레벨이 주는 스탯 상승은 유료 강화와 별개 합산이라
/// 아래 강화 행의 화살표에는 섞이지 않는다([_HeroStatUpgradeRow._base] 참고).
class _HeroLevelPanel extends StatelessWidget {
  const _HeroLevelPanel({required this.hero, required this.progress});

  final RuneHeroDef hero;
  final RuneProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final level = progress.heroLevel(hero.heroId);
    final maxed = progress.isHeroMaxLevel(hero.heroId);
    final exp = progress.heroExp(hero.heroId);
    final next = progress.heroExpToNext(hero.heroId);
    final ratio = progress.heroExpRatio(hero.heroId);
    final bonus = progress.heroLevelBonus(hero.heroId);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatusBadge(
                text: '${l10n.tr('hero_level_label')} $level',
                color: AppColors.accentGold,
              ),
              const Spacer(),
              Text(
                maxed
                    ? l10n.tr('hero_level_max')
                    : l10n.trp('hero_exp_progress', {
                        'exp': exp,
                        'next': next,
                      }),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentGold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.tr('hero_level_bonus')}  '
            '${l10n.tr('stat_hp')} +${bonus.hp}  '
            '${l10n.tr('stat_atk')} +${bonus.attack}  '
            '${l10n.tr('stat_def')} +${bonus.defense}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// 팝업 내 소제목.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

/// 스탯 강화 한 줄 — `[이름] [기본치→현재치] [레벨] [+ 비용]`.
///
/// 상점의 아이템 타일을 대체한 강화 UI다. 기본치와 현재치를 **둘 다** 보여줘야
/// "내가 뭘 샀는지"가 읽힌다 — 강화량이 없다면 현재치만으로 충분하고, 있으면
/// `100 → 200` 처럼 증가분이 그대로 보인다.
class _HeroStatUpgradeRow extends StatelessWidget {
  const _HeroStatUpgradeRow({
    required this.hero,
    required this.progress,
    required this.config,
    required this.enabled,
    required this.onUpgrade,
  });

  final RuneHeroDef hero;
  final RuneProgress progress;
  final HeroStatUpgradeConfig config;

  /// 미보유 영웅은 강화 불가 (보유해도 재화만 날리는 함정 방지).
  final bool enabled;

  final VoidCallback onUpgrade;

  /// 이 스탯의 강화 반영 후 실제 값.
  int get _current => switch (config.kind) {
    HeroStatKind.hp => progress.heroCombatStatsOf(hero.heroId).hp,
    HeroStatKind.attack => progress.heroCombatStatsOf(hero.heroId).attack,
    HeroStatKind.defense => progress.heroCombatStatsOf(hero.heroId).defense,
  };

  /// 강화 전 개인 기본치. **레벨 보너스는 포함**한다 — 그래야 `기본 → 현재`
  /// 화살표가 유료 강화분만 가리키고, 레벨 성장은 위쪽 레벨 패널이 설명한다.
  int get _base {
    final levelBonus = progress.heroLevelBonus(hero.heroId);
    return switch (config.kind) {
      HeroStatKind.hp => hero.hp + levelBonus.hp,
      HeroStatKind.attack => hero.attack + levelBonus.attack,
      HeroStatKind.defense => hero.defense + levelBonus.defense,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final level = progress.heroStatLevel(hero.heroId, config.kind);
    final maxed = level >= config.maxLevel;
    final cost = config.costForLevel(level);
    final affordable = enabled && !maxed && progress.gameCurrency >= cost;
    final raised = _current > _base;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.tr(_labelKey),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                // 기본치 → 현재치. 강화 전이면 현재치만 (화살표가 거슬리므로).
                Text(
                  raised ? '$_base → $_current' : '$_current',
                  style: TextStyle(
                    color: raised ? AppColors.accent : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.trp('shop_lv', {'level': level, 'max': config.maxLevel}),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 8),
          _UpgradePlusButton(
            label: maxed ? 'MAX' : l10n.trp('currency_game', {'n': cost}),
            enabled: affordable,
            isMax: maxed,
            onTap: onUpgrade,
          ),
        ],
      ),
    );
  }

  /// 스탯 → l10n 키. `stat_hp` / `stat_atk` / `stat_def` 를 재사용한다.
  String get _labelKey => switch (config.kind) {
    HeroStatKind.hp => 'stat_hp',
    HeroStatKind.attack => 'stat_atk',
    HeroStatKind.defense => 'stat_def',
  };
}

/// 강화 행 우측의 `+` 버튼 — **비용을 버튼 안에** 담아 누르기 전에 보이게 한다.
class _UpgradePlusButton extends StatelessWidget {
  const _UpgradePlusButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isMax = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    final accent = isMax ? AppColors.accentGold : AppColors.accent;
    return Opacity(
      opacity: enabled || isMax ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: UiPill(
            size: UiPillSize.medium,
            borderColor: accent.withValues(alpha: isMax ? 0.8 : 1.0),
            background: accent.withValues(alpha: isMax ? 0.12 : 0.18),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMax) ...[
                  Icon(Icons.add, size: 14, color: accent),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 강화 결과 스낵바 (연속 강화 시 겹치지 않게 교체).
void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 보유/편성 상태 배지.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return UiPill(
      size: UiPillSize.medium,
      borderColor: color.withValues(alpha: 0.6),
      background: color.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
