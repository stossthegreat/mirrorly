import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/mirrorly_wordmark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final onboarded   = await LocalStoreService.isOnboarded();
    final hasGender   = (await LocalStoreService.userGender()) != null;
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Gating order:
    //
    // 0) FIRST EVER LAUNCH (no gender, never onboarded) → play the
    //    cinematic INTRO REEL. It pushes /onboarding/gender after BEGIN
    //    so the rest of the funnel proceeds as designed.
    //
    // 1) Has the user picked Men's / Women's? If NOT — even if they've
    //    already completed onboarding on a previous version of the app
    //    — send them to /onboarding/gender and force a pick. Without
    //    this every analysis + render downstream stays male-coded for
    //    women, which is brand-killing.
    //
    // 2) Otherwise, returning user → /home.
    //
    // 3) Otherwise, fresh install (no onboarded flag, no gender) →
    //    /onboarding/gender too. Same destination as case 1 but the
    //    gender screen also serves as the entry funnel for first
    //    launches.
    if (!hasGender && !onboarded) {
      context.go('/intro');
    } else if (!hasGender) {
      context.go('/onboarding/gender');
    } else {
      context.go(onboarded ? '/home' : '/scan');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cinematic black loading screen. The logo sits a touch above centre
    // with a soft red bloom behind it and a slow breathing halo, the
    // ImHim Looks wordmark beneath (set like the Looks-tab header), and a
    // slim red loading bar near the bottom so it reads as a real loading
    // state. Black + red only — the brand's editorial palette.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Ambient red bloom behind the logo + faint red floor.
          const Positioned.fill(child: _AmbientBackdrop()),

          // Logo + wordmark, sitting a touch above centre.
          Align(
            alignment: const Alignment(0, -0.22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const _PulsingHalo(),
                      Image.asset(
                        'assets/icons/appstore.png',
                        width: 150,
                        height: 150,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 150, height: 150,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                          .scale(
                            begin: const Offset(0.94, 0.94),
                            end: const Offset(1, 1),
                            duration: 900.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const MirrorlyWordmark(fontSize: 40)
                    .animate()
                    .fadeIn(delay: 260.ms, duration: 700.ms, curve: Curves.easeOut)
                    .moveY(
                      begin: 8, end: 0,
                      delay: 260.ms, duration: 700.ms,
                      curve: Curves.easeOut,
                    ),
              ],
            ),
          ),

          // Slim loading bar near the bottom.
          Align(
            alignment: const Alignment(0, 0.8),
            child: const _LoadingBar()
                .animate()
                .fadeIn(delay: 700.ms, duration: 800.ms),
          ),
        ],
      ),
    );
  }
}

// ── Soft red radial bloom behind the logo + a faint red floor ────────────────
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Red bloom radiating from behind the logo.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.28),
                radius: 1.0,
                colors: [
                  AppColors.red.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
        // Faint red wash along the very bottom — echoes the logo art's base.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.red.withValues(alpha: 0.10),
                ],
                stops: const [0.72, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slow breathing red halo sitting behind the logo ──────────────────────────
class _PulsingHalo extends StatelessWidget {
  const _PulsingHalo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.red.withValues(alpha: 0.30),
            Colors.transparent,
          ],
          stops: const [0.0, 0.70],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.45, end: 0.9, duration: 1600.ms, curve: Curves.easeInOut)
        .scaleXY(begin: 0.9, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut);
  }
}

// ── Slim indeterminate loading bar — a red segment sweeping a dim track ───────
class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 3,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 44,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .slideX(
              begin: -0.2, end: 2.2,
              duration: 1150.ms,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}
