import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';

/// An engine is an algorithm, such as expectimiminax, that can choose what it
/// considers the best move for a game position.
abstract class Engine<G extends Game<G>> {
  Future<Move<G>> chooseBest(List<Move<G>> moves, G game);

  /// Clear all data than an engine may cache data it learned upon analyzing a
  /// move (eg, transpositions etc) that it would otherwise reuse in the next
  /// analysis.
  ///
  /// This is mostly used for benchmarking, to compare cold analysis speeds to
  /// warm cache analysis speeds.
  void clearCache();

  /// Get data from the engine about its performance.
  SearchStats get stats;

}

/// Base class for configuration of a specific engine.
///
/// For instance, expectiminimax will have different tuning options than monte
/// carlo tree search.
///
/// This configuration object should be able to produce the engine based on its
/// own properties indicating the various settings and options.
abstract class EngineConfig {
  Engine<G> buildEngine<G extends Game<G>>();
}
