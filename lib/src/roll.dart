import 'dart:math';

import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/dice.dart';

class Roll {
  final _cache = <Dice, Chance<int>>{};

  Chance<int> roll(Dice dice) {
    return _cache[dice] ??= _computeAndCache(dice);
  }

  Chance<int> _computeAndCache(Dice dice) {
    final table = <int, int>{};
    _recursiveCompute(dice.sides, dice.rolls, 0, table);
    final comb = pow(dice.sides, dice.rolls);

    return _cache[dice] = Chance<int>(
        possibilities: table.entries
            .map((entry) => Possibility<int>(
                description: 'rolled a ${entry.key}',
                probability: entry.value / comb,
                outcome: entry.key))
            .toList());
  }

  // TODO: use actual statistics to calculate this in fewer steps...
  _recursiveCompute(int sides, int rolls, int baseline, Map<int, int> table) {
    for (int i = 1; i <= sides; ++i) {
      final sum = i + baseline;
      if (rolls == 1) {
        if (table.containsKey(sum)) {
          table[sum] = table[sum]! + 1;
        } else {
          table[sum] = 1;
        }
      } else {
        _recursiveCompute(sides, rolls - 1, sum, table);
      }
    }
  }
}
