import 'dart:math';

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_helpers.dart';

void main() {
  group('PuzzleBoard 생성', () {
    test('6×6 = 36칸 전부 채워짐', () {
      final board = PuzzleBoard.generate(rng: Random(1));
      expect(board.filledCount, PuzzleBoard.size);
      expect(board.isFull, isTrue);
    });

    test('초기 생성 보드에 3매치 없음 (여러 시드, RPT-68/169)', () {
      for (var seed = 0; seed < 50; seed++) {
        final board = PuzzleBoard.generate(
          rng: Random(seed),
          blackSpawnRate: 0.1,
        );
        // 가로
        for (var y = 0; y < PuzzleBoard.rows; y++) {
          var run = 1;
          for (var x = 1; x < PuzzleBoard.cols; x++) {
            final a = board.at(x - 1, y)?.rune;
            final b = board.at(x, y)?.rune;
            run = (a != null && a == b) ? run + 1 : 1;
            expect(run, lessThanOrEqualTo(2), reason: 'seed=$seed horizontal');
          }
        }
        // 세로
        for (var x = 0; x < PuzzleBoard.cols; x++) {
          var run = 1;
          for (var y = 1; y < PuzzleBoard.rows; y++) {
            final a = board.at(x, y - 1)?.rune;
            final b = board.at(x, y)?.rune;
            run = (a != null && a == b) ? run + 1 : 1;
            expect(run, lessThanOrEqualTo(2), reason: 'seed=$seed vertical');
          }
        }
      }
    });

    test('Black은 maxBlackOnBoard를 넘지 않음 (RPT-57/58)', () {
      final board = PuzzleBoard.generate(
        rng: Random(7),
        blackSpawnRate: 0.9,
        maxBlackOnBoard: 6,
      );
      expect(board.blackCount, lessThanOrEqualTo(6));
    });
  });

  group('보드 조작', () {
    test('인접 판정', () {
      final board = boardFromRows(cleanRows);
      expect(
        PuzzleBoard.isAdjacent(board.indexAt(0, 0), board.indexAt(1, 0)),
        isTrue,
      );
      expect(
        PuzzleBoard.isAdjacent(board.indexAt(0, 0), board.indexAt(0, 1)),
        isTrue,
      );
      expect(
        PuzzleBoard.isAdjacent(board.indexAt(0, 0), board.indexAt(1, 1)),
        isFalse,
      );
      expect(
        PuzzleBoard.isAdjacent(board.indexAt(0, 0), board.indexAt(0, 0)),
        isFalse,
      );
      expect(PuzzleBoard.isAdjacent(-1, 0), isFalse);
    });

    test('Swap 타일', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(
        board.indexAt(0, 0),
        const BoardTile.rune(RuneElement.fire),
      );
      expect(board.cell(board.indexAt(0, 0))?.rune, RuneElement.fire);
      board.swap(board.indexAt(0, 0), board.indexAt(1, 0));
      expect(board.cell(board.indexAt(1, 0))?.rune, RuneElement.fire);
    });

    test('boardToString / boardFromRows 왕복', () {
      final board = boardFromRows(cleanRows);
      expect(boardToString(board), cleanRows.join('\n'));
    });
  });
}
