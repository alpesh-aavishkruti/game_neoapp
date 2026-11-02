import '../../core/network/api_client.dart';
import '../models/statement_link.dart';

/// The desk's side of a party's shared statement link.
class StatementLinkRepository {
  StatementLinkRepository(this._api);

  final ApiClient _api;

  String _path(int partyId) => '/master/parties/$partyId/statement-link/';

  /// The party's link, made the first time it is asked for.
  Future<StatementLink> get(int partyId) async =>
      StatementLink.fromJson(asMap(await _api.get(_path(partyId))));

  /// Off, the link the party holds stops opening until it is turned on again.
  Future<StatementLink> setActive(int partyId, bool isActive) async =>
      StatementLink.fromJson(
          asMap(await _api.patch(_path(partyId), data: {'is_active': isActive})));

  /// A new link with no password; the old one stops opening at once.
  Future<StatementLink> reset(int partyId) async =>
      StatementLink.fromJson(asMap(await _api.post('${_path(partyId)}reset/')));
}
