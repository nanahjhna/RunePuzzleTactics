/// Rune Puzzle Tactics — 허브 [Shop] 탭 (PHASE 7, RPT-415 / 3-재화·HeroPool 개편)
///
/// Game Currency 기반 성장: 파티 스탯 마도서 5종 + 영구 업그레이드 1종 (RPT-397 ~ RPT-404)
/// + Hero Currency 기반 **랜덤 영입(뽑기)**.
/// - 업그레이드: Game Currency 차감 → 레벨+1 (원자적 스냅샷, RPT-400)
/// - 영입: ⭐ 1연/10연 뽑기. 등급( HeroRarity ) 가중 추첨, 중복은 최고 등급 영웅이
///   흡수해 1등급 승급한다. 자동 파티 편성 없음 (프롬프트 §1).
///   (등급은 현재 ★ 1단계뿐이라 확률표는 `★ 100%` 한 줄이고 중복은 항상 최고 등급.)
///
/// 화면 배치 (요구사항 7·8·9):
/// - **뽑기 패널이 최상단** — 재화 소모가 가장 크고 이벤트성이라 스크롤 없이 보인다.
/// - 마도서/업그레이드는 **세로 카드 리스트** (5 + 1 = 스탯 하나당 카드 한 장,
///   카드 안에 현재값·레벨·가격·`+` 버튼이 함께 보인다).
/// - 뽑기 패널 안에 **천상(연속 중복) 바**와 확률표를 노출한다.
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flutter/material.dart';

import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/hero_portrait.dart';
import '../../widgets/ui_bar.dart';
import '../../widgets/ui_frame.dart';
import '../../widgets/ui_pill.dart';
// (rune_grid import 제거됨 - ShopItemTile 삭제로 상점 탭에서 불필요)
import 'hero_gacha_dialog.dart';

/// Shop 탭 (메인 허브 탭 2).
class RuneShopTab extends StatelessWidget {
  const RuneShopTab({
    super.key,
    required this.progress,
    required this.onChanged,
    this.analytics,
  });

