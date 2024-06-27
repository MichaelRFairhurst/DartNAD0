import 'package:args/args.dart';
import 'package:dartnad0/src/engine.dart';

abstract class CliEngine {
  String get name;

  String get description;

  String get example;

  String summaryString(String parentCommand) => '''
    ${name.padRight(18)}$description
    ${' ' * 18}Example: $parentCommand $example''';

  String get usage => '''
'$name' engine config options:

${configureParser().usage.splitMapJoin(
            '\n',
            onNonMatch: (line) => '    $line',
          )}
''';

  ArgParser configureParser();

  EngineConfig buildConfig(ArgResults argResults);
}
