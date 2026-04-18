import 'package:flutter/foundation.dart';

@immutable
class Fix {
  final String title;
  final String reason;
  final String action;
  final String timeline;
  final int rescanDay;

  const Fix({
    required this.title,
    required this.reason,
    required this.action,
    required this.timeline,
    required this.rescanDay,
  });

  factory Fix.fromJson(Map<String, dynamic> j) => Fix(
    title:     j['title']     as String? ?? '',
    reason:    j['reason']    as String? ?? '',
    action:    j['action']    as String? ?? '',
    timeline:  j['timeline']  as String? ?? '',
    rescanDay: (j['rescanDay'] as num?)?.toInt() ?? 14,
  );
}

@immutable
class Report {
  final String strongest;
  final String pulldown;
  final String boneReading;   // human translation of measured geometry
  final List<Fix> fixes;
  final String verdict;

  const Report({
    required this.strongest,
    required this.pulldown,
    required this.boneReading,
    required this.fixes,
    required this.verdict,
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    strongest:   j['strongest']   as String? ?? '',
    pulldown:    j['pulldown']    as String? ?? '',
    boneReading: j['boneReading'] as String? ?? '',
    fixes: ((j['fixes'] as List?) ?? [])
        .map((e) => Fix.fromJson(e as Map<String, dynamic>))
        .toList(),
    verdict: j['verdict'] as String? ?? '',
  );
}

@immutable
class MirrorAnalysis {
  final Report report;
  final String maximizedImageUrl;

  const MirrorAnalysis({
    required this.report,
    required this.maximizedImageUrl,
  });

  factory MirrorAnalysis.fromJson(Map<String, dynamic> j) => MirrorAnalysis(
    report: Report.fromJson(j['report'] as Map<String, dynamic>),
    maximizedImageUrl: (j['maximized'] as Map<String, dynamic>?)?['url'] as String? ?? '',
  );
}
