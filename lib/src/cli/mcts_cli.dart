import 'package:args/args.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/mcts.dart';

class MctsCli extends CliEngine {
  final MctsConfig defaultConfig;

  MctsCli(this.defaultConfig);

  @override
  String get name => 'mcts';

  @override
  String get description => 'Monte-Carlo Tree Search game engine.';

  @override
  String get example => 'mcts --max-playouts 10000';

  @override
  ArgParser configureParser() => ArgParser()
    ..addOption('max-depth',
        abbr: 'd',
        defaultsTo: defaultConfig.maxDepth.toString(),
        help: 'max depth to search')
    ..addOption('max-time',
        abbr: 't',
        defaultsTo: defaultConfig.maxTime?.inMilliseconds.toString(),
        help: 'Optional constraint to limit search below time control.')
    ..addOption('max-playouts',
        abbr: 'p',
        defaultsTo: defaultConfig.maxPlayouts.toString(),
        help: 'Max playouts before aborting search')
    ..addOption('expand-depth',
        abbr: 'e',
        defaultsTo: defaultConfig.expandDepth.toString(),
        help: 'Max new deeper nodes to add to tree during expand phase')
    ..addOption('c-uct',
        defaultsTo: defaultConfig.cUct.toString(),
        help: 'Constant parameter "c" for UCT selection')
    ..addOption('c-puct',
        defaultsTo: defaultConfig.cPuct.toString(),
        help: 'Constant parameter "cpUCT" for pUCT selection');

  @override
  EngineConfig buildConfig(ArgResults results) {
    return MctsConfig(
      maxDepth: int.parse(results['max-depth']),
      maxTime: results['max-time'] == null
          ? null
          : Duration(milliseconds: int.parse(results['max-time'])),
      maxPlayouts: int.parse(results['max-playouts']),
      expandDepth: int.parse(results['expand-depth']),
      cUct: double.parse(results['c-uct']),
      cPuct: double.parse(results['c-puct']),
    );
  }
}
