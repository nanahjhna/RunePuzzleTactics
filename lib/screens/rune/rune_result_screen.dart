/// Rune Puzzle Tactics — 배틀 결과 화면 (전체 화면, RPT-408 ~ RPT-410)
///
/// 승리/패배 결과와 획득 Game Currency, 현재 파티/시너지/파티 공격력을 보여주고
/// 다음 스테이지 / 재도전 / 로비 이동을 제공한다 (프롬프트 §37~38).
///
/// 사양 2-3 Result Flow 에 맞춰 버튼 구성을 통일했다:
/// - 승리: [로비로 이동] + [다음 스테이지 ▶]
/// - 패배: [로비로 이동] + [재도전 (Play 1)]
/// 기존 [상점으로] 버튼은 두 화면에서 제거했다 — 성장/충전은 로비의 상점 탭과
/// 재화 부족 다이얼로그(광고 보기)에서 처리한다.
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter/material.dart';

import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/play_shortage_dialog.dart';
import '../../widgets/rewarded_ad_helper.dart';

/// 결과 화면. 버튼은 각각 'next' / 'retry' / 'shop' / 'lobby' 문자열을 pop한다.
/// - 요구사항 6.3: [다음]/[재도전]은 pop 전 Play 재화를 사전 검증하고,
///   부족하면 이 결과 화면 위에서 재화 부족(광고/상점) 다이얼로그를 즉시 띄운다.
/// - 요구사항 6.4: [로비로 이동]은 연쇄 pop 깜빡임을 막기 위해 popUntil로
///   결과/배틀 라우트를 한 번에 정리해 메인 허브를 바로 드러낸다.
///   (사양 2-3으로 [상점으로] 버튼은 제거되었으나, 재화 부족 다이얼로그의
///   '상점' 선택은 [_exitToHub] 의 'shop' 경로를 계속 사용한다.)
class RuneResultScreen extends StatelessWidget {
  const RuneResultScreen({
    super.key,
    required this.win,
    required this.stageNumber,
    required this.gameReward,
    required this.party,
    required this.baseAttack,
    this.damageSummary,
    this.heroStats,
    this.levelUps = const [],
    this.playCurrency,
    this.onRewardAdPlay,
    this.onShopRequested,
  });

  final bool win;
  final int stageNumber;
  final int gameReward;
  final HeroRoster party;

  /// 업그레이드가 반영된 파티 공격력 (RPT-397).
  final int baseAttack;
  final BattleDamageSummary? damageSummary;

  /// 편성 영웅 **개별** 최종 스탯 (합산 아님). 카드가 각자 값을 보여준다.
  final List<HeroCombatStats>? heroStats;

  /// 이번 전투에서 오른 레벨 목록 (승리 EXP). 비어 있으면 레벨업 카드를 숨긴다.
  final List<HeroLevelUp> levelUps;

  /// 결과 시점의 현재 Play 잔액 (입장 비용 소모 후 기준, 요구사항 6.3).
  /// null이면(저장소 없는 직접 진입/테스트) 사전 검증을 생략한다.
  final int? playCurrency;

  /// 재화 부족 다이얼로그 [보상형 광고 보기]에서 Play를 충전한다 (요구사항 6.3).
  final bool Function()? onRewardAdPlay;

