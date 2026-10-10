import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 구글 공식 테스트 배너 광고 단위 ID (개발/디버그용).
///
/// 출시 전 반드시 실서비스 배너 유닛 ID로 교체할 것
/// (예: 'ca-app-pub-1474045642143501/2747098127').
const String kTestBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isDisposed = false;

  // 실제 서비스용 광고 단위 ID (출시 시 kTestBannerAdUnitId → 실서비스 유닛으로 교체)
  final String _adUnitId = kTestBannerAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (_isDisposed) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!_isDisposed && mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err (AdUnitId: $_adUnitId)');
          ad.dispose();
          if (!_isDisposed && mounted) {
            setState(() {
              _isAdLoaded = false;
              _bannerAd = null;
            });
            // 광고 로드 실패 시 5초 후 자동 재시도
            Future.delayed(const Duration(seconds: 5), () {
              if (!_isDisposed && mounted) {
                _loadBannerAd();
              }
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // 로딩 중이거나 실패 시 빈 공간
    return const SizedBox(width: 320, height: 50, child: SizedBox.shrink());
  }
}
