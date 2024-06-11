import 'dart:math';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/perft.dart';
import 'package:expectiminimax/src/stats.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final ExpectiminimaxConfig defaultConfig;

  CliTools({required this.startingGame, required this.defaultConfig}) {}

  void run(List<String> args) {
    // Convert args to a mutable list
    args = args.toList();

    // Split args by '--vs' into sections
    final sections = <List<String>>[];

    while (true) {
      final index = args.indexOf('--vs');
      if (index == -1) {
        sections.add(args);
        break;
      }

      final section = args.getRange(0, index);
      sections.add(section.toList());
      args.removeRange(0, index + 1);
    }

    final configs = sections.skip(1).toList();

    final commandRunner = CommandRunner('expectiminimax cli',
        'Pre-built CLI tools to run expectiminimax on custom games')
      ..addCommand(PerftCommand(startingGame))
      // TODO: play two AIs against each other
      ..addCommand(WatchGame(startingGame, defaultConfig, []))
      // TODO: Distinguish SingleConfigCommand from MultiConfigCommand
      ..addCommand(Benchmark(startingGame, defaultConfig, []))
      ..addCommand(Compare(startingGame, defaultConfig, configs));

    commandRunner.run(sections[0]);
  }
}

class WatchGame<G extends Game<G>> extends ParseConfigCommand {
  final name = 'watch';
  final description = 'Run a game and print out the moves/events/positions.';

  final G startingGame;

  WatchGame(this.startingGame, ExpectiminimaxConfig defaultConfig,
      List<List<String>> configSpecs)
      : super(defaultConfig, configSpecs) {
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
  void runWithConfigs(List<ExpectiminimaxConfig> configs) {
    final config = configs[0];
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

class Benchmark<G extends Game<G>> extends ParseConfigCommand {
  final name = 'bench';
  final description = 'Play a series of games, tracking performance.';

  final G startingGame;

  Benchmark(this.startingGame, ExpectiminimaxConfig defaultConfig,
      List<List<String>> configSpecs)
      : super(defaultConfig, configSpecs) {
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
  void runWithConfigs(List<ExpectiminimaxConfig> configs) {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final config = configs[0];
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

class Compare<G extends Game<G>> extends ParseConfigCommand {
  final name = 'compare';
  final description = 'Compare the performance and/or decisions of two configs,'
      ' by playing a series of exactly the same games';

  final G startingGame;

  Compare(this.startingGame, ExpectiminimaxConfig defaultConfig,
      List<List<String>> configSpecs)
      : super(defaultConfig, configSpecs) {
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
  void runWithConfigs(List<ExpectiminimaxConfig> configs) {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final config = configs[0];
    final vsConfig = configs[1];
    final count = int.parse(argResults!['count']);
    final compareChoices = argResults!['choices'];

    final random = Random(seed);
    var algs = configs.map((c) => Expectiminimax<G>(config: c)).toList();
    final stats = configs.map((c) => SearchStats(c.maxDepth)).toList();

    for (var i = 0; i < count; ++i) {
      var game = startingGame;
      var turn = 0;
      if (argResults!['refresh'] && i != 0) {
        for (var c = 0; c < configs.length; ++c) {
          stats[c].add(algs[c].stats);
          algs[c] = Expectiminimax<G>(config: configs[c]);
        }
      }

      while (game.score != 1.0 && game.score != -1.0) {
        final moves = game.getMoves();
        final move = algs[0].chooseBest(moves, game);
        for (var c = 1; c < configs.length; ++c) {
          final vsMove = algs[c].chooseBest(moves, game);
          if (compareChoices && move != vsMove) {
            print('Difference on turn $turn, game $i');
            print('- Baseline chose ${move.description}');
            print('- Alternate config $c chose ${vsMove.description}');
            print('  (choosing baseline move and continuing)');
          }
        }
        final chance = move.perform(game);
        final outcome = chance.pick(random.nextDouble());
        game = outcome.outcome;
        ++turn;
      }
    }

    for (var c = 0; c < configs.length; ++c) {
      stats[c].add(algs[c].stats);
      algs[c] = Expectiminimax<G>(config: configs[c]);
    }

    print('Baseline stats:');
    print(stats[0]);
    for (var c = 1; c < configs.length; ++c) {
      print('');
      print('Alternative stats #$c (--vs):');
      print(stats[c]);
    }
    for (var c = 1; c < configs.length; ++c) {
      print('');
      print('Comparative stats (alternative #$c - baseline):');
      print(stats[c] - stats[0]);
    }
  }
}

abstract class ParseConfigCommand extends Command {
  List<List<String>> configSpecs;
  final ExpectiminimaxConfig defaultConfig;

  ParseConfigCommand(this.defaultConfig, this.configSpecs) {
    addConfigOptionsToParser(argParser, defaultConfig);
  }

  void runWithConfigs(List<ExpectiminimaxConfig> configs);

  @override
  void run() {
    final configParser = ArgParser(allowTrailingOptions: false);
    addConfigOptionsToParser(configParser, defaultConfig);

    final configs = [
      getPrimaryConfig(),
      ...configSpecs
          .map((args) => getConfigFromResults(configParser.parse(args)))
          .toList(),
    ];

    runWithConfigs(configs);
  }

  void addConfigOptionsToParser(
          ArgParser parser, ExpectiminimaxConfig defaults) =>
      parser
        ..addOption('max-depth',
            abbr: 'd',
            defaultsTo: defaults.maxDepth.toString(),
            help: 'max depth to search')
        ..addFlag('iterative-deepening',
            defaultsTo: defaults.iterativeDeepening,
            help: 'enable iterative deepening')
        ..addOption('chance-node-probe-window',
            allowed: [
              'none',
              'overlapping',
              'centerToEnd',
              'edgeToEnd',
            ],
            defaultsTo: defaults.chanceNodeProbeWindow.name,
            help: 'enable probing phase on chance nodes')
        ..addOption('transposition-table-size',
            defaultsTo: defaults.transpositionTableSize.toString(),
            help: 'size (in entry count) of transposition table')
        ..addFlag('strict-transpositions',
            defaultsTo: defaults.strictTranspositions,
            help: 'check == on transposition entries to avoid hash collisions')
        ..addOption('debug-setting', hide: true);

  ExpectiminimaxConfig getPrimaryConfig() => getConfigFromResults(argResults!);

  ExpectiminimaxConfig getConfigFromResults(ArgResults results) =>
      ExpectiminimaxConfig(
        maxDepth: int.parse(results['max-depth']),
        iterativeDeepening: results['iterative-deepening'],
        chanceNodeProbeWindow:
            ProbeWindow.values.byName(results['chance-node-probe-window']),
        transpositionTableSize: int.parse(results['transposition-table-size']),
        strictTranspositions: results['strict-transpositions'],
        // ignore: deprecated_member_use_from_same_package
        debugSetting: results['debug-setting'],
      );
}
