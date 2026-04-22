import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool isAvailable = false;
  ProductDetails? premiumUploadProduct;
  bool isPremiumUser = false;

  // The Product ID we'll configure in Google Play Console / App Store Connect
  // For testing, android supports android.test.purchased
  static const String premiumUploadId = 'spendr_premium_upload';
  
  // Or for quick local testing without connecting Play Console:
  // static const String premiumUploadId = 'android.test.purchased';

  Future<void> init() async {
    isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint("IAP not available on this device.");
      await _loadPremiumStatus();
      return;
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) => _listenToPurchaseUpdated(purchaseDetailsList),
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint("IAP Stream Error: $error");
      },
    );

    await _fetchProducts();
    await _loadPremiumStatus();
    
    // Optionally restore purchases immediately on init
    await _iap.restorePurchases();
  }

  Future<void> _fetchProducts() async {
    final Set<String> kIds = <String>{premiumUploadId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(kIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("Products not found: ${response.notFoundIDs}");
    }

    if (response.productDetails.isNotEmpty) {
      premiumUploadProduct = response.productDetails.first;
      debugPrint("Loaded product: ${premiumUploadProduct!.title} - ${premiumUploadProduct!.price}");
    } else {
      debugPrint("No products available from store.");
    }
  }

  Future<void> buyPremium() async {
    if (premiumUploadProduct == null) {
      debugPrint("Cannot buy: product isn't loaded");
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: premiumUploadProduct!);
    // We treat this as a non-consumable (you buy it once)
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint("Purchase pending UI update...");
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          if (purchaseDetails.productID == premiumUploadId) {
            await _setPremiumStatus(true);
            debugPrint("Successfully purchased Premium or restored it!");
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isPremiumUser = prefs.getBool('is_premium_upload') ?? false;
  }

  Future<void> _setPremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_upload', isPremium);
    isPremiumUser = isPremium;
  }

  void dispose() {
    _subscription.cancel();
  }
}
