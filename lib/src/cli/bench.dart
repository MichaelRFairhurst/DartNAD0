import 'dart:math';

import 'package:dartnad0/src/cli/parse_config_command.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/mcts.dart';
import 'package:dartnad0/src/config.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/time_control.dart';

class Benchmark<G extends Game<G>> extends ParseConfigCommand {
  final name = 'bench';
  final description = 'Play a series of games, tracking performance.';

  final G startingGame;
  final Duration defaultMoveTimer;

  Benchmark(
      this.startingGame,
      this.defaultMoveTimer,
      ExpectiminimaxConfig defaultXmmConfig,
      MctsConfig defaultMctsConfig,
      List<List<String>> configSpecs)
      : super(defaultXmmConfig, defaultMctsConfig, configSpecs) {
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
  void runWithConfigs(List<EngineConfig> configs) async {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final config = configs[0];
    final count = int.parse(argResults!['count']);

    final random = Random(seed);
    var engine = config.buildEngine<G>();

    for (var i = 0; i < count; ++i) {
      var game = startingGame;
      if (argResults!['refresh']) {
        engine.clearCache();
      }

      while (game.score != 1.0 && game.score != -1.0) {
        final move = await engine.chooseBest(
            game.getMoves(), game, RelativeTimeControl(defaultMoveTimer));
        final chance = move.perform(game);
        final outcome = chance.pick(random.nextDouble());
        game = outcome.outcome;
      }
    }

    print(engine.stats);
  }
}
