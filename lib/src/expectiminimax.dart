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
    //alpha = chance.possibilities.length == 1 ? alpha : -2.0;
    //beta = chance.possibilities.length == 1 ? beta : 2.0;
    //return chance.expectedValue((g) => scoreGame(g, depth - 1, alpha, beta));

    if (chance.possibilities.length == 1) {
      // Optimization: skip all the below float math for this simple case.
      return scoreGame(
          chance.possibilities.single.outcome, depth - 1, alpha, beta);
    }

    var sum = 0.0;
    var future = 1.0;
    for (final p in chance.possibilities) {
      future -= p.probability;

      const worstAlpha = 1.0;
      const worstBeta = -1.0;

      // Our alpha cutoff condition is when previously seen nodes, plus future
      // nodes assumed to be worst case W, plus the current node score, exceed
      // alpha/beta
      //
      // s0 * p0 + s1 * p1 + ... + si * pi + W * pi+1 + W * pi+2 ... <= alpha
      // s0 * p0 + s1 * p1 + ... + si * pi + W * pi+1 + W * pi+2 ... >= beta
      //
      // We can reorder this to get alphaX, betaX
      //
      // si <= (alpha - W * pi+1 - W * pi+2 - s0 * p0 - s1 * p1) / pi
      // si >= (beta - W * pi+1 - W * pi+2 - s0 * p0 - s1 * p1) / pi

	  // Optimization? We can prove without floating multiplication and
	  // division that these nodes cannot result in an alpha-beta cutoff.
      if (future > alpha + p.probability - sum &&
          future > -beta + p.probability + sum) {

        // Proof of correctness:
		//
        // (alpha - sum - worstAlpha * future) / p.probability < -1.0
        // alpha - sum - worstAlpha * future < -p.probability
        // alpha - worstAlpha * future < -p.probability + sum
        // worstAlpha * future > alpha + p.probability - sum
        // future > (alpha + p.probability - sum) / worstAlpha
        // future > alpha + p.probability - sum
        // or
        // (beta - sum - worstBeta * future) / p.probability > 1.0
        // beta - sum - worstBeta * future > p.probability
        // beta - worstBeta * future > p.probability + sum
        // worstBeta * future < beta - p.probability - sum
        // -1 * future < beta - p.probability - sum
        // future > -beta + p.probability + sum

        assert((alpha - sum - worstAlpha * future) / p.probability < -1);
        assert((beta - sum - worstBeta * future) / p.probability > 1);
        sum += scoreGame(p.outcome, depth - 1, -2.0, 2.0) * p.probability;
        continue;
      }

      final alphaP = (alpha - sum - worstAlpha * future) / p.probability;
      final betaP = (beta - sum - worstBeta * future) / p.probability;
      final score =
          scoreGame(p.outcome, depth - 1, max(-2.0, alphaP), min(2.0, betaP));

      sum += score * p.probability;

      double maxScore = sum + worstAlpha * future;
      double minScore = sum + worstBeta * future;

      if (score <= alphaP) {
        return maxScore;
      } else if (score >= betaP) {
        return minScore;
      }
    }

    return sum;
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