  /// [상점으로] 선택 시 popUntil 이후 메인 허브의 Shop 탭 전환을 위한
  /// 콜백(라우터 플래그, 요구사항 6.4). null이면 예전처럼 값 전달 pop으로 폴백.
  final VoidCallback? onShopRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final combat = damageSummary ?? BattleDamageSummary(const []);
    // 속성별 공격력 합 = 그 색 매칭 데미지의 밑 ([BattleState.attackForElement]).
    // 예전 시너지 배율(x0.8 등)을 대체한다 — 배율표 대신 **합계 자체**를 보여줘야
    // 플레이어가 "몇 명이나 넣었는지"와 "데미지가 왜 나오는지"를 바로 잇는다.
    final atkByElement = <RuneElement, int>{};
    if (heroStats case final list?) {
      for (final s in list) {
        atkByElement.update(
          s.element,
          (v) => v + s.attack,
          ifAbsent: () => s.attack,
        );
      }
    }
    // 요구사항 1.2 + 6.4: 결과 오버레이에서 Android 뒤로가기 시 '로비로'와 동일하게
    // popUntil로 결과/배틀 라우트를 한 번에 정리해 메인 허브로 복귀시킨다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitToHub(context, 'lobby');
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E2130), AppColors.bgMain, Color(0xFF0B0C12)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          // 승/패 타이틀: 네온 그라데이션 텍스트 (규칙 1)
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: win
                                  ? [
                                      const Color(0xFFFFD97A),
                                      AppColors.accentGold,
                                      AppColors.ctaGradStart,
                                    ]
                                  : [AppColors.danger, const Color(0xFFB71C1C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              win
                                  ? l10n.tr('result_victory')
                                  : l10n.tr('result_defeat'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: AppColors.glowNeon,
                                    blurRadius: 18,
                                  ),
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            win
                                ? l10n.trp('result_clear', {'n': stageNumber})
                                : l10n.trp('result_defeated', {
                                    'n': stageNumber,
                                  }),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Game Currency 보상 카드 (글래스)
                          GlassSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            art: const CardArt.fill(kCardArtResultReward),
                            child: Row(
                              children: [
                                const Text('⚡', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    win
                                        ? l10n.tr('result_game_win')
                                        : l10n.tr('result_game_loss'),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  win ? '+$gameReward' : '0',
                                  style: TextStyle(
                                    color: win
                                        ? AppColors.accent
                                        : Colors.white54,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 레벨 업 카드 (승리 EXP 로 오른 영웅) — 없으면 숨긴다.
                          if (levelUps.isNotEmpty) ...[
                            _LevelUpCard(levelUps: levelUps),
                            const SizedBox(height: 14),
                          ],

                          // 파티 요약 카드 (글래스, 프롬프트 §38: Current Party / Synergy / Party Attack)
                          GlassSurface(
                            padding: const EdgeInsets.all(14),
                            art: const CardArt.fill(kCardArtResultParty),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      l10n.tr('party_summary'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      l10n.trp('result_attack', {
                                        'n': baseAttack,
                                      }),
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (final e in RuneElement.normal)
                                  if (party.partyCount(e) > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 3,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            e.emoji,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              l10n.tr('element_${e.name}'),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'N=${party.partyCount(e)}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'ATK ${atkByElement[e] ?? 0}',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DamageAnalysisCard(summary: combat),
                          if (heroStats case final list?
                              when list.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _HeroStatsCard(stats: list),
                          ],
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  // 액션 버튼 (사양 2-3: 승리 [로비로 이동]/[다음 스테이지],
                  // 패배 [로비로 이동]/[재도전 (Play 1)] — [상점으로] 버튼은 두 화면
                  // 모두에서 제거. 성장·충전은 로비의 상점 탭/광고 칩에서 처리한다).
                  OutlinedButton.icon(
                    key: const ValueKey('result-lobby'),
                    onPressed: () => _exitToHub(context, 'lobby'),
                    icon: const Icon(Icons.home),
                    label: Text(l10n.tr('result_btn_lobby')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (win)
                    // 규칙 1: Primary CTA — 네온 그라데이션 (다음 스테이지)
                    GradientButton(
                      key: const ValueKey('result-next'),
                      onPressed: () => _handleEntry(context, 'next'),
                      icon: Icons.arrow_forward,
                      label: l10n.tr('result_btn_next'),
                      fontSize: 16,
                    )
                  else
                    // 규칙 1: Primary CTA — 네온 그라데이션 (재도전, Play 1 소모)
                    GradientButton(
                      key: const ValueKey('result-retry'),
                      onPressed: () => _handleEntry(context, 'retry'),
                      icon: Icons.replay,
                      label: l10n.trp('result_btn_retry', {
                        'n': RuneMeta.stageEntryCost,
                      }),
                      fontSize: 16,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 요구사항 6.3: [다음 스테이지]/[다시 도전] — pop 전 Play 재화를 사전 검증한다.
  ///
  /// 결과 화면 시점에 Play 잔액이 입장 비용보다 적으면 결과 화면 위에서 즉시
  /// 재화 부족(보상형 광고/상점) 다이얼로그를 띄운다. 광고 시청으로 충전되면
  /// 원래 동작(다음/재도전) 그대로 pop하여 배틀 화면이 재진입을 처리하게 한다.
  Future<void> _handleEntry(BuildContext context, String action) async {
    final cost = RuneMeta.stageEntryCost;
    if (playCurrency == null || playCurrency! >= cost) {
      Navigator.pop(context, action);
      return;
    }
    final choice = await showPlayShortageDialog(context);
    if (!context.mounted) return;
    switch (choice) {
      case 'ad':
        // 요구사항 6.3: [보상형 광고 보기] → 실제 광고를 재생한 뒤 지급한다.
        // (배틀 화면 _showPlayShortageMenu와 동일 패턴)
        final rewarded = await showRewardedAdOnce();
        if (!context.mounted) return;
        if (!rewarded) {
          _showAdFailedSnackBar(context);
          return; // 결과 화면 유지 (충전 실패)
        }
        final granted = onRewardAdPlay?.call() ?? false;
        if (!granted) {
          _showAdFailedSnackBar(context);
          return;
        }
        Navigator.pop(context, action);
      case 'shop':
        _exitToHub(context, 'shop');
      default:
        // 취소 → 결과 화면 유지.
        break;
    }
  }

  /// 요구사항 6.4: [로비로]/[상점으로] — 연쇄 pop 화면 깜빡임 방지.
  ///
  /// 결과 → 배틀 순서로 두 번 pop하면 중간에 배틀 화면(승/패 연출 오버레이)이
  /// 잠깐 비치므로, popUntil로 결과/배틀 라우트를 한 번에 정리해 메인 허브를
  /// 바로 드러낸다. '상점으로'는 라우트 값 대신 [onShopRequested] 콜백(플래그)으로
  /// 허브에 전달하며, 콜백이 없으면(직접 진입/테스트) 예전처럼 값 전달 pop으로
  /// 폴백해 배틀 화면이 pop('shop')을 이어서 처리한다.
  void _exitToHub(BuildContext context, String destination) {
    final nav = Navigator.of(context);

    if (destination == 'shop' && onShopRequested != null) {
      onShopRequested!();
    }

    // 강제 popUntil 대신 결과 문자열('lobby' 또는 'shop')을 pop하여
    // 호출한 배틀 화면으로 안전하게 전달합니다.
    if (nav.canPop()) {
      nav.pop(destination);
    }
  }

  /// 광고 로드/시청 실패 안내 (요구사항 3.2).
  void _showAdFailedSnackBar(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('ad_load_failed'))));
  }
}

class _DamageAnalysisCard extends StatelessWidget {
  const _DamageAnalysisCard({required this.summary});

  final BattleDamageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final largest = summary.largestOutgoingHit;
    final elements = <RuneElement, ({int damage, int count})>{};
    for (final record in summary.records) {
      final element = record.element;
      if (record.isIncoming || element == null) continue;
      final old = elements[element] ?? (damage: 0, count: 0);
      elements[element] = (
        damage: old.damage + record.damage,
        count: old.count + 1,
      );
    }

    return GlassSurface(
      padding: const EdgeInsets.all(14),
      art: const CardArt.fill(kCardArtResultDamage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tr('result_damage_analysis'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _DamageTotalRow(
            label: l10n.tr('result_damage_dealt'),
            value: summary.totalDamageDealt,
            color: AppColors.accent,
          ),
          _DamageTotalRow(
            label: l10n.tr('result_damage_received'),
            value: summary.totalDamageReceived,
            color: AppColors.danger,
          ),
          if (largest != null)
            _DamageTotalRow(
              label: l10n.tr('result_largest_hit'),
              value: largest.damage,
              color: Colors.white,
            ),
          const SizedBox(height: 6),
          Text(
            l10n.tr('result_damage_sources'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final source in BattleDamageSource.values)
            if (summary.countFor(source) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tr('damage_source_${source.name}'),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${summary.countFor(source)} ×  '
                      '${summary.damageFor(source)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          for (final element in RuneElement.values)
            if (elements[element] case final row?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(element.emoji),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.tr('element_${element.name}'),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${row.count} ×  ${row.damage}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          if (summary.incomingRecords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.tr('result_incoming_breakdowns'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            for (var i = 0; i < summary.incomingRecords.length; i++)
              _IncomingDamageRow(
                index: i + 1,
                record: summary.incomingRecords[i],
              ),
          ],
        ],
      ),
    );
  }
}

class _DamageTotalRow extends StatelessWidget {
  const _DamageTotalRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _IncomingDamageRow extends StatelessWidget {
  const _IncomingDamageRow({required this.index, required this.record});

  final int index;
  final BattleDamageRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final formula = record.incoming;
    final details = formula == null
        ? '${l10n.tr('damage_source_${record.source.name}')}: '
              '-${record.damage} (${record.hpBefore ?? 0} → '
              '${record.hpAfter ?? 0})'
        : l10n.trp('incoming_damage_formula', {
            'atk': formula.attack,
            'def': formula.defense,
            'damage': record.damage,
            'hpBefore': record.hpBefore ?? 0,
            'hpAfter': record.hpAfter ?? 0,
            'hpMax': record.hpMax ?? 0,
          });
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$index. $details',
        style: const TextStyle(color: Colors.white60, fontSize: 10),
      ),
    );
  }
}

class _HeroStatsCard extends StatelessWidget {
  const _HeroStatsCard({required this.stats});

  /// 편성 영웅 **개별** 최종 스탯. 합계가 아니라 각자 값을 보여준다.
  final List<HeroCombatStats> stats;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return GlassSurface(
      padding: const EdgeInsets.all(14),
      art: const CardArt.fill(kCardArtResultStats),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tr('result_party_stat_breakdown'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in stats) ...[
            Text(
              l10n.tr('hero_name_${s.heroId}'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${l10n.tr('stat_hp')} ${s.hp}  '
                '${l10n.tr('stat_atk')} ${s.attack}  '
                '${l10n.tr('stat_def')} ${s.defense}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            l10n.tr('result_stat_breakdown_legend'),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
