import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';

/// Modal disclosure asking the user to permit transmission of their
/// selfie photo to the third-party AI providers Mirrorly uses to
/// generate the analysis and renders.
///
/// Required by App Store guideline 5.1.2(i): the user must be told
/// what data is sent, who it is sent to, and must explicitly grant
/// permission BEFORE the app shares personal data with a third-party
/// AI service. Apple explicitly notes that putting the disclosure
/// only in the Privacy Policy is not sufficient — there has to be an
/// in-app permission gate. This is that gate.
///
/// Asked once per install. The choice is persisted in
/// [LocalStoreService.setAiConsent]. The user can revoke it later
/// from the Settings screen, which clears the flag and re-shows this
/// dialog on the next scan.
class AiConsentDialog extends StatelessWidget {
  const AiConsentDialog({super.key});

  /// Show the dialog. Returns true iff the user tapped ALLOW. A
  /// tapping of CANCEL, the back button, or a barrier dismissal all
  /// resolve to false — the caller must NOT proceed to send any
  /// data in those cases.
  static Future<bool> show(BuildContext context) async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => const AiConsentDialog(),
    );
    if (granted == true) {
      await LocalStoreService.setAiConsent(true);
      return true;
    }
    return false;
  }

  /// Centralised "make sure consent exists before transmitting" helper.
  /// Call this from EVERY entry point that fires an AI / backend call
  /// carrying user data (scan, chat send, try-on, maximise, rate). It
  /// short-circuits to true when the persisted flag is already set, so
  /// the user only sees one dialog ever (until they revoke). When the
  /// user is asked and declines, returns false and the caller MUST
  /// abort the operation without sending any bytes.
  ///
  /// Apple guideline 5.1.2(i) requires the dialog to gate every path
  /// — not just the scan flow — because the reviewer can navigate to
  /// chat / try-on / maximise without going through the scan, and
  /// data must not transmit on any of those paths without permission.
  static Future<bool> ensure(BuildContext context) async {
    if (await LocalStoreService.hasAiConsent()) return true;
    if (!context.mounted) return false;
    return show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.base,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PERMISSION TO SHARE YOUR PHOTO WITH AI PROVIDERS',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: 11, letterSpacing: 2.4,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Mirrorly cannot produce your written analysis, '
                   'your honest-looks rating, or your rendered '
                   '"maximised" preview without sending your selfie '
                   'photo to two third-party AI services. Read every '
                   'point below, then tap ALLOW or CANCEL.',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14, height: 1.5,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              _Bullet(
                head: 'EXACTLY WHAT IS SENT',
                body: '1) The selfie photo you captured (JPEG, '
                      'compressed, base64-encoded inside an HTTPS '
                      'POST body).\n'
                      '2) Sixteen geometric measurements computed '
                      'on-device by Apple ML Kit before transmission: '
                      'canthal-tilt angle (degrees), jaw apex angle '
                      '(degrees), face width-to-height ratio, '
                      'facial-symmetry score (0–100), facial-thirds '
                      'split (top/mid/lower percentages), eye spacing '
                      'ratio, lip fullness, brow-to-eye gap, philtrum '
                      'ratio, interpupillary distance ratio, nose '
                      'length ratio, face length ratio, head-shape '
                      'category (long / oval / square / broad / '
                      'round).\n\n'
                      'NOT sent: name, email address, phone number, '
                      'location, contacts, advertising ID, IP-based '
                      'tracking, social-login data — none of these '
                      'leave your device.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'EXACT ROUTE THE PHOTO TAKES',
                body: 'Step 1 — your phone → Mirrorly\'s backend at '
                      'https://mirrorly-production.up.railway.app '
                      '(HTTPS / TLS 1.3). Mirrorly\'s backend does '
                      'NOT persist the photo bytes; it forwards '
                      'them to the relevant AI provider and returns '
                      'the response.\n\n'
                      'Step 2 — Mirrorly\'s backend → AI provider:\n'
                      '• /analyse and /rate forward the photo to '
                      'OpenAI\'s GPT-4o Vision API (api.openai.com) '
                      'for the written analysis and honest-looks '
                      'rating.\n'
                      '• /maximize and /tryon forward the photo to '
                      'Replicate (api.replicate.com) — Google\'s '
                      'Nano Banana model renders the "maximised" '
                      'preview, then cdingram/face-swap locks the '
                      'identity to your real bones.\n'
                      '• /chat forwards the photo to OpenAI so the '
                      'Mirror advisor can answer questions about '
                      'your specific face.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'WHO RECEIVES IT, BY NAME',
                body: '• OpenAI, L.L.C. (San Francisco, CA, USA) — '
                      'GPT-4o Vision endpoint.\n'
                      '• Replicate, Inc. (San Francisco, CA, USA) — '
                      'Nano Banana + cdingram/face-swap endpoints.\n'
                      '• Mirrorly\'s own backend (Railway) — '
                      'transient routing only, no persistent '
                      'photo storage.\n\n'
                      'No other party — no advertisers, data '
                      'brokers, analytics SDKs, social-login '
                      'partners, or affiliates — receives your '
                      'photo or your geometry data.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'HOW LONG EACH PARTY KEEPS IT',
                body: '• On your phone — until you delete the '
                      'scan from inside the app or uninstall.\n'
                      '• In flight — encrypted by TLS 1.3.\n'
                      '• On Mirrorly\'s backend — bytes are NOT '
                      'persisted to disk; only request timestamps '
                      'and HTTP status codes are logged, and those '
                      'logs auto-expire after 30 days.\n'
                      '• On OpenAI — for the duration of one API '
                      'request; excluded from training and from '
                      'long-term retention by OpenAI\'s standard '
                      'API terms.\n'
                      '• On Replicate — for the duration of one '
                      'inference request; excluded from training '
                      'and not retained long-term per Replicate\'s '
                      'standard API terms.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'WHY YOUR PHOTO IS SENT',
                body: 'Sole purpose: produce the analysis text, '
                      'the honest-looks score, and the rendered '
                      'preview that you see inside the app. Your '
                      'photo is NEVER used for advertising, '
                      'profiling, identity matching, facial '
                      'recognition, biometric template building, '
                      'AI model training, or sale to third '
                      'parties.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'EQUAL OR GREATER PROTECTION',
                body: 'Per App Store guideline 5.1.2(i), any third '
                      'party that receives your data must provide '
                      'the same or equal privacy protection as '
                      'Mirrorly itself. Both providers meet this '
                      'bar under their standard API terms: '
                      'encrypted in transit (TLS) and at rest, '
                      'inputs excluded from training, processed '
                      'transiently for one request, no advertising '
                      'or profiling use, no resale, no cross-app '
                      'tracking.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'YOU CAN REVOKE AT ANY TIME',
                body: 'Settings → Revoke AI permission. After that, '
                      'no further photos or measurements will be '
                      'transmitted until you grant permission '
                      'again. You can also delete every scan + '
                      'render stored on this device from Settings → '
                      'Delete all data.'),
              const SizedBox(height: 12),
              _Bullet(
                head: 'GOVERNING POLICY',
                body: 'Full text in the in-app Privacy Policy '
                      '(Settings → Privacy Policy) and at the '
                      'public privacy URL linked from App Store '
                      'Connect. Both contain dedicated sections '
                      'titled AI DATA PERMISSION, WHO PROCESSES '
                      'YOUR PHOTOS, and THIRD-PARTY PROTECTION '
                      'PARITY that mirror this dialog word for '
                      'word.'),

              const SizedBox(height: 18),
              Text('Tap ALLOW to permit Mirrorly to transmit your '
                   'photo to OpenAI and Replicate via Mirrorly\'s '
                   'backend for this scan and future scans, on the '
                   'terms above. Tap CANCEL to keep the photo '
                   'entirely on this device — without permission, '
                   'the analysis and the rendered preview cannot '
                   'be produced.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12.5, height: 1.5,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('CANCEL',
                      style: GoogleFonts.inter(
                        fontSize: 12, letterSpacing: 1.8,
                        fontWeight: FontWeight.w800)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('ALLOW',
                      style: GoogleFonts.inter(
                        fontSize: 12, letterSpacing: 1.8,
                        fontWeight: FontWeight.w900)),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String head, body;
  const _Bullet({required this.head, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(head,
          style: GoogleFonts.inter(
            color: AppColors.red,
            fontSize: 9.5, letterSpacing: 2.0,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(body,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 13, height: 1.45,
            fontWeight: FontWeight.w500)),
      ],
    );
  }
}
