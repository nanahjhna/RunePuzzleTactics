import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_helpers.dart';

void main() {
  final eng = PuzzleEngine();

  group('매치 / Swap', () {
    test('Swap으로 3매치 생성 → 1파도 해석 + 보드 완전 (RPT-76~79)', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(idx(board, 1, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.water));
      board.setIndex(idx(board, 3, 4), rune(RuneElement.fire));
      expect(eng.findMatches(board), isEmpty); // Swap 전 매치 없음

      final result = eng.resolveSwap(
        board,
        from: idx(board, 3, 4),
        to: idx(board, 3, 5),
      );
      expect(result.isEmpty, isFalse);
      expect(result.waves.first.waveNumber, 1);
      expect(result.waves.first.runs.single.length, 3);
      expect(board.isFull, isTrue);
    });

    test('무효 Swap: 보드 복원 + 빈 결과 (RPT-108)', () {
      final board = boardFromRows(cleanRows);
      final before = boardToString(board);
      final result = eng.resolveSwap(
        board,
        from: idx(board, 0, 0),
        to: idx(board, 1, 0),
      );
      expect(result.isEmpty, isTrue);
      expect(boardToString(board), before);
    });

    test('비인접 Swap: 무시 (영역 밖 포함)', () {
      final board = boardFromRows(cleanRows);
      final before = boardToString(board);
      final result = eng.resolveSwap(
        board,
        from: idx(board, 0, 0),
        to: idx(board, 1, 1),
      );
      expect(result.isEmpty, isTrue);
      expect(boardToString(board), before);
    });

    test('Cascade: 연쇄 파도에서 Combo 증가 (RPT-79~82)', () {
      final board = boardFromRows(cleanRows);
      // Swap 트리거: (0,5)↔(1,5) → 바닥 FFF (cols 1~3) 생성
      board.setIndex(idx(board, 0, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 1, 5), rune(RuneElement.water));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.fire));
      // 연쇄용: 계단형으로 매달린 F 3개 (cols 1~3, 낙하 경로를 비움)
      board.setIndex(idx(board, 1, 2), rune(RuneElement.fire));
      board.setIndex(idx(board, 1, 3), null);
      board.setIndex(idx(board, 1, 4), null);
      board.setIndex(idx(board, 2, 3), rune(RuneElement.fire));
      board.setIndex(idx(board, 2, 4), null);
      board.setIndex(idx(board, 3, 4), rune(RuneElement.fire));
      expect(eng.findMatches(board), isEmpty); // Swap 전 매치 없음

      final result = eng.resolveSwap(
        board,
        from: idx(board, 0, 5),
        to: idx(board, 1, 5),
      );
      expect(result.waves.length, greaterThanOrEqualTo(2));
      expect(result.waves.first.combo, 1);
      expect(result.waves[1].combo, 2); // 두 번째 파도 = Combo 2
    });

    test('findMatches 공개 API: 검출 결과', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(idx(board, 1, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 3, 5), rune(RuneElement.fire));
      final matches = eng.findMatches(board);
      expect(matches.single.length, 3);
      expect(matches.single.element, RuneElement.fire);
    });

    test('다음 수가 없는 보드는 자동 재배치해 계속 플레이할 수 있다', () {
      final board = boardFromRows(const [
        'FGWFGW',
        'GWFGWF',
        'WFGWFG',
        'FGWFGW',
        'GWFGWF',
        'WFGWFG',
      ]);
      expect(eng.findMatches(board), isEmpty);
      expect(eng.hasAvailableMove(board), isFalse);

      final result = eng.removeAndCascade(board, <int>{});

      expect(result.isEmpty, isTrue);
      expect(result.wasShuffled, isTrue);
      expect(eng.findMatches(board), isEmpty);
      expect(eng.hasAvailableMove(board), isTrue);
    });
  });

  group('스페셜 오브 (RPT-69 ~ RPT-72)', () {
    test('4매치 → Explosion Orb 3×3 제거', () {
      final board = boardFromRows(cleanRows);
      for (var x = 0; x < 4; x++) {
        board.setIndex(idx(board, x, 5), rune(RuneElement.fire));
      }
      final result = eng.removeAndCascade(board, <int>{});
      final w1 = result.waves.first;
      expect(w1.runs.single.length, 4);
      // 폭발 중심 = cells[3] = (3,5) → 3×3에 (2,4),(3,4),(4,4) 포함
      expect(w1.removedCells.contains(idx(board, 2, 4)), isTrue);
      expect(w1.removedCells.contains(idx(board, 3, 4)), isTrue);
      expect(w1.removedCells.contains(idx(board, 4, 4)), isTrue);
    });
  });

  group('Combo (RPT-85~88, RPT-124~126)', () {
    test('Normal 파도는 Combo 증가', () {
      final board = boardFromRows(cleanRows);
      board.setIndex(idx(board, 0, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 1, 5), rune(RuneElement.fire));
      board.setIndex(idx(board, 2, 5), rune(RuneElement.fire));
      final result = eng.removeAndCascade(board, <int>{});
      final w1 = result.waves.first;
      expect(w1.combo, 1);
    });
  });
}

// 작은 헬퍼 (테스트 가독성용)
int idx(PuzzleBoard b, int x, int y) => b.indexAt(x, y);
BoardTile rune(RuneElement e) => BoardTile.rune(e);
