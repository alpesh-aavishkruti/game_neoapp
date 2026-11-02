import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/data/models/party.dart';
import 'package:game_app_flutter/data/repositories/master_repository.dart';
import 'package:game_app_flutter/features/dashboard/close_match_sheet.dart';
import 'package:game_app_flutter/features/masters/master_providers.dart';
import 'package:game_app_flutter/features/matches/match_providers.dart';

class _Settings implements MasterRepository {
  _Settings(this.settings);

  final Map<String, dynamic> settings;

  @override
  Future<Map<String, dynamic>> organisationSettings() async => settings;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

const _parties = [
  Party(id: 3, code: 'F200', name: 'FALCON 100 OTG'),
  Party(id: 7, code: 'OTG', name: 'OTG'),
  Party(id: 9, code: 'AM', name: 'AUTO MEMBER'),
  Party(id: 12, code: 'LOV', name: 'LOVE BHAI'),
];

Future<PlAccounts> _read(Map<String, dynamic> settings) async {
  final container = ProviderContainer(overrides: [
    partiesProvider.overrideWith((ref) async => _parties),
    masterRepositoryProvider.overrideWithValue(_Settings(settings)),
  ]);
  addTearDown(container.dispose);
  final sub = container.listen(accountsProvider, (_, _) {});
  addTearDown(sub.close);
  return container.read(accountsProvider.future);
}

void main() {
  test('the P&L list is the parties, OTG among them', () async {
    final pl = await _read(const {});
    expect(pl.list.map((a) => a.code), ['F200', 'OTG', 'AM', 'LOV']);
    expect(pl.list.firstWhere((a) => a.code == 'OTG').id, 7, reason: "a party's id, as the close expects");
  });

  test('the account last closed to comes first, as on the desk', () async {
    expect((await _read({'last_pl_account': 12, 'auto_member': 9})).suggested?.code, 'LOV');
    expect((await _read({'last_pl_account': {'id': 12}})).suggested?.code, 'LOV');
  });

  test('then the party coded exactly OTG, not one with OTG in its name', () async {
    expect((await _read({'auto_member': 9})).suggested?.code, 'OTG');
  });

  test('a last account no longer in the list falls back', () async {
    expect((await _read({'last_pl_account': 99, 'auto_member': 9})).suggested?.code, 'OTG');
  });
}
