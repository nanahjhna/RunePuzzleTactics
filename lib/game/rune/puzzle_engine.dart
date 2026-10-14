/// 순수 Dart 퍼즐 엔진 (RPT-79 ~ RPT-82, RPT-114 ~ RPT-131)
///
/// Animation/UI에 의존하지 않고 Match/Cascade/Special을 계산한다.
/// Resolve-first / Animate-second 원칙의 계산 계층 (RPT-112, RPT-116, RPT-132).
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'puzzle_board.dart';
import 'rune_element.dart';

/// Match 발생 원인 (RPT-49, RPT-52)
enum MatchSource { direct, cascade }

/// 한 번의 Swap 입력.
class PuzzleMove {
  const PuzzleMove(this.from, this.to);

  final int from;
  final int to;
}

/// 한 Match Wave의 연속된 동일 Rune 그룹 (RPT-76 ~ RPT-80).
class MatchRun {
  MatchRun(this.element, this.cells, {required this.horizontal});

  final RuneElement element;
  final List<int> cells;
  final bool horizontal;

  int get length => cells.length;
}

/// 한 Cascade Wave의 결과.
class WaveResult {
  WaveResult({
    required this.waveNumber,
    required this.combo,
    required this.runs,
    required this.removedCells,
    this.boardAfter,
  });

  /// 직접 Swap Wave = 1 (RPT-77), 이후 2, 3, ...
  final int waveNumber;

  /// 이 Wave의 Combo 값.
  ///
  /// 이번 Wave 에서 맞힌 **서로 다른 색의 수**만큼 오른다 — 한 턴에 두 색을 맞추면
  /// 2콤보다(요구사항 7).
  final int combo;

  final List<MatchRun> runs;
  final Set<int> removedCells;

  /// 이 Wave 해석(제거+중력+리필) 직후의 보드 상태.
  /// UI(Flame)가 연쇄 파도별로 "플래시→낙하→대기"를 재생할 때
  /// 중간 배치를 그릴 수 있도록 제공한다 (RPT-116 개편).
  final PuzzleBoard? boardAfter;
}

/// 하나의 퍼즐 입력에 대한 전체 Cascade 결과.
class CascadeResult {
  CascadeResult._(this.waves, this.board);

  final List<WaveResult> waves;
  final PuzzleBoard board;
  bool wasShuffled = false;

  bool get isEmpty => waves.isEmpty;
  int get finalCombo => waves.isEmpty ? 0 : waves.last.combo;

  void markShuffled() => wasShuffled = true;
}

