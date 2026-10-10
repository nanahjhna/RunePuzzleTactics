/// 튜토리얼 스크립트 정의 (RPT-418 ~ RPT-426)
/// - 레인보우/블랙/셔플 등 제거된 요소는 제외하고, 기본 3매치 슬라이드 가이드에 집중합니다.
/// - 인터랙티브 튜토리얼을 개편된 6개 섹션(단계)으로 구성합니다.
/// 각 섹션은 고유의 스크립트 보드([PuzzleBoard.fromRows])와 목표 판정([TutorialSection.isDone])을 가집니다.
/// 순수 Dart(화면/애니메이션 없음)로 구현해 결정성 테스트가 가능합니다.
/// 목표 판정은 배틀 상태(BattleState)만 바라본다 (RPT-126 단일 상태 원칙).
///
/// 튜토리얼 흐름:
///   1. 기본 3매치 → 공격
///   2. 속성 시너지 (유일한 속성 배율 축)
///   3. 콤보/캐스케이드
///   4. 몬스터 턴
///   5. 영웅 스킬 사용하기
///   6. 보스 승리
library;

import 'battle_engine.dart';
import 'battle_state.dart';
import 'puzzle_board.dart';
import 'puzzle_engine.dart';
import 'rune_element.dart';
import 'stage.dart';

/// 섹션 목표 판정 함수. [battle]의 최신 상태로 완료 여부를 판단한다.
typedef TutorialDone = bool Function(BattleEngine battle);

/// 튜토리얼 섹션 정의 (RPT-419).
class TutorialSection {
  const TutorialSection({
    required this.id,
    required this.title,
    required this.message,
    required this.boardRows,
    required this.stage,
    required this.isDone,
    this.hintMove,
    this.autoSwapMove,
  });

  final String id;
  final String title;
  final String message;

  /// 이 섹션 전용 스크립트 보드 (6×6, 문자 표기 F/G/W/L/P/B).
  final List<String> boardRows;

  final StageConfig stage;

  /// 안내용 추천 스왑 (from → to 인덱스).
  final PuzzleMove? hintMove;

  /// auto-swipe 연출 후 플레이어가 드래그하는 것을 유도하는 초기 스왑.
  /// 섹션 시작 시 engine.resolveSwap으로 연출한 뒤, player가 이를 이어가거나
  /// 첫 드래그가 이 move와 같도록 힌트를 주는 용도입니다.
  final PuzzleMove? autoSwapMove;

  final TutorialDone isDone;

  int get stepNumber {
    for (var i = 0; i < TutorialScript.sections.length; i++) {
      if (identical(TutorialScript.sections[i], this)) return i + 1;
    }
    return 0;
  }
}

/// 튜토리얼 스크립트 (RPT-420).
class TutorialScript {
  TutorialScript._();

  /// 튜토리얼 섹션 목록. Black/레인보우/셔플 관련 섹션은 제외하고
  /// 핵심 플레이 루프(3매치 → 콤보 → 몬스터 턴 → 영웅 스킬 → 보스 승리) 위주로 구성했습니다.
  static final List<TutorialSection> sections = [
    // 1. 기본 3매치 → 공격
    TutorialSection(
      id: 'match',
      title: '같은 룬 3개를 맞춰보세요',
      message:
          '보드에서 불(Fire) 룬 3개가 모아 있어요.\n'
          '룰을 옆/아래로 스와이프( 드래그 )하면 3개가 터지며 몬스터를 공격합니다!',
      boardRows: _fireBoard,
      stage: _stage(monsterHp: 9999),
      hintMove: const PuzzleMove(31, 32),
      autoSwapMove: const PuzzleMove(31, 32),
      isDone: _attackDone,
    ),
    // 2. 약점 속성
    //
    // 매칭 데미지의 밑은 **그 색 살아있는 영웅의 공격력 합**이다
    // ([BattleState.attackForElement]). 같은 색 영웅을 더 넣으면 그 합이 커져
    // 데미지가 자동으로 오른다 — 별도의 시너지 배율표가 없다.
    // [_stage] 는 약점을 Fire 로 잡으므로 이 단계의 Fire 매칭은 ×1.5 다.
    TutorialSection(
      id: 'affinity',
      title: '몬스터의 약점을 노리세요',
      message:
          '데미지는 "그 색 영웅의 공격력 합"에 콤보와 상성 배율을 곱한 값입니다.\n'
          '이번 몬스터는 불(Fire)에 약하므로 ×1.5 배가 붙습니다. '
          'Fire 3개를 터트려 보세요.',
      boardRows: _fireBoard,
      stage: _stage(monsterHp: 9999),
      hintMove: const PuzzleMove(31, 32),
      autoSwapMove: const PuzzleMove(31, 32),
      isDone: _attackDone,
    ),
    // 3. 콤보/캐스케이드
    TutorialSection(
      id: 'combo',
      title: '연쇄가 일어나면 콤보!',
      message:
          '매치 후 룬이 떨어지며 다시 3개가 모이면 COMBO!\n'
          '콤보는 데미지가 올라갑니다. 보드 위쪽 GGG를 남겨두고 스와이프해 보세요.',
      boardRows: _comboBoard,
      stage: _stage(monsterHp: 9999),
      hintMove: const PuzzleMove(16, 17),
      autoSwapMove: const PuzzleMove(16, 17),
      isDone: _comboDone,
    ),
    // 4. 몬스터 턴
    TutorialSection(
      id: 'monster',
      title: '턴이 끝나면 몬스터가 공격',
      message:
          '한 번의 스와이프 후 턴이 끝나면 몬스터가 공격합니다.\n'
          '내 체력(🛡 파티)이 깎이는 걸 확인해 보세요.',
      boardRows: _fireBoard,
      stage: _stage(monsterHp: 9999, monsterAttack: 6),
      hintMove: const PuzzleMove(31, 32),
      autoSwapMove: const PuzzleMove(31, 32),
      isDone: _partyDamaged,
    ),
    // 5. 영웅 스킬 사용하기
    TutorialSection(
      id: 'skill',
      title: '영웅 스킬 사용하기',
      message:
          '전투 중 영웅 초상화를 눌러 해당 영웅의 스킬을 사용할 수 있습니다.\n'
          '각 영웅은 스테이지당 1회, 내 턴마다 파티 전체에서 1회만 사용할 수 있습니다. 사용하면 몬스터가 반격합니다.',
      boardRows: _fireBoard,
      stage: _stage(monsterHp: 9999, monsterAttack: 6),
      hintMove: null,
      autoSwapMove: null,
      isDone: _heroSkillUsed,
    ),
    // 6. 보스 승리
    TutorialSection(
      id: 'boss',
      title: '마지막! 보스를 쓰러뜨리세요',
      message:
          '🔥 Fire 3개를 맞춰 보스를 격파하면 튜토리얼 완료!\n'
          '배틀 승리 시 Game Currency 보상을 얻고 다음 스테이지로 진행합니다.',
      boardRows: _fireBoard,
      // HP 는 **Fire 1회 매칭 피해에 맞춰** 잡는다.
      // fire_a ATK 15 × combo 1.0 × 약점 배율 1.5 = 22.5 → 23.
      // 캐스케이드가 붙으면 피해가 더 커지므로 한 번에 반드시 격파된다.
      stage: _stage(monsterHp: 20),
      hintMove: const PuzzleMove(31, 32),
      autoSwapMove: const PuzzleMove(31, 32),
      isDone: _victoryDone,
    ),
  ];

