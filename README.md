# Dart expectiminimax implementation

A version of minimax that allows for random events, coded in dart.

Note that expectiminimax is often much slower than minimax as it cannot leverage
alpha/beta pruning nearly as effectively. In the future I would like to
parallelize this, etc., and support parallelized MCTS too.

Mildy optimized, and comes with prebuilt command line tools, use for your own
fun!

## Current features

- transposition tables
- minimax-style alpha-beta pruning (for deterministic nodes)
- \*-minimax (alpha beta pruning on CHANCE nodes)
- move ordering (based on best move stored in transition tables)
- killer move heuristic

## TODO

- '\*-minimax2' pruning (probing pass on CHANCE descendents): implemented but
  does not seem to perform well currently.
- Iterative deepening: implemented but not meeting requirements to perform well
  currentl.
- Concurrency: will be hard to do anything like lazy SMP in Dart. We could
  easily thread on CHANCE nodes, however, this strategy could backfire if we
  can't share the transposition table.
- Quiescence search (necessary for certain games to avoid horizon problems,
  find good move orderings in iterative deepening).
- Reversible games: Reduce allocation & GC overhead by using mutable game
  objects and making/unmaking moves
- Developer features: Stuff like building in ways to play AIs against each
  other, perft(), and benchmarking improvements.
- MCTS. It aint expectiminimax, but it is a better choice for some games.
- Late move reductions
- Support roll-to-move style games more naturally
- Configurable search options
- Principle-Variation search

## Usage

First we define how the game moves and progresses.

### Game definition

Create your `Game`. This should generally be an immutable object.

```dart
class DiceBattle extends Game<DiceBattle> {
  DiceBattle({
    required this.p1Turn,
    required this.p1Score,
    required this.p1DiceScore,
    required this.p2Score,
    required this.p2DiceScore,
  });

  final bool p1Turn;
  final int p1Score;
  final int p1DiceScore;
  final int p2Score;
  final int p2DiceScore;

  // ...
```

#### Score Game States

Next, define how a game state is scored, and whether the engine should max or
min that score. In general, the score should be a positive when player 1 is
winning and negative when player 1 is winning. In this case, the game is maxing
on player 1's turn and minning on player 2's turn.

```dart
class DiceBattle extends Game<DiceBattle> {
  // ...

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

  // ...
}
```

Games should be scored between the values `1.0` and `-1.0`, as shown here.

You may implement any heuristic to compute a score. The algorithm will seek to
minimize and maximize this score. A simple heuristic can often be less likely to
reward poor play, but requires more search depth to accurately evaluate a
player's position.

Your game also needs a hash function to be able to take advantage of
transposition tables.

```dart
class DiceBattle extends Game<DiceBattle> {
  // ...
  int get hashCode => Object.hashAll([p1Score, p2Score, ...]);
  // ...
}
```

#### Define Game Moves

Define the `Move`s for your game:

```dart
class DiceBattle extends Game<DiceBattle> {
  // ...
  @override
  List<Move<DiceBattle>> getMoves() {
    return [
	  // ...
	  Invest(),
	  // ...
	];
  }
  // ...
}

class Invest implements Move<DiceBattle> {
  const Invest();

  @override
  String get description => 'invest';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    // TODO: implement this
  }
}
```

Make sure your game returns no moves when there is a winner:

```dart
  @override
  List<Move<DiceBattle>> getMoves() {
	if (p1Score >= 20 || p2Score >= 20) {
	  return const [];
	}

    // ...
  }
```

Now we must implement our `Move` class behavior, using `Chance` and `Dice` etc.

### Chance, Dice, Etc

All moves return a `Chance` object which represent the various probabilistic
outcomes from a player action.

When a `Move` is deterministic (as opposed to probabilistic), you can use the
constructor `Chance.just(x)` to declare that the game progresses to a single,
certain state.

```
class ScoreOnePoint implements Move<DiceBattle> {
  const ScoreOnePoint();

  @override
  String get description => 'score one point';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
    return Chance<DiceBattle>.just(game.copyWith(
      p1Turn: !game.p1Turn,
      p1Score: game.p1Turn ? game.p1Score + 1 : null,
      p2Score: game.p1Turn ? null : game.p2Score  + 1,
    ));
  }
}
```

But `Chance` events don't have to contain a game state, they can contain any
type. This is useful as the chance types can be manipulated. For example, let's
look at the built in `Dice` helpers.

```dart
final roll = Roll(); // cache this for performance.

class RollToScore implements Move<DiceBattle> {
  const RollToScore();

  @override
  String get description => 'roll to score';

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
	// r1d6 is a constant equal to Dice(sides: 6, rolls: 1)
	final Chance<int> rollChance = roll.roll(r1d6);

    return rollChance.map((result) => game.copyWith(
      p1Turn: !game.p1Turn,
      p1Score: game.p1Turn ? game.p1Score + result : null,
      p2Score: game.p1Turn ? null : game.p2Score  + result,
    ));
  }
}
```

This example rolls a 1d6 to generate a `Chance<int>` with each of the six roll
values, each with 1/6 chance. It then maps each roll value (preserving
probability) into a new game where the player scores that many points.

If the transformation you wish to run will reduce the branching factor, you
should use `reduce()` instead of `map()`, as this will result in a faster
search:

```dart
    // A player is rolling 2d8, attempting to get a result of 9 or greater.
	roll.roll(r2d8)
	  // Using `map()` means we still have 16 outcomes (10 false, 6 true),
	  // which means the algorithm will have to explore 16 children (bad!)
	  .map((r) => r > 9)

   // The correct method to call for performance reasons is `reduce()`:
   roll.roll(r2d8).reduce((r) => r > 9);

   // Alternatively, you can always `condense()` any `Chance` to the same
   // effect:
   roll.roll(r2d8).map((r) => r > 9).condense();
```

