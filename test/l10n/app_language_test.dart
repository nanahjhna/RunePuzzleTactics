/// 언어 식별자 정의 테스트 (Localization §1)
///
/// - 지원 언어는 정확히 en/ko/ja/zh-Hans/zh-Hant 5개이고 기본 언어는 en이다.
/// - 내부 식별자는 게임/저장/번역 조회에 사용하며 번역되지 않는다.
/// - 시스템 Locale → 지원 언어 매핑(fromLocale/fromLocales)도 검증한다.
library;

import 'dart:ui' show Locale;

import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLanguage', () {
    test('지원 언어는 정확히 en/ko/ja/zh-Hans/zh-Hant 5개 (게임 로직 식별자와 독립)', () {
      expect(AppLanguage.values, hasLength(5));
      expect(AppLanguage.values.map((l) => l.code).toSet(), {
        'en',
        'ko',
        'ja',
        'zh-Hans',
        'zh-Hant',
      });
    });

    test('기본 언어는 en (사용자 저장값이 없을 때)', () {
      expect(AppLanguage.defaultLanguage, AppLanguage.en);
    });

    test('내부 코드는 en/ko/ja/zh-Hans/zh-Hant (저장/로드/번역 키 전용)', () {
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.ko.code, 'ko');
      expect(AppLanguage.ja.code, 'ja');
      expect(AppLanguage.zhHans.code, 'zh-Hans');
      expect(AppLanguage.zhHant.code, 'zh-Hant');
    });

    test('tryParse: 저장된 code를 정확히 복원하고, 미지원 값은 null', () {
      expect(AppLanguage.tryParse('en'), AppLanguage.en);
      expect(AppLanguage.tryParse('ko'), AppLanguage.ko);
      expect(AppLanguage.tryParse('ja'), AppLanguage.ja);
      expect(AppLanguage.tryParse('zh-Hans'), AppLanguage.zhHans);
      expect(AppLanguage.tryParse('zh-Hant'), AppLanguage.zhHant);
      expect(AppLanguage.tryParse(null), isNull);
      expect(AppLanguage.tryParse('fr'), isNull);
      expect(AppLanguage.tryParse('zh'), isNull);
      expect(AppLanguage.tryParse(''), isNull);
    });

    test('표시 순서: English → 한국어 → 日本語 → 简体中文 → 繁體中文 ([values] 순서 그대로)', () {
      expect(AppLanguage.values[0], AppLanguage.en);
      expect(AppLanguage.values[1], AppLanguage.ko);
      expect(AppLanguage.values[2], AppLanguage.ja);
      expect(AppLanguage.values[3], AppLanguage.zhHans);
      expect(AppLanguage.values[4], AppLanguage.zhHant);
      expect(AppLanguage.values.map((l) => l.displayName).toList(), [
        'English',
        '한국어',
        '日本語',
        '简体中文',
        '繁體中文',
      ]);
    });

    test('locale: zh 계열은 scriptCode가 있는 유효한 Locale로 변환', () {
      expect(AppLanguage.en.locale, const Locale('en'));
      expect(AppLanguage.ko.locale, const Locale('ko'));
      expect(AppLanguage.ja.locale, const Locale('ja'));
      expect(AppLanguage.zhHans.locale.languageCode, 'zh');
      expect(AppLanguage.zhHans.locale.scriptCode, 'Hans');
      expect(AppLanguage.zhHant.locale.languageCode, 'zh');
      expect(AppLanguage.zhHant.locale.scriptCode, 'Hant');
      // Locale.fromSubtags 기반 변환이어야 한다 — languageCode가 'zh-Hans'가 아니다.
      expect(AppLanguage.zhHans.locale.languageCode, isNot('zh-Hans'));
      expect(AppLanguage.zhHant.locale.languageCode, isNot('zh-Hant'));
    });
  });

  group('AppLanguage.fromLocale (시스템 언어 감지)', () {
    test('ko/ja/en 단순 매핑', () {
      expect(AppLanguage.fromLocale(const Locale('ko')), AppLanguage.ko);
      expect(AppLanguage.fromLocale(const Locale('ja')), AppLanguage.ja);
      expect(AppLanguage.fromLocale(const Locale('en')), AppLanguage.en);
    });

    test('미지원 언어는 null', () {
      expect(AppLanguage.fromLocale(const Locale('fr')), isNull);
      expect(AppLanguage.fromLocale(const Locale('de')), isNull);
      expect(AppLanguage.fromLocale(const Locale('es')), isNull);
    });

    test('zh 스크립트 코드 우선 (Hans/Hant)', () {
      expect(
        AppLanguage.fromLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ),
        AppLanguage.zhHans,
      );
      expect(
        AppLanguage.fromLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        AppLanguage.zhHant,
      );
    });

    test('zh 스크립트 코드가 없으면 국가 코드로 판별 (TW/HK/MO → 번체)', () {
      expect(
        AppLanguage.fromLocale(const Locale('zh', 'TW')),
        AppLanguage.zhHant,
      );
      expect(
        AppLanguage.fromLocale(const Locale('zh', 'HK')),
        AppLanguage.zhHant,
      );
      expect(
        AppLanguage.fromLocale(const Locale('zh', 'MO')),
        AppLanguage.zhHant,
      );
      expect(
        AppLanguage.fromLocale(const Locale('zh', 'CN')),
        AppLanguage.zhHans,
      );
      expect(
        AppLanguage.fromLocale(const Locale('zh', 'SG')),
        AppLanguage.zhHans,
      );
    });

    test('스크립트/국가 코드가 모두 없으면 zh-Hans 기본', () {
      expect(AppLanguage.fromLocale(const Locale('zh')), AppLanguage.zhHans);
    });
  });

  group('AppLanguage.fromLocales (시스템 언어 우선순위 목록)', () {
    test('첫 번째 매칭되는 지원 언어를 고른다', () {
      expect(
        AppLanguage.fromLocales([
          const Locale('fr'),
          const Locale('zh', 'TW'),
          const Locale('en'),
        ]),
        AppLanguage.zhHant,
      );
      expect(
        AppLanguage.fromLocales([const Locale('de'), const Locale('ko')]),
        AppLanguage.ko,
      );
      expect(
        AppLanguage.fromLocales([
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          const Locale('en'),
        ]),
        AppLanguage.zhHans,
      );
    });

    test('전부 미지원이면 null', () {
      expect(
        AppLanguage.fromLocales([const Locale('fr'), const Locale('de')]),
        isNull,
      );
      expect(AppLanguage.fromLocales(const []), isNull);
    });
  });
}
