import 'dart:math';

import 'package:expectiminimax/src/cli/parse_config_command.dart';
import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/mcts.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/game.dart';

class Compare<G extends Game<G>> extends ParseConfigCommand {
  final name = 'compare';
  final description = 'Compare the performance and/or decisions of two configs,'
      ' by playing a series of exactly the same games';

  final G startingGame;

  Compare(this.startingGame, ExpectiminimaxConfig defaultXmmConfig,
      MctsConfig defaultMctsConfig, List<List<String>> configSpecs)
      : super(defaultXmmConfig, defaultMctsConfig, configSpecs) {
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
  void runWithConfigs(List<EngineConfig> configs) async {
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final count = int.parse(argResults!['count']);
    final compareChoices = argResults!['choices'];

    final random = Random(seed);
    var algs = configs.map((c) => c.buildEngine<G>()).toList();

    for (var i = 0; i < count; ++i) {
      var game = startingGame;
      var turn = 0;
      if (argResults!['refresh'] && i != 0) {
        for (var c = 0; c < configs.length; ++c) {
          algs[c].clearCache();
        }
      }

      while (game.score != 1.0 && game.score != -1.0) {
        final moves = game.getMoves();
        final move = await algs[0].chooseBest(moves, game);
        for (var c = 1; c < configs.length; ++c) {
          final vsMove = await algs[c].chooseBest(moves, game);
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

    print('Baseline stats:');
    print(algs[0].stats);
    for (var c = 1; c < configs.length; ++c) {
      print('');
      print('Alternative stats #$c (--vs):');
      print(algs[c].stats);
    }
    for (var c = 1; c < configs.length; ++c) {
      print('');
      print('Comparative stats (alternative #$c - baseline):');
      print(algs[c].stats - algs[0].stats);
    }
  }
}