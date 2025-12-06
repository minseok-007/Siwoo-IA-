import '../models/walk_request_model.dart';
import '../models/user_model.dart';

/// Service for detecting and preventing schedule conflicts.
/// - Implements interval overlap detection algorithm
/// - Calculates conflict severity scores
/// - Provides conflict resolution suggestions
class ScheduleConflictService {
  /// Detects if a new walk request would conflict with existing walks.
  /// 
  /// Uses interval overlap detection:
  /// Two intervals [a1, a2] and [b1, b2] overlap if: a1 < b2 && a2 > b1
  /// 
  /// Time Complexity: O(n) where n is the number of existing walks
  /// Space Complexity: O(1)
  static bool hasConflict({
    required WalkRequestModel newWalk,
    required List<WalkRequestModel> existingWalks,
    required String walkerId,
  }) {
    for (final existingWalk in existingWalks) {
      // Only check walks for the same walker
      if (existingWalk.walkerId != walkerId) continue;
      
      // Only check active walks (not cancelled)
      if (existingWalk.status == WalkRequestStatus.cancelled) continue;

      if (_intervalsOverlap(
        newWalk.startTime,
        newWalk.endTime,
        existingWalk.startTime,
        existingWalk.endTime,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Checks if two time intervals overlap.
  /// 
  /// Intervals [start1, end1] and [start2, end2] overlap if:
  /// start1 < end2 && end1 > start2
  /// 
  /// Time Complexity: O(1)
  static bool _intervalsOverlap(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    final overlaps = start1.isBefore(end2) && end1.isAfter(start2);
    if (overlaps) {
      print('   ⚠️ Overlap detected: ${start1.toString()} - ${end1.toString()} vs ${start2.toString()} - ${end2.toString()}');
    }
    return overlaps;
  }

  /// Calculates conflict severity score (0.0 to 1.0).
  /// 
  /// - 1.0: Complete overlap (same time)
  /// - 0.5-0.9: Partial overlap
  /// - 0.0: No conflict
  /// 
  /// Time Complexity: O(1)
  static double calculateConflictSeverity({
    required DateTime start1,
    required DateTime end1,
    required DateTime start2,
    required DateTime end2,
  }) {
    if (!_intervalsOverlap(start1, end1, start2, end2)) {
      return 0.0;
    }

    // Calculate overlap duration
    final overlapStart = start1.isAfter(start2) ? start1 : start2;
    final overlapEnd = end1.isBefore(end2) ? end1 : end2;
    final overlapDuration = overlapEnd.difference(overlapStart).inMinutes;

    // Calculate total duration of both walks
    final duration1 = end1.difference(start1).inMinutes;
    final duration2 = end2.difference(start2).inMinutes;
    final totalDuration = duration1 + duration2;

    // Severity is proportional to overlap percentage
    return (overlapDuration / totalDuration).clamp(0.0, 1.0);
  }

  /// Finds all conflicting walks for a given walk request.
  /// 
  /// Returns list of conflicting walks with their severity scores.
  /// 
  /// Time Complexity: O(n) where n is the number of existing walks
  /// Space Complexity: O(k) where k is the number of conflicts
  static List<({WalkRequestModel walk, double severity})> findConflicts({
    required WalkRequestModel newWalk,
    required List<WalkRequestModel> existingWalks,
    required String walkerId,
  }) {
    final conflicts = <({WalkRequestModel walk, double severity})>[];

    for (final existingWalk in existingWalks) {
      if (existingWalk.walkerId != walkerId) continue;
      if (existingWalk.status == WalkRequestStatus.cancelled) continue;
      if (existingWalk.id == newWalk.id) continue; // Skip self

      final severity = calculateConflictSeverity(
        start1: newWalk.startTime,
        end1: newWalk.endTime,
        start2: existingWalk.startTime,
        end2: existingWalk.endTime,
      );

      if (severity > 0.0) {
        conflicts.add((walk: existingWalk, severity: severity));
      }
    }

    // Sort by severity (highest first)
    conflicts.sort((a, b) => b.severity.compareTo(a.severity));

    return conflicts;
  }

  /// Suggests alternative times to avoid conflicts.
  /// 
  /// Finds gaps in the schedule and suggests times that don't conflict.
  /// 
  /// Time Complexity: O(n log n) for sorting + O(n) for gap detection
  /// Space Complexity: O(k) where k is the number of suggestions
  static List<DateTime> suggestAlternativeTimes({
    required WalkRequestModel requestedWalk,
    required List<WalkRequestModel> existingWalks,
    required String walkerId,
    required int durationMinutes,
    int maxSuggestions = 3,
  }) {
    // Get all walks for this walker, sorted by start time
    final walkerWalks = existingWalks
        .where((w) => w.walkerId == walkerId &&
            w.status != WalkRequestStatus.cancelled &&
            w.id != requestedWalk.id)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final suggestions = <DateTime>[];
    final now = DateTime.now();

    // Check if requested time itself is available (with buffer)
    if (!hasConflict(
      newWalk: requestedWalk,
      existingWalks: existingWalks,
      walkerId: walkerId,
    )) {
      suggestions.add(requestedWalk.startTime);
    }

    // Find gaps between existing walks
    for (int i = 0; i < walkerWalks.length - 1 && suggestions.length < maxSuggestions; i++) {
      final currentWalk = walkerWalks[i];
      final nextWalk = walkerWalks[i + 1];

      final gapStart = currentWalk.endTime.add(const Duration(minutes: 15)); // 15 min buffer
      final gapEnd = nextWalk.startTime.subtract(const Duration(minutes: 15));
      final gapDuration = gapEnd.difference(gapStart).inMinutes;

      if (gapDuration >= durationMinutes && gapStart.isAfter(now)) {
        suggestions.add(gapStart);
      }
    }

    // Check time after last walk
    if (walkerWalks.isNotEmpty && suggestions.length < maxSuggestions) {
      final lastWalk = walkerWalks.last;
      final afterLastWalk = lastWalk.endTime.add(const Duration(minutes: 15));
      if (afterLastWalk.isAfter(now)) {
        suggestions.add(afterLastWalk);
      }
    }

    return suggestions.take(maxSuggestions).toList();
  }
}
