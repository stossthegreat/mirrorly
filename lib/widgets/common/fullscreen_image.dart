import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Fullscreen image viewer. Simple, brutal, always fills the screen.
///
/// Design: Stack(fit: StackFit.expand) with a SizedBox.expand child that
/// contains the Image. No InteractiveViewer, no Center, no FittedBox. The
/// outer stack forces expand; the SizedBox forces the Image widget to
/// receive tight infinite-bounded constraints; BoxFit.contain then scales
/// the source pixels to fill one axis of the screen.
///
/// Previous bugs came from InteractiveViewer + Center combos passing loose
/// constraints to Image, which then collapsed to native pixel size.
class FullscreenImage extends StatelessWidget {
  final Uint8List? bytes;
  final String?    url;
  final String?    caption;

  const FullscreenImage.memory({super.key, required Uint8List this.bytes, this.caption}) : url = null;
  const FullscreenImage.network({super.key, required String this.url,   this.caption}) : bytes = null;

  static Future<void> open(BuildContext context, {
    Uint8List? bytes, String? url, String? caption,
  }) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => bytes != null
          ? FullscreenImage.memory(bytes: bytes, caption: caption)
          : FullscreenImage.network(url: url!, caption: caption),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = bytes != null
        ? MemoryImage(bytes!) as ImageProvider
        : NetworkImage(url!);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image uses explicit infinity dimensions so it takes ALL space.
            // BoxFit.contain then scales the pixel data to fill one axis,
            // centering with black bars on the other if aspect mismatched.
            Image(
              image: provider,
              fit: BoxFit.contain,
              width:  double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              gaplessPlayback: true,
              loadingBuilder: (_, child, p) {
                if (p == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 30, height: 30,
                    child: CircularProgressIndicator(
                      color: AppColors.red, strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Center(
                child: Text('Image unavailable',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary)),
              ),
            ),

            // Top bar — close + caption
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(width: Sp.sm),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(caption!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: AppColors.red, letterSpacing: 2.0,
                              fontSize: 9)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom hint — tap anywhere to close
            Positioned(
              left: 0, right: 0, bottom: 16,
              child: Center(
                child: Text('TAP TO CLOSE',
                  style: AppTypography.label.copyWith(
                    color: Colors.white54, fontSize: 9, letterSpacing: 2.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
