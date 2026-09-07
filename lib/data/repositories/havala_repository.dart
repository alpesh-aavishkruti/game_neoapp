import '../../core/network/api_client.dart';
import '../../core/util/app_time.dart';
import '../models/havala.dart';

/// Money moving between two parties.
class HavalaRepository {
  HavalaRepository(this._api);

  final ApiClient _api;

  Future<List<Havala>> list() async {
    final body = await _api.get('/soda/havala/');
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

  Future<void> delete(int id) => _api.delete('/soda/havala/$id/');
}
