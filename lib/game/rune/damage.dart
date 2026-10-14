/// 데미지 계산기.
///
/// 세 개의 축만 남긴다. 예전에 있던 **속성 시너지 배율**과
/// **영웅 개인 상성 증폭/저항**은 통째로 삭제했다.
///
/// - 시너지는 "그 속성 룬을 맞출 수 있는 영웅이 파티에 몇 명 있는가"를
///   배율표(0.6 ~ 1.6)로 옮기기만 해서 정보가 아니었다. 이제는 그 인원수의
///   **공격력 자체가** 데미지에 더해진다 ([BattleState.attackForElement]).
///   같은 계산을 두 번 하지 않는다.
/// - 몬스터는 무속성이므로 `affinityBonus`/`affinityResistance` 로 만들던
///   증폭·저항축은 **항상 0 이거나 항상 1.0 이었다**. 상성은 이제 몬스터가
///   아니라 **스테이지**가 정한다 ([StageConfig.affinityFor]).
///
/// ```
/// 매칭 데미지 = (매칭 속성의 살아있는 영웅 ATK 합) × 콤보 × 상성
/// 스킬 데미지 = (시전 영웅 개인 ATK)      × ratio × 상성
/// 반격 데미지 = max(1, round(몬스터ATK × 100 / (100 + 대상 DEF)))
/// ```
library;

/// 반격 피해 1건의 산출 내역 (결과 화면의 공식 캡션용).
class IncomingDamageResult {
  const IncomingDamageResult({
    required this.attack,
    required this.defense,
    required this.damage,
  });

  /// 몬스터 공격력.
  final int attack;

  /// 피격 대상 영웅의 개인 방어력.
  final int defense;

  /// 최종 피해. [DamageCalculator.incomingDamage] 규칙을 그대로 적용한 값.
  final int damage;

  /// 방어력 감쇄율 (0 ~ 1). 몬스터 공격력이 방어력에 눌려 얼마나 남았는가.
  double get remainingRatio => attack <= 0 ? 1.0 : 100 / (100 + defense);
}

/// 데미지 계산기. **상태를 hold하지 않는다** — 인스턴스를 만들어도 무방하다.
class DamageCalculator {
  const DamageCalculator();

  /// 콤보 배율 — `1.0 + 0.20 × (combo - 1)`, 최소 1.0.
  ///
  /// 0 이나 음수 콤보는 정의상 불가능하지만(콤보는 Wave 에서만 증가) 방어적으로
  /// 1.0 을 돌려준다.
  static double comboMultiplier(int combo) =>
      combo <= 1 ? 1.0 : 1.0 + 0.20 * (combo - 1);

  /// 룬 매칭 1그룹(런 1개)의 피해.
  ///
  /// [elementAttackSum] 은 **매칭한 룬과 같은 속성의 살아있는 영웅들의 ATK 합**
  /// ([BattleState.attackForElement]). 다른 색 룬을 맞추면 그 색 영웅의 공격력은
  /// 전혀 반영되지 않는다 — 그래서 "어떤 색을 몇 명이나 맞추느냐"가 곧 데미지다.
  ///
  /// [affinity] 는 [StageConfig.affinityFor] 가 낸 값(약점 1.5 / 중립 1.0 /
  /// 열세 0.5). 데미지 계산과 배율 표시가 **같은 값**을 내야 하므로 호출자가
  /// 한 번만 구해 넘긴다.
  int matchDamage({
    required int elementAttackSum,
    required int combo,
    required double affinity,
  }) => (elementAttackSum * comboMultiplier(combo) * affinity)
      .clamp(0, 0x7fffffff)
      .round();

  /// 몬스터 반격이 **떨어진 영웅 1명**에게 주는 피해 — 감쇄형 방어력.
  ///
  /// ```
  /// damage = max(1, round(몬스터ATK × 100 / (100 + 대상DEF)))
  /// ```
  ///
  /// 예전의 `ATK - DEF` 선형 차감은 탱커(DEF 18)의 데미지를 1 로 바닥내고,
  /// 약한 영웅(DEF 5)에게도 풀 데미지가 그대로 들어갔다. `100 / (100 + DEF)`
  /// 는 DEF 가 **비례 감쇄**로 작동하므로 두 문제가 동시에 사라진다.
  ///
  /// 방어자 스탯은 **영웅 개인값**이다 — 몬스터가 살아있는 영웅 한 명을 골라
  /// 때리기 때문이다. 최소 1 은 "반격을 맞았는데 아무도 안 다치는" 일이 없도록
  /// 하는 하한이다.
  IncomingDamageResult incomingDamage({
    required int attack,
    required int defenderDefense,
  }) {
    final ratio = 100 / (100 + defenderDefense);
    final damage = (attack * ratio).clamp(1, 0x7fffffff).round();
    return IncomingDamageResult(
      attack: attack,
      defense: defenderDefense,
      damage: damage,
    );
  }

  /// [incomingDamage] 의 [IncomingDamageResult.damage] 만 돌리는 편의 경로.
  int incomingDamageValue({
    required int attack,
    required int defenderDefense,
  }) => incomingDamage(attack: attack, defenderDefense: defenderDefense).damage;
}


