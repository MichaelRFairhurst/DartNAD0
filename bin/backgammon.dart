import 'dart:math';
import 'package:collection/collection.dart';
import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/cli.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/dice.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/roll.dart';

final roll = Roll();

// "Checkers" (pieces) per player.
const numCheckers = 15;

// "Points" (spaces) per board.
const boardSize = 24;

// Starting position of checkers on the points.
const startingBoard = [
  -2,
  0,
  0,
  0,
  0,
  5,
  0,
  3,
  0,
  0,
  0,
  -5,
  5,
  0,
  0,
  0,
  -3,
  0,
  -5,
  0,
  0,
  0,
  0,
  2,
];

class Backgammon extends Game<Backgammon> {
  Backgammon({
    required this.player1,
    required this.p1Bar,
    required this.p2Bar,
    required this.die1,
    required this.die2,
    required this.die3,
    required this.die4,
    required this.points,
  });

  /// The points and how many checkers are on each. A zero in this list
  /// represents a point with no checkers. A positive number is the count
  /// of player 1's checkers, a negative number is player 2's checkers.
  final List<int> points;

  /// Is it player 1's turn?
  final bool player1;

  /// How many checkers are on the bar for player 1.
  final int p1Bar;

  /// How many checkers are on the bar for player 1.
  final int p2Bar;

  /// The four dice rolls, set to 0 upon use. This is clunky, but it is the
  /// best way to have an inlined array of 4 in Dart.
  final int die1;
  final int die2;
  final int die3;
  final int die4;

  @override
  List<Move<Backgammon>> getMoves() {
    // Victory condition
    if (!points.any((point) => point < 0) ||
        !points.any((point) => point > 0)) {
      return const [];
    }

    if (die1 == 0 && die2 == 0 && die3 == 0 && die4 == 0) {
      return const [RollFirst()];
    }

    if (player1 && p1Bar > 0 || !player1 && p2Bar > 0) {
      return getEnterMoves();
    }

    int highestChecker = player1
        ? points.lastIndexWhere((p) => p > 0)
        : boardSize - points.indexWhere((p) => p < 0);

    bool exactBearOffAllowed = highestChecker <= 6;
    bool inexactBearOffAllowed = exactBearOffAllowed &&
        highestChecker > max(die1, max(die2, max(die3, die4)));

    final results = <Move<Backgammon>>[];
    int myChecker = player1 ? 1 : -1;
    final hasMyCheckers = player1
        ? (int pointVal) => pointVal > 0
        : (int pointVal) => pointVal < 0;

    var point = player1 ? boardSize - 1 : 0;
    final isMyEndOfBoard =
        player1 ? (int point) => point < 0 : (int point) => point >= boardSize;
    final myDirection = player1 ? -1 : 1;

    int checkers = 0;
    while (!isMyEndOfBoard(point)) {
      if (!hasMyCheckers(points[point])) {
        point += myDirection;
        continue;
      }

      final moveRoll1 = tryMoveChecker(
          point: point,
          roll: die1,
          exactBearOffAllowed: exactBearOffAllowed,
          inexactBearOffAllowed: inexactBearOffAllowed);
      final moveRoll2 = tryMoveChecker(
          point: point,
          roll: die2,
          exactBearOffAllowed: exactBearOffAllowed,
          inexactBearOffAllowed: inexactBearOffAllowed);
      final moveRoll3 = tryMoveChecker(
          point: point,
          roll: die3,
          exactBearOffAllowed: exactBearOffAllowed,
          inexactBearOffAllowed: inexactBearOffAllowed);
      final moveRoll4 = tryMoveChecker(
          point: point,
          roll: die4,
          exactBearOffAllowed: exactBearOffAllowed,
          inexactBearOffAllowed: inexactBearOffAllowed);

      if (moveRoll1 != null) {
        results.add(moveRoll1);
      }
      if (moveRoll2 != null) {
        results.add(moveRoll2);
      }
      if (moveRoll3 != null) {
        results.add(moveRoll3);
      }
      if (moveRoll4 != null) {
        results.add(moveRoll4);
      }

      checkers += points[point] ~/ myChecker;
      if (checkers > numCheckers) {
        //break;
      }

      point += myDirection;
    }

    if (results.isEmpty) {
      return const [AbandonTurn()];
    }

    return results;
  }

  MoveChecker? tryMoveChecker(
      {required int point,
      required int roll,
      required bool exactBearOffAllowed,
      required bool inexactBearOffAllowed}) {
    if (roll == 0) {
      return null;
    }

    final targetPoint = player1 ? point - roll : point + roll;
    // bearing off
    if (targetPoint == -1 || targetPoint == boardSize) {
      if (exactBearOffAllowed) {
        // TODO: cache these instances
        return MoveChecker(point: point, roll: roll);
      } else {
        return null;
      }
    } else if (targetPoint < 0 || targetPoint >= boardSize) {
      if (inexactBearOffAllowed) {
        // TODO: cache these instances
        return MoveChecker(point: point, roll: roll);
      } else {
        return null;
      }
    }

    final targetVal = points[targetPoint];

    // Check the point is open.
    if (targetVal == 5 || targetVal == -5) {
      // Point is full.
      return null;
    } else if (player1 && targetVal < -1) {
      // Point has more than one opponent checker.
      return null;
    } else if (!player1 && targetVal > 1) {
      // Point has more than one opponent checker.
      return null;
    }

    // Free to move!
    return MoveChecker(point: point, roll: roll);
  }

