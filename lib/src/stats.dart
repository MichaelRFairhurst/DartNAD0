import 'dart:math';

/// A collection of metrics about search performance.
///
/// Note, ensure you initialize this with the proper depth!
class SearchStats {
  SearchStats(this._maxDepth)
      : cutoffsByPly = List<int>.filled(_maxDepth, 0, growable: false),
        nodesSearchedByPly =
            List<int>.filled(_maxDepth + 1, 0, growable: false);

  /// Track the max depth for the purposes of adding/comparing stat reports.
  final int _maxDepth;

  /// How much time has been spent searching.
  Duration duration = Duration.zero;

  /// How many alpha/beta cutoffs were performed at each ply (depth).
  final List<int> cutoffsByPly;

  /// How many cutoffs were performed total (every ply/depth summed).
  int get totalCutoffs => cutoffsByPly.reduce((a, b) => a + b);

  /// Count of full-width chance node searches (searches with completely
  /// unbounded alpha & beta values).
  int fwChanceSearches = 0;

  /// Transposition table cache lookup count (total lookups).
  int ttLookups = 0;

  /// Transposition table cache lookup miss count (invalid/no entry found).
  int ttMisses = 0;

  /// Count of how many nodes could not get a recommended first move from the
  /// transposition table. Note that this is a subset of [ttMisses].
  int ttNoFirstMove = 0;

  /// Transposition table cache lookup hit count (valid entry found).
  int get ttHits => ttLookups - ttMisses;

  ///  Count of how many nodes were searched at each ply (depth).
  final List<int> nodesSearchedByPly;

  /// How many cutoffs were performed total (every ply/depth summed).
  int get nodesSearched => nodesSearchedByPly.reduce((a, b) => a + b);

  /// How often the killer move heuristic or transition table provided the best
  /// move, as our first-searched move (which maximizes cutoffs).
  int firstMoveHits = 0;

  /// How often the killer move heuristic or transition table provided a
  /// candidate best move, but the candidate was not the best move.
  int firstMoveMisses = 0;

  /// Add all event counts (cutoffs, nodes searched, transposition table hits
  /// and misses, etc) to these stats.
  ///
  /// This will mutate the current instance but not the provided SearchStats.
  void add(SearchStats other) {
    if (other._maxDepth > _maxDepth) {
      throw 'Cannot add provided stats, depth exceeds current stats.';
    }
    duration += other.duration;
    ttLookups += other.ttLookups;
    ttMisses += other.ttMisses;
    fwChanceSearches += other.fwChanceSearches;
    firstMoveHits += other.firstMoveHits;
    firstMoveMisses += other.firstMoveMisses;
    ttNoFirstMove += other.ttNoFirstMove;
    int depthDiff = _maxDepth - other._maxDepth;
    for (int i = depthDiff; i < _maxDepth; ++i) {
      cutoffsByPly[i] += other.cutoffsByPly[i - depthDiff];
      nodesSearchedByPly[i] += other.nodesSearchedByPly[i - depthDiff];
    }
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// This will mutate the current instance but not the provided SearchStats.
  void subtract(SearchStats other) {
    if (other._maxDepth > _maxDepth) {
      throw 'Cannot subtract provided stats, depth exceeds current stats.';
    }
    duration -= other.duration;
    ttLookups -= other.ttLookups;
    ttMisses -= other.ttMisses;
    fwChanceSearches -= other.fwChanceSearches;
    firstMoveHits -= other.firstMoveHits;
    firstMoveMisses -= other.firstMoveMisses;
    ttNoFirstMove -= other.ttNoFirstMove;
    int depthDiff = _maxDepth - other._maxDepth;
    for (int i = depthDiff; i < _maxDepth; ++i) {
      cutoffsByPly[i] -= other.cutoffsByPly[i + depthDiff];
      nodesSearchedByPly[i] -= other.nodesSearchedByPly[i + depthDiff];
    }
  }

  /// Add the [other] search stats to these stats, to get cumulative numbers
  /// between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  SearchStats operator +(SearchStats other) {
    return SearchStats(max(_maxDepth, other._maxDepth))
      ..add(this)
      ..add(other);
  }

  /// Negate these stats, and return the result in a new instance.
  ///
  /// Does not mutate this instance.
  SearchStats operator -() {
    return SearchStats(_maxDepth)..subtract(this);
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  SearchStats operator -(SearchStats other) {
    return SearchStats(max(_maxDepth, other._maxDepth))
      ..add(this)
      ..subtract(other);
  }

  @override
  String toString() {
    return 'Total time: ${duration.inMilliseconds}ms\n'
        'nodes searched: $nodesSearched :: $nodesSearchedByPly\n'
        'cutoffs: $totalCutoffs :: $cutoffsByPly\n'
        'full width chance searches: $fwChanceSearches\n'
        'tt lookups $ttLookups hits $ttHits, perc ${ttHits / ttLookups}\n'
        'first move hits $firstMoveHits misses $firstMoveMisses'
        ' (${firstMoveHits / (firstMoveHits + firstMoveMisses) * 100}%),'
        ' no move in $ttNoFirstMove';
  }
}
