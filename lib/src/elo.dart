import 'dart:math';

enum GameResult {
  win,
  loss,
  draw,
}

abstract class Elo<T> {
  void init(List<T> players);

  double getElo(T player);

  void result(T a, T b, GameResult result) {
    switch (result) {
      case GameResult.win:
        return victory(a, b);
      case GameResult.loss:
        return loss(a, b);
      case GameResult.draw:
        return draw(a, b);
    }
  }

  void victory(T victor, T loser);

  void draw(T player1, T player2);

  void loss(T loser, T winner) => victory(winner, loser);
}

class StandardElo<T> extends Elo<T> {
  StandardElo({this.kVal = 32, this.cVal = 400});

  final _eloTable = <T, double>{};
  final kVal;
  final cVal;

  void init(List<T> players, [double startingScore = 1200]) {
    for (final player in players) {
      _eloTable[player] = startingScore;
    }
  }

  double getElo(T player) => _eloTable[player]!;

  void victory(T victor, T loser) {
    final ratingVictor = _eloTable[victor]!;
    final ratingLoser = _eloTable[loser]!;
    _eloTable[victor] = _newRating(ratingVictor, ratingLoser, 1);
    _eloTable[loser] = _newRating(ratingLoser, ratingVictor, 0);
  }

  void draw(T player1, T player2) {
    final ratingVictor = _eloTable[player1]!;
    final ratingLoser = _eloTable[player2]!;
    _eloTable[player1] = _newRating(ratingVictor, ratingLoser, 0.5);
    _eloTable[player2] = _newRating(ratingLoser, ratingVictor, 0.5);
  }

  double _newRating(double rating, double opRating, double result) {
    // Ea = Qa /(Qa + Qb), where Qa = 10^(Ra/c) and Qb = 10^(Rb/c)
    final qa = pow(10, rating / cVal);
    final qb = pow(10, opRating / cVal);
    final expected = qa / (qa + qb);

    // R’a = Ra + K*(Sa — Ea)
    return rating + kVal * (result - expected);
  }

  @override
  String toString() =>
      _eloTable.entries.map((e) => '${e.key}: ${e.value}').join('\n');
}

class FullHistoryElo<T> extends Elo<T> {
  final _table = <T, _WdlRecord>{};
  final cVal;

  FullHistoryElo({this.cVal = 400});

  void init(List<T> players) {
    for (final player in players) {
      _table[player] = _WdlRecord();
    }
  }

  double getElo(T player) => _eloForScore(_table[player]!.score);

  double getEloError(T player, double zscore) {
    final wdl = _table[player]!;
    final variance = _getVariance(wdl, wdl.score);
    final stddev = sqrt(variance);
    //final zscore = 1.959963984540054; // 95% confidence

    // Technically, we get a range of scores not elos. So get a min/max.
    final scoreErr = zscore * stddev / sqrt(wdl.total);
    final maxElo = _eloForScore(wdl.score + scoreErr);
    final minElo = _eloForScore(wdl.score - scoreErr);

    // This elo err is probably good enough!
    return (maxElo - minElo) / 2;
  }

  double _scoreForElo(double elo) => 1 / (1 + pow(10, -elo / cVal));
  double _eloForScore(double score) => -cVal * log(1 / score - 1) / ln10;

  double _getVariance(_WdlRecord wdl, double score) {
    final lossDev = wdl.lossRatio * pow(0 - score, 2);
    final drawDev = wdl.drawRatio * pow(0.5 - score, 2);
    final winDev = wdl.winRatio * pow(1 - score, 2);
    return lossDev + drawDev + winDev;
  }

  double getLlr(T player, double elo1, double elo2) {
    final wdl = _table[player]!;
    final score1 = _scoreForElo(elo1);
    final score2 = _scoreForElo(elo2);
    final variance1 = _getVariance(wdl, score1);
    final variance2 = _getVariance(wdl, score2);
    return 0.5 * wdl.total * log(variance1 / variance2);
  }

  void victory(T victor, T loser) {
    _table[victor]!.wins++;
    _table[loser]!.losses++;
  }

  void draw(T player1, T player2) {
    _table[player1]!.draws++;
    _table[player2]!.draws++;
  }

  Map<T, bool> sprt({
    required double alpha,
    required double beta,
    required double elo1,
    required double elo2,
  }) {
    final results = <T, bool>{};

    final a = (1 - beta) / alpha;
    final b = beta / (1 - alpha);

    for (final player in _table.keys) {
      final llr = getLlr(player, elo1, elo2);
      if (llr >= log(a)) {
        results[player] = true;
      } else if (llr <= log(b)) {
        results[player] = false;
      }
    }

    return results;
  }

  @override
  String toString() => _table.keys
      .map((p) => '$p: ${getElo(p).toStringAsFixed(2)}'
          ' +/- ${getEloError(p, 2 /*sigma*/).toStringAsFixed(2)}')
      .join('\n');
}

class _WdlRecord {
  int wins = 0;
  int losses = 0;
  int draws = 0;

  double get score => (wins + draws / 2) / total;
  int get total => wins + draws + losses;

  double get lossRatio => losses / total;
  double get winRatio => wins / total;
  double get drawRatio => draws / total;
}
