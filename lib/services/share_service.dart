import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../widgets/common/share_card.dart';

/// Captures any widget via RepaintBoundary + exports a PNG + opens the
/// system share sheet. Supports:
/// - Simple repaint-boundary share (widget already on screen)
/// - Off-screen ShareCard render (composed just for sharing, never shown)
class ShareService {
  /// Screenshot an existing widget wrapped in RepaintBoundary via GlobalKey.
  static Future<void> shareFromKey(
    GlobalKey key, {
    String suggestedName = 'mirrorly.png',
    String? text,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final origin = _sharePositionOriginFromKey(key);
      await _shareBytes(byteData.buffer.asUint8List(), suggestedName, text,
          origin: origin);
    } catch (_) {}
  }

  /// Render the ShareCard off-screen at 1080×1920, capture as PNG, open
  /// share sheet. The card never appears in UI — pure composition.
  ///
  /// Format is the 9:16 export of the in-app hero card: score transition
  /// on top (CURRENT → PROJECTED with red arrow), before/after with
  /// "Mirrorly" overlaid on the NOW half, tagline, three proof lines,
  /// domain footer. Same visual language in-app and on socials.
  ///
  /// Pass currentScore / projectedScore = 0 from contexts that don't have
  /// scores (e.g. chat inline tryon); the card hides the score row and
  /// shows the brand wordmark at the top instead.
  static Future<void> shareComposed({
    required BuildContext context,
    required Uint8List? beforeBytes,
    required String? afterUrl,
    required int currentScore,
    required int projectedScore,
    required String tagline,
    required List<String> microProofs,
    String? text,
  }) async {
    HapticFeedback.lightImpact();

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (_) => const _RenderingOverlay(),
      );
    }

    // Anchor for the iOS share sheet — REQUIRED on iPad (the system
    // pops the action sheet from a popover that needs a source rect),
    // and useful on iPhone too because under iOS 26's UIScene
    // lifecycle the legacy keyWindow lookup share_plus uses returns
    // a stale window and the sheet silently fails to present (the
    // bug the founder reported as "tap acts like it's doing
    // something but doesn't"). Anchor the popover to the top-centre
    // of the screen — invisible on iPhone, correctly placed on iPad.
    final mq = MediaQuery.of(context);
    final origin = Rect.fromLTWH(
      mq.size.width / 2 - 1, mq.padding.top + 8, 2, 2);

    String? errorMsg;
    try {
      if (!context.mounted) return;
      final card = ShareCard(
        beforeBytes:    beforeBytes,
        afterUrl:       afterUrl,
        currentScore:   currentScore,
        projectedScore: projectedScore,
        tagline:        tagline,
        microProofs:    microProofs,
      );
      final bytes = await _captureOffscreen(
        context:     context,
        widget:      card,
        logicalSize: const Size(1080, 1920),
        pixelRatio:  2.0,
      );
      if (bytes == null) {
        errorMsg = 'Couldn\'t render the card — try again';
      } else {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        HapticFeedback.mediumImpact();
        await _shareBytes(
          bytes,
          'mirrorly-${DateTime.now().millisecondsSinceEpoch}.png',
          text,
          origin: origin,
        );
        return;
      }
    } catch (e) {
      errorMsg = 'Share failed: ${e.toString().split('\n').first}';
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.surface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> _shareBytes(
      Uint8List bytes, String name, String? text,
      {Rect? origin}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: text,
      // Required for iPad popover; on iPhone share_plus 10.x under
      // iOS 26 UIScene also benefits from a valid origin because the
      // plugin's deprecated keyWindow lookup otherwise returns nil
      // and the sheet silently fails to present.
      sharePositionOrigin: origin,
    );
  }

  /// Best-effort source rect for the iOS share popover, derived from
  /// a widget's RepaintBoundary key. Falls back to null if the key's
  /// render object isn't yet attached — share_plus then computes a
  /// default which works on iPhone but not iPad.
  static Rect? _sharePositionOriginFromKey(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) return null;
      final tl = box.localToGlobal(Offset.zero);
      return tl & box.size;
    } catch (_) {
      return null;
    }
  }

  /// Render any widget off-screen at an explicit logical size. Uses a
  /// MediaQuery + Theme + Directionality wrapper so text/fonts resolve.
  static Future<Uint8List?> _captureOffscreen({
    required BuildContext context,
    required Widget widget,
    required Size logicalSize,
    double pixelRatio = 3.0,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: View.of(context),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(logicalSize),
        physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(
        alignment: Alignment.center, child: repaintBoundary),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    final buildOwner = BuildOwner(focusManager: FocusManager());
    renderView.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
          child: Theme(
            data: Theme.of(context),
            // Pure black surface — NOT AppColors.base (#07070A). The share
            // card prints against true #000000 so the edges disappear into
            // whatever surface it's posted on.
            child: ColoredBox(color: Colors.black, child: widget),
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

/// Loading overlay shown while the ShareCard is being rendered. Gives the
/// user immediate feedback on the share button press (otherwise the 2-3s
/// render time reads as "button is broken").
class _RenderingOverlay extends StatelessWidget {
  const _RenderingOverlay();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.red.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                color: AppColors.red, strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Composing your card…',
              style: TextStyle(
                color: Color(0xFFF7F7F9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}
