/// Rune 진행도 저장소 인터페이스 (PHASE 5 ~ PHASE 8, RPT-316).
///
/// UI/엔진은 이 인터페이스만 의존한다. 테스트는 [InMemoryRuneProgressStore],
/// 실제 앱은 [SharedPrefsRuneProgressStore] 또는 [SqliteRuneProgressStore]를 사용한다.
///
/// [RuneProgressStore] 인터페이스는 `package:rune_puzzle_tactics/game/rune/rune_progress.dart`
/// 에서 정의되며, 여기에서는 구체적 구현체만 제공한다.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:rune_puzzle_tactics/game/rune.dart';

// RuneProgressStore 인터페이스는 game/rune/rune_progress.dart에서 정의되므로
// 여기서 재정의하지 않으며, 하위 클래스에서 구현하도록 기대한다.

/// SharedPreferences 기반 저장소 (기존 PHASE 5 패턴 유지).
///
/// [RuneProgressStore] 인터페이스를 구현한다. (인터페이스는 game/rune/rune_progress.dart 정의)
class SharedPrefsRuneProgressStore implements RuneProgressStore {
  SharedPrefsRuneProgressStore({this.key = defaultKey});

  static const String defaultKey = 'rune_progress_v1';

  final String key;

  @override
  Future<RuneProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return RuneMeta.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return RuneMeta.initial();
      return RuneProgress.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // 손상된 데이터는 초기 구성으로 폴백 (RPT-316 안전 복원)
      return RuneMeta.initial();
    }
  }

  @override
  Future<void> save(RuneProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(progress.toJson()));
  }
}

// 참고: 테스트/디버그용 [InMemoryRuneProgressStore]는
// game/rune/rune_progress.dart의 canonical 구현을 사용한다 (중복 제거).
