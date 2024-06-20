import 'dart:math';

import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/stats.dart';

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
  Move<G> chooseBest(List<Move<G>> moves, G game) {
    return moves[random.nextInt(moves.length)];
  }

  @override
  void clearCache() {
    // noop
  }

  @override
  final stats = SearchStats(1);
}
