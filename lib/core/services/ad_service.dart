import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // TEST ID provided by Google AdMob documentation. 
  // IMPORTANT: For production, replace this with your actual Play Console App ID unit.
  final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          debugPrint('Rewarded ad loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isAdLoaded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Shows the rewarded ad and returns a distinct Future<bool> that completes 
  /// with true if the user earned the reward, or false if they dismissed it early.
  Future<bool> showRewardedAd() async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('Warning: attempt to show rewarded ad before it was loaded.');
      _loadRewardedAd(); // Try to load for next time
      return false; 
    }

    final Completer<bool> completer = Completer<bool>();
    bool didEarnReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Ad showed fullscreen content.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Ad dismissed. Reward earned? $didEarnReward');
        ad.dispose();
        _loadRewardedAd(); // Load the next one immediately
        if (!completer.isCompleted) {
          completer.complete(didEarnReward);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Ad failed to show: $error');
        ad.dispose();
        _loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
        debugPrint('Reward earned: ${rewardItem.amount} ${rewardItem.type}');
        didEarnReward = true;
      },
    );

    return completer.future;
  }
}
