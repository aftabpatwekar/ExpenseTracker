import 'package:flutter/material.dart';

/// The window a group's shared-spend total is measured over. Lets the group
/// spend card show more than just the current calendar month, so a tracked
/// amount doesn't vanish when the month rolls over.
enum TimelineKind { thisMonth, lastMonth, thisYear, allTime, custom }

class GroupTimeline {
  final TimelineKind kind;
  final DateTime? start; // only for custom
  final DateTime? end; // only for custom
  const GroupTimeline(this.kind, {this.start, this.end});

  static const thisMonth = GroupTimeline(TimelineKind.thisMonth);

  String get label => switch (kind) {
        TimelineKind.thisMonth => 'This month',
        TimelineKind.lastMonth => 'Last month',
        TimelineKind.thisYear => 'This year',
        TimelineKind.allTime => 'All time',
        TimelineKind.custom => 'Custom',
      };

  /// Concrete [start,end] window for [now], or null for "all time".
  DateTimeRange? window(DateTime now) {
    switch (kind) {
      case TimelineKind.thisMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999));
      case TimelineKind.lastMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month - 1, 1),
            end: DateTime(now.year, now.month, 0, 23, 59, 59, 999));
      case TimelineKind.thisYear:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1),
            end: DateTime(now.year, 12, 31, 23, 59, 59, 999));
      case TimelineKind.allTime:
        return null;
      case TimelineKind.custom:
        if (start == null || end == null) return null;
        return DateTimeRange(
            start: DateTime(start!.year, start!.month, start!.day),
            end: DateTime(end!.year, end!.month, end!.day, 23, 59, 59, 999));
    }
  }

  /// Serialize for SharedPreferences. ISO strings contain ':' so we join with
  /// '|', which they never contain.
  String encode() =>
      (kind == TimelineKind.custom && start != null && end != null)
          ? 'custom|${start!.toIso8601String()}|${end!.toIso8601String()}'
          : kind.name;

  static GroupTimeline decode(String? s) {
    if (s == null || s.isEmpty) return thisMonth;
    if (s.startsWith('custom|')) {
      final parts = s.split('|');
      if (parts.length == 3) {
        final a = DateTime.tryParse(parts[1]);
        final b = DateTime.tryParse(parts[2]);
        if (a != null && b != null) {
          return GroupTimeline(TimelineKind.custom, start: a, end: b);
        }
      }
      return thisMonth;
    }
    return GroupTimeline(TimelineKind.values
        .firstWhere((k) => k.name == s, orElse: () => TimelineKind.thisMonth));
  }
}
