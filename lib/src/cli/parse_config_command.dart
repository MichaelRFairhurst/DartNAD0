import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dartnad0/src/cli/cli_engine.dart';
import 'package:dartnad0/src/cli/time_control_mixin.dart';
import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/time/time_controller.dart';

abstract class ParseConfigCommand extends Command {
  List<List<String>> configSpecs;
  final Map<String, CliEngine> engines;

  ParseConfigCommand({required this.engines, required this.configSpecs}) {
    for (final engine in engines.values) {
      argParser.addCommand(engine.name, engine.configureParser());
    }
  }

  void runWithConfigs(List<EngineConfig> configs);

  @override
  String get usageFooter => '''

Additionally, running this command requires specifying one or more engines:

${engines.values.map((e) => e.summaryString(name)).join('\n')}

Some commands can accept multiple engines. These engines may be separated with '--vs' flags.

    --vs              Specify an additional engine to $name.
                      Example: $name xmm --max-depth 8 --vs mcts --max-playouts 1000 --vs random

${engines.values.map((e) => e.usage).join('\n')}
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
    for (final engine in engines.values) {
      configParser.addCommand(engine.name, engine.configureParser());
    }

    try {
      final TimeController? timeController;
      if (this is TimeControlMixin) {
        timeController = (this as TimeControlMixin).parseTimeController();
      } else {
        timeController = null;
      }

      EngineConfig restrictConfig(EngineConfig config) {
        if (timeController == null) {
          return config;
        } else {
          return timeController.restrictConfig(config);
        }
      }

      final configs = [
        restrictConfig(getPrimaryConfig()),
        ...configSpecs.map((args) {
          if (args.first.startsWith('-')) {
            throw 'Error: Specify an engine before engine flags: "$args"';
          }
          if (!engines.keys.contains(args.first)) {
            throw 'Error: Invalid engine name: "${args.first}"';
          }
          try {
            return restrictConfig(
                getConfigFromResults(configParser.parse(args)));
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

  EngineConfig getPrimaryConfig() => getConfigFromResults(argResults!);

  EngineConfig getConfigFromResults(ArgResults results) {
    final engineCli = engines[results.command?.name];
    if (engineCli == null) {
      throw 'bad engine name ${results.command?.name}';
    }

    return engineCli.buildConfig(results.command!);
  }
}
