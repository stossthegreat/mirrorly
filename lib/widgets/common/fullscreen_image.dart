import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Tap-to-open fullscreen image viewer with pinch-zoom. Fills the screen —
/// the Image uses BoxFit.contain but is given tight parent constraints so it
/// scales up to fill one axis. (Previous version centered inside the viewer,
/// which with loose constraints collapsed the image to its native pixel size
/// and rendered as a tiny thumbnail on a black screen.)
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
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => bytes != null
          ? FullscreenImage.memory(bytes: bytes, caption: caption)
          : FullscreenImage.network(url: url!, caption: caption),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fill with Image directly — InteractiveViewer passes its tight
          // constraints to the Image, and BoxFit.contain scales up to fill.
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: true,
              child: SizedBox.expand(
                child: bytes != null
                    ? Image.memory(bytes!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        gaplessPlayback: true)
                    : Image.network(url!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        loadingBuilder: (_, child, p) => p == null ? child
                          : const Center(child: CircularProgressIndicator(
                              color: AppColors.gold, strokeWidth: 2)),
                        errorBuilder: (_, __, ___) => Center(
                          child: Text('Image unavailable',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary)))),
              ),
            ),
          ),

          // Top bar: close + caption
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
                          color: Colors.white.withValues(alpha: 0.12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(caption!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.gold, letterSpacing: 2.0,
                            fontSize: 9)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
