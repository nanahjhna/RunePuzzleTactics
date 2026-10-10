/// Rune 메인 허브(로비) 화면 테스트 (PHASE 7 내비게이션, RPT-417 / 3-재화·HeroPool 개편)
///
/// PHASE 5의 독립 로비가 하단 탭 허브(Lobby/Party/Shop/Settings)로 승격되었다.
/// - Lobby 탭: 3-재화/진행도/업그레이드/파티 N² 표시, 전투 시작(입장 비용)
/// - Party 탭: 편성(assign)/해제(unassign) — heroId 단위
/// - Shop 탭: 영웅 뽑기(gacha, Hero Currency) + 업그레이드 구매(Game Currency)
/// - Settings 탭: 튜토리얼 다시보기 / 진행도 초기화
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_battle_view.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_lobby_view.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 메인 허브 + 배틀 라우트를 갖춘 테스트 앱.
/// [autoOpenTutorial] false: 첫 실행 자동 튜토리얼이 라우트 부재로 실패하지 않게 한다.
/// 한국어 문자열 검증 유지: ko 고정 LanguageScope로 감싼다 (Localization 테스트 하네스).
Widget makeApp(RuneProgressStore store) {
  return LanguageScope(
    controller: LanguageController(
      persist: false,
      initialLanguage: AppLanguage.ko,
    ),
    child: MaterialApp(
      home: RuneLobbyView(
        store: store,
        analytics: RuneAnalytics.disabled,
        autoOpenTutorial: false,
      ),
      routes: {'/runeBattle': (context) => const RuneBattleView()},
    ),
  );
}

/// 기본 파티(Fire 1)를 갖춘 진행도: 시작 Play 5 보유.
RuneProgress fireOnly({int game = 0, int hero = 0}) => RuneProgress(
  highestCleared: 0,
  gameCurrency: game,
  heroCurrency: hero,
  playCurrency: 5,
  heroOwned: {HeroPool.starter.heroId},
  heroParty: [HeroPool.starter.heroId],
);

