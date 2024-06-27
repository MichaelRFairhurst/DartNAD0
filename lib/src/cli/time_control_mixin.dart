import 'package:args/command_runner.dart';
import 'package:dartnad0/src/time/time_controller.dart';

mixin TimeControlMixin on Command {
  void addTimeControlFlags(TimeController defaults) {
    argParser.addOption(
      'time-control',
      abbr: 't',
      defaultsTo: defaults.moveTime.inMilliseconds.toString(),
      help: 'Maximimum move time (in ms)',
    );

    argParser.addFlag(
      'reltime',
      defaultsTo: !defaults.absolute,
      help: 'Use relative (not absolute) time control, avoiding http overhead'
          ' etc. Can be useful for benchmarking.',
    );
  }

  TimeController parseTimeController() {
    return TimeController(
      Duration(milliseconds: int.parse(argResults!['time-control'])),
      absolute: !argResults!['reltime'],
    );
  }
}
