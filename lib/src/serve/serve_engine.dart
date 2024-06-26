import 'dart:async';
import 'dart:math';

import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/time_control.dart';
import 'package:http/http.dart' as http;

/// An engine served over http instead of run locally.
///
/// Note that each instance of this class creates a private session ID on
/// construct, and that the server will not multithread multiple requests for
/// same session ID. Therefore, sending instances of this engine across isolates
/// will result in counter intiutive behavior of not threading.
class ServedEngine<G extends Game<G>> implements Engine<G> {
  /// Server and/or port where API is served (e.g. localhost:8080).
  final String server;

  /// The session ID for the API, a unique key used for multithreading.
  final String _sessionId;

  @override
  // TODO: Decide how to handle this & other types of engine stats.
  final stats = SearchStats(1);

  ServedEngine(this.server)
      : _sessionId = Random().nextInt(4294967296).toRadixString(16);

  @override
  Future<Move<G>> chooseBest(
      List<Move<G>> moves, G game, TimeControl timeControl) async {
    final uri = Uri.http(server, '/$_sessionId/chooseBest');
    for (var retries = 0;; ++retries) {
      try {
        // TODO: Pass along time control!
        final response = await http.post(uri, body: game.encode());
        return moves[int.parse(response.body)];
      } catch (e) {
        if (retries >= 5) {
          rethrow;
        }

        print('Issue posting to $uri: $e');
      }
    }
  }

  @override
  void clearCache() {
    final uri = Uri.http(server, '/$_sessionId/clearCache');
    // TODO: Make this method async, and await?
    http.post(uri);
  }
}
