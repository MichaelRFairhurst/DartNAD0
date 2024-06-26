import 'dart:math';

import 'package:expectiminimax/src/cli/parse_config_command.dart';
import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/mcts.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/game.dart';

class WatchGame<G extends Game<G>> extends ParseConfigCommand {
  final name = 'watch';
  final description = 'Run a game and print out the moves/events/positions.';

  final G startingGame;

  WatchGame(this.startingGame, ExpectiminimaxConfig defaultXmmConfig,
      MctsConfig defaultMctsConfig, List<List<String>> configSpecs)
      : super(defaultXmmConfig, defaultMctsConfig, configSpecs) {
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addOption('print-stats',
        abbr: 'p',
        help: 'Which stats to print (if any) when the game is finished.',
        allowed: const ['time', 'all', 'none'],
        defaultsTo: 'time');
    argParser.addFlag('print-timing',
        help: 'Print timing when the game is finished.');
  }

  @override
  void runWithConfigs(List<EngineConfig> configs) async {
    final config = configs[0];
    final printStats = argResults!['print-stats'];
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);

    final random = Random(seed);
    var engine = config.buildEngine<G>();
    var game = startingGame;
    var steps = 0;
    while (game.score != 1.0 && game.score != -1.0) {
      steps++;
      print('step $steps');
      final move = await engine.chooseBest(game.getMoves(), game);
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
      print(engine.stats);
    } else if (printStats == 'time') {
      print('took ${engine.stats.duration.inMilliseconds}ms');
    }
  }
}

