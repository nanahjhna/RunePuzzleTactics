/// Rune Puzzle Tactics — 언어 상태 관리 (Localization Service)
///
/// 하나의 중앙 컨트롤러가 현재 언어를 관리하고 SharedPreferences에 저장한다.
///  - 앱 시작 시 저장된 언어 로드 → Locale 설정 → 메인 UI 표시
///  - 언어 변경 시 상태 즉시 갱신 → [LanguageScope]를 통해 UI 즉시 재빌드
///  - 게임 로직 문자열 비교는 없으며, 위젯은 `LanguageScope.of(context)`로 상태를 읽는다.
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// 언어 상태 관리 컨트롤러 (ChangeNotifier).
///
/// [LanguageController.instance]를 운영 싱글턴으로 사용하고, [setLanguage]로
/// 언어를 바꾸면 즉시 [notifyListeners]한다(재시작 불필요). 기기 저장은
/// [prefsKey] 키 아래 언어 code(en/ko/ja/zh-Hans/zh-Hant)를 문자열로 보관한다.
class LanguageController extends ChangeNotifier {
  LanguageController({this.persist = true, AppLanguage? initialLanguage})
    : _language = initialLanguage ?? AppLanguage.defaultLanguage;

  /// SharedPreferences 저장 키 (진행도 저장 키와 충돌하지 않음).
  static const String prefsKey = 'rpt_app_language';

  /// 테스트에서 사용하는 전역 인스턴스. `main()`에서 [load] 후 runApp한다.
  static final LanguageController instance = LanguageController();

  /// false면 저장/로드를 생략한다 (위젯 테스트용).
  final bool persist;

  AppLanguage _language;

  AppLanguage get language => _language;

  /// 현재 언어의 번역 표 조회 객체.
  AppLocalizations get strings => AppLocalizations(_language);

  /// 앱 시작 시 저장된 언어를 로드한다.
  ///
  /// 우선순위: **저장된 사용자 선택 → 시스템 언어 → 기본 언어(en)**.
  /// 저장값이 없으면 스마트폰의 시스템 언어([systemLocales] 또는
  /// [PlatformDispatcher.locales])를 감지해 적용한다(한국 폰이면 한국어로 시작).
  ///
  /// 자동 감지값은 저장하지 않는다 — 사용자가 직접 고른 값만 영속화되어,
  /// 이후 시스템 언어가 바뀌어도 사용자의 선택이 우선한다.
  ///
  /// [systemLocales] 는 테스트에서 시스템 로케일을 주입하기 위한 파라미터다.
  Future<void> load({List<Locale>? systemLocales}) async {
    if (!persist) return;
    String? code;
    try {
      final prefs = await SharedPreferences.getInstance();
      code = prefs.getString(prefsKey);
    } catch (_) {
      // 저장소 접근 실패 시 아래 시스템 언어 감지로 폴백한다(오프라인/테스트 안전).
    }
    final loaded =
        AppLanguage.tryParse(code) ??
        AppLanguage.fromLocales(
          systemLocales ?? PlatformDispatcher.instance.locales,
        );
    if (loaded != null && loaded != _language) {
      _language = loaded;
      notifyListeners();
    }
  }

  /// 언어를 변경하고 즉시 알린 뒤 기기에 저장한다.
  ///
  /// UI 갱신은 저장 완료를 기다리지 않고 동기적으로 발생한다 (RPT Localization §2).
  Future<void> setLanguage(AppLanguage lang) async {
    if (lang == _language) return;
    _language = lang;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, lang.code);
    } catch (_) {
      // 저장 실패해도 UI 언어 전환은 유지한다.
    }
  }
}

/// 위젯 트리에 언어 컨트롤러를 제공하는 InheritedNotifier.
///
/// 의존 위젯은 언어 변경 시 자동으로 다시 빌드된다 (즉시 UI 갱신).
/// 트리에 Scope가 없으면 [LanguageController.instance]로 폴백한다(테스트 안전).
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 현재 위젯 트리의 언어 컨트롤러 (의존성 등록 포함).
  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return scope?.notifier ?? LanguageController.instance;
  }

  /// 현재 언어의 번역 표 (편의 getter).
  static AppLocalizations stringsOf(BuildContext context) =>
      of(context).strings;
}
