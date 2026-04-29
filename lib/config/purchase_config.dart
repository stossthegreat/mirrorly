/// RevenueCat public SDK keys + product/entitlement identifiers.
///
/// ──────────────────────────────────────────────────────────────────────
/// WHAT YOU NEED TO DO BEFORE PAYMENT WORKS
/// ──────────────────────────────────────────────────────────────────────
/// 1. Log in to https://app.revenuecat.com
/// 2. Create a project "Mirrorly" if you haven't already.
/// 3. Project Settings → API Keys — copy:
///      - "Public SDK Key" for the iOS app  (starts with  appl_…)
///      - "Public SDK Key" for the Android app (starts with  goog_…)
///    Paste them into the two consts below.
/// 4. In RevenueCat: Products → Add each App Store / Play product by
///    the exact identifier strings in [PurchaseConfig.productIds].
/// 5. Entitlements → Create `pro` → attach both the monthly and the
///    annual subscription products to it. (The 20-credit pack does
///    NOT entitle `pro` — it's a consumable credit grant, handled
///    separately.)
/// 6. Offerings → Default Offering → attach all three products as
///    packages with identifiers that match the `packageId` values
///    in [PurchaseConfig.offering].
/// 7. Publish the offering. Rebuild the Flutter app.
///
/// Until keys are filled in the app still runs — the paywall just
/// shows "—" for prices and the CTA is disabled. No hardcoded prices
/// ever ship to the store.
/// ──────────────────────────────────────────────────────────────────────
class PurchaseConfig {
  /// RevenueCat public SDK key for iOS. Starts with `appl_`.
  static const iosApiKey     = 'appl_LZCBJirwBRyekXFKrBGdcdnyRLJ';

  /// RevenueCat public SDK key for Android. Starts with `goog_`.
  static const androidApiKey = 'goog_cdoFAjjiwMkzsxNjPBwoKalEwkF';

  /// The entitlement identifier that grants Mirrorly Pro. Configured
  /// in RevenueCat dashboard → Entitlements. Both monthly and annual
  /// subscriptions attach to this entitlement.
  static const proEntitlementId = 'pro';

  /// Product identifiers — MUST match exactly what's in App Store
  /// Connect and Google Play Console.
  ///   mirrorly_pro_monthly   →  Monthly subscription
  ///   mirrorly_pro_annual    →  Annual subscription
  ///
  /// The 20-credit rescue pack is intentionally NOT here. Credits are
  /// no longer sold through RevenueCat — that flow has moved out of
  /// the paywall. Re-introduce a credits product here only if the
  /// in-app credit pack ever returns to the RC integration path.
  static const productIds = (
    monthly: 'mirrorly_pro_monthly',
    yearly:  'mirrorly_pro_annual',
  );

  /// RevenueCat package identifiers inside the Default Offering.
  /// RevenueCat has built-in slot names ($rc_monthly, $rc_annual)
  /// for the two subscriptions — those are what we attach products
  /// to in the dashboard.
  static const offering = (
    monthlyPackage: '\$rc_monthly',
    annualPackage:  '\$rc_annual',
  );

  /// Convenience — true once keys are filled in. Lets the app avoid
  /// configuring RevenueCat at all during development when the fields
  /// are blank, instead of hitting the SDK with an empty key and
  /// crashing.
  static bool get isConfigured =>
      iosApiKey.isNotEmpty || androidApiKey.isNotEmpty;
}