  final RuneProgress progress;
  final ValueChanged<RuneProgress> onChanged;
  final RuneAnalytics? analytics;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final l10n = LanguageScope.of(context).strings;
    // 고정 크기(업그레이드 3 + 뽑기 패널) 콘텐츠이므로 SingleChildScrollView로
    // 전부 즉시 빌드한다. ListView(children:)는 뷰포트 근처만 실체화해 아래쪽 뽑기
    // 버튼이 위젯 트리에 없어 ensureVisible/탭이 실패할 수 있다.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더: Game Currency + Hero Currency 잔액
          Row(
            children: [
              Text(
                l10n.tr('shop_title'),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              _CurrencyChip(
                label: l10n.trp('currency_game', {'n': p.gameCurrency}),
              ),
              const SizedBox(width: 6),
              _CurrencyChip(
                label: l10n.trp('currency_hero', {'n': p.heroCurrency}),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 영웅 랜덤 영입 (뽑기, Hero Currency) ──
          // **최상단 배치** (요구사항 8): 재화 소모가 가장 크고 이벤트성이라
          // 스크롤 없이 바로 보인다. 마서부는 그 아래로 미룬다.
          Text(
            l10n.tr('gacha_header'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          _GachaPanel(progress: p, onPull: (count) => _pull(context, count)),

          // ── 파티 스탯 업그레이드는 영웅 초상화 팝업으로 옮겨갔다 ──
          // 상점의 아이템(마도서 5종)과 파티 공통 업그레이드를 전부 걷어냈다.
          // 강화는 이제 **영웅 1명씩** 한다 — 로비/파티 탭에서 영웅을 탭하면
          // 뜨는 [showHeroDetailDialog] 안의 `+` 버튼. 상점은 뽑기 전용.
        ],
      ),
    );
  }

  /// 뽑기 실행: 재화 차감 + 결과 확정 → 진행도 반영 → 결과 팝업(연출).
  Future<void> _pull(BuildContext context, int count) async {
    final l10n = LanguageScope.of(context).strings;
    final cost = count == HeroGacha.tenCount
        ? HeroGacha.tenCost
        : count * HeroGacha.singleCost;
    final r = progress.tryPullHeroes(count: count);
    if (!r.ok) {
      final msg = switch (r.reason) {
        'empty_pool' => l10n.tr('gacha_empty_pool'),
        _ =>
          count > 1
              ? l10n.trp('gacha_error_hero_count', {'n': cost, 'count': count})
              : l10n.trp('gacha_error_hero', {'n': cost}),
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    for (final res in r.results) {
      analytics?.logHeroRecruit(
        heroId: res.hero.heroId,
        element: res.hero.element,
        rarity: res.gradeAfter,
        outcome: res.outcome.name,
      );
    }
    onChanged(r.progress);
    if (!context.mounted) return;
    await showHeroGachaDialog(
      context,
      results: r.results,
      progress: r.progress,
    );
  }
}

/// 잔액 칩 (규칙 2: Pill Shape radius 50).
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return UiPill(
      size: UiPillSize.medium,
      borderColor: AppColors.glassBorder,
      background: AppColors.glassCard,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 영웅 뽑기 패널: 1연/10연 버튼 + 보유 도감 진행도 + 등급 확률표.
///
/// 재화가 모자라면 버튼을 비활성화하고, 확률은 **현재 스테이지에서 가용 등급만**
/// 정규화해 표시한다 ([HeroGacha.rateTable]).
class _GachaPanel extends StatelessWidget {
  const _GachaPanel({required this.progress, required this.onPull});

  final RuneProgress progress;
  final ValueChanged<int> onPull;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final nextStage = progress.nextStage;
    final table = HeroGacha.rateTable(nextStage);
    final maxRate = table.isEmpty
        ? 1.0
        : table.map((e) => e.rate).reduce((a, b) => a > b ? a : b);
    final affordable1 = progress.heroCurrency >= HeroGacha.singleCost;
    final affordable10 = progress.heroCurrency >= HeroGacha.tenCost;

    return GlassSurface(
      padding: const EdgeInsets.all(12),
      blur: 0,
      art: const CardArt.fill(kCardArtShopGacha),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PullButton(
                  buttonKey: const ValueKey('gacha-single'),
                  label: l10n.tr('gacha_single'),
                  cost: HeroGacha.singleCost,
                  enabled: affordable1,
                  onPressed: () => onPull(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PullButton(
                  buttonKey: const ValueKey('gacha-ten'),
                  label: l10n.tr('gacha_ten'),
                  cost: HeroGacha.tenCost,
                  enabled: affordable10,
                  highlight: true,
                  onPressed: () => onPull(HeroGacha.tenCount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PityBar(progress: progress),
          const SizedBox(height: 10),
          Text(
            l10n.trp('gacha_codex_progress', {
              'owned': progress.ownedTotal,
              'total': HeroPool.heroes.length,
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tr('gacha_rates_header'),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in table)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    // ★ 대신 등급 **문자**(R/SR/SSR/UR)를 쓴다.
                    child: Text(
                      e.rarity.badge,
                      style: TextStyle(
                        color: heroRarityColor(e.rarity),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: UiBar(
                      value: maxRate == 0 ? 0.0 : e.rate / maxRate,
                      fillColor: heroRarityColor(e.rarity),
                      trackColor: AppColors.glassCard,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(e.rate * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            l10n.tr('gacha_rates_note'),
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// **천상(피티) 바** — 연속 중복 횟수를 노출한다 (요구사항 9).
///
/// ★1 단일이라 "등급 천상"은 무의미하므로 **신규 등장 보장**으로 정의한다.
/// - 중복이면 카운터 +1, 신규가 나오면 0으로 리셋.
/// - [RuneProgress.heroPityThreshold] 회 이상이면 **다음 1연은 미보유 확정**.
///
/// 발동 직전부터 막짚이 켜지고 숫자가 커지도록 만들어 "곧 나온다"는
/// 기대감(도파민)을 만든다. 10연에는 적용되지 않는다.
class _PityBar extends StatelessWidget {
  const _PityBar({required this.progress});

  final RuneProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final count = progress.heroPityCount;
    final max = RuneProgress.heroPityThreshold;
    final ready = progress.pityReady;
    final ratio = (count / max).clamp(0.0, 1.0);
    // 발동 3회 전부터 경고색으로 넘어간다.
    final remaining = max - count;
    final accent = ready
        ? AppColors.green
        : remaining <= 3
        ? AppColors.accentOrange
        : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 왼쪽 문구는 영어가 길다("New hero guaranteed in N more single pull(s)").
        // `Spacer` 만으로는 Row 가 넘칠 수 있어 `Expanded` 로 감싸 2줄까지 허용한다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                ready
                    ? l10n.tr('gacha_pity_ready')
                    : l10n.trp('gacha_pity_progress', {'n': remaining}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.trp('gacha_pity_counter', {'count': count, 'max': max}),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 10칸 막대 — 연속 중복이 쌓일수록 하나씩 채워진다.
        Row(
          children: [
            for (var i = 0; i < max; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                // 세그먼트는 값이 0 또는 1 이다. `UiBar` 의 기본 260ms 가 옛
                // AnimatedContainer 와 같은 애니메이션을 그대로 준다.
                child: UiBar(
                  value: i < count ? 1.0 : 0.0,
                  fillColor: accent,
                  trackColor: AppColors.glassCard,
                  // 다음 세그먼트(지금 뽑을 1회)만 강조 테두리를 갖는다.
                  borderColor: i == count && !ready
                      ? accent.withValues(alpha: 0.6)
                      : AppColors.glassBorder,
                  height: 7,
                ),
              ),
            ],
          ],
        ),
        if (!ready) ...[
          const SizedBox(height: 3),
          Text(
            l10n.tr('gacha_pity_note'),
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
        // 진행률도 함께 보여준다 (색 + 길이 이중 인코딩).
        const SizedBox(height: 3),
        UiBar(
          value: ratio,
          fillColor: accent,
          trackColor: AppColors.glassCard,
          height: 3,
        ),
      ],
    );
  }
}

/// 뽑기 버튼 1개 (비용 + 레이블). 잔액 부족 시 비활성.
class _PullButton extends StatelessWidget {
  const _PullButton({
    required this.buttonKey,
    required this.label,
    required this.cost,
    required this.enabled,
    required this.onPressed,
    this.highlight = false,
  });

  final Key buttonKey;
  final String label;
  final int cost;
  final bool enabled;
  final VoidCallback onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      // 채움색은 스프라이트 뒤 `background`, 테두리는 스프라이트의 `color`(srcIn
      // 틴트)로. 원래 `Material` 의 배경을 쓰던 자리를 `Material(transparency)`
      // 로 바꿔 잉크 스플래시만 남긴다 — 조상 Material 이 없으면 리플이 아예
      // 안 그려진다.
      child: UiFrame.round12(
        // 부모 `Column(mainAxisSize: min)` 안이라 세로가 무한대다.
        fit: StackFit.loose,
        background: highlight
            ? AppColors.accent.withValues(alpha: 0.18)
            : AppColors.glassCard,
        color: highlight ? AppColors.accent : AppColors.glassBorder,
        insets: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Material(
          color: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: InkWell(
            key: buttonKey,
            onTap: enabled ? onPressed : null,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.trp('gacha_cost', {'n': cost}),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
