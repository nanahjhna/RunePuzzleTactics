/// Rune Puzzle Tactics — 로비 탭 (사양 1-1 Layout & Global Structure, Portrait)
///
/// 사양 대응:
///  - Top Bar(Currency Header): 재화 3종(Gold/Play/Token) 실시간 표시.
///    일일 보상 칩은 Game 재화 칩 바로 왼쪽에 배치한다.
///  - Stage Card (요구사항 1): 스테이지 선택기(◀ ▶)는 **삭제** — 항상 최신
///    진입 가능 스테이지(`min(highestCleared + 1, RuneMeta.maxStage)`)를
///    겨냥하고, 마지막 플레이 기록(승/패)은 같은 카드 안의 보조 행으로 함께
///    보여준다. 전적(승/패/클리어) 표는 **노출하지 않는다** — 데이터는 계속
///    기록된다.
///  - `[전투 시작 (STAGE N)]` 메인 CTA → Stage Preparation Modal 호출.
///  - 일일 보상 칩은 체크 표시 없이 **항상 선물 아이콘 + 「수령」** 문구다.
///  - Current Party Summary: 1x4 Portrait Grid + `+` (빈 자리 → 영웅 그리드).
///  - 시너지 요약 한 줄은 유지하��다.
///  - ✂️ 영웅 스탯 카드 / 영구 업그레이드 버튼은 **삭제** (요구사항 3).
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flutter/material.dart';

import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/party_editor.dart';
import '../../widgets/party_slots.dart';
import '../../widgets/rewarded_ad_helper.dart';
import '../../widgets/ui_pill.dart';
import 'hero_detail_dialog.dart';

/// Lobby 탭 (메인 허브 탭 0).
class RuneLobbyTab extends StatefulWidget {
  const RuneLobbyTab({
    super.key,
    required this.progress,
    required this.onStartBattle,
    required this.onChanged,
    this.analytics,
  });

  final RuneProgress progress;

  /// 전투 진입. **선택된 스테이지 번호**를 전달한다 (Stage Selector).
  final ValueChanged<int> onStartBattle;

  /// 일일 보상/광고 보상 수령 후 진행도 전달 (상태 갱신 + 저장).
  final ValueChanged<RuneProgress> onChanged;

  final RuneAnalytics? analytics;

  @override
  State<RuneLobbyTab> createState() => _RuneLobbyTabState();
}

class _RuneLobbyTabState extends State<RuneLobbyTab> {
  RuneProgress get progress => widget.progress;

  /// 일일 보상/광고 보상 수령 후 진행도 전달 (상태 갱신 + 저장).
  ValueChanged<RuneProgress> get onChanged => widget.onChanged;

  RuneAnalytics? get analytics => widget.analytics;

  /// 로비가 겨냥하는 스테이지 = **진행도상 최신 진입 가능 스테이지**.
  ///
  /// 스테이지 선택기(◀ ▶)를 폐기했으므로 고를 수 있는 값이 없다 — 항상
  /// "여기까지 깬 다음 한 판"으로 직행시킨다.
  int get _stage => progress.selectableMaxStage;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final l10n = LanguageScope.of(context).strings;
    final now = DateTime.now();

    // 1. Play 재화: 잔액이 0일 때만 광고 충전 가능
    final canAdPlay = p.playCurrency == 0;

    // 2. Hero 재화: 하루 1회만 광고 충전 가능 (00시 자정 리셋)
    final canAdHero = p.canClaimHeroAd(now);

