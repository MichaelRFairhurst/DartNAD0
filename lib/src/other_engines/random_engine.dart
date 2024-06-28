import 'dart:math';

import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/time/time_control.dart';

class RandomEngineConfig extends EngineConfig {
  final int? seed;

  RandomEngineConfig({
    this.seed,
  });

  RandomEngine<G> buildEngine<G extends Game<G>>() => RandomEngine<G>(seed);
}

class RandomEngine<G extends Game<G>> extends Engine<G> {
  final Random random;

  RandomEngine([int? seed]) : random = Random(seed);

  @override
  Future<Move<G>> chooseBest(
      List<Move<G>> moves, G game, TimeControl timeControl) async {
    return moves[random.nextInt(moves.length)];
  }

  @override
  void clearCache() {
    // noop
  }

  @override
  final stats = NullSearchStats();
}
