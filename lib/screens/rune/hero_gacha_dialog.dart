/// Rune Puzzle Tactics — 영웅 랜덤 영입(뽑기) 결과 팝업
///
/// 배정 시점에 결과는 이미 확정되어 있고([RuneProgress.tryPullHeroes]) 이 팝업은
/// **연출만** 담당한다. 결과 카드/그리드는 탭하면 기존 영웅 상세 팝업을 띄운다.
///
/// 연출 (요구사항 9):
/// - 1연: 세로 슬롯머신. 지수 감속 후 카드 확정 + **탄(overshoot) 스케일** 팝.
/// - 10연: 2×5 그리드가 순차적으로 공개(스태거) + 신규/상승 요약.
/// - **신규 영웅 공개 → 대형 파이어워크 스프라이트 버스트** (중복은 작은 스파클).
/// - **스킵 버튼** — 회전 중 즉시 결과로 점프(재탭 impatient 방지).
/// - 카드 교체마다 틱 사운드, 확정/신규/중복마다 다른 사운드.
/// - 결과가 [GachaOutcome.promoted] 이면 승급 사실과 등급 이동을,
///   [GachaOutcome.levelUp] 이면 뽑힌 영웅의 `Lv.from → Lv.to` 를 함께 표기한다.
///
/// 참고: [AlertDialog] 위에 [SpriteBurst] 를 얹기 위해 content 를
/// [CenteredSpriteBurst] 로 감싼다. `BackdropFilter` 를 쓰지 않으므로 저사양에서도
/// 프레임이 끊기지 않는다.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import '../../l10n/language_controller.dart';
import '../../services/game_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/hero_portrait.dart';
import '../../widgets/sprite_burst.dart';
import '../../widgets/ui_frame.dart';
import '../../widgets/ui_pill.dart';
import 'hero_detail_dialog.dart';

/// 뽑기 결과 팝업 표시.
///
/// [results] 가 비어 있으면(풀 고갈 등) 확인 버튼만 있는 빈 팝업을 띄운다.
Future<void> showHeroGachaDialog(
  BuildContext context, {
  required List<GachaResult> results,
  required RuneProgress progress,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HeroGachaDialog(results: results, progress: progress),
  );
}

class _HeroGachaDialog extends StatefulWidget {
  const _HeroGachaDialog({required this.results, required this.progress});

  final List<GachaResult> results;
  final RuneProgress progress;

  @override
  State<_HeroGachaDialog> createState() => _HeroGachaDialogState();
}

