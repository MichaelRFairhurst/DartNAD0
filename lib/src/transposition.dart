/// A simple transposition table that takes a game's hash and creates four
///candidate
class TranspositionTable<G> {
  final List<_PositionData?> _table;
  final int size;

  TranspositionTable(this.size)
      : _table = List.filled(size, null, growable: false);

  double scoreTransposition(G game, int work, double Function() ifAbsent) {
    final hash = game.hashCode;
    final bucket = _bucket(hash);

    if (bucket == null) {
      final score = ifAbsent();
      _add(
        hash: game.hashCode,
        work: work,
        score: score,
      );
      return score;
    } else {
      final entry = _table[bucket]!;
      if (entry.work >= work || entry.score == 1.0 || entry.score == -1.0) {
        return entry.score;
      } else {
        final score = ifAbsent();
        // Mutate existing to avoid thrashing GC.
        _table[bucket]!
          ..hash = hash
          ..work = work
          ..score = score;
        return score;
      }
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

  void _add({required int hash, required int work, required double score}) {
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
      );
    } else {
      // Mutate existing to avoid thrashing GC.
      worstEntry
        ..hash = hash
        ..work = work
        ..score = score;
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

class _PositionData {
  _PositionData({
    required this.hash,
    required this.work,
    required this.score,
  });

  // Mutable entries to avoid thrashing GC.
  int hash;
  int work;
  double score;
}
