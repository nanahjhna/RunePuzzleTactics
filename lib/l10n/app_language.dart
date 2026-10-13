/// Rune Puzzle Tactics — 지원 언어 정의 (Localization)
///
/// 지원 언어는 en(English)/ko(한국어)/ja(日本語)/zh-Hans(简体中文)/
/// zh-Hant(繁體中文) 5개이고, 기본 언어는 en이다. 문자열 번역 자체는
/// [app_strings.dart]에서 관리한다.
library;

import 'dart:ui' show Locale;

/// 앱에서 지원하는 언어. 내부 식별자는 [code] (en/ko/ja/zh-Hans/zh-Hant)를 쓴다.
///
/// 게임 로직의 enum/id/key 데이터 값은 절대 번역하지 않으며,
/// 이 enum의 [code]는 SharedPreferences 저장/로드와 번역 키 조회에만 사용한다.
enum AppLanguage {
  en('en', 'English'),
  ko('ko', '한국어'),
  ja('ja', '日本語'),
  zhHans('zh-Hans', '简体中文'),
  zhHant('zh-Hant', '繁體中文');

  const AppLanguage(this.code, this.displayName);

  /// 내부 식별자 (en/ko/ja/zh-Hans/zh-Hant). SharedPreferences 저장 키 값으로 사용.
  final String code;

  /// 언어 선택 다이얼로그에 그대로 표시하는 자체 이름.
  /// (표시 순서: English → 한국어 → 日本語 → 简体中文 → 繁體中文, [values] 순서 그대로)
  final String displayName;

  /// 저장된 언어가 없을 때 사용하는 기본 언어.
  static const AppLanguage defaultLanguage = AppLanguage.en;

  /// Flutter [Locale] 변환.
  ///
  /// 중국어는 스크립트 코드가 필요하므로 `Locale.fromSubtags` 를 쓴다 —
  /// `Locale('zh-Hans')` 는 languageCode 가 `'zh-Hans'` 가 되어 잘못된 로케일이
  /// 된다(scriptCode 가 비어 있다).
  Locale get locale => switch (this) {
    AppLanguage.zhHans => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    AppLanguage.zhHant => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    _ => Locale(code),
  };

  /// [code]에 해당하는 언어를 찾는다. 없으면 null.
  static AppLanguage? tryParse(String? code) {
    for (final lang in values) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  /// 시스템 [Locale] 하나를 지원 언어로 매핑한다. 미지원 언어면 null.
  ///
  /// 중국어는 스크립트 코드(zh-Hans / zh-Hant)를 우선 보고, 없으면 국가 코드로
  /// 번체(대만·홍콩·마카오)와 간체를 구분한다.
  static AppLanguage? fromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ko':
        return AppLanguage.ko;
      case 'ja':
        return AppLanguage.ja;
      case 'en':
        return AppLanguage.en;
      case 'zh':
        final script = locale.scriptCode;
        if (script == 'Hant') return AppLanguage.zhHant;
        if (script == 'Hans') return AppLanguage.zhHans;
        const hantRegions = {'TW', 'HK', 'MO'};
        final region = locale.countryCode;
        if (region != null && hantRegions.contains(region)) {
          return AppLanguage.zhHant;
        }
        return AppLanguage.zhHans;
      default:
        return null;
    }
  }

  /// 시스템 [Locale] 목록에서 처음 매칭되는 지원 언어를 고른다. 없으면 null.
  ///
  /// 기기 설정이 여러 언어를 우선순위로 줄 때를 대비해 순서대로 시도한다.
  static AppLanguage? fromLocales(List<Locale> locales) {
    for (final locale in locales) {
      final match = fromLocale(locale);
      if (match != null) return match;
    }
    return null;
  }
}
