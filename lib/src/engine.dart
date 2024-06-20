import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/stats.dart';

/// An engine is an algorithm, such as expectimiminax, that can choose what it
/// considers the best move for a game position.
abstract class Engine<G extends Game<G>> {
  Move<G> chooseBest(List<Move<G>> moves, G game);

  /// Clear all data than an engine may cache data it learned upon analyzing a
  /// move (eg, transpositions etc) that it would otherwise reuse in the next
  /// analysis.
  ///
  /// This is mostly used for benchmarking, to compare cold analysis speeds to
  /// warm cache analysis speeds.
  void clearCache();

  /// Get data from the engine about its performance.
  SearchStats get stats;

  /// Build an engine from the given config.
  static Engine<G> forConfig<G extends Game<G>>({
    /// TODO: abstract this so different engines take different configs
    required ExpectiminimaxConfig config,
  }) {
    return Expectiminimax(config: config);
  }
}
