# Dart expectiminimax implementation

A version of minimax that allows for random events, coded in dart.

Note that expectiminimax is often much slower than minimax as it cannot leverage
alpha/beta pruning nearly as effectively. The alternative approach which can
help in some games, MCTS, is also supported.

Mildy optimized, and comes with prebuilt command line tools, use for your own
fun!

## Current features

- transposition tables
- iterative deepening with timeouts
- minimax-style alpha-beta pruning (for deterministic nodes)
- move ordering (based on best move stored in transition tables)
- killer move heuristic
- \*-minimax (alpha beta pruning on CHANCE nodes)
- star2-style probing pass on CHANCE descendents
- MCTS with UCT-based and/or pUCT-based node selection
- SPRT testing support
- serving engine over HTTP

## TODO

- Concurrent search: will be hard to do anything like lazy SMP in Dart. We could
  easily thread on CHANCE nodes, however, this strategy could backfire if we
  can't share the transposition table.
- Quiescence search (necessary for certain games to avoid horizon problems, find
  good move orderings in iterative deepening).
- Reversible games: Reduce allocation & GC overhead by using mutable game
  objects and making/unmaking moves
- Zobrist hashing
- Further optimize MCTS: support pUct, more parameters, transposition tables,
  additional selection methods such as RAVE
- Late move reductions
- Support roll-to-move style games more naturally
- Principle-Variation search (prototyped but not offering improvement).
- TLA+ model checking of optimizations.
- Draw detection.
- Prefer winning in fewer turns.
- Test algorithm on more games.

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

Specify a starting game state and default engine configuration settings to
easily make a command line tool for playing and benchmarking your game, as well
as serving your engine over http.

```dart
// bin/my_game.dart
void main(List<String> args) {
  final cli = CliTool(
    startingGame: DiceGame(p1Score: 0, p2Score: 0),
	defaultXmmConfig(
	  maxDepth: 20,
	  maxTime: const Duration(seconds: 1),
	),
	defaultMctsConfig(
	  maxDepth: 80,
	  maxTime: const Duration(seconds: 1),
	)
  );

  return cli.run(args);
}
```

The command line interface supports multiple engines. Use `xmm` to specify the
expectiminimax engine, and `mcts` to use monte-carlo tree search. Run `help` to
see all available engines.

Basic usage:

```bash
# Watch a game of AI vs AI, with searches up to 50ms in duration.
# Note: pleasant viewership requires your game implement `toString()` :)
dart bin/my_game.dart watch xmm --max-time=50

# Same as above but with MCTS instead of expectiminimax.
dart bin/my_game.dart watch mcts --max-time=50

# Run 100 games, searching each move up to 8 plies in depth, and print
# performance stats.
dart bin/my_game.dart bench -c 100 xmm --max-depth=8

# Serve your game engine over http
dart bin/my_game.dart serve --port 8080 xmm --max-time=50

# Run the 'perft' tool on your game, a useful benchmark measuring how long it
# takes to perform all possible moves up to 6 moves ahead.
dart bin/my_game.dart perft --depth=6

# Print out more help:
dart bin/my_game.dart --help
dart bin/my_game.dart watch --help
dart bin/my_game.dart rank --help
dart bin/my_game.dart compare --help
dart bin/my_game.dart bench --help
dart bin/my_game.dart perft --help
```

### Expectiminimax engine config

You can configure the xmm engine settings for your game in many of the
subcommands by using the following settings:

- `--max-depth` or `-d`: set maximum search depth. Prefer high and rely on
  timeouts to stop the search, unless you have disabled iterative deepening.
- `--max-time` or `-t`: set maximum search time in ms. If you have disabled
  iterative deepening, prefer a very large number/no timeout.
- `--no-iterative-deepening`: Disable "iterative deepening" in favor of a fixed
  depth search. With iterative deepening enabled, the engine searches to depth
  1, then 2, etc, until either timeout or max depth is reached, the best move
  from the deepest search is picked. Note that fixed depth search is often
  slower than an equivalently deep iterative deepening search due to caching,
  and that if the search times out during a fixed depth search, the engine will
  be forced to pick the first available move.
- `--chance-node-probe-window`: Use probing approaches to attempt to reduce
  unconstrained chance node searches, and increase alpha-beta cutoffs. Options
  are 'none', 'overlapping', 'centerToEnd', and 'edgeToEnd'. For each child of a
  chance node, we can perform an upper bound and lower bound probe based on the
  current alpha/beta values. Overlapping searches from alpha to 2.0 and -2.0 to
  beta, while edgeToEnd searches from beta to 2.0 and -2 to alpha. Center to end
  is an average of the two, and none disables probing.
