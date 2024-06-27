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

  /// How much time is allotted for each move.
  final Duration moveTime;

  const TimeController(this.moveTime, {this.absolute = true});

  /// Create a [TimeControl] for timing a single move.
  TimeControl makeMoveTimer() {
    if (absolute) {
      return AbsoluteTimeControl(DateTime.now().add(moveTime));
    } else {
      return RelativeTimeControl(moveTime);
    }
  }
}
