import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/time/time_control.dart';

class NthEngineConfig extends EngineConfig {
  final Direction direction;
  final int offset;

  NthEngineConfig({
    this.direction = Direction.fromStart,
    required this.offset,
  });

  NthEngine<G> buildEngine<G extends Game<G>>() => NthEngine<G>(this);
}

enum Direction {
  fromStart,
  fromEnd,
}

/// An engine which always picks the nth move (from beginning or end).
///
/// Useful for testing quality of move ordering, where the first move should be
/// typically the best and the last move should be typically the worst.
class NthEngine<G extends Game<G>> extends Engine<G> {
  final NthEngineConfig config;

  NthEngine(this.config);

  @override
  Future<Move<G>> chooseBest(
      List<Move<G>> moves, G game, TimeControl timeControl) async {
    final Iterable<Move<G>> orderedMoves;
    switch (config.direction) {
      case Direction.fromStart:
        orderedMoves = moves;
        break;
      case Direction.fromEnd:
        orderedMoves = moves.reversed;
    }

    if (moves.length <= config.offset) {
      return orderedMoves.last;
    }

    return orderedMoves.skip(config.offset).first;
  }

  @override
  void clearCache() {
    // noop
  }

  @override
  final stats = NullSearchStats();
}
