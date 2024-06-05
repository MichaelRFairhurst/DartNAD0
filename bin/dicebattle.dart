import 'dart:math';
import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/dice.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/roll.dart';
import 'package:expectiminimax/src/stats.dart';

const winningScore = 20;
const die = r1d6;
const investCost = -1;
const maxScoreRoll = 3;
const attackPointWin = 0;

class DiceBattle extends Game<DiceBattle> {
  DiceBattle({
    required this.p1Score,
    required this.p1DiceScore,
    required this.p2Score,
    required this.p2DiceScore,
    required this.p1Turn,
    required this.roll,
  });

  final Roll roll;
  final int p1Score;
  final int p1DiceScore;
  final int p2Score;
  final int p2DiceScore;
  final bool p1Turn;

  @override
  double get score {
    if (p1Score >= winningScore) {
      return 1.0;
    } else if (p2Score >= winningScore) {
      return -1.0;
    }

    return (p1Score - p2Score) / winningScore;
  }

  @override
  bool get isMaxing => p1Turn;

  @override
  List<Move<DiceBattle>> getMoves() {
    if (p1Score >= winningScore || p2Score >= winningScore) {
      return const [];
    }

    const fortifyOnly = [Fortify()];
    const canInvest = [Fortify(), Invest()];
    const canAttack = [Fortify(), Attack()];
    const all = [Fortify(), Invest(), Attack()];

    final myScore = p1Turn ? p1Score : p2Score;
    final oppScore = p1Turn ? p2Score : p1Score;
    final myDice = p1Turn ? p1DiceScore : p2DiceScore;
    final opDice = p1Turn ? p2DiceScore : p1DiceScore;

    final legalToAttack = opDice > 1 && myDice * 6 >= oppScore;
    final legalToInvest = myScore >= investCost;

    if (legalToAttack && legalToInvest) {
      return all;
    } else if (!legalToAttack && !legalToInvest) {
      return fortifyOnly;
    } else if (legalToAttack) {
      return canAttack;
    } else {
      return canInvest;
    }
  }

  DiceBattle adjust({
    bool flipTurns = false,
    int curScore = 0,
    int curDiceScore = 0,
    int oppScore = 0,
    int oppDiceScore = 0,
  }) =>
      copyWith(
        p1Turn: flipTurns ? !p1Turn : p1Turn,
        p1Score: p1Score + (p1Turn ? curScore : oppScore),
        p1DiceScore: p1DiceScore + (p1Turn ? curDiceScore : oppDiceScore),
        p2Score: p2Score + (p1Turn ? oppScore : curScore),
        p2DiceScore: p2DiceScore + (p1Turn ? oppDiceScore : curDiceScore),
      );

  DiceBattle copyWith({
    int? p1Score,
    int? p1DiceScore,
    int? p2Score,
    int? p2DiceScore,
    bool? p1Turn,
  }) =>
      DiceBattle(
        p1Score: p1Score ?? this.p1Score,
        p1DiceScore: p1DiceScore ?? this.p1DiceScore,
        p2Score: p2Score ?? this.p2Score,
        p2DiceScore: p2DiceScore ?? this.p2DiceScore,
        p1Turn: p1Turn ?? this.p1Turn,
        roll: roll,
      );

  @override
  bool operator ==(Object? other) {
    return other is DiceBattle &&
        other.p1Score == p1Score &&
        other.p2Score == p2Score &&
        other.p1DiceScore == p1DiceScore &&
        other.p2DiceScore == p2DiceScore &&
        other.p1Turn == p1Turn;
  }

  @override
  int get hashCode {
    // Mixed radix id as hash code, because we store every game without
    // collision in a reasonably small transition table like this.
    int result = p1Turn ? 1 : 0;
    result = result * 30 + p1Score;
    result = result * 30 + p2Score;
    result = result * 10 + p1DiceScore;
    result = result * 10 + p2DiceScore;
    return result;
  }
}

