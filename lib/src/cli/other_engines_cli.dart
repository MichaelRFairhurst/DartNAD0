import 'package:args/args.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/other_engines/nth_engine.dart';
import 'package:dartnad0/src/other_engines/random_engine.dart';

class RandomEngineCli extends CliEngine {
  @override
  String get name => 'random';

  @override
  String get description => 'Simple engine which just picks random moves.';

  @override
  String get example => 'random --seed 0';

  @override
  ArgParser configureParser() => ArgParser()
    ..addOption('seed', abbr: 's', help: 'seed for random move selection.');

  @override
  EngineConfig buildConfig(ArgResults results) {
    return RandomEngineConfig(
      seed: results.wasParsed('seed') ? int.parse(results['seed']) : null,
    );
  }
}

class NthEngineCli extends CliEngine {
  @override
  String get name => 'nth';

  @override
  String get description => 'Simple engine which always picks the nth move.';

  @override
  String get example => 'nth -n 0';

  @override
  ArgParser configureParser() => ArgParser()
    ..addFlag('from-end',
        abbr: 'e', help: 'select nth move from the end instead of the start')
    ..addOption('n',
        abbr: 'n',
        defaultsTo: '0',
        help: '0-based index for which move to select');

  @override
  EngineConfig buildConfig(ArgResults results) {
    return NthEngineConfig(
      direction: results['from-end'] ? Direction.fromEnd : Direction.fromStart,
      offset: int.parse(results['n']),
    );
  }
}
