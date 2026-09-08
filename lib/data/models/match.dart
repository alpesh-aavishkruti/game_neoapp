import '../../core/util/app_time.dart';

/// The four books this system keeps. Each has its own board, but they share
/// the same entry shape underneath.
enum GameType {
  oneDay('ONE_DAY', 'One Day', 'oneday'),
  test('TEST', 'Test', 'test'),
  session('SESSION', 'Session', 'session'),
  cup('CUP', 'Cup', 'cup');

  const GameType(this.code, this.label, this.slug);

  /// What the backend calls it.
  final String code;

  /// What the operator calls it.
  final String label;

  /// The path segment under `/soda/`.
  final String slug;

  /// The endpoint that lists open matches of this kind.
  String get activeListPath => switch (this) {
        GameType.oneDay => '/master/matches/oneday_active_match/',
        GameType.test => '/master/matches/test_active_match/',
        GameType.session => '/master/matches/session_active_match/',
        GameType.cup => '/master/matches/cup_active_match/',
      };

  static GameType parse(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'TEST' => GameType.test,
        'SESSION' => GameType.session,
        'CUP' => GameType.cup,
        _ => GameType.oneDay,
      };
}

/// A match, cup or session the book is open on.
class GameMatch {
  const GameMatch({
    required this.id,
    required this.game,
    required this.nationA,
    required this.nationB,
    this.nationC,
    this.cupName,
    this.cupNations = const [],
    required this.isActive,
    this.winNation,
    this.createdAt,
    this.closeDate,
    this.commissionEnabled = true,
    this.ptrnEnabled = true,
    this.partyBookEnabled = true,
  });

  final int id;
  final GameType game;
  final String nationA;
  final String nationB;

  /// Test matches carry a third outcome - the draw.
  final String? nationC;

  final String? cupName;

  /// A cup runs many teams rather than two.
  final List<String> cupNations;

  final bool isActive;
  final String? winNation;
  final DateTime? createdAt;
  final DateTime? closeDate;

  final bool commissionEnabled;
  final bool ptrnEnabled;
  final bool partyBookEnabled;

  /// [game] is passed by callers that already know which board they asked for.
  /// The cup endpoints do not send a `game` field at all, so without it a cup
  /// would read as a one day match and every board call would go to the wrong
  /// endpoint.
  factory GameMatch.fromJson(Map<String, dynamic> json, {GameType? game}) {
    // A cup's teams arrive as nation_a .. nation_j from the cup endpoints, and
    // as nation1 .. nation10 from the settlement ones. Read whichever shape
    // turned up: with neither, a cup board has no teams to show or bet on.
    final nations = <String>[];
    void take(dynamic raw) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) nations.add(value.toUpperCase());
    }

    for (var i = 1; i <= 10; i++) {
      take(json['nation$i']);
    }
    if (nations.isEmpty) {
      for (var i = 0; i < 10; i++) {
        take(json['nation_${String.fromCharCode(97 + i)}']);
      }
    }

    return GameMatch(
      id: int.tryParse('${json['id']}') ?? 0,
      game: game ?? GameType.parse(json['game']),
      nationA: (json['nation_a'] ?? '').toString().trim().toUpperCase(),
      nationB: (json['nation_b'] ?? '').toString().trim().toUpperCase(),
      nationC: (json['nation_c'] ?? '').toString().trim().isEmpty
          ? null
          : json['nation_c'].toString().trim().toUpperCase(),
      cupName: (json['cup_name'] ?? '').toString().trim().isEmpty
          ? null
          : json['cup_name'].toString().trim(),
      cupNations: nations,
      isActive: json['is_active'] != false,
      winNation: (json['win_nation'] ?? '').toString().trim().isEmpty
          ? null
          : json['win_nation'].toString().trim(),
      createdAt: AppTime.toLocal(json['created_at']),
      closeDate: AppTime.toLocal(json['close_date']),
      commissionEnabled: json['commission_enabled'] != false,
      ptrnEnabled: json['ptrn_enabled'] != false,
      partyBookEnabled: json['party_book_enabled'] != false,
    );
  }

  /// The same match with one or more of the desk switches flipped.
  GameMatch copyWith({
    bool? commissionEnabled,
    bool? ptrnEnabled,
    bool? partyBookEnabled,
  }) =>
      GameMatch(
        id: id,
        game: game,
        nationA: nationA,
        nationB: nationB,
        nationC: nationC,
        cupName: cupName,
        cupNations: cupNations,
        isActive: isActive,
        winNation: winNation,
        createdAt: createdAt,
        closeDate: closeDate,
        commissionEnabled: commissionEnabled ?? this.commissionEnabled,
        ptrnEnabled: ptrnEnabled ?? this.ptrnEnabled,
        partyBookEnabled: partyBookEnabled ?? this.partyBookEnabled,
      );

  // Two objects describing the same match are the same match, whatever their
  // switches currently read. Providers are keyed on this, so flipping a switch
  // must not look like a different match and throw the loaded board away.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameMatch && other.id == id && other.game == game);

  @override
  int get hashCode => Object.hash(id, game);

  /// The third outcome of a test, named. Falls back to DRAW, which is what the
  /// backend assumes when the column was left empty.
  String get drawName => nationC?.isNotEmpty == true ? nationC! : 'DRAW';

  /// How this match is announced on a card or an app bar.
  String get title {
    if (game == GameType.cup) return cupName ?? nationA;
    if (nationB.isEmpty) return nationA;
    return '$nationA vs $nationB';
  }

  /// The sides a bet can be placed on, in board order.
  List<String> get selectableNations => switch (game) {
        GameType.cup => cupNations,
        GameType.test => [nationA, nationB, drawName],
        _ => [nationA, nationB],
      };

  /// The columns the books carry for this match.
  ///
  /// A session is not bet on sides - it is bet on run figures, taken either
  /// way - so its books are ruled K and L. Everything else is ruled by team.
  List<String> get bookColumns =>
      game == GameType.session ? const ['K', 'L'] : selectableNations;

  bool get isSettled => !isActive;
}
