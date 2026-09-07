import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_app_flutter/core/network/api_exception.dart';

DioException _http(int status, dynamic body, {String path = '/soda/oneday/'}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: body,
      ),
      type: DioExceptionType.badResponse,
    );

/// An error message has one job: send the reader at the actual problem. These
/// pin the case that got that wrong - a mistyped password being reported as an
/// expired session, which sends someone looking for a problem they do not have.
void main() {
  group('401 while signing in', () {
    // The real body from POST /api/v1/login with a wrong password.
    final wrongPassword = {
      'status': false,
      'error': 401,
      'data': null,
      'message': 'No active account found with the given credentials',
    };

    test('says the credentials were wrong, not that a session ended', () {
      final e = ApiException.from(_http(401, wrongPassword, path: '/login'));
      expect(e.message, 'That user ID or password was not recognised.');
      expect(e.message, isNot(contains('session')));
    });

    test('passes through any other reason the server gives', () {
      final e = ApiException.from(_http(
        401,
        {'message': 'This account has been deactivated.'},
        path: '/login',
      ));
      expect(e.message, 'This account has been deactivated.');
    });

    test('covers the 2FA step too', () {
      final e = ApiException.from(_http(
        401,
        {'message': 'No active account found with the given credentials'},
        path: '/verify-2fa',
      ));
      expect(e.message, 'That user ID or password was not recognised.');
    });
  });

  group('401 anywhere else', () {
    test('reads as an ended session', () {
      final e = ApiException.from(_http(401, {'detail': 'Token is invalid'}));
      expect(e.message, 'Your session has ended. Please sign in again.');
      expect(e.isUnauthorized, isTrue);
    });
  });

  group('other failures', () {
    test('403 explains it is a permission problem', () {
      final e = ApiException.from(_http(403, {'detail': 'Not allowed'}));
      expect(e.isForbidden, isTrue);
      expect(e.message, contains('permission'));
    });

    test('field errors are kept so a form can mark the field', () {
      final e = ApiException.from(_http(400, {
        'amount': ['This field is required.'],
      }));
      expect(e.fieldErrors?['amount'], 'This field is required.');
    });

    test('the backend envelope message is used when there is one', () {
      final e = ApiException.from(_http(400, {
        'status': false,
        'message': 'Win Nation is required.',
      }));
      expect(e.message, 'Win Nation is required.');
    });

    test('no connection says so plainly', () {
      final e = ApiException.from(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      ));
      expect(e.message, contains('Cannot reach the server'));
    });
  });
}
