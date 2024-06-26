import 'dart:math';

import 'package:dartnad0/src/chance.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/mcts.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/time_control.dart';
import 'package:test/test.dart';

void main() {
  test('test move node get first child', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ]
      ]),
      0,
    );

    expect(node.child, isNull);
    final child = node.getChild(0);

    expect(node.child, child);
    expect(node.child?.sibling, isNull);
    expect(node.child?.edgeIdx, 0);
  });

  test('test move node get first child is idempotent', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ]
      ]),
      0,
    );

    expect(node.child, isNull);
    final child = node.getChild(0);
    final childAgain = node.getChild(0);

    expect(child, childAgain);
    expect(node.child, child);
    expect(node.child?.sibling, isNull);
    expect(node.child?.edgeIdx, 0);
  });

  test('test move node get child 1 first', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
      ]),
      0,
    );

    expect(node.child, isNull);
    final child = node.getChild(1);

    expect(node.child, child);
    expect(node.child?.edgeIdx, 1);
  });

  test('test move node get child 1 first is idempotent', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
      ]),
      0,
    );

    expect(node.child, isNull);
    final child = node.getChild(1);
    final childAgain = node.getChild(1);

    expect(child, childAgain);
    expect(node.child, child);
    expect(node.child?.edgeIdx, 1);
  });

  test('test move node get child 0 then 1', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
      ]),
      0,
    );

    node.getChild(0);
    node.getChild(1);

    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling, isNull);
  });

  test('test move node get child 0 then 1 is idempotent', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
      ]),
      0,
    );

    final c01 = node.getChild(0);
    final c11 = node.getChild(1);
    final c02 = node.getChild(0);
    final c12 = node.getChild(1);

    expect(c01, c02);
    expect(c11, c12);
    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling, isNull);
  });

  test('test move node get child 0 then 1 then 2', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
        [
          TestGame([]),
        ],
      ]),
      0,
    );

    node.getChild(0);
    node.getChild(1);
    node.getChild(2);

    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling?.edgeIdx, 2);
    expect(node.child?.sibling?.sibling?.sibling, isNull);
  });

  test('test chance node get first child', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>.just(TestGame([])),
    );

    expect(node.child, isNull);
    final child = node.getChild(0);

    expect(node.child, child);
    expect(node.child?.sibling, isNull);
    expect(node.child?.edgeIdx, 0);
  });

  test('test chance node get first child is idempotent', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>.just(TestGame([])),
    );

    expect(node.child, isNull);
    final child = node.getChild(0);
    final childAgain = node.getChild(0);

    expect(child, childAgain);
    expect(node.child, child);
    expect(node.child?.sibling, isNull);
    expect(node.child?.edgeIdx, 0);
  });

  test('test move node get child 1 first', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>(possibilities: [
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
      ]),
    );

    expect(node.child, isNull);
    final child = node.getChild(1);

    expect(node.child, child);
    expect(node.child?.edgeIdx, 1);
  });

  test('test move node get child 1 first is idempotent', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>(possibilities: [
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
      ]),
    );

    expect(node.child, isNull);
    final child = node.getChild(1);
    final childAgain = node.getChild(1);

    expect(child, childAgain);
    expect(node.child, child);
    expect(node.child?.edgeIdx, 1);
    expect(node.child?.sibling, isNull);
  });

  test('test move node get child 0 then 1', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>(possibilities: [
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
      ]),
    );

    node.getChild(0);
    node.getChild(1);

    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling, isNull);
  });

  test('test move node get child 0 then 1 is idempotent', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>(possibilities: [
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 0.5,
          outcome: TestGame([]),
        ),
      ]),
    );

    final c01 = node.getChild(0);
    final c11 = node.getChild(1);
    final c02 = node.getChild(0);
    final c12 = node.getChild(1);

    expect(c01, c02);
    expect(c11, c12);
    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling, isNull);
  });

  test('test move node get child 0 then 1 then 2', () {
    final node = MctsRandomNode(
      TestGame([]),
      0,
      Chance<TestGame>(possibilities: [
        Possibility(
          probability: 1 / 3,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 1 / 3,
          outcome: TestGame([]),
        ),
        Possibility(
          probability: 1 / 3,
          outcome: TestGame([]),
        ),
      ]),
    );

    node.getChild(0);
    node.getChild(1);
    node.getChild(2);

    expect(node.child?.edgeIdx, 0);
    expect(node.child?.sibling?.edgeIdx, 1);
    expect(node.child?.sibling?.sibling?.edgeIdx, 2);
    expect(node.child?.sibling?.sibling?.sibling, isNull);
  });

  test('test move node starting values', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    expect(node.simulations, 0);
    expect(node.q, 0);
  });

  test('test move node set q first time', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);
    expect(node.q, 0.5);
  });

  test('test move node set q twice averages', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);
    node.simulations++;
    node.backpropagate(1.0);
    expect(node.q, 0.75);
  });

  test('test move node set q three times averages', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    node.simulations++;
    node.backpropagate(-0.25);
    node.simulations++;
    node.backpropagate(-0.5);
    node.simulations++;
    node.backpropagate(0.0);
    expect(node.q, -0.25);
  });

  test('test move node set q minning node negates', () {
    final node = MctsMoveNode(
      TestGame([], isMaxing: false),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);
    expect(node.q, -0.5);
  });

  test('test move node set q minning node negates twice', () {
    final node = MctsMoveNode(
      TestGame([], isMaxing: false),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);
    node.simulations++;
    node.backpropagate(1.0);
    expect(node.q, -0.75);
  });

  test('test move node get uct no simulations infinity', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    final uct = node.scoreForSelect(1, 1.0, 0.0);

    expect(uct, double.infinity);
  });

  test('test move node get uct only one simulation', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);

    // one parent simulations, expect q + 0
    expect(node.scoreForSelect(1, 1.41, 0.0) - 1, equals(0.5));
    // two parent simulations, expect q + cUct * 0.832...
    expect(node.scoreForSelect(2, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 0.832, 0.001));
    // three parent simulations, expect q + cUct * 1.048...
    expect(node.scoreForSelect(3, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 1.048, 0.001));
    // four parent simulations, expect q + cUct * 1.177...
    expect(node.scoreForSelect(4, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 1.177, 0.001));
  });

  test('test move node get uct two simulations', () {
    final node = MctsMoveNode(
      TestGame([]),
      0,
    );

    node.simulations++;
    node.backpropagate(0.5);
    node.simulations++;
    node.backpropagate(0.5);

    // two parent simulations, expect q + cUct * 0.588...
    expect(node.scoreForSelect(2, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 0.588, 0.001));
    // three parent simulations, expect q + cUct * 0.741...
    expect(node.scoreForSelect(3, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 0.741, 0.001));
    // four parent simulations, expect q + cUct * 0.832...
    expect(node.scoreForSelect(4, 1.41, 0.0) - 1,
        closeTo(0.5 + 1.41 * 0.832, 0.001));
  });

  test('test move node get puct no simulations', () {
    final node = MctsMoveNode(
      TestGame([], score: 0.5),
      0,
    );

    // one parent simulations, expect (score + 1) * 1
    expect(node.scoreForSelect(1, 0.0, 1.0), equals((0.5 + 1) + 1));
    // two parent simulations, expect (score + 1) * 1.414...
    expect(node.scoreForSelect(2, 0.0, 1.0) - 1, closeTo(1.5 * 1.414, 0.001));
    // three parent simulations, expect (score + 1) * 1.732...
    expect(node.scoreForSelect(3, 0.0, 1.0) - 1, closeTo(1.5 * 1.732, 0.001));
    // four parent simulations, expect (score + 1) * 2...
    expect(node.scoreForSelect(4, 0.0, 1.0) - 1, equals(1.5 * 2));
  });

  test('test move node get puct only one simulation', () {
    final node = MctsMoveNode(
      TestGame([], score: 0.5),
      0,
    );

    node.simulations++;
    node.backpropagate(0.3);

    // one parent simulations, expect q + (score + 1) * 0.5
    expect(
      node.scoreForSelect(1, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.5, 0.001),
    );
    // two parent simulations, expect q + (score + 1) * 0.707...
    expect(
      node.scoreForSelect(2, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.707, 0.001),
    );
    // three parent simulations, expect q + (score + 1) * 0.866...
    expect(
      node.scoreForSelect(3, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.866, 0.001),
    );
    // four parent simulations, expect q + (score + 1) * 1...
    expect(
      node.scoreForSelect(4, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 1, 0.001),
    );
  });

  test('test move node get puct two simulations', () {
    final node = MctsMoveNode(
      TestGame([], score: 0.5),
      0,
    );

    node.simulations++;
    node.backpropagate(0.2);
    node.simulations++;
    node.backpropagate(0.4);

    // one parent simulations, expect q + (score + 1) * 0.333
    expect(
      node.scoreForSelect(1, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.333, 0.001),
    );
    // two parent simulations, expect q + (score + 1) * 0.471...
    expect(
      node.scoreForSelect(2, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.471, 0.001),
    );
    // three parent simulations, expect q + (score + 1) * 0.577...
    expect(
      node.scoreForSelect(3, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.577, 0.001),
    );
    // four parent simulations, expect q + (score + 1) * 0.666...
    expect(
      node.scoreForSelect(4, 0.0, 1.0) - 1,
      closeTo(0.3 + 1.5 * 0.666, 0.001),
    );
  });

  MctsConfig testConfig({
    double cUct = 0.0,
    double cpUct = 0.0,
  }) =>
      MctsConfig(
        maxTime: Duration.zero,
        maxDepth: 1,
        expandDepth: -1,
        maxPlayouts: -1,
        cUct: cUct,
        cPuct: cpUct,
      );

  test('test uct select all nodes equal', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([])],
        [TestGame([])],
      ]),
      0,
    );

    node.simulations++;

    expect(Random(0).nextInt(2), 1);
    expect(node.select(Random(0), testConfig(cUct: 1.41)).edgeIdx, 1);
  });

  test('test uct select ignores score', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.1)],
        [TestGame([], score: 0.9)],
      ]),
      0,
    );

    node.simulations++;

    expect(Random(0).nextInt(2), 1);
    expect(node.select(Random(0), testConfig(cUct: 1.41)).edgeIdx, 1);
  });

  test('test puct selects node by best score', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.4)],
        [TestGame([], score: 0.6)],
        [TestGame([], score: 0.5)],
      ]),
      0,
    );

    node.simulations++;

    expect(node.select(Random(), testConfig(cpUct: 1.0)).edgeIdx, 1);
  });

  test('test puct selects node by best expected value', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.0), TestGame([], score: 1.0)],
        [TestGame([], score: 1.0), TestGame([], score: 0.0)],
        [TestGame([], score: 0.6), TestGame([], score: 0.5)],
        [TestGame([], score: 0.4), TestGame([], score: 0.3)],
      ]),
      0,
    );

    node.simulations++;

    expect(node.select(Random(), testConfig(cpUct: 1.0)).edgeIdx, 2);
  });

  test('test expand, uct style', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
        ],
        [
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
        ],
      ]),
      0,
    );

    final mcts = Mcts<TestGame>(Random(0), testConfig(cUct: 1.0));
    mcts.timeControl =
        AbsoluteTimeControl(DateTime.now().add(const Duration(hours: 1)));
    final score = mcts.expand(node, 10, 10);

    MctsNode<TestGame, dynamic> child = node;
    while (!child.isTerminal) {
      expect(child.simulations, equals(1));
      expect(child.child, isNotNull);
      expect(child.sibling, isNull);
      expect(child.q, equals(score));
      child = child.child!;
    }

    expect(child.isTerminal, isTrue);
    expect(child.simulations, equals(0));
  });

  test('test expand, puct style', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.4), TestGame([], score: 0.6)],
        [TestGame([], score: 0.8), TestGame([], score: 0.6)],
      ]),
      0,
    );

    final mcts = Mcts<TestGame>(Random(), testConfig(cpUct: 1.0));
    mcts.timeControl =
        AbsoluteTimeControl(DateTime.now().add(const Duration(hours: 1)));
    mcts.expand(node, 10, 1);

    expect(node.simulations, equals(1));
    expect(node.child, isNotNull);
    expect(node.child!.simulations, equals(0));
    expect(node.child!.child, isNull);
    expect(node.child!.sibling, isNotNull);
    expect(node.q, closeTo(0.7, 0.0001));

    var child = node.child;
    while (child != null) {
      expect(child.simulations, equals(0));
      expect(child.child, isNull);
      expect(child.q, equals(0));
      child = child.sibling;
    }
  });

  test('test expand uct max expand depth of 2', () {
    final node = MctsMoveNode(
      TestGame([
        [
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
        ],
        [
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
          TestGame([
            [TestGame([]), TestGame([])],
          ]),
        ],
      ]),
      0,
    );

    final mcts = Mcts<TestGame>(Random(0), testConfig(cUct: 1.0));
    mcts.timeControl =
        AbsoluteTimeControl(DateTime.now().add(const Duration(hours: 1)));
    final score = mcts.expand(node, 10, 2);

    MctsNode<TestGame, dynamic> child = node;
    for (int depth = 0; depth < 3; ++depth) {
      expect(child.simulations, equals(1));
      expect(child.child, isNotNull);
      expect(child.sibling, isNull);
      expect(child.q, equals(score));
      child = child.child!;
    }

    expect(child.isTerminal, isFalse);
    expect(child.simulations, equals(0));
    expect(child.child, isNull);
  });

  test('test expand, puct style', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.4), TestGame([], score: 0.6)],
        [TestGame([], score: 0.8), TestGame([], score: 0.6)],
      ]),
      0,
    );

    final mcts = Mcts<TestGame>(Random(), testConfig(cpUct: 1.0));
    mcts.timeControl =
        AbsoluteTimeControl(DateTime.now().add(const Duration(hours: 1)));
    mcts.expand(node, 10, 1);

    expect(node.simulations, equals(1));
    expect(node.child, isNotNull);
    expect(node.child!.simulations, equals(0));
    expect(node.child!.child, isNull);
    expect(node.child!.sibling, isNotNull);
    expect(node.q, closeTo(0.7, 0.0001));

    var child = node.child;
    while (child != null) {
      expect(child.simulations, equals(0));
      expect(child.child, isNull);
      expect(child.q, equals(0));
      child = child.sibling;
    }
  });

  test('test expand, puct style but expand depth of 2', () {
    final node = MctsMoveNode(
      TestGame([
        [TestGame([], score: 0.4), TestGame([], score: 0.6)],
        [
          TestGame([], score: 0.6),
          TestGame([
            [
              TestGame([], score: 0.95),
              TestGame([], score: 0.85),
            ],
          ], score: 0.8),
        ],
      ]),
      0,
    );

    final mcts = Mcts<TestGame>(Random(0), testConfig(cpUct: 1.0));
    mcts.timeControl =
        AbsoluteTimeControl(DateTime.now().add(const Duration(hours: 1)));
    mcts.expand(node, 10, 2);

    expect(node.simulations, equals(1));
    expect(node.child, isNotNull);
    expect(node.child!.simulations, equals(0));
    expect(node.child!.child, isNull);
    expect(node.child!.sibling, isNotNull);
    expect(node.q, closeTo(0.9, 0.001));

    {
      // pUCT scoring expands all immediate children to 1 depth
      var child = node.child;
      while (child != null) {
        if (child.edgeIdx != 1) {
          expect(child.simulations, equals(0));
          expect(child.child, isNull);
          expect(child.q, equals(0));
        }
        child = child.sibling;
      }
    }

    final expanded = node.getChild(1);
    expect(expanded.simulations, equals(1));
    expect(expanded.child, isNotNull);
    expect(expanded.child!.simulations, equals(1));
    expect(expanded.child!.child, isNotNull);
    expect(expanded.child!.sibling, isNull);
    expect(expanded.q, closeTo(0.9, 0.0001));

    {
      // All of the expanded's children were scored, but not visited.
      // Immediate child is a random node. 2nd child is the move node.
      var child = expanded.child!.child;
      expect(child, isNotNull);
      while (child != null) {
        expect(child.simulations, equals(0));
        expect(child.child, isNull);
        expect(child.q, equals(0));
        child = child.sibling;
      }
    }
  });
}

class TestGame extends Game<TestGame> {
  final List<List<TestGame>> children;

  final double score;
  final bool isMaxing;

  TestGame(this.children, {this.score = 0.0, this.isMaxing = true});

  @override
  List<Move<TestGame>> getMoves() =>
      children.map((games) => TestMove(games)).toList();
}

class TestMove extends Move<TestGame> {
  final Chance<TestGame> chance;

  TestMove(List<TestGame> games)
      : chance = Chance<TestGame>(
          possibilities: games.map(
            (g) => Possibility<TestGame>(
              probability: 1 / games.length,
              outcome: g,
            ),
          ),
        );

  @override
  String get description => 'test move';

  @override
  Chance<TestGame> perform(TestGame game) => chance;
}
