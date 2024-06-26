import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/cli/bench.dart';
import 'package:expectiminimax/src/cli/compare.dart';
import 'package:expectiminimax/src/cli/rank.dart';
import 'package:expectiminimax/src/cli/watch.dart';
import 'package:expectiminimax/src/mcts.dart';
import 'package:expectiminimax/src/serve/serve_command.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/perft.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final G Function(String) decoder;
  final ExpectiminimaxConfig defaultXmmConfig;
  final MctsConfig defaultMctsConfig;

  CliTools({
    required this.startingGame,
    required this.defaultXmmConfig,
    required this.defaultMctsConfig,
    G Function(String)? decoder,
  }) : decoder = decoder ?? throwingDecoder;

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

    final commandRunner = _ListEnginesCommandRunner('dart your_wrapper.dart',
        'Pre-built CLI tools to run expectiminimax on custom games')
      ..addCommand(PerftCommand(startingGame))
      // TODO: play two AIs against each other
      ..addCommand(
          WatchGame(startingGame, defaultXmmConfig, defaultMctsConfig, []))
      // TODO: Distinguish SingleConfigCommand from MultiConfigCommand
      ..addCommand(
          Benchmark(startingGame, defaultXmmConfig, defaultMctsConfig, []))
      ..addCommand(
          Compare(startingGame, defaultXmmConfig, defaultMctsConfig, configs))
      ..addCommand(
          Rank(startingGame, defaultXmmConfig, defaultMctsConfig, configs))
      ..addCommand(
          ServeCommand(decoder, defaultXmmConfig, defaultMctsConfig, configs));

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

