import 'package:args/args.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/serve/served_engine_config.dart';

class ServedEngineCli extends CliEngine {
  @override
  String get name => 'served';

  @override
  String get description =>
      'Engine running with API launched via `serve` command.';

  @override
  String get example => 'served localhost:8080';

  @override
  ArgParser configureParser() => ArgParser();

  @override
  EngineConfig buildConfig(ArgResults results) {
    if (results.rest.length != 1) {
      throw FormatException('wrong number of arguments provided, expected'
          ' hostname, got ${results.rest}');
    }
    return ServedEngineConfig(server: results.rest.single);
  }
}
