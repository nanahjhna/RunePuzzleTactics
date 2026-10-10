/// Rune Analytics/Crashlytics 래퍼 (PHASE 5, RPT-308 ~ RPT-309)
///
/// 기존 Firebase 초기화(firebase_core)를 재사용해 이벤트/오류를 기록한다.
///  - 모든 호출은 try/catch로 감싸고, Firebase 미초기화 시 조용히 무시한다
///    (오프라인 우선, 테스트 환경 안전, RPT-316).
///  - 테스트에서는 `RuneAnalytics(enabled: false)` 또는 null 주입으로 비활성화.
library;

import 'dart:async';

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class RuneAnalytics {
  const RuneAnalytics({this.enabled = true});

  /// false면 모든 이벤트가 no-op (테스트/디버그).
  final bool enabled;

  static const RuneAnalytics disabled = RuneAnalytics(enabled: false);

  bool get _ready => enabled && Firebase.apps.isNotEmpty;

  Future<void> _log(String name, Map<String, Object> params) async {
    if (!_ready) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('RuneAnalytics log 실패($name): $e');
    }
  }

  // ── 이벤트 (RPT-308) ──

  /// 앱 오픈 (Firebase 초기화 직후 1회).
  void logAppOpen() {
    unawaited(_log('app_open', const {}));
  }

  /// 튜토리얼 시작.
  void logTutorialStart() {
    unawaited(_log('tutorial_start', const {}));
  }

  /// 상점 탭 진입.
  void logShopOpen() {
    unawaited(_log('shop_open', const {}));
  }

  /// 재화 거래 (원자적 성공분만 기록, RPT-316 원장).
  void logCurrencyTx({
    required String txId,
    required CurrencyType type,
    required int amount,
    required CurrencyTxType txType,
    required String source,
  }) {
    unawaited(
      _log('rune_currency_tx', {
        'tx_id': txId,
        'currency': type.name,
        'amount': amount,
        'tx_type': txType.name,
        'source': source,
      }),
    );
  }

  /// 배틀 시작.
  void logBattleStart(BattleState state) {
    unawaited(
      _log('rune_battle_start', {
        'stage': state.stage.stageNumber,
        'stage_type': state.stage.type.name,
        // 몬스터는 무속성이므로 상성은 스테이지가 정한다.
        'weak_element': state.stage.weakElement.name,
        'resist_element': state.stage.resistElement.name,
        'party_hp': state.partyMaxHp,
      }),
    );
  }

  /// 승리 (Game Currency 보상 포함).
  void logVictory({required int stage, required int gameReward}) {
    unawaited(
      _log('rune_battle_victory', {'stage': stage, 'game_reward': gameReward}),
    );
  }

  /// 패배.
  void logDefeat({required int stage}) {
    unawaited(_log('rune_battle_defeat', {'stage': stage}));
  }

  /// 영웅 영입 (1회 추첨 단위).
  ///
  /// [rarity] = 확정에 반영된 등급, [outcome] = `newHero` / `promoted` / `maxed`.
  void logHeroRecruit({
    required String heroId,
    required RuneElement element,
    HeroRarity? rarity,
    String? outcome,
  }) {
    unawaited(
      _log('rune_hero_recruit', {
        'hero_id': heroId,
        'element': element.name,
        if (rarity != null) 'rarity': rarity.name,
        'outcome': ?outcome,
      }),
    );
  }

  /// 일일 보상 수령 (Play/Hero).
  void logDailyReward({required int play, required int hero}) {
    unawaited(_log('rune_daily_reward', {'play': play, 'hero': hero}));
  }

  /// 보상형 광고 보상 지급.
  void logRewardedAd({required CurrencyType type, required int amount}) {
    unawaited(
      _log('rune_rewarded_ad', {'currency': type.name, 'amount': amount}),
    );
  }

  /// 배틀 입장 비용 지불 (Play Currency).
  void logStageEntry({required int cost}) {
    unawaited(_log('rune_stage_entry', {'cost': cost}));
  }

  /// 영웅 개별 스탯 강화 (영웅 상세 팝업).
  ///
  /// 옛 상점 마도서/영구 업그레이드 구매 이벤트(`logBookPurchase`,
  /// `logUpgradePurchase`)를 대체한다 — 강화가 상점에서 영웅 단위로 옮겨 갔다.
  void logHeroStatUpgrade({
    required String heroId,
    required String stat,
    required int level,
  }) {
    unawaited(
      _log('rune_hero_stat_upgrade', {
        'hero': heroId,
        'stat': stat,
        'level': level,
      }),
    );
  }

  /// 튜토리얼 완료/스킵 (RPT-406).
  void logTutorialComplete({required bool skipped}) {
    unawaited(_log('rune_tutorial_complete', {'skipped': skipped}));
  }

  /// 도중 이탈(retreat).
  void logRetreat({required int stage}) {
    unawaited(_log('rune_battle_retreat', {'stage': stage}));
  }

  // ── Crashlytics (RPT-309) ──

  /// Rune 모드 진행 중 오류 기록. 앱은 계속 실행된다.
  ///
  /// [keys]는 Crashlytics custom key로 노출된다 (예: fatal 여부, 스테이지).
  void recordError(
    Object error,
    StackTrace stack, {
    String? context,
    Map<String, Object>? keys,
  }) {
    if (!_ready) return;
    try {
      final crash = FirebaseCrashlytics.instance;
      keys?.forEach((k, v) => crash.setCustomKey(k, v));
      crash.recordError(error, stack, reason: context, fatal: false);
    } catch (e) {
      debugPrint('Crashlytics 기록 실패: $e');
    }
  }

  /// 진행도 저장 실패 등 데이터 안정성 이벤트.
  void logSaveError(String context, Object error) {
    unawaited(_log('rune_save_error', {'context': context}));
    debugPrint('Rune 저장 실패($context): $error');
  }
}
