/// Rune Puzzle Tactics — Stage Preparation Center Modal (사양 1-2)
///
/// Reference: 모바일 수집형 RPG 출격 준비 화면 — **다크 카드 중앙 모달 + 반투명
/// Background Dimmer**.
///
/// 구조(사양 ASCII 대응):
/// ```text
/// ┌──────────────────────────────────────────────┐
/// │ [X]              STAGE 12              [i]   │  닫기 / 정보
/// │           "오래된 유물과 함께 봉인된 수호자"   │  서브 타이틀
/// │  MY ENTRY PARTY (1x5 Portrait Slots)         │
/// │  [🔥A][🔥B][💧C][+][+]                        │  빈 자리는 `+` (편성 진입점)
/// │   Fire x3 (1.2x) | Water x1 (0.8x)           │  속성 시너지 (유일한 속성 축)
/// │  🔥 영웅#1  HP 100  ATK 15  DEF 8             │  영웅 **개인** 스탯 (합계 칩 없음)
/// │  입장 재화: [⚡ Play 1 / 보유: 5]             │
/// │                 [  전투 출격  ]               │
/// └──────────────────────────────────────────────┘
/// ```
///
/// **상성**: 몬스터는 무속성이지만 상성은 있다 — 파도 전투에서는 **몬스터마다**
/// 약점/열세 속성을 갖는다([WaveMonster.affinityFor]). [_MonsterWaveView] 가
/// 마리별로, 단일 몬스터면 [_MonsterAffinityRow] 한 줄로 출격 전에 공개한다.
/// 속성 집계([partyElementLine])는 배율 없이 인원수만 보여준다.
///
/// **파티 인라인 편집**: 1x5 슬롯은 공통 [PartySlots] 이고, 빈 자리의 `+` 로
/// 이 다이얼로그 안에서 바로 영웅을 넣을 수 있다. 예전의 "파티 수정하기" 버튼으로
/// 다른 탭에 튕기던 경로와 `StagePrepOutcome.editParty` 는 사라졌다.
///
/// 기존 계약 유지: `ValueKey('stage-prep-dialog')`,
/// `ValueKey('stage-prep-confirm')`.
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/party_editor.dart';
import '../../widgets/party_slots.dart';
import '../../widgets/ui_frame.dart';
import '../../widgets/ui_pill.dart';
import 'hero_detail_dialog.dart';

/// 전투 준비 모달의 사용자 선택.
enum StagePrepOutcome {
  /// 닫기(X)/바깥 탭 — 재화 미소모.
  cancel,

  /// [전투 출격] — Play 입장 비용 소모 후 Battle Screen 진입.
  confirm,
}

/// Stage Preparation Center Modal. 중앙 정렬 다크 카드 + 딤머.
///
/// [progress] / [onChanged] 로 파티 인라인 편집을 지원한다 — 다이얼로그 안에서
/// 편성/해제한 결과가 즉시 이 그리드에 반영된다.
Future<StagePrepOutcome> showStagePrepDialog(
  BuildContext context, {
  required int stageNumber,
  required RuneProgress progress,
  required ValueChanged<RuneProgress> onChanged,
  required StageConfig stageConfig,
  required int entryCost,
  int? playCurrency,
}) async {
  final outcome = await showDialog<StagePrepOutcome>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    barrierDismissible: true,
    builder: (ctx) => _StagePrepCard(
      key: const ValueKey('stage-prep-dialog'),
      stageNumber: stageNumber,
      progress: progress,
      onChanged: onChanged,
      stageConfig: stageConfig,
      entryCost: entryCost,
      playCurrency: playCurrency,
    ),
  );
  return outcome ?? StagePrepOutcome.cancel;
}

/// 중앙 모달 카드 본체.
///
/// Statefully 만들어 [PartySlots] 안에서 일어난 편성/해제를 즉시 반영한다.
class _StagePrepCard extends StatefulWidget {
  const _StagePrepCard({
    super.key,
    required this.stageNumber,
    required this.progress,
    required this.onChanged,
    required this.stageConfig,
    required this.entryCost,
    this.playCurrency,
  });

  final int stageNumber;
  final RuneProgress progress;
  final ValueChanged<RuneProgress> onChanged;
  final StageConfig stageConfig;
  final int entryCost;
  final int? playCurrency;

  @override
  State<_StagePrepCard> createState() => _StagePrepCardState();
}