  List<Move<Backgammon>> getEnterMoves() {
    final enter1 = tryEnter(die1);
    final enter2 = tryEnter(die2);
    final enter3 = tryEnter(die3);
    final enter4 = tryEnter(die4);
    if (enter1 == null && enter2 == null && enter3 == null && enter4 == null) {
      return [const AbandonTurn()];
    }

    return [
      if (enter1 != null) enter1,
      if (enter2 != null) enter2,
      if (enter3 != null) enter3,
      if (enter4 != null) enter4,
    ];
  }

  Enter? tryEnter(int roll) {
    if (roll == 0) {
      return null;
    }

    final target = player1 ? roll : boardSize - roll;

    if (points[target] == 5 || points[target] == -5) {
      return null;
    } else if (player1 && points[target] < -1) {
      return null;
    } else if (!player1 && points[target] > 1) {
      return null;
    }

    const enters = [
      Enter(1),
      Enter(2),
      Enter(3),
      Enter(4),
      Enter(5),
      Enter(6),
    ];

    return enters[roll - 1];
  }

  @override
  bool get isMaxing => player1;

  /// Give each player 1 point for each checker for each space it has traveled
  /// towards home. Checkers on the bar count as 0 and bear-offs as 24.
  @override
  double get score {
    // Co
    var p1Score = 0.0;
    var p2Score = 0.0;
    // Track checkers we've seen so we can infer bear-off count.
    var p1Checkers = numCheckers - p1Bar;
    var p2Checkers = numCheckers - p2Bar;
    for (int i = 0; i < boardSize; ++i) {
      // For each checker, give it one point for each space it has traveled
      // towards home, and track that it hasn't born off.
      if (points[i] > 0) {
        p1Score += points[i] * (boardSize - i);
        p1Checkers -= points[i];
      } else if (points[i] < 0) {
        p2Checkers += -points[i];
        p2Score -= -points[i] * i;
      }
    }

    // Add points for bearing off.
    p1Score += p1Checkers * boardSize;
    p2Score += p2Checkers * boardSize;

    const maxScore = numCheckers * boardSize;

    if (p1Checkers == numCheckers) {
      return 1.0;
    } else if (p2Checkers == numCheckers) {
      return -1.0;
    } else {
      return p1Score / maxScore - p2Score / maxScore;
    }
  }

  @override
  String toString() {
    List<String> lines = List.filled(11, '-' * 12, growable: true);

    for (int i = 12; i < boardSize; ++i) {
      for (int c = 0; c < 6; ++c) {
        if (points[i] < -c) {
          lines[c] = lines[c].replaceRange(i - 12, i - 11, 'x');
        } else if (points[i] > c) {
          lines[c] = lines[c].replaceRange(i - 12, i - 11, 'o');
        }
      }
    }

    lines[5] = '';

    for (int i = 11; i >= 0; --i) {
      for (int c = 0; c < 6; ++c) {
        if (points[i] < -c) {
          lines[10 - c] = lines[10 - c].replaceRange(11 - i, 12 - i, 'x');
        } else if (points[i] > c) {
          lines[10 - c] = lines[10 - c].replaceRange(11 - i, 12 - i, 'o');
        }
      }
    }

    final dice = [
      if (this.die1 != 0) die1,
      if (this.die2 != 0) die2,
      if (this.die3 != 0) die3,
      if (this.die4 != 0) die4,
    ];

    lines.add('rolls: ${dice.join(",")}');
    lines.add('onBar: $p1Bar for p1, $p2Bar for p2.');
    final turnText = player1 ? 'Os turn:\n' : 'Xs turn:\n';

    return turnText + lines.join('\n');
  }

  Backgammon copyWith({
    List<int>? points,
    bool? player1,
    int? p1Bar,
    int? p2Bar,
    int? die1,
    int? die2,
    int? die3,
    int? die4,
  }) =>
      Backgammon(
        points: points ?? this.points,
        player1: player1 ?? this.player1,
        p1Bar: p1Bar ?? this.p1Bar,
        p2Bar: p2Bar ?? this.p2Bar,
        die1: die1 ?? this.die1,
        die2: die2 ?? this.die2,
        die3: die3 ?? this.die3,
        die4: die4 ?? this.die4,
      );

  @override
  int get hashCode => Object.hashAll(
      [player1, p1Bar, p2Bar, die1, die2, die3, die4, ...points]);

  bool operator ==(Object? other) =>
      other is Backgammon &&
      other.player1 == player1 &&
      other.p1Bar == p1Bar &&
      other.p2Bar == p2Bar &&
      other.die1 == die1 &&
      other.die2 == die2 &&
      other.die3 == die3 &&
      other.die4 == die4 &&
      ListEquality().equals(other.points, points);
}

