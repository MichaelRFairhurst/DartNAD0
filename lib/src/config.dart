/// Config object for defining expectiminimax search parameters.
class ExpectiminimaxConfig {
  const ExpectiminimaxConfig({
    required this.maxDepth,
    required this.maxTime,
    this.iterativeDeepening = true,
    this.chanceNodeProbeWindow = ProbeWindow.overlapping,
    this.transpositionTableSize = 1024 * 1024,
    this.strictTranspositions = false,
    @Deprecated('Internal setting for development only.') this.debugSetting,
  });

  /// The max depth of plies to search.
  final int maxDepth;

  /// The maximum time to spend on any given search.
  final Duration maxTime;

  /// Whether to use iterative deepening (start searching at ply 1, and then
  /// increment depth by 1 and repeat, until we've reached max depth).
  ///
  /// Iterative deepening sounds counter-productive. However, each search at a
  /// lower depth primes the cache for the next round. Whether this is results
  /// in a performance benefit depends on search characteristics.
  ///
  /// Defaults to false, pending further exploration.
  final bool iterativeDeepening;

  /// Which type of probing to use on chance node children in order to more
  /// quickly establish a lower/upper bound before a second full search pass.
  ///
  /// This technique can result in performance increases, but it can also reduce
  /// performance in some cases.
  ///
  /// Defaults to probing from -2 to beta and alpha to +2 (overlapping probe).
  final ProbeWindow chanceNodeProbeWindow;

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

  /// Reserved for debugging/development.
  @Deprecated('Internal use only.')
  final dynamic debugSetting;

  /// Copy a config with changes to some of its settings.
  ExpectiminimaxConfig copyWith({
    int? maxDepth,
    Duration? maxTime,
    bool? iterativeDeepening,
    ProbeWindow? chanceNodeProbeWindow,
    int? transpositionTableSize,
    bool? strictTranspositions,
    @Deprecated('Internal use only.') dynamic debugSetting,
  }) =>
      ExpectiminimaxConfig(
        maxDepth: maxDepth ?? this.maxDepth,
        maxTime: maxTime ?? this.maxTime,
        iterativeDeepening: iterativeDeepening ?? this.iterativeDeepening,
        chanceNodeProbeWindow:
            chanceNodeProbeWindow ?? this.chanceNodeProbeWindow,
        transpositionTableSize:
            transpositionTableSize ?? this.transpositionTableSize,
        strictTranspositions: strictTranspositions ?? this.strictTranspositions,
        // ignore: deprecated_member_use_from_same_package
        debugSetting: debugSetting ?? this.debugSetting,
      );
}

/// Strategy for probing chance nodes
enum ProbeWindow {
  /// Do not probe chance nodes.
  none,

  /// For range alpha-beta, probe from alpha to +1 and -1 to beta.
  overlapping,

  /// Find the central point between alpha and beta, then probe from center
  /// to +1, and -1 to center.
  centerToEnd,

  /// For range alpha-beta, probe from beta to +1 and -1 to alpha.
  edgeToEnd,
}
