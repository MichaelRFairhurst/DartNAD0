import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/mcts.dart';
import 'package:expectiminimax/src/other_engines/nth_engine.dart';
import 'package:expectiminimax/src/other_engines/random_engine.dart';
import 'package:expectiminimax/src/serve/served_engine_config.dart';
import 'package:expectiminimax/src/config.dart';

abstract class ParseConfigCommand extends Command {
  List<List<String>> configSpecs;
  final ExpectiminimaxConfig defaultXmmConfig;
  final MctsConfig defaultMctsConfig;

  ParseConfigCommand(
      this.defaultXmmConfig, this.defaultMctsConfig, this.configSpecs) {
    argParser.addCommand('xmm', xmmParser(defaultXmmConfig));
    argParser.addCommand('mcts', mctsParser(defaultMctsConfig));
    argParser.addCommand('served', servedEngineParser());
    argParser.addCommand('random', randomEngineParser());
    argParser.addCommand('nth', nthEngineParser());
  }

  void runWithConfigs(List<EngineConfig> configs);

  @override
  String get usageFooter => '''

Additionally, running this command requires specifying one or more engines:

    xmm               Expectiminimax game engine.
                      Example: $name xmm --max-depth 8
    mcts              Monte-Carlo Tree Search game engine.
                      Example: $name mcts --max-playouts 10000
    served            Engine runnnig with API launched via `serve` command.
                      Example: $name served localhost:8080
    random            Simple engine which just picks random moves.
                      Example: $name random --seed 0
    nth               Simple engine which always picks the nth move.
                      Example: $name nth -n 0

Some commands can accept multiple engines. These engines may be separated with '--vs' flags.

    --vs              Specify an additional engine to $name.
                      Example: $name xmm --max-depth 8 --vs mcts --max-playouts 1000 --vs random

'xmm' engine config options:

${xmmParser(defaultXmmConfig).usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}

'mcts' engine config options:

${mctsParser(defaultMctsConfig).usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}

'served' engine config options:

${servedEngineParser().usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}

'random' engine config options:

${randomEngineParser().usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}

'nth' engine config options:

${nthEngineParser().usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}
''';

  @override
  void run() {
    if (argResults?.command == null) {
      print('Error: no engine specified, cannot proceed.');
      print('');
      printUsage();
      return;
    }

    final configParser = ArgParser(allowTrailingOptions: false);
    configParser.addCommand('xmm', xmmParser(defaultXmmConfig));
    configParser.addCommand('mcts', mctsParser(defaultMctsConfig));
    configParser.addCommand('served', servedEngineParser());
    configParser.addCommand('random', randomEngineParser());
    configParser.addCommand('nth', nthEngineParser());

    try {
      final configs = [
        getPrimaryConfig(),
        ...configSpecs.map((args) {
          if (args.first.startsWith('-')) {
            throw 'Error: Specify an engine before engine flags: "$args"';
          }
          if (!{'xmm', 'mcts', 'served', 'random', 'nth'}
              .contains(args.first)) {
            throw 'Error: Invalid engine name: "${args.first}"';
          }
          try {
            return getConfigFromResults(configParser.parse(args));
          } catch (e) {
            throw 'Error: Misconfigured engine "$args"\n\n$e';
          }
        })
      ];

      runWithConfigs(configs);
    } on FormatException catch (e) {
      print(e);
      print('');
      printUsage();
    }
  }

  @override
  String get invocation =>
      '$name [--$name-flags] `engine` [--engine-flags] [--vs `engine [--engineflags] --vs ...]';

  ArgParser xmmParser(ExpectiminimaxConfig defaults) =>
      addXmmOptionsToParser(ArgParser(), defaults);

  ArgParser addXmmOptionsToParser(
          ArgParser parser, ExpectiminimaxConfig defaults) =>
      parser
        ..addOption('max-depth',
            abbr: 'd',
            defaultsTo: defaults.maxDepth.toString(),
            help: 'max depth to search')
        ..addOption('max-time',
            abbr: 't',
            defaultsTo: defaults.maxTime.inMilliseconds.toString(),
            help: 'max time to search, in milliseconds')
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

