import 'package:args/command_runner.dart';
import 'package:dartnad0/src/time/time_controller.dart';

mixin TimeControlMixin on Command {
  void addTimeControlFlags(TimeController defaults) {
    argParser
      ..addOption(
        'time-control',
        abbr: 't',
        defaultsTo: defaults.moveTime.inMilliseconds.toString(),
        help: 'Maximimum move time (in ms)',
      )
      ..addFlag(
        'reltime',
        defaultsTo: !defaults.absolute,
        help: 'Use relative (not absolute) time control, avoiding http overhead'
            ' etc. Can be useful for benchmarking.',
      )
      ..addFlag(
        'strict-time-control',
        defaultsTo: defaults.strict,
        help: 'Use strict time control, run searches on an isolate and kill'
            ' that isolate if it goes over time.',
      )
      ..addOption(
        'strict-time-buffer',
        defaultsTo: defaults.strictTimeBuffer.inMilliseconds.toString(),
        help: 'Time to allot to ensure engines do not exceed move timer.'
            ' Automatically enables --strict-time-control if specified.',
      );
  }

  TimeController parseTimeController() {
    return TimeController(
      Duration(milliseconds: int.parse(argResults!['time-control'])),
      absolute: !argResults!['reltime'],
      strict: argResults!['strict-time-control'] ||
          argResults!.wasParsed('strict-time-control'),
      strictTimeBuffer:
          Duration(milliseconds: int.parse(argResults!['strict-time-buffer'])),
    );
  }
}