class RollFirst implements Move<Backgammon> {
  const RollFirst();

  @override
  String get description => 'roll to start turn';

  @override
  Chance<Backgammon> perform(Backgammon game) {
    final d6 = roll.roll(r1d6);
    return d6.mergeWith(d6, (a, b) {
      return min(a, b) * 7 + max(a, b);
    }).map((v) {
      int a = v % 7;
      int b = v ~/ 7;
      assert(a > 0 && a < 7);
      assert(b > 0 && b < 7);

      if (a == b) {
        return game.copyWith(
          die1: a,
          die2: a,
          die3: a,
          die4: a,
        );
      } else {
        return game.copyWith(
          die1: a,
          die2: b,
        );
      }
    });
  }
}

class MoveChecker implements Move<Backgammon> {
  MoveChecker({
    required this.point,
    required this.roll,
  });

  final int point;
  final int roll;

  @override
  String get description => 'move checker on point $point by $roll spaces';

  @override
  Chance<Backgammon> perform(Backgammon game) {
    final points = List<int>.from(game.points, growable: false);
    final bool hitBlot;

    final checkerInt = game.player1 ? 1 : -1;
    final targetPoint = game.player1 ? point - roll : point + roll;

    points[point] -= checkerInt;

    if (targetPoint >= 0 && targetPoint < boardSize) {
      points[targetPoint] += checkerInt;

      if (points[targetPoint] == 0) {
        points[targetPoint] = checkerInt;
        hitBlot = true;
      } else {
        hitBlot = false;
      }
    } else {
      hitBlot = false;
    }

    var die1 = game.die1;
    var die2 = game.die2;
    var die3 = game.die3;
    var die4 = game.die4;

    if (die4 == roll) {
      die4 = 0;
    } else if (die3 == roll) {
      die3 = 0;
    } else if (die2 == roll) {
      die2 = 0;
    } else {
      assert(die1 == roll);
      die1 = 0;
    }

    final switchTurns = die1 == 0 && die2 == 0 && die3 == 0 && die4 == 0;

    return Chance<Backgammon>.just(game.copyWith(
      points: points,
      player1: switchTurns ? !game.player1 : game.player1,
      die1: die1,
      die2: die2,
      die3: die3,
      die4: die4,
      p1Bar: !game.player1 && hitBlot ? game.p1Bar + 1 : null,
      p2Bar: game.player1 && hitBlot ? game.p2Bar + 1 : null,
    ));
  }

  @override
  bool operator ==(Object? other) =>
      other is MoveChecker && other.point == point && other.roll == roll;

  @override
  int get hashCode => roll * boardSize + point;
}

class Enter implements Move<Backgammon> {
  const Enter(this.roll);

  final int roll;

  @override
  String get description => 'Player enters on a $roll';

  @override
  Chance<Backgammon> perform(Backgammon game) {
    final points = List<int>.from(game.points, growable: false);
    final bool hitBlot;

    final checkerInt = game.player1 ? 1 : -1;
    final targetPoint = game.player1 ? boardSize - roll : roll;

    if (targetPoint >= 0 && targetPoint < boardSize) {
      points[targetPoint] += checkerInt;

      if (points[targetPoint] == 0) {
        points[targetPoint] = checkerInt;
        hitBlot = true;
      } else {
        hitBlot = false;
      }
    } else {
      hitBlot = false;
    }

    var die1 = game.die1;
    var die2 = game.die2;
    var die3 = game.die3;
    var die4 = game.die4;

    if (die4 == roll) {
      die4 = 0;
    } else if (die3 == roll) {
      die3 = 0;
    } else if (die2 == roll) {
      die2 = 0;
    } else {
      assert(die1 == roll);
      die1 = 0;
    }

    return Chance<Backgammon>.just(game.copyWith(
      player1: !game.player1,
      points: points,
      die1: die1,
      die2: die2,
      die3: die3,
      die4: die4,
      p1Bar: game.player1 ? game.p1Bar - 1 : (hitBlot ? game.p1Bar + 1 : null),
      p2Bar: !game.player1 ? game.p2Bar - 1 : (hitBlot ? game.p2Bar + 1 : null),
    ));
  }

  @override
  bool operator ==(Object? other) => other is Enter && other.roll == roll;

  @override
  int get hashCode => roll;
}

class AbandonTurn implements Move<Backgammon> {
  const AbandonTurn();

  @override
  String get description => 'Player abandons turn';

  @override
  Chance<Backgammon> perform(Backgammon game) =>
      Chance<Backgammon>.just(game.copyWith(
        player1: !game.player1,
        die1: 0,
        die2: 0,
        die3: 0,
        die4: 0,
      ));
}

void main(List<String> args) {
  CliTools<Backgammon>(
    defaultConfig: ExpectiminimaxConfig(
      maxDepth: 10,
    ),
    startingGame: Backgammon(
      points: startingBoard,
      player1: true,
      p1Bar: 0,
      p2Bar: 0,
      die1: 0,
      die2: 0,
      die3: 0,
      die4: 0,
    ),
  ).run(args);
}
