import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static Future<void> initAds() async {
    await MobileAds.instance.initialize();
  }

  // Sample Test Banner Unit ID
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  // Sample Test Interstitial Unit ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  static InterstitialAd? _interstitialAd;

  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  static void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitialAd(); // Preload next
    }
  }
}
