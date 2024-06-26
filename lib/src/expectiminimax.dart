import 'dart:async';
import 'dart:math';
import 'package:dartnad0/src/config.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/transposition.dart';
import 'package:dartnad0/src/util.dart';

class Expectiminimax<G extends Game<G>> implements Engine<G> {
  Expectiminimax({
    required ExpectiminimaxConfig config,
    TranspositionTable<G>? transpositionTable,
  })  : transpositionTable = transpositionTable ??
            TranspositionTable<G>(config.transpositionTableSize),
        killerMoves =
            List<Move<G>?>.filled(config.maxDepth, null, growable: false),
        stats = SearchStats(config.maxDepth),
        maxDepth = config.maxDepth,
        chanceNodeProbeWindow = config.chanceNodeProbeWindow,
        useIterativeDeepening = config.iterativeDeepening,
        maxSearchDuration = config.maxTime,
        // ignore: deprecated_member_use_from_same_package
        _debugSetting = config.debugSetting;

  final List<Move<G>?> killerMoves;
  final TranspositionTable<G> transpositionTable;
  final SearchStats stats;

  // For internal development only.
  dynamic _debugSetting;

  // Max search depth.
  final int maxDepth;

  // Feature permanently turned on, but, disableable for debugging etc.
  static const bool useAlphaBeta = true;

  // Feature permanently turned on, but, disableable for debugging etc.
  static const bool useStarMinimax = true;

  /// Which type of probing to use on chance node children in order to more
  /// quickly establish a lower/upper bound before a second full search pass.
  final ProbeWindow chanceNodeProbeWindow;

  // Experimental feature, can be turned on or off.
  final bool useIterativeDeepening;

  /// Max time to perform a search, mostly for iterative deepening in order to
  /// search to the maximum depth allowed by circumstance.
  final Duration maxSearchDuration;

  /// A time to abort the search, set when search begins, and checked on every
  /// iteration of the search.
  DateTime timeout = DateTime.now();

  /// Used by negamax algorithm to know when minning/maxing player turns flip,
  /// so we can compute `-score(child, -beta, -alpha)`.
  var _isMaxing = true;

  void clearCache() {
    transpositionTable.clear();
  }

  Future<Move<G>> chooseBest(List<Move<G>> moves, G game) async {
    final start = DateTime.now();
    timeout = start.add(maxSearchDuration);
    final alpha = -2.0;
    final beta = 2.0;
    _isMaxing = game.isMaxing;
    Move<G> bestMove = moves[0];

    try {
      if (useIterativeDeepening) {
        // Increment by 2 because scores don't change on chance node layers.
        for (var i = 2; i < maxDepth; i += 2) {
          bestMove = bestBy<Move<G>, num>(
              moves, (m) => scoreMove(m, game, i, alpha, beta))!;
        }
      } else {
        try {
          bestMove = bestBy<Move<G>, num>(
              moves, (m) => scoreMove(m, game, maxDepth, alpha, beta))!;
        } on TimeoutException {
          print('WARNING: timed out without iterative deepening');
        }
      }
    } on TimeoutException catch (_) {}

    stats.duration += DateTime.now().difference(start);

    return bestMove;
  }

  double checkScoreGame(G game, int depth, double alpha, double beta) {
    assert(alpha <= beta, 'Got alpha $alpha > beta $beta');
    final score = negaScoreGame(game, depth, alpha, beta);
    assert(() {
      final checkedScore = negaScoreGame(game, depth, -2.0, 2.0);
      if (score > alpha && score < beta) {
        assert(checkedScore + 0.00001 > score,
            'Got the wrong score in non-cutoff range: $score vs $checkedScore ($alpha, $beta)');
        assert(checkedScore - 0.00001 < score,
            'Got the wrong score in non-cutoff range: $score vs $checkedScore ($alpha, $beta)');
      } else if (score < alpha) {
        assert(checkedScore - 0.0001 < alpha,
            'Incorrect alpha cutoff: $score vs $checkedScore, alpha $alpha');
        assert(checkedScore - 0.0001 <= score,
            'alpha cutoff with wrong score: $score vs $checkedScore, alpha $alpha');
      } else if (score > beta) {
        assert(checkedScore + 0.0001 > beta,
            'Incorrect beta cutoff: $score vs $checkedScore, beta $beta');
        assert(checkedScore + 0.0001 >= score,
            'beta cutoff with wrong score: $score vs $checkedScore, beta $beta');
      }
      return true;
    }());
    return score;
  }