  ArgParser mctsParser(MctsConfig defaults) =>
      ArgParser(allowTrailingOptions: false)
        ..addOption('max-depth',
            abbr: 'd',
            defaultsTo: defaults.maxDepth.toString(),
            help: 'max depth to search')
        ..addOption('max-time',
            abbr: 't',
            defaultsTo: defaults.maxTime.inMilliseconds.toString(),
            help: 'max time to search, in milliseconds')
        ..addOption('max-playouts',
            abbr: 'p',
            defaultsTo: defaults.maxPlayouts.toString(),
            help: 'Max playouts before aborting search')
        ..addOption('expand-depth',
            abbr: 'e',
            defaultsTo: defaults.expandDepth.toString(),
            help: 'Max new deeper nodes to add to tree during expand phase')
        ..addOption('c-uct',
            defaultsTo: defaults.cUct.toString(),
            help: 'Constant parameter "c" for UCT selection')
        ..addOption('c-puct',
            defaultsTo: defaults.cPuct.toString(),
            help: 'Constant parameter "cpUCT" for pUCT selection');

  ArgParser randomEngineParser() => ArgParser(allowTrailingOptions: false)
    ..addOption('seed', abbr: 's', help: 'seed for random move selection.');

  ArgParser servedEngineParser() => ArgParser();

  ArgParser nthEngineParser() => ArgParser(allowTrailingOptions: false)
    ..addFlag('from-end',
        abbr: 'e', help: 'select nth move from the end instead of the start')
    ..addOption('n',
        abbr: 'n',
        defaultsTo: '0',
        help: '0-based index for which move to select');

  EngineConfig getPrimaryConfig() => getConfigFromResults(argResults!);

  EngineConfig getConfigFromResults(ArgResults results) {
    switch (results.command?.name) {
      case 'xmm':
        return getXmmConfig(results.command!);
      case 'mcts':
        return getMctsConfig(results.command!);
      case 'served':
        return getServedEngineConfig(results.command!);
      case 'random':
        return getRandomEngineConfig(results.command!);
      case 'nth':
        return getNthEngineConfig(results.command!);
      default:
        throw 'bad engine name ${results.command?.name}';
    }
  }

  ExpectiminimaxConfig getXmmConfig(ArgResults results) {
    return ExpectiminimaxConfig(
      maxDepth: int.parse(results['max-depth']),
      maxTime: Duration(milliseconds: int.parse(results['max-time'])),
      iterativeDeepening: results['iterative-deepening'],
      chanceNodeProbeWindow:
          ProbeWindow.values.byName(results['chance-node-probe-window']),
      transpositionTableSize: int.parse(results['transposition-table-size']),
      strictTranspositions: results['strict-transpositions'],
      // ignore: deprecated_member_use_from_same_package
      debugSetting: results['debug-setting'],
    );
  }

  MctsConfig getMctsConfig(ArgResults results) {
    return MctsConfig(
      maxDepth: int.parse(results['max-depth']),
      maxTime: Duration(milliseconds: int.parse(results['max-time'])),
      maxPlayouts: int.parse(results['max-playouts']),
      expandDepth: int.parse(results['expand-depth']),
      cUct: double.parse(results['c-uct']),
      cPuct: double.parse(results['c-puct']),
    );
  }

  ServedEngineConfig getServedEngineConfig(ArgResults results) {
    if (results.rest.length != 1) {
      throw FormatException('wrong number of arguments provided, expected'
          ' hostname, got ${results.rest}');
    }
    return ServedEngineConfig(server: results.rest.single);
  }

  RandomEngineConfig getRandomEngineConfig(ArgResults results) {
    return RandomEngineConfig(
      seed: results.wasParsed('seed') ? int.parse(results['seed']) : null,
    );
  }

  NthEngineConfig getNthEngineConfig(ArgResults results) {
    return NthEngineConfig(
      direction: results['from-end'] ? Direction.fromEnd : Direction.fromStart,
      offset: int.parse(results['n']),
    );
  }
}
