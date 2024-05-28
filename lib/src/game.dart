import 'package:expectiminimax/src/move.dart';

abstract class Game<G extends Game<G>> {
  double get score;
  bool get isMaxing;

  List<Move<G>> getMoves();
}