class _HeroGachaDialogState extends State<_HeroGachaDialog>
    with TickerProviderStateMixin {
  /// 슬롯머신 사이클 횟수.
  static const int _cycles = 28;

  bool get _isTen => widget.results.length > 1;

  GachaResult? get _final =>
      widget.results.isEmpty ? null : widget.results.first;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.results.isEmpty ? 1 : (_isTen ? 1400 : 2600),
    ),
  );

  /// 카드 확정 **탄(overshoot) 스케일** — 0 → 1.12 → 1.0.
  ///
  /// 슬롯머신 회전이 멈춘 직후 한 번만 울린다. 스케일만으로 "떡!" 하는
  /// 느낌을 만들어 준다.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// 오버슈트 곡선 — 살짝 넘어갔다가 원래 크기로 돌아온다.
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.55, end: 1.14), weight: 55),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 45),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOutBack));

  /// 확정 순간 등급색 **글로우 펄스** (0 → 1). [HeroCard] 밖 테두리에 얹는다.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// 현재 슬롯에 표시 중인 카드 인덱스.
  int _slotIndex = 0;

  /// 카드 교체마다 증가하는 시퀀스.
  ///
  /// [AnimatedSwitcher] 는 전환 중 이전/다음 자식을 Stack 에 함께 두므로,
  /// 슬롯이 빠르게 돌아 풀 안의 같은 영웅을 90ms 안에 재방문하면
  /// 영웅 id 기반 키가 겹쳐 `Duplicate keys` 가 터진다. 교체 횟수로 키를
  /// 유일하게 만들어 이 문제를 원천 차단한다.
  int _slotSeq = 0;

  /// 1연 결과 확정 플래시.
  bool _revealed = false;

  GameAudioService get _audio => GameAudioService.instance;

  /// 슬롯머신이 도는 카드 풀(가용 영웅).
  List<RuneHeroDef> get _pool {
    final pool = HeroGacha.poolFor(widget.progress.nextStage);
    return pool.isEmpty ? const <RuneHeroDef>[] : pool;
  }

  /// 확정 결과가 신규 영웅인가 (연출 강도 분기용).
  bool get _isNewReveal => _final?.outcome == GachaOutcome.newHero;

  @override
  void initState() {
    super.initState();
    if (widget.results.isEmpty) {
      // 결과 없음: 애니메이션 없이 정적 표시.
      _revealed = true;
      return;
    }
    // 시작 인덱스는 임의로(결과와 무관하게 스크롤되도록).
    final n = _pool.length;
    if (n > 0) {
      _slotIndex = Random().nextInt(n);
    }
    _anim
      ..addListener(_onTick)
      ..addStatusListener(_onStatus)
      ..forward();
  }

  @override
  void dispose() {
    _anim
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
    _pop.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// **스킵** — 회전을 즉시 끝내고 결과로 점프한다.
  ///
  /// 결과는 이미 확정돼 있으므로 연출만 건너뛰는 것이고, 데이터에는 영향이 없다.
  /// 스킵 사운드 없이 곧바로 확정 임팩트를 한 번 울린다.
  void _skip() {
    if (_revealed) return;
    _anim.stop();
    _anim.value = 1.0;
    _reveal();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _reveal();
  }

  /// 결과 확정 처리 — 팝 애니메이션 + 사운드 + 버스트를 한 번만 시작한다.
  void _reveal() {
    if (!mounted || _revealed) return;
    setState(() => _revealed = true);
    _pop.forward(from: 0);
    _glow.forward(from: 0);
    // 10연은 카드별 연출이 이미 있으니 "마지막 임팩트" 한 번만 울린다.
    if (_isTen) {
      _audio.playEffect(GameSound.gachaReveal);
      if (widget.results.any((r) => r.outcome == GachaOutcome.newHero)) {
        _audio.playEffect(GameSound.gachaNew);
      }
      return;
    }
    // 신규면 가장 강한 축제 음, 그 외에는 공개 임팩트 + 반짝임.
    if (_isNewReveal) {
      _audio.playEffect(GameSound.gachaNew);
    } else {
      _audio.playEffect(GameSound.gachaReveal);
      _audio.playEffect(GameSound.gachaDup);
    }
  }

  /// 지수 감속: 0→1 진행률에서 사이클 인덱스를 계산해 카드를 교체한다.
  void _onTick() {
    if (_revealed || _isTen) return;
    final n = _pool.length;
    if (n == 0) return;
    final t = Curves.easeOutCubic.transform(_anim.value.clamp(0.0, 1.0));
    final idx = (t * n * _cycles).floor() % n;
    if (idx != _slotIndex) {
      setState(() {
        _slotIndex = idx;
        _slotSeq++;
      });
      // 회전 중 틱 사운드 — 다음 틱보다 먼저 울리면 연속감만 남아 좋은이다.
      _audio.playEffect(GameSound.gachaTick);
    }
  }

  /// 현재 표시할 카드 (1연: 결과 확정 후에는 최종 카드 고정).
  RuneHeroDef get _slotHero {
    final pool = _pool;
    if (pool.isEmpty) return HeroPool.starter;
    final f = _final;
    if (_revealed && f != null) return f.hero;
    return pool[_slotIndex % pool.length];
  }

  void _openDetail(RuneHeroDef hero) {
    showHeroDetailDialog(context, hero: hero, progress: widget.progress);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final results = widget.results;

    // 결과가 확정되었고 아직 버스트를 안 썼을 때만 1회 재생한다.
    // (setState 로 [_burstPlayed] 를 올리면 재생 조건이 false 가 된다.)
    final showBurst = _revealed && results.isNotEmpty;
    final effect = _isNewReveal ? SpriteEffect.firework : SpriteEffect.sparkle;

    return CardArtBackdrop(
      asset: kCardArtGachaDialog,
      child: AlertDialog(
      key: const ValueKey('gacha-result-dialog'),
      backgroundColor: AppColors.glassCardStrong,
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isNewReveal && _revealed
                  ? l10n.tr('gacha_congrats_new')
                  : l10n.tr('gacha_header'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // ── 스킵 (요구사항 9) ──
          // 회전 중에만 뜬다. 확정 후 숨기면 화면이 제자리로 돌아간다.
          if (!_revealed)
            TextButton(
              key: const ValueKey('gacha-skip'),
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(l10n.tr('gacha_skip')),
            ),
        ],
      ),
      // ── 결과 본문 + 스프라이트 버스트 오버레이 ──
      content: CenteredSpriteBurst(
        effect: showBurst ? effect : null,
        size: _isNewReveal ? 300 : 220,
        child: results.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l10n.tr('gacha_empty_pool'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              )
            : _isTen
            ? SizedBox(
                width: 360,
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: _TenPullView(
                  results: results,
                  reveal: _anim,
                  onTap: _openDetail,
                ),
              )
            : _SinglePullView(
                hero: _slotHero,
                slotSeq: _slotSeq,
                result: _final!,
                progress: widget.progress,
                revealed: _revealed,
                popScale: _popScale,
                glow: _glow,
                onTap: _openDetail,
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('gacha-confirm'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.tr('gacha_confirm')),
        ),
      ],
      ),
    );
  }
}

