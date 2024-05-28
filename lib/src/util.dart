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
