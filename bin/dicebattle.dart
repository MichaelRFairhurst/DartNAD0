import 'dart:math';
import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/dice.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/roll.dart';

const winningScore = 20;
const sides = 6;
const investCost = -1;
const maxScoreRoll = 4;

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
}

class Fortify implements Move<DiceBattle> {
  const Fortify();

  @override
  String get description => 'fortify';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    final singleRoll = game.roll
        .roll(Dice(sides: sides, rolls: 1))
        .map((r) => r <= maxScoreRoll ? r : 0)
        .condense();

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
        .roll(Dice(sides: sides, rolls: rolls))
        .map((roll) => roll >= toHit)
        .condense()
        .map((hit) {
      return game.copyWith(
        p1Turn: !game.p1Turn,
        p1DiceScore: hit && !game.p1Turn ? game.p1DiceScore - 1 : null,
        p2DiceScore: hit && game.p1Turn ? game.p2DiceScore - 1 : null,
      );
    });
  }
}

void main() {
  var game = DiceBattle(
    p1Turn: true,
    p1Score: 0,
    p1DiceScore: 1,
    p2Score: 0,
    p2DiceScore: 1,
    roll: Roll(),
  );
  final random = Random();

  var turns = 0;
  while (game.score != 1.0 && game.score != -1.0) {
	turns++;
	final Move<DiceBattle> move;
    move = Expectiminimax<DiceBattle>(maxDepth: 5)
        .chooseBest(game.getMoves(), game);
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

  main();
}
