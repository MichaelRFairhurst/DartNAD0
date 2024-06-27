import 'package:args/args.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/config.dart';
import 'package:dartnad0/src/engine.dart';

class XmmCli extends CliEngine {
  final ExpectiminimaxConfig defaultConfig;

  XmmCli(this.defaultConfig);
  @override
  String get name => 'xmm';

  @override
  String get description => 'Expectiminimax game engine.';

  @override
  String get example => 'xmm --max-depth 8';

  @override
  ArgParser configureParser() => ArgParser()
    ..addOption('max-depth',
        abbr: 'd',
        defaultsTo: defaultConfig.maxDepth.toString(),
        help: 'max depth to search')
    ..addOption('max-time',
        abbr: 't',
        defaultsTo: defaultConfig.maxTime.inMilliseconds.toString(),
        help: 'max time to search, in milliseconds')
    ..addFlag('iterative-deepening',
        defaultsTo: defaultConfig.iterativeDeepening,
        help: 'enable iterative deepening')
    ..addOption('chance-node-probe-window',
        allowed: [
          'none',
          'overlapping',
          'centerToEnd',
          'edgeToEnd',
        ],
        defaultsTo: defaultConfig.chanceNodeProbeWindow.name,
        help: 'enable probing phase on chance nodes')
    ..addOption('transposition-table-size',
        defaultsTo: defaultConfig.transpositionTableSize.toString(),
        help: 'size (in entry count) of transposition table')
    ..addFlag('strict-transpositions',
        defaultsTo: defaultConfig.strictTranspositions,
        help: 'check == on transposition entries to avoid hash collisions')
    ..addOption('debug-setting', hide: true);

  @override
  EngineConfig buildConfig(ArgResults results) {
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
}
