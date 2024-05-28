import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/game.dart';

abstract class Move<G extends Game<G>> {
  String get description;

  Chance<G> perform(G game);
}
