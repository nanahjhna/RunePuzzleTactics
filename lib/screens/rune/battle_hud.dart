/// Rune Puzzle Tactics — 전투 HUD 공용 위젯 (RuneBattleView ↔ RuneTutorialView 공용)
///
/// **왜 공용인가**: 튜토리얼은 "옆 게임"이 아니라 **실제 전투와 같은 화면**이어야
/// 한다(요구사항 9). 상단바·몬스터 영역·영웅 포트레이트 행을 각 화면이 따로 그리면
/// inevitably 조금씩 벌어진다 — 스케일 규격, HP 바 높이, 스킬 캡션 문구, 시너지
/// 칩 배치가 서로 다른 수가 된다.
///
/// 그래서 화면 골격([BattleStageScaffold])과 규격([BattleStageMetrics])까지 전부
/// 이 파일 하나에 두고 두 화면이 함께 쓴다. 튜토리얼에 남는 차이는 오직
/// "안내 카드 / 스킵 바" 뿐이고, 그 위에 올라가는 HUD는 픽셀 단위로 동일하다.
///
/// 참고로 몬스터 위 데미지 칩(개별/합계/넘침)은 삭제된 상태다(요구사항 6) —
/// 몬스터 HP 바가 곧 유일한 정보다.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/game_audio_service.dart';
import 'package:rune_puzzle_tactics/widgets/hero_hit_flash.dart';
import 'package:rune_puzzle_tactics/widgets/hero_portrait.dart';
import 'package:rune_puzzle_tactics/widgets/monster_sprite.dart';

import '../../l10n/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_bar.dart';
import '../../widgets/ui_pill.dart';

/// 전투 화면 세로 규격. 실제 전투와 튜토리얼이 **같은 값**을 쓴다.
///
/// 세로 화면에서 보드가 정사각형으로 최대한 커야 하므로 몬스터 스프라이트와
/// 영웅 초상화에 세로 높이를 할당하고, 남은 높이를 보드가 가져간다.
class BattleStageMetrics {
  const BattleStageMetrics({
    required this.monsterSpriteHeight,
    required this.heroPortraitHeight,
  });

  /// [maxHeight] = `SafeArea` 안쪽 세로 길이.
  factory BattleStageMetrics.of(double maxHeight) => BattleStageMetrics(
    // 몬스터 스프라이트 — 충분해야 피격/사망 프레임이 읽힌다.
    monsterSpriteHeight: (maxHeight * 0.20).clamp(72.0, 140.0),
    // 영웅 초상화 (요구사항 5): 세로로 지나치게 길어 유닛 행이 화면을 다 먹던
    // 것을 **높이만** 줄인다. 가로는 슬롯 폭 그대로라 종횡비가 살아난다.
    heroPortraitHeight: (maxHeight * 0.13).clamp(72.0, 108.0),
  );

  final double monsterSpriteHeight;

  /// 영웅 포트레이트 슬롯 높이. 슬롯 **너비**는 [BattleHeroPortraitHud] 가
  /// 화면 폭으로 계산한다 — 여기서는 세로만 관여한다.
  final double heroPortraitHeight;
}

/// 전투/튜토리얼 공용 스테이지 배경.
///
/// 실제 전투 화면과 튜토리얼은 **같은 배경 이미지 + 같은 다크닝**을 쓴다
/// (요구사항 9). 튜토리얼만 다른 그라데이션 배경을 쓰고 있었다.
const BoxDecoration battleStageBackdrop = BoxDecoration(
  color: AppColors.bgMain,
  image: DecorationImage(
    image: AssetImage('assets/background/stage.jpg'),
    fit: BoxFit.cover,
    colorFilter: ColorFilter.mode(Color(0xB0000000), BlendMode.darken),
  ),
);

/// 전투 화면 골격: 배경 → SafeArea → [topBar] / [hudRows] / [board] 세로 배치.
///
/// [footer] (튜토리얼 안내 카드 등)와 [overlay] (일시정지·승패 오버레이)는
/// 선택 사항이라 실제 전투만 채운다. 두 화면의 차이를 이 두 칸으로만 격리한다.
///
/// [hudRows] 는 규격([BattleStageMetrics])을 받는 빌더다 — 규격 계산이 이
/// 위젯 한 곳에만 있어야 두 화면의 HUD가 어긋나지 않는다.
class BattleStageScaffold extends StatelessWidget {
  const BattleStageScaffold({
    super.key,
    required this.topBar,
    required this.hudRows,
    required this.board,
    this.footer,
    this.overlay,
  });

