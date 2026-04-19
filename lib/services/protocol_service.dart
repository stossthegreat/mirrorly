import '../models/protocol.dart';
import '../models/scan_record.dart';
import 'local_store_service.dart';

/// Creates, loads, and advances the user's active 60-day protocol.
///
/// Protocol templates are keyed to the user's weakest axis (the pulldown
/// surfaced by scoring). Each template ships a matched daily task set and
/// milestones at day 14 / 30 / 60.
class ProtocolService {
  static Future<Protocol?> loadActive() async {
    final j = await LocalStoreService.loadProtocolJson();
    if (j == null) return null;
    try { return Protocol.fromJson(j); } catch (_) { return null; }
  }

  static Future<void> save(Protocol? p) async {
    await LocalStoreService.saveProtocolJson(p?.toJson());
  }

  static Future<Protocol> markDayComplete(Protocol p, int day) async {
    final updated = p.withDayCompleted(day);
    await save(updated);
    return updated;
  }

  /// Start a protocol tuned to a specific pulldown axis. Called from the
  /// "Start protocol" CTA in the report or advisor.
  static Future<Protocol> startForScan(ScanRecord scan, String targetAxis) async {
    final template = _templateFor(targetAxis);
    final protocol = Protocol(
      id:         'proto-${DateTime.now().millisecondsSinceEpoch}',
      startedAt:  DateTime.now(),
      lengthDays: 60,
      title:      template.title,
      targetAxis: targetAxis,
      summary:    template.summary,
      dailyTasks: template.dailyTasks,
      milestones: template.milestones,
      completedDays: const {},
    );
    await save(protocol);
    return protocol;
  }

  static _Template _templateFor(String axis) {
    switch (axis) {
      case 'Jaw definition':
        return const _Template(
          title: 'Sharpen the Jaw',
          summary: 'Sixty days of mewing, body-fat reduction, and posture work. '
                   'Your mandibular angle improves as the fat pad retracts and the '
                   'masseter thickens. Expect a visible shift by day 45.',
          dailyTasks: [
            DailyTask(
              title: 'Mewing — full tongue posture',
              detail: 'Tongue against palate for 12 waking hours. Set 3 reminders.',
              duration: 'all day', category: TaskCategory.habit),
            DailyTask(
              title: 'Masseter isometrics',
              detail: '3 sets of 30 s clench + release + massage. Avoid jaw clicks.',
              duration: '6 min', category: TaskCategory.exercise),
            DailyTask(
              title: 'Body-fat protocol',
              detail: '0.5–1 lb/wk cut if above 16% bf. Protein 1 g/lb, walk 10k.',
              duration: 'all day', category: TaskCategory.nutrition),
          ],
        );
      case 'Canthal tilt':
        return const _Template(
          title: 'Lift the Eye',
          summary: 'Canthal tilt is genetic-dominant, but orbital fat-pad reduction, '
                   'brow shape, and rest posture all read as tilt. Target the levers '
                   'you control: sleep, salt, brow, squint muscles.',
          dailyTasks: [
            DailyTask(
              title: 'De-puff routine',
              detail: 'Cold roller + caffeine eye cream, AM. No added salt after 6pm.',
              duration: '5 min', category: TaskCategory.skin),
            DailyTask(
              title: 'Squint isometric',
              detail: '3 × 20 firm squints. Activates orbicularis for lateral lift.',
              duration: '2 min', category: TaskCategory.exercise),
            DailyTask(
              title: 'Brow mapping',
              detail: 'Brush brows up-and-out. Trim length, preserve tail arch.',
              duration: '2 min', category: TaskCategory.grooming),
          ],
        );
      case 'Symmetry':
        return const _Template(
          title: 'Rebalance',
          summary: 'Asymmetry is 80% habitual — chewing side, sleep side, posture. '
                   'Sixty days of corrective habits measurably shift soft-tissue '
                   'distribution. Bone asymmetry stays; surface asymmetry responds.',
          dailyTasks: [
            DailyTask(
              title: 'Weak-side chewing',
              detail: 'Gum 15 min/day ONLY on the weaker (thinner) cheek side.',
              duration: '15 min', category: TaskCategory.habit),
            DailyTask(
              title: 'Sleep-posture switch',
              detail: 'Back-sleep only. Asymmetric pillow compression is #1 cause.',
              duration: 'all night', category: TaskCategory.habit),
            DailyTask(
              title: 'Posterior chain mobility',
              detail: 'Thoracic rotations + scalene stretch, alternating sides.',
              duration: '8 min', category: TaskCategory.exercise),
          ],
        );
      case 'Chin projection':
        return const _Template(
          title: 'Push the Chin Forward',
          summary: 'Tongue posture, lower-jaw mewing, and platysma strength project '
                   'the mental eminence. Persistent. Measurable.',
          dailyTasks: [
            DailyTask(
              title: 'Forward mewing',
              detail: 'Tongue on palate + lower jaw relaxed forward. All day.',
              duration: 'all day', category: TaskCategory.habit),
            DailyTask(
              title: 'Platysma exercise',
              detail: 'Jut lower jaw forward 30×, 3 sets. Feel platysma activate.',
              duration: '5 min', category: TaskCategory.exercise),
          ],
        );
      default:
        return const _Template(
          title: 'Foundations',
          summary: 'Eight weeks of the fundamentals nobody skips. Skin, sleep, '
                   'posture, body composition — the platform every other intervention '
                   'multiplies off.',
          dailyTasks: [
            DailyTask(
              title: 'Skin core-four',
              detail: 'Gentle cleanser · SPF 50 AM · tretinoin (3×/wk) · moisturizer.',
              duration: '4 min AM + 3 min PM', category: TaskCategory.skin),
            DailyTask(
              title: 'Sleep — 8 hours, dark room',
              detail: 'No screens 60m before bed. Room ≤ 18°C. Cortisol baseline = facial.',
              duration: '8 h', category: TaskCategory.habit),
            DailyTask(
              title: 'Walk 10k steps',
              detail: 'NEAT burns 2–3% bf/month without training fatigue. Non-negotiable.',
              duration: 'all day', category: TaskCategory.nutrition),
          ],
        );
    }
  }
}

class _Template {
  final String title;
  final String summary;
  final List<DailyTask> dailyTasks;
  List<ProtocolMilestone> get milestones => const [
    ProtocolMilestone(day: 14, title: 'Check-in',  action: 'Re-scan. Compare to baseline.'),
    ProtocolMilestone(day: 30, title: 'Midpoint',  action: 'Re-scan. Adjust if an axis stalled.'),
    ProtocolMilestone(day: 60, title: 'Completion', action: 'Final scan. Compare before / after.'),
  ];
  const _Template({
    required this.title, required this.summary, required this.dailyTasks,
  });
}
