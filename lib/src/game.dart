import 'package:dartnad0/src/move.dart';

/// A class to represent how games are played, so that the expectiminimax or
/// MCTS algorithms can play the defined game.
///
/// To define a game, implement the game state (for instance, in chess, you
/// would store where each player's pieces are on the board) and the moves from
/// that position for the current player.
///
/// The [score] getter will be used to determine whether a position is
/// advantageous for one player or another, the more accurate (and the faster it
/// is to compute) the better. It should return a value between -1.0 and 1.0,
/// inclusive, where 1.0 and -1.0 are winning and losing scores respectively.
///
/// The engine must know whether the current player is pursuing a high score
/// ([isMaxing] is true) or a low score ([isMaxing] is false). For istance, in
/// chess, when white is up material over black, the score would be positive and
/// [isMaxing] would be true on white's turn and false on black's turn.
///
/// It is possible to serve an engine over HTTP, however, it requires
/// implementing [encode].
abstract class Game<G extends Game<G>> {
  /// A value between 1.0 (maxing player wins) and -1.0 (maxing player loses),
  /// inclusive.
  ///
  /// Used by engines to choose the best move. This function should be accurate
  /// and fast.
  double get score;

  /// Whether the set of moves returned by [getMoves] are moves done by the
  /// maxing player, pursing a winning score of 1.0, or the minning player,
  /// pursuing a score of -1.0.
  bool get isMaxing;

  /// Required to serve the engine over http with the `serve` command.
  String encode() => throw UnimplementedError(
      'Implement encode() to serve this game engine over http.');

  /// The current moves available to the current player.
  ///
  /// Must return an empty list when the game has been won or lost. If this
  /// returns an empty list but is not a victory or a win, it may be treated as
  /// a draw, or it may result in poor play by the engines.
  List<Move<G>> getMoves();
}