  final Widget topBar;

  /// 몬스터 영역 + 영웅 포트레이트 행.
  final Widget Function(BattleStageMetrics metrics) hudRows;

  /// 정사각형 보드 (GameWidget).
  final Widget board;

  /// 보드 아래 부가 영역 (튜토리얼 안내 카드 등).
  final Widget? footer;

  /// 보드 위 전체 화면 오버레이 (일시정지 / 승패 연출 등).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: battleStageBackdrop,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = BattleStageMetrics.of(constraints.maxHeight);
            return Stack(
              children: [
                Column(
                  children: [
                    topBar,
                    hudRows(metrics),
                    // 턴 인디케이터는 없고, 몬스터 턴/결과 전환은 보드 그레이아웃으로
                    // 대체 표시한다. 보드는 살짝 아래로 내려온다.
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, 0.08),
                        child: AspectRatio(aspectRatio: 1, child: board),
                      ),
                    ),
                    ?footer,
                    const SizedBox(height: 8),
                  ],
                ),
                ?overlay,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 상단바 + 몬스터/영웅 HUD 행을 통째로 묶는 컨테이너.
///
/// [BattleStageMetrics] 를 받아 자기 높이를 재 계산하는 대신, 이미 계산된
/// 규격을 그대로 쓴다 — 그래야 두 화면이 언제나 같은 픽셀 높이를 쓴다.
class BattleHudRows extends StatelessWidget {
  const BattleHudRows({
    super.key,
    required this.metrics,
    required this.battle,
    required this.hud,
    required this.audioService,
    required this.isPlayerTurn,
    required this.canUseSkill,
    required this.onUseSkill,
    this.armedSkillHeroId,
    this.hintHeroId,
    this.heroHit,
    required this.sprite,
  });

  final BattleStageMetrics metrics;

  final BattleEngine battle;

  /// HUD 갱신 알림 ([ValueNotifier] 등). 몬스터 스프라이트·영웅 HP가 구독한다.
  final Listenable hud;

  final GameAudioService audioService;

  /// 플레이어 턴 여부 (보드 그레이아웃과 동일 판정).
  final bool isPlayerTurn;

  /// 지금 스킬을 쓸 수 있는지 (캐시타임 등).
  final bool canUseSkill;

  /// 스킬 발동 요청. [HeroSkillEffect.needsTarget] 스킬은 `target == null` 로
  /// 불려 조준 모드로 들어가고, 보드 룬을 누른 뒤 `target` 과 함께 다시 불린다.
  final void Function(String heroId, {int? target}) onUseSkill;

  /// **조준 모드에 든 영웅 id** (보드에서 대상 칸을 고르는 중).
  ///
  /// HUD 는 이 영웅 슬롯에 조준 링을 그려 "지금 무엇을 기다리는 중인지"를
  /// 알려준다. 보드 하이라이트와 반드시 같은 값을 쓴다.
  final String? armedSkillHeroId;

  /// 튜토리얼: 이 영웅 슬롯을 "눌러야 할 곳"으로 강조한다(맥동 링). null 이면 없음.
  final String? hintHeroId;

  /// 현재 재생 중인 영웅 피격 연출. null 이면 없다.
  final ({String heroId, int token, int damage})? heroHit;

  /// 몬스터 스프라이트. 호출부가 [MonsterSprite] 를 만들어 넘긴다 — 여기서는
  /// 엔진/오디오 의존을 갖지 않기 위해 슬롯만 받는다.
  final Widget sprite;

