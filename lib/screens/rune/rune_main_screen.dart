/// Rune Puzzle Tactics — 메인 허브 화면 (PHASE 7 내비게이션, RPT-417)
///
/// PHASE 5의 독립 로비를 하단 탭 허브로 승격한다 (프롬프트 §24):
///   [0] Lobby   — 골드/클리어/전투 시작/업그레이드·파티 요약
///   [1] Party   — 파티 편성 (Owned → Party ≤ 5)
///   [2] Shop    — 영구 업그레이드 3종 + 영웅 영입
///   [3] Settings— 튜토리얼 다시보기/진행도 초기화
///
///
/// 진행도 스냅샷은 이 허브가 단일 소유(Single Source of Truth)하고
/// 탭 변경 시 저장소에 기록한다. 배틀/튜토리얼 귀환 시 저장소에서 재로드한다.
/// 첫 실행이면 튜토리얼을 자동으로 연다 (RPT-406).
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/services/rune_analytics.dart';
import 'package:rune_puzzle_tactics/services/sqlite_rune_progress_store.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/language_controller.dart';
import '../../services/game_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/card_art.dart';
import '../../widgets/play_shortage_dialog.dart';
import '../../widgets/rewarded_ad_helper.dart';
import '../../widgets/ui_frame.dart';
import 'rune_lobby_tab.dart';
import 'rune_party_tab.dart';
import 'rune_settings_tab.dart';
import 'rune_shop_tab.dart';
import 'stage_prep_dialog.dart';

/// Rune 모드 메인 허브. [store]를 주입하지 않으면 기기에 저장한다(운영 기본).
class RuneMainScreen extends StatefulWidget {
  const RuneMainScreen({
    super.key,
    this.store,
    this.analytics,
    this.audioService,
    this.autoOpenTutorial = true,
  });

  final RuneProgressStore? store;
  final RuneAnalytics? analytics;
  final GameAudioService? audioService;

  /// true(기본): 진행도에 튜토리얼 완료 기록이 없으면 첫 진입 시 자동으로 연다.
  final bool autoOpenTutorial;

  @override
  State<RuneMainScreen> createState() => _RuneMainScreenState();
}

class _RuneMainScreenState extends State<RuneMainScreen> {
  static const int _shopTabIndex = 2;

  /// 각 탭별 배경 이미지 경로 (더미 PNG).
  static const List<String> _tabBackgrounds = [
    'assets/background/lobby_bg.png',
    'assets/background/party_bg.png',
    'assets/background/shop_bg.png',
    'assets/background/settings_bg.png',
  ];

  late final RuneProgressStore _store;

  RuneProgress? _progress;
  Object? _loadError;
  int _index = 0;

  /// Android 뒤로가기 두 번 연속 입력 감지용 시각 (요구사항 1.2).
  DateTime? _lastBackPress;

