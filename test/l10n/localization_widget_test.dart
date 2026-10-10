/// Localization 통합 위젯 테스트
///
/// - 기본 언어 en (저장값 없음)
/// - en→ko, en→ja 즉시 UI 갱신 (재시작 불필요)
/// - SharedPreferences 저장/재초기화 복원
/// - 하단 내비게이션 / 상점·통화 / 설정 언어 다이얼로그
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_main_screen.dart';
import 'package:rune_puzzle_tactics/screens/title_view.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 특정 버튼/레이블 텍스트를 표시하는 프로브.
class _LanguageProbe extends StatelessWidget {
  const _LanguageProbe({this.key2, this.key3});

  final String? key2;
  final String? key3;

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Column(
          children: [
            Text(l10n.tr('title_start'), key: const ValueKey('probe-1')),
            if (key2 != null)
              Text(l10n.tr(key2!), key: const ValueKey('probe-2')),
            if (key3 != null)
              Text(l10n.tr(key3!), key: const ValueKey('probe-3')),
          ],
        ),
      ),
    );
  }
}

Widget wrapScope(LanguageController controller, Widget child) =>
    LanguageScope(controller: controller, child: child);

Widget probeApp(LanguageController controller, {String? k2, String? k3}) =>
    wrapScope(controller, _LanguageProbe(key2: k2, key3: k3));

/// 메인 허브 테스트 앱 (상점/설정/내비게이션 접근용).
Widget hubApp(LanguageController controller, {int game = 500}) {
  return wrapScope(
    controller,
    MaterialApp(
      theme: ThemeData.dark(),
      home: RuneMainScreen(
        store: InMemoryRuneProgressStore(
          RuneProgress(
            highestCleared: 0,
            gameCurrency: game,
            playCurrency: 5,
            heroOwned: {HeroPool.starter.heroId},
            heroParty: [HeroPool.starter.heroId],
          ),
        ),
        analytics: RuneAnalytics.disabled,
        autoOpenTutorial: false,
      ),
    ),
  );
}

void usePortraitSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('기본 언어 & 즉시 갱신', () {
    testWidgets('저장값 없으면 기본 언어 en으로 표시 (TitleView)', (tester) async {
      final controller = LanguageController(persist: false);
      expect(controller.language, AppLanguage.en);

      await tester.pumpWidget(
        wrapScope(controller, const MaterialApp(home: TitleView())),
      );
      await tester.pump();

      expect(find.text('Start Battle'), findsOneWidget); // en 버튼
      expect(find.text('전투 시작'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en → ko 즉시 UI 갱신 (재시작 불필요)', (tester) async {
      final controller = LanguageController(persist: false);
      await tester.pumpWidget(probeApp(controller, k2: 'nav_shop'));
      await tester.pump();

      expect(find.text('Start Battle'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);

      await controller.setLanguage(AppLanguage.ko);
      await tester.pump(); // 저장 완료와 무관하게 동기적으로 리빌드된다

      expect(find.text('전투 시작'), findsOneWidget);
      expect(find.text('상점'), findsOneWidget);
      expect(find.text('Start Battle'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en → ja 즉시 UI 갱신 (재시작 불필요)', (tester) async {
      final controller = LanguageController(persist: false);
      await tester.pumpWidget(probeApp(controller));
      await tester.pump();

      expect(find.text('Start Battle'), findsOneWidget);

      await controller.setLanguage(AppLanguage.ja);
      await tester.pump();

      expect(find.text('バトル開始'), findsOneWidget);
      expect(find.text('Start Battle'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('언어 변경은 리스너에 동기적으로 알리고 이벤트 1회 발생', (tester) async {
      final controller = LanguageController(persist: false);
      var notifications = 0;
      controller.addListener(() => notifications++);

      // 같은 위젯 트리를 유지한 채 언어만 전환 → 앱 재시작 없이 즉시 반영.
      await tester.pumpWidget(probeApp(controller));
      await tester.pump();
      expect(find.text('Start Battle'), findsOneWidget);

      await controller.setLanguage(AppLanguage.ko);
      expect(notifications, 1); // notifyListeners 직후(저장 완료 대기 없이)
      await tester.pump();
      expect(find.text('전투 시작'), findsOneWidget);

      await controller.setLanguage(AppLanguage.ko); // 같은 언어 → 무시
      expect(notifications, 1);
      expect(controller.language, AppLanguage.ko);
    });
  });

  group('SharedPreferences 영속화', () {
    test('setLanguage → prefs에 언어 code가 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LanguageController(); // persist: true
      expect(controller.language, AppLanguage.en);

      await controller.setLanguage(AppLanguage.ko);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('rpt_app_language'), 'ko');
      expect(controller.language, AppLanguage.ko);
    });

    test('앱 재초기화 시 저장된 언어가 복원된다 (기본값은 en)', () async {
      SharedPreferences.setMockInitialValues({'rpt_app_language': 'ja'});

      final restarted = LanguageController();
      expect(restarted.language, AppLanguage.en); // 로드 전 기본값
      await restarted.load();
      expect(restarted.language, AppLanguage.ja);

      // 저장값이 없으면 기본 언어(en)로 초기화된다.
      SharedPreferences.setMockInitialValues({});
      final fresh = LanguageController();
      await fresh.load();
      expect(fresh.language, AppLanguage.en);
    });
  });

  group('하단 내비게이션 / 상점·통화 / 설정 언어', () {
    testWidgets('Bottom Nav 라벨이 언어에 따라 갱신된다', (tester) async {
      usePortraitSurface(tester);
      final controller = LanguageController(
        persist: false,
        initialLanguage: AppLanguage.ko,
      );
      await tester.pumpWidget(hubApp(controller));
      await tester.pump(); // 진행도 로드

      expect(find.text('로비'), findsOneWidget);
      expect(find.text('파티'), findsOneWidget);
      expect(find.text('상점'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);

      await controller.setLanguage(AppLanguage.en);
      await tester.pump();

      expect(find.text('Lobby'), findsOneWidget);
      expect(find.text('Party'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shop/Currency 라벨이 언어에 따라 번역된다 (숫자/ID는 불변)', (tester) async {
      usePortraitSurface(tester);
      final controller = LanguageController(
        persist: false,
        initialLanguage: AppLanguage.ko,
      );
      await tester.pumpWidget(hubApp(controller, game: 500));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.storefront_outlined));
      await tester.pumpAndSettle();

      expect(find.text('🛒 상점'), findsOneWidget);
      expect(find.text('⚡ 500'), findsWidgets); // Game 통화 기호+숫자는 동일
      // 요구사항 7/8: 상점은 최상단 뽑기 패널 + 6열 아이템 그리드.
      // 가격 칸은 숫자만 노출하므로 번역 여부는 아이템명/뽑기 문구로 검증한다.
      expect(find.text('1연 뽑기'), findsOneWidget);
      expect(find.text('10연 뽑기'), findsOneWidget);
      expect(find.text('생명의 서'), findsOneWidget); // 마도서 그리드 타일
      expect(find.text('Game Currency 획득'), findsOneWidget); // 업그레이드 타일
      // 천상 바 문구 (요구사항 9).
      expect(find.textContaining('10연에는 적용되지 않습니다'), findsOneWidget);

      await controller.setLanguage(AppLanguage.en);
      await tester.pump();

      expect(find.text('🛒 Shop'), findsOneWidget);
      expect(find.text('⚡ 500'), findsWidgets);
      expect(find.text('Recruit ×1'), findsOneWidget);
      expect(find.text('Recruit ×10'), findsOneWidget);
      expect(find.text('Book of Life'), findsOneWidget);
      expect(find.text('Game Currency Gain'), findsOneWidget);
      expect(
        find.textContaining('10-pulls are not affected'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('설정 탭: 언어 선택 다이얼로그 (English → 한국어 → 日本語) → 즉시 적용', (
      tester,
    ) async {
      usePortraitSurface(tester);
      final controller = LanguageController(persist: false);
      await tester.pumpWidget(hubApp(controller));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('⚙ Settings'), findsOneWidget);
      expect(find.text('Current Language: English'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('select-language')));
      await tester.pumpAndSettle();

      // 다이얼로그에 3개 언어가 순서대로(English → 한국어 → 日本語) 표시된다.
      final enY = tester.getTopLeft(find.byKey(const ValueKey('lang-en'))).dy;
      final koY = tester.getTopLeft(find.byKey(const ValueKey('lang-ko'))).dy;
      final jaY = tester.getTopLeft(find.byKey(const ValueKey('lang-ja'))).dy;
      expect(enY, lessThan(koY));
      expect(koY, lessThan(jaY));

      // 한국어 선택 → 다이얼로그 닫힘 + 즉시 UI 전환 + 현재 언어 표시 갱신.
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();

      expect(find.text('Select Language'), findsNothing); // 다이얼로그 닫힘
      expect(find.text('⚙ 설정'), findsOneWidget);
      expect(find.text('현재 언어: 한국어'), findsOneWidget);
      expect(controller.language, AppLanguage.ko);
      expect(tester.takeException(), isNull);
    });
  });
}