class Fortify implements Move<DiceBattle> {
  const Fortify();

  @override
  String get description => 'fortify';

  static Chance<int>? _singleRoll;
  static Chance<int> getSingleRoll(Roll roll) =>
      _singleRoll ??= roll.roll(die).reduce((r) => r <= maxScoreRoll ? r : 0);

  static final _manyRollsCache = <Chance<int>>[];
  static Chance<int> manyRolls(Roll roll, int count) {
    if (_manyRollsCache.length >= count) {
      return _manyRollsCache[count - 1];
    }

    final singleRoll = getSingleRoll(roll);
    if (_manyRollsCache.isEmpty) {
      _manyRollsCache.add(singleRoll);
    }
    var chance = singleRoll;
    for (int i = _manyRollsCache.length + 1; i <= count; ++i) {
      chance = chance.mergeWith(singleRoll, (a, b) => a + b);
      _manyRollsCache.add(chance);
    }
    assert(_manyRollsCache.length == count);
    assert(identical(_manyRollsCache[count - 1], chance));
    return chance;
  }

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    int rollCount = game.p1Turn ? game.p1DiceScore : game.p2DiceScore;

    final chance = manyRolls(game.roll, rollCount);

    return chance.map((result) => game.adjust(
          flipTurns: true,
          curScore: result,
        ));
  }
}

class Invest implements Move<DiceBattle> {
  const Invest();

  @override
  String get description => 'invest';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    return Chance<DiceBattle>.just(game.adjust(
      flipTurns: true,
      curScore: -investCost,
      curDiceScore: 1,
    ));
  }
}

class Attack implements Move<DiceBattle> {
  const Attack();

  @override
  String get description => 'attack';

  static final attackMap = <Dice, Map<int, Chance<bool>>>{};

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    final rolls = game.p1Turn ? game.p1DiceScore : game.p2DiceScore;
    final toHit = game.p1Turn ? game.p2Score : game.p1Score;

    final dice = Dice(sides: die.sides, rolls: rolls);

    final chance = attackMap.putIfAbsent(dice, () {
      return <int, Chance<bool>>{};
    }).putIfAbsent(toHit, () {
      return game.roll.roll(dice).reduce((roll) => roll >= toHit);
    });

    return chance.map((hit) {
      if (hit) {
        return game.adjust(
          flipTurns: true,
          curScore: attackPointWin +
              (game.p1Turn ? game.p2DiceScore : game.p1DiceScore),
          oppDiceScore: -1,
        );
      } else {
        return game.adjust(
          flipTurns: true,
        );
      }
    });
  }
}

void main() {
  final startingGame = DiceBattle(
    p1Turn: true,
    p1Score: 0,
    p1DiceScore: 1,
    p2Score: 0,
    p2DiceScore: 1,
    roll: Roll(),
  );
  final random = Random(0);
  final maxDepth = 20;
  final stats = SearchStats(maxDepth);

  final start = DateTime.now();
  for (int i = 0; i < 100; ++i) {
    final expectiminimax = Expectiminimax<DiceBattle>(maxDepth: maxDepth);
    var game = startingGame;
    var turns = 0;
    while (game.score != 1.0 && game.score != -1.0) {
      turns++;
      final Move<DiceBattle> move;
      move = expectiminimax.chooseBest(game.getMoves(), game);
      //if (move.description == 'attack') {
      //  print('turn $turns ${move.description}');
      //}
      final chance = move.perform(game);
      final outcome = chance.pick(random.nextDouble());
      game = outcome.outcome;
    }

    //print('turns $turns');
    //print('p1: ${game.p1Score} / ${game.p1DiceScore}');
    //print('p2: ${game.p2Score} / ${game.p2DiceScore}');
    stats.add(expectiminimax.stats);
  }
  final end = DateTime.now();
  print('took ${end.difference(start).inMilliseconds}ms');
  print(stats);
}
