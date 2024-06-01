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

  Move<G> chooseBest(List<Move<G>> move, G game) {
    if (game.isMaxing) {
      return bestBy<Move<G>, num>(move, (m) => scoreMove(m, game, 0))!;
    } else {
      return bestBy<Move<G>, num>(move, (m) => -scoreMove(m, game, 0))!;
    }
  }

  double scoreMove(Move<G> move, G game, int depth) {
    final chance = move.perform(game);
    return chance.expectedValue((g) => scoreGame(g, depth + 1));
  }

  double scoreGame(G game, int depth) =>
      transpositionTable.scoreTransposition(game, maxDepth - depth, () {
        if (depth == maxDepth) {
          return game.score;
        }

		final moves = game.getMoves();

        if (moves.isEmpty) {
		  return game.score;
		}

        final moveScores =
            moves.map((m) => scoreMove(m, game, depth));
        if (game.isMaxing) {
          return moveScores.reduce((a, b) => max(a, b));
        } else {
          return moveScores.reduce((a, b) => min(a, b));
        }
      });
}
