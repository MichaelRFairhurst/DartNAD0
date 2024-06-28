import 'dart:math';

import 'package:dartnad0/src/expectiminimax.dart';
import 'package:dartnad0/src/game.dart';

/// A simple transposition table that takes a game's hash and creates four
/// candidate buckets based on HASH + n % size for n=0..3.
///
/// By default, this does not require strict equality but rather assumes a good
/// enough hashing algorithm. Set the optional parameter [isStrict] to true to
/// prevent hash collisions, although do note that this takes up more memory.
class TranspositionTable<G extends Game<G>> {
  /// Total number of entries in the transition table.
  final int size;

  /// Whether to use `==` on lookup, to ensure hits are not hash collisions.
  ///
  /// Requires additional memory and skipped by most chess engines. However,
  /// this is also required for correctness/avoids search instability.
  final bool isStrict;

  final List<_PositionData?> _table;
  final List<G?> _strictStore;

  TranspositionTable(this.size, {this.isStrict = false})
      : _table = List.filled(size, null, growable: false),
        _strictStore =
            isStrict ? List.filled(size, null, growable: false) : const [];

  void clear() {
    _table.fillRange(0, size, null);
    if (isStrict) {
      _strictStore.fillRange(0, size, null);
    }
  }

  double scoreTransposition(G game, int work, double alpha, double beta,
      MoveScore Function(int?) ifAbsent) {
    final hash = game.hashCode;
    final bucket = _bucket(hash, game);

    if (bucket == null) {
      final moveScore = ifAbsent(null);
      var maxScore = _maxScoreFor(moveScore.score, beta: beta);
      var minScore = _minScoreFor(moveScore.score, alpha: alpha);
      if (!game.isMaxing) {
        final temp = maxScore;
        maxScore = minScore == null ? null : -minScore;
        minScore = temp == null ? null : -temp;
      }
      _add(
        game,
        hash: game.hashCode,
        work: work,
        maxScore: maxScore,
        minScore: minScore,
        moveIdx: moveScore.moveIdx,
      );

      return moveScore.score;
    } else {
      final entry = _table[bucket]!;
      final oldScore = _validScore(entry, work, alpha, beta, game.isMaxing);

      if (oldScore != null) {
        return oldScore;
      } else {
        final moveScore = ifAbsent(entry.moveIdx);
        var maxScore = _maxScoreFor(moveScore.score, beta: beta);
        var minScore = _minScoreFor(moveScore.score, alpha: alpha);

        // Recursion may have replaced this bucket, we can only keep min/max
        // if it applies to the current game and we have the *same* work.
        if (_isSame(bucket, game, hash) && entry.work == work) {
          maxScore ??= entry.maxScore;
          minScore ??= entry.minScore;
        }

        // Mutate existing to avoid thrashing GC.
        if (!game.isMaxing) {
          final temp = maxScore;
          maxScore = minScore == null ? null : -minScore;
          minScore = temp == null ? null : -temp;
        }

        _table[bucket]!
          ..hash = hash
          ..work = work
          ..maxScore = maxScore
          ..minScore = minScore
          ..moveIdx = moveScore.moveIdx;
        _setStrict(hash, game);

        return moveScore.score;
      }
    }
  }

  double? _validScore(
      _PositionData entry, int work, double alpha, double beta, bool isMaxing) {
    var factor = 1.0;
    if (!isMaxing) {
      final temp = beta;
      beta = -alpha;
      alpha = -temp;
      factor = -1.0;
    }

    if (entry.minScore == 1.0) {
      return factor * 1.0;
    } else if (entry.maxScore == -1.0) {
      return factor * -1.0;
    }

    if (entry.work < work) {
      return null;
    }

    if (entry.work != work) {
      assert(false, 'This breaks correctness and will fail other assertions.');
    }

    if (entry.minScore == entry.maxScore) {
      return factor * entry.minScore!;
    } else if (entry.maxScore != null && entry.maxScore! <= alpha) {
      return factor * entry.maxScore!;
    } else if (entry.minScore != null && entry.minScore! >= beta) {
      return factor * entry.minScore!;
    }

    return null;
  }