We can also merge simultaneous `Chance`s by using `mergeWith()`. Calling
`mergeWith()`, like `reduce()`, will automatically `condense()`.

```dart
  // The player rolls a d6
  final d6 = roll.roll(r1d6);

  // And a player rolls a d8 as well
  final d8 = roll.roll(r1d8);

  // And we take the result of them added together:
  final sumChance = d6.mergeWith(d8, (a, b) => a + b);

  // There is no need to call `.condense()` in this case.
```

You can define the outcome of game actions either through chains of `Chance`
results, maps, and merges, or you can define the `Chance` events manually:

```dart
class Fortify implements Move<DiceBattle> {
  // ...

  @override
  Chance<DiceBattle> perform(DiceBattle game) {
	// Use dice helpers and Chance manipulation, etc:
    return roll.roll(r1d6).map((r) => game.copyWith(
	  p1Score: game.p1Score + r,
	));

	// OR

    // You can always create Chance objects manually:
	return Chance<DiceBattle>(
	  possibilities: [
		for (final i in [1, 2, 3, 4, 5, 6])
		  Possibility(
			description: 'roll a $i',
			probability: 1/6,
			outcome: game.copyWith(
			  p1Score: game.p1Score + i,
			),
		  ),
	  ]
	);

    // And of course, you can do a mix of the two.
  }
}
```

#### Implement equals/hash code

In order to enable usage of the killer move heuristic, make sure to implement
`==` (and hashcode)`.

```
class Enter implements Move<Backgammon> {
  Enter({required this.point});

  final int point;

  // ...

  @override
  bool operator==(Object? other) => other is Enter && other.point == point;

  @override
  int get hashCode => point;
}
```

The last move to cause an alpha-beta cutoff at each ply is saved. If a branch in
that same ply returns that same move in the next `game.getMoves()`, (and no
other best move saved in the transposition table) it will be checked first which
is often extremely effective for move ordering. It can only do this if the moves
are `==` to each other. So this works for `const` `Move`s or `Move`s that define
`==`.

### Pick the best move

Lastly, its easy to call the expectiminimax algorithm with your new `Game`:

```dart
  var game = DiceBattle.brandNewGame();
  var minimax = Expectiminimax<DiceBattle>(maxDepth: 10);

  final move = minimax.chooseBest(game.getMoves(), game);
```

Pick a suitable depth for your requirements. Even small depths can be expensive
to compute, as expectiminimax is not as efficient as minimax, due mostly to less
efficient alpha beta pruning. But of course, larger depths will select better
moves.

In general, it is best to only construct one `Expectiminimax<G>()` and re-use
it. Each instance maintains a transition table to cache prior results, which are
often helpful across moves & games.

You can customize this transition table as well:

```dart
  var table = TransitionTable(1024 * 1024);
  var minimax = Expectiminimax<DiceBattle>(maxDepth: 5, transitionTable: table);
```

### Play your game

A simple game loop between two AIs will look like the following:

```dart
  var minimax = Expectiminimax<DiceBattle>(maxDepth: 5);

  while (game.score != 1.0 && game.score != -1.0) {
    final move = minimax.chooseBest(game.getMoves(), game);
    print(move.description);

    final chance = move.perform(game);
    final outcome = chance.pick(random.nextDouble());
	print(outcome.description);

    game = outcome.outcome;
  }
```

## Command line tools

Specify a starting game state to easily make a command line tool for playing and
benchmarking your game!

```dart
// bin/my_game.dart
void main(List<String> args) {
  final cli = CliTool(
    startingGame: DiceGame(p1Score: 0, p2Score: 0),
  );

  return cli.run(args);
}
```

Basic usage:

```bash
# Watch a game of AI vs AI, with searches up to 8 plies in depth
# Note: pleasant viewership requires your game implement `toString()` :)
dart bin/my_game.dart watch --max-depth=8

# Run 100 games, searching each move up to 8 plies in depth, and print
# performance stats.
dart bin/my_game.dart bench -c 100 --max-depth=8

# Run the 'perft' tool on your game, a useful benchmark measuring how long it
# takes to perform all possible moves up to 6 moves ahead.
dart bin/my_game.dart perft --depth=6

# Print out more help:
dart bin/my_game.dart --help
dart bin/my_game.dart watch --help
dart bin/my_game.dart bench --help
dart bin/my_game.dart perft --help
```

## Performance considerations

The most important consideration is branching factor. If your game has a very
high branching factor, consider MCTS instead.

In general, ensure that all branches of your game are actually unique. For
example, if a player rolls two six sided dice on their turn in your game, are
there 36 outcomes or are there actually only 12? See details on Chance methods
like `reduce()` and `mergeWith()` and `condense()`.

The next biggest cost is typically list allocation. One easy place to reduce
this is to try to return constants from `Game.getMoves`:

```dart
  @override
  List<Move<DiceBattle>> getMoves() {
    const fortifyOnly = [Fortify()];
    const all = [Fortify(), Invest(), Attack()];

    final myScore = p1Turn ? p1Score : p2Score;
    final opDice = p1Turn ? p2DiceScore : p1DiceScore;

    if (opDice > 1 && myScore >= investCost) {
      return all;
    } else {
      return fortifyOnly;
    }
  }
```

Lastly, effort should be made to optimize the code for performing each move. For
example, any `Chance<T>` manipulations that will be repeated and can be cached,
should be.

### perft()

This library includes a function `perft()` that runs on a game and generates all
of its moves to a specified depth. This simple function is useful in
benchmarking that your game's move generation code is fast, a key piece of
overall engine performance.

Run it via command line tools:

```bash
dart bin/your_game.dart perft --depth 8
```
