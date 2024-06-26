import 'package:dartnad0/src/chance.dart';
import 'package:dartnad0/src/game.dart';

abstract class Move<G extends Game<G>> {
  String get description;

  Chance<G> perform(G game);
}
