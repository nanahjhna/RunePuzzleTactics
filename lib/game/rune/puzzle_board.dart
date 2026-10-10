/// 6×6 퍼즐 보드 (RPT-65 ~ RPT-68, RPT-168 ~ RPT-170, 6×6 개편)
library;

import 'dart:math';
import 'rune_element.dart';

/// 보드 타일: 일반 Rune (Rainbow Orb 제거됨) + Explosion Orb (사양 결정 4).
class BoardTile {
  const BoardTile.rune(this.rune) : isExplosionOrb = false;

  /// Explosion Orb: Fire 영웅 스킬이 부여하는 특수 타일.
  /// 매칭에 포함되면 해당 칸 주변 3×3을 제거한다 (Normal 4 오브와 동일 규칙).
  const BoardTile.orb(this.rune) : isExplosionOrb = true;

  final RuneElement rune;

  /// 이 타일이 Explosion Orb인지.
  final bool isExplosionOrb;
}

/// 6×6 보드. Row-major 인덱스를 사용한다.
class PuzzleBoard {
  static const int rows = 6;
  static const int cols = 6;
  static const int size = rows * cols;

  final List<BoardTile?> _cells = List.filled(size, null);

  PuzzleBoard();

  /// 초기 보드 생성: 초기 3매치 없음 + Black 최대 개수 준수 (RPT-68, RPT-169, RPT-57/58).
  factory PuzzleBoard.generate({
    double blackSpawnRate = 0.05,
    int maxBlackOnBoard = 6,
    Random? rng,
  }) {
    final board = PuzzleBoard();
    board._fill(
      blackSpawnRate: blackSpawnRate,
      maxBlackOnBoard: maxBlackOnBoard,
      rng: rng,
    );
    return board;
  }

  /// 스크립트 보드 생성 (튜토리얼/연출용, RPT-405).
  ///
  /// 문자 표기: F=Fire, G=Grass, W=Water, L=Light, P=Poison,
  /// B=Black, '.' 또는 기타 = 빈칸.
  /// 테스트 헬퍼 `boardFromRows`와 동일 규약이다.
  factory PuzzleBoard.fromRows(List<String> rows) {
    final board = PuzzleBoard();
    for (var y = 0; y < rows.length && y < PuzzleBoard.rows; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length && x < PuzzleBoard.cols; x++) {
        board.setIndex(board.indexAt(x, y), switch (row[x]) {
          'F' => const BoardTile.rune(RuneElement.fire),
          'G' => const BoardTile.rune(RuneElement.grass),
          'W' => const BoardTile.rune(RuneElement.water),
          'L' => const BoardTile.rune(RuneElement.light),
          'P' => const BoardTile.rune(RuneElement.poison),
          'B' => const BoardTile.rune(RuneElement.black),
          _ => null,
        });
      }
    }
    return board;
  }

  BoardTile? cell(int i) => _cells[i];
  BoardTile? at(int x, int y) => inBounds(x, y) ? _cells[indexAt(x, y)] : null;
  void setIndex(int i, BoardTile? t) => _cells[i] = t;
  void set(int x, int y, BoardTile? t) {
    if (inBounds(x, y)) _cells[indexAt(x, y)] = t;
  }

  /// 셀을 복사한 새 보드 (시뮬레이션/테스트용, RPT-405).
  PuzzleBoard clone() {
    final b = PuzzleBoard();
    for (var i = 0; i < _cells.length; i++) {
      b._cells[i] = _cells[i];
    }
    return b;
  }

  int indexAt(int x, int y) => y * cols + x;
  bool inBounds(int x, int y) => x >= 0 && x < cols && y >= 0 && y < rows;

  /// 인접(상하좌우) 여부.
  static bool isAdjacent(int a, int b) {
    if (a < 0 || b < 0 || a >= size || b >= size) return false;
    final ax = a % cols, ay = a ~/ cols;
    final bx = b % cols, by = b ~/ cols;
    return (ax - bx).abs() + (ay - by).abs() == 1;
  }

  /// 중심 셀 주변 **3×3 영역** — 중심 + 주변 8칸, 보드 밖은 잘라낸다
  /// (RPT-70, 모서리 4칸 / 가장자리 6칸 / 중앙 9칸).
  ///
  /// 폭발 오브 매칭([PuzzleEngine])과 Light 영웅 스킬
  /// ([HeroSkillEffect.blastArea])이 **같은 규칙**을 공유한다. 여기서 한 번만
  /// 정의해야 규칙이 갈라지지 않는다.
  static Set<int> area3x3(int center) {
    final cx = center % cols;
    final cy = center ~/ cols;
    final result = <int>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final x = cx + dx, y = cy + dy;
        if (x >= 0 && x < cols && y >= 0 && y < rows) {
          result.add(y * cols + x);
        }
      }
    }
    return result;
  }

  /// [element] 룬이 놓인 칸 인덱스 목록.
  ///
  /// 폭발 오브 칸(`BoardTile.orb`)도 해당 요소로 센다 — 오브는 그 색 룬이며
  /// Water/Grass/Poison 스킬이 세는 대상이기 때문이다.
  List<int> indicesOf(RuneElement element) => [
    for (var i = 0; i < size; i++)
      if (_cells[i]?.rune == element) i,
  ];

  int get blackCount =>
      _cells.where((t) => t?.rune == RuneElement.black).length;
  int get filledCount => _cells.where((t) => t != null).length;
  bool get isFull => filledCount == size;

  /// Black 타일 인덱스 목록.
  List<int> get blackIndices => [
    for (var i = 0; i < size; i++)
      if (_cells[i]?.rune == RuneElement.black) i,
  ];

  /// Explosion Orb 타일 인덱스 목록 (Fire 영웅 스킬 결과물).
  List<int> get explosionOrbIndices => [
    for (var i = 0; i < size; i++)
      if (_cells[i]?.isExplosionOrb ?? false) i,
  ];

  /// 인덱스를 Explosion Orb로 변환한다. 빈칸/Black 지정은 무시된다.
  ///
  /// 이미 Orb인 칸은 그대로 둔다(중복 소모 방지).
  void markExplosionOrbs(Iterable<int> indices) {
    for (final i in indices) {
      if (i < 0 || i >= size) continue;
      final t = _cells[i];
      if (t == null || t.rune == RuneElement.black) continue;
      if (t.isExplosionOrb) continue;
      _cells[i] = BoardTile.orb(t.rune);
    }
  }

  void swap(int a, int b) {
    final t = _cells[a];
    _cells[a] = _cells[b];
    _cells[b] = t;
  }

  /// 디버그/테스트용 덤프. `.`=빈칸, 나머지는 이모지.
  String dump() {
    final buf = StringBuffer();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final t = at(x, y);
        if (t == null) {
          buf.write('. ');
        } else {
          buf.write('${t.rune.emoji} ');
        }
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ── 초기 생성 ──

  void _fill({
    required double blackSpawnRate,
    required int maxBlackOnBoard,
    Random? rng,
  }) {
    final r = rng ?? Random();
    for (var i = 0; i < size; i++) {
      final normals = _matchSafeNormals(i);
      final canBlack = _isBlackSafe(i) && blackCount < maxBlackOnBoard;
      if (canBlack && r.nextDouble() < blackSpawnRate) {
        _cells[i] = const BoardTile.rune(RuneElement.black);
      } else {
        _cells[i] = BoardTile.rune(normals[r.nextInt(normals.length)]);
      }
    }
  }

  /// (i-2, i-1) 가로 / (i-2rows, i-1rows) 세로 3매치를 만들지 않는 정상 Rune 목록.
  List<RuneElement> _matchSafeNormals(int i) {
    final left1 = i % cols >= 1 ? _cells[i - 1]?.rune : null;
    final left2 = i % cols >= 2 ? _cells[i - 2]?.rune : null;
    final up1 = i >= cols ? _cells[i - cols]?.rune : null;
    final up2 = i >= 2 * cols ? _cells[i - 2 * cols]?.rune : null;
    return [
      for (final e in RuneElement.normal)
        if (!(left1 == e && left2 == e) && !(up1 == e && up2 == e)) e,
    ];
  }

  bool _isBlackSafe(int i) {
    final left1 = i % cols >= 1 ? _cells[i - 1]?.rune : null;
    final left2 = i % cols >= 2 ? _cells[i - 2]?.rune : null;
    final up1 = i >= cols ? _cells[i - cols]?.rune : null;
    final up2 = i >= 2 * cols ? _cells[i - 2 * cols]?.rune : null;
    return !(left1 == RuneElement.black && left2 == RuneElement.black) &&
        !(up1 == RuneElement.black && up2 == RuneElement.black);
  }
}
