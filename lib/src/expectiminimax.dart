import 'dart:math';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/stats.dart';
import 'package:expectiminimax/src/transposition.dart';
import 'package:expectiminimax/src/util.dart';

class Expectiminimax<G extends Game<G>> {
  Expectiminimax({
    required this.maxDepth,
    TranspositionTable<G>? transpositionTable,
  })  : transpositionTable =
            transpositionTable ?? TranspositionTable<G>(1024 * 1024),
        killerMoves = List<Move<G>?>.filled(maxDepth, null, growable: false),
        stats = SearchStats(maxDepth);

  final List<Move<G>?> killerMoves;
  final TranspositionTable<G> transpositionTable;
  final SearchStats stats;

  final int maxDepth;
  bool useAlphaBeta = true;
  bool useStarMinimax = true;
  bool probeChanceNodes = true;
  bool useIterativeDeepening = false;

  Move<G> chooseBest(List<Move<G>> moves, G game) {
    final alpha = -2.0;
    final beta = 2.0;

    if (useIterativeDeepening) {
      for (var i = 1; i < maxDepth; ++i) {
        for (final move in moves) {
          scoreMove(move, game, i, alpha, beta);
        }
      }
    }

    // Final scoring.
    if (game.isMaxing) {
      return bestBy<Move<G>, num>(
          moves, (m) => scoreMove(m, game, maxDepth, alpha, beta))!;
    } else {
      return bestBy<Move<G>, num>(
          moves, (m) => -scoreMove(m, game, maxDepth, alpha, beta))!;
    }
  }

  double checkScoreGame(G game, int depth, double alpha, double beta) {
    final score = scoreGame(game, depth, alpha, beta);
    assert(() {
      final checkedScore = scoreGame(game, depth, -2.0, 2.0);
      if (score < alpha && score > beta) {
        assert(checkedScore == score,
            'Got the wrong score in non-cutoff range: $score vs $checkedScore');
      } else if (score > alpha) {
        assert(checkedScore + 0.0001 > alpha,
            'Incorrect alpha cutoff: $score vs $checkedScore, alpha $alpha');
        assert(checkedScore + 0.0001 >= score,
            'alpha cutoff with wrong score: $score vs $checkedScore, alpha $alpha');
      } else if (score < beta) {
        assert(checkedScore - 0.0001 < beta,
            'Incorrect beta cutoff: $score vs $checkedScore, beta $beta');
        assert(checkedScore - 0.0001 <= score,
            'beta cutoff with wrong score: $score vs $checkedScore, beta $beta');
      }
      return true;
    }());
    return score;
  }

