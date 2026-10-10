/// Rune Puzzle 테스트 공용 헬퍼 (테스트 전용).
///
/// 문자 표기: F=Fire, G=Grass, W=Water, L=Light, P=Poison, B=Black, .=빈칸
library;

import 'dart:math';

import 'package:rune_puzzle_tactics/game/rune.dart';

/// 문자열 행 배열로 보드 제작 (row-major, 6자/행 권장, 초과분은 잘림).
PuzzleBoard boardFromRows(List<String> rows) {
  final board = PuzzleBoard();
  for (var y = 0; y < rows.length && y < PuzzleBoard.rows; y++) {
    final row = rows[y];
    for (var x = 0; x < row.length && x < PuzzleBoard.cols; x++) {
      final tile = switch (row[x]) {
        'F' => const BoardTile.rune(RuneElement.fire),
        'G' => const BoardTile.rune(RuneElement.grass),
        'W' => const BoardTile.rune(RuneElement.water),
        'L' => const BoardTile.rune(RuneElement.light),
        'P' => const BoardTile.rune(RuneElement.poison),
        'B' => const BoardTile.rune(RuneElement.black),
        _ => null,
      };
      board.setIndex(board.indexAt(x, y), tile);
    }
  }
  return board;
}

/// 보드를 문자 문자열로 변환 (boardFromRows의 역).
String boardToString(PuzzleBoard board) {
  final buf = StringBuffer();
  for (var y = 0; y < PuzzleBoard.rows; y++) {
    for (var x = 0; x < PuzzleBoard.cols; x++) {
      final t = board.at(x, y);
      buf.write(switch (t) {
        null => '.',
        BoardTile(rune: final r) => _char(r),
      });
    }
    if (y < PuzzleBoard.rows - 1) buf.writeln();
  }
  return buf.toString();
}

String _char(RuneElement e) => switch (e) {
  RuneElement.fire => 'F',
  RuneElement.grass => 'G',
  RuneElement.water => 'W',
  RuneElement.light => 'L',
  RuneElement.poison => 'P',
  RuneElement.black => 'B',
};

/// 3매치가 없는 깨끗한 6×6 보드 (엔진 테스트 기반).
/// F=Fire, G=Grass, W=Water, L=Light, P=Poison 순환으로 매치를 피한다.
const List<String> cleanRows = [
  'GWLPGW',
  'WGLWPG',
  'LWGPLG',
  'PLGWGL',
  'WPLGWP',
  'LGPWLP',
];

/// 기본 스테이지 (테스트용). [stageNumber], [type], [weakElement] 등 재정의 가능.
///
/// 기본 상성은 Fire 약점 / Water 열세다 — 매칭 데미지 배율이 1.0 이 되므로
/// "디미지 = 그 색 ATK 합 × 콤보"를 그대로 검증하기 좋다.
StageConfig testStage({
  int stageNumber = 1,
  StageType type = StageType.normal,
  int monsterHp = 1000,
  int monsterAttack = 10,
  RuneElement weakElement = RuneElement.fire,
  RuneElement resistElement = RuneElement.water,
  int bossCountdown = 0,
  double blackSpawnRate = 0.05,
  int maxBlackOnBoard = 6,
  int blackDamage = 10,
  int goldReward = 100,
}) {
  return StageConfig(
    stageNumber: stageNumber,
    type: type,
    monsterHp: monsterHp,
    monsterAttack: monsterAttack,
    weakElement: weakElement,
    resistElement: resistElement,
    bossCountdown: bossCountdown,
    blackSpawnRate: blackSpawnRate,
    maxBlackOnBoard: maxBlackOnBoard,
    blackDamage: blackDamage,
    goldReward: goldReward,
  );
}

/// 지정한 보드/스테이지로 BattleEngine 구성 (테스트 전용).
BattleEngine battleWithBoard({
  required PuzzleBoard board,
  StageConfig? stage,
  HeroRoster? roster,
  int baseAttack = 100,
  int partyMaxHp = 100,
  Random? rng,
}) {
  final s = stage ?? testStage();
  final r = roster ?? HeroRoster.initial();
  final engine = PuzzleEngine(
    rng: rng,
    blackSpawnRate: s.blackSpawnRate,
    maxBlackOnBoard: s.maxBlackOnBoard,
  );
  final state = BattleState(
    stage: s,
    party: r,
    board: board,
    partyMaxHp: partyMaxHp,
    baseAttack: baseAttack,
  );
  return BattleEngine(
    state: state,
    engine: engine,
    damageCalc: const DamageCalculator(),
    blackCalc: BlackDamageCalculator(),
  );
}
