import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/time/strict_engine_wrapper.dart';
import 'package:dartnad0/src/time/time_control.dart';

/// Class for creating move timers and/or killing engines that go over allotted
/// move times.
class TimeController {
  /// Whether to use absolute or relative move timers.
  ///
  /// Relative timers will allow an engine to determine when the move timer
  /// starts. This allows, for instance, http overhead to be "free." Absolute
  /// timers use a fixed end time. So http overhead will reduce search time, and
  /// clock differences may come into play as well.
  final bool absolute;

  /// Whether to abort search engines that go over time (commonly, from GC
  /// pauses).
  ///
  /// If set to true, engines will be started on a thread and the thread will be
  /// killed if it goes over the allotted time.
  final bool strict;

  /// How much time is allotted for each move.
  final Duration moveTime;

  /// How much time is reserved, in strict mode, to avoid exceeding move timer.
  final Duration strictTimeBuffer;

  const TimeController(
    this.moveTime, {
    this.absolute = true,
    this.strict = false,
	this.strictTimeBuffer = const Duration(milliseconds: 10),
  });

  /// Create a [TimeControl] for timing a single move.
  TimeControl makeMoveTimer() {
    if (absolute) {
      return AbsoluteTimeControl(DateTime.now().add(moveTime));
    } else {
      return RelativeTimeControl(moveTime);
    }
  }

  /// Wraps an engine config, if [strict] is true, with a strict timer that
  /// kills searches which go over time.
  EngineConfig restrictConfig(EngineConfig config) {
    if (!strict) {
      return config;
    }

    if (config is StrictEngineConfigWrapper) {
      return config;
    } else {
      return StrictEngineConfigWrapper(config, buffer: strictTimeBuffer);
    }
  }
}
