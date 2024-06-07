/// Config object for defining expectiminimax search parameters.
class ExpectiminimaxConfig {
  const ExpectiminimaxConfig({
    required this.maxDepth,
    this.iterativeDeepening = false,
    this.probeChanceNodes = false,
    this.transpositionTableSize = 1024 * 1024,
    this.strictTranspositions = false,
  });

  /// The max depth of plies to search.
  final int maxDepth;

  /// Whether to use iterative deepening (start searching at ply 1, and then
  /// increment depth by 1 and repeat, until we've reached max depth).
  ///
  /// Iterative deepening sounds counter-productive. However, each search at a
  /// lower depth primes the cache for the next round. Whether this is results
  /// in a performance benefit depends on search characteristics.
  ///
  /// Defaults to false, pending further exploration.
  final bool iterativeDeepening;

  /// Whether to use probing on chance node children in order to more quickly
  /// establish a lower/upper bound before a second full search pass.
  ///
  /// According to sources, this technique can result in performance increases
  /// by producing additional cutoffs.
  ///
  /// Defaults to false, pending further exploration.
  final bool probeChanceNodes;

  /// How many entries to store in the transposition table.
  ///
  /// Defaults to 1024 * 1024 entries.
  final int transpositionTableSize;

  /// Whether to check for hash collisions in the transposition table.
  ///
  /// Without checking for collisions, engines can produce poor move choices.
  /// However, most chess engines do not bother with this step as the benefits
  /// typically do not exceed the memory + cpu costs.
  ///
  /// Defaults to false.
  final bool strictTranspositions;

  /// Copy a config with changes to some of its settings.
  ExpectiminimaxConfig copyWith({
    int? maxDepth,
    bool? iterativeDeepening,
    bool? probeChanceNodes,
    int? transpositionTableSize,
    bool? strictTranspositions,
  }) =>
      ExpectiminimaxConfig(
        maxDepth: maxDepth ?? this.maxDepth,
        iterativeDeepening: iterativeDeepening ?? this.iterativeDeepening,
        probeChanceNodes: probeChanceNodes ?? this.probeChanceNodes,
        transpositionTableSize:
            transpositionTableSize ?? this.transpositionTableSize,
        strictTranspositions: strictTranspositions ?? this.strictTranspositions,
      );
}
