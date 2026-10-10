/// 번역 표 검증 테스트 (Localization §3)
///
/// - en keys == ko keys == ja keys (누락/초과 키가 없어야 한다)
/// - 어떤 키도 빈 문자열을 표시하지 않는다 (미지원 키는 key 문자열 폴백)
/// - {placeholder} 파라미터 이름이 3개 언어에서 동일하다
library;

import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// 값에서 '{name}' 꼴의 파라미터 이름을 추출한다.
Set<String> placeholdersOf(String value) {
  final result = <String>{};
  final re = RegExp(r'\{(\w+)\}');
  for (final m in re.allMatches(value)) {
    result.add(m.group(1)!);
  }
  return result;
}

void main() {
  final en = AppLocalizations(AppLanguage.en);
  final ko = AppLocalizations(AppLanguage.ko);
  final ja = AppLocalizations(AppLanguage.ja);

  group('AppLocalizations', () {
    test('en keys == ko keys == ja keys (누락/초과 키 없음)', () {
      expect(en.keys, ko.keys, reason: 'ko에 en과 다른 키 집합');
      expect(en.keys, ja.keys, reason: 'ja에 en과 다른 키 집합');
      expect(ko.keys, ja.keys, reason: 'ja에 ko와 다른 키 집합');
      expect(en.keys, isNotEmpty);
    });

    test('어떤 키의 번역도 빈 문자열이 아니다 (en/ko/ja)', () {
      for (final key in en.keys) {
        expect(en.tr(key), isNotEmpty, reason: 'en[ $key ] 빈 값');
        expect(ko.tr(key), isNotEmpty, reason: 'ko[ $key ] 빈 값');
        expect(ja.tr(key), isNotEmpty, reason: 'ja[ $key ] 빈 값');
      }
    });

    test('모든 표에 빈 값이 없다 (누락 키가 화면에 빈 문자열로 표시되지 않음)', () {
      for (final table in [en, ko, ja]) {
        for (final key in table.keys) {
          expect(table.raw(key), isNotEmpty, reason: key);
        }
      }
    });

    test('미지원 키는 빈 문자열 대신 key 문자열로 폴백한다', () {
      expect(en.tr('no_such_key'), 'no_such_key');
      expect(ko.tr('no_such_key'), 'no_such_key');
      expect(ja.tr('no_such_key'), 'no_such_key');
      // 번역 표는 자기 언어를 우선, 누락 시 en 폴백한다.
      expect(ja.tr('nav_lobby'), 'ロビー');
      expect(en.tr('nav_lobby'), 'Lobby');
    });

    test('trp: {placeholder} 치환이 동작한다 (en/ko/ja 대표 키)', () {
      expect(en.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3W 1L');
      expect(ko.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3승 1패');
      expect(ja.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3勝 1敗');

      expect(en.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(ko.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(ja.trp('currency_game', {'n': 500}), '⚡ 500');

      expect(en.trp('currency_play', {'n': 3}), '🎟 3');
      expect(en.trp('currency_hero', {'n': 7}), '⭐ 7');

      expect(en.trp('lobby_battle_start', {'n': 3}), 'Start Battle (STAGE 3)');
      expect(ko.trp('lobby_battle_start', {'n': 3}), '전투 시작 (STAGE 3)');
      expect(ja.trp('lobby_battle_start', {'n': 3}), 'バトル開始 (STAGE 3)');

    });

    test('파라미터 이름이 3개 언어에서 동일하다 (치환 키 호환성)', () {
      final failures = <String>[];
      for (final key in en.keys) {
        final e = placeholdersOf(en.tr(key));
        final k = placeholdersOf(ko.tr(key));
        final j = placeholdersOf(ja.tr(key));
        if (e.length != k.length || e.length != j.length) {
          failures.add('$key: {en:$e} {ko:$k} {ja:$j}');
        }
      }
      expect(failures, isEmpty, reason: '파라미터 집합 불일치 키 목록');
    });

    test('필수 UI 키가 존재한다 (스모크 체크)', () {
      for (final key in [
        'title_start',
        'nav_lobby',
        'nav_party',
        'nav_shop',
        'nav_settings',
        'shop_title',
        'settings_title',
        'settings_language_select',
        'lang_dialog_title',
        'common_stage',
        'turn_player',
        'result_victory',
        'result_defeat',
        'tutorial_title_match',
        'tutorial_msg_boss',
        'element_fire',
        'upgrade_name_partyAttack',
      ]) {
        expect(en.containsKey(key), isTrue, reason: '누락 키: $key');
        expect(ko.containsKey(key), isTrue, reason: '누락 키: $key');
        expect(ja.containsKey(key), isTrue, reason: '누락 키: $key');
      }
    });
  });
}