  double scoreMove(Move<G> move, G game, int depth, double alpha, double beta) {
    stats.nodesSearchedByPly[depth]++;
    final chance = move.perform(game);
    if (!useAlphaBeta || (alpha < -1.0 && beta > 1.0)) {
      stats.fwChanceSearches++;
      return chance
          .expectedValue((g) => checkScoreGame(g, depth - 1, -2.0, 2.0));
    } else if (!useStarMinimax) {
      if (chance.possibilities.length > 1) {
        stats.fwChanceSearches++;
      }
      alpha = chance.possibilities.length == 1 ? alpha : -2.0;
      beta = chance.possibilities.length == 1 ? beta : 2.0;
      return chance
          .expectedValue((g) => checkScoreGame(g, depth - 1, alpha, beta));
    }

    if (chance.possibilities.length == 1) {
      // Optimization: skip all the below float math for this simple case.
      return checkScoreGame(
          chance.possibilities.single.outcome, depth - 1, alpha, beta);
    }

    // This is better, at least for now, but that's not surprising as it
    // seems overall to be slower to *any* chance nodes....
    final probeChanceNodes = this.probeChanceNodes &&
        chance.possibilities.length > 3 && depth > 1;

    final scoresLB =
        List.filled(chance.possibilities.length, -1.0, growable: false);
    final scoresUB =
        List.filled(chance.possibilities.length, 1.0, growable: false);

    double sumLB = -1.0;
    double sumUB = 1.0;
    if (probeChanceNodes) {
      for (var i = 0; i < chance.possibilities.length; ++i) {
        final p = chance.possibilities[i];

        // Best strategy so far
        final center = (alpha + beta) / 2;

        // TODO: further evaluate strategies such as these.
        //final center = (game.isMaxing ? alpha : beta).clamp(-0.5, 0.5);
        //final center = 0.0;
        //final center = game.score;
        //final double center;
        //if (alpha < -1.0) {
        //  center = beta;
        //} else if (beta > 1.0) {
        //  center = alpha;
        //} else {
        //  center = (alpha + beta) / 2;
        //}

        final zwResult = checkScoreGame(p.outcome, depth - 1, center, center);
        if (zwResult < center) {
          // Fudge against floating point error.
          scoresUB[i] = zwResult + 0.001;
        } else if (zwResult > center) {
          // Fudge against floating point error.
          scoresLB[i] = zwResult - 0.001;
        }
        sumLB += scoresLB[i] * p.probability + p.probability;
        sumUB += scoresUB[i] * p.probability - p.probability;
        if (sumUB <= alpha) {
          stats.cutoffsByPly[depth]++;
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore <= alpha,
                '$sumUB is <= $alpha, but real score is $checkScore');
            return true;
          }());
          return sumUB;
        } else if (sumLB >= beta) {
          stats.cutoffsByPly[depth]++;
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore >= alpha,
                '$sumUB is >= $beta, but real score is $checkScore');
            return true;
          }());
          return sumLB;
        }
      }
    }

    var sum = 0.0;
    var future = 1.0;
    for (var i = 0; i < chance.possibilities.length; ++i) {
      final p = chance.possibilities[i];
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
      if (!probeChanceNodes &&
          future > alpha + p.probability - sum &&
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
        sum += checkScoreGame(p.outcome, depth - 1, -2.0, 2.0) * p.probability;
        continue;
      }

      final double alphaP;
      final double betaP;
      if (probeChanceNodes) {
        alphaP =
            (alpha - (sumUB - scoresUB[i] * p.probability)) / p.probability -
                0.000001;
        betaP = (beta - (sumLB - scoresLB[i] * p.probability)) / p.probability +
            0.000001;
        assert(() {
          final alphaPP =
              (alpha - sum - worstAlpha * future) / p.probability - 0.0000001;
          final betaPP =
              (beta - sum - worstBeta * future) / p.probability + 0.0000001;
          assert(alphaP + 0.0001 >= alphaPP, '$alphaP is not >= $alphaPP');
          assert(betaP - 0.0001 <= betaPP, '$betaP is not <= $betaPP');
          return true;
        }());
      } else {
        alphaP =
            (alpha - sum - worstAlpha * future) / p.probability - 0.0000001;
        betaP = (beta - sum - worstBeta * future) / p.probability + 0.0000001;
      }

      final score = checkScoreGame(
          p.outcome, depth - 1, max(-2.0, alphaP), min(2.0, betaP));

      if (probeChanceNodes) {
        assert(score >= scoresLB[i]);
        assert(score <= scoresUB[i]);
        sumLB += score * p.probability - scoresLB[i] * p.probability;
        sumUB += score * p.probability - scoresUB[i] * p.probability;

        if (score <= alphaP) {
          assert(sumUB <= alpha,
              'sumUB $sumUB <= alpha $alpha, but $score is not <= $alphaP');
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore <= alpha,
                '$sumUB is <= $alpha, but real score is $checkScore');
            return true;
          }());

          stats.cutoffsByPly[depth]++;
          // Careful, returning a sumUB > alpha due to floating point error will
          // look like an exact score rather than an UB.
          return min(sumUB, alpha);
        } else if (score >= betaP) {
          assert(sumLB >= beta,
              'sumLB $sumLB >= beta $beta, but $score is not >= $betaP');
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore >= alpha,
                '$sumUB is >= $beta, but real score is $checkScore');
            return true;
          }());

          stats.cutoffsByPly[depth]++;
          // Careful, returning a sumLB < beta due to floating point error will
          // look like an exact score rather than an LB.
          return max(sumLB, beta);
        }
      }

      sum += score * p.probability;

      double maxScore = sum + worstAlpha * future;
      double minScore = sum + worstBeta * future;

      if (!probeChanceNodes) {
        if (score <= alphaP) {
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore <= alpha, '$checkScore is not <= $alpha');
            assert(maxScore <= alpha, '$maxScore is not <= $alpha');
            return true;
          }());
          stats.cutoffsByPly[depth]++;
          return maxScore;
        } else if (score >= betaP) {
          assert(() {
            final checkScore =
                chance.expectedValue((g) => scoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore >= beta, '$checkScore is not >= $beta');
            assert(maxScore >= beta, '$maxScore is not >= $beta');
            return true;
          }());
          stats.cutoffsByPly[depth]++;
          return minScore;
        }
      }
    }

    return sum;
  }

  double scoreGame(G game, int depth, double alpha, double beta) {
    stats.ttLookups++;
    return transpositionTable.scoreTransposition(game, depth, alpha, beta,
        (int? lastBestMoveIdx) {
      stats.ttMisses++;
      stats.nodesSearchedByPly[max(depth, 0)]++;
      if (depth <= 0) {
        return MoveScore(score: game.score, moveIdx: null);
      }

      final moves = game.getMoves();

      if (moves.isEmpty) {
        return MoveScore(score: game.score, moveIdx: null);
      }

      var firstMoveIdx = lastBestMoveIdx;
      if (lastBestMoveIdx == null) {
        stats.ttNoFirstMove++;

        if (depth > -1) {
          final killerMove = killerMoves[depth];
          if (killerMove != null) {
            final idx = moves.indexOf(killerMove);
            firstMoveIdx = idx == -1 ? null : idx;
          }
        }
      }

      MoveScore moveScore({required double score, required int moveIdx}) {
        if (moveIdx == firstMoveIdx) {
          stats.firstMoveHits++;
        } else if (firstMoveIdx == null) {
          stats.firstMoveMisses++;
        }

        if (depth > 0 && (score >= beta || score <= alpha)) {
          killerMoves[depth] = moves[moveIdx];
        }
        return MoveScore(score: score, moveIdx: moveIdx);
      }

      if (game.isMaxing) {
        var maxScore = -2.0;
        if (firstMoveIdx != null && firstMoveIdx < moves.length) {
          final score =
              scoreMove(moves[firstMoveIdx], game, depth - 1, alpha, beta);
          if (score >= beta && useAlphaBeta) {
            stats.cutoffsByPly[depth]++;
            return moveScore(score: score, moveIdx: firstMoveIdx);
          }
          maxScore = max(maxScore, score);
          alpha = max(alpha, score);
        }

        var bestMove = firstMoveIdx ?? -1;
        for (var i = 0; i < moves.length; ++i) {
          if (i == firstMoveIdx) {
            continue;
          }
          final move = moves[i];
          final score = scoreMove(move, game, depth - 1, alpha, beta);
          if (score > maxScore) {
            bestMove = i;
          }
          if (score >= beta && useAlphaBeta) {
            stats.cutoffsByPly[depth]++;
            return moveScore(score: score, moveIdx: i);
          }
          maxScore = max(maxScore, score);
          alpha = max(alpha, score);
        }

        return moveScore(score: maxScore, moveIdx: bestMove);
      } else {
        var minScore = 2.0;
        if (firstMoveIdx != null && firstMoveIdx < moves.length) {
          final score =
              scoreMove(moves[firstMoveIdx], game, depth - 1, alpha, beta);
          if (score <= alpha && useAlphaBeta) {
            stats.cutoffsByPly[depth]++;
            return moveScore(score: score, moveIdx: firstMoveIdx);
          }
          minScore = min(minScore, score);
          beta = min(beta, score);
        }
        var bestMove = firstMoveIdx ?? -1;
        for (var i = 0; i < moves.length; ++i) {
          if (i == firstMoveIdx) {
            continue;
          }
          final move = moves[i];
          final score = scoreMove(move, game, depth - 1, alpha, beta);
          if (score < minScore) {
            bestMove = i;
          }
          if (score <= alpha && useAlphaBeta) {
            stats.cutoffsByPly[depth]++;
            return moveScore(score: score, moveIdx: i);
          }
          minScore = min(minScore, score);
          beta = min(beta, score);
        }

        return moveScore(score: minScore, moveIdx: bestMove);
      }
    });
  }
}

class MoveScore {
  MoveScore({
    required this.moveIdx,
    required this.score,
  });

  final int? moveIdx;
  final double score;
}
