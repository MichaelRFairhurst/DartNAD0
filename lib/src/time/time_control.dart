/// A class for telling an engine how long it has to compute the best move.
///
/// A time control may be an absolute end time, or a fixed duration. The former
/// means that all overhead (most notably, http overhead) will be considered a
/// part of the search time, or essentially, "real world conditions." The latter
/// means that http overhead (etc) is "free," which is useful for benchmarking.
///
/// In order to support both use cases, make sure to call [constrain] before
/// checking if a time control [isExceeded].
abstract class TimeControl {
  /// Check if the time control is exceeded.
  ///
  /// To support relative time control, you MUST call [constrain] before this
  /// method, even if you pass in null.
  bool isExceeded();

  /// The time that the time control expires.
  ///
  /// To support relative time control, you MUST call [constrain] before this
  /// method, even if you pass in null.
  DateTime get endTime;

  /// Constrain the time control to not exceed now plus the provided [maxTime].
  ///
  /// This method must be called before [isExceeded] in order to start relative
  /// time control.
  void constrain(Duration? maxTime);

  /// Create the HTTP query parameter for sending this [TimeControl] over http.
  Map<String, String> toQueryParameters();
}

/// A [TimeControl] that has a move [Duration] instead of a fixed end time.
///
/// That duration starts when [constrain] is called.
class RelativeTimeControl implements TimeControl {
  final Duration moveDuration;

  RelativeTimeControl(this.moveDuration);

  DateTime? _endTime;

  @override
  void constrain(Duration? maxTime) {
    if (maxTime == null) {
      _endTime = DateTime.now().add(moveDuration);
    } else if (moveDuration.compareTo(maxTime) == -1) {
      _endTime = DateTime.now().add(moveDuration);
    } else {
      _endTime = DateTime.now().add(maxTime);
    }
  }

  /// Check if an arbitrary time will be exceeded; useful for testing.
  bool isExceededFor(DateTime time) => !time.isBefore(_endTime!);

  @override
  bool isExceeded() => isExceededFor(DateTime.now());

  @override
  // TODO: How should we handle null here?
  DateTime get endTime => _endTime!;

  @override
  String toString() => 'relative time control, $moveDuration, endtime $_endTime';

  @override
  Map<String, String> toQueryParameters() {
    if (_endTime != null) {
      throw 'Cannot http encode relative time control that has been started';
    }
    return {'reltime': moveDuration.inMilliseconds.toString()};
  }
}

/// A [TimeControl] that has a fixed end time.
class AbsoluteTimeControl implements TimeControl {
  DateTime _endTime;

  AbsoluteTimeControl(this._endTime);

  @override
  void constrain(Duration? maxTime) {
    if (maxTime == null) {
      return;
    }

    final newTime = DateTime.now().add(maxTime);
    if (newTime.isBefore(_endTime)) {
      _endTime = newTime;
    }
  }

  /// Check if an arbitrary time will be exceeded; useful for testing.
  bool isExceededFor(DateTime time) => !time.isBefore(_endTime);

  @override
  bool isExceeded() => isExceededFor(DateTime.now());

  @override
  DateTime get endTime => _endTime;

  @override
  String toString() => 'absolute time control, endtime $_endTime';

  @override
  Map<String, String> toQueryParameters() =>
      {'time': endTime.millisecondsSinceEpoch.toString()};
}