  RuneAnalytics? get _analytics => widget.analytics;
  GameAudioService get _audioService =>
      widget.audioService ?? GameAudioService.instance;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SqliteRuneProgressStore();
    _reload();
  }

  /// 저장소에서 진행도를 다시 읽는다 (배틀/튜토리얼 귀환, 초기 로드).
  Future<void> _reload() async {
    try {
      final p = await _store.load();
      if (!mounted) return;
      setState(() {
        _progress = p;
        _loadError = null;
      });
      // 최초 실행 온보딩 (요구사항 4.1): '최초 실행'이란 아직 튜토리얼을 완료하지
      // 않은 상태(RuneMeta.initial()의 tutorialCompleted=false)를 말한다.
      // 메인 허브 진입 직후 프레임이 끝난 뒤 튜토리얼로 자동 라우팅한다 (RPT-406).
      final isFirstLaunch = !p.tutorialCompleted;
      if (widget.autoOpenTutorial && isFirstLaunch && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openTutorial();
        });
      }
    } catch (e, st) {
      _analytics?.recordError(e, st, context: 'rune main screen load');
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  /// 진행도 변경 (탭 내부 조작 결과): 상태 갱신 + 저장 + 분석 미포함(탭이 기록).
  void _onProgressChanged(RuneProgress p) {
    setState(() => _progress = p);
    _store.save(p);
  }

  void _selectTab(int index) {
    // 상점 탭 진입 분석 (RPT-308 확장).
    if (index == _shopTabIndex && _index != _shopTabIndex) {
      _analytics?.logShopOpen();
    }
    setState(() => _index = index);
  }

  /// 전투 진입. Play Currency(입장 비용) 소모는 스테이지 준비 확인 후 1회 수행한다.
  /// 배틀에서 pop한 결과가 'shop'이거나(직접 진입 폴백) 결과 화면의 popUntil(요구사항
  /// 6.4)이 '상점으로' 의도를 콜백으로 전달했으면 상점 탭으로 전환 (RPT-410).
  ///
  /// [stageNumber]는 로비 Stage Selector가 넘긴 선택 스테이지다(사양 1-1).
  /// null이면 진행도 기본값([RuneProgress.nextStage])을 사용한다.
  Future<void> _startBattle([int? stageNumber]) async {
    final p = _progress;
    if (p == null) return;

    // 사양 결정 1: 진입 상한 min(highestCleared + 1, maxStage) 안으로 클램핑.
    final stage = (stageNumber ?? p.nextStage).clamp(1, p.selectableMaxStage);

    // 요구사항 3.1: Play(전투 재화)가 부족하면 전투 진입을 막고,
    // [보상형 광고 보기] / [상점으로 이동]을 제공하는 팝업을 띄운다.
    if (p.playCurrency < RuneMeta.stageEntryCost) {
      _analytics?.logCurrencyTx(
        txId: 'stage_entry_denied',
        type: CurrencyType.play,
        amount: 0,
        txType: CurrencyTxType.stageEntry,
        source: 'hub',
      );
      await _showPlayShortageDialog();
      return;
    }

    // 요구사항 6.1: 바로 이동하지 않고 StagePrepDialog(스테이지 정보, 출전 파티,
    // 소모 재화)로 진입을 확인받은 뒤에만 입장 비용을 소모하고 배틀로 이동한다.
    // 사양 1-2: 모달은 [StagePrepOutcome] 으로 "취소/전투 출격"을 구분한다.
    // 파티 편성은 다이얼로그 안의 공통 1x5 슬롯(`+`)에서 인라인으로 끝난다.
    final outcome = await showStagePrepDialog(
      context,
      stageNumber: stage,
      progress: p,
      onChanged: _onProgressChanged,
      stageConfig: StageGenerator().generate(stage),
      entryCost: RuneMeta.stageEntryCost,
      playCurrency: p.playCurrency,
    );
    if (!mounted) return;

    // 취소/닫기 → 재화 미소모.
    if (outcome != StagePrepOutcome.confirm) return;

    final entry = p.tryStageEntry(RuneMeta.stageEntryCost);
    if (!entry.ok) {
      // 방어: 확인 직후 잔액이 바뀐 경우만(거의 없음) 재화 부족 팝업으로 안내.
      _analytics?.logCurrencyTx(
        txId: 'stage_entry_denied',
        type: CurrencyType.play,
        amount: 0,
        txType: CurrencyTxType.stageEntry,
        source: 'hub',
      );
      await _showPlayShortageDialog();
      return;
    }
    _analytics?.logStageEntry(cost: RuneMeta.stageEntryCost);
    _onProgressChanged(entry.progress);

    // 요구사항 6.4: 결과 화면이 popUntil로 배틀 라우트까지 한 번에 정리하면
    // 라우트 결과 값('shop')이 허브에 도달하지 않는다. 대신 '상점으로' 의도를
    // 라우터 플래그(콜백)로 전달받아 귀환 후 상점 탭으로 전환한다.
    var goToShop = false;
    final result = await Navigator.pushNamed(
      context,
      '/runeBattle',
      arguments: <String, dynamic>{
        // 선택 스테이지를 그대로 전달(Stage Selector).
        'stage': stage,
        'store': _store,
        'analytics': _analytics,
        'audioService': _audioService,
        'onShopRequested': () => goToShop = true,
      },
    );
    await _reload();
    if ((result == 'shop' || goToShop) && mounted) {
      setState(() => _index = _shopTabIndex);
    }
  }

  /// 튜토리얼 열기 (자동 첫 실행 / 설정 탭 다시보기, RPT-406).
  Future<void> _openTutorial() async {
    await Navigator.pushNamed(
      context,
      '/runeTutorial',
      arguments: <String, dynamic>{
        'store': _store,
        'analytics': _analytics,
        'audioService': _audioService,
      },
    );
    await _reload();
  }

  /// 진행도 초기화 (설정 탭): 초기 구성으로 되돌린다.
  Future<void> _resetProgress() async {
    // 요구사항 4.2: 전역 상태를 완전 초기 상태(RuneMeta.initial())로 갱신 + 저장.
    await _store.save(RuneMeta.initial());
    await _reload();
    if (!mounted) return;
    // 요구사항 4.2: 초기화 직후 메인 허브의 0번 탭(Lobby)으로 돌아가 UI에 즉시 반영.
    setState(() => _index = 0);
    _lastBackPress = null;
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.tr('main_reset_done'))));
  }

  // ── Play(전투 재화) 부족 팝업 (요구사항 3.1) ──

  /// [보상형 광고 보기] 단축 경로를 제공하는 재화 부족 팝업.
  ///
  /// - 'ad'   → 보상형 광고 시청으로 Play를 충전한 뒤 전투 진입을 재시도.
  Future<void> _showPlayShortageDialog() async {
    // 요구사항 3.1/6.3 공용 팝업 (허브/배틀/결과 화면 동일 UI).
    final action = await showPlayShortageDialog(context);
    if (!mounted) return;
    if (action == 'ad') {
      // 광고 시청 → Play 충전 → 전투 진입 재시도 (요구사항 3.1 단축 경로).
      await _grantPlayFromAdAndRetry();
    }
  }

  /// [보상형 광고 보기]에서 Play를 충전하고 전투 진입을 다시 시도한다.
  ///
  /// 광고 로드/시청 실패 시(요구사항 3.2) 실패 SnackBar를 띄우고 종료한다.
  Future<void> _grantPlayFromAdAndRetry() async {
    final rewarded = await showRewardedAdOnce(
      onReward: () {
        final p = _progress;
        if (p == null) return;
        // 멱등 txId('ad_dialog_play_<ts>')로 중복 지급을 차단한다.
        final r = p.claimRewardedAd(
          txId: 'ad_dialog_play_${DateTime.now().millisecondsSinceEpoch}',
          type: CurrencyType.play,
          amount: RuneMeta.rewardedAdPlay,
        );
        if (r.applied) _onProgressChanged(r.progress);
      },
    );
    if (!mounted) return;
    if (!rewarded) {
      _showAdFailedSnackBar();
      return;
    }
    // 충전 완료 → 전투 진입 재시도 (처음에 부족했던 Play가 이제 충분하다).
    await _startBattle();
  }

  /// 광고 로드/시청 실패 안내 (요구사항 3.2).
  void _showAdFailedSnackBar() {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('ad_load_failed'))));
  }

  // ── Android 뒤로가기 (요구사항 1.2) ──

  /// 메인 허브 뒤로가기 처리:
  /// - Lobby가 아닌 탭에서는 먼저 Lobby(0번 탭)로 이동.
  /// - Lobby에서는 '한 번 더 누르면 종료' SnackBar 후 두 번째 입력 시 앱 종료.
  void _onAndroidBack() {
    if (_index != 0) {
      setState(() => _index = 0);
      _lastBackPress = null;
      return;
    }
    final now = DateTime.now();
    final withinWindow =
        _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);
    if (withinWindow) {
      // 두 번째 입력: 앱 종료.
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('exit_confirm'))));
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final l10n = LanguageScope.of(context).strings;
    // 요구사항 1.2: 메인 허브에서 뒤로가기 시 앱이 바로 닫히지 않도록
    // PopScope로 백 입력을 가로채 '한 번 더 누르면 종료' SnackBar 흐름을 적용한다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onAndroidBack();
      },
      child: Scaffold(
        // 각 탭별 배경 이미지 — 더미 PNG (1080×1920 그라데이션).
        // IndexedStack 위에 배경을 깔아 탭 전환 시 배경이 자연스럽게 바뀐다.
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                _tabBackgrounds[_index],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              ),
            ),
            SafeArea(
              child: _loadError != null
                  ? _buildLoadError()
                  : p == null
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
                      index: _index,
                      children: [
                        RuneLobbyTab(
                          progress: p,
                          onStartBattle: (stage) => _startBattle(stage),
                          onChanged: _onProgressChanged,
                        ),
                        RunePartyTab(
                          progress: p,
                          onChanged: _onProgressChanged,
                        ),
                        RuneShopTab(
                          progress: p,
                          onChanged: _onProgressChanged,
                          analytics: _analytics,
                          // 첫 패배 가이드 진행중이면 상점 뽑기 안내를 노출한다.
                          guideActive: p.firstDefeatGuideStep == 1,
                          onGuideFinished: () => setState(() => _index = 0),
                        ),
                        RuneSettingsTab(
                          onReplayTutorial: _openTutorial,
                          onResetProgress: _resetProgress,
                          audioService: _audioService,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        // 규칙 4: 하단 12px 마진 + 반투명 글래스모피즘 플로팅 바.
        // AdMob 배너(Android 플랫폼 뷰)는 BackdropFilter(saveLayer) 안에 합성할
        // 수 없어 화면 멈춤/검정 렌더링이 생길 수 있으므로, 배너는 blur 밖의 별도
        // 반투명 패널에 두고 탭 바만 blur를 적용한다 (Android 실기기 멈춤 수정).
        //
        // 9-slice 이미지(`drawImageNine`)는 플랫폼 뷰가 아니라 레이어 복사가
        // 필요 없으므로 blur 안에도 안전하다. 반대로 AdMob 배너를 blur 안에
        // 넣으면 위 주석의 문제가 그대로 남는다 — 구조는 그대로 유지한다.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiFrame.round24(
                  width: double.infinity,
                  // 9-slice 는 모서리 타일이 항상 1:1 이므로 최소 크기(=코너 24px
                  // x2 = 48)가 대상 크기를 결정한다. AdMob 패널은 높이 50
                  // 으로 48 보다 크므로 모서리가 살아남는다.
                  fit: StackFit.loose,
                  // 원래 `Container` 에 padding 이 없었다. 테두리 굵이만큼
                  // 안쪽으로 밀면 AdMob(높이 50)이 48 로 줄어든다.
                  insets: EdgeInsets.zero,
                  background: AppColors.glassCardStrong,
                  color: AppColors.glassBorder,
                  child: const Center(child: AdBannerWidget()),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: UiFrame.round24(
                      // `NavigationBar` 가 `Row` + `Expanded` 라 느슨한 제약만
                      // 줘도 폭을 최대로 먹는다. 강제 확장(expand)은 피한다.
                      fit: StackFit.loose,
                      insets: EdgeInsets.zero,
                      background: AppColors.glassCardStrong,
                      color: AppColors.glassBorder,
                      art: const CardArt.fill(kCardArtMainNav),
                      child: NavigationBar(
                        selectedIndex: _index,
                        onDestinationSelected: (index) {
                          _audioService.playEffect(GameSound.uiTap);
                          _selectTab(index);
                        },
                        backgroundColor: Colors.transparent,
                        indicatorColor: AppColors.accentGold.withValues(
                          alpha: 0.22,
                        ),
                        destinations: [
                          NavigationDestination(
                            icon: _pixelNavigationIcon(
                              'assets/UI/nav_home.png',
                              Icons.home_outlined,
                            ),
                            selectedIcon: _pixelNavigationIcon(
                              'assets/UI/nav_home.png',
                              Icons.home,
                            ),
                            label: l10n.tr('nav_lobby'),
                          ),
                          NavigationDestination(
                            icon: _pixelNavigationIcon(
                              'assets/UI/nav_character.png',
                              Icons.groups_outlined,
                            ),
                            selectedIcon: _pixelNavigationIcon(
                              'assets/UI/nav_character.png',
                              Icons.groups,
                            ),
                            label: l10n.tr('nav_party'),
                          ),
                          NavigationDestination(
                            icon: _pixelNavigationIcon(
                              'assets/UI/nav_shop.png',
                              Icons.storefront_outlined,
                            ),
                            selectedIcon: _pixelNavigationIcon(
                              'assets/UI/nav_shop.png',
                              Icons.storefront,
                            ),
                            label: l10n.tr('nav_shop'),
                          ),
                          NavigationDestination(
                            icon: _pixelNavigationIcon(
                              'assets/UI/nav_settings.png',
                              Icons.settings_outlined,
                            ),
                            selectedIcon: _pixelNavigationIcon(
                              'assets/UI/nav_settings.png',
                              Icons.settings,
                            ),
                            label: l10n.tr('nav_settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    final l10n = LanguageScope.of(context).strings;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tr('main_load_error'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _loadError = null);
                _reload();
              },
              child: Text(l10n.tr('common_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pixelNavigationIcon(String asset, IconData legacyIcon) {
  return SizedBox(
    width: 26,
    height: 26,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, filterQuality: FilterQuality.none),
        Icon(legacyIcon, color: Colors.transparent),
      ],
    ),
  );
}
