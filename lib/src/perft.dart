import 'package:args/command_runner.dart';
import 'package:dartnad0/src/game.dart';

/// A class to run perft to variable depth on the command line. See [CliTools]
/// for more.
class PerftCommand<G extends Game<G>> extends Command {
  final name = 'perft';
  final description = 'Performance tool which generates all moves for a game to'
      ' a specified depth';

  /// The root of the tree to explore during [perft].
  final G startingGame;

  /// Generate a command that runs off of this root.
  PerftCommand(this.startingGame) {
    argParser.addOption('depth',
        abbr: 'd', defaultsTo: '5', help: 'Depth of moves to generate');
  }

  @override
  void run() {
    final depth = int.parse(argResults!['depth']);
    final duration = perft(startingGame, depth);
    print('Performed all possible moves to depth $depth.');
    print('elapsed: ${duration.inMilliseconds}ms');
  }
}

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
