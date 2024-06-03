/// A simple transposition table that takes a game's hash and creates four
///candidate
class TranspositionTable<G> {
  final List<_PositionData?> _table;
  final int size;

  TranspositionTable(this.size)
      : _table = List.filled(size, null, growable: false);

  double scoreTransposition(
      G game, int work, double alpha, double beta, double Function() ifAbsent) {
    final hash = game.hashCode;
    final bucket = _bucket(hash);

    if (bucket == null) {
      final score = ifAbsent();
      _add(
        hash: game.hashCode,
        work: work,
        score: score,
        constraint: _constraintFor(score, alpha, beta),
      );
      return score;
    } else {
      final entry = _table[bucket]!;
      if (_isValid(entry, work, alpha, beta)) {
        return entry.score;
      } else {
        final score = ifAbsent();
        // Mutate existing to avoid thrashing GC.
        _table[bucket]!
          ..hash = hash
          ..work = work
          ..score = score
          ..constraint = _constraintFor(score, alpha, beta);
        return score;
      }
    }
  }

  bool _isValid(_PositionData entry, int work, double alpha, double beta) {
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
        entry.score > alpha && entry.constraint != _ScoreConstraint.atMost;
    final exceedsBeta =
        entry.score < beta && entry.constraint != _ScoreConstraint.atLeast;
    final exceedsCutoff = exceedsAlpha || exceedsBeta;
    final isExact = entry.constraint == _ScoreConstraint.exactly;

    return exceedsCutoff || isExact;
  }

  _ScoreConstraint _constraintFor(double score, double alpha, double beta) {
    if (score <= alpha) {
      return _ScoreConstraint.atLeast;
    } else if (score >= beta) {
      return _ScoreConstraint.atMost;
    } else {
      return _ScoreConstraint.exactly;
    }
  }

  int? _bucket(int hash) {
    for (int i = 0; i < 4; ++i) {
      final bucket = (hash + i) % size;
      final entry = _table[bucket];
      if (entry != null && entry.hash == hash) {
        return bucket;
      }
    }
    return null;
  }

  void _add({
    required int hash,
    required int work,
    required double score,
    required _ScoreConstraint constraint,
  }) {
    int worstIdx = -1;
    _PositionData? worstEntry;
    for (int i = 0; i < 4; ++i) {
      final bucket = (hash + i) % size;
      final entry = _table[bucket];
      if (entry == null) {
        worstIdx = bucket;
        worstEntry = entry;
        break;
      } else {
        if (_isWorse(worstEntry, entry)) {
          worstEntry = entry;
          worstIdx = bucket;
        }
      }
    }

    if (worstEntry == null) {
      _table[worstIdx] = _PositionData(
        hash: hash,
        work: work,
        score: score,
        constraint: constraint,
      );
    } else {
      // Mutate existing to avoid thrashing GC.
      worstEntry
        ..hash = hash
        ..work = work
        ..score = score
        ..constraint = constraint;
    }
  }

  bool _isWorse(_PositionData? knownWorst, _PositionData? candidate) {
    if (knownWorst == null) {
      return true;
    } else if (candidate == null) {
      return false;
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
  });

  // Mutable entries to avoid thrashing GC.
  int hash;
  int work;
  double score;
  _ScoreConstraint constraint;
}