  double scoreMove(Move<G> move, G game, int depth, double alpha, double beta) {
    stats.nodesSearchedByPly[depth]++;
    final chance = move.perform(game);
    if (!useAlphaBeta || (alpha < -1.0 && beta > 1.0) || depth <= 1) {
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

    final probeChanceNodes =
        chanceNodeProbeWindow != ProbeWindow.none && depth > 1;

    final scoresLB =
        List.filled(chance.possibilities.length, -1.0, growable: false);
    final scoresUB =
        List.filled(chance.possibilities.length, 1.0, growable: false);

    double sumLB = -1.0;
    double sumUB = 1.0;

    // Fudge against floating point error in these two functions.
    double alphaForChild(int i, double probability) =>
        (alpha - (sumUB - scoresUB[i] * probability)) / probability - 0.000001;

    double betaForChild(int i, double probability) =>
        (beta - (sumLB - scoresLB[i] * probability)) / probability + 0.000001;

    // Log and sanitize this cutoff score, plus sanity assertions.
    double alphaCutoff() {
      assert(sumUB <= alpha,
          'sumUB $sumUB > alpha $alpha, but we were told to alpha cutoff');
      assert(() {
        final checkScore =
            chance.expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
        assert(checkScore <= alpha,
            '$sumUB is <= $alpha, but real score is $checkScore');
        return true;
      }());

      stats.cutoffsByPly[depth]++;
      // Careful, returning a sumUB > alpha due to floating point error will
      // look like an exact score rather than an UB.
      return min(sumUB, alpha).clamp(-2.0, 2.0);
    }

    // Log and sanitize this cutoff score, plus sanity assertions.
    double betaCutoff() {
      assert(sumLB >= beta,
          'sumLB $sumLB < beta $beta, but we were told to beta cutoff');
      assert(() {
        final checkScore =
            chance.expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
        assert(checkScore >= beta,
            '$sumUB is >= $beta, but real score is $checkScore');
        return true;
      }());

      stats.cutoffsByPly[depth]++;
      // Careful, returning a sumLB < beta due to floating point error will
      // look like an exact score rather than an LB.
      return max(sumLB, beta).clamp(-2.0, 2.0);
    }

    if (probeChanceNodes) {
      probeSearch:
      for (var i = 0; i < chance.possibilities.length; ++i) {
        final p = chance.possibilities[i];

        final double ubSearchBottom;
        final double lbSearchTop;

        switch (chanceNodeProbeWindow) {
          case ProbeWindow.none:
            assert(false, 'should not get here');
            break probeSearch;
          case ProbeWindow.overlapping:
            lbSearchTop = beta;
            ubSearchBottom = alpha;
            break;
          case ProbeWindow.centerToEnd:
            ubSearchBottom = lbSearchTop = (alpha + beta) / 2;
            break;
          case ProbeWindow.edgeToEnd:
            lbSearchTop = alpha;
            ubSearchBottom = beta;
            break;
        }

        // Probe for an upper bound (from ubSearchBottom to 2.0 or cutoff).
        //
        // TODO: Investigate why alpha > -1.0 condition speeds up backgammon,
        // but slows down dicebattle.
        // TODO: Investigate why 1.0 > ubSearchBottom > -1.0 condition speeds
        // up dicebattle but slows down backgammon.
        //
        // For now, use both, which functions well as a compromise.
        if (ubSearchBottom > -1.0 && ubSearchBottom < 1.0 && alpha > -1.0) {
          final betaP = min(betaForChild(i, p.probability), 2.0);

          // The upper bound we chose to probe is actually in cutoff range. For
          // now, we just skip, though, we may be able to do something smarter.
          if (ubSearchBottom < betaP) {
            final ubSearch =
                checkScoreGame(p.outcome, depth - 1, ubSearchBottom, betaP);
            sumUB += (ubSearch - scoresUB[i]) * p.probability;
            scoresUB[i] = ubSearch;
            if (ubSearch >= ubSearchBottom) {
              sumLB += (ubSearch - scoresLB[i]) * p.probability;
              scoresLB[i] = ubSearch;
            }
            if (ubSearch >= betaP) {
              return betaCutoff();
            }
          }
        }

        // Probe for a lower bound (from -2.0 or cutoff to lbSearchTop).
        //
        // TODO: Investigate why beta < 1.0 condition speeds up backgammon,
        // but slows down dicebattle.
        // TODO: Investigate why 1.0 > lbSearchTop > -1.0 condition speeds
        // but backgammon but slows down dicebattle.
        //
        // For now, use beta < 1.0, as it dicebattle is more of a solver and
        // backgammon is more likely to be more representative.
        if (lbSearchTop < 1.0 &&
            lbSearchTop > -1.0 &&
            alpha != beta &&
            scoresUB[i] != scoresLB[i]) {
          final alphaP = max(alphaForChild(i, p.probability), -2.0);

          // The lower bound we chose to probe is actually in cutoff range. For
          // now, we just skip, though, we may be able to do something smarter.
          if (alphaP < lbSearchTop) {
            final lbSearch =
                checkScoreGame(p.outcome, depth - 1, alphaP, lbSearchTop);
            sumLB -= scoresLB[i] * p.probability;
            scoresLB[i] = max(scoresLB[i], lbSearch);
            sumLB += scoresLB[i] * p.probability;
            if (lbSearch <= lbSearchTop) {
              sumUB -= scoresUB[i] * p.probability;
              scoresUB[i] = min(scoresUB[i], lbSearch);
              sumUB += scoresUB[i] * p.probability;
            }
            if (lbSearch <= alphaP) {
              return alphaCutoff();
            }
          }
        }

        if (sumUB <= alpha) {
          stats.cutoffsByPly[depth]++;
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore - 0.000001 <= alpha,
                '$sumUB is <= $alpha, but real score is $checkScore');
            return true;
          }());
          return sumUB.clamp(-2.0, 2.0);
        } else if (sumLB >= beta) {
          stats.cutoffsByPly[depth]++;
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore + 0.000001 >= beta,
                '$sumUB is >= $beta, but real score is $checkScore');
            return true;
          }());
          return sumLB.clamp(-2.0, 2.0);
        }

        // This indicates that we cannot possibly produce any cutoffs, and it is
        // not worth probing any more.
        if (sumLB > alpha && sumUB < beta) {
          break;
        }
      }
    }

    var sum = 0.0;
    var future = 1.0;
    for (var i = 0; i < chance.possibilities.length; ++i) {
      final p = chance.possibilities[i];
      future -= p.probability;

      if (probeChanceNodes && scoresLB[i] == scoresUB[i]) {
        sum += scoresLB[i] * p.probability;
        continue;
      }

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
        assert(score + 0.000001 >= scoresLB[i],
            '$score is not >= lb ${scoresLB[i]}');
        assert(score - 0.000001 <= scoresUB[i],
            '$score is not <= ub ${scoresUB[i]}');
        sumLB += score * p.probability - scoresLB[i] * p.probability;
        sumUB += score * p.probability - scoresUB[i] * p.probability;

        if (score <= alphaP) {
          assert(sumUB <= alpha,
              'sumUB $sumUB <= alpha $alpha, but $score is not <= $alphaP');
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore <= alpha,
                '$sumUB is <= $alpha, but real score is $checkScore');
            return true;
          }());

          stats.cutoffsByPly[depth]++;
          // Careful, returning a sumUB > alpha due to floating point error will
          // look like an exact score rather than an UB.
          return min(sumUB, alpha).clamp(-2.0, 2.0);
        } else if (score >= betaP) {
          assert(sumLB >= beta,
              'sumLB $sumLB >= beta $beta, but $score is not >= $betaP');
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore >= alpha,
                '$sumUB is >= $beta, but real score is $checkScore');
            return true;
          }());

          stats.cutoffsByPly[depth]++;
          // Careful, returning a sumLB < beta due to floating point error will
          // look like an exact score rather than an LB.
          return max(sumLB, beta).clamp(-2.0, 2.0);
        }
      }

      sum += score * p.probability;

      double maxScore = sum + worstAlpha * future;
      double minScore = sum + worstBeta * future;

      if (!probeChanceNodes) {
        if (score <= alphaP) {
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
            assert(checkScore <= alpha, '$checkScore is not <= $alpha');
            assert(maxScore <= alpha, '$maxScore is not <= $alpha');
            return true;
          }());
          stats.cutoffsByPly[depth]++;
          return maxScore;
        } else if (score >= betaP) {
          assert(() {
            final checkScore = chance
                .expectedValue((g) => negaScoreGame(g, depth - 1, -2.0, 2.0));
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

  /// Negamax algorithm phase, choose the best move for the current player.
  ///
  /// If `game.isMaxing` flips, this will recurse to return
  /// `-negamax(game, depth, -beta, -alpha`, so that we can perform max and
  /// min nodes with one consistent logical pathway (fewer bugs).
  double negaScoreGame(G game, int depth, double alpha, double beta) {
    if (game.isMaxing != _isMaxing) {
      _isMaxing = !_isMaxing;
      final score = -negaScoreGame(game, depth, -beta, -alpha);
      assert(_isMaxing == game.isMaxing);
      _isMaxing = !_isMaxing;
      return score;
    }

    if (!DateTime.now().isBefore(timeout)) {
      throw TimeoutException('Search timed out, backing out');
    }

    stats.ttLookups++;
    return transpositionTable.scoreTransposition(game, depth, alpha, beta,
        (int? lastBestMoveIdx) {
      stats.ttMisses++;
      stats.nodesSearchedByPly[max(depth, 0)]++;
      if (depth <= 0) {
        return MoveScore(
            score: game.score * (game.isMaxing ? 1.0 : -1.0), moveIdx: null);
      }

      final moves = game.getMoves();

      if (moves.isEmpty) {
        return MoveScore(
            score: game.score * (game.isMaxing ? 1.0 : -1.0), moveIdx: null);
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

      var bestMove = firstMoveIdx ?? 0;
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