/// 1연 결과: 세로 슬롯 + 결과 고정 + 탄 스케일 + 등급색 글로우 플래시.
class _SinglePullView extends StatelessWidget {
  const _SinglePullView({
    required this.hero,
    required this.slotSeq,
    required this.result,
    required this.progress,
    required this.revealed,
    required this.popScale,
    required this.glow,
    required this.onTap,
  });

  final RuneHeroDef hero;

  /// 슬롯 교체 횟수([AnimatedSwitcher] 키 유일화용).
  final int slotSeq;

  /// 확정 결과(등급 상승 대상 포함).
  final GachaResult result;
  final RuneProgress progress;
  final bool revealed;

  /// 카드 확정 오버슈트 스케일 (0.55 → 1.14 → 1.0).
  final Animation<double> popScale;

  /// 테두리 글로우 페이드 아웃 (1 → 0).
  final Animation<double> glow;
  final ValueChanged<RuneHeroDef> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    // 스크롤 중에는 카드 자체 등급을, 확정 후에는 결과 등급을 보여준다.
    final grade = revealed
        ? progress.heroGrade(result.hero.heroId)
        : hero.rarity;
    final color = heroRarityColor(grade);
    final isNew = revealed && result.outcome == GachaOutcome.newHero;
    final name = l10n.tr('hero_name_${hero.heroId}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 확정 순간 1.14까지 튀었다가 돌아오는 카드.
          ScaleTransition(
            scale: revealed ? popScale : const AlwaysStoppedAnimation(1.0),
            child: AnimatedBuilder(
              animation: glow,
              builder: (context, child) {
                // 글로우 alpha 를 바깥 그림자로 표현한다(테두리 두께는 유지).
                final pulse = revealed
                    ? (1.0 - glow.value).clamp(0.0, 1.0)
                    : 0.0;
                // 테두리는 스프라이트 2벌(1px/3px), 채움은 색. 글로우는 BoxShadow 이라
                // 9-slice 로 옮길 수 없어 그대로 둔다.
                final card = Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 90),
                    child: HeroPortrait(
                      key: ValueKey(
                        revealed
                            ? 'slot-final-$slotSeq'
                            : 'slot-$slotSeq-${hero.heroId}-${grade.badge}',
                      ),
                      hero: hero,
                      size: revealed ? 84 : 72,
                      dimmed: !revealed,
                    ),
                  ),
                );
                if (!revealed) {
                  return UiFrame.square1(
                    height: 148,
                    width: 132,
                    color: AppColors.glassBorder,
                    background: AppColors.cardDark,
                    child: card,
                  );
                }
                return UiFrame.square3(
                  height: 148,
                  width: 132,
                  color: color,
                  background: AppColors.cardDark,
                  shadows: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25 + 0.5 * pulse),
                      blurRadius: 12 + 18 * pulse,
                      spreadRadius: 2 * pulse,
                    ),
                  ],
                  child: card,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (revealed) ...[
            // 신규는 초록 + 짧게 커졌다가 돌아오는 확대 연출(색 + 동작 이중 인코딩).
            _RevealName(
              name: name,
              color: isNew ? AppColors.green : Colors.white,
              glow: glow,
            ),
            const SizedBox(height: 6),
            // ★ 등급 배지 삭제 — 결과 성격(신규/상승/최고)만 남긴다.
            _OutcomeBadge(result: result),
            if (result.outcome == GachaOutcome.promoted) ...[
              const SizedBox(height: 4),
              Text(
                l10n.trp('gacha_promote_to', {
                  // ★ 대신 등급 **문자**(R/SR/SSR/UR)를 쓴다.
                  'from': result.gradeBefore.badge,
                  'to': result.gradeAfter.badge,
                }),
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            // 중복 레벨업: 뽑힌 영웅의 카드가 오른 레벨(Lv.from → Lv.to).
            if (result.outcome == GachaOutcome.levelUp) ...[
              const SizedBox(height: 4),
              Text(
                l10n.trp('result_level_up_line', {
                  'from': result.levelBefore,
                  'to': result.levelAfter,
                }),
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('gacha-detail'),
              onPressed: () => onTap(hero),
              icon: const Icon(Icons.info_outline, size: 16),
              label: Text(l10n.tr('hero_detail_open')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 확정된 영웅 이름 — 공개 직후 살짝 커졌다가 원래 크기로 (짧은 감속 확대).
class _RevealName extends StatelessWidget {
  const _RevealName({
    required this.name,
    required this.color,
    required this.glow,
  });

  final String name;
  final Color color;

  /// 0 → 1 진행. 앞 40% 동안만 확대되고 이후엔 1.0 에 고정된다.
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutBack.transform((glow.value / 0.4).clamp(0.0, 1.0));
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.7 + 0.3 * t).animate(glow),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8)],
        ),
      ),
    );
  }
}

