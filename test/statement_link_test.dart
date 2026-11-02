import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/config/app_config.dart';
import 'package:game_app_flutter/data/models/session.dart';

void main() {
  test('the statement link points at the web desk with a random token', () {
    expect(
      AppConfig.partyStatementLink('aB3-x_9'),
      'https://neonacc.com/#/statement/aB3-x_9',
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
