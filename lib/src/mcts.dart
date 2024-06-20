import 'dart:math';

import 'package:expectiminimax/src/chance.dart';
import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/move.dart';
import 'package:expectiminimax/src/stats.dart';
import 'package:expectiminimax/src/util.dart';

class MctsConfig implements EngineConfig {
  MctsConfig({
    required this.maxDepth,
    required this.maxPlayouts,
    required this.maxTime,
    this.cUct = 1.41,
  });

  final double cUct;
  final int maxDepth;
  final int maxPlayouts;
  final Duration maxTime;

  Mcts<G> buildEngine<G extends Game<G>>() => Mcts<G>(Random(), this);
}

class Mcts<G extends Game<G>> implements Engine<G> {
  final MctsConfig config;
  final Random random;
  final SearchStats stats;
  late DateTime timeout;

  _MctsNode<G, dynamic>? lastTree;

  Mcts(this.random, this.config) : stats = SearchStats(config.maxDepth);

  @override
  void clearCache() {
    lastTree = null;
  }

  Move<G> chooseBest(List<Move<G>> moves, G game) {
    final start = DateTime.now();
    timeout = start.add(config.maxTime);

    final cached = lastTree?.findChildGame(game, 2);
    final tree = cached ?? _MctsMoveNode<G>(game, 0);
    lastTree = tree;
    for (int i = 0; true; ++i) {
      if (!DateTime.now().isBefore(timeout) || i == config.maxPlayouts) {
        break;
      }

	  _simulate(tree, 0);
    }

    final bestIdx =
        bestIdxBy<num>(moves.length, (i) => tree.getChild(i).simulations)!;
    return moves[bestIdx];
  }

  bool _simulate(_MctsNode<G, dynamic> tree, int depth) {
    if (tree.isTerminal || !DateTime.now().isBefore(timeout)) {
      return tree.backpropagate(tree.game.score > 0);
    }

    if (tree is _MctsRandomNode<G>) {
      final pIdx = tree.chance.pickIndex(random.nextDouble());
      final next = tree.getChild(pIdx);
      return tree.backpropagate(_simulate(next, depth + 1));
    }

    if (tree is _MctsMoveNode<G>) {
      if (depth >= config.maxDepth) {
        return tree.backpropagate(tree.game.score > 0);
      } else {
        final child = tree.select(random, config);
        return tree.backpropagate(_simulate(child, depth + 1));
      }
    }

    throw 'unreachable';
  }
}

abstract class _MctsNode<G extends Game<G>, E> {
  int wins = 0;
  int simulations = 0;
  double q = 0;
  final G game;
  _MctsNode<G, dynamic>? child;
  _MctsNode<G, dynamic>? sibling;
  int edgeIdx;
  _MctsNode(this.game, this.edgeIdx);

  double? _score;
  double get score => _score ??= game.score;

  _MctsNode<G, dynamic> getChild(int edgeIdx) {
    final edge = edges[edgeIdx];
    if (child == null) {
      return child = walk(edge, edgeIdx);
    }

    var node = child!;
    while (true) {
      if (node.edgeIdx == edgeIdx) {
        return node;
      }

      if (node.sibling == null) {
        return node.sibling = walk(edge, edgeIdx);
      } else {
        node = node.sibling!;
      }
    }
  }

  static final _edgeScoreCache = <double>[];

  _MctsNode<G, dynamic> select(Random random, MctsConfig config) {
    if (child == null) {
      return getChild(random.nextInt(edges.length));
    }

    if (_edgeScoreCache.length < edges.length) {
      _edgeScoreCache.addAll(Iterable.generate(
          edges.length - _edgeScoreCache.length, (_) => double.infinity));
    }

    for (int i = 0; i < edges.length; ++i) {
      _edgeScoreCache[i] = double.infinity;
    }

    var node = child;
    while (node != null) {
      _edgeScoreCache[node.edgeIdx] = node.uct(simulations, config.cUct);
      node = node.sibling;
    }

    final bestIdx = bestIdxBy<num>(edges.length, (i) => _edgeScoreCache[i])!;
    return getChild(bestIdx);
  }

  List<E> get edges;
  _MctsNode<G, dynamic> walk(E edge, int edgeIdx);

  bool get isTerminal => edges.isEmpty;

  bool backpropagate(bool winner) {
    simulations++;
    if (game.isMaxing == winner) {
      wins++;
    }
    return winner;
  }

  _MctsNode<G, dynamic>? findChildGame(G game, int searchDepth) {
    if (this.game == game) {
      return this;
    }

    if (searchDepth <= 0 || this.edges.isEmpty) {
      return null;
    }

    var node = child;

    while (node != null) {
      final result = node.findChildGame(game, searchDepth - 1);
      if (result != null) {
        return result;
      }

      node = node.sibling;
    }

    return null;
  }

  double uct(int parentSimulations, double cUct) {
    if (simulations == 0) {
      return double.infinity;
    }
    return wins / simulations +
        cUct * sqrt(log(parentSimulations) / simulations);
  }
}

class _MctsMoveNode<G extends Game<G>> extends _MctsNode<G, Move<G>> {
  @override
  final List<Move<G>> edges;

  _MctsMoveNode(super.game, super.edgeIdx) : edges = game.getMoves();

  @override
  _MctsNode<G, dynamic> walk(Move<G> edge, int edgeIdx) {
    return _MctsRandomNode(game, edgeIdx, edge.perform(game));
  }
}

class _MctsRandomNode<G extends Game<G>> extends _MctsNode<G, Possibility<G>> {
  final Chance<G> chance;

  _MctsRandomNode(super.game, super.edgeIdx, this.chance);

  @override
  List<Possibility<G>> get edges => chance.possibilities;

  @override
  _MctsNode<G, dynamic> walk(Possibility<G> edge, int edgeIdx) {
    return _MctsMoveNode(edge.outcome, edgeIdx);
  }
}
