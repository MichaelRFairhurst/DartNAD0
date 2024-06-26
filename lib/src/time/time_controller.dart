import 'package:dartnad0/src/time/time_control.dart';

class TimeController {
  final bool absolute;
  final Duration moveTime;

  const TimeController(this.moveTime, {this.absolute = true});

  TimeControl makeMoveTimer() {
    if (absolute) {
      return AbsoluteTimeControl(DateTime.now().add(moveTime));
    } else {
      return RelativeTimeControl(moveTime);
    }
  }
}
