/// 영웅 **레벨 / 경험치** 규격 (신규 성장 축).
///
/// 기존 성장 축은 두 가지였다:
///  - **유료 스탯 강화** ([HeroStatUpgrades]) — Game 재화로 HP/ATK/DEF 를 한 칸씩 산다.
///  - **등급(★)** ([HeroRarity]) — 중복 영입으로 승급 (현재 1성뿐).
///
/// 여기에 **전투를 이겨서 쌓이는 레벨**을 더한다. 레벨은 재화를 쓰지 않고 승리
/// 보상 EXP 로만 오르며, 오를 때마다 HP/ATK/DEF 가 자동으로 소폭 상승한다.
/// 유료 강화와는 **별개로 합산**된다(둘 중 하나를 대체하지 않는다).
///
/// 수치는 전부 이 파일 한 곳에 모았다 — 밸런스를 바꿀 때 화면/엔진을 건드리지
/// 않도록 하기 위함이다.
library;

import 'hero_stats.dart';
import 'stage.dart';

/// 영웅 레벨/경험치 공통 규칙.
class HeroLevel {
  HeroLevel._();

  /// 시작 레벨. 모든 영웅은 이 레벨로 태어난다(기록이 없으면 이 값).
  static const int minLevel = 1;

  /// 최대 레벨. 여기서 잠근다(무한 사다리 방지).
  ///
  /// 스테이지 상한([RuneMeta.maxStage] = 30)과 같은 값을 써서 "30 스테이지 =
  /// 30 레벨"이라는 리듬을 준다.
  static const int maxLevel = 30;

  /// 레벨당 자동 상승치 (강화 [HeroStatUpgrades] 와 별개 합산).
  ///
  /// Lv.30 기준 누적: HP +232 · ATK +29 · DEF +29.
  static const int hpPerLevel = 8;
  static const int attackPerLevel = 1;
  static const int defensePerLevel = 1;

  /// 중복 영입(뽑기) 1회가 기존 카드에 주는 레벨 상승량.
  ///
  /// 같은 영웅이 다시 나오면 그 영웅의 카드가 이만큼 레벨업한다(만렙이면 무효).
  /// 전투 EXP 와 별개로, 뽑기 중복을 성장 동력으로 되살리는 값이다.
  static const int levelsPerDuplicate = 1;

  /// [level] → `level + 1` 로 오르는 데 필요한 EXP.
  ///
  /// 선형 증가(레벨이 오를수록 조금씩 더 필요). Lv.1→2 = 50, Lv.29→30 = 750.
  static int expToNext(int level) {
    final from = level.clamp(minLevel, maxLevel);
    return 50 + (from - 1) * 25;
  }

  /// Lv.1 부터 [level] 까지 오르는 데 필요한 **누적** EXP (Lv.30 = 11,600).
  static int totalExpToReach(int level) {
    final target = level.clamp(minLevel, maxLevel);
    var sum = 0;
    for (var l = minLevel; l < target; l++) {
      sum += expToNext(l);
    }
    return sum;
  }

  /// [level] 이 주는 자동 스탯 보너스 (Lv.1 = 0).
  static HeroStatBonuses statBonusAt(int level) {
    final steps = level.clamp(minLevel, maxLevel) - minLevel;
    return HeroStatBonuses(
      hp: steps * hpPerLevel,
      attack: steps * attackPerLevel,
      defense: steps * defensePerLevel,
    );
  }

  /// 승리 시 **영웅 1명**이 받는 EXP (스테이지에 비례).
  ///
  /// 정예 ×1.5 · 보스 ×2 로 난이도 보상을 준다. Lv.1→2(50)는 1~2스테이지
  /// 승리로 오르고, 뒤로 갈수록 한 판이 여러 레벨을 밀어 준다.
  static int expForVictory(int stageNumber) {
    final n = stageNumber < 1 ? 1 : stageNumber;
    final base = 25 + n * 12;
    final mult = switch (StageGenerator.typeFor(n)) {
      StageType.boss => 2.0,
      StageType.elite => 1.5,
      StageType.normal => 1.0,
    };
    return (base * mult).round();
  }
}

/// 레벨업 1건 — 전투 결과 화면의 "레벨 업" 알림이 소비한다.
class HeroLevelUp {
  const HeroLevelUp({
    required this.heroId,
    required this.fromLevel,
    required this.toLevel,
  });

  final String heroId;
  final int fromLevel;
  final int toLevel;

  /// 이번에 오른 레벨 수 (여러 레벨이 한 번에 오를 수 있다).
  int get levelsGained => toLevel - fromLevel;
}
