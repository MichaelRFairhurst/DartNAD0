import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/perft.dart';
import 'package:expectiminimax/src/stats.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final ExpectiminimaxConfig defaultConfig;
  final commandRunner = CommandRunner('expectiminimax cli',
      'Pre-built CLI tools to run expectiminimax on custom games');

  CliTools({required this.startingGame, required this.defaultConfig}) {
    commandRunner
      ..addCommand(PerftCommand(startingGame))
      ..addCommand(WatchGame(startingGame, defaultConfig))
      ..addCommand(Benchmark(startingGame, defaultConfig))
      ..addCommand(Compare(startingGame, defaultConfig));
  }

  void run(List<String> args) {
    commandRunner.run(args);
  }
}

class WatchGame<G extends Game<G>> extends Command with ParseConfig {
  final name = 'watch';
  final description = 'Run a game and print out the moves/events/positions.';

  final G startingGame;
  final ExpectiminimaxConfig defaultConfig;

  WatchGame(this.startingGame, this.defaultConfig) {
    addConfigOptions(defaultConfig);
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addOption('print-stats',
        abbr: 'p',
        help: 'Which stats to print (if any) when the game is finished.',
        allowed: const ['time', 'all', 'none'],
        defaultsTo: 'time');
    argParser.addFlag('print-timing',
        abbr: 't', help: 'Print timing when the game is finished.');
  }

  @override
  void run() {
    final config = getConfig();
    final printStats = argResults!['print-stats'];
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);

    final random = Random(seed);
    var expectiminimax = Expectiminimax<G>(config: config);
    var game = startingGame;
    var steps = 0;
    while (game.score != 1.0 && game.score != -1.0) {
      steps++;
      print('step $steps');
      final move = expectiminimax.chooseBest(game.getMoves(), game);
      print('Player chooses: ${move.description}');
      final chance = move.perform(game);
      final outcome = chance.pick(random.nextDouble());
      print('random event: ${outcome.description}');
      game = outcome.outcome;
      print('new game state:');
      print(game);
      print('');
    }

    print('');
    print('GAME OVER!');
    print('');

    if (printStats == 'all') {
      print('steps $steps');
      print(expectiminimax.stats);
    } else if (printStats == 'time') {
      print('took ${expectiminimax.stats.duration.inMilliseconds}ms');
    }
  }
}

class Benchmark<G extends Game<G>> extends Command with ParseConfig {
  final name = 'bench';
  final description = 'Play a series of games, tracking performance.';

  final G startingGame;
  final ExpectiminimaxConfig defaultConfig;

  Benchmark(this.startingGame, this.defaultConfig) {
    addConfigOptions(defaultConfig);
    argParser.addOption('count',
        abbr: 'c', defaultsTo: '20', help: 'How many games to play');
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addFlag('refresh',
        abbr: 'r',
        help: 'Whether or not to clear cache results between games',
        defaultsTo: false);
  }

  @override
  void run() {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final config = getConfig();
    final count = int.parse(argResults!['count']);
    final stats = SearchStats(config.maxDepth);

    final random = Random(seed);
    var expectiminimax = Expectiminimax<G>(config: config);

    for (var i = 0; i < count; ++i) {
      var game = startingGame;
      if (argResults!['refresh'] && i != 0) {
        expectiminimax = Expectiminimax<G>(config: config);
      }

      while (game.score != 1.0 && game.score != -1.0) {
        final move = expectiminimax.chooseBest(game.getMoves(), game);
        final chance = move.perform(game);
        final outcome = chance.pick(random.nextDouble());
        game = outcome.outcome;
      }

      stats.add(expectiminimax.stats);
    }

    print(stats);
  }
}

class Compare<G extends Game<G>> extends Command with ParseConfig {
  final name = 'compare';
  final description = 'Compare the performance and/or decisions of two configs,'
      ' by playing a series of exactly the same games';

  final G startingGame;
  final ExpectiminimaxConfig defaultConfig;

