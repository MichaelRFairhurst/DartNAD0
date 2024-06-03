import 'dart:math';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/transposition.dart';
import 'package:expectiminimax/src/util.dart';

class Expectiminimax<G extends Game<G>> {
  Expectiminimax({
    required this.maxDepth,
    TranspositionTable<G>? transpositionTable,
  }) : transpositionTable =
            transpositionTable ?? TranspositionTable<G>(1024 * 1024);

  final TranspositionTable<G> transpositionTable;

  final int maxDepth;

  Move<G> chooseBest(List<Move<G>> moves, G game) {
    final alpha = -2.0;
    final beta = 2.0;

    // Final scoring.
    if (game.isMaxing) {
      return bestBy<Move<G>, num>(
          moves, (m) => scoreMove(m, game, maxDepth, alpha, beta))!;
    } else {
      return bestBy<Move<G>, num>(
          moves, (m) => -scoreMove(m, game, maxDepth, alpha, beta))!;
    }
  }

  double scoreMove(Move<G> move, G game, int depth, double alpha, double beta) {
    final chance = move.perform(game);
	alpha = chance.possibilities.length == 1 ? alpha : -2.0;
	beta = chance.possibilities.length == 1 ? beta : 2.0;
    return chance.expectedValue((g) => scoreGame(g, depth - 1, alpha, beta));
  }

  double scoreGame(G game, int depth, double alpha, double beta) =>
      transpositionTable.scoreTransposition(game, depth, alpha, beta, () {
        if (depth <= 0) {
          return game.score;
        }

        final moves = game.getMoves();

        if (moves.isEmpty) {
          return game.score;
        }

        if (game.isMaxing) {
          var maxScore = -1.0;
          for (final move in moves) {
            final score = scoreMove(move, game, depth - 1, alpha, beta);
            if (score >= beta) {
              return score;
            }
            maxScore = max(maxScore, score);
            alpha = max(alpha, score);
          }

          return maxScore;
        } else {
          var minScore = 1.0;
          for (final move in moves) {
            final score = scoreMove(move, game, depth - 1, alpha, beta);
            if (score <= alpha) {
              return score;
            }
            minScore = min(minScore, score);
            beta = min(beta, score);
          }

          return minScore;
        }
      });
}
