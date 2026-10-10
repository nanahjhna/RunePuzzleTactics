/// Rune Puzzle Tactics — 보상형 광고 버튼 (RPT-317, 3-재화 설계 §21)
///
/// 로드/표시 로직은 [RewardedAdHelper]와 공유한다 (요구사항 3.2).
/// - 로드 성공 시에만 활성화되고, 보상 지급 → 닫기 → 다음 광고 재로드 (single-fire).
/// - 보상은 [onRewardGranted]로 전달되며 호출부(로비)는 멱등 트랜잭션 id로
///   원장에 반영한다 (중복 콜백 안전, 프롬프트 §6).
/// - 로드/표시 실패 시 "광고를 불러올 수 없습니다" SnackBar를 노출한다.
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:rune_puzzle_tactics/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import 'rewarded_ad_helper.dart';

/// 보상형 광고 버튼.
///
/// [rewardCurrency]/[rewardAmount]는 이 버튼이 지급할 보상 정의이고,
/// 보상 지급 시 [onRewardGranted](CurrencyType, amount)를 1회 호출한다.
/// id 기반 멱등 적용은 호출부가 담당한다.
class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton({
    super.key,
    required this.label,
    required this.rewardCurrency,
    required this.rewardAmount,
    required this.onRewardGranted,
    this.adUnitId = kRewardedAdTestUnitId,
  });

  /// 버튼 라벨 (예: '▶ Watch Ad: +1 🎟').
  final String label;

  /// 지급할 재화 종류.
  final CurrencyType rewardCurrency;

  /// 지급할 재화 수량.
  final int rewardAmount;

  /// 보상 지급 콜백: (재화 종류, 수량).
  final void Function(CurrencyType type, int amount) onRewardGranted;

  /// 실제 서비스용 광고 단위 ID (테스트 기본값 대체 가능).
  final String adUnitId;

  @override
  State<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends State<RewardedAdButton> {
  late final RewardedAdHelper _helper = RewardedAdHelper(
    adUnitId: widget.adUnitId,
  );
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    await _helper.load();
    if (_isDisposed || !mounted) return;
    setState(() {}); // 로드 완료 상태 반영(활성화).
  }

  Future<void> _showAd() async {
    final rewarded = await _helper.show(
      onReward: () {
        // 보상 승인 시 이 버튼의 보상 정의(재화 종류/수량)를 1회 전달한다.
        // 같은 id 트랜잭션은 원장이 멱등으로 차단하므로 중복 호출에도 안전.
        widget.onRewardGranted(widget.rewardCurrency, widget.rewardAmount);
      },
    );
    if (_isDisposed || !mounted) return;
    if (!rewarded) {
      // 광고 로드/표시 실패 또는 보상 없이 종료 → 안내 (요구사항 3.2).
      _showAdFailedSnackBar();
      if (_isDisposed || !mounted) return;
    }
    await _loadAd(); // 다음 시청 준비 (single-fire 재사용)
  }

  /// 광고 로드/시청 실패 안내 (요구사항 3.2).
  void _showAdFailedSnackBar() {
    final l10n = LanguageScope.of(context).strings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('ad_load_failed'))));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _helper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _helper.isLoaded;
    return OutlinedButton.icon(
      onPressed: loaded ? _showAd : null,
      icon: const Icon(Icons.play_circle_outline, size: 18),
      label: Text(widget.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: loaded ? AppColors.accent : Colors.white30,
        side: const BorderSide(color: Colors.white24),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
