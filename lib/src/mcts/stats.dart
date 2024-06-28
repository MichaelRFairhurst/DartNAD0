import 'dart:math';

import 'package:dartnad0/src/stats.dart';

class MctsSearchStats implements SearchStats {
  MctsSearchStats(this._maxDepth)
      : nodesSearchedByPly =
            List<int>.filled(_maxDepth + 1, 0, growable: false);

  /// Track the max depth for the purposes of adding/comparing stat reports.
  final int _maxDepth;

  /// How many searches were performed.
  int searchCount = 0;

  /// How many samples/playouts were performed.
  int samples = 0;

  /// How many samples/playouts were performed, on average, for each search.
  double get samplesPerSearch => samples / searchCount;

  /// How many playouts/samples were performed on the root of the search tree.
  ///
  /// Most usefully, see [avgRootSimulations].
  int rootSimulations = 0;

  /// This will be greater than [samplesPerSearch] because the tree is cached.
  double get avgRootSimulations => rootSimulations / searchCount;

  /// How many nodes were added to the tree.
  int treeSize = 0;

  /// How much time has been spent searching.
  @override
  Duration duration = Duration.zero;

  ///  Count of how many nodes were searched at each ply (depth).
  final List<int> nodesSearchedByPly;

  /// How many cutoffs were performed total (every ply/depth summed).
  int get nodesSearched => nodesSearchedByPly.reduce((a, b) => a + b);

  /// Add all event counts (cutoffs, nodes searched, transposition table hits
  /// and misses, etc) to these stats.
  ///
  /// This will mutate the current instance but not the provided SearchStats.
  void add(MctsSearchStats other) {
    if (other._maxDepth > _maxDepth) {
      throw 'Cannot add provided stats, depth exceeds current stats.';
    }
    duration += other.duration;
    searchCount += other.searchCount;
    samples += other.samples;
	rootSimulations += other.rootSimulations;
    treeSize += other.treeSize;
    int depthDiff = _maxDepth - other._maxDepth;
    for (int i = depthDiff; i < _maxDepth; ++i) {
      nodesSearchedByPly[i] += other.nodesSearchedByPly[i - depthDiff];
    }
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// This will mutate the current instance but not the provided MctsSearchStats.
  void subtract(MctsSearchStats other) {
    if (other._maxDepth > _maxDepth) {
      throw 'Cannot subtract provided stats, depth exceeds current stats.';
    }
    duration -= other.duration;
    searchCount -= other.searchCount;
    samples -= other.samples;
    treeSize -= other.treeSize;
	rootSimulations += other.rootSimulations;
    int depthDiff = _maxDepth - other._maxDepth;
    for (int i = depthDiff; i < _maxDepth; ++i) {
      nodesSearchedByPly[i] -= other.nodesSearchedByPly[i - depthDiff];
    }
  }

  /// Add the [other] search stats to these stats, to get cumulative numbers
  /// between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  MctsSearchStats operator +(MctsSearchStats other) {
    return MctsSearchStats(max(_maxDepth, other._maxDepth))
      ..add(this)
      ..add(other);
  }

  /// Negate these stats, and return the result in a new instance.
  ///
  /// Does not mutate this instance.
  MctsSearchStats operator -() {
    return MctsSearchStats(_maxDepth)..subtract(this);
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  MctsSearchStats operator -(MctsSearchStats other) {
    return MctsSearchStats(max(_maxDepth, other._maxDepth))
      ..add(this)
      ..subtract(other);
  }

  @override
  String toString() {
    return 'Total time: ${duration.inMilliseconds}ms\n'
        'nodes searched: $nodesSearched :: $nodesSearchedByPly\n'
        'samples: $samples ($samplesPerSearch per search)\n'
        'Average root simulations: $avgRootSimulations ($rootSimulations total)\n'
        'Sample reuse per search: ${avgRootSimulations - samplesPerSearch}\n'
        'tree size: $treeSize\n';
  }
}
