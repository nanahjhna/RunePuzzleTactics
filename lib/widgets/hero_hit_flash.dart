/// 영웅 피격 연출 위젯.
///
/// [HeroHitFlash] 는 초상화 위에 순간적으로 피격 이미지를 띄우고,
/// 그 아래에 데미지 숫자("-N") 를 떠오르게 한다.
///
/// - [element] 로 [RuneHeroDef.damagePortraitFor] 를 이용해 에셋을 찾는다.
/// - [damage] 가 0 이하면 렌더링하지 않는다(이미 사라진 영웅 등).
/// - key 로 [ValueKey] 를 사용하면 같은 영웅이 연속 맞아도 별도 연출이 재생된다.
/// - 애니메이션은 AnimationController 없이 TweenAnimationBuilder 로 대체해
///   TickerProvider가 필요 없어 전투 HUD와 충돌하지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

import 'hero_portrait.dart';

/// 피격 연출 토큰. 매 피격마다 증가하며 widget key 로 사용해 재생을 보장한다.
typedef HeroHitToken = int;

/// 한 번의 피격 연출을 그리는 위젯.
///
/// - [element]: 피부를 입힌 영웅의 속성
/// - [damage]: 실제로 깎인 HP 양 (0 이하면 nada)
/// - [token]: 매 프레임마다 증가하는 시퀀스. widget key 로 활용해 재생 보장.
class HeroHitFlash extends StatelessWidget {
  const HeroHitFlash({
    super.key,
    required this.element,
    required this.damage,
    required this.token,
  });

  final RuneElement element;
  final int damage;
  final HeroHitToken token;

  /// 피격 이미지 경로 조회.
  static String _assetFor(RuneElement e) =>
      // ignore: constant_conditional_used
      e == RuneElement.fire
      ? 'assets/images/hero/fire_damage_full.png'
      : e == RuneElement.grass
      ? 'assets/images/hero/grass_damage_full.png'
      : e == RuneElement.water
      ? 'assets/images/hero/water_damage_full.png'
      : e == RuneElement.light
      ? 'assets/images/hero/light_damage_full.png'
      : 'assets/images/hero/poison_damage_full.png';

  /// 피격 연출 총 길이 = [impactHold] + [fadeDuration].
  ///
  /// 예전 값(620ms)은 피격 이미지가 켜졌다 사라지는 걸 한 번도 못 따라갈 만큼
  /// 짧았다. 그 뒤 900ms 로 늘렸는데도 잘 안 보인다는 지적이 계속났다.
  /// 원인은 길이가 아니라 **모양**이었다. 아래 [opacityAt] 참고.
  static const Duration animDuration = Duration(milliseconds: 1150);

  /// 타격 직후 **완전 노출로 버티는** 시간.
  ///
  /// 선형 페이드는 타격 순간부터 바로 흐려져 "무슨 일이 있었는지"를 읽을
  /// 틈이 없다. 처음 200ms 는 1.0 을 유지해 타격이 눈에 박히게 만든다.
  static const Duration impactHold = Duration(milliseconds: 200);

  /// [impactHold] 이후 완전히 사라지는 데 걸리는 시간.
  static const Duration fadeDuration = Duration(milliseconds: 950);

  /// 데미지 숫자가 피격 이미지보다 더 오래 남는 시간.
  ///
  /// 이미지가 사라진 뒤 숫자만 잠깐 남아야 "얼마나 맞았는지"를 읽을 수 있다.
  static const Duration numberTail = Duration(milliseconds: 420);

  /// [animDuration] 중 완전 노출로 버티는 비율 ([impactHold] / [animDuration]).
  static const double _holdFraction = 0.174;

