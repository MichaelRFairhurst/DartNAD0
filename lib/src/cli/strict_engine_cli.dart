import 'package:args/args.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/time/strict_engine_wrapper.dart';

/// A wrapper object which adds a `--strict` flag to an engine, to use strict
/// timing for that engine (kill search if it exceeds time).
class StrictEngineCli extends CliEngine {
  final CliEngine baseEngine;

  StrictEngineCli(this.baseEngine);

  @override
  String get name => baseEngine.name;

  @override
  String get description => baseEngine.description;

  @override
  String get example => baseEngine.example;

  @override
  ArgParser configureParser() => baseEngine.configureParser()
    ..addFlag(
      'strict-time-control',
      defaultsTo: false,
      negatable: false,
      help: 'Kill search if it goes over time. Automatically enabled if'
          ' --strict-time-buffer is specified.',
    )
    ..addOption(
      'strict-time-buffer',
      help: 'Time to allot to ensure engine does not exceed move timer.'
          ' Automatically enables --strict-time-control if specified.',
    );

  @override
  EngineConfig buildConfig(ArgResults results) {
    final config = baseEngine.buildConfig(results);

    final strict = results['strict-time-control'] ||
        results.wasParsed('strict-time-buffer');
    final buffer = results['strict-time-buffer'];

    return strict
        ? StrictEngineConfigWrapper(config,
            buffer: Duration(milliseconds: int.parse(buffer ?? '0')))
        : config;
  }
}