/// 10연 결과: 2×5 그리드 + 스태거 공개 + 요약.
class _TenPullView extends StatelessWidget {
  const _TenPullView({
    required this.results,
    required this.reveal,
    required this.onTap,
  });

  final List<GachaResult> results;

  /// 0→1 공개 진행률 (카드 인덱스만큼 밀려 순차 공개).
  final Animation<double> reveal;
  final ValueChanged<RuneHeroDef> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final newCount = results
        .where((r) => r.outcome == GachaOutcome.newHero)
        .length;
    final levelUpCount = results
        .where((r) => r.outcome == GachaOutcome.levelUp)
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (newCount > 0 || levelUpCount > 0)
            _TenPullSummary(newCount: newCount, levelUpCount: levelUpCount)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.tr('gacha_ten_no_new'),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: reveal,
              builder: (context, _) {
                // i번째 카드는 (i+1)/N 진행 시점에 공개.
                final unit = (reveal.value * (results.length + 1) - i).clamp(
                  0.0,
                  1.0,
                );
                return Opacity(
                  opacity: unit,
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * unit,
                    child: _PullCard(
                      result: results[i],
                      grade: results[i].outcome == GachaOutcome.newHero
                          ? results[i].hero.rarity
                          : results[i].gradeAfter,
                      hidden: unit <= 0,
                      onTap: () => onTap(results[i].hero),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 10연 요약 배너 — 신규 수에 따라 배지 색이 바뀌고 살짝 깜빡인다 (요구사항 9).
///
/// 신규 0명은 "아쉬움" 톤으로 가라앉히고, 신규가 있으면 초록 배지를 크게 띄워
/// 결과를 한눈에 요약한다. 숫자만큼 **배너 자체가 커진다**(0 → 1.15 배 튐).
class _TenPullSummary extends StatefulWidget {
  const _TenPullSummary({required this.newCount, required this.levelUpCount});

  final int newCount;
  final int levelUpCount;

  @override
  State<_TenPullSummary> createState() => _TenPullSummaryState();
}

class _TenPullSummaryState extends State<_TenPullSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final n = widget.newCount;
    // 신규 0 = 회색, 1~2 = 금색, 3+ = 초록(강조).
    final accent = n == 0
        ? Colors.white38
        : n <= 2
        ? AppColors.accentGold
        : AppColors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScaleTransition(
        // 오버슈트 후 원래 크기 — 숫자가 클수록 크게 뛴다.
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(
          CurvedAnimation(
            parent: _ctrl,
            // 신규 수에 비례해 오버슈트를 키운다.
            curve: Interval(0, 0.6, curve: Curves.easeOutBack),
          ),
        ),
        child: UiPill(
          size: UiPillSize.large,
          // 옛 테두리는 1.5px 였다. 픽셀아트 정합을 위해 2px(L 티어)로 올린다.
          borderColor: accent,
          background: accent.withValues(alpha: 0.16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.tr('gacha_badge_new')} $n',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (widget.levelUpCount > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '${l10n.tr('gacha_badge_levelup')} ${widget.levelUpCount}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 10연 그리드 1칸.
class _PullCard extends StatelessWidget {
  const _PullCard({
    required this.result,
    required this.grade,
    required this.onTap,
    this.hidden = false,
  });

  final GachaResult result;
  final HeroRarity grade;
  final VoidCallback onTap;

  /// 공개 전 placeholder 표시 여부.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final color = heroRarityColor(grade);
    final isNew = result.outcome == GachaOutcome.newHero;

    // 신규 칸에만 작은 스파클 버스트를 한 번 겹친다 (요구사항 9).
    // `SpriteBurst` 는 스스로 재생하고 사라지므로 여기서 상태를 관리하지 않는다.
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hidden ? null : onTap,
      child: UiFrame.square2(
          // 옛 테두리는 1.5px 였다. 픽셀아트 정합을 위해 2px 로 올린다.
          color: hidden ? AppColors.glassBorder : color,
          background: AppColors.cardDark,
          // 옛 `padding: all(3)` 을 프레임 안쪽 여백으로 옮긴다.
          insets: const EdgeInsets.all(3),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hidden)
              const Text(
                '?',
                style: TextStyle(fontSize: 22, color: Colors.white24),
              )
            else ...[
              HeroPortrait(hero: result.hero, size: 34),
              const SizedBox(height: 3),
              // ★ 등급 표시는 삭제 — 신규 여부만 배지로 알린다(배지가 없으면 중복).
              if (isNew)
                Text(
                  l10n.tr('gacha_badge_new'),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    if (hidden || !isNew) return card;
    return Stack(
      alignment: Alignment.center,
      children: [
        card,
        // 버스트는 탭을 가로막지 않는다 (카드 탭 → 상세 팝업 유지).
        const Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SpriteBurst(effect: SpriteEffect.sparkle, size: 72),
            ),
          ),
        ),
      ],
    );
  }
}

/// 결과 성격 배지 (신규 / 등급 상승 / 최고 등급).
class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.result});

  final GachaResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final (text, color) = switch (result.outcome) {
      GachaOutcome.newHero => (l10n.tr('gacha_badge_new'), AppColors.green),
      GachaOutcome.promoted => (
        l10n.tr('gacha_badge_promote'),
        AppColors.accentGold,
      ),
      GachaOutcome.maxed => (l10n.tr('gacha_badge_max'), Colors.white38),
      GachaOutcome.levelUp => (
        l10n.tr('gacha_badge_levelup'),
        AppColors.accentGold,
      ),
    };
    return UiPill(
      size: UiPillSize.medium,
      borderColor: color.withValues(alpha: 0.6),
      background: color.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
