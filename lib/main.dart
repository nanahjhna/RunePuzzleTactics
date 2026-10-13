import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'game/rune.dart' show RuneProgressStore;
import 'l10n/language_controller.dart';
import 'screens/rune/rune_battle_view.dart';
import 'screens/rune/rune_main_screen.dart';
import 'screens/rune/rune_tutorial_view.dart';
import 'screens/title_view.dart';
import 'services/game_audio_service.dart';
import 'services/rune_analytics.dart';
import 'theme/app_theme.dart';

/// Rune 모드 분석 인스턴스. Firebase가 초기화되지 않았어도 no-op으로 안전.
RuneAnalytics _runeAnalytics() => RuneAnalytics();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 사양 1-1 / 2-1 Portrait Mode: 앱 전체가 세로(Portrait) 전용이다.
  // 로비·전투·준비 모달 모두 세로 레이아웃(1x5 그리드, 420~450px 보드)을 전제로
  // 설계되어 있으므로 가로 모드는 진입하지 못하게 잠근다.
  // iOS 는 Info.plist 의 UISupportedInterfaceOrientations, Android 는
  // AndroidManifest 의 screenOrientation 으로도 제한되지만, 여기서 한 번 더
  // 지정하면 테스트/디버그 빌드까지 동일하게 동작한다.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Google Mobile Ads SDK 초기화 (배너/리워드 광고). 실패해도 게임 진행에는
  // 영향이 없도록 조용히 넘긴다. 플러그인이 첫 요청 시 자동 초기화도 수행하지만,
  // 첫 광고 로드 대기 시간을 줄이기 위해 앱 시작 시 명시적으로 초기화한다.
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('AdMob 초기화 실패: $e');
  }

  // Localization: 앱 초기화 → SharedPreferences에서 언어 로드 → Locale 설정 → UI 표시.
  await LanguageController.instance.load();

  // Firebase 초기화 (실패해도 게임 동작에는 영향 없음)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final analytics = RuneAnalytics();

    // 전역 오류 → Crashlytics (RPT-309): 위젯 빌드/레이아웃 오류 + 플랫폼 디스패치 오류.
    FlutterError.onError = (details) {
      final stack = details.stack;
      analytics.recordError(
        details.exception,
        stack ?? StackTrace.current,
        context: 'flutter_error',
        keys: const {},
      );
      // 디버그 빌드에서 콘솔/logcat에 실제 예외를 남겨 원인을 파악할 수 있게
      // 한다. (전환 프레임 예외가 기록만 되고 화면이 검정으로 멈추는 사례 —
      // 게임 종료 후 로비 복귀 멈춤 진단용.) 릴리즈에서는 오류 UI를 띄우지
      // 않도록 기존처럼 분석 기록만 남긴다.
      if (kDebugMode) {
        debugPrint('[FlutterError] ${details.exception}');
        debugPrint('$stack');
        FlutterError.presentError(details);
      }
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      analytics.recordError(
        error,
        stack,
        context: 'platform_dispatcher',
        keys: const {},
      );
      return true; // 앱 종료 방지
    };

    analytics.logAppOpen();

    debugPrint('Firebase 초기화 성공');
    debugPrint('Firebase App: ${Firebase.app().name}');
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
  }

  runApp(const RunePuzzleTacticsApp());
  unawaited(GameAudioService.instance.initialize());
}

class RunePuzzleTacticsApp extends StatelessWidget {
  const RunePuzzleTacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 언어 변경 시 전체 트리를 즉시 재빌드해 UI를 갱신한다 (재시작 불필요).
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, _) => LanguageScope(
        controller: LanguageController.instance,
        child: MaterialApp(
          title: 'RunePuzzleTactics',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          // 로드된 언어를 Flutter Locale에 반영한다 (Localization §2).
          // zh-Hans/zh-Hant 는 scriptCode 가 필요해 AppLanguage.locale 을 쓴다.
          locale: LanguageController.instance.language.locale,
          initialRoute: '/',
          routes: {
            '/': (context) => const TitleView(),
            '/runeLobby': (context) =>
                RuneMainScreen(analytics: _runeAnalytics()),
            '/runeBattle': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              final stage = (args?['stage'] as int?) ?? 1;
              final store = args?['store'] as RuneProgressStore?;
              final analytics =
                  (args?['analytics'] as RuneAnalytics?) ?? _runeAnalytics();
              // 요구사항 6.4: 결과 화면의 popUntil 대량 정리 시 '상점으로' 의도를
              // 라우트 결과 없이 허브로 전달하기 위한 콜백 (라우터 플래그).
              final onShopRequested = args?['onShopRequested'] as VoidCallback?;
              final audioService =
                  args?['audioService'] as GameAudioService? ??
                  GameAudioService.instance;
              return RuneBattleView(
                startStage: stage,
                store: store,
                analytics: analytics,
                audioService: audioService,
                onShopRequested: onShopRequested,
              );
            },
            '/runeTutorial': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              final store = args?['store'] as RuneProgressStore?;
              final analytics =
                  (args?['analytics'] as RuneAnalytics?) ?? _runeAnalytics();
              final audioService =
                  args?['audioService'] as GameAudioService? ??
                  GameAudioService.instance;
              return RuneTutorialView(
                store: store,
                analytics: analytics,
                audioService: audioService,
              );
            },
          },
        ),
      ),
    );
  }
}
