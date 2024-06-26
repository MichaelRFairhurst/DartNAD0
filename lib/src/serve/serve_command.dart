import 'dart:async';

import 'package:expectiminimax/src/cli/parse_config_command.dart';
import 'package:expectiminimax/src/config.dart';
import 'package:expectiminimax/src/engine.dart';
import 'package:expectiminimax/src/game.dart';
import 'package:expectiminimax/src/mcts.dart';
import 'package:shelf/shelf.dart';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:thread/thread.dart';

/// Allows CLI to run a configured engine as a service bound to a port.
///
/// The server that's launched supports:
/// - POST /<sessionId>/chooseBest
/// - GET /<sessionId>/clearCache
///
/// The provided engine config will be used to create an engine for each
/// session id. There is no need to create a session by any means other than
/// calling one of these APIs. Sessions are cleaned up after inactivity,
/// configurable by the `--keepalive` argument (in seconds).
///
/// Sessions are each given their own thread and construct their own engine.
///
/// The result of running this command can be used in other commands as its own
/// engine, named `served`. For instance:
///
/// ```bash
/// dart your_wrapper.dart serve --port 8000 xmm --max-depth 25
/// dart your_wrapper.dart watch served localhost:8000
/// ```
///
/// Using this class requires implementing [decoder] in order to parse a Game
/// out of a String. You may choose JSON, or any other encoding. For instance,
/// chess could use FEN representation.
class ServeCommand<G extends Game<G>> extends ParseConfigCommand {
  final name = 'serve';
  final description = 'Serve a game engine locally at a given port';

  final G Function(String) decoder;

  final _sessions = <String, _Session>{};

  ServeCommand(this.decoder, ExpectiminimaxConfig defaultXmmConfig,
      MctsConfig defaultMctsConfig, List<List<String>> configSpecs)
      : super(defaultXmmConfig, defaultMctsConfig, configSpecs) {
    argParser.addOption('port',
        abbr: 'p', defaultsTo: '8080', help: 'Port to serve this engine on.');
    argParser.addOption('keepalive',
        abbr: 'k',
        defaultsTo: Duration(minutes: 2).inSeconds.toString(),
        help: 'How long to keep sessions alive without activity, in seconds');
  }

  /// Start a thread to be used by a session, with a private instance of the
  /// specified engine.
  ///
  /// This is static because if it were an instance method, the resulting thread
  /// would be bound to [this], which has the property [_sessions], which
  /// includes [Thread]s, which can not be sent across isolates.
  static Thread startThread<G extends Game<G>>(
      EngineConfig config, G Function(String) decoder) {
    return Thread((events) {
      final engine = config.buildEngine<G>();
      events.on<String>('chooseBest', (str) async {
        final game = decoder(str);
        final moves = game.getMoves();
        final move = await engine.chooseBest(moves, game);
        events.emit('bestMove', moves.indexOf(move));
      });

      events.on<Null>('clearCache', (_) {
        engine.clearCache();
      });
    });
  }

  @override
  void runWithConfigs(List<EngineConfig> configs) {
    final config = configs[0];
    final port = int.parse(argResults!['port']);
    final keepalive = Duration(seconds: int.parse(argResults!['keepalive']));
    final api = Router();

    api.post('/<sid>/chooseBest', (request, String sid) async {
      final session = _sessions.putIfAbsent(sid, () {
        print('Starting new session: $sid');
        return _Session(startThread(config, decoder));
      });
      final body = await request.readAsString();

      session.thread.emit('chooseBest', body);
      final idx = await session.thread.once<int>('bestMove', (idx) => idx);
      session.lastAccessed = DateTime.now();

      return Response.ok('$idx');
    });

    api.get('/<sid>/clearCache', (request, String sid) async {
      final session = _sessions[sid];
      if (session != null) {
        final thread = session.thread;
        thread.emit('clearCache', null);
        session.lastAccessed = DateTime.now();
      }

      return Response.ok('');
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      final killBefore = DateTime.now().subtract(keepalive);
      final removedKeys = _sessions.keys.toSet();
      _sessions.removeWhere((_, s) => s.lastAccessed.isBefore(killBefore));
      final keptKeys = _sessions.keys.toSet();
      removedKeys.removeAll(keptKeys);
      if (removedKeys.isNotEmpty) {
        print('Killed sessions ${removedKeys}');
      }
    });

    final pipeline = const Pipeline().addHandler(api);
    shelf_io.serve(pipeline, 'localhost', port);
  }
}

class _Session {
  DateTime lastAccessed;
  final Thread thread;

  _Session(this.thread) : lastAccessed = DateTime.now();
}
