class Chance<G> {
  Chance({
    required this.possibilities,
  });

  Chance.just(G outcome)
      : this(possibilities: [Possibility(probability: 1, outcome: outcome)]);

  final List<Possibility<G>> possibilities;

  /// Get the expected value of all possible outcomes, as scored by a function.
  ///
  /// For instance, rolling 1d6 has an expected value of 3.5.
  double expectedValue(double Function(G) scorer) {
    var sum = 0.0;
    for (final p in possibilities) {
      sum += p.probability * scorer(p.outcome);
    }

    return sum;
  }

  /// Transform the possible outcomes without changing the branching factor or
  /// probabilities.
  ///
  /// If the transformation reduces the probability factor, use [reduce].
  ///
  /// For instance, rolling 1d6 and subtracting it from an opponent's health.
  Chance<T> map<T>(T Function(G) f) =>
      Chance<T>(
          possibilities: possibilities
              .map((o) => Possibility<T>(
                    probability: o.probability,
                    outcome: f(o.outcome),
                    description: o.description,
                  ))
              .toList());

  /// Transform the set of possible outcomes into a smaller set of possible
  /// outcomes, summing their probabilities.
  ///
  /// For instance, rolling 1d6 and scoring a point on a roll of 3+. While there
  /// are six sides of the die, there are only two possible outcomes (you score
  /// 1 point or you do not).
  Chance<T> reduce<T>(T Function(G) f) {
    final map = <T, Possibility<T>>{};
    for (final p in possibilities) {
      final outcome = f(p.outcome);
      map.update(
        outcome,
        (v) => Possibility<T>(
          description: '(merged into) ${v.description}',
          probability: v.probability + p.probability,
          outcome: outcome,
        ),
        ifAbsent: () => Possibility<T>(
          description: p.description,
          probability: p.probability,
          outcome: outcome,
        ),
      );
    }

    return Chance<T>(
      possibilities: map.values.toList(),
    );
  }

  /// Transform possibility objects directly, allowing manipulation of
  Chance<T> mapWithProbability<T>(Possibility<T> Function(Possibility<G>) f) =>
      Chance<T>(possibilities: possibilities.map((o) => f(o)).toList());

  /// Supply a number between 0.0 and 1.0, to pick an outcome, weighted by
  /// the probability of that outcome.
  Possibility<G> pick(double select) {
    for (final ro in possibilities) {
      select -= ro.probability;
      if (select < 0) {
        return ro;
      }
    }

    throw 'unreachable';
  }

  /// Given two independent random events, returns a single random event which
  /// describes every combination of outcomes and their probability.
  ///
  /// This is useful for reducing the branching factor of a game and therefore
  /// speeding up searches over its move space.
  ///
  /// For instance, rolling 1d8 + 1d6 does not truly yield 8 * 6 different
  /// random outcomes. Rather, this roll produces a number between 2 and 14.
  Chance<G> mergeWith(Chance<G> other, G Function(G, G) merger) {
    final map = <G, Possibility<G>>{};

    for (final p1 in possibilities) {
      for (final p2 in other.possibilities) {
        final outcome = merger(p1.outcome, p2.outcome);
        final p = p1.probability * p2.probability;
        map.update(
          outcome,
          (v) => Possibility<G>(
            description: '(merged into) ${v.description}',
            probability: v.probability + p,
            outcome: outcome,
          ),
          ifAbsent: () => Possibility<G>(
            description: '${p1.description} and ${p2.description}',
            probability: p,
            outcome: outcome,
          ),
        );
      }
    }

    return Chance<G>(
      possibilities: map.values.toList(),
    );
  }

  /// Find equivalent outcomes and merge them into one possibility to reduce
  /// the branching factor of this chance event.
  ///
  /// This should not typically be necessary, see methods [reduce] and
  /// [mergeWith], which will condense the outcomes automatically.
  Chance<G> condense() {
    final map = <G, Possibility<G>>{};

    for (final p in possibilities) {
      map.update(
          p.outcome,
          (v) => Possibility<G>(
                description: '(condensed into) ${v.description}',
                probability: p.probability + v.probability,
                outcome: p.outcome,
              ),
          ifAbsent: () => p);
    }

    return Chance<G>(
      possibilities: map.values.toList(),
    );
  }
}

class Possibility<G> {
  Possibility({
    this.description,
    required this.probability,
    required this.outcome,
  });

  final String? description;
  final double probability;
  G outcome;
}