class _StagePrepCardState extends State<_StagePrepCard> {
  /// 다이얼로그 안에서 편성이 바뀔 때마다 갱신되는 최신 스냅샷.
  late RuneProgress _progress = widget.progress;

  /// 편성/해제 공통 처리: 로컬 상태 갱신 + 상위(메인 화면) 전파.
  void _onPartyChanged(RuneProgress next) {
    setState(() => _progress = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final canAfford =
        widget.playCurrency == null || widget.playCurrency! >= widget.entryCost;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: UiFrame.round24(
            // `SingleChildScrollView` 안이라 세로 제약이 무한대다.
            // `StackFit.expand` 면 `Stack` 가 `tight(∞)` 을 만들어 버린다.
            fit: StackFit.loose,
            background: AppColors.cardDark,
            color: AppColors.glassBorder,
            insets: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            art: const CardArt.header(kCardArtHeaderStagePrep),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 헤더: [X] / STAGE N / [i] ──
                Row(
                  children: [
                    _CircleIconButton(
                      key: const ValueKey('stage-prep-close'),
                      icon: Icons.close,
                      tooltip: l10n.tr('common_cancel'),
                      onPressed: () =>
                          Navigator.pop(context, StagePrepOutcome.cancel),
                    ),
                    Expanded(
                      child: Text(
                        l10n.trp('common_stage', {'n': widget.stageNumber}),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _CircleIconButton(
                      key: const ValueKey('stage-prep-info'),
                      icon: Icons.info_outline,
                      tooltip: widget.stageConfig.subtitle.isEmpty
                          ? l10n.tr('stage_prep_title')
                          : widget.stageConfig.subtitle,
                      onPressed: () => _showInfoDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 몬스터 이름 + 서브타틀 ──
                Text(
                  widget.stageConfig.monsterName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.stageConfig.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.stageConfig.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),

                // ── MY ENTRY PARTY (1x5, 빈 자리는 `+`) ──
                Text(
                  l10n.tr('stage_prep_party'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                PartySlots(
                  progress: _progress,
                  onChanged: _onPartyChanged,
                  onHeroTap: (ctx, hero) => showHeroDetailDialog(
                    ctx,
                    hero: hero,
                    progress: _progress,
                    onChanged: _onPartyChanged,
                  ),
                  onHeroLongPress: (ctx, hero) => showUnassignHeroDialog(
                    ctx,
                    hero: hero,
                    progress: _progress,
                    onChanged: _onPartyChanged,
                  ),
                ),
                const SizedBox(height: 10),

                // ── 속성 집계 + 스테이지 상성 ──
                // 배율 숫자는 없다. 같은 속성 영웅의 공격력 합이 그 색 매칭 데미지의
                // 밑이라 인원수만 보여주고, 배율이 붙는 경우는 몬스터 약점/열세로
                // 정직하게 알린다. 파도 전투는 마리별로 나열한다(먼저 잡을 녀석).
                Text(
                  partyElementLine(l10n, _progress),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (widget.stageConfig.monsterCount > 1)
                  _MonsterWaveView(stage: widget.stageConfig)
                else
                  _MonsterAffinityRow(
                    monster: widget.stageConfig.monsterAt(0),
                  ),
                const SizedBox(height: 12),

                // ── 영웅 **개별** 스탯 (드래곤퀘스트식) ──
                // 파티 합계 ATK/HP 칩은 삭제 — 아래 개인 스탯 줄이 이미 그 값을
                // 영웅 단위로 다 보여준다(합계 한 줄은 중복 정보였다).
                for (final s in _progress.heroCombatStats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            '${s.element.emoji} ${_heroLabel(l10n, s)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.tr('stat_hp')} ${s.hp}  '
                            '${l10n.tr('stat_atk')} ${s.attack}  '
                            '${l10n.tr('stat_def')} ${s.defense}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // ── 입장 재화 ──
                UiFrame.round12(
                  // 부모 `Column(mainAxisSize: min)` 안이라 세로가 무한대다.
                  fit: StackFit.loose,
                  background: AppColors.playCoinBlue.withValues(alpha: 0.12),
                  color: AppColors.playCoinBlue.withValues(alpha: 0.4),
                  insets: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // entry_cost_label = "입장 비용: ⚡ {n}" (n = 소모 재화)
                      Text(
                        l10n.trp('entry_cost_label', {'n': widget.entryCost}),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (widget.playCurrency != null)
                        Text(
                          l10n.trp('stage_prep_play_held', {
                            'n': widget.playCurrency!,
                          }),
                          style: TextStyle(
                            color: canAfford
                                ? Colors.white54
                                : AppColors.danger,
                            fontSize: 12,
                            fontWeight: canAfford
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 액션: [전투 출격] ──
                // 화살표 아이콘 없음 — 라벨만으로 CTA 임을 알린다(중복 표시 제거).
                GradientButton(
                  key: const ValueKey('stage-prep-confirm'),
                  onPressed: canAfford
                      ? () => Navigator.pop(context, StagePrepOutcome.confirm)
                      : null,
                  label: l10n.tr('stage_prep_confirm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 영웅 개인 스탯 행의 이름 라벨 (예: "마리스").
  static String _heroLabel(AppLocalizations l10n, HeroCombatStats stats) =>
      l10n.tr('hero_name_${stats.heroId}');

  /// [i] 버튼 상세 정보.
  void _showInfoDialog(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassCardStrong,
        title: Text(widget.stageConfig.monsterName),
        content: Text(
          '${widget.stageConfig.subtitle}\n\n'
          '${l10n.tr('stage_prep_info_body')}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('common_cancel')),
          ),
        ],
      ),
    );
  }
}

/// 전투 준비 모달의 몬스터 상성 한 줄 — 약점(×1.5) / 열세(×0.5).
///
/// 전투 HUD 에도 같은 정보가 뜨지만, **출격 전에** 상성을 아는 것과 보드
/// 보면서 다시 확인하는 건 다르다. 편성 단계에서 미리 보고 색을 고를 수 있게 한다.
///
/// 파도 전투에서는 마리마다 상성이 다르므로 [WaveMonster] 한 마리씩 받는다.
class _MonsterAffinityRow extends StatelessWidget {
  const _MonsterAffinityRow({required this.monster});

  final WaveMonster monster;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(
          l10n,
          element: monster.weakElement,
          label: l10n.tr('battle_monster_weak'),
          color: AppColors.accent,
        ),
        const SizedBox(width: 6),
        _chip(
          l10n,
          element: monster.resistElement,
          label: l10n.tr('battle_monster_resist'),
          color: Colors.white38,
        ),
      ],
    );
  }

  Widget _chip(
    AppLocalizations l10n, {
    required RuneElement element,
    required String label,
    required Color color,
  }) {
    return UiPill(
      size: UiPillSize.medium,
      borderColor: color.withValues(alpha: 0.45),
      background: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(element.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$label ${l10n.tr('element_${element.name}')}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 파도 전투 준비 미리보기 — "몬스터 {n}마리" + 마리별 약점/열세 줄.
///
/// 파도 전투에서는 몬스터마다 약점/열세가 달라 "먼저 잡을 녀석"이 선택지가
/// 된다. 각 마리가 어느 속성에 약한지 출격 전에 나열해 색 고르기를 미리
/// 가능하게 한다. 단일 몬스터 스테이지는 [_MonsterAffinityRow] 한 줄만 쓴다.
class _MonsterWaveView extends StatelessWidget {
  const _MonsterWaveView({required this.stage});

  final StageConfig stage;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final count = stage.monsterCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.trp('stage_prep_monster_count', {'n': '$count'}),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${i + 1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 6),
                _MonsterAffinityRow(monster: stage.monsterAt(i)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 모달 헤더의 원형 아이콘 버튼.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 테두리는 원형 38x38 스프라이트다(9-slice 아님 — 크기 고정이라 자를 이유가
    // 없다). 채움색은 스프라이트 뒤 `background` 로 준다.
    // `Material` 을 남기는 이유: 잉크 스플래시를 그리려면 조상 Material 이
    // 있어야 한다(없으면 아예 안 그린다). 테두리 색만 스프라이트로 옮겼을 뿐
    // 원래 `IconButton` 의 동작(툴팁/리플/접근성)은 그대로 유지한다.
    //
    // `ConstrainedBox(48)` 도 필수다. `IconButton` 은 기본
    // `MaterialTapTargetSize.padded` 로 48x48 터치 영역을 덧씌우는데, 그냥
    // 스프라이트로 바꾸면 38 로 줄어들어 레이아웃과 접근성이 함께 후퇴한다.
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: UiFrame.circle38(
              background: AppColors.glassCard,
              color: AppColors.glassBorder,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(icon, size: 20, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