  double? _maxScoreFor(double score, {required double beta}) {
    if (score >= beta) {
      return null;
    } else {
      return score;
    }
  }

  double? _minScoreFor(double score, {required double alpha}) {
    if (score <= alpha) {
      return null;
    } else {
      return score;
    }
  }

  int? _bucket(int hash, G game) {
    for (int i = 0; i < 4; ++i) {
      final bucket = (hash + i) % size;
      if (_isSame(bucket, game, hash)) {
        return bucket;
      }
    }
    return null;
  }

  void _add(
    G game, {
    required int hash,
    required int work,
    required double? minScore,
    required double? maxScore,
    required int? moveIdx,
  }) {
    int worstIdx = -1;
    _PositionData? worstEntry;
    for (int i = 0; i < 4; ++i) {
      final bucket = (hash + i) % size;
      final entry = _table[bucket];
      if (worstIdx == -1) {
        worstIdx = bucket;
        worstEntry = entry;
      }

      if (entry?.hash == hash) {
        worstEntry = entry;
        worstIdx = bucket;
        break;
      } else if (_isWorse(knownWorst: worstEntry, candidate: entry)) {
        worstEntry = entry;
        worstIdx = bucket;
      }
    }

    if (worstEntry == null) {
      _table[worstIdx] = _PositionData(
        hash: hash,
        work: work,
        maxScore: maxScore,
        minScore: minScore,
        moveIdx: moveIdx,
      );
    } else {
      // We have to have equal work, or we're effectively "promoting" one
      // result (current or past).
      if (_isSame(worstIdx, game, hash) && worstEntry.work == work) {
        maxScore ??= worstEntry.maxScore;
        minScore ??= worstEntry.minScore;
      }

      // Mutate existing to avoid thrashing GC.
      worstEntry
        ..hash = hash
        ..work = work
        ..maxScore = maxScore
        ..minScore = minScore
        ..moveIdx = moveIdx;
    }
    _setStrict(worstIdx, game);
  }

  void _setStrict(int bucket, G game) {
    if (!isStrict) {
      return;
    }

    _strictStore[bucket] = game;
  }

  bool _isSame(int bucket, G game, int hash) {
    final entry = _table[bucket];
    if (entry?.hash != hash) {
      return false;
    }

    if (!isStrict) {
      return true;
    }

    return game == _strictStore[bucket];
  }

  bool _isWorse({_PositionData? knownWorst, _PositionData? candidate}) {
    if (knownWorst == null) {
      return false;
    } else if (candidate == null) {
      return true;
    } else {
      return candidate.work < knownWorst.work;
    }
  }
}

/// Cached data about a position. Note that these table entries are designed to
/// be mutable, to avoid thrashing GC.
///
/// Note that these entries currently score a max and a min score. However, they
/// *could* store a single double score, plus a constraint (min, max, exact).
/// Past versions did this, and in theory this approach can take up less space.
///
/// This was changed to improve the performance of edgeToEnd chance searches,
/// where a chance node's children can be scanned for extreme outcomes only
/// before searching the center. This results in a constrained min and max.
class _PositionData {
  _PositionData({
    required this.hash,
    required this.work,
    required this.minScore,
    required this.maxScore,
    required this.moveIdx,
  });

  /// The hash of the position.
  int hash;

  /// The amount of work done to compute these cache results.
  int work;

  /// The last best move at this position.
  int? moveIdx;

  /// The min score of this position.
  double? minScore;

  /// The max score of this position.
  double? maxScore;

  @override
  String toString() {
    return '($hash: min $minScore max $maxScore, work $work hashmove $moveIdx)';
  }
}
