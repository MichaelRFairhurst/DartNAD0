class Chance<G> {
  Chance({
    required this.possibilities,
  });

  Chance.just(G outcome)
      : this(possibilities: [Possibility(probability: 1, outcome: outcome)]);

  final List<Possibility<G>> possibilities;

  double expectedValue(double Function(G) scorer) {
    var sum = 0.0;
    for (final p in possibilities) {
      sum += p.probability * scorer(p.outcome);
    }

    return sum;
  }

  Chance<T> map<T>(T Function(G) f) => Chance<T>(
      possibilities: possibilities
          .map((o) => Possibility<T>(
                probability: o.probability,
                outcome: f(o.outcome),
                description: o.description,
              ))
          .toList());

  Chance<T> mapWithProbability<T>(Possibility<T> Function(Possibility<G>) f) =>
      Chance<T>(possibilities: possibilities.map((o) => f(o)).toList());

  Possibility<G> pick(double select) {
    for (final ro in possibilities) {
      select -= ro.probability;
      if (select < 0) {
        return ro;
      }
    }

    throw 'unreachable';
  }

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
