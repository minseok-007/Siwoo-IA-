import '../models/walk_request_model.dart';
import '../models/user_model.dart';

/// Dynamic Programming solution for optimal walk scheduling.
/// 
/// Problem: Given multiple walk requests, select the maximum number of 
/// non-overlapping walks that a walker can accept, maximizing total value.
/// 
/// This is a variant of the Interval Scheduling problem solved with DP.
/// Time Complexity: O(n log n + n^2) where n is the number of requests
/// Space Complexity: O(n)
class OptimalSchedulingService {
  /// Solves the optimal walk selection problem using Dynamic Programming.
  /// 
  /// Algorithm:
  /// 1. Sort walks by end time (earliest first)
  /// 2. For each walk, find the last non-overlapping walk before it
  /// 3. Use DP: dp[i] = max(dp[i-1], value[i] + dp[lastNonOverlapping])
  /// 
  /// Returns the maximum value and the selected walk indices.
  static OptimalScheduleResult findOptimalSchedule({
    required List<WalkRequestModel> availableWalks,
    required UserModel walker,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (availableWalks.isEmpty) {
      return OptimalScheduleResult(
        selectedWalks: [],
        totalValue: 0.0,
        totalWalks: 0,
      );
    }

    // Filter walks by date range and walker compatibility
    List<WalkRequestModel> validWalks = availableWalks
        .where((walk) {
          if (walk.status != WalkRequestStatus.pending) return false;
          if (startDate != null && walk.startTime.isBefore(startDate)) return false;
          if (endDate != null && walk.startTime.isAfter(endDate)) return false;
          return true;
        })
        .toList();

    if (validWalks.isEmpty) {
      return OptimalScheduleResult(
        selectedWalks: [],
        totalValue: 0.0,
        totalWalks: 0,
      );
    }

    // Sort by end time (earliest first) - key to DP solution
    validWalks.sort((a, b) => a.endTime.compareTo(b.endTime));

    final n = validWalks.length;
    
    // dp[i] = maximum value achievable with first i walks
    final dp = List<double>.filled(n + 1, 0.0);
    
    // parent[i] = index of last walk in optimal solution ending at walk i
    final parent = List<int>.filled(n + 1, -1);
    
    // Precompute last non-overlapping walk for each walk
    final lastNonOverlapping = List<int>.filled(n, -1);
    
    for (int i = 0; i < n; i++) {
      // Binary search for last walk that ends before current walk starts
      final currentStart = validWalks[i].startTime;
      
      int left = 0, right = i - 1;
      int best = -1;
      
      while (left <= right) {
        final mid = (left + right) ~/ 2;
        if (validWalks[mid].endTime.isBefore(currentStart) ||
            validWalks[mid].endTime.isAtSameMomentAs(currentStart)) {
          best = mid;
          left = mid + 1;
        } else {
          right = mid - 1;
        }
      }
      
      lastNonOverlapping[i] = best;
    }

    // DP: for each walk, decide whether to include it
    for (int i = 0; i < n; i++) {
      final value = _calculateWalkValue(validWalks[i], walker);
      
      // Option 1: Don't include this walk
      final skipValue = dp[i];
      
      // Option 2: Include this walk
      var includeValue = value;
      if (lastNonOverlapping[i] != -1) {
        includeValue += dp[lastNonOverlapping[i] + 1];
      }
      
      if (includeValue > skipValue) {
        dp[i + 1] = includeValue;
        parent[i + 1] = i;
      } else {
        dp[i + 1] = skipValue;
        parent[i + 1] = parent[i];
      }
    }

    // Reconstruct solution
    final selectedIndices = <int>[];
    int current = n;
    
    while (current > 0) {
      if (parent[current] != -1 && parent[current] == current - 1) {
        selectedIndices.add(current - 1);
        final lastNonOverlap = lastNonOverlapping[current - 1];
        current = lastNonOverlap != -1 ? lastNonOverlap + 1 : 0;
      } else {
        current = parent[current] != -1 ? parent[current] : current - 1;
      }
    }

    selectedIndices.sort();
    final selectedWalks = selectedIndices.map((i) => validWalks[i]).toList();

    return OptimalScheduleResult(
      selectedWalks: selectedWalks,
      totalValue: dp[n],
      totalWalks: selectedWalks.length,
    );
  }

  /// Calculates the value of a walk for a walker.
  /// Higher value = more desirable walk.
  static double _calculateWalkValue(WalkRequestModel walk, UserModel walker) {
    double value = 100.0; // Base value
    
    // Prefer longer walks (more earning potential)
    final duration = walk.endTime.difference(walk.startTime).inMinutes;
    value += duration * 0.5;
    
    // Prefer walks with higher ratings (if walker has rating)
    value += walker.rating * 10.0;
    
    // Prefer walks scheduled sooner (urgency bonus)
    final hoursUntilWalk = walk.startTime.difference(DateTime.now()).inHours;
    if (hoursUntilWalk <= 24) {
      value += 20.0; // Urgency bonus
    }
    
    return value;
  }

  /// Greedy algorithm alternative: Select maximum non-overlapping walks.
  /// 
  /// This is the classic Interval Scheduling greedy solution.
  /// Always select the walk that ends earliest among remaining compatible walks.
  /// 
  /// Time Complexity: O(n log n) - faster than DP but may not maximize value
  /// Space Complexity: O(n)
  static List<WalkRequestModel> findMaxNonOverlappingWalks(
    List<WalkRequestModel> walks,
  ) {
    if (walks.isEmpty) return [];

    // Sort by end time (earliest first)
    final sorted = List<WalkRequestModel>.from(walks)
      ..sort((a, b) => a.endTime.compareTo(b.endTime));

    final selected = <WalkRequestModel>[];
    DateTime? lastEndTime;

    for (final walk in sorted) {
      if (walk.status != WalkRequestStatus.pending) continue;
      
      // If this walk starts after the last selected walk ends, select it
      if (lastEndTime == null || 
          walk.startTime.isAfter(lastEndTime) ||
          walk.startTime.isAtSameMomentAs(lastEndTime)) {
        selected.add(walk);
        lastEndTime = walk.endTime;
      }
    }

    return selected;
  }
}

class OptimalScheduleResult {
  final List<WalkRequestModel> selectedWalks;
  final double totalValue;
  final int totalWalks;

  OptimalScheduleResult({
    required this.selectedWalks,
    required this.totalValue,
    required this.totalWalks,
  });
}