  @override
  Widget build(BuildContext context) {
    final s = battle.state;
    return AnimatedBuilder(
      animation: hud,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // 몬스터 영역: HP 바 → 스프라이트.
            // 상성은 파도 전투에서 몬스터마다 다르므로 항상 **현재 등장 중인
            // 몬스터**([BattleState.currentMonster]) 기준으로 표시한다.
            BattleMonsterPanel(
              spriteHeight: metrics.monsterSpriteHeight,
              monsterHp: s.monsterHp,
              monsterMaxHp: s.monsterMaxHp,
              weakElement: s.currentMonster.weakElement,
              resistElement: s.currentMonster.resistElement,
              monsterNumber: s.monsterNumber,
              monsterCount: s.monsterCount,
              poisonStacks: s.poisonStacks,
              poisonPerStack: s.poisonPerStack,
              sprite: sprite,
            ),
            const SizedBox(height: 8),

            // 통합 파티 HP 바는 없다 — 체력은 각 영웅 초상화 **하단**에 표시한다.
            // 몬스터는 이제 영웅 1명만 때리므로 "합계 HP" 는 누구의 HP 인지
            // 알려주지 않는다. 개별 HP 바가 곧 유일한 체력 지표다.
            BattleHeroPortraitHud(
              units: s.units,
              active: isPlayerTurn,
              canUseSkill: canUseSkill,
              portraitHeight: metrics.heroPortraitHeight,
              onUseSkill: onUseSkill,
              armedSkillHeroId: armedSkillHeroId,
              hintHeroId: hintHeroId,
              maxParty: HeroRoster.maxPartySize,
              hit: heroHit,
            ),
          ],
        ),
      ),
    );
  }
}

/// 몬스터 HUD: 상성 칩 → (파도 진행) → HP 바 → 몬스터 스프라이트.
///
/// 몬스터는 무속성이지만 상성은 있다 — **현재 등장 중인 몬스터가 약점/열세
/// 속성을 갖는다** ([WaveMonster.affinityFor]). 파도 전투에서는 몬스터가 바뀔
/// 때마다 이 칩도 함께 바뀐다([BattleState.currentMonster]). 배율이 붙는 이유를
/// 숨기면 플레이어가 "왜 불색만 계속 때려야 하지?"를 설명할 수 없으므로, 칩
/// 두 개로 정직하게 공개한다.
class BattleMonsterPanel extends StatelessWidget {
  const BattleMonsterPanel({
    super.key,
    required this.spriteHeight,
    required this.monsterHp,
    required this.monsterMaxHp,
    required this.weakElement,
    required this.resistElement,
    required this.monsterNumber,
    required this.monsterCount,
    this.poisonStacks = 0,
    this.poisonPerStack = 0,
    this.sprite,
  });

  final double spriteHeight;
  final int monsterHp;
  final int monsterMaxHp;

  /// 이 스테이지의 약점 속성 — 매칭 데미지 ×1.5.
  final RuneElement weakElement;

  /// 이 스테이지의 열세 속성 — 매칭 데미지 ×0.5.
  final RuneElement resistElement;

  /// 파도 진행 — 현재 n번째 등장 몬스터 (1-based).
  final int monsterNumber;

  /// 파도 총 몬스터 수. 1이면(단일 몬스터) 진행 칩을 그리지 않는다.
  final int monsterCount;

  /// 몬스터에 걸린 독 스택 수. 0 이면 칩을 그리지 않는다.
  ///
  /// 독은 **반복형**이라 몬스터 HP 바로는 "언제까지 남았는가"가 안 보인다.
  /// 스택 수를 그대로 노출해야 플레이어가 "이대로 끌고 가면 이만큼 깎인다"를
  /// 예측할 수 있다.
  final int poisonStacks;

  /// 스택 1개당 턴 피해 — 칩에 `×N` 으로 붙는다.
  final int poisonPerStack;