- `--transposition-table-size`: How many entries to hold in the transposition
  table. Too large will not use the processor cache as effectively, two small
  means transpositions will be overwritten that would have been useful.
- `--strict-transpositions`: The transposition table by default assumes that two
  equal hash codes represent the same game. This is not truly correct behavior,
  and it is fixable with `--strict-transpositions`. However, it consumes much
  more memory when enabled.

### MCTS engine config

There are important configuration options exposed for monte-carlo tree search as
well.

- `--max-depth` or `-d`: set maximum playout depth. If the scoring function is
  unreliable without looking many moves ahead, set this high. Otherwise, a lower
  depth may reduce the amount of noise in each playout and improve the engine.
- `--max-time` or `-t`: set maximum search time in ms.

#### UCT vs pUCT

The following settings determine whether the engine will perform a UCT-style
search (upper confidence applied to trees), which uses no priors to assume the
strength of a move, or, whether to perform a pUCT-style search, which utilizes
priors.

To perform a pure UCT style search, set `--c-puct` to zero, or else a hybrid
approach will be used.

- `--c-uct`: Set the constant parameter `c` in UCT-style searching. The
  theoretically this parameter should equal root 2. A higher number will prefer
  a broader search, and narrower number will focus more on simulating previously
  effective moves.

AlphaZero and Leela Chess Zero use pUCT search. To perform a pure pUCT style
search, set `--c-uct` to zero and `--expand-depth` to 1, or else a hybrid
approach will be used.

In a pUCT search, only a few nodes are added to the tree per "playout." However,
playouts are rarely completed, and instead a scoring function is used (ideally,
a neural network) to predict the chance of a player winning the game.

- `--c-puct`: Set the constant parameter `cPUCT` for pUCT-style searching. A
  higher number will rely more on priors in node selection when visit count is
  low, and will weight novel exploration more as visit count increases.
- `--expand-depth` When a leaf is selected, how deep to traverse for adding new
  nodes. Traditional pUCT searching uses an expand depth of 1, however, this can
  amount to a short-sighted search when the scoring function is short sighted.

## Performance considerations

The most important consideration is branching factor, especially if you use the
expectiminimax engine instead of the MCTS engine.

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

### Benchmarking & compare commands

To measure the performance of your engine, and/or compare performance with
different settings, you can use the `bench` or `compare` commands.

```bash
# Run 100 games with the given config and print timing/stats
dart bin/my_game.dart bench --count 100

# Run 100 games with the given configs and compare timing/stats
dart bin/my_game.dart compare --count 100 $CONFIG1 --vs $CONFIG2
```

The first command will run 100 games and count how many nodes are visited,
cutoffs performed, how much time elapsed, etc.

The second command will run 100 games with two different engine configs, check
for differences in their stats, timing, and move selection. To ensure an apples
to apples comparison of search statistics, the first engine will pick each move
and the second engine's move is not played.

You can compare as many engines as you wish at once, for instance:

```bash
dart bin/my_game.dart compare --count 100 \
  --max-depth 8 --no-iterative-deepening \ # config 1
  --vs --max-depth 8 --iterative-deepening \ # config 2
  --vs --max-depth 40 --iterative-deepening \ # conifg 3
  --vs ... # config 4+
```

Run `bench help` and `compare help` for more flags and options.

### SPRT testing

To dial in your engine settings, consider running SPRT tests using the `rank`
command, to test your engines in directly in elo.

```bash
# basic ranking functionality
dart bin/my_game.dart rank --count 100 $CONFIG1 --vs $CONFIG2

# SPRT ranking functionality
dart bin/my_game.dart rank --sprt --count 10000 $CONFIG1 --vs $CONFIG2
```

The basic version above will pit engine one against engine two for 100 games,
and display their ELO scores as calculated by win/loss/draw record, with an
error margin. But how many games should you run?

The second command starts a Sequential Probability Ratio Test (SPRT), which
will run games between the provided engine until it has proven one elo
hypothesis (e.g. +15) over another (e.g. to +0) or vice versa, for each
specified engine. These elos can be customized with flags `--elo` and
`--null-elo`, and false positive/false negative rate can be customized with
flags `--alpha` and `--beta`.

Like `compare`, the `rank` command can take more than two engine configs,
separated by `--vs` flags. They will all compete against each other, and SPRT
will finish when each engine has concluded its testing to the requested error.

```bash
dart bin/my_game.dart rank --sprt --count 10000 \
  --max-depth 8 --no-iterative-deepening \ # config 1
  --vs --max-depth 8 --iterative-deepening \ # config 2
  --vs --max-depth 40 --iterative-deepening \ # conifg 3
  --vs ... # config 4+
```

You can use SPRT testing to measure performance changes in elo, and to pick
the best default settings for your engine's performance.

Run `rank help` for more flags and options.
