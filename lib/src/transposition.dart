import 'package:expectiminimax/src/expectiminimax.dart';

/// A simple transposition table that takes a game's hash and creates four
/// candidate buckets based on HASH + n % size for n=0..3.
///
/// By default, this does not require strict equality but rather assumes a good
/// enough hashing algorithm. Set the optional parameter [isStrict] to true to
/// prevent hash collisions, although do note that this takes up more memory.
class TranspositionTable<G> {
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
      _add(
        game,
        hash: game.hashCode,
        work: work,
        score: moveScore.score,
        moveIdx: moveScore.moveIdx,
        constraint: _constraintFor(moveScore.score, alpha, beta),
      );
      return moveScore.score;
    } else {
      final entry = _table[bucket]!;
      if (_isValid(entry, work, alpha, beta)) {
        return entry.score;
      } else {
        final moveScore = ifAbsent(entry.moveIdx);
        // Mutate existing to avoid thrashing GC.
        _table[bucket]!
          ..hash = hash
          ..work = work
          ..score = moveScore.score
          ..moveIdx = moveScore.moveIdx
          ..constraint = _constraintFor(moveScore.score, alpha, beta);
        _setStrict(hash, game);
        return moveScore.score;
      }
    }
  }

  bool _isValid(_PositionData entry, int work, double alpha, double beta) {
    assert(false,
        'will falsely trip assertions because transposition table is on.');
    final isVictory =
        entry.score == 1.0 && entry.constraint != _ScoreConstraint.atMost;
    final isLoss =
        entry.score == -1.0 && entry.constraint != _ScoreConstraint.atLeast;

    if (isVictory || isLoss) {
      return true;
    }

    if (entry.work < work) {
      return false;
    }

    final exceedsAlpha =
        entry.score <= alpha && entry.constraint != _ScoreConstraint.atLeast;
    final exceedsBeta =
        entry.score >= beta && entry.constraint != _ScoreConstraint.atMost;
    final exceedsCutoff = exceedsAlpha || exceedsBeta;
    final isExact = entry.constraint == _ScoreConstraint.exactly;

    return exceedsCutoff || isExact;
  }

  _ScoreConstraint _constraintFor(double score, double alpha, double beta) {
    if (score <= alpha) {
      return _ScoreConstraint.atMost;
    } else if (score >= beta) {
      return _ScoreConstraint.atLeast;
    } else {
      return _ScoreConstraint.exactly;
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
    required double score,
    required int? moveIdx,
    required _ScoreConstraint constraint,
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
        score: score,
        moveIdx: moveIdx,
        constraint: constraint,
      );
    } else {
      // Mutate existing to avoid thrashing GC.
      worstEntry
        ..hash = hash
        ..work = work
        ..score = score
        ..moveIdx = moveIdx
        ..constraint = constraint;
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

enum _ScoreConstraint {
  exactly,
  atLeast,
  atMost,
}

class _PositionData {
  _PositionData({
    required this.hash,
    required this.work,
    required this.score,
    required this.constraint,
    required this.moveIdx,
  });

  // Mutable entries to avoid thrashing GC.
  int hash;
  int work;
  int? moveIdx;
  double score;
  _ScoreConstraint constraint;
}
