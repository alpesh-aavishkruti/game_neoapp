import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/bet_entry.dart';
import 'package:game_app_flutter/data/models/book_row.dart';
import 'package:game_app_flutter/data/models/havala.dart';
import 'package:game_app_flutter/data/models/match.dart';
import 'package:game_app_flutter/data/models/match_totals.dart';
import 'package:game_app_flutter/data/models/party.dart';

/// Payloads copied verbatim from the running backend.
///
/// The rest of the model tests use tidy fixtures; these use what the server
/// actually sends - decimals as strings, empty many-to-many lists, parties
/// whose name repeats their code. If a response shape ever drifts, this is
/// what catches it rather than a blank screen on someone's phone.
void main() {
  group('party, as the list endpoint sends it', () {
    // GET /api/v1/master/parties/
    final json = {
      'id': 36,
      'organization': 1,
      'party_code': 'NR',
      'party_name': 'NAR',
      'category': <dynamic>[],
      'city': '',
      'is_bookie': false,
      'is_own': false,
      'show_in_book': false,
      'rec_int': '0.00',
      'pay_int': '0.00',
      'credit_limit': '0.00',
      'ref_member': null,
      'mobile': '',
      'is_active': true,
      'created_at': '2026-08-13T15:12:56.501438+05:30',
    };

    test('reads the party', () {
      final party = Party.fromJson(json);
      expect(party.id, 36);
      expect(party.code, 'NR');
      expect(party.name, 'NAR');
      expect(party.isActive, isTrue);
    });

    test('an empty category list is no category, not a crash', () {
      expect(Party.fromJson(json).categoryName, isNull);
      // The subtitle then falls back to just the code.
      expect(Party.fromJson(json).subtitle, 'NR');
    });

    test('a populated category list is read', () {
      final party = Party.fromJson({
        ...json,
        'category': [
          {'id': 1, 'category_name': 'A'},
        ],
      });
      expect(party.categoryName, 'A');
      expect(party.subtitle, 'NR · Cat A');
    });

    test('a party named after its own code is not doubled up', () {
      // Real rows look like this: party_code PDG, party_name PDG.
      final party = Party.fromJson({...json, 'party_code': 'PDG', 'party_name': 'PDG'});
      expect(party.display, 'PDG');
    });

    test('the confirmation names the party, not the code just typed', () {
      // Catching a mistyped code only works if the app says something back
      // that the operator did not type themselves.
      final party = Party.fromJson({...json, 'party_code': 'NR', 'party_name': 'NAR'});
      expect(party.confirmation, 'NAR');
      expect(party.confirmation, isNot('NR'));
    });

    test('a party named after its code still confirms with something', () {
      // Real rows look like this, and it is the one case where the code is
      // all there is to show.
      final party = Party.fromJson({...json, 'party_code': 'PDG', 'party_name': 'PDG'});
      expect(party.confirmation, 'PDG');
    });

    test('the confirmation carries category and bookie when they are known', () {
      final party = Party.fromJson({
        ...json,
        'party_code': 'RAJ01',
        'party_name': 'Rajesh Traders',
        'category': [
          {'category_name': 'A'},
        ],
        'is_bookie': true,
      });
      expect(party.confirmation, 'Rajesh Traders · Cat A · Bookie');
    });

    test('balance and brokerage stay unknown rather than zero', () {
      final party = Party.fromJson(json);
      expect(party.balance, isNull);
      expect(party.brokeragePercent, isNull);
    });
  });

  group('bet entry, as the soda endpoint sends it', () {
    // GET /api/v1/soda/oneday/77/oneday_soda/ -> data.entries[0]
    final json = {
      'row_no': 1,
      'nation': 'INDIA',
      'bet_type': 'L',
      'bet_label': 'I/L',
      'amount': '213.00',
      'rate': '123.00',
      'nation1_pl': '-2130.00',
      'nation2_pl': '2619.90',
      'commission_amount': '0.00',
      'is_ptrn_entry': true,
      'is_checked': false,
      'client': 42,
      'client_code': 'PDG',
      'client_name': 'PDG',
      'created_by_name': 'KPS',
      'is_edited': false,
      'created_at': '2026-08-21T09:24:46.710192+04:00',
    };

    test('figures arrive as strings and become numbers', () {
      final entry = BetEntry.fromJson(json);
      expect(entry.amount, 213);
      expect(entry.rate, 123);
      expect(entry.nation1Pl, -2130);
      expect(entry.nation2Pl, 2619.90);
    });

    test('keeps the label the board already computed', () {
      expect(BetEntry.fromJson(json).label, 'I/L');
    });

    test('the timestamp carries the offset the server rendered it in', () {
      // +04:00 is Dubai - the app asked for it with the X-Timezone header.
      final entry = BetEntry.fromJson(json);
      expect(entry.createdAt, isNotNull);
      expect(entry.createdAt!.toUtc(), DateTime.utc(2026, 8, 21, 5, 24, 46, 710, 192));
    });
  });

  group('totals, as the totals endpoint sends them', () {
    test('an untouched match reads as flat, not as missing', () {
      // GET /api/v1/soda/oneday/66/oneday_totals/
      final totals = MatchTotals.fromJson({
        'full_match_totals': {
          'nation1_pl': 0.0,
          'nation2_pl': 0.0,
          'avg_rate_n1': 0.0,
          'avg_rate_n2': 0.0,
          'comm_total': 0.0,
        },
        'commission_total': 0.0,
      }, nationNames: ['TYT', 'G']);

      expect(totals.positions, hasLength(2));
      expect(totals.positions.first.profitLoss, 0);
      expect(totals.positions.first.name, 'TYT');
    });
  });

  group('party book, as the partybook endpoint sends it', () {
    test('reads a row and the pinned totals', () {
      // GET /api/v1/soda/oneday/77/oneday_partybook/
      final book = MatchBook.fromJson({
        'parties': [
          {
            'party_id': 40,
            'party_code': '0017',
            'party_name': 'KR',
            'code_party_name': '0017-KR',
            'nation1_pl': -2340.0,
            'nation2_pl': 5475.6,
            'comm': 0.0,
            'check_status': 'none',
          },
        ],
        'total_a': -4391.8,
        'total_b': 6831.9,
      });

      expect(book.rows, hasLength(1));
      expect(book.rows.first.code, '0017');
      expect(book.rows.first.figures, [-2340.0, 5475.6]);
      expect(book.totals, [-4391.8, 6831.9]);
    });
  });

  group('havala, as the havala endpoint sends it', () {
    test('reads who pays and who receives', () {
      final havala = Havala.fromJson({
        'id': 7,
        'voucher_no': 'HV/26/0418',
        'voucher_date': '2026-08-20',
        'p_member': 41,
        'p_member_code_display': 'abr',
        'p_member_name_display': 'ABR',
        'h_member': 42,
        'h_member_code_display': 'pdg',
        'h_member_name_display': 'PDG',
        'amount': '150000.0000',
        'description': 'Settlement',
        'created_by_name': 'KPS',
      });

      expect(havala.fromId, 41);
      expect(havala.fromCode, 'ABR');
      expect(havala.toId, 42);
      expect(havala.toCode, 'PDG');
      expect(havala.amount, 150000);
    });
  });

  group('match, as the active-match endpoint sends it', () {
    test('reads an open one day match', () {
      final match = GameMatch.fromJson({
        'id': 66,
        'game': 'ONE_DAY',
        'nation_a': 'TYT',
        'nation_b': 'G',
        'nation_c': null,
        'is_active': true,
        'ptrn_enabled': true,
        'commission_enabled': true,
        'party_book_enabled': true,
        'cup_name': null,
        'nation1': null,
        'created_at': '2026-08-19T18:02:11+04:00',
      });

      expect(match.id, 66);
      expect(match.game, GameType.oneDay);
      expect(match.selectableNations, ['TYT', 'G']);
      expect(match.isSettled, isFalse);
      expect(match.ptrnEnabled, isTrue);
    });
  });

  group('party balances, as the settle-up list sends them', () {
    // GET /api/v1/master/parties/fetch_all/
    test('reads what each party is carrying', () {
      final row = PartyBalanceRow.fromJson({
        'id': 42,
        'party_code': 'PDG',
        'party_name': 'PDG',
        'closing_balance': '-2691.80',
        'ref_member': null,
        'is_active': true,
      });
      expect(row.id, 42);
      expect(row.balance, -2691.80);
      expect(row.isSquare, isFalse);
      // Name repeats the code on real rows, so it is not printed twice.
      expect(row.display, 'PDG');
    });

    test('a party with nothing outstanding reads as square', () {
      final row = PartyBalanceRow.fromJson({
        'id': 7,
        'party_code': 'NR',
        'party_name': 'NAR',
        'closing_balance': '0.00',
      });
      expect(row.isSquare, isTrue);
      expect(row.display, 'NR — NAR');
    });

    test('ref_member is read whether it arrives flat or nested', () {
      expect(
        PartyBalanceRow.fromJson({'id': 1, 'ref_member': 9}).refMemberId,
        9,
      );
      expect(
        PartyBalanceRow.fromJson({
          'id': 1,
          'ref_member': {'id': 9},
        }).refMemberId,
        9,
      );
      expect(PartyBalanceRow.fromJson({'id': 1}).refMemberId, isNull);
    });
  });

  group('cup, as the cup endpoints actually send it', () {
    // GET /api/v1/master/matches/cup_active_match/ - copied verbatim. Note
    // there is no `game` key at all, and the teams are nation_a .. nation_j.
    final json = {
      'id': 8,
      'cup_name': 'IPL 2026',
      'nation_a': 'AA',
      'nation_b': 'BB',
      'nation_c': 'CC',
      'nation_d': 'DD',
      'nation_e': '',
      'nation_f': null,
      'total_nations': 4,
      'is_active': true,
      'status': 'OPEN',
      'out_nations': '',
      'pending_nations': ['AA', 'BB', 'CC', 'DD'],
      'commission_enabled': true,
      'ptrn_enabled': true,
      'winner_nation': null,
      'winner_auto_declared': false,
    };

    test('a cup asked for by the cup endpoint is a cup', () {
      // Without being told, this payload reads as a one day match and every
      // board call goes to /soda/oneday/ with a cup id.
      final cup = GameMatch.fromJson(json, game: GameType.cup);
      expect(cup.game, GameType.cup);
      expect(cup.game.slug, 'cup');
    });

    test('the teams are read from the nation_a..j shape', () {
      final cup = GameMatch.fromJson(json, game: GameType.cup);
      expect(cup.cupNations, ['AA', 'BB', 'CC', 'DD']);
      // Blank and missing slots are not teams.
      expect(cup.cupNations, hasLength(4));
      expect(cup.selectableNations, ['AA', 'BB', 'CC', 'DD']);
    });

    test('the older nation1..10 shape still wins when it is present', () {
      final cup = GameMatch.fromJson(
        {...json, 'nation1': 'IND', 'nation2': 'AUS'},
        game: GameType.cup,
      );
      expect(cup.cupNations, ['IND', 'AUS']);
    });

    test('a cup is titled by its name, not by two of its teams', () {
      expect(GameMatch.fromJson(json, game: GameType.cup).title, 'IPL 2026');
    });

    test('a one day match is unaffected by the fallback', () {
      final match = GameMatch.fromJson({
        'id': 77,
        'game': 'ONE_DAY',
        'nation_a': 'IND',
        'nation_b': 'AUS',
        'is_active': true,
      });
      expect(match.game, GameType.oneDay);
      expect(match.selectableNations, ['IND', 'AUS']);
    });
  });
}
