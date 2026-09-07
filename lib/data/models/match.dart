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

  factory GameMatch.fromJson(Map<String, dynamic> json) {
    final nations = <String>[];
    for (var i = 1; i <= 10; i++) {
      final value = json['nation$i']?.toString().trim();
      if (value != null && value.isNotEmpty) nations.add(value.toUpperCase());
    }

    return GameMatch(
      id: int.tryParse('${json['id']}') ?? 0,
      game: GameType.parse(json['game']),
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

  bool get isSettled => !isActive;
}
