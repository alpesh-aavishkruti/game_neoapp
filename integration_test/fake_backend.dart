import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A stand-in for the Django server, answering from responses recorded off
/// the real backend (`fixtures/api.json`).
///
/// Reads come back exactly as the server sent them. Writes are accepted and
/// remembered, so the test can check what the app tried to save.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(String recordedJson)
      : _recorded = Map<String, dynamic>.from(jsonDecode(recordedJson) as Map);

  final Map<String, dynamic> _recorded;

  /// Every write the app sent, as `METHOD /path` with its body.
  final writes = <({String call, dynamic body})>[];

  /// Every read the app made that had no recording - an empty list was sent.
  final unrecorded = <String>{};

  static const _prefix = '/api/v1';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var path = options.uri.path;
    if (path.startsWith(_prefix)) path = path.substring(_prefix.length);
    final method = options.method.toUpperCase();
    final call = '$method $path';

    // A beat of latency, so loading states are exercised as on a phone.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    if (call == 'POST /login') {
      return _json(_recorded[call], 200);
    }
    if (method == 'GET') {
      final hit = _recorded[call];
      if (hit is Map && hit.containsKey('status') && hit.containsKey('body')) {
        return _json(hit['body'], hit['status'] as int);
      }
      unrecorded.add(path);
      return _json({'status': true, 'message': 'success', 'data': <dynamic>[]}, 200);
    }

    writes.add((call: call, body: options.data));
    return _json({'status': true, 'message': 'Saved', 'data': <String, dynamic>{}}, 200);
  }

  ResponseBody _json(dynamic body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
