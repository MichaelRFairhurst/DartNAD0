import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/serve/serve_command.dart';
import 'package:dartnad0/src/time/time_control.dart';
import 'package:test/test.dart';

void main() {
  test('make time control, none specified', () {
    final cmd =
        ServeCommand<TestGame>((_) => TestGame(), configSpecs: [], engines: {});

    try {
      cmd.makeMoveTimer({'other': 'params', 'but': 'not', 'theright': 'ones'});
    } on FormatException catch (_) {
      return;
    }

    expect(false, isTrue);
  });

  test('make time control, time and reltime both specified', () {
    final cmd =
        ServeCommand<TestGame>((_) => TestGame(), configSpecs: [], engines: {});

    try {
      cmd.makeMoveTimer({'time': '123', 'reltime': '123'});
    } on FormatException catch (_) {
      return;
    }

    expect(false, isTrue);
  });

  test('make relative time control', () {
    final cmd =
        ServeCommand<TestGame>((_) => TestGame(), configSpecs: [], engines: {});

    final tc = cmd.makeMoveTimer({'reltime': '123'});

    expect(tc, isA<RelativeTimeControl>());
    expect((tc as RelativeTimeControl).moveDuration,
        equals(Duration(milliseconds: 123)));
  });

  test('make absolute time control', () {
    final cmd =
        ServeCommand<TestGame>((_) => TestGame(), configSpecs: [], engines: {});

    final tc = cmd.makeMoveTimer({'time': '123'});

    expect(tc, isA<AbsoluteTimeControl>());
    expect((tc as AbsoluteTimeControl).endTime,
        equals(DateTime.fromMillisecondsSinceEpoch(123)));
  });
}

class TestGame extends Game<TestGame> {
  @override
  List<Move<TestGame>> getMoves() {
    throw UnimplementedError();
  }

  @override
  bool get isMaxing => throw UnimplementedError();

  @override
  double get score => throw UnimplementedError();
}
