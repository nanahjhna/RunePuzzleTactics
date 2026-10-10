/// 영웅 개인 전투 스탯. 합산 파티 스탯 컨테이너는 삭제했다.
///
/// 상성 증폭/저항(`affinityBonus`/`affinityResistance`) 필드도 삭제했다. 몬스터가
/// 무속성이어서 이 값은 전투에서 항상 0 이었고, 상성은 이제 스테이지가 정한다
/// ([StageConfig.affinityFor]).
library;

import 'hero_pool.dart';
import 'rune_element.dart';

/// 영웅 1명의 **개인** 전투 스탯 (해당 영웅의 개별 강화 반영).
///
/// 전투 중 현재 HP 는 `PartyHeroUnit.hp` 가 들고 있다.
class HeroCombatStats {
  const HeroCombatStats({
    required this.heroId,
    required this.element,
    required this.hp,
    required this.attack,
    required this.defense,
  });

  /// 전역 고유 영웅 id.
  final String heroId;

  /// 속성 (상성 계산·시너지용).
  final RuneElement element;

  /// 이 영웅의 최대 HP.
  final int hp;

  /// 공격력. 매칭 데미지의 밑이 되고 스킬 수치 계산에도 쓰인다.
  final int attack;

  /// 방어력. 이 영웅이 몬스터 반격을 받을 때만 쓰인다.
  final int defense;
}

/// 스탯 가산치 컨테이너.
///
/// 예전엔 "파티 공통 보너스"였고 편성 N명에게 균등 분배됐지만, 파티 공통 보너스
/// 개념은 사라졌다. 지금은 **영웅 개별 강화 누적량**을 담는다
/// ([HeroStatUpgradeLevels] 이 만들어 준다) — 분배 과정이 없다.
class HeroStatBonuses {
  const HeroStatBonuses({this.hp = 0, this.attack = 0, this.defense = 0});

  final int hp;
  final int attack;
  final int defense;
}

/// [heroes] N명의 개인 기본치를 그대로 목록으로 만든다 (가산치 없음).
///
/// 예전에 파티 공통 보너스를 N명에게 균등 분배하던 함수였으나, 보너스 개념이
/// 사라지고 **영웅 개별 강화**로 옮겨 갔다. 이제 각 영웅의 강화 반영은
/// `RuneProgress.heroCombatStatsOf` 가 담당한다(분배할 필요가 없다).
List<HeroCombatStats> splitHeroStats(Iterable<RuneHeroDef> heroes) => [
  for (final h in heroes) plainHeroStats(h),
];

/// [hero] 의 강화 미반영 기본치를 [HeroCombatStats] 로 변환.
HeroCombatStats plainHeroStats(RuneHeroDef hero) => HeroCombatStats(
  heroId: hero.heroId,
  element: hero.element,
  hp: hero.hp,
  attack: hero.attack,
  defense: hero.defense,
);
