import 'dart:math';

import 'package:dartnad0/src/cli/parse_config_command.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/mcts.dart';
import 'package:dartnad0/src/time_control.dart';
import 'package:thread/thread.dart';
import 'package:dartnad0/src/config.dart';
import 'package:dartnad0/src/elo.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';

class Rank<G extends Game<G>> extends ParseConfigCommand {
  final name = 'rank';
  final description = 'Rank two configs in ELO, by playing a series of games'
      ' between them.';

  final G startingGame;
  final Duration defaultMoveTimer;

  Rank(
      this.startingGame,
      this.defaultMoveTimer,
      ExpectiminimaxConfig defaultXmmConfig,
      MctsConfig defaultMctsConfig,
      List<List<String>> configSpecs)
      : super(defaultXmmConfig, defaultMctsConfig, configSpecs) {
    argParser.addOption('count',
        abbr: 'c', defaultsTo: '10', help: 'Maximum number of games to play');
    argParser.addOption('seed',
        abbr: 's', help: 'Random number generator seed.');
    argParser.addOption('threads',
        defaultsTo: '8', help: 'Number of games to run concurrently.');
    argParser.addFlag('sprt',
        defaultsTo: false,
        help: 'Run SPRT (sequential probability ratio test), which tests until'
            ' --elo or --null-elo is proven for each engine, or max games is'
            ' hit.');
    argParser.addOption('alpha',
        defaultsTo: '0.05',
        help: 'alpha value for running SPRT, or, false positive rate');
    argParser.addOption('beta',
        defaultsTo: '0.05',
        help: 'beta value for running SPRT, or, false negative rate');
    argParser.addOption('elo',
        defaultsTo: '20',
        help: 'When running SPRT, this sets the alternative hypothesis ELO for'
            ' each engine.');
    argParser.addOption('null-elo',
        defaultsTo: '0',
        help: 'When running SPRT, this sets the null hypothesis ELO for each'
            ' engine.');
    argParser.addFlag('refresh',
        abbr: 'r',
        help: 'Whether or not to clear cache results between games',
        defaultsTo: false);
  }

  Thread startThread(List<EngineConfig> configs, Random random, bool refresh) {
    return Thread((events) {
      final algs = configs.map((c) => c.buildEngine<G>()).toList();
      events.on('game', (List<int> players) async {
        var game = startingGame;
        final aIdx = players[0];
        var bIdx = players[1];

        final playerA = algs[aIdx];
        final playerB = algs[bIdx];

        if (refresh) {
          algs[bIdx].clearCache();
          algs[aIdx].clearCache();
        }

        for (int i = 0; true; ++i) {
          if (game.score == 1.0 || game.score == -1.0) {
            events.emit('result', game.score);
            break;
          } else if (i == 1000) {
            events.emit('result', 0.0);
            break;
          }

          final moves = game.getMoves();
          if (moves.isEmpty) {
            events.emit('result', 0.0);
            break;
          }

          final Move<G> move;
          if (game.isMaxing) {
            move = await playerA.chooseBest(
                moves, game, RelativeTimeControl(defaultMoveTimer));
          } else {
            move = await playerB.chooseBest(
                moves, game, RelativeTimeControl(defaultMoveTimer));
          }
          final chance = move.perform(game);
          final outcome = chance.pick(random.nextDouble());
          game = outcome.outcome;
        }
      });
    });
  }

  void stopThreads(List<Thread> threads) {
    for (final thread in threads) {
      thread.events?.receivePort.close();
      thread.stop();
    }
  }

  @override
  void runWithConfigs(List<EngineConfig> configs) {
    final elo = FullHistoryElo<int>();
    elo.init(List.generate(configs.length, (i) => i));
    final seed =
        argResults!['seed'] == null ? null : int.parse(argResults!['seed']);
    final count = int.parse(argResults!['count']);
    final threadCount = int.parse(argResults!['threads']);

    final random = Random(seed);
    final refresh = argResults!['refresh'];

    print('[GAMES]');
    print('');
    print('[RATINGS]');
    print(elo);

    final esc = String.fromCharCode(27);
    final clearStr = '$esc[1A$esc[2K' * (configs.length + 2);

    final threads = List.generate(
        threadCount, (i) => startThread(configs, random, refresh));

    var startedGames = 0;
    var game = 0;
    for (final thread in threads) {
      var aIdx;
      var bIdx;
      runGame() {
        aIdx = random.nextInt(configs.length);
        bIdx = random.nextInt(configs.length - 1);
        if (bIdx >= aIdx) {
          ++bIdx;
        }
        startedGames++;
        thread.emit('game', <int>[aIdx, bIdx]);
      }

      thread.on('result', (double score) {
        game++;
        if (score == 1.0) {
          print('${clearStr}* game $game, $aIdx beats $bIdx');
          elo.victory(aIdx, bIdx);
        } else if (score == 0.0) {
          print('${clearStr}* game $game, $aIdx and $bIdx draw');
          elo.draw(aIdx, bIdx);
        } else if (score == -1.0) {
          print('${clearStr}* game $game, $bIdx beats $aIdx');
          elo.loss(aIdx, bIdx);
        }

        print('');
        print('[RATINGS]');
        print(elo);

        if (argResults!['sprt']) {
          final alpha = double.parse(argResults!['alpha']);
          final beta = double.parse(argResults!['beta']);
          final elo1 = double.parse(argResults!['null-elo']);
          final elo2 = double.parse(argResults!['elo']);
          final sprt =
              elo.sprt(alpha: alpha, beta: beta, elo1: elo1, elo2: elo2);
          if (sprt.length == configs.length) {
            stopThreads(threads);

            print('');
            print('Stopping on SPRT result!');
            print(sprt.entries
                .map((e) => '${e.key}:'
                    ' ${e.value ? "more likely $elo2" : "more likely $elo1"}')
                .join('\n'));
          }
        }

        if (startedGames < count) {
          runGame();
        } else {
          thread.events?.receivePort.close();
          thread.stop();
        }
      });

      runGame();
    }
  }
}