    // 3. 일일 보상 수령 가능 여부
    final isDailyAvailable = p.dailyRewardAvailable(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Top Bar (Currency Header) ──
        // 재화 3종을 노출하고 일일 보상 칩은 Game 재화 칩 바로 왼쪽에 둔다.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // 우측 정렬 유지
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DailyRewardChip(
                      isAvailable: isDailyAvailable,
                      onTap: () => _showDailyRewardDialog(context, p),
                    ),
                    const SizedBox(width: 8),
                    // Game 재화 (광고 충전 없음)
                    _CurrencyAdChip(
                      label: l10n.trp('currency_game', {'n': p.gameCurrency}),
                      showAddIcon: false,
                      isEnabled: true,
                      onTap: null,
                    ),
                    const SizedBox(width: 8),
                    // Play 재화 (0개일 때만 + 활성화)
                    _CurrencyAdChip(
                      label: l10n.trp('currency_play', {'n': p.playCurrency}),
                      showAddIcon: true,
                      isEnabled: canAdPlay,
                      onTap: () {
                        if (canAdPlay) {
                          _showAdConfirmation(
                            context,
                            type: CurrencyType.play,
                            amount: RuneMeta.rewardedAdPlay,
                          );
                        } else {
                          // 재화 보유 중: 광고 없이 무음 처리하지 않고 안내한다.
                          _showAlreadyAdSnackBar(context, CurrencyType.play);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Hero 재화 (하루 1회만 가능, 00시 리셋)
                    _CurrencyAdChip(
                      label: l10n.trp('currency_hero', {'n': p.heroCurrency}),
                      showAddIcon: true,
                      isEnabled: canAdHero,
                      onTap: () {
                        if (canAdHero) {
                          _showAdConfirmation(
                            context,
                            type: CurrencyType.hero,
                            amount: RuneMeta.rewardedAdHero,
                          );
                        } else {
                          // 오늘 이미 시청: 내일 다시 안내.
                          _showAlreadyAdSnackBar(context, CurrencyType.hero);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── 통합 스테이지 카드 (요구사항 1) ──
        // 스테이지 선택기(◀ ▶)를 없애고 **최신 진입 가능 스테이지**로 고정한다.
        // 마지막 플레이 기록은 이 카드 안에 함께 표시한다(별도 카드 없음).
        _StageCard(
          stage: _stage,
          previousStage: p.highestCleared,
          highestCleared: p.highestCleared,
          maxStage: RuneMeta.maxStage,
          lastPlayedStage: p.lastPlayedStage,
          lastVictory: p.lastStageVictory ?? false,
          showMaxBanner: p.isMaxStageReached,
          maxBanner: l10n.tr('lobby_max_stage_banner'),
          startLabel: l10n.trp('lobby_battle_start', {'n': _stage}),
          lastPlayedLabel: l10n.tr('lobby_last_played'),
          winLabel: l10n.tr('lobby_last_result_win'),
          loseLabel: l10n.tr('lobby_last_result_lose'),
          onStart: widget.onStartBattle,
        ),
        const SizedBox(height: 14),

        // ── Current Party Summary (1x4 Portrait Grid) ──
        _SectionLabel(label: l10n.tr('lobby_current_party')),
        const SizedBox(height: 8),
        GlassSurface(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          blur: 0,
          art: const CardArt.fill(kCardArtLobbyParty),
          // 공통 파티 슬롯 — 빈 자리는 `+` (파티 탭 / 전투 준비와 같은 위젯).
          // `+` 를 누르면 6열 영웅 그리드 → 합류 확인 (요구사항 2).
          child: PartySlots(
            progress: p,
            onChanged: onChanged,
            onHeroTap: (ctx, hero) => showHeroDetailDialog(
              ctx,
              hero: hero,
              progress: p,
              onChanged: onChanged,
              analytics: analytics,
            ),
            onHeroLongPress: (ctx, hero) => showUnassignHeroDialog(
              ctx,
              hero: hero,
              progress: p,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 속성 집계 한 줄. 배율은 붙이지 않는다 — 같은 속성의 공격력 합이 곧
        // 그 색 매칭 데미지의 밑이라 인원수만 알려주면 충분하다.
        Text(
          partyElementLine(l10n, p),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 일일 보상 수령 안내 팝업
  void _showDailyRewardDialog(BuildContext context, RuneProgress p) {
    final l10n = LanguageScope.of(context).strings;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark2,
        title: Text(
          l10n.tr('daily_reward_title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.trp('daily_reward_desc', {
            'play': RuneMeta.dailyRewardPlay,
            'hero': RuneMeta.dailyRewardHero,
          }),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('common_cancel')),
          ),
          // 선물 아이콘을 붙여 "보상 수령" 이라는 성격을 글자로만 알리지 않는다.
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _claimDaily(p);
            },
            icon: const Icon(Icons.card_giftcard, size: 18),
            label: Text(l10n.tr('daily_reward_claim')),
          ),
        ],
      ),
    );
  }

  /// 광고 시청 확인 안내 팝업
  void _showAdConfirmation(
    BuildContext context, {
    required CurrencyType type,
    required int amount,
  }) {
    final l10n = LanguageScope.of(context).strings;
    final currencyName = l10n.tr('currency_${type.name}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark2,
        title: Text(
          l10n.trp('ad_reward_${type.name}', {'n': amount}),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '$currencyName $amount개를 받으시겠습니까?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _claimAdWithAd(context, type, amount);
            },
            child: Text(l10n.tr('common_confirm')),
          ),
        ],
      ),
    );
  }

  void _claimDaily(RuneProgress p) {
    final r = p.claimDailyReward(now: DateTime.now());
    if (!r.ok) return;
    analytics?.logDailyReward(
      play: RuneMeta.dailyRewardPlay,
      hero: RuneMeta.dailyRewardHero,
    );
    onChanged(r.progress);
  }

  /// 로비 재화 칩의 보상형 광고 → 보상 수령 흐름 (요구사항 3.1/3.2).
  ///
  /// [showRewardedAdOnce]로 실제 광고를 재생하고, 보상 승인 시에만 지급한다.
  /// 로드/표시 실패 또는 보상 없이 닫으면 지급하지 않고 실패 안내 스낵바를 띄운다.
  /// - Hero: 일일 1회 제한 키([RuneProgress.heroAdTxId]) 사용.
  /// - Play: 타임스탬프 멱등 키 사용 (중복 콜백은 원장이 차단).
  Future<void> _claimAdWithAd(
    BuildContext context,
    CurrencyType type,
    int amount,
  ) async {
    final now = DateTime.now();
    final txId = type == CurrencyType.hero
        ? RuneProgress.heroAdTxId(now)
        : 'ad_${type.name}_${now.millisecondsSinceEpoch}';
    final rewarded = await showRewardedAdOnce(
      onReward: () {
        // 보상 승인 시 1회 지급. 같은 id 트랜잭션은 원장이 멱등으로 차단하므로
        // 중복 콜백에도 안전하다.
        final r = progress.claimRewardedAd(
          txId: txId,
          type: type,
          amount: amount,
        );
        if (!r.applied) return;
        analytics?.logRewardedAd(type: type, amount: amount);
        onChanged(r.progress);
      },
    );
    if (!context.mounted) return;
    if (rewarded) {
      _showAdRewardSnackBar(context, amount);
    } else {
      _showAdFailedSnackBar(context);
    }
  }

  /// 보상형 광고 지급 성공 안내.
  void _showAdRewardSnackBar(BuildContext context, int amount) {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.trp('ad_reward_granted', {'n': amount}))),
      );
  }

  /// 비활성 광고 칩(재화 보유/일일 제한) 탭 시 안내 — "아무 반응 없음" 방지.
  void _showAlreadyAdSnackBar(BuildContext context, CurrencyType type) {
    final l10n = LanguageScope.of(context).strings;
    final msg = type == CurrencyType.play
        ? l10n.tr('ad_play_owned')
        : l10n.tr('ad_hero_daily_done');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 광고 로드/시청 실패 안내 (요구사항 3.2).
  void _showAdFailedSnackBar(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('ad_load_failed'))));
  }
}

/// 🎁 상단 일일 보상 칩
///
/// 체크(✔) 상태 아이콘은 **쓰지 않는다** — 남았는지/이미 받았는지와 무관하게
/// 항상 선물 아이콘 + 「수령」 문구를 보여준다. 수령 가능 여부는 색/투명도로만
/// 구분한다(선물 아이콘·텍스트 점등 vs 비점등).
class _DailyRewardChip extends StatelessWidget {
  const _DailyRewardChip({required this.isAvailable, required this.onTap});

  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final color = isAvailable ? AppColors.accent : Colors.white38;

    return Opacity(
      key: const ValueKey('daily-reward-chip'),
      opacity: isAvailable ? 1.0 : 0.45,
      child: UiPill(
        size: UiPillSize.large,
        borderColor: isAvailable
            ? AppColors.accent.withValues(alpha: 0.72)
            : AppColors.glassBorder,
        background: isAvailable
            ? AppColors.accent.withValues(alpha: 0.2)
            : AppColors.glassCardStrong,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isAvailable ? onTap : null,
            borderRadius: appPillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard, color: color, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    l10n.tr('daily_reward_claim'),
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 통합 재화 칩 (잔액 표시 + 광고 충전 버튼)
class _CurrencyAdChip extends StatelessWidget {
  const _CurrencyAdChip({
    required this.label,
    required this.onTap,
    this.showAddIcon = true,
    this.isEnabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool showAddIcon;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final active = isEnabled && onTap != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: UiPill(
        size: UiPillSize.large,
        borderColor: active
            ? AppColors.accent.withValues(alpha: 0.72)
            : AppColors.glassBorder,
        background: AppColors.glassCardStrong,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // 비활성(재화 보유/일일 제한)일 때도 탭하면 안내 스낵바가 나오도록
            // onTap은 항상 전달한다. opacity/아이콘으로 비활성 시각만 유지.
            onTap: onTap,
            borderRadius: appPillRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showAddIcon) ...[
                    const SizedBox(width: 4),
                    Icon(
                      active ? Icons.add_circle : Icons.check_circle_outline,
                      color: active ? AppColors.accent : Colors.white38,
                      size: 15,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 섹션 라벨 (사양 1-1 카드 상단 제목).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// **통합 스테이지 카드** (요구사항 1).
///
/// 이전에는 (a) `[◀ STAGE N ▶]` 스테이지 선택기와 (b) 「계속하기」 마지막 플레이
/// 카드가 **별개 카드 두 개**였다. 선택기는 되돌아갈 스테이지를 고르게 하고
/// 카드는 직전 판을 재도전하게 만들어 "어디로 가야 하지"를 두 번 판단하게 했다.
///
/// 이제는 하나다:
///  - 목표는 **항상 최신 진입 가능 스테이지**([stage])로 고정(선택 UI 없음).
///  - **이전 스테이지**([previousStage])를 카드 상단에 함께 보여준다 —
///    "어디까지 왔는지"를 한눈에 읽히게 한다.
///  - "여기까지 했더라"는 마지막 플레이 기록을 카드 안의 보조 행으로 함께 보여준다.
///    기록이 없으면 그 행 자체를 숨긴다.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.previousStage,
    required this.highestCleared,
    required this.maxStage,
    required this.lastPlayedStage,
    required this.lastVictory,
    required this.showMaxBanner,
    required this.maxBanner,
    required this.startLabel,
    required this.lastPlayedLabel,
    required this.winLabel,
    required this.loseLabel,
    required this.onStart,
  });

  /// 최신 진입 가능 스테이지 (= `RuneProgress.selectableMaxStage`).
  final int stage;

  /// 이전 스테이지 (= `RuneProgress.highestCleared`). 0이면 아직 클리어 없음.
  final int previousStage;

  /// 실제 최고 클리어 스테이지 ([RuneProgress.highestCleared]).
  final int highestCleared;

  /// 절대 상한 ([RuneMeta.maxStage]).
  final int maxStage;

  /// 마지막으로 플레이한 스테이지. null 이면 기록이 없다(행 숨김).
  final int? lastPlayedStage;

  /// 마지막 전투 승패. 기록이 있을 때만 쓰인다.
  final bool lastVictory;

  final bool showMaxBanner;
  final String maxBanner;

  /// 「전투 시작 (STAGE N)」 CTA 라벨.
  final String startLabel;

  final String lastPlayedLabel;
  final String winLabel;
  final String loseLabel;

  /// CTA 탭 — 항상 [stage] 로 진입한다(직전 판 스테이지로 되돌아가지 않는다).
  ///
  /// [previousStage] 버튼은 별도로 처리하므로 이 콜백은 현재 스테이지 전용.
  final ValueChanged<int> onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final accent = lastVictory ? AppColors.green : AppColors.danger;

    return GlassSurface(
      padding: const EdgeInsets.all(16),
      blur: 0,
      art: const CardArt.fill(kCardArtLobbyStage),
      child: Column(
        children: [
          // 이전 스테이지 — "어디까지 왔는지"를 현재 스테이지 바로 위에 표시.
          // 0이면 아직 클리어 없음이므로 숨긴다.
          if (previousStage > 0) ...[
            Text(
              l10n.trp('lobby_previous_stage', {'n': previousStage}),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 2),
          ],
          // 목표 스테이지 — 선택 불가. 최신 진행 스테이지로 고정.
          Text(
            l10n.trp('common_stage', {'n': stage}),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            l10n.trp('lobby_stage_progress', {
              'cleared': '$highestCleared / $maxStage',
            }),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),

          // 마지막 플레이 기록 — 같은 카드 안의 보조 행. 기록 없으면 숨긴다.
          if (lastPlayedStage case final played?) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lastPlayedLabel,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.trp('common_stage', {'n': played}),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                // 승패는 색으로도 구분된다(색맹 배려).
                Text(
                  lastVictory ? winLabel : loseLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],

          if (showMaxBanner) ...[
            const SizedBox(height: 8),
            Text(
              maxBanner,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              // 이전 스테이지 버튼 — 현재 스테이지 바로 아래 단계로 재도전.
              // previousStage > 0 일 때만 표시 (첫 클리어 전에는 숨김).
              // 전투 시작 버튼과 동일한 스타일/크기로 통일.
              if (previousStage > 0) ...[
                Expanded(
                  child: GradientButton(
                    key: const ValueKey('previous-stage'),
                    onPressed: () => onStart(previousStage),
                    label: l10n.trp('common_stage', {'n': previousStage}),
                    fontSize: 14,
                    height: 52,
                    glow: false,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 규칙 1: Primary CTA — 네온 그라데이션 + Outer Glow
              Expanded(
                child: GradientButton(
                  key: const ValueKey('start-battle'),
                  onPressed: () => onStart(stage),
                  icon: Icons.play_arrow,
                  label: startLabel,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
