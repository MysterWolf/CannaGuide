import 'package:purchases_flutter/purchases_flutter.dart';

// Product IDs — update before release
const _entitlementPro = 'pro';
const _entitlementAi = 'ai';
const _productPro = 'pro_499';
const _productAi = 'ai_299_monthly';

class RevenueCatService {
  static bool _configured = false;

  static Future<void> configure(String apiKey) async {
    if (_configured) return;
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
  }

  static Future<String> getCurrentTier() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.containsKey(_entitlementAi)) return 'ai';
      if (info.entitlements.active.containsKey(_entitlementPro)) return 'pro';
      return 'free';
    } catch (_) {
      return 'free';
    }
  }

  static Future<bool> purchasePro() async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .firstWhere((p) => p.storeProduct.identifier == _productPro);
      if (pkg == null) return false;
      await Purchases.purchasePackage(pkg);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> purchaseAi() async {
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .firstWhere((p) => p.storeProduct.identifier == _productAi);
      if (pkg == null) return false;
      await Purchases.purchasePackage(pkg);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }
}
