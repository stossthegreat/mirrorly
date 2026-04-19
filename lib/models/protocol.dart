/// A 60-day aesthetic program targeting a specific weakness surfaced by the
/// user's scan. Generated once by the AI advisor and tracked daily — this is
/// the core retention loop. Check-ins are the habit; the before/after at day
/// 60 is the reward.
class Protocol {
  final String id;
  final DateTime startedAt;
  final int lengthDays;            // 60 typical
  final String title;              // "Sharpen the Jaw"
  final String targetAxis;         // "Jaw definition"
  final String summary;            // One-paragraph description
  final List<DailyTask> dailyTasks;       // recurring — done per day
  final List<ProtocolMilestone> milestones;
  final Set<int> completedDays;    // day indices marked done

  const Protocol({
    required this.id,
    required this.startedAt,
    required this.lengthDays,
    required this.title,
    required this.targetAxis,
    required this.summary,
    required this.dailyTasks,
    required this.milestones,
    required this.completedDays,
  });

  int get currentDay {
    final diff = DateTime.now().difference(startedAt).inDays + 1;
    return diff.clamp(1, lengthDays);
  }

  double get progress => completedDays.length / lengthDays;

  bool get completedToday => completedDays.contains(currentDay);

  Protocol withDayCompleted(int day) => Protocol(
    id: id, startedAt: startedAt, lengthDays: lengthDays, title: title,
    targetAxis: targetAxis, summary: summary, dailyTasks: dailyTasks,
    milestones: milestones,
    completedDays: {...completedDays, day},
  );

  Map<String, dynamic> toJson() => {
    'id':             id,
    'startedAt':      startedAt.toIso8601String(),
    'lengthDays':     lengthDays,
    'title':          title,
    'targetAxis':     targetAxis,
    'summary':        summary,
    'dailyTasks':     dailyTasks.map((t) => t.toJson()).toList(),
    'milestones':     milestones.map((m) => m.toJson()).toList(),
    'completedDays':  completedDays.toList(),
  };

  factory Protocol.fromJson(Map<String, dynamic> j) => Protocol(
    id:          j['id']         as String,
    startedAt:   DateTime.parse(j['startedAt'] as String),
    lengthDays:  (j['lengthDays'] as num).toInt(),
    title:       j['title']      as String? ?? '',
    targetAxis:  j['targetAxis'] as String? ?? '',
    summary:     j['summary']    as String? ?? '',
    dailyTasks:  ((j['dailyTasks'] as List?) ?? [])
                     .map((e) => DailyTask.fromJson(e as Map<String, dynamic>))
                     .toList(),
    milestones:  ((j['milestones'] as List?) ?? [])
                     .map((e) => ProtocolMilestone.fromJson(e as Map<String, dynamic>))
                     .toList(),
    completedDays: Set<int>.from(j['completedDays'] as List? ?? []),
  );
}

class DailyTask {
  final String title;
  final String detail;
  final String? duration;  // e.g. "10 min"
  final TaskCategory category;

  const DailyTask({
    required this.title,
    required this.detail,
    required this.category,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'title':    title,
    'detail':   detail,
    'duration': duration,
    'category': category.name,
  };

  factory DailyTask.fromJson(Map<String, dynamic> j) => DailyTask(
    title:    j['title']    as String,
    detail:   j['detail']   as String? ?? '',
    duration: j['duration'] as String?,
    category: TaskCategory.values.firstWhere(
      (e) => e.name == j['category'], orElse: () => TaskCategory.habit),
  );
}

class ProtocolMilestone {
  final int day;
  final String title;
  final String action; // "Re-scan. Compare to baseline."
  const ProtocolMilestone({
    required this.day, required this.title, required this.action,
  });

  Map<String, dynamic> toJson() => {
    'day': day, 'title': title, 'action': action,
  };

  factory ProtocolMilestone.fromJson(Map<String, dynamic> j) => ProtocolMilestone(
    day:    (j['day'] as num).toInt(),
    title:  j['title']  as String? ?? '',
    action: j['action'] as String? ?? '',
  );
}

enum TaskCategory { habit, exercise, skin, nutrition, grooming }
