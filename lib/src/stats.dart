/// A collection of metrics about search performance.
///
/// Note, ensure you initialize this with the proper depth!
class SearchStats {
  SearchStats(int maxDepth)
      : cutoffsByPly = List<int>.filled(maxDepth, 0, growable: false),
        nodesSearchedByPly = List<int>.filled(maxDepth + 1, 0, growable: false);

  /// How many alpha/beta cutoffs were performed at each ply (depth).
  final List<int> cutoffsByPly;

  /// How many cutoffs were performed total (every ply/depth summed).
  int get totalCutoffs => nodesSearchedByPly.reduce((a, b) => a + b);

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
  void add(SearchStats other) {
    ttLookups += other.ttLookups;
    ttMisses += other.ttMisses;
    fwChanceSearches += other.fwChanceSearches;
    firstMoveHits += other.firstMoveHits;
    firstMoveMisses += other.firstMoveMisses;
    ttNoFirstMove += other.ttNoFirstMove;
    for (int i = 0; i < 20; ++i) {
      cutoffsByPly[i] += other.cutoffsByPly[i];
      nodesSearchedByPly[i] += other.nodesSearchedByPly[i];
    }
  }

  @override
  String toString() {
    return 'nodes searched: $nodesSearched :: $nodesSearchedByPly\n'
        'cutoffs: $totalCutoffs :: $cutoffsByPly\n'
        'full width chance searches: $fwChanceSearches\n'
        'tt lookups $ttLookups hits $ttHits, perc ${ttHits / ttLookups}\n'
        'first move hits $firstMoveHits misses $firstMoveMisses'
        ' (${firstMoveHits / (firstMoveHits + firstMoveMisses) * 100}%),'
        ' no move in $ttNoFirstMove';
  }
}