  /// 스프라이트 슬롯. 기본은 슬라임 스프라이트가 아니라 빈 공간 — 호출부가
  /// [MonsterSprite] 를 직접 끼워 넣는다(스프라이트가 [BattleEngine] 를 요구하므로
  /// 이 위젯은 엔진/오디오를 알지 않는다).
  final Widget? sprite;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return Column(
      children: [
        // 예전에 있던 ⚖️ 시너지 설명 칩은 삭제했다. 대신 **실제로 배율이 걸리는**
        // 약점/열세 속성 두 개만 남긴다 — 툴팁 대신 규칙을 말한다.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AffinityChip(
              element: weakElement,
              text: l10n.tr('battle_monster_weak'),
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            _AffinityChip(
              element: resistElement,
              text: l10n.tr('battle_monster_resist'),
              color: Colors.white38,
            ),
            // 독은 상성이 아니라 **누적 상태**라 약점/열세 칩과 성격이 다르다.
            // 붙어 있을 때만 세 번째 칩으로 나타난다.
            if (poisonStacks > 0) ...[
              const SizedBox(width: 6),
              _AffinityChip(
                element: RuneElement.poison,
                text: poisonPerStack > 0
                    ? '$poisonStacks ×$poisonPerStack'
                    : '$poisonStacks',
                color: Color(RuneElement.poison.argb),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // 파도 진행 칩 — 단일 몬스터(1마리)면 숨겨 기존 배치를 그대로 유지한다.
        if (monsterCount > 1) ...[
          Text(
            l10n.trp('battle_monster_wave', {
              'i': '$monsterNumber',
              'n': '$monsterCount',
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Center(
          child: SizedBox(
            width: 110,
            child: _HpBar(
              label: l10n.tr('hp_monster'),
              value: monsterHp,
              max: monsterMaxHp,
              color: AppColors.danger,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: spriteHeight,
          child: sprite ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 약점/열세 속성 칩 — 아이콘 + 라벨 한 줄.
class _AffinityChip extends StatelessWidget {
  const _AffinityChip({
    required this.element,
    required this.text,
    required this.color,
  });

  final RuneElement element;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
            text,
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

/// 전투 중 스킬 설명 팝업 — 초상화 위 스킬 칩을 누르면 띄운다.
///
/// 이름/효과/사용 횟수를 한 화면에 압축한다. 전투에서 나가지 않고 스킬이
/// 무엇을 하는지 확인할 수 있어야 "스킬을 모르고 넘어가는" 일이 없다.
void _showSkillInfoDialog(
  BuildContext context, {
  required HeroSkillSpec spec,
  required String heroId,
  required RuneElement element,
}) {
  final l10n = LanguageScope.of(context).strings;
  final color = heroElementColor(element);
  final name = l10n.tr(spec.l10nKeyFor(heroId));
  final desc = l10n.tr(spec.descriptionKeyFor(heroId));
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(element.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tr('battle_skill_once'),
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 전투 상단바: 중앙 제목 + 우측 일시정지 버튼.
///
/// 좌측 48px 는 제거된 [X] 버튼 자리 — 중앙 제목이 화면 정중앙에 오도록 하는
/// 균형 패딩이다(요구사항: 상단 X 제거).
///
/// [center] 를 넘기면 중앙 자리를 갈아끼운다. 튜토리얼이 "STAGE N" 대신
/// 「튜토리얼 / STEP n/N」을 넣는 자리다 — 좌우 여백·버튼 위치는 그대로라
/// 두 화면의 상단바 **프레임**은 여전히 동일하다.
class BattleStageTopBar extends StatelessWidget {
  const BattleStageTopBar({
    super.key,
    required this.stage,
    required this.bossUltimateWarning,
    required this.onPause,
    this.center,
    this.leading,
    this.pauseTooltip,
  });

  final StageConfig stage;

  /// 보스가 다음 공격으로 궁극기를 쓴다는 경고 (2턴째부터 true).
  final bool bossUltimateWarning;

  final VoidCallback onPause;

  /// 중앙 자리 교체 (기본값은 STAGE N + 스테이지 종류).
  final Widget? center;

  /// 좌측 균형 패딩(기본 48px) 대신 넣을 위젯.
  final Widget? leading;

  /// 우측 버튼 툴팁(기본 = 실제 전투의 일시정지 문구).
  final String? pauseTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (leading != null) leading! else const SizedBox(width: 48),
          Expanded(
            child:
                center ??
                Column(
                  children: [
                    Text(
                      l10n.trp('common_stage', {'n': stage.stageNumber}),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      // 보스: 카운트다운 숫자 대신 궁극기 예고 문구를 띄운다.
                      stage.isBoss && bossUltimateWarning
                          ? l10n.tr('battle_boss_ultimate_warning')
                          : (stage.isBoss
                                ? l10n.tr('battle_type_boss')
                                : (stage.type == StageType.elite
                                      ? l10n.tr('battle_type_elite')
                                      : l10n.tr('battle_type_normal'))),
                      style: TextStyle(
                        color: stage.isBoss && bossUltimateWarning
                            ? AppColors.accent
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: stage.isBoss && bossUltimateWarning
                            ? FontWeight.w900
                            : null,
                      ),
                    ),
                  ],
                ),
          ),
          IconButton(
            tooltip: pauseTooltip ?? l10n.tr('battle_pause_tooltip'),
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// 영웅 초상화 HUD. 초상화를 탭하면 영웅별 스킬을 사용한다.
///
/// 슬롯 너비는 화면 폭/정원으로, 높이는 [portraitHeight](요구사항 5: 세로만 축소)
/// 로 정해진다. 빈 자리는 잠금 초상화로 채워 정원 수와 같은 높이를 유지한다.
class BattleHeroPortraitHud extends StatelessWidget {
  const BattleHeroPortraitHud({
    super.key,
    required this.units,
    required this.active,
    required this.canUseSkill,
    required this.portraitHeight,
    required this.onUseSkill,
    this.maxParty = HeroRoster.maxPartySize,
    this.armedSkillHeroId,
    this.hintHeroId,
    this.hit,
  });

  /// 출전 유닛 (최대 [maxParty]).
  final List<PartyHeroUnit> units;

  /// 플레이어 턴 여부.
  final bool active;
  final bool canUseSkill;
  final double portraitHeight;

  /// 스킬 발동 요청 (조준 스킬은 `target == null` 로 먼저 불린다).
  final void Function(String heroId, {int? target}) onUseSkill;

  final int maxParty;

  /// **조준 모드에 든 영웅 id** — 이 슬롯만 조준 링으로 표시된다.
  final String? armedSkillHeroId;

  /// 튜토리얼: 이 슬롯을 "눌러야 할 곳"으로 강조한다(맥동 링 + 탭 아이콘).
  final String? hintHeroId;

  /// 몬스터 반격/블랙룬/보스 궁극기로 실제로 HP 를 잃은 영웅 정보.
  ///
  /// [HeroHitFlash] / [HeroDamageNumber] 가 이 정보를 받아 피격 연출을 재생한다.
  /// null 이면 현재 활성화된 연출이 없다.
  final ({String heroId, int token, int damage})? hit;

  @override
  Widget build(BuildContext context) {
    final total = maxParty > units.length ? maxParty : units.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / total;
        final size = (slotWidth - 6).clamp(0.0, portraitHeight).toDouble();
        return Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Center(
                  child: i < units.length
                      ? _UnitSlot(
                          key: ValueKey('battle-hero-$i'),
                          unit: units[i],
                          active: active,
                          canUseSkill: canUseSkill,
                          portraitSize: size,
                          portraitHeight: portraitHeight,
                          onUseSkill: onUseSkill,
                          armed: armedSkillHeroId == units[i].heroId,
                          hint: hintHeroId == units[i].heroId,
                          hit: hit?.heroId == units[i].heroId ? hit : null,
                        )
                      : _UnitSlot.locked(
                          portraitSize: size,
                          portraitHeight: portraitHeight,
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// HUD 슬롯 1칸.
class _UnitSlot extends StatelessWidget {
  const _UnitSlot({
    super.key,
    required this.unit,
    required this.active,
    required this.canUseSkill,
    required this.portraitSize,
    required this.portraitHeight,
    required this.onUseSkill,
    this.armed = false,
    this.hint = false,
    this.hit,
  }) : locked = false;

  const _UnitSlot.locked({
    required this.portraitSize,
    required this.portraitHeight,
  }) : unit = null,
       active = false,
       canUseSkill = false,
       onUseSkill = null,
       armed = false,
       hint = false,
       hit = null,
       locked = true;

  final PartyHeroUnit? unit;

  final bool active;
  final bool canUseSkill;
  final double portraitSize;
  final double portraitHeight;
  final void Function(String heroId, {int? target})? onUseSkill;

  /// **조준 모드에 든 슬롯** — 대상 칸을 고르는 중이므로 캡션과 테두리가
  /// "눌러서 기다리는 중" 으로 바뀐다.
  ///
  /// 조준 스킬의 포트레이트는 한 번 더 누르면 취소도 되므로, 탭이 막히면
  /// 조준을 못 빠져나온다.
  final bool armed;

  /// **튜토리얼 힌트 슬롯** — 지금 눌러야 할 초상화. 맥동 링 + 탭 아이콘으로
  /// 시선을 끈다. [IgnorePointer] 라 탭 입력은 실제 스킬 발동으로 이어진다.
  final bool hint;

  /// 이 슬롯에 표시할 피격 연출.
  final ({String heroId, int token, int damage})? hit;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked || unit == null) {
      // 빈 슬롯도 출전 슬롯과 **높이/순서를 맞춰야** 행이 지저분해지지 않는다.
      // (캡션 → HP 바 → 초상화 순서로 통일.)
      return Column(
        children: [
          const SizedBox(height: 20),
          const SizedBox(height: 4),
          const SizedBox(height: _UnitHpBar.height),
          const SizedBox(height: 4),
          HeroPortrait.locked(size: portraitSize, height: portraitHeight),
        ],
      );
    }

    final u = unit!;
    // 스킬은 영웅 고유 — 유닛이 들고 있는 정의를 그대로 쓴다.
    final spec = u.skill;
    // **이 스테이지에서** 이미 스킬을 썼는가. 엔진 판정([canUseHeroSkill])과
    // 같은 기준을 쓴다 — 두 판정이 어긋나면 "화면은 된 것 같은데 안 된다"가
    // 생긴다.
    final used = u.skillUsed;
    // 쓰러진 영웅은 HP 0 이고 스킬을 쓸 수 없다 — 초상화 자체가 ✕ 로 바뀐다.
    final down = u.isDown;
    final ready = active && canUseSkill && !used && !down && spec != null;
    // 스킬명 칩 표시 여부 — 캡션이 "스킬 이름"을 보여주는 상태에서만 칩으로
    // 그리고 탭(설명 팝업)을 허용한다. 조준/사용 완료/쓰러짐/무스킬은 평문.
    final showSkillChip = spec != null && !armed && !used && !down;
    final color = heroElementColor(u.element);
    final l10n = LanguageScope.of(context).strings;
    final hero = HeroPool.byId(u.heroId);
    final heroName = hero == null
        ? l10n.tr('element_${u.element.name}')
        : l10n.tr('hero_name_${hero.heroId}');
    final border = armed
        ? color
        : down
        ? AppColors.danger.withValues(alpha: 0.6)
        : ready
        ? AppColors.accentGold
        : color;

    // 세로 순서: **스킬 캡션 → HP 바 → 초상화.**
    //
    // 예전에는 초상화 아래에 정보행을 두었는데, 그게 룬 보드와의 사이에 34px 빈
    // 띠를 만들었다. 정보를 위로 올리면 그 간격이 사라지고 동시에 "체력이
    // 줄었으니 위험하다"가 화면 위쪽에서 먼저 읽힌다 (시선 이동이 짧아진다).
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Center(
            // 스킬명 칩 — "스킬이 있다"는 인지 + 탭하면 설명 팝업. 포트레이트
            // 탭(발동/조준)과 입력 영역이 분리되어 충돌하지 않는다.
            child: showSkillChip
                ? GestureDetector(
                    onTap: () => _showSkillInfoDialog(
                      context,
                      spec: spec,
                      heroId: u.heroId,
                      element: u.element,
                    ),
                    child: UiPill(
                      size: UiPillSize.medium,
                      borderColor: color.withValues(alpha: 0.55),
                      background: color.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '${u.element.emoji} ${l10n.tr(spec.l10nKeyFor(u.heroId))}',
                        maxLines: 1,
                        style: TextStyle(
                          color: ready ? AppColors.accentGold : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      armed
                          ? l10n.tr('battle_skill_aiming')
                          : down
                          ? l10n.tr('battle_hero_down')
                          : used
                          ? l10n.tr('battle_skill_used')
                          : l10n.tr('battle_skill_none'),
                      maxLines: 1,
                      style: TextStyle(
                        color: armed
                            ? color
                            : down
                            ? AppColors.danger
                            : ready
                            ? AppColors.accentGold
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        // 개인 HP 게이지 — 이제 유일한 체력 지표다.
        _UnitHpBar(hp: u.hp, maxHp: u.maxHp),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                // 조준 중에도 탭은 살아 있다 — 한 번 더 누르면 취소된다.
                onTap: armed
                    ? () => onUseSkill?.call(u.heroId)
                    : (ready ? () => onUseSkill?.call(u.heroId) : null),
                child: HeroPortrait(
                  hero: hero,
                  size: portraitSize,
                  height: portraitHeight,
                  // 유일하게 세로로 긴 슬롯. 여기만 전신 이미지를 쓴다.
                  fullBody: true,
                  // 쓰러진 영웅만 무채색. 스킬은 스테이지당 1회이지만 초상화를
                  // 회색으로 구리게 만들지 않는다 — "이미 썼다"는 캡션 문자열로
                  // 충분히 전달된다.
                  grayscale: down,
                  // 조준 중에는 어두워지지 않는다 — "지금 입력 대기 중" 인데
                  // 눌렸다는 표시가 정확한 행동으로 읽혀야 한다.
                  dimmed: down || (!armed && !active),
                  borderColor: border,
                  overlay: SizedBox(
                    height: portraitHeight * 0.27,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  heroName,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hit != null) ...[
              HeroHitFlash(
                key: ValueKey('hero-hit-flash-${hit!.token}'),
                element: u.element,
                damage: hit!.damage,
                token: hit!.token,
              ),
              HeroDamageNumber(
                key: ValueKey('hero-damage-number-${hit!.token}'),
                damage: hit!.damage,
                token: hit!.token,
              ),
            ],
            // 쓰러진 영웅: 초상화 전체를 어둡게 덮고 ✕ 를 찍는다.
            // IgnorePointer 로 감싸 힌트 테스트를 가로채지 않게 한다.
            if (down)
              const Positioned.fill(child: IgnorePointer(child: _DownMark())),
            // 조준 중: 조준판(⌖) 뱃지. 캡션만으로는 "보드에서 뭘 기다리는 중인지"
            // 를 놓치기 쉬워 아이콘으로 한 번 더 말한다. IgnorePointer 라
            // 슬롯 탭(취소)을 가로채지 않는다.
            if (armed)
              Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 테두리 링만 스프라이트. 아이콘은 그대로 둔다.
                        Image.asset(
                          'assets/ui_dummy/circle_ring_16.png',
                          width: 18,
                          height: 18,
                          filterQuality: FilterQuality.none,
                          color: color,
                        ),
                        Icon(
                          Icons.gps_fixed_rounded,
                          size: 10,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 튜토리얼 힌트: 지금 눌러야 할 초상화. IgnorePointer 라 실제 탭은
            // 스킬 발동으로 이어진다(armed 상태에서는 조준 링이 이미 안내한다).
            if (hint && !down && !armed)
              const Positioned.fill(
                child: IgnorePointer(child: _PortraitHintRing()),
              ),
          ],
        ),
      ],
    );
  }
}

/// 튜토리얼 힌트용 초상화 맥동 링 + 탭 아이콘.
///
/// 정적 테두리로는 "지금 눌러라"가 전달되지 않아 알파가 맥동한다.
/// [IgnorePointer] 로 감싸 실제 탭은 스킬 발동으로 이어진다.
class _PortraitHintRing extends StatefulWidget {
  const _PortraitHintRing();

  @override
  State<_PortraitHintRing> createState() => _PortraitHintRingState();
}

class _PortraitHintRingState extends State<_PortraitHintRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // repeat() 은 0→1 반복이라 삼각파로 바꿔 0→1→0 맥동을 만든다.
        final t = _c.value;
        final tri = t < 0.5 ? t * 2 : (1 - t) * 2;
        final alpha = 0.45 + 0.55 * tri;
        return Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: alpha),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SizedBox.expand(),
            ),
            // 탭 아이콘은 얼굴을 가리지 않도록 하단에 두고, 초상화 위에서도
            // 읽히도록 어두운 원판을 깐다.
            Align(
              alignment: const Alignment(0, 0.72),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45 * alpha),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: const Color(0xFFFFFFFF).withValues(alpha: alpha),
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 초상화 하단의 개인 HP 게이지 + 수치.
class _UnitHpBar extends StatelessWidget {
  const _UnitHpBar({required this.hp, required this.maxHp});

  static const double height = 10;

  final int hp;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final down = hp <= 0;
    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final color = down
        ? AppColors.danger
        : (ratio <= 0.3 ? AppColors.orange : AppColors.green);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: UiBar(
              value: ratio,
              fillColor: color,
              trackColor: Colors.black38,
              height: 6,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$hp',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 쓰러진 영웅을 표시하는 빨간 ✕ 오버레이.
class _DownMark extends StatelessWidget {
  const _DownMark();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: AppColors.danger,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// HP 바 (몬스터 머리 위 소형 표시).
class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.compact = false,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  /// 소형(몬스터 머리 위) 표시 여부.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  $value / $max',
          style: TextStyle(color: Colors.white70, fontSize: compact ? 10 : 12),
        ),
        SizedBox(height: compact ? 1 : 2),
        UiBar(
          value: fraction,
          fillColor: color,
          trackColor: Colors.black38,
          height: compact ? 8 : 12,
        ),
      ],
    );
  }
}
