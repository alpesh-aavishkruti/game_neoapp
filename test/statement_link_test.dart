import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/config/app_config.dart';
import 'package:game_app_flutter/data/models/session.dart';

void main() {
  test('the statement link points at the web desk with company and code', () {
    expect(
      AppConfig.partyStatementLink(5, 'DGP'),
      'https://neonacc.com/#/ledger/5/DGP',
    );
  });

  test('a code with spaces or slashes stays one part of the link', () {
    expect(
      AppConfig.partyStatementLink(5, 'A B/C'),
      'https://neonacc.com/#/ledger/5/A%20B%2FC',
    );
  });

  test('the company is read from the sign-in profile', () {
    expect(
      Session.fromJson({'access': 'a', 'refresh': 'r', 'profile': {'organization': 7}})
          .organizationId,
      7,
    );
    expect(
      Session.fromJson({
        'access': 'a',
        'refresh': 'r',
        'profile': {
          'organization': {'id': 9},
        },
      }).organizationId,
      9,
    );
    expect(Session.fromJson({'access': 'a', 'refresh': 'r'}).organizationId, isNull);
  });
}
