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
    required this.expandDepth,
    required this.maxTime,
    this.cUct = 1.41,
    this.cPuct = 2.0,
  });

  /// Constant factor c for UCT formula.
  ///
  /// To perform a UCT search, ensure CpUCT is zero, otherwise a blend of both
  /// approaches will be used.
  ///
  /// Theoretically should equal sqrt(2), though higher values will explore more
  /// widely, lower values will explore more narrowly, which can improve
  /// results.
  final double cUct;

  /// Constant factor CpUCT for pUCT formula.
  ///
  /// To perform a pUCT search, ensure cUCT is zero, otherwise a blend of both
  /// approaches will be used.
  ///
  /// Also, to use pUCT as used by AlphaZero/lc0/etc, set [expandDepth] to 1.
  ///
  /// lc0 and alphaZero chance CpUCT over time, so this setting is subject to
  /// change to match their approach.
  final double cPuct;

  /// Max game branches to traverse before scoring the current node.
  ///
  /// Exploring deeper is beneficial when the game's scoring function is less
  /// predictive, however, this reduces the breadth of search which makes
  /// blunders more likely.
  final int maxDepth;

  /// Max number of playouts to perform before stopping search.
  ///
  /// Typically this number should be extremely high, and [maxTime] should be
  /// used to terminate search instead.
  final int maxPlayouts;

  /// How many nodes to add to the tree when performing an expansion.
  ///
  /// For a traditional UCT-style search, set this equal to [maxDepth]. For a
  /// traditional pUCT-style search, set this to 1.
  final int expandDepth;

  /// Duration before cutting off search.
  final Duration maxTime;

  @override
  Mcts<G> buildEngine<G extends Game<G>>() => Mcts<G>(Random(), this);
}

class Mcts<G extends Game<G>> implements Engine<G> {
  final MctsConfig config;
  final Random random;
  final SearchStats stats;
  late DateTime timeout;

  MctsNode<G, dynamic>? lastTree;

  Mcts(this.random, this.config) : stats = SearchStats(config.maxDepth);

  @override
  void clearCache() {
    lastTree = null;
  }

  Move<G> chooseBest(List<Move<G>> moves, G game) {
    final start = DateTime.now();
    timeout = start.add(config.maxTime);

    final cached = lastTree?.findChildGame(game, 2);
    final tree = cached ?? MctsMoveNode<G>(game, 0);
    lastTree = tree;
    for (int i = 0; true; ++i) {
      if (!DateTime.now().isBefore(timeout) || i == config.maxPlayouts) {
        break;
      }

      expand(tree, config.maxDepth, config.expandDepth);
    }

    final bestIdx =
        bestIdxBy<num>(moves.length, (i) => tree.getChild(i).simulations)!;
    return moves[bestIdx];
  }

  double expand(MctsNode<G, dynamic> tree, int depth, int expandDepth) {
    if (depth <= 0 ||
        expandDepth <= 0 ||
        tree.isTerminal ||
        !DateTime.now().isBefore(timeout)) {
      return tree.backpropagate(tree.score);
    }

    tree.simulations++;
    if (tree is MctsRandomNode<G>) {
      final pIdx = tree.chance.pickIndex(random.nextDouble());
      final next = tree.getChild(pIdx);
      return tree.backpropagate(expand(next, depth - 1, expandDepth));
    }

    if (tree is MctsMoveNode<G>) {
      final child = tree.select(random, config);
      final newExpandDepth =
          child.simulations == 0 ? expandDepth - 1 : expandDepth;

      if (newExpandDepth <= 0) {
        return tree.backpropagate(child.score);
      }

      return tree.backpropagate(expand(child, depth - 1, newExpandDepth));
    }

    throw 'unreachable';
  }
}

abstract class MctsNode<G extends Game<G>, E> {
  int simulations = 0;
  double q = 0;
  final G game;
  MctsNode<G, dynamic>? child;
  MctsNode<G, dynamic>? sibling;
  final int edgeIdx;
  MctsNode(this.game, this.edgeIdx);

  double? _score;
  double get score => _score ??= computeScore();

  double computeScore() => game.score;

  MctsNode<G, dynamic> getChild(int edgeIdx) {
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

  MctsNode<G, dynamic> select(Random random, MctsConfig config) {
    if (config.cPuct != 0) {
      return getChild(bestIdxBy<num>(
          edges.length,
          (i) => getChild(i)
              .scoreForSelect(simulations, config.cUct, config.cPuct))!);
    }

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
      _edgeScoreCache[node.edgeIdx] =
          node.scoreForSelect(simulations, config.cUct, config.cPuct);
      node = node.sibling;
    }

    final bestIdx = bestIdxBy<num>(edges.length, (i) => _edgeScoreCache[i])!;
    return getChild(bestIdx);
  }

  List<E> get edges;
  MctsNode<G, dynamic> walk(E edge, int edgeIdx);

  bool get isTerminal => edges.isEmpty;

  double backpropagate(double score) {
    final factor = game.isMaxing ? 1.0 : -1.0;
    q = q * ((simulations - 1) / simulations) + factor * score / simulations;
    return score;
  }

  MctsNode<G, dynamic>? findChildGame(G game, int searchDepth) {
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

  /// The additional value we assign this node, in addition to q, to account for
  /// uncertainty and encourage it to be searched, specifically for UCT.
  double _uctValue(int parentSimulations, double cUct) {
    if (cUct == 0) {
      // Caution, 0 * double.infinity == NaN. In this case we do want zero.
      return 0;
    }

    if (simulations == 0) {
      return double.infinity;
    }

    return cUct * sqrt(log(parentSimulations) / simulations);
  }

  /// The additional value we assign this node, in addition to q, to account for
  /// uncertainty and encourage it to be searched, specifically for pUCT.
  double _pUctValue(int parentSimulations, double cPUct) {
    return cPUct * (score + 1.0) * sqrt(parentSimulations) / (simulations + 1);
  }

  /// Performs a blend of UCT scoring and pUCT scoring based on scaling factors
  /// c for each.
  double scoreForSelect(int parentSimulations, double cUct, double cPUct) {
    final uctVal = _uctValue(parentSimulations, cUct);
    final pUctVal = _pUctValue(parentSimulations, cPUct);
    return (q + 1.0) + uctVal + pUctVal;
  }
}

class MctsMoveNode<G extends Game<G>> extends MctsNode<G, Move<G>> {
  @override
  final List<Move<G>> edges;

  MctsMoveNode(super.game, super.edgeIdx) : edges = game.getMoves();

  @override
  MctsNode<G, dynamic> walk(Move<G> edge, int edgeIdx) {
    return MctsRandomNode(game, edgeIdx, edge.perform(game));
  }
}

class MctsRandomNode<G extends Game<G>> extends MctsNode<G, Possibility<G>> {
  final Chance<G> chance;

  @override
  // TODO: should this traverse into children so they can also cache this?
  double computeScore() => chance.expectedValue((g) => g.score);

  MctsRandomNode(super.game, super.edgeIdx, this.chance);

  @override
  List<Possibility<G>> get edges => chance.possibilities;

  @override
  MctsNode<G, dynamic> walk(Possibility<G> edge, int edgeIdx) {
    return MctsMoveNode(edge.outcome, edgeIdx);
  }
}
