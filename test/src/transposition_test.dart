import 'package:dartnad0/src/expectiminimax.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/transposition.dart';
import 'package:test/test.dart';

void main() {
  test('Add first entry', () {
    final t = TranspositionTable<TestGame>(64);

    expect(
        t.scoreTransposition(TestGame(1), 1, -2, 2,
            (_, __, ___) => MoveScore(score: 1.0, moveIdx: null)),
        1.0);
  });

  test('Reuse first entry', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.5);
  });

  test('Dont use wrong hash entry', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    t.scoreTransposition(TestGame(2), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.6, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.5);

    expect(
        t.scoreTransposition(
            TestGame(2), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.6);
  });

  test('Dont use wrong hash entry with same modulus', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    t.scoreTransposition(TestGame(65), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.6, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.5);

    expect(
        t.scoreTransposition(
            TestGame(65), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.6);
  });

  test('Dont reuse entry with less work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 2, -2, 2,
            (_, __, ___) => MoveScore(score: 0.8, moveIdx: null)),
        0.8);
  });

  test('Reuse winning entry with less work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 1.0, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 2, -2, 2, (_, __, ___) => throw 'fail test'),
        1.0);
  });

  test('Reuse losing entry with less work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2, 2,
        (_, __, ___) => MoveScore(score: -1.0, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 2, -2, 2, (_, __, ___) => throw 'fail test'),
        -1.0);
  });

  test('Reuse entry with more work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.5);
  });

  test('Reuse entry with alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0, 0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -0.3, 0.2, (_, __, ___) => throw 'fail test'),
        -0.5);
  });

  test('Reuse entry with beta cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -0.8, 0.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -0.3, 0.2, (_, __, ___) => throw 'fail test'),
        0.5);
  });

  test('Dont reuse entry outside previous alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 1, -0.8, 0.5,
            (_, __, ___) => MoveScore(score: -0.6, moveIdx: null)),
        -0.6);
  });

  test('Dont reuse entry equal previous alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: 0.0, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 1, -0.8, 0.5,
            (_, __, ___) => MoveScore(score: -0.6, moveIdx: null)),
        -0.6);
  });

  test('Dont reuse entry outside previous beta cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: 0.6, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 1, 0.0, 0.8,
            (_, __, ___) => MoveScore(score: 0.6, moveIdx: null)),
        0.6);
  });

  test('Dont reuse entry equal previous beta cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 1, 0.0, 0.8,
            (_, __, ___) => MoveScore(score: 0.6, moveIdx: null)),
        0.6);
  });

  test('Reuse entry with beta and alpha cutoffs', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, -0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    t.scoreTransposition(TestGame(1), 1, 0.8, 2.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -0.9, -0.85, (_, __, ___) => throw 'fail test'),
        -0.5);

    expect(
        t.scoreTransposition(
            TestGame(1), 1, 0.9, 0.85, (_, __, ___) => throw 'fail test'),
        0.5);
  });

  test('Dont reuse entry with beta and alpha cutoffs', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, -0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    t.scoreTransposition(TestGame(1), 1, 0.8, 2.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1), 1, -0.7, 0.7,
            (_, __, ___) => MoveScore(score: 0.6, moveIdx: null)),
        0.6);
  });

  test('Reuse hash move with less work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, 2.0,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: 1));

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 2, -2.0, 2.0, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 1);
  });

  test('Reuse hash move with alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, -0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: 1));

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 1, -0.7, 0.7, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 1);
  });

  test('Reuse hash move with beta cutoffs', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, 0.8, 2.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: 1));

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 1, -0.7, 0.7, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 1);
  });

  test('Reuse hash move with beta and alpha cutoffs', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, -0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    t.scoreTransposition(TestGame(1), 1, 0.8, 2.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: 1));

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 1, -0.7, 0.7, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 1);
  });

  test('Set hash move then replace it', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1), 1, -2.0, 2.0,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: 1));

    t.scoreTransposition(TestGame(1), 2, -2.0, 2.0,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: 2));

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 3, -2.0, 2.0, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 2);
  });

  test('Set hash move then replace it recursive', () {
    final t = TranspositionTable<TestGame>(64);

    void setMoveOne() {
      t.scoreTransposition(TestGame(1), 1, -2.0, 2.0,
          (_, __, ___) => MoveScore(score: -0.5, moveIdx: 1));
    }

    t.scoreTransposition(TestGame(1), 2, -2.0, 2.0, (_, __, ___) {
      setMoveOne();
      return MoveScore(score: -0.5, moveIdx: 2);
    });

    int? moveIdx;
    t.scoreTransposition(TestGame(1), 3, -2.0, 2.0, (midx, __, ___) {
      moveIdx = midx;
      return MoveScore(score: 0.6, moveIdx: null);
    });

    expect(moveIdx, 2);
  });

  test('Set min then replace it recursive', () {
    final t = TranspositionTable<TestGame>(64);

    void setMin() {
      t.scoreTransposition(TestGame(1), 1, -0.1, 0.1,
          (_, __, ___) => MoveScore(score: 0.2, moveIdx: 1));
    }

    t.scoreTransposition(TestGame(1), 2, -0.1, 0.1, (_, __, ___) {
      setMin();
      return MoveScore(score: 0.3, moveIdx: 2);
    });

    // Min exceeds cutoff
    expect(
        t.scoreTransposition(
            TestGame(1), 2, -0.1, 0.2, (_, __, ___) => throw 'fail test'),
        0.3);

    // Min doesn't exceed cutoff, recompute.
    expect(
        t.scoreTransposition(TestGame(1), 2, -0.1, 0.5,
            (midx, __, ___) => MoveScore(score: 0.4, moveIdx: null)),
        0.4);
  });

  test('Set max then replace it recursive', () {
    final t = TranspositionTable<TestGame>(64);

    void setMax() {
      t.scoreTransposition(TestGame(1), 1, -0.1, 0.1,
          (_, __, ___) => MoveScore(score: -0.2, moveIdx: 1));
    }

    t.scoreTransposition(TestGame(1), 2, -0.1, 0.1, (_, __, ___) {
      setMax();
      return MoveScore(score: -0.3, moveIdx: 2);
    });

    // Max exceeds cutoff
    expect(
        t.scoreTransposition(
            TestGame(1), 2, -0.2, 0.1, (_, __, ___) => throw 'fail test'),
        -0.3);

    // Max doesn't exceed cutoff, recompute.
    expect(
        t.scoreTransposition(TestGame(1), 2, -0.5, 0.1,
            (midx, __, ___) => MoveScore(score: -0.4, moveIdx: null)),
        -0.4);
  });

  test('Set min and max recursive', () {
    final t = TranspositionTable<TestGame>(64);

    void setMax(TestGame game, void Function() andThen) {
      t.scoreTransposition(game, 1, 0.5, 2.0, (_, __, ___) {
        andThen();
        return MoveScore(score: 0.2, moveIdx: 1);
      });
    }

    void setMin(TestGame game, void Function() andThen) {
      t.scoreTransposition(game, 1, -2.0, -0.5, (_, __, ___) {
        andThen();
        return MoveScore(score: -0.2, moveIdx: 1);
      });
    }

    final game1 = TestGame(1);
    final game2 = TestGame(2);
    setMin(game1, () => setMax(game1, () {}));
    setMax(game2, () => setMin(game2, () {}));

    // Max exceeds cutoff
    expect(
        t.scoreTransposition(
            game1, 1, 0.5, 2.0, (_, __, ___) => throw 'fail test'),
        0.2);

    expect(
        t.scoreTransposition(
            game2, 1, 0.5, 2.0, (_, __, ___) => throw 'fail test'),
        0.2);

    // Min exceeds cutoff
    expect(
        t.scoreTransposition(
            game1, 1, -2.0, -0.5, (_, __, ___) => throw 'fail test'),
        -0.2);

    expect(
        t.scoreTransposition(
            game2, 1, -2.0, -0.5, (_, __, ___) => throw 'fail test'),
        -0.2);

    // Max doesn't exceed cutoff, recompute.
    expect(
        t.scoreTransposition(game1, 1, 0.0, 0.5,
            (midx, __, ___) => MoveScore(score: 0.1, moveIdx: null)),
        0.1);

    // Min doesn't exceed cutoff, recompute.
    expect(
        t.scoreTransposition(game2, 1, -0.5, 0.0,
            (midx, __, ___) => MoveScore(score: -0.1, moveIdx: null)),
        -0.1);
  });

  test('Set min and max recursive doesnt promote unequal work', () {
    final t = TranspositionTable<TestGame>(64);

    void setMax(TestGame game, int work, void Function() andThen) {
      t.scoreTransposition(game, work, 0.5, 2.0, (_, __, ___) {
        andThen();
        return MoveScore(score: 0.2, moveIdx: 1);
      });
    }

    void setMin(TestGame game, int work, void Function() andThen) {
      t.scoreTransposition(game, work, -2.0, -0.5, (_, __, ___) {
        andThen();
        return MoveScore(score: -0.2, moveIdx: 1);
      });
    }

    final game1 = TestGame(1);
    final game2 = TestGame(2);
    final game3 = TestGame(3);
    final game4 = TestGame(4);
    setMin(game1, 1, () => setMax(game1, 2, () {}));
    setMax(game2, 1, () => setMin(game2, 2, () {}));
    setMin(game3, 2, () => setMax(game3, 1, () {}));
    setMax(game4, 2, () => setMin(game4, 1, () {}));

    // Max cutoff is safe because it came from work 2
    // TODO: this should pass
    //expect(
    //    t.scoreTransposition(
    //        game1, 1, 0.5, 2.0, (_, __, ___) => throw 'fail test'),
    //    0.2);

    expect(
        t.scoreTransposition(
            game4, 1, 0.5, 2.0, (_, __, ___) => throw 'fail test'),
        0.2);

    // Min cutoff is safe because of always-write policy
    expect(
        t.scoreTransposition(
            game1, 1, -2.0, -0.5, (_, __, ___) => throw 'fail test'),
        -0.2);

    // Max cutoff is safe because of always-write policy
    expect(
        t.scoreTransposition(
            game2, 1, 2.0, 0.5, (_, __, ___) => throw 'fail test'),
        0.2);

    // Min cutoff is safe because it came from work 2
    // TODO: this should pass
    //expect(
    //    t.scoreTransposition(
    //        game2, 1, -2.0, -0.5, (_, __, ___) => throw 'fail test'),
    //    -0.2);

    expect(
        t.scoreTransposition(
            game3, 1, -2.0, -0.5, (_, __, ___) => throw 'fail test'),
        -0.2);

    // Max cutoff isn't safe because it came from work 1
    expect(
        t.scoreTransposition(game3, 1, 0.5, 2.0,
            (_, __, ___) => MoveScore(score: 0.3, moveIdx: null)),
        0.3);

    // Min cutoff isn't safe because it came from work 1
    expect(
        t.scoreTransposition(game1, 2, -2.0, -0.5,
            (_, __, ___) => MoveScore(score: -0.3, moveIdx: null)),
        -0.3);

    // Max cutoff isn't safe because it came from work 1
    expect(
        t.scoreTransposition(game2, 2, 0.5, 2.0,
            (_, __, ___) => MoveScore(score: 0.3, moveIdx: null)),
        0.3);

    // Min cutoff isn't safe because it came from work 1
    expect(
        t.scoreTransposition(game4, 1, -2.0, -0.5,
            (_, __, ___) => MoveScore(score: -0.3, moveIdx: null)),
        -0.3);
  });

  test('Always write policy', () {
    final t = TranspositionTable<TestGame>(64);

    for (int i = 0; i < 10; ++i) {
      final game = TestGame(i * 64);
      final score = i * 0.01;
      t.scoreTransposition(game, 1, -2, 2,
          (_, __, ___) => MoveScore(score: score, moveIdx: null));

      expect(
          t.scoreTransposition(
              game, 1, -2, 2, (_, __, ___) => throw 'fail test'),
          score);
    }
  });

  test('Keeps up to four with same modulus', () {
    final t = TranspositionTable<TestGame>(64);

    for (int i = 0; i < 4; ++i) {
      final game = TestGame(i * 64);
      final score = i * 0.01;
      t.scoreTransposition(game, 1, -2, 2,
          (_, __, ___) => MoveScore(score: score, moveIdx: null));
    }

    for (int i = 0; i < 4; ++i) {
      final game = TestGame(i * 64);
      final score = i * 0.01;
      expect(
          t.scoreTransposition(
              game, 1, -2, 2, (_, __, ___) => throw 'fail test'),
          score);
    }
  });

  test('Rewrite entry with least work', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(64), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.1, moveIdx: null));

    // least work
    t.scoreTransposition(TestGame(2 * 64), 1, -2, 2,
        (_, __, ___) => MoveScore(score: 0.2, moveIdx: 2));

    t.scoreTransposition(TestGame(3 * 64), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.3, moveIdx: null));

    t.scoreTransposition(TestGame(4 * 64), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.4, moveIdx: null));

    // Triggers rewrite of entry 2*64
    t.scoreTransposition(TestGame(5 * 64), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(64), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.1);

    expect(
        t.scoreTransposition(
            TestGame(3 * 64), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.3);

    expect(
        t.scoreTransposition(
            TestGame(4 * 64), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.4);

    expect(
        t.scoreTransposition(
            TestGame(5 * 64), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        0.5);

    expect(
        t.scoreTransposition(TestGame(2 * 64), 1, -2, 2, (moveIdx, __, ___) {
          expect(moveIdx, null);
          return MoveScore(score: 0.6, moveIdx: null);
        }),
        0.6);
  });

  test('Negamax inverts simple entry on store', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(
            TestGame(1), 1, -2, 2, (_, __, ___) => throw 'fail test'),
        -0.5);
  });

  test('Negamax inverts simple entry on retrieve', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: true), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: false), 1, -2, 2,
            (_, __, ___) => throw 'fail test'),
        -0.5);
  });

  test('Negamax doesnt invert simple entry on store then retrieve', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 2, -2, 2,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: false), 1, -2, 2,
            (_, __, ___) => throw 'fail test'),
        0.5);
  });

  test('Reuse negamax entry with alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 1, 0, 0.8,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    t.scoreTransposition(TestGame(2, isMaxing: true), 1, 0, 0.8,
        (_, __, ___) => MoveScore(score: -0.6, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: true), 1, -2.0, 0.3,
            (_, __, ___) => throw 'fail test'),
        0.5);

    expect(
        t.scoreTransposition(TestGame(2, isMaxing: false), 1, -2.0, 0.3,
            (_, __, ___) => throw 'fail test'),
        0.6);
  });

  test('Reuse negamax entry with beta cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 1, -0.8, 0.0,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    t.scoreTransposition(TestGame(2, isMaxing: true), 1, -0.8, 0.0,
        (_, __, ___) => MoveScore(score: 0.6, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: true), 1, -0.3, 2.0,
            (_, __, ___) => throw 'fail test'),
        -0.5);

    expect(
        t.scoreTransposition(TestGame(2, isMaxing: false), 1, -0.3, 2.0,
            (_, __, ___) => throw 'fail test'),
        -0.6);
  });

  test('Dont reuse entry outside previous alpha cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: -0.5, moveIdx: null));

    t.scoreTransposition(TestGame(2, isMaxing: true), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: -0.6, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: true), 1, -0.1, 0.7,
            (_, __, ___) => MoveScore(score: 0.65, moveIdx: null)),
        0.65);

    expect(
        t.scoreTransposition(TestGame(2, isMaxing: false), 1, -0.1, 0.7,
            (_, __, ___) => MoveScore(score: 0.65, moveIdx: null)),
        0.65);
  });

  test('Dont reuse entry outside previous beta cutoff', () {
    final t = TranspositionTable<TestGame>(64);

    t.scoreTransposition(TestGame(1, isMaxing: false), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: 0.5, moveIdx: null));

    t.scoreTransposition(TestGame(2, isMaxing: true), 1, 0.0, 0.5,
        (_, __, ___) => MoveScore(score: 0.6, moveIdx: null));

    expect(
        t.scoreTransposition(TestGame(1, isMaxing: true), 1, -0.8, 0.0,
            (_, __, ___) => MoveScore(score: -0.65, moveIdx: null)),
        -0.65);

    expect(
        t.scoreTransposition(TestGame(2, isMaxing: false), 1, -0.8, 0.0,
            (_, __, ___) => MoveScore(score: -0.65, moveIdx: null)),
        -0.65);
  });
}

class TestGame extends Game<TestGame> {
  TestGame(this.hashCode, {this.isMaxing = true});
  final int hashCode;
  final bool isMaxing;

  @override
  List<Move<TestGame>> getMoves() {
    throw UnimplementedError();
  }

  @override
  double get score => throw UnimplementedError();
}
