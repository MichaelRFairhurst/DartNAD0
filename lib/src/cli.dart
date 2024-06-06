import 'package:args/command_runner.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/perft.dart';

class CliTools<G extends Game<G>> {
  final G startingGame;
  final commandRunner = CommandRunner('expectiminimax cli',
      'Pre-built CLI tools to run expectiminimax on custom games');

  CliTools({required this.startingGame}) {
	commandRunner.addCommand(PerftCommand(startingGame));
  }

  void run(List<String> args) {
	commandRunner.run(args);
  }
}
