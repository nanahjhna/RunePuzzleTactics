/// Rune Puzzle Tactics — 보상형 광고 공용 헬퍼 (RPT-317 확장, 요구사항 3.2)
///
/// [RewardedAdButton] 위젯과 "재화 부족 팝업"([보상형 광고 보기])이 동일한
/// 로드/표시·보상 흐름을 공유하도록 추출한 유틸이다.
/// - 로드/표시 실패를 조용히 넘기지 않고 호출부가 안내 SnackBar를 노출할 수 있도록
///   성공 여부(bool)를 반환한다 (광고 로딩/시청 실패 예외 처리).
/// - 보상 지급 자체(멱등 txId 적용 포함)는 호출부가 담당한다 (중복 콜백 안전).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 구글 공식 테스트 보상형 광고 단위 ID (RPT-318).
const String kRewardedAdTestUnitId = 'ca-app-pub-3940256099942544/5224354917';

/// 광고 로드가 실제로 끝나기까지 기다리는 최대 시간.
///
/// google_mobile_ads의 로드 결과는 네이티브 SDK의 비동기 콜백으로 도착하므로
/// 네트워크/디바이스 상태에 따라 영원히 끝나지 않을 수 있다. 무한 대기를 막아
/// 다이얼로그/버튼 흐름이 멈추지 않도록 상한을 둔다.
const Duration _kRewardedAdLoadTimeout = Duration(seconds: 30);

/// 보상형 광고 1회 로드·표시 흐름을 소유하는 헬퍼.
///
/// [load]로 미리 로드한 뒤 [show]로 표시한다. [show]가 끝나면 헬퍼가 광고를
/// 소모하므로 다시 사용하려면 [load]를 재호출해야 한다 (single-fire).
///
/// **중요**: google_mobile_ads에서 `RewardedAd.load`는 로드 *요청*을 네이티브에
/// 전달하고 즉시 반환하며, 실제 완료는 `onAdLoaded`/`onAdFailedToLoad` 콜백으로
/// 도착한다. 그래서 [load]는 콜백을 직접 기다려 **실제 로드 완료** 시점에
/// 성공 여부를 반환한다 — 그렇지 않으면 로드 직후 [show]를 호출해도 아직
/// 광고가 없어 항상 실패한다 (전 화면 보상광고 미동작 원인).
class RewardedAdHelper {
  RewardedAdHelper({this.adUnitId = kRewardedAdTestUnitId});

  final String adUnitId;

  RewardedAd? _ad;
  bool _loaded = false;
  bool _disposed = false;
  bool _showing = false;

  /// 광고 로드 완료 여부 (표시 가능 상태).
  bool get isLoaded => _loaded && _ad != null;

  /// 광고를 로드하고 실제 로드 완료까지 기다린다.
  ///
  /// 로드 성공 시 `true`, 실패/타임아웃/이미 dispose된 경우 `false`를 반환한다.
  /// 예외를 던지지 않으므로 호출부가 분기만으로 성공/실패를 처리할 수 있다.
  Future<bool> load() async {
    if (_disposed) return false;
    if (_loaded && _ad != null) return true;

    // onAdLoaded/onAdFailedToLoad가 실제로 도착할 때까지 완료를 보류한다.
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              ad.dispose();
              return;
            }
            _ad = ad;
            _loaded = true;
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            // 로드 실패: 재시도 가능한 일시 오류로 보고 비활성 상태 유지.
            debugPrint('RewardedAd 로드 실패: $error');
            _loaded = false;
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      // 테스트/플러그인 미초기화 환경에서도 비활성 유지 (앱 진행은 계속).
      debugPrint('RewardedAd.load 예외: $e');
      return false;
    }
    return completer.future.timeout(
      _kRewardedAdLoadTimeout,
      onTimeout: () {
        debugPrint('RewardedAd 로드 타임아웃 ($_kRewardedAdLoadTimeout)');
        return false;
      },
    );
  }

  /// 로드된 광고를 표시한다.
  ///
  /// - 보상 승인 시 [onReward]를 1회 호출하고 `true`를 반환.
  /// - 광고 로드 전/표시 실패/보상 없이 닫은 경우 `false`를 반환.
  /// - 이미 표시 중이면 중복 표시를 막고 `false`를 반환한다.
  Future<bool> show({VoidCallback? onReward}) {
    final ad = _ad;
    if (ad == null || !_loaded || _disposed || _showing) {
      return Future.value(false);
    }
    _showing = true;
    final completer = Completer<bool>();
    var rewarded = false;
    var settled = false;

    void settle() {
      if (settled) return;
      settled = true;
      _showing = false;
      _ad = null;
      _loaded = false;
      if (!completer.isCompleted) completer.complete(rewarded);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        settle();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('RewardedAd 표시 실패: $error');
        a.dispose();
        settle();
      },
    );
    ad.show(
      onUserEarnedReward: (_, _) {
        rewarded = true;
        onReward?.call();
      },
    );
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
  }
}

/// [RewardedAdHelper]를 사용한 1회성 표시 흐름.
///
/// 로드 **완료**를 기다린 뒤 표시 → 정리를 한 번에 수행한다.
/// 보상을 받았으면 `true`, 로드/표시 실패이거나 보상 없이 닫았으면 `false`.
Future<bool> showRewardedAdOnce({
  String adUnitId = kRewardedAdTestUnitId,
  VoidCallback? onReward,
}) async {
  final helper = RewardedAdHelper(adUnitId: adUnitId);
  try {
    // 실제 로드 완료(onAdLoaded)까지 기다려야 show()가 광고를 찾을 수 있다.
    if (!await helper.load()) return false;
    return await helper.show(onReward: onReward);
  } finally {
    helper.dispose();
  }
}
