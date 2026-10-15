import '../../core/network/api_client.dart';
import '../../core/util/app_time.dart';
import '../models/havala.dart';
import '../models/party.dart';

/// Money moving between two parties.
class HavalaRepository {
  HavalaRepository(this._api);

  final ApiClient _api;

  /// One havala, as the edit form needs it.
  Future<Havala> byId(int id) async =>
      Havala.fromJson(asMap(await _api.get('/soda/havala/$id/')));

  /// Havala entries, newest first - within [from]..[to] when given, as the
  /// desk lists them by date rather than all at once.
  Future<List<Havala>> list({DateTime? from, DateTime? to}) async {
    final body = await _api.get('/soda/havala/', query: {
      if (from != null) 'from_date': AppTime.apiDate(from),
      if (to != null) 'to_date': AppTime.apiDate(to),
    });
    final entries = asList(body).map(Havala.fromJson).toList()
      ..sort((a, b) {
        final left = a.date;
        final right = b.date;
        if (left == null || right == null) return b.id.compareTo(a.id);
        return right.compareTo(left);
      });
    return entries;
  }

  /// The next number in the havala series.
  ///
  /// Voucher numbers come from the Document Code master rather than being
  /// invented here, so an entry made on a phone carries the same series as one
  /// made at the desk.
  Future<String> nextVoucherNo() async {
    final body = asMap(await _api.get('/soda/havala/get_latest_item_code/'));
    return (body['item_code'] ?? '').toString().trim();
  }

  Future<void> create({
    required int fromPartyId,
    required int toPartyId,
    required double amount,
    required DateTime date,
    String description = '',
    String? voucherNo,
  }) async {
    // The server requires a number; ask for the next one if the caller has not
    // already fetched it.
    final number = (voucherNo == null || voucherNo.isEmpty)
        ? await nextVoucherNo()
        : voucherNo;

    await _api.post('/soda/havala/', data: {
      'voucher_no': number,
      // The date the operator picked, in their own timezone, so the voucher
      // lands on the day they are working rather than the server's day.
      'voucher_date': AppTime.apiDate(date),
      'p_member': fromPartyId,
      'h_member': toPartyId,
      'amount': amount,
      if (description.trim().isNotEmpty) 'description': description.trim(),
    });
  }

  /// Parties with what they are currently carrying.
  ///
  /// The plain party list does not include balances; this endpoint does, and
  /// squaring people off is the one job that cannot be done without them.
  Future<List<PartyBalanceRow>> partiesWithBalances() async {
    final body = await _api.get('/master/parties/fetch_all/');
    return asList(body)
        .whereType<Map>()
        .map((e) => PartyBalanceRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Squares a set of clients off against one party in a single stroke.
  ///
  /// Each client's own balance decides the direction: someone carrying a debit
  /// receives, someone carrying a credit pays. The server raises one havala per
  /// client and numbers them from the same voucher run as a manual entry, so
  /// nothing about the result is special-cased afterwards.
  Future<void> autoHavala({
    required int targetPartyId,
    required DateTime date,
    required Map<int, double> amountByClientId,
  }) async {
    final entries = [
      for (final e in amountByClientId.entries)
        if (e.value != 0) {'client_id': e.key, 'amount': e.value},
    ];
    if (entries.isEmpty) return;

    await _api.post('/soda/havala/auto_havala/', data: {
      'party_code': targetPartyId,
      'date': AppTime.apiDate(date),
      'entries': entries,
    });
  }

  /// Changing a havala that is already written.
  ///
  /// The amount keeps whatever sign the caller passes: a Dena havala is held
  /// as a minus figure, and an edit that only renamed a party must not turn it
  /// into a Lena one.
  Future<void> update({
    required int id,
    required int fromPartyId,
    required int toPartyId,
    required double amount,
    required DateTime date,
    String description = '',
  }) =>
      _api.patch('/soda/havala/$id/', data: {
        'voucher_date': AppTime.apiDate(date),
        'p_member': fromPartyId,
        'h_member': toPartyId,
        'amount': amount,
        'description': description.trim(),
      });

  Future<void> delete(int id) => _api.delete('/soda/havala/$id/');
}
