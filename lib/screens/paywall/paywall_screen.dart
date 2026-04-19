import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// The unlock screen. Editorial, direct, zero "try it free" noise.
/// Designed to load AFTER splash and BEFORE home once the real paywall is
/// wired — for now it's a bypassable surface so flow can be tested.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  static const _bullets = [
    ('Measurement engine',   '9 geometric axes · 468-landmark mesh · real bone-structure analysis'),
    ('Maximized Twin',       'Flux Kontext identity-locked render of your optimized self'),
    ('AI Advisor',           'Answers every question against YOUR measurements, not a generic face'),
    ('Protocol system',      '60-day programs tuned to your pulldown. Weekly rescans. Progress charts.'),
    ('Generation vault',     'Every haircut / beard / skin / glasses render, saved and revisitable'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Mirrorly',
                        style: AppTypography.h1.copyWith(
                          fontSize: 26, letterSpacing: -0.6, height: 1)),
                      const SizedBox(width: 10),
                      Container(
                        width: 5, height: 5, margin: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.gold, shape: BoxShape.circle),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: Sp.xs),
                  Text('PRIVATE MEMBERSHIP',
                    style: AppTypography.label.copyWith(
                      color: AppColors.gold, letterSpacing: 3.0, fontSize: 9))
                    .animate().fadeIn(delay: 120.ms, duration: 400.ms),

                  const SizedBox(height: Sp.xl),

                  Text('The face,\nmaximized.',
                    style: AppTypography.h1.copyWith(
                      fontSize: 44, letterSpacing: -1.5, height: 1.08))
                    .animate().fadeIn(delay: 200.ms, duration: 500.ms),
                  const SizedBox(height: Sp.sm),
                  Text('A private aesthetic advisor that sees your bones.',
                    style: AppTypography.h1Italic.copyWith(
                      fontSize: 17, color: AppColors.textSecondary, height: 1.4))
                    .animate().fadeIn(delay: 320.ms, duration: 500.ms),

                  const SizedBox(height: Sp.xxl),

                  for (var i = 0; i < _bullets.length; i++) ...[
                    _BulletRow(
                      title: _bullets[i].$1,
                      body:  _bullets[i].$2,
                      delay: 420 + i * 80,
                    ),
                    if (i != _bullets.length - 1) const SizedBox(height: Sp.md),
                  ],

                  const SizedBox(height: Sp.xxl),

                  _PriceCard().animate().fadeIn(delay: 1000.ms, duration: 500.ms),

                  const SizedBox(height: Sp.md),
                  Text(
                    'Membership renews monthly. No free tier. Cancel anytime.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),

            // Sticky CTA
            Positioned(
              left: Sp.lg, right: Sp.lg, bottom: Sp.md,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.base,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Rd.lg)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await LocalStoreService.setSubscribed(true);
                        await LocalStoreService.setOnboarded(true);
                        if (context.mounted) context.go('/home');
                      },
                      child: const Text('Unlock — £14.99 / month',
                        style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15,
                          letterSpacing: 0.4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dev-only: skip. Remove when real IAP wires in.
                  TextButton(
                    onPressed: () async {
                      await LocalStoreService.setOnboarded(true);
                      if (context.mounted) context.go('/home');
                    },
                    child: Text('Skip (dev)',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textTertiary, fontSize: 10,
                        letterSpacing: 1.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String title, body;
  final int delay;
  const _BulletRow({required this.title, required this.body, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16, height: 16, margin: const EdgeInsets.only(top: 3, right: 12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 0.8),
          ),
          child: const Icon(Icons.check_rounded,
            size: 11, color: AppColors.gold),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary, letterSpacing: 2.0, fontSize: 11)),
              const SizedBox(height: 3),
              Text(body,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary, fontSize: 12.5, height: 1.5)),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(
      delay: Duration(milliseconds: delay), duration: 400.ms)
      .slideX(begin: -0.04, end: 0,
        delay: Duration(milliseconds: delay), duration: 400.ms,
        curve: Curves.easeOut);
  }
}

class _PriceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.12),
            AppColors.surface1,
          ],
        ),
        borderRadius: BorderRadius.circular(Rd.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('£14.99',
                style: AppTypography.display.copyWith(
                  fontSize: 42, color: AppColors.gold, letterSpacing: -1.5, height: 1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('/ month',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Less than one surgeon\'s consultation, forever.',
            style: AppTypography.h1Italic.copyWith(
              fontSize: 14, color: AppColors.textSecondary, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}