  // ── 스크립트 보드 ──

  /// 기본 안전 보드 (매치 없음) + Fire 3개 세로(col1, rows3~5) 생성용.
  static const List<String> _fireBoard = [
    'GWLPGW',
    'WGLWPG',
    'LWGPLG',
    'PFGWGL',
    'WFLGWP',
    'LGFWLP',
  ];

  /// 콤보 연습: row2 GGG(가로) 제거 → col0에 F가 쌓여 세로 3매치(연쇄).
  static const List<String> _comboBoard = [
    'FWLPGW',
    'FGLWPG',
    'GGGPLG',
    'FLGWGL',
    'WPLGWP',
    'LGPWLP',
  ];

  // ── 목표 판정 ──

  /// 일반 공격이 들어갔는가 (몬스터 HP 감소).
  static bool _attackDone(BattleEngine battle) =>
      battle.state.monsterHp < battle.state.monsterMaxHp;

  /// 콤보 ≥ 2 (캐스케이드 연쇄 발생).
  /// 마지막 해석의 연쇄 파도 수 기준.
  /// state.combo는 몬스터 턴 종료 시 0으로 리셋되므로 lastCascade로 판정한다 (RPT-81).
  static bool _comboDone(BattleEngine battle) =>
      (battle.lastCascade?.finalCombo ?? 0) >= 2;

  /// 파티가 피해를 입었는가 (몬스터 공격).
  static bool _partyDamaged(BattleEngine battle) =>
      battle.state.partyHp < battle.state.partyMaxHp;

  /// 영웅 스킬이 한 번 발동했는가.
  static bool _heroSkillUsed(BattleEngine battle) =>
      battle.state.units.any((unit) => unit.skillUsed);

  /// 보스 승리.
  static bool _victoryDone(BattleEngine battle) =>
      battle.state.phase == BattlePhase.victory;

  /// 섹션용 스테이지 설정 (몬스터 능력치 튜닝).
  ///
  /// 약점/열세 속성은 Fire / Grass 로 고정한다 — [_fireBoard] 로 teaches 하는
  /// 단계에서 설명과 실제 배율이 어긋나지 않게 하기 위해서다.
  /// (1스테이지 생성 규칙과도 일치한다: 약점 불 → 열세 풀.)
  static StageConfig _stage({
    required int monsterHp,
    int monsterAttack = 0,
    RuneElement weakElement = RuneElement.fire,
    RuneElement resistElement = RuneElement.grass,
  }) {
    return StageConfig(
      stageNumber: 1,
      type: StageType.normal,
      monsterHp: monsterHp,
      monsterAttack: monsterAttack,
      weakElement: weakElement,
      resistElement: resistElement,
      bossCountdown: 0,
      blackSpawnRate: 0, // 리필 시 Black 비생성 (스크립트 보드 유지)
      maxBlackOnBoard: 6,
      blackDamage: 10,
      goldReward: 0,
    );
  }
}
