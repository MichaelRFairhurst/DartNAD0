import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/expectiminimax.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/perft.dart';
import 'package:expectiminimax/src/stats.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final commandRunner = CommandRunner('expectiminimax cli',
      'Pre-built CLI tools to run expectiminimax on custom games');

  CliTools({required this.startingGame}) {
    commandRunner
      ..addCommand(PerftCommand(startingGame))
      ..addCommand(WatchGame(startingGame))
      ..addCommand(Benchmark(startingGame));
  }

  void run(List<String> args) {
    commandRunner.run(args);
  }
}

class WatchGame<G extends Game<G>> extends Command {
  final name = 'watch';
  final description = 'Run a game and print out the moves/events/positions.';

  final G startingGame;

  WatchGame(this.startingGame) {
    // TODO make this a shared set of config options for multiple commands.
    argParser.addOption('maxDepth',
        abbr: 'd', defaultsTo: '5', help: 'max depth to search');
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addFlag('print-stats',
        abbr: 'p', help: 'Print stats when the game is finished.');
    argParser.addFlag('print-timing',
        abbr: 't', help: 'Print timing when the game is finished.');
  }

  @override
  void run() {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final maxDepth = int.parse(argResults!['maxDepth']);

    final random = Random(seed);
    final expectiminimax = Expectiminimax<G>(maxDepth: maxDepth);
    final start = DateTime.now();
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

    final end = DateTime.now();
    if (argResults!['print-timing']) {
      print('took ${end.difference(start).inMilliseconds}ms');
    }

    if (argResults!['print-stats']) {
      print('steps $steps');
      print(expectiminimax.stats);
    }
  }
}

class Benchmark<G extends Game<G>> extends Command {
  final name = 'bench';
  final description = 'Play a series of games, tracking performance.';

  final G startingGame;

  Benchmark(this.startingGame) {
    // TODO make this a shared set of config options for multiple commands.
    argParser.addOption('maxDepth',
        abbr: 'd', defaultsTo: '5', help: 'max depth to search');
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
    final count = int.parse(argResults!['count']);
    final maxDepth = int.parse(argResults!['maxDepth']);
    final stats = SearchStats(maxDepth);

    final random = Random(seed);
    var expectiminimax = Expectiminimax<G>(maxDepth: maxDepth);
    final start = DateTime.now();

    for (var i = 0; i < count; ++i) {
	  var game = startingGame;
	  if (argResults!['refresh'] && i != 0) {
		expectiminimax = Expectiminimax<G>(maxDepth: maxDepth);
	  }

      while (game.score != 1.0 && game.score != -1.0) {
        final move = expectiminimax.chooseBest(game.getMoves(), game);
        final chance = move.perform(game);
        final outcome = chance.pick(random.nextDouble());
        game = outcome.outcome;
      }

      stats.add(expectiminimax.stats);
    }

    final end = DateTime.now();
    print('took ${end.difference(start).inMilliseconds}ms');
    print(stats);
  }
}
