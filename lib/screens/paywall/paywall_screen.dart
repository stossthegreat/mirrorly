import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Mirrorly paywall — single screen, no scroll, three identical price cards.
///
/// Design constraints (from product brief):
/// - Black background, white text, red accents only.
/// - Logo centre-top, three powerful selling points, three identical-size
///   price cards with one selected by default, big red CTA, terms below.
/// - No "free trial" messaging. Honest pricing only — Apple's review process
///   rejects vague trial language.
/// - Three IAP product IDs (must match App Store Connect):
///     mirrorly_pro_monthly  £9.99/mo   (auto-renew)
///     mirrorly_pro_yearly   £89.99/yr  (auto-renew, "save 25%" badge)
///     mirrorly_pro_rescue   £8.99      (one-time → 20 image credits)
///
/// IAP wiring is left as a stub against LocalStoreService; replace
/// `_purchase` with the real `in_app_purchase` flow when keys land.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  // Default selected = annual (highest LTV, anchors against monthly).
  String _selected = 'mirrorly_pro_yearly';

  static const _tiers = <_Tier>[
    _Tier(
      id: 'mirrorly_pro_monthly',
      title: 'MONTHLY',
      price: '£9.99',
      cadence: 'per month',
      footnote: 'Cancel anytime',
      badge: null,
    ),
    _Tier(
      id: 'mirrorly_pro_yearly',
      title: 'ANNUAL',
      price: '£89.99',
      cadence: 'per year · £7.50/mo',
      footnote: 'Best value',
      badge: 'SAVE 25%',
    ),
    _Tier(
      id: 'mirrorly_pro_rescue',
      title: '20 CREDITS',
      price: '£8.99',
      cadence: 'one-time · no sub',
      footnote: '1 image per credit',
      badge: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Logo (centre top) ─────────────────────────────────────
              const _Wordmark()
                  .animate()
                  .fadeIn(duration: 380.ms)
                  .slideY(begin: -0.18, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 4),

              // ── 2. Differentiator strap (anti-gimmick line) ──────────────
              Center(
                child: Text('NOT A GIMMICK · REAL FACE GEOMETRY',
                  style: AppTypography.label.copyWith(
                    color: AppColors.red,
                    fontSize: 9, letterSpacing: 3.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 360.ms),

              const SizedBox(height: 24),

              // ── 3. Three selling points ──────────────────────────────────
              const _Point(
                n: '1',
                headline: 'WE MEASURE EVERY FACIAL BONE',
                body: '16 surgical measurements. Sub-millimetre. No guessing.',
              ),
              const SizedBox(height: 14),
              const _Point(
                n: '2',
                headline: '5 MAXIMIZED IMAGES PER WEEK',
                body: 'Your real face, rendered at its peak. Hairstyles. Beard. Skin. Glasses.',
              ),
              const SizedBox(height: 14),
              const _Point(
                n: '3',
                headline: 'YOUR FACE DOCTOR, ON CALL',
                body: 'Knows every inch of your anatomy. Every fix designed for your bones — not a generic.',
              ),

              const Spacer(),

              // ── 4. Three identical price cards ───────────────────────────
              Row(
                children: [
                  for (final t in _tiers) ...[
                    Expanded(
                      child: _PriceCard(
                        tier: t,
                        selected: _selected == t.id,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selected = t.id);
                        },
                      ),
                    ),
                    if (t != _tiers.last) const SizedBox(width: 8),
                  ],
                ],
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // ── 5. Big red CTA ───────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    shadowColor: AppColors.redGlow,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(
                      AppColors.redDim.withValues(alpha: 0.3)),
                  ),
                  onPressed: () => _purchase(context, _selected),
                  child: Text(
                    _selected == 'mirrorly_pro_rescue'
                        ? 'BUY 20 CREDITS — £8.99'
                        : 'CONTINUE',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15, letterSpacing: 2.4,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 720.ms, duration: 400.ms),

              const SizedBox(height: 14),

              // ── 6. Terms / privacy / restore (Apple requires) ────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LinkButton(
                    label: 'TERMS',
                    onTap: () => _showLegal(context, 'Terms of Use',
                        'mirrorly.app/terms'),
                  ),
                  _LinkButton(
                    label: 'PRIVACY',
                    onTap: () => _showLegal(context, 'Privacy Policy',
                        'mirrorly.app/privacy'),
                  ),
                  _LinkButton(label: 'RESTORE', onTap: _restore),
                ],
              ),

              // Auto-renew disclosure (Apple-required for sub products).
              if (_selected != 'mirrorly_pro_rescue')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Subscription auto-renews. Cancel anytime in App Store settings.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10, height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, String productId) async {
    HapticFeedback.mediumImpact();
    // STUB — wire to in_app_purchase here. For now, mark as subscribed and
    // proceed to home so flow can be tested.
    await LocalStoreService.setSubscribed(true);
    await LocalStoreService.setOnboarded(true);
    if (context.mounted) context.go('/home');
  }

  Future<void> _restore() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('No previous purchases found.'),
      backgroundColor: Colors.black,
    ));
  }

  void _showLegal(BuildContext context, String title, String url) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          'Read the full document at $url',
          style: TextStyle(
            color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close',
              style: TextStyle(
                color: AppColors.red, fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  WIDGETS
// ──────────────────────────────────────────────────────────────────────────

class _Tier {
  final String id, title, price, cadence, footnote;
  final String? badge;
  const _Tier({
    required this.id, required this.title, required this.price,
    required this.cadence, required this.footnote, this.badge,
  });
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mirrorly',
            style: AppTypography.h1.copyWith(
              fontSize: 30, letterSpacing: -0.8, height: 1)),
          const SizedBox(width: 8),
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              color: AppColors.red, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String n, headline, body;
  const _Point({required this.n, required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(n,
            style: AppTypography.h1.copyWith(
              color: AppColors.red, fontSize: 24,
              fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline,
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontSize: 11, letterSpacing: 2.0,
                  fontWeight: FontWeight.w800,
                )),
              const SizedBox(height: 3),
              Text(body,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5, height: 1.4,
                )),
            ],
          ),
        ),
      ],
    ).animate(delay: Duration(milliseconds: 320 + int.parse(n) * 80))
      .fadeIn(duration: 400.ms)
      .slideX(begin: -0.04, end: 0, curve: Curves.easeOut);
  }
}

/// Identical-size price card. Selected = red border + red price + glow.
class _PriceCard extends StatelessWidget {
  final _Tier tier;
  final bool selected;
  final VoidCallback onTap;
  const _PriceCard({
    required this.tier, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.red : Colors.white24;
    final priceColor  = selected ? AppColors.red : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        height: 132,  // identical for all 3
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.redGlow : Colors.transparent,
          border: Border.all(color: borderColor, width: selected ? 1.5 : 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tier.title,
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontSize: 9, letterSpacing: 1.6,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (tier.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(tier.badge!,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 7.5,
                        letterSpacing: 0.8, fontWeight: FontWeight.w900,
                      )),
                  ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(tier.price,
                style: AppTypography.display.copyWith(
                  color: priceColor,
                  fontSize: 26, height: 1, letterSpacing: -1.0,
                  fontWeight: FontWeight.w800,
                )),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.cadence,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9, fontWeight: FontWeight.w600, height: 1.2,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(tier.footnote,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 8.5, fontWeight: FontWeight.w500, height: 1.2,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label,
        style: TextStyle(
          color: AppColors.textTertiary, fontSize: 10,
          letterSpacing: 1.5, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