  /// 진행률(0~1) → 불투명도.
  ///
  /// **선형이 아니라 "유지 → ease-out" 이다.** 예전 구현은 `opacity: progress`
  /// (1 → 0 선형) 라서 900ms 중 앞 300ms 만에 이미 눈에 띄게 흐려지고,
  /// 체감상 스쳐 지나가는 빛깔처럼 보였다. 여기선 [_holdFraction] 까지 1.0 을
  /// 그대로 붙들고, 남은 구간에서만 `easeInCubic` 으로 서서히 지운다.
  ///
  /// 지연(시작이 늦어지는 느낌)은 주지 않는다 — 페이드는 타격과 **동시에**
  /// 시작해야 "지금 맞았다"가 읽힌다.
  static double opacityAt(double progress) {
    if (progress <= _holdFraction) return 1.0;
    final t = ((progress - _holdFraction) / (1 - _holdFraction)).clamp(0.0, 1.0);
    return 1.0 - Curves.easeInCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    if (damage <= 0) return const SizedBox.shrink();

    // 애니메이션 토큰이 바뀔 때마다 1회 재생되게 한다.
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        duration: animDuration,
        tween: Tween<double>(begin: 1, end: 0),
        builder: (context, progress, child) {
          // `Transform.scale` 을 쓰지 않는다. 이 [child] 는 [HeroPortrait] 와
          // 같은 정렬로 겹쳐진 전신 이미지라, 한 픽셀이라도 크기가 달라지면
          // 밑에 깔린 초상화와 어긋나 "떠오르는" 티가 남아 오히려 티끄럽다.
          // 타격감은 [_holdFraction] 만큼 버티는 것으로 대신한다.
          return Opacity(opacity: opacityAt(progress), child: child);
        },
        child: LayoutBuilder(
          builder: (context, constraints) => Image.asset(
            _assetFor(element),
            fit: BoxFit.cover,
            // **반드시** [HeroPortrait] 의 fullBody 정렬과 같은 값을 쓴다. 두
            // 이미지는 같은 규격(409×610 / 408×612)에 위쪽 투명 밴드만 2px 차이
            // 나므로, 정렬이 어긋나면 피격 프레임이 순간적으로 튀어 보인다.
            //
            // 근삿값을 쓰지 않고 여기서 슬롯 크기를 그대로 읽는다 — 부모가
            // `Positioned.fill` 이라 LayoutBuilder 제약이 곧 슬롯 치수다.
            alignment: HeroPortrait.alignmentForFullBody(
              element: element,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
            // 에셋 로드 실패 시 아무것도 안 냄 (러너 startup stutter 방지).
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 데미지 숫자(-N) 를 표시하는 위젯.
///
/// [HeroHitFlash] 와 함께 사용되며, 같은 [token] 을 공유해 연출이 일치한다.
///
/// **숫자는 영웅 얼굴 위에 뜬다.** 아래(발밑)에 띄우면 슬롯이 작을 때 HP 바와
/// 겹치고, 무엇보다 "얼굴이 어디 있는지"를 알려 주는 단서가 사라진다. 얼굴은
/// 어디까지나 사람이 읽는 중심이므로, 아프다는 신호도 같은 자리에 둔다.
class HeroDamageNumber extends StatelessWidget {
  const HeroDamageNumber({
    super.key,
    required this.damage,
    required this.token,
  });

  final int damage;
  final HeroHitToken token;

  /// 슬롯 높이의 몇 퍼센트 지점을 얼굴로 본다.
  ///
  /// 전신 이미지에서 머리는 세로 4~20% 에 있고, 슬롯 정렬이 밴드만 걷어내는
  /// [HeroPortrait.alignmentForFullBody] 기준으로 실제 얼굴은 대략
  /// 10~28% 부근에 놓인다. 20% 를 기준으로 잡으면 숫자가 이마~눈 높이에서 시작해
  /// 위로 떠오른다.
  static const double _faceFraction = 0.20;

  @override
  Widget build(BuildContext context) {
    if (damage <= 0) return const SizedBox.shrink();

    // "-5" 와 같은 포맷. red 색상에 그림자.
    final text = Text(
      '-$damage',
      style: const TextStyle(
        color: Color(0xFFFF6B6B), // 기존 보드 중앙 플로터와 동일한 색
        fontSize: 26,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Colors.black45, blurRadius: 5, offset: Offset(1, 1)),
        ],
      ),
    );

    // 토큰이 바뀔 때마다 위로 22px 상승하며 페이드아웃.
    // 페이드 길이는 [HeroHitFlash.animDuration] + [HeroHitFlash.numberTail] —
    // 이미지가 사라진 뒤에도 숫자가 좀 더 남아 "얼마나 맞았는지"를 읽을 시간을 준다.
    //
    // [Positioned.fill] 로 슬롯 전체를 덮는 이유는 하나다 — LayoutBuilder 의
    // 제약이 **슬롯 치수 그대로**여야 [_faceFraction] 이 "얼굴 위치"가 된다.
    // 느슨한 제약 아래에서는 maxHeight 가 0 이 될 수 있다.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: constraints.maxHeight * _faceFraction,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration:
                    HeroHitFlash.animDuration + HeroHitFlash.numberTail,
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, progress, child) {
                  return Opacity(
                    // 앞 16% 는 안 사라졌다가, 나머지 구간에 걸쳐 완전히 사라진다.
                    // 즉 [HeroHitFlash.animDuration] 시점에 이미 0 이 되어, 피격
                    // 이미지와 동시에 끝난다.
                    opacity: (1.0 - progress * 1.25).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -22 * progress),
                      child: child,
                    ),
                  );
                },
                child: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
