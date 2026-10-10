/// 스테이지 Config / Generator (RPT-172 ~ RPT-177, RPT-186)
library;

import 'dart:math';
import 'rune_element.dart';

/// 스테이지 종류 (RPT-173)
enum StageType { normal, elite, boss }

/// 스테이지별 밸런스 설정 (RPT-186).
///
/// 몬스터는 **무속성**이다. 그래도 상성은 있다 — 몬스터가 어느 속성인지가 아니라
/// **이 스테이지가 어느 속성에 약하고 어느 속성에 강한지**로 정한다.
class StageConfig {
  const StageConfig({
    required this.stageNumber,
    required this.type,
    required this.monsterHp,
    required this.monsterAttack,
    required this.weakElement,
    required this.resistElement,
    required this.bossCountdown,
    required this.blackSpawnRate,
    required this.maxBlackOnBoard,
    required this.blackDamage,
    required this.goldReward,
    this.bossUltimateDamage = 100,
    this.monsterName = 'Slime',
    this.subtitle = '',
  });

  final int stageNumber;
  final StageType type;
  final int monsterHp;
  final int monsterAttack;

  /// **약점 속성** — 이 속성 룬을 맞히면 데미지 ×1.5.
  final RuneElement weakElement;

  /// **열세 속성** — 이 속성 룬을 맞히면 데미지 ×0.5.
  final RuneElement resistElement;

  /// 매칭 속성 [atk] 의 상성 배율 — 상성 규칙의 단일 권위.
  ///
  /// ```
  /// 약점 속성 → 1.5 · 그 외 → 1.0 · 열세 속성 → 0.5
  /// ```
  ///
  /// 데미지 계산([DamageCalculator.matchDamage])과 UI 배율 표시가 **반드시 이
  /// 값을 그대로** 써야 한다. 두 곳이 따로 계산하면 표기가 어긋나고 플레이어는
  /// 숫자를 믿지 않게 된다.
  double affinityFor(RuneElement atk) {
    if (atk == weakElement) return weakAffinity;
    if (atk == resistElement) return resistAffinity;
    return neutralAffinity;
  }

  /// 매칭 속성 [atk] 가 이 몬스터의 약점인가 (UI 뱃지용).
  bool isWeakAgainst(RuneElement atk) => atk == weakElement;

  /// 약점 속성 배율.
  static const double weakAffinity = 1.5;

  /// 열세 속성 배율.
  static const double resistAffinity = 0.5;

  /// 그 외(무관) 배율.
  static const double neutralAffinity = 1.0;

  final int bossCountdown;

  /// 보스 궁극기 1회의 피해 (스테이지 비례).
  ///
  /// 예전엔 엔진에 고정 100 이 박혀 있었고 발동하면 **무조건 패배**였다. 이제는
  /// 스테이지가 값을 정하고, 엔진이 대상 최대 HP의 80% 로 상한을 둬 풀피 즉사를
  /// 막는다. 전멸했을 때만 패배한다.
  final int bossUltimateDamage;

  final double blackSpawnRate;
  final int maxBlackOnBoard;
  final int blackDamage;
  final int goldReward;

  /// 몬스터 표시 이름 (사양 결정 6: 전용 애니메이션 에셋 없이 텍스트로 다변화).
  /// 예: "Flame Drake", "Slime King". UI(배틀 HUD / 준비 모달 서브타틀)에서 노출.
  final String monsterName;

  /// 몬스터 한 줄 설명 (준비 모달 서브타틀, 예: "위험한 화염 몬스터의 둥지").
  final String subtitle;

  bool get isBoss => type == StageType.boss;
}

/// 사실상 Infinite Stage. 결정론적 생성 (RPT-172).
class StageGenerator {
  StageGenerator({
    this.baseHp = 120,
    this.baseAttack = 12,
    this.baseGold = 100,
    this.bossHpMultiplier = 2.0,
    double? blackSpawnRate,
  }) : blackSpawnRate = blackSpawnRate ?? 0.05;

  final int baseHp;
  final int baseAttack;
  final int baseGold;
  final double bossHpMultiplier;
  final double blackSpawnRate;

  /// Stage Rule: %10 == 0 → Boss, %5 == 0 → Elite, 그 외 Normal (RPT-174).
  static StageType typeFor(int stageNumber) {
    if (stageNumber % 10 == 0) return StageType.boss;
    if (stageNumber % 5 == 0) return StageType.elite;
    return StageType.normal;
  }

  // ── 스테이지 상성 배정 ──
  //
  // 몬스터에게 속성을 붙이지 않는 대신, **스테이지가 약점/열세 속성을 갖는다.**
  //
  // 보드는 5속성을 균등 생성하므로 스테이지마다 "이 색을 노려라"가 생기면 매칭
  // 속성이 진짜 선택지가 된다. 예전처럼 몬스터가 무속성이라 상성이 항상 1.0 이던
  // 상태에서는 어떤 색을 맞히든 결과가 같았다.
  //
  // 규칙은 **약점을 5단계 순환시키고 열세를 그 바로 다음 속성**으로 둔다:
  //
  /// ```
  /// stage  1   2      3     4      5     6      7 …
  /// 약점   🔥불  🌿풀  💧물  ⚡빛  ☠독  🔥불  🌿풀
  /// 열세   🌿풀  💧물  ⚡빛  ☠독  🔥불  🌿풀  💧물
  /// ```
  //
  /// 약점과 열세를 인덱스로 1 차이만 두는 게 핵심이다. 같은 속성에 ×1.5 와
  /// ×0.5 를 동시에 배정하면 규칙이 자기모순이 되어 코드가 어느 분기를 먼저 탈지
  /// 모른다. 보폭(b1, b2)을 따로 두는 방식(예: `n*b1 % 5`, `n*b2 % 5`)은
  /// **5 의 배수 스테이지에서 반드시 겹친다** — 두 식 모두 그 자리에서 0 이 되기
  /// 때문이다. 그래서 출발점을 1 어긋나게 두는 이 형태를 택했다. 겹치지 않음이
  /// 구조적으로 보장된다(`n-1 ≡ n (mod 5)` 는 해가 없다).
  //
  /// 주기는 5스테이지다. 5속성만 있으므로 그보다 긴 주기는 원천적으로 불가능하고,
  /// 결정론적 생성 규칙을 늘리기 위해 값을 지저분하게 굴릴 필요는 없다.