/// 테스트 표면을 세로(500×900)로 넓혀 모든 탭 내용이 보이도록 한다.
void usePortraitSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Lobby 탭: 3-재화/진행도/업그레이드 표시', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      RuneProgress(
        highestCleared: 2,
        gameCurrency: 500,
        playCurrency: 5,
        wins: 1,
        heroOwned: {HeroPool.starter.heroId},
        heroParty: [HeroPool.starter.heroId],
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    expect(find.byKey(const ValueKey('start-battle')), findsOneWidget);
    expect(find.text('전투 시작 (STAGE 3)'), findsOneWidget);
    expect(find.text('⚡ 500'), findsOneWidget); // Game Currency
    expect(find.text('🎟 5'), findsOneWidget); // Play Currency
    expect(find.text('⭐ 0'), findsOneWidget); // Hero Currency
    expect(
      tester.getCenter(find.byKey(const ValueKey('daily-reward-chip'))).dx,
      lessThan(tester.getCenter(find.text('⚡ 500')).dx),
      reason: '일일 보상 칩은 Game 재화 칩 왼쪽에 배치한다',
    );
    expect(find.text('STAGE 3'), findsOneWidget);
    // 요구사항 3: 영웅 스탯 카드 / 영구 업그레이드 UI 삭제 → LV 표기 자체가 없다.
    expect(find.text('LV0(100)'), findsNothing);
    expect(find.text('LV0'), findsNothing);
    expect(find.byKey(const ValueKey('lobby-permanent-upgrade')), findsNothing);
    // 시너지 요약 한 줄은 유지된다 (불 1명 = 0.6 + 0.2 = 0.8x).
    expect(find.textContaining('불 x1 (0.8x)'), findsOneWidget);
  });

  testWidgets('Lobby 탭: 마지막 플레이 스테이지 카드 + 「계속하기」 (요구사항 1)', (
    tester,
  ) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      RuneProgress(
        highestCleared: 3,
        gameCurrency: 500,
        playCurrency: 5,
        heroOwned: {HeroPool.starter.heroId},
        heroParty: [HeroPool.starter.heroId],
        lastPlayedStage: 2,
        lastStageVictory: false,
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    expect(find.byKey(const ValueKey('lobby-last-continue')), findsOneWidget);
    expect(find.text('마지막 플레이'), findsOneWidget);
    expect(find.text('STAGE 2'), findsOneWidget);

    // 「계속하기 ▶」 → 그 스테이지로 재도전(스테이지 준비 다이얼로그 경유).
    await tester.tap(find.byKey(const ValueKey('lobby-last-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // 다이얼로그 진입
    expect(find.byKey(const ValueKey('stage-prep-dialog')), findsOneWidget);
  });

  testWidgets('Lobby 탭: 전투 기록이 없으면 마지막 플레이 카드를 띄우지 않는다', (
    tester,
  ) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(fireOnly());
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    expect(find.byKey(const ValueKey('lobby-last-continue')), findsNothing);
    expect(find.text('마지막 플레이'), findsNothing);
  });

  testWidgets('전투 시작 버튼 → 스테이지 준비 확인 후 Play 소모 + 배틀 이동 (RPT-19, §6.1)', (
    tester,
  ) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(fireOnly());
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('start-battle')));
    await tester.pump();
    // 요구사항 6.1: 바로 이동하지 않고 스테이지 준비 다이얼로그가 먼저 뜬다.
    await tester.pump(const Duration(milliseconds: 300)); // 다이얼로그 진입

    expect(find.byKey(const ValueKey('stage-prep-dialog')), findsOneWidget);
    expect(find.text('STAGE 1'), findsWidgets); // 선택 단계와 준비 단계 정보
    expect(find.text('출전 파티'), findsWidgets);
    // 확인 전에는 입장 비용을 소모하지 않는다.
    expect((await store.load()).playCurrency, 5);

    // 확인 → 입장 비용 1 소모 후 배틀로 이동.
    await tester.tap(find.byKey(const ValueKey('stage-prep-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // 다이얼로그 pop
    await tester.pump(const Duration(milliseconds: 400)); // 라우트 전환
    await tester.pump();

    expect(find.text('전투 시작 (STAGE 1)'), findsNothing);
    expect(find.text('STAGE 1'), findsOneWidget); // 배틀 화면 타이틀
    // 요구사항 3(턴 표시 제거): 턴 인디케이터가 더 이상 표시되지 않는다.
    expect(find.textContaining('PLAYER TURN'), findsNothing);
    expect(find.textContaining('MONSTER TURN'), findsNothing);
    // 입장 비용 1 소모
    expect((await store.load()).playCurrency, 4);
  });

  testWidgets('전투 시작 시 Play 부족 → 진입 실패 + 안내 (RPT-19)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      // Play 0 보유 → 진입 불가
      RuneProgress(
        highestCleared: 0,
        gameCurrency: 0,
        playCurrency: 0,
        heroOwned: {HeroPool.starter.heroId},
        heroParty: [HeroPool.starter.heroId],
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('start-battle')));
    await tester.pumpAndSettle();

    // 배틀로 이동하지 않고 화면 중앙의 팝업으로 안내한다.
    expect(find.byKey(const ValueKey('stage-prep-dialog')), findsNothing);
    expect(find.bySubtype<GameWidget>(), findsNothing);
    expect(find.byKey(const ValueKey('shortage-watch-ad')), findsOneWidget);
    expect(find.textContaining('플레이 재화가 부족합니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('play-shortage-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('shortage-go-shop')), findsNothing);
  });

  testWidgets('Lobby 탭: 영구 업그레이드 바로가기 삭제 (요구사항 3) — 상점은 네비로 진입', (
    tester,
  ) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(fireOnly());
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    // 로비에는 더 이상 업그레이드 바로가기가 없다.
    expect(find.text('영구 업그레이드 보기'), findsNothing);
    expect(find.byKey(const ValueKey('lobby-permanent-upgrade')), findsNothing);

    // 상점은 하단 네비게이션에서 진입한다.
    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    expect(find.text('🛒 상점'), findsOneWidget);
    // 마서부는 6열 그리드로 상단 뽑기 패널 아래에 한 줄(6칸) 노출된다 (요구사항 7).
    expect(find.byKey(const ValueKey('buy-bookHp')), findsOneWidget);
    expect(find.byKey(const ValueKey('buy-upgrade-gameGain')), findsOneWidget);
  });

  testWidgets('Party 탭: 편성/해제가 저장에 반영 (heroId 단위, RPT-289)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      RuneProgress(
        highestCleared: 0,
        playCurrency: 5,
        heroOwned: {HeroPool.starter.heroId, 'water_a'},
        heroParty: [HeroPool.starter.heroId],
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.groups_outlined));
    await tester.pumpAndSettle();
    expect(find.text('👥 파티 관리'), findsOneWidget);
    expect(find.byKey(const ValueKey('party-page-0')), findsOneWidget);
    expect(find.text('현재 파티 (속성 시너지)'), findsOneWidget);

    // Water 페이지(네 번째 탭)에서 보유 영웅을 카드 탭으로 합류시킨다.
    await tester.tap(find.byKey(const ValueKey('party-page-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hero-detail-open-water_a')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('party-assign-confirm-water_a')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('party-assign-no-water_a')));
    await tester.pumpAndSettle();
    expect((await store.load()).partyTotal, 1);

    await tester.tap(find.byKey(const ValueKey('hero-detail-open-water_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('party-assign-yes-water_a')));
    await tester.pumpAndSettle();
    expect((await store.load()).partyCount(RuneElement.water), 1);
    expect((await store.load()).partyTotal, 2);

    // 도감은 속성 아코디언 없이 5열 그리드로 항상 전량 노출된다.
    // 노출 대상은 속성당 1번 영웅 5명뿐이라 분모도 5다.
    expect(find.byKey(const ValueKey('codex-hero-fire_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('codex-hero-water_a')), findsOneWidget);
    // b/c/d 영웅은 삭제됐다 — 속성당 대표 1명만 도감에 뜬다.
    expect(find.byKey(const ValueKey('codex-hero-fire_b')), findsNothing);
    expect(find.text('보유 2 / 5'), findsOneWidget);

    // Fire 페이지에서 파티 해제 → 보유 유지
    final firePage = find.byKey(const ValueKey('party-page-1'));
    await tester.ensureVisible(firePage);
    await tester.tap(firePage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unassign-hero-fire_a')));
    await tester.pumpAndSettle();
    expect((await store.load()).partyCount(RuneElement.fire), 0);
    expect((await store.load()).partyTotal, 1);
  });

  testWidgets('Shop 탭: 뽑기(Hero) 반영 (RPT-306)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      RuneProgress(
        highestCleared: 0,
        gameCurrency: 1200,
        heroCurrency: 1200,
        playCurrency: 5,
        heroOwned: {HeroPool.starter.heroId},
        heroParty: [HeroPool.starter.heroId],
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();
    expect(find.text('🛒 상점'), findsOneWidget);

    // 10연 뽑기: Hero 1200 → 1110, 결과 팝업 노출
    final pull = find.byKey(const ValueKey('gacha-ten'));
    await tester.ensureVisible(pull);
    await tester.pumpAndSettle();
    await tester.tap(pull);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gacha-result-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gacha-confirm')));
    await tester.pumpAndSettle();

    final afterPull = await store.load();
    expect(afterPull.heroCurrency, 1110);
    // 자동 파티 편성 없음 (§1) — 파티는 스타터 1명 유지
    expect(afterPull.partyTotal, 1);
  });

  testWidgets('Shop 탭: 영웅 재화 부족 시 뽑기 실패 (RPT-306)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(fireOnly(hero: 0));
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    final pull = find.byKey(const ValueKey('gacha-single'));
    await tester.ensureVisible(pull);
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(pull).onTap, isNull);
    await tester.tap(pull);
    await tester.pump();
    expect((await store.load()).heroCurrency, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Shop 탭: 해금 전 등급은 확률표에 미노출 (Stage 기준)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(fireOnly(hero: 5000));
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.storefront_outlined));
    await tester.pumpAndSettle();

    // 1스테이지: R 등급만 가용 → 정규화 100.0% 표기, 상위 등급 미노출.
    // 등급 표기는 ★ 가 아니라 문자 배지(R/SR/SSR/UR)로 나온다.
    expect(find.text('R'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);
    expect(find.textContaining('★'), findsNothing);
  });

  testWidgets('Settings 탭: 진행도 초기화 (다이얼로그 확인)', (tester) async {
    usePortraitSurface(tester);
    final store = InMemoryRuneProgressStore(
      RuneProgress(
        highestCleared: 2,
        gameCurrency: 900,
        heroCurrency: 300,
        wins: 3,
        heroOwned: {HeroPool.starter.heroId, 'water_a'},
        heroParty: [HeroPool.starter.heroId, 'water_a'],
      ),
    );
    await tester.pumpWidget(makeApp(store));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('replay-tutorial')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reset-progress')));
    await tester.pumpAndSettle();
    expect(find.text('진행도 초기화'), findsWidgets); // 목록 항목 + 다이얼로그 제목

    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();

    final reset = await store.load();
    expect(reset.gameCurrency, 0);
    expect(reset.heroCurrency, 0);
    expect(reset.highestCleared, 0);
    expect(reset.wins, 0);
    expect(reset.partyTotal, 1); // 스타터 fire_a만
    expect(find.text('진행도가 초기화되었습니다.'), findsOneWidget);
  });
}
