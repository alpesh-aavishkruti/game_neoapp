import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import '../util/app_time.dart';
import 'api_exception.dart';

/// The single way this app talks to the backend.
///
/// Three things happen to every request here, so no screen has to remember
/// them: the access token is attached, the device's timezone is declared, and
/// an expired token is refreshed once and the call retried.
class ApiClient {
  ApiClient({required TokenStore tokens, Dio? dio})
      : _tokens = tokens,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.apiRoot
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers['Accept'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final Dio _dio;
  final TokenStore _tokens;

  /// Called when the session cannot be recovered, so the app can sign out.
  void Function()? onSessionExpired;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _tokens.readAccess();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }

    // The server renders most dates to strings before sending them. Telling it
    // where this phone is means those strings arrive in the reader's own
    // timezone - which matters the moment one office is in India and another
    // in the UAE, because a late-night entry otherwise lands on the wrong day.
    options.headers['X-Timezone'] = AppTime.ianaName;

    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final isAuthCall = _isAuthEndpoint(error.requestOptions.path);
    final alreadyRetried = error.requestOptions.extra['retried'] == true;

    if (error.response?.statusCode != 401 || isAuthCall || alreadyRetried) {
      return handler.next(error);
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _tokens.clear();
      onSessionExpired?.call();
      return handler.next(error);
    }

    try {
      final request = error.requestOptions;
      request.extra['retried'] = true;
      final access = await _tokens.readAccess();
      if (access != null) request.headers['Authorization'] = 'Bearer $access';
      final response = await _dio.fetch(request);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  bool _isAuthEndpoint(String path) =>
      path.contains('/login') || path.contains('/refresh') || path.contains('/verify-2fa');

  /// Guards against a burst of 401s all firing their own refresh.
  Future<bool>? _refreshInFlight;

  Future<bool> _refresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      // A bare Dio: the interceptor above must not run on the refresh itself.
      final response = await Dio(BaseOptions(baseUrl: AppConfig.apiRoot))
          .post<Map<String, dynamic>>('/refresh', data: {'refresh': refresh});
      final access = response.data?['access'] as String?;
      if (access == null || access.isEmpty) return false;
      await _tokens.saveTokens(access: access);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) =>
      _send(() => _dio.post(path, data: data, queryParameters: query));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } catch (error) {
      throw ApiException.from(error);
    }
  }
}

/// The backend wraps most replies as `{status, data, message}`. This pulls the
/// payload out, while still working for the endpoints that answer plainly.
dynamic unwrap(dynamic body) {
  if (body is Map && body.containsKey('data')) return body['data'];
  return body;
}

List<Map<String, dynamic>> asList(dynamic body) {
  final data = unwrap(body);
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  // Paginated replies keep the rows under `results`.
  if (data is Map && data['results'] is List) {
    return (data['results'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Map<String, dynamic> asMap(dynamic body) {
  final data = unwrap(body);
  return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
}
