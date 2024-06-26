import 'package:args/command_runner.dart';
import 'package:dartnad0/src/cli/bench.dart';
import 'package:dartnad0/src/cli/compare.dart';
import 'package:dartnad0/src/cli/mcts_cli.dart';
import 'package:dartnad0/src/cli/other_engines_cli.dart';
import 'package:dartnad0/src/cli/rank.dart';
import 'package:dartnad0/src/cli/served_cli.dart';
import 'package:dartnad0/src/cli/strict_engine_cli.dart';
import 'package:dartnad0/src/cli/watch.dart';
import 'package:dartnad0/src/cli/xmm_cli.dart';
import 'package:dartnad0/src/config.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/mcts.dart';
import 'package:dartnad0/src/perft.dart';
import 'package:dartnad0/src/serve/serve_command.dart';
import 'package:dartnad0/src/time/time_controller.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final TimeController timeController;
  final G Function(String) decoder;
  final ExpectiminimaxConfig defaultXmmConfig;
  final MctsConfig defaultMctsConfig;

  CliTools({
    required this.startingGame,
    required this.timeController,
    ExpectiminimaxConfig? defaultXmmConfig,
    MctsConfig? defaultMctsConfig,
    G Function(String)? decoder,
  })  : decoder = decoder ?? throwingDecoder,
        defaultXmmConfig = defaultXmmConfig ?? ExpectiminimaxConfig(),
        defaultMctsConfig = defaultMctsConfig ?? MctsConfig();

  static Never throwingDecoder(String) =>
      throw UnimplementedError('no decoder specified');

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

    final engines = {
      'xmm': StrictEngineCli(XmmCli(defaultXmmConfig)),
      'mcts': StrictEngineCli(MctsCli(defaultMctsConfig)),
      'served': ServedEngineCli(),
      'random': RandomEngineCli(),
      'nth': NthEngineCli(),
    };

    final commandRunner = _ListEnginesCommandRunner('dart your_wrapper.dart',
        'Pre-built CLI tools to run expectiminimax on custom games')
      ..addCommand(PerftCommand(startingGame))
      // TODO: play two AIs against each other
      ..addCommand(WatchGame(startingGame, timeController,
          engines: engines, configSpecs: []))
      // TODO: Distinguish SingleConfigCommand from MultiConfigCommand
      ..addCommand(Benchmark(startingGame, timeController,
          engines: engines, configSpecs: []))
      ..addCommand(Compare(startingGame, timeController,
          engines: engines, configSpecs: configs))
      ..addCommand(Rank(startingGame, timeController,
          engines: engines, configSpecs: configs))
      ..addCommand(
          ServeCommand(decoder, engines: engines, configSpecs: configs));

    // Workaround: parse command separately before running it. Command Runner
    // does not like our usage of subcommands and crashes on run() if there's a
    // parse error. This parse() call correctly throws.
    commandRunner.argParser.parse(sections[0]);

    // If we didn't throw, we can safely run.
    commandRunner.run(sections[0]);
  }
}

class _ListEnginesCommandRunner extends CommandRunner {
  _ListEnginesCommandRunner(super.name, super.description);

  @override
  String get usageFooter => '''

Available engines for the above commands:
  xmm       Expectiminimax engine.
  mcts      Monte-Carlo Tree Search engine.
  served    Connect over API to engine hosted by `serve` command.
  random    Utility engine which simply picks a random move.
  nth       Utility engine which always picks the nth move or nth-to-last move.
''';
}
