/// Rune 진행도 저장소 — SQLite 구현 (PHASE 8, RPT-316 확장).
///
///SharedPreferences 대신 SQLite([sqflite] + [path_provider])를 로컬 퍼시스턴스로 사용한다.
/// - 기존 SharedPreferences `rune_progress_v1` 데이터는 첫 로드 시 SQLite로 마이그레이션.
/// - [RuneProgressStore] 인터페이스는 `game/rune/rune_progress.dart`에서 정의되며,
///   여기서 구현체를 제공한다.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:rune_puzzle_tactics/game/rune.dart';

// RuneProgressStore는 game/rune/rune_progress.dart에서 정의된 인터페이스를 사용.

/// @nodoc
class SqliteRuneProgressStore implements RuneProgressStore {
  // ignore: prefer_initializing_formals
  SqliteRuneProgressStore({String? dbPath}) : _dbPath = dbPath;

  final String? _dbPath;

  /// DB 파일 경로 결정: 인자가 있으면 그대로 사용, 없으면
  /// 문서 디렉터리에 실제 DB **파일명**을 붙여 반환한다.
  ///
  /// (수정 전: 디렉터리 경로를 그대로 반환해 [openDatabase]가 폴더를
  /// DB 파일로 열려고 해서 로드가 실패했음 — Android에서 EISDIR 오류.)
  Future<String> _getDbPath() async {
    if (_dbPath != null && _dbPath.isNotEmpty) return _dbPath;
    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, 'rune_progress.db');
  }

  Database? _db;

  /// DB 열기 및 테이블 생성. 기존 SharedPreferences 데이터가 있으면 마이그레이션.
  Future<Database> _openDb() async {
    final dbPath = await _getDbPath();
    // DB가 이미 열려 있으면 재사용.
    if (_db != null && _db!.isOpen) return _db!;
    _db = await openDatabase(
      dbPath,
      version: 2, // v1: SharedPreferences 이전, v2: 마이그레이션 완료
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
    return _db!;
  }

  /// 스키마 변경 마이그레이션. 현재 스키마로는 실제 변환 작업이 없다
  /// (JSON 자체는 [RuneProgress.fromJson]이 v1/v2/v3를 자동 변환).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // no-op: 진행도 데이터는 json 칼럼에 스냅샷으로 저장되므로 스키마는 안정적.
  }

  /// 새 DB 테이블 생성.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        json TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  /// DB 열릴 때 호출: legacy SharedPreferences 데이터 마이그레이션.
  Future<void> _onOpen(Database db) async {
    // SharedPreferences에서 기존 데이터 읽기.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final legacyJson = prefs.getString('rune_progress_v1');
    if (legacyJson == null) return; // 이전에 저장된 적 없음.

    // 이미 저장된 행이 있으면 (앱 조기 종료 등으로 중복 실행된 경우) 스킵.
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM progress WHERE id = 1'),
        ) ??
        0;
    if (count > 0) {
      await prefs.remove('rune_progress_v1');
      return;
    }

    // JSON 파싱 후 INSERT (id=1 한 행만 가짐).
    await db.insert('progress', {'id': 1, 'json': legacyJson, 'version': 1});

    // SharedPreferences에서 제거(마이그레이션 완료 후 불필요).
    await prefs.remove('rune_progress_v1');
  }

  /// DB가 열리도록 보장하고 [_db]를 리턴.
  Future<Database> get db async {
    // lazy initialization: 최초 접근 시 DB 열기.
    if (_db == null || !_db!.isOpen) await _openDb();
    return _db!;
  }

  // ── RuneProgressStore 인터페이스 구현 ───────────────────────

  @override
  Future<RuneProgress> load() async {
    final db_ = await db;
    final List<Map<String, dynamic>> result = await db_.query(
      'progress',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isEmpty) return RuneMeta.initial();

    final jsonStr = result.first['json'] as String;
    return RuneProgress.fromJson(jsonDecode(jsonStr));
  }

  @override
  Future<void> save(RuneProgress progress) async {
    final db_ = await db;
    final jsonStr = jsonEncode(progress.toJson());
    // 단일 스냅샷: 항상 id=1 행을 덮어쓴다 (매 저장마다 새 행을
    // INSERT 하던 버그 수정 — 테이블 무한 비대 방지).
    await db_.insert('progress', {
      'id': 1,
      'json': jsonStr,
      'version': 2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