class PuzzleEngine {
  PuzzleEngine({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  /// 현재 보드의 매치 검출 (테스트/UI 하이라이트용 공개 API).
  List<MatchRun> findMatches(PuzzleBoard board) => _detectMatches(board);

  /// 안정된 보드에 매치를 만들 수 있는 인접 Swap이 하나라도 있는지 확인한다.
  bool hasAvailableMove(PuzzleBoard board) {
    for (var i = 0; i < PuzzleBoard.size; i++) {
      final x = i % PuzzleBoard.cols;
      final y = i ~/ PuzzleBoard.cols;
      for (final neighbor in [
        if (x + 1 < PuzzleBoard.cols) i + 1,
        if (y + 1 < PuzzleBoard.rows) i + PuzzleBoard.cols,
      ]) {
        board.swap(i, neighbor);
        final createsMatch = _detectMatches(board).isNotEmpty;
        board.swap(i, neighbor);
        if (createsMatch) return true;
      }
    }
    return false;
  }

  /// Swap 해석. 무효 Swap이면 보드를 복원하고 빈 결과를 돌려준다 (RPT-108).
  ///
  /// [board]는 성공 시 최종 상태로 갱신된다.
  CascadeResult resolveSwap(
    PuzzleBoard board, {
    required int from,
    required int to,
  }) {
    if (!PuzzleBoard.isAdjacent(from, to)) {
      return CascadeResult._(<WaveResult>[], board);
    }
    board.swap(from, to);
    if (_detectMatches(board).isEmpty) {
      board.swap(from, to); // Reverse (RPT-108)
      return CascadeResult._(<WaveResult>[], board);
    }
    return _resolveWaves(board);
  }

  /// 임의 제거 후 Gravity → Refill → Cascade (스킬 효과 공용).
  ///
  /// [board]는 최종 상태로 갱신된다.
  CascadeResult removeAndCascade(PuzzleBoard board, Set<int> initialRemoval) {
    _applyRemoval(board, initialRemoval);
    _gravity(board);
    _refill(board);
    return _resolveWaves(board);
  }

  /// **제거 없이** 이미 성립한 매칭만 잇는다 (Gravity/Refill 없음).
  ///
  /// [removeAndCascade] 는 "뺀 칸을 채우고 연쇄를 잇는다"가 전제라, 첫 파도
  /// 전에 낙하/리필을 한 번 돌린다. 그래서 **칸을 하나도 안 지운 효과**에는
  /// 쓸 수 없다 — 사용하지 않으면 다음 두 가지가 함께 망가진다.
  ///
  ///  - 변환으로 만들어진 불 3+가 **인식되지 않는다.** 플레이어는 "불이 됐는데
  ///    아무 일도 안 일어나지?"로 읽는다. (실제 버그 보고)
  ///  - 보드에 이미 매칭이 남아 있으면 아무 효과 없이 **다음 입력에서 터진다.**
  ///    스킬을 쓴 사람이 아니라 다음에 룬을 움직인 사람이 파임을 받는다.
  ///
  /// [resolveSwap] 과 [_resolveWaves] 를 그대로 쓰되 낙하/리필을 건너뛴다.
  /// 변환은 칸을 "제거"하지 않으므로 보드 밀도가 그대로다 — 밀도가 변하는
  /// 효과([removeAndCascade])에만 낙하가 필요하고, 여기서는 필요 없다.
  CascadeResult cascadeExistingMatches(PuzzleBoard board) =>
      _resolveWaves(board);

  /// 타일을 재배열해 즉시 매치가 없고 유효한 다음 수가 있는 배치를 만든다.
  ///
  /// [board]는 최종 상태로 갱신된다. 타일 구성(개수)은 유지된다.
  void shuffleBoard(PuzzleBoard board) {
    final tiles = <BoardTile?>[
      for (var i = 0; i < PuzzleBoard.size; i++) board.cell(i),
    ];

    // 매치가 없고 다음 수가 하나 이상 있는 배치를 만든다.
    for (var attempt = 0; attempt < 512; attempt++) {
      final pool = [for (final t in tiles) t]..shuffle(_rng);
      final out = PuzzleBoard();
      var pi = 0;
      var failed = false;
      for (var i = 0; i < PuzzleBoard.size; i++) {
        if (tiles[i] == null) {
          out.setIndex(i, null);
          continue;
        }
        int? chosen;
        for (var j = pi; j < pool.length; j++) {
          final t = pool[j];
          if (t != null && _tilePlacementSafe(out, i, t)) {
            chosen = j;
            break;
          }
        }
        if (chosen == null) {
          failed = true;
          break;
        }
        out.setIndex(i, pool[chosen]);
        pool[chosen] = null;
      }
      if (!failed && _detectMatches(out).isEmpty && hasAvailableMove(out)) {
        for (var i = 0; i < PuzzleBoard.size; i++) {
          board.setIndex(i, out.cell(i));
        }
        return;
      }
    }

    throw StateError('Unable to shuffle the board into a playable layout.');
  }

  /// [out]의 이미 배치된 (i-2, i-1) 가로 / (i-2rows, i-1rows) 세로와
  /// 3매치를 만들지 않는 [t] 배치 가능 여부.
  bool _tilePlacementSafe(PuzzleBoard out, int i, BoardTile t) {
    final e = t.rune;
    final x = i % PuzzleBoard.cols;
    final y = i ~/ PuzzleBoard.cols;
    if (x >= 2) {
      final l1 = out.at(x - 1, y)?.rune;
      final l2 = out.at(x - 2, y)?.rune;
      if (l1 == e && l2 == e) return false;
    }
    if (y >= 2) {
      final u1 = out.at(x, y - 1)?.rune;
      final u2 = out.at(x, y - 2)?.rune;
      if (u1 == e && u2 == e) return false;
    }
    return true;
  }

  // ── 내부 ──

  /// Player Swap 해석(공용): 캐스케이드 전 Wave를 계산한다.
  CascadeResult _resolveWaves(PuzzleBoard board) {
    final waves = <WaveResult>[];
    var combo = 0;
    var waveNumber = 0;

    while (true) {
      final matches = _detectMatches(board);
      if (matches.isEmpty) break;
      waveNumber++;

      // 이번 Wave 에서 맞힌 색 수만큼 콤보가 오른다 (요구사항 7).
      combo += _comboGain(matches);
      final waveCombo = combo;

      final removed = <int>{};

      for (final m in matches) {
        removed.addAll(m.cells);

        if (m.length == 4) {
          // Normal 4: Explosion Orb → 3×3 제거 (RPT-69 ~ RPT-72)
          removed.addAll(_area3x3(board, m.cells[3]));
        }
        // Normal 5+: 특수 오브 없음 — 매치된 타일만 제거.

        // Fire 스킬이 부여한 Explosion Orb가 매칭에 포함되면 3×3 추가 제거.
        // 오브 칸이 run 어디에 있든 해당 칸을 중심으로 확장한다.
        for (final c in m.cells) {
          if (board.cell(c)?.isExplosionOrb ?? false) {
            removed.addAll(_area3x3(board, c));
          }
        }
      }

      _applyRemoval(board, removed);
      _gravity(board);
      _refill(board);

      waves.add(
        WaveResult(
          waveNumber: waveNumber,
          combo: waveCombo,
          runs: matches,
          removedCells: removed,
          boardAfter: board.clone(),
        ),
      );
    }

    final result = CascadeResult._(waves, board);
    if (!hasAvailableMove(board)) {
      shuffleBoard(board);
      result.markShuffled();
    }
    return result;
  }

  /// 이 Wave에서 상승하는 콤보량 (요구사항 7).
  ///
  /// **이번 Wave 에서 맞힌 색 수만큼** 오른다.
  ///
  /// 단, 같은 색 런이 여러 개면 **색 1개**로 센다. L/T 모양은 가로 런과 세로 런으로
  /// 두 번 잡히지만 플레이어 관점엔 한 덩어리라 1콤보가 맞다. 그래서 런 개수가 아니라
  /// **중복 없는 속성 수**를 센다.
  int _comboGain(List<MatchRun> matches) {
    var gain = 0;
    final counted = <RuneElement>{};
    for (final m in matches) {
      if (counted.add(m.element)) gain++;
    }
    return gain;
  }

  List<MatchRun> _detectMatches(PuzzleBoard board) {
    final runs = <MatchRun>[];

    // 가로 스캔
    for (var y = 0; y < PuzzleBoard.rows; y++) {
      var x = 0;
      while (x < PuzzleBoard.cols) {
        final t = board.at(x, y);
        if (t == null) {
          x++;
          continue;
        }
        var end = x + 1;
        while (end < PuzzleBoard.cols) {
          final nt = board.at(end, y);
          if (nt == null || nt.rune != t.rune) break;
          end++;
        }
        if (end - x >= 3) {
          runs.add(
            MatchRun(t.rune, [
              for (var i = x; i < end; i++) board.indexAt(i, y),
            ], horizontal: true),
          );
        }
        x = end;
      }
    }

    // 세로 스캔
    for (var x = 0; x < PuzzleBoard.cols; x++) {
      var y = 0;
      while (y < PuzzleBoard.rows) {
        final t = board.at(x, y);
        if (t == null) {
          y++;
          continue;
        }
        var end = y + 1;
        while (end < PuzzleBoard.rows) {
          final nt = board.at(x, end);
          if (nt == null || nt.rune != t.rune) break;
          end++;
        }
        if (end - y >= 3) {
          runs.add(
            MatchRun(t.rune, [
              for (var j = y; j < end; j++) board.indexAt(x, j),
            ], horizontal: false),
          );
        }
        y = end;
      }
    }

    return runs;
  }

  void _applyRemoval(PuzzleBoard board, Set<int> cells) {
    for (final i in cells) {
      board.setIndex(i, null);
    }
  }

  void _gravity(PuzzleBoard board) {
    for (var c = 0; c < PuzzleBoard.cols; c++) {
      final stack = <BoardTile>[];
      for (var y = PuzzleBoard.rows - 1; y >= 0; y--) {
        final t = board.cell(board.indexAt(c, y));
        if (t != null) stack.add(t);
      }
      for (var y = PuzzleBoard.rows - 1; y >= 0; y--) {
        board.setIndex(
          board.indexAt(c, y),
          stack.isNotEmpty ? stack.removeAt(0) : null,
        );
      }
    }
  }

  /// Refill: 빈 칸을 정상 Rune으로 채운다 (RPT-170).
  void _refill(PuzzleBoard board) {
    for (var i = 0; i < PuzzleBoard.size; i++) {
      if (board.cell(i) != null) continue;
      board.setIndex(
        i,
        BoardTile.rune(
          RuneElement.normal[_rng.nextInt(RuneElement.normal.length)],
        ),
      );
    }
  }

  /// 중심 셀 주변 3×3 영역 (RPT-70).
  ///
  /// 정본은 [PuzzleBoard.area3x3] 이다 — Light 영웅 스킬이 같은 규칙을 쓰므로
  /// 여기선 위임만 한다.
  Set<int> _area3x3(PuzzleBoard board, int center) =>
      PuzzleBoard.area3x3(center);
}
