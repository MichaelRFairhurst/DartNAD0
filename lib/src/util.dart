T? bestBy<T, R extends Comparable<R>>(Iterable<T> list, R Function(T) ranker) {
  T? result;
  R? score;
  for (final item in list) {
    if (result == null) {
      result = item;
    } else {
      if (score == null) {
        score = ranker(result);
      }
      final newScore = ranker(item);
      if (newScore.compareTo(score) > 0) {
        result = item;
        score = newScore;
      }
    }
  }

  return result;
}

int? bestIdxBy<R extends Comparable<R>>(int length, R Function(int) ranker) {
  int? result;
  R? score;
  for (int i = 0; i < length; ++i) {
    if (result == null) {
      result = i;
    } else {
      if (score == null) {
        score = ranker(result);
      }
      final newScore = ranker(i);
      if (newScore.compareTo(score) > 0) {
        result = i;
        score = newScore;
      }
    }
  }

  return result;
}
