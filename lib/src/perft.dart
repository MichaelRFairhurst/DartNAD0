import 'package:expectiminimax/src/game.dart';

Duration perft<G extends Game<G>>(G game, int depth) {
  final startTime = DateTime.now();
  _perft(game, depth);
  return DateTime.now().difference(startTime);
}

void _perft<G extends Game<G>>(G game, int depth) {
  for (final move in game.getMoves()) {
    final chance = move.perform(game);

    if (depth <= 0) {
      continue;
    }

    for (final possibility in chance.possibilities) {
      _perft(possibility.outcome, depth - 1);
    }
  }
}