  /// 스테이지 번호 → 약점 속성 (이 속성 매칭은 ×1.5).
  static RuneElement weakElementFor(int stageNumber) {
    final n = stageNumber < 1 ? 0 : stageNumber;
    return RuneElement.normal[(n - 1) % RuneElement.normal.length];
  }

  /// 스테이지 번호 → 열세 속성 (이 속성 매칭은 ×0.5).
  ///
  /// 항상 [weakElementFor] 의 바로 다음 속성이다 — [RuneElement.normal] 순서
  /// (불 → 풀 → 물 → 빛 → 독) 기준.
  static RuneElement resistElementFor(int stageNumber) {
    final n = stageNumber < 1 ? 0 : stageNumber;
    return RuneElement.normal[n % RuneElement.normal.length];
  }

  // ── 몬스터 이름/설명 테이블 (사양 결정 6) ──
  // 전용 몬스터 애니메이션 에셋을 만들지 않고 텍스트로만 종류를 표현한다.
  //
  // **속성 키 → 스테이지 번호 기반 테이블.** 몬스터가 무속성이 되어 속성별 이름을
  // 쓸 근거가 사라졌으므로, "어느 속성인지"가 아니라 "몇 단계 몬스터인지"로
  // 이름이 결정된다 (결정론적, 저장/표시 흔들림 없음).

  /// 스테이지 번호 → 몬스터 기본 이름. 인덱스 = `(stageNumber-1) ~/ 5`.
  static const List<String> _monsterNames = [
    'Cave Slime',
    'Stone Maw',
    'Ancient Guardian',
    'Void Spawn',
  ];

  /// [_monsterNames] 와 같은 인덱스의 한 줄 설명 (준비 모달 서브타틀).
  static const List<String> _monsterSubtitles = [
    '동굴 바닥에 뭉쳐 사는 기본 몬스터',
    '움직임이 느리지만 벽 하나는 부수는 짐승',
    '오래된 유물과 함께 봉인되어 있던 수호자',
    '균열 너머에서 기어 나온 것인지부터 애매한 존재',
  ];

  /// 스테이지 종류 접두/접미 (이름 다변화).
  static const Map<StageType, String> _typeTitle = {
    StageType.normal: '',
    StageType.elite: 'Elite ',
    StageType.boss: 'Elder ',
  };

  /// 몬스터 표시 이름 결정 (결정론적: 스테이지 번호 + 종류만 사용).
  static String monsterNameFor(int stageNumber) {
    final base = _monsterNames[_nameIndex(stageNumber)];
    return '${_typeTitle[typeFor(stageNumber)]}$base';
  }

  /// 몬스터 서브타틀 결정.
  static String monsterSubtitleFor(int stageNumber) {
    final base = _monsterSubtitles[_nameIndex(stageNumber)];
    return switch (typeFor(stageNumber)) {
      StageType.boss => '$base — 보스',
      StageType.elite => '$base — 정예',
      StageType.normal => base,
    };
  }

  /// 스테이지 번호 → 이름 테이블 인덱스 (5스테이지마다 한 종류씩 교체).
  static int _nameIndex(int stageNumber) {
    final i = (stageNumber - 1) ~/ 5;
    return i < 0 ? 0 : i % _monsterNames.length;
  }

  StageConfig generate(int stageNumber) {
    final type = typeFor(stageNumber);
    final normalHp = (baseHp * pow(1 + stageNumber * 0.08, 1.15)).round();
    final monsterHp = type == StageType.boss
        ? (normalHp * bossHpMultiplier).round()
        : normalHp;
    final monsterAttack = (baseAttack * pow(1 + stageNumber * 0.06, 1.1))
        .round();
    final gold = (baseGold * (1 + stageNumber * 0.04)).round();

    return StageConfig(
      stageNumber: stageNumber,
      type: type,
      monsterHp: monsterHp,
      monsterAttack: monsterAttack,
      weakElement: weakElementFor(stageNumber),
      resistElement: resistElementFor(stageNumber),
      bossCountdown: type == StageType.boss ? 3 : 0,
      // 보스 궁극기 피해 = 보스 최대 HP의 25%. 스테이지가 오를수록 강해지지만
      // 엔진이 대상 최대 HP의 80% 로 상한을 둬 풀피 즉사는 없다.
      bossUltimateDamage: type == StageType.boss
          ? (monsterHp * 0.25).round()
          : 0,
      blackSpawnRate: blackSpawnRate,
      // RPT-57/58/198: Black은 기본 6, Boss는 7까지 허용 (Black 5 발동 가능성 유지)
      maxBlackOnBoard: type == StageType.boss ? 7 : 6,
      blackDamage: 10, // Playtest 기준값 (RPT-61)
      goldReward: gold,
      monsterName: monsterNameFor(stageNumber),
      subtitle: monsterSubtitleFor(stageNumber),
    );
  }
}
