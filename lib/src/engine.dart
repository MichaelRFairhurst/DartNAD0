import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/time_control.dart';

/// An engine is an algorithm, such as expectimiminax, that can choose what it
/// considers the best move for a game position.
abstract class Engine<G extends Game<G>> {
  /// Choose the best move for the game based on engine search.
  ///
  /// The moves list should be the same as those produced by `game.getMoves()`,
  /// listed as an argument in case the move list is already available.
  ///
  /// This returns a future so that engines can be async -- for instance, use
  /// http, or get input from a user.
  ///
  /// The time control determines the max allowed time to search and return a
  /// move. The engine may constrain this time control if it wishes, and in
  /// fact, must call [constrain] before using the time control, in case it is
  /// a relative time control (end time is determined from when search begins).
  Future<Move<G>> chooseBest(
      List<Move<G>> moves, G game, TimeControl timeControl);

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
