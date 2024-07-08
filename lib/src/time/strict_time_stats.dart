import 'package:dartnad0/src/stats.dart';

class StrictTimeStats extends SearchStats {
  /// How much time has been spent searching.
  Duration duration = Duration.zero;

  /// How many searches were performed.
  int searchCount = 0;

  /// How many searches were killed for going over time.
  int killedSearches = 0;

  /// Add all event counts (cutoffs, nodes searched, transposition table hits
  /// and misses, etc) to these stats.
  ///
  /// This will mutate the current instance but not the provided SearchStats.
  void add(StrictTimeStats other) {
    duration += other.duration;
    searchCount += other.searchCount;
    killedSearches += other.killedSearches;
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// This will mutate the current instance but not the provided StrictTimeStats.
  void subtract(StrictTimeStats other) {
    duration -= other.duration;
    searchCount -= other.searchCount;
    killedSearches -= other.killedSearches;
  }

  /// Add the [other] search stats to these stats, to get cumulative numbers
  /// between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  StrictTimeStats operator +(StrictTimeStats other) {
    return StrictTimeStats()
      ..add(this)
      ..add(other);
  }

  /// Negate these stats, and return the result in a new instance.
  ///
  /// Does not mutate this instance.
  StrictTimeStats operator -() {
    return StrictTimeStats()..subtract(this);
  }

  /// Subtract the [other] search stats from these stats, to get comparative
  /// numbers between them, and return the result in a new instance.
  ///
  /// Does not mutate either instance.
  StrictTimeStats operator -(StrictTimeStats other) {
    return StrictTimeStats()
      ..add(this)
      ..subtract(other);
  }

  @override
  String toString() {
    return 'Total time: ${duration.inMilliseconds}ms\n'
        'Killed searches: $killedSearches / $searchCount,'
        ' perc ${killedSearches / searchCount}\n';
  }
}
