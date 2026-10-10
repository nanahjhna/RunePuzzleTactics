/// 언어 식별자 정의 테스트 (Localization §1)
///
/// - 지원 언어는 정확히 en/ko/ja 3개이고 기본 언어는 en이다.
/// - 내부 식별자는 게임/저장/번역 조회에 사용하며 번역되지 않는다.
library;

import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguage', () {
    test('지원 언어는 정확히 en/ko/ja 3개 (게임 로직 식별자와 독립)', () {
      expect(AppLanguage.values, hasLength(3));
      expect(AppLanguage.values.map((l) => l.code).toSet(), {'en', 'ko', 'ja'});
    });

    test('기본 언어는 en (사용자 저장값이 없을 때)', () {
      expect(AppLanguage.defaultLanguage, AppLanguage.en);
    });

    test('내부 코드는 en/ko/ja (저장/로드/번역 키 전용)', () {
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.ko.code, 'ko');
      expect(AppLanguage.ja.code, 'ja');
    });

    test('tryParse: 저장된 code를 정확히 복원하고, 미지원 값은 null', () {
      expect(AppLanguage.tryParse('en'), AppLanguage.en);
      expect(AppLanguage.tryParse('ko'), AppLanguage.ko);
      expect(AppLanguage.tryParse('ja'), AppLanguage.ja);
      expect(AppLanguage.tryParse(null), isNull);
      expect(AppLanguage.tryParse('fr'), isNull);
      expect(AppLanguage.tryParse(''), isNull);
    });

    test('표시 순서: English → 한국어 → 日本語 ([values] 순서 그대로)', () {
      expect(AppLanguage.values[0], AppLanguage.en);
      expect(AppLanguage.values[1], AppLanguage.ko);
      expect(AppLanguage.values[2], AppLanguage.ja);
      expect(AppLanguage.values.map((l) => l.displayName).toList(), [
        'English',
        '한국어',
        '日本語',
      ]);
    });
  });
}
