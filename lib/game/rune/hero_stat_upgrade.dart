/// 영웅 **개별** 스탯 강화 정의.
///
/// 예전에는 마도서([BookUpgrade]) + 파티 공통 보너스로 "파티 전체가 똑같이
/// 강해지는" 축만 있었다. 파티 공통 보너스는 편성 N명에게 균등 분배되므로
/// 영웅마다 기여도가 1/N 으로 희석됐다. 이제 강화는 **영웅 한 명씩** 한다 —
/// 이 파일이 그 규격이다.
///
/// 수치는 전부 여기 한 곳에 모았다 (프롬프트 §29 계열). 화면/위젯에서 규격을
/// 흩뜨리지 말고 이 테이블만 고치면 되게 하는 것이 목적이다.
library;

import 'hero_stats.dart';

/// 강화 가능한 영웅 스탯.
///
/// 상성(affinity) 두 종은 넣지 않는다. 배틀에서 몬스터가 **무속성**이라
/// 저항은 사실상 무효이고, 보너스도 값이 12/18/22/26 처럼 커서
/// "얼마를 썼더니 몇이 올랐나" 가 읽히지 않는다.
enum HeroStatKind { hp, attack, defense }

/// 스탯 1종의 강화 규격: 레벨당 증가량 + 기본가 + 최대 레벨.
class HeroStatUpgradeConfig {
  const HeroStatUpgradeConfig({
    required this.kind,
    required this.increase,
    required this.baseCost,
    required this.maxLevel,
  });

  final HeroStatKind kind;

  /// 레벨당 증가량.
  ///
  /// HP 는 +10. 마도서는 +100 이었지만 그건 **파티 4명이 나눠 가진** 값이라
  /// 1인당 +25 에 해당했고, 그것도 무제한이었다. 영웅 1인 기준으로 낮춘다.
  final int increase;

  /// 1레벨 구매가. 실제 가격은 [costForLevel] 이 레벨별로 올린다.
  ///
  /// 클리어 보상(`StageConfig.goldReward` = 100 × (1 + 스테이지 × 0.04)) 1회분
  /// 으로 잡았다. 초기 재화가 0 이라 첫 강화가 목표가 되는 걸 막아 준다.
  final int baseCost;

  /// 최대 레벨. 여기서 잠근다 (무한 사다리 방지).
  final int maxLevel;

  /// [currentLevel] → [currentLevel + 1] 올리는 비용. 최대 레벨이면 0 (구매 불가 의미).
  int costForLevel(int currentLevel) {
    final next = currentLevel + 1;
    if (next < 1 || next > maxLevel) return 0;
    return baseCost * next;
  }

  /// [level] 까지 올렸을 때의 누적 증가량.
  ///
  /// `clamp` 가 `num` 을 돌려줘서 `increase` 와 곱하면 `num` 이 되므로
  /// `toInt()` 로 떨어야 한다 — 안 하면 누적값이 double 이 되어
  /// [HeroCombatStats] 의 int 필드에 못 들어간다.
  int totalAtLevel(int level) {
    if (level <= 0) return 0;
    return increase * level.clamp(0, maxLevel).toInt();
  }
}

/// 영웅 개별 강화 정의 테이블.
class HeroStatUpgrades {
  HeroStatUpgrades._();

  static const HeroStatUpgradeConfig hp = HeroStatUpgradeConfig(
    kind: HeroStatKind.hp,
    increase: 10,
    baseCost: 100,
    maxLevel: 20,
  );

  static const HeroStatUpgradeConfig attack = HeroStatUpgradeConfig(
    kind: HeroStatKind.attack,
    increase: 1,
    baseCost: 150,
    maxLevel: 20,
  );

  static const HeroStatUpgradeConfig defense = HeroStatUpgradeConfig(
    kind: HeroStatKind.defense,
    increase: 1,
    baseCost: 150,
    maxLevel: 20,
  );

  /// 화면 노출 순서 (HP → ATK → DEF).
  static const List<HeroStatUpgradeConfig> all = [hp, attack, defense];

  static HeroStatUpgradeConfig of(HeroStatKind kind) => switch (kind) {
    HeroStatKind.hp => hp,
    HeroStatKind.attack => attack,
    HeroStatKind.defense => defense,
  };
}

/// 영웅 한 명의 강화 누적량을 담은 보너스.
///
/// 파티 공통 보너스가 사라졌으므로 분배 과정이 없다 — 이 값을 영웅 개인 기본치에
/// 더하면 그 영웅의 최종 전투 스탯이 된다.
class HeroStatUpgradeLevels {
  const HeroStatUpgradeLevels(this.levels);

  /// 스탯 → 누적 레벨. 없는 항목은 0으로 본다.
  final Map<HeroStatKind, int> levels;

  static const empty = HeroStatUpgradeLevels({});

  int levelOf(HeroStatKind kind) => levels[kind] ?? 0;

  /// 누적 HP 증가량.
  int get hp => HeroStatUpgrades.hp.totalAtLevel(levelOf(HeroStatKind.hp));

  /// 누적 공격력 증가량.
  int get attack =>
      HeroStatUpgrades.attack.totalAtLevel(levelOf(HeroStatKind.attack));

  /// 누적 방어력 증가량.
  int get defense =>
      HeroStatUpgrades.defense.totalAtLevel(levelOf(HeroStatKind.defense));

  /// 이 보너스를 [HeroStatBonuses] 로 변환 (전투 스탯 조립용).
  HeroStatBonuses toBonuses() =>
      HeroStatBonuses(hp: hp, attack: attack, defense: defense);

  /// 레벨 1을 올린 새 인스턴스.
  HeroStatUpgradeLevels bumped(HeroStatKind kind) {
    final next = Map<HeroStatKind, int>.of(levels);
    final maxLevel = HeroStatUpgrades.of(kind).maxLevel;
    next[kind] = (levelOf(kind) + 1).clamp(0, maxLevel).toInt();
    return HeroStatUpgradeLevels(next);
  }
}
