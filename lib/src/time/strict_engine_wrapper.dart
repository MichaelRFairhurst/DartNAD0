import 'dart:async';

import 'package:dartnad0/src/engine.dart';
import 'package:dartnad0/src/game.dart';
import 'package:dartnad0/src/move.dart';
import 'package:dartnad0/src/stats.dart';
import 'package:dartnad0/src/time/strict_time_stats.dart';
import 'package:dartnad0/src/time/time_control.dart';
import 'package:thread/thread.dart';

class StrictEngineConfigWrapper implements EngineConfig {
  final EngineConfig config;
  final Duration buffer;

  StrictEngineConfigWrapper(this.config, {required this.buffer});

  @override
  Engine<G> buildEngine<G extends Game<G>>() =>
      StrictEngineWrapper<G>(config, buffer: buffer);
}

/// Runs an engine on a new isolate in order to enforce strict time control.
class StrictEngineWrapper<G extends Game<G>> implements Engine<G> {
  final EngineConfig config;
  final Duration buffer;

  Thread? _engineThread;

  StrictEngineWrapper(this.config, {required this.buffer}) {
    _getThread();
  }

  @override
  Future<Move<G>> chooseBest(
      List<Move<G>> moves, G game, TimeControl timeControl) {
    timeControl.constrain(null);
    ++stats.searchCount;
    final thread = _getThread();
    final completer = Completer<Move<G>>();

    thread.once<Move<G>>('chooseBestResult', (move) {
      if (completer.isCompleted) {
        return;
      }
      if (timeControl.isExceeded()) {
        completer.complete(moves[0]);
      } else {
        completer.complete(move);
      }
    });

    Future.delayed(timeControl.endTime.difference(DateTime.now())).then((_) {
      if (completer.isCompleted) {
        return;
      }
      //print('[killing search thread for going over time]');
      thread.stop();
      thread.events?.receivePort.close();
      _engineThread = null;
      ++stats.killedSearches;
      _getThread();
      completer.complete(moves[0]);
    });

    thread.emit(
        'chooseBest',
        _ChooseBestParams<G>(
            game, AbsoluteTimeControl(timeControl.endTime.subtract(buffer))));

    return completer.future;
  }

  @override
  void clearCache() {
    _engineThread?.emit('clearCache', null);
  }

  @override
  final StrictTimeStats stats = StrictTimeStats();

  Thread _getThread() => _engineThread ??= Thread((events) {
        final engine = config.buildEngine<G>();
        events.on<_ChooseBestParams<G>>('chooseBest', (params) async {
          final move = await engine.chooseBest(
              params.game.getMoves(), params.game, params.timeControl);
          events.emit<Move<G>>('chooseBestResult', move);
        });

        events.on<Null>('clearCache', (_) {
          engine.clearCache();
        });
      });
}

class _ChooseBestParams<G> {
  final G game;
  final TimeControl timeControl;

  const _ChooseBestParams(this.game, this.timeControl);
}
