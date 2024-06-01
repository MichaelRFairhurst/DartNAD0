import 'dart:math';
import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/dice.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/roll.dart';

const winningScore = 15;
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
    final opDice = p1Turn ? p2DiceScore : p1DiceScore;

    if (opDice > 1 && myScore >= investCost) {
      return all;
    } else if (opDice == 1 && myScore < investCost) {
      return fortifyOnly;
    } else if (opDice > 1) {
      return canAttack;
    } else {
      return canInvest;
    }
  }

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
  int get hashCode => Object.hashAll([
        p1Score,
        p2Score,
        p1DiceScore,
        p2DiceScore,
        p1Turn,
      ]);
}

class Fortify implements Move<DiceBattle> {
  const Fortify();

  @override
  String get description => 'fortify';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    final singleRoll = game.roll
        .roll(die)
        .reduce((r) => r <= maxScoreRoll ? r : 0);

    int rollCount = game.p1Turn ? game.p1DiceScore : game.p2DiceScore;

    var chance = singleRoll;
    for (int i = 1; i < rollCount; ++i) {
      chance = chance.mergeWith(singleRoll, (a, b) => a + b);
    }

    return chance.map((result) => game.copyWith(
          p1Turn: !game.p1Turn,
          p1Score: game.p1Turn ? game.p1Score + result : null,
          p2Score: game.p1Turn ? null : game.p2Score + result,
        ));
  }
}

class Invest implements Move<DiceBattle> {
  const Invest();

  @override
  String get description => 'invest';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    return Chance<DiceBattle>.just(game.copyWith(
      p1Turn: !game.p1Turn,
      p1Score: game.p1Turn ? game.p1Score - investCost : null,
      p2Score: game.p1Turn ? null : game.p2Score - investCost,
      p1DiceScore: game.p1Turn ? game.p1DiceScore + 1 : null,
      p2DiceScore: game.p1Turn ? null : game.p2DiceScore + 1,
    ));
  }
}

class Attack implements Move<DiceBattle> {
  const Attack();

  @override
  String get description => 'attack';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    final rolls = game.p1Turn ? game.p1DiceScore : game.p2DiceScore;
    final toHit = game.p1Turn ? game.p2Score : game.p1Score;

    return game.roll
        .roll(Dice(sides: die.sides, rolls: rolls))
        .map((roll) => roll >= toHit)
        .condense()
        .map((hit) {
      if (hit) {
        return game.copyWith(
          p1Turn: !game.p1Turn,
          p1Score: game.p1Turn
              ? game.p1Score + game.p2DiceScore + attackPointWin
              : null,
          p2Score: game.p1Turn
              ? null
              : game.p2Score + game.p1DiceScore + attackPointWin,
          p1DiceScore: game.p1Turn ? null : game.p1DiceScore - 1,
          p2DiceScore: game.p1Turn ? game.p2DiceScore - 1 : null,
        );
      } else {
        return game.copyWith(
          p1Turn: !game.p1Turn,
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
  final random = Random();
  final expectiminimax = Expectiminimax<DiceBattle>(maxDepth: 12);

  while (true) {
	var game = startingGame;
    var turns = 0;
    while (game.score != 1.0 && game.score != -1.0) {
      turns++;
      final Move<DiceBattle> move;
      move = expectiminimax.chooseBest(game.getMoves(), game);
      if (move.description == 'attack') {
        print('turn $turns ${move.description}');
      }
      final chance = move.perform(game);
      final outcome = chance.pick(random.nextDouble());
      game = outcome.outcome;
    }

    print('turns $turns');
    print('p1: ${game.p1Score} / ${game.p1DiceScore}');
    print('p2: ${game.p2Score} / ${game.p2DiceScore}');
  }
}
