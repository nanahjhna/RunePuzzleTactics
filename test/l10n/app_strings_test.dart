/// 번역 표 검증 테스트 (Localization §3)
///
/// - en keys == ko keys == ja keys == zh-Hans keys == zh-Hant keys
///   (누락/초과 키가 없어야 한다)
/// - 어떤 키도 빈 문자열을 표시하지 않는다 (미지원 키는 key 문자열 폴백)
/// - {placeholder} 파라미터 이름이 5개 언어에서 동일하다
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

/// 두 파라미터 집합이 같은지 비교 (setEquals 대체, 의존성 없음).
bool samePlaceholders(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

void main() {
  final en = AppLocalizations(AppLanguage.en);
  final ko = AppLocalizations(AppLanguage.ko);
  final ja = AppLocalizations(AppLanguage.ja);
  final zhHans = AppLocalizations(AppLanguage.zhHans);
  final zhHant = AppLocalizations(AppLanguage.zhHant);
  final all = [en, ko, ja, zhHans, zhHant];

  group('AppLocalizations', () {
    test('5개 언어의 key 집합이 동일하다 (누락/초과 키 없음)', () {
      expect(en.keys, isNotEmpty);
      for (final other in [ko, ja, zhHans, zhHant]) {
        expect(
          en.keys,
          other.keys,
          reason: '${other.language.code}에 en과 다른 키 집합',
        );
      }
      for (final other in [ja, zhHans, zhHant]) {
        expect(
          ko.keys,
          other.keys,
          reason: '${other.language.code}에 ko와 다른 키 집합',
        );
      }
      expect(zhHans.keys, zhHant.keys);
    });

    test('어떤 키의 번역도 빈 문자열이 아니다 (5개 언어)', () {
      for (final key in en.keys) {
        for (final l10n in all) {
          expect(
            l10n.tr(key),
            isNotEmpty,
            reason: '${l10n.language.code}[ $key ] 빈 값',
          );
        }
      }
    });

    test('모든 표에 빈 값이 없다 (누락 키가 화면에 빈 문자열로 표시되지 않음)', () {
      for (final table in all) {
        for (final key in table.keys) {
          expect(
            table.raw(key),
            isNotEmpty,
            reason: '${table.language.code} $key',
          );
        }
      }
    });

    test('미지원 키는 빈 문자열 대신 key 문자열로 폴백한다', () {
      for (final l10n in all) {
        expect(
          l10n.tr('no_such_key'),
          'no_such_key',
          reason: l10n.language.code,
        );
      }
      // 번역 표는 자기 언어를 우선, 누락 시 en 폴백한다.
      expect(ja.tr('nav_lobby'), 'ロビー');
      expect(en.tr('nav_lobby'), 'Lobby');
    });

    test('trp: {placeholder} 치환이 동작한다 (5개 언어 대표 키)', () {
      expect(en.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3W 1L');
      expect(ko.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3승 1패');
      expect(ja.trp('lobby_record_value', {'wins': 3, 'losses': 1}), '3勝 1敗');
      expect(
        zhHans.trp('lobby_record_value', {'wins': 3, 'losses': 1}),
        '3胜 1负',
      );
      expect(
        zhHant.trp('lobby_record_value', {'wins': 3, 'losses': 1}),
        '3勝 1負',
      );

      expect(en.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(ko.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(ja.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(zhHans.trp('currency_game', {'n': 500}), '⚡ 500');
      expect(zhHant.trp('currency_game', {'n': 500}), '⚡ 500');

      expect(en.trp('currency_play', {'n': 3}), '🎟 3');
      expect(en.trp('currency_hero', {'n': 7}), '⭐ 7');

      expect(en.trp('lobby_battle_start', {'n': 3}), 'Start Battle (STAGE 3)');
      expect(ko.trp('lobby_battle_start', {'n': 3}), '전투 시작 (STAGE 3)');
      expect(ja.trp('lobby_battle_start', {'n': 3}), 'バトル開始 (STAGE 3)');
      expect(zhHans.trp('lobby_battle_start', {'n': 3}), '开始战斗 (STAGE 3)');
      expect(zhHant.trp('lobby_battle_start', {'n': 3}), '開始戰鬥 (STAGE 3)');
    });

    test('파라미터 이름이 5개 언어에서 동일하다 (치환 키 호환성)', () {
      final failures = <String>[];
      for (final key in en.keys) {
        final placeholderSets = all
            .map((l) => placeholdersOf(l.tr(key)))
            .toList();
        final first = placeholderSets.first;
        for (var i = 1; i < placeholderSets.length; i++) {
          if (!samePlaceholders(first, placeholderSets[i])) {
            failures.add(
              '$key: {${all.map((l) => placeholdersOf(l.tr(key))).join(' | ')}}',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: '파라미터 집합 불일치 키 목록');
    });

    test('필수 UI 키가 존재한다 (스모크 체크, 5개 언어)', () {
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
        'lang_zh_hans',
        'lang_zh_hant',
        'common_stage',
        'turn_player',
        'result_victory',
        'result_defeat',
        'tutorial_title_match',
        'tutorial_msg_boss',
        'element_fire',
        'upgrade_name_partyAttack',
      ]) {
        for (final l10n in all) {
          expect(
            l10n.containsKey(key),
            isTrue,
            reason: '${l10n.language.code} 누락 키: $key',
          );
        }
      }
    });

    test('가이드 키가 5개 언어 모두에 존재한다 (첫 패배 가이드)', () {
      for (final key in [
        'guide_name',
        'guide_first_defeat_msg',
        'guide_first_defeat_cta',
        'guide_first_defeat_cancel',
        'guide_shop_banner',
        'guide_pull_done_msg',
        'guide_pull_done_cta',
      ]) {
        for (final l10n in all) {
          expect(
            l10n.containsKey(key),
            isTrue,
            reason: '${l10n.language.code} 누락 키: $key',
          );
        }
      }
    });
  });
}