  Compare(this.startingGame, this.defaultConfig) {
    addConfigOptions(defaultConfig);
    addConfigOptions(defaultConfig, 'vs-');
    argParser.addOption('count',
        abbr: 'c', defaultsTo: '10', help: 'How many games to play');
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addFlag('refresh',
        abbr: 'r',
        help: 'Whether or not to clear cache results between games',
        defaultsTo: false);
    argParser.addFlag('choices',
        help: 'Whether or not to check the choices match', defaultsTo: true);
  }

  @override
  void run() {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final config = getConfig();
    final vsConfig = getConfig('vs-');
    final count = int.parse(argResults!['count']);
    final compareChoices = argResults!['choices'];
    final baselineStats = SearchStats(config.maxDepth);
    final vsStats = SearchStats(vsConfig.maxDepth);

    final random = Random(seed);
    var baseline = Expectiminimax<G>(config: config);
    var vs = Expectiminimax<G>(config: vsConfig);

    for (var i = 0; i < count; ++i) {
      var game = startingGame;
      var turn = 0;
      if (argResults!['refresh'] && i != 0) {
        baselineStats.add(baseline.stats);
        vsStats.add(vs.stats);

        baseline = Expectiminimax<G>(config: config);
        vs = Expectiminimax<G>(config: vsConfig);
      }

      while (game.score != 1.0 && game.score != -1.0) {
        final move = baseline.chooseBest(game.getMoves(), game);
        final vsMove = vs.chooseBest(game.getMoves(), game);
        if (compareChoices && move != vsMove) {
          print('Difference on turn $turn, game $i');
          print('- Baseline chose ${move.description}');
          print('- Alternate config chose ${vsMove.description}');
          print('  (choosing baseline move and continuing)');
        }
        final chance = move.perform(game);
        final outcome = chance.pick(random.nextDouble());
        game = outcome.outcome;
        ++turn;
      }
    }

    baselineStats.add(baseline.stats);
    vsStats.add(vs.stats);

    print('Baseline stats:');
    print(baselineStats);
    print('');
    print('Alternative stats (--vs-config):');
    print(vsStats);
    print('');
    print('Comparative stats (alternative - baseline):');
    print(vsStats - baselineStats);
  }
}

mixin ParseConfig on Command {
  void addConfigOptions(ExpectiminimaxConfig defaults, [String prefix = '']) {
    argParser.addOption('${prefix}max-depth',
        abbr: prefix == '' ? 'd' : null,
        defaultsTo: defaults.maxDepth.toString(),
        help: 'max depth to search');
    argParser.addFlag('${prefix}iterative-deepening',
        defaultsTo: defaults.iterativeDeepening,
        help: 'enable iterative deepening');
    argParser.addFlag('${prefix}probe-chance-nodes',
        defaultsTo: defaults.probeChanceNodes,
        help: 'enable probing phase on chance nodes');
    argParser.addOption('${prefix}transposition-table-size',
        defaultsTo: defaults.transpositionTableSize.toString(),
        help: 'size (in entry count) of transposition table');
    argParser.addFlag('${prefix}strict-transpositions',
        defaultsTo: defaults.strictTranspositions,
        help: 'check == on transposition entries to avoid hash collisions');
    argParser.addOption('${prefix}debug-setting', hide: true);
  }

  ExpectiminimaxConfig getConfig([String prefix = '']) {
    return ExpectiminimaxConfig(
      maxDepth: int.parse(argResults!['${prefix}max-depth']),
      iterativeDeepening: argResults!['${prefix}iterative-deepening'],
      probeChanceNodes: argResults!['${prefix}probe-chance-nodes'],
      transpositionTableSize:
          int.parse(argResults!['${prefix}transposition-table-size']),
      strictTranspositions: argResults!['${prefix}strict-transpositions'],
      // ignore: deprecated_member_use_from_same_package
      debugSetting: argResults!['${prefix}debug-setting'],
    );
  }
}
