import 'package:dio/dio.dart';

/// A failure the user can be told about.
///
/// Dio's own errors talk about sockets and status codes; this turns them into
/// one sentence that says what went wrong and, where possible, what to do.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;

  /// Per-field messages from DRF, so a form can mark the offending input
  /// instead of showing one banner for the whole screen.
  final Map<String, String>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return ApiException('Something went wrong. Please try again.');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('The server took too long to answer. Check the connection and try again.');
      case DioExceptionType.connectionError:
        return ApiException('Cannot reach the server. Check the connection and try again.');
      case DioExceptionType.cancel:
        return ApiException('Request cancelled.');
      default:
        break;
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    final parsed = _readErrors(data);

    if (status == 401) {
      // A 401 means two different things depending on where it came from.
      // While signing in it means the credentials were wrong; anywhere else it
      // means the session ran out. Saying "your session has ended" to someone
      // who just mistyped their password sends them looking for the wrong
      // problem, so the two are answered separately.
      if (_isSignInPath(error.requestOptions.path)) {
        return ApiException(
          _friendlyCredentialError(parsed.message),
          statusCode: 401,
          fieldErrors: parsed.fields,
        );
      }
      return ApiException('Your session has ended. Please sign in again.', statusCode: 401);
    }
    if (status == 403) {
      return ApiException('You do not have permission to do that.', statusCode: 403);
    }
    return ApiException(
      parsed.message ?? 'Something went wrong. Please try again.',
      statusCode: status,
      fieldErrors: parsed.fields,
    );
  }

  static bool _isSignInPath(String path) =>
      path.contains('/login') || path.contains('/verify-2fa');

  /// The server's own wording for bad credentials is accurate but reads like a
  /// database message. Anything else it says is passed through untouched -
  /// a locked or deactivated account has its own reason worth showing.
  static String _friendlyCredentialError(String? serverMessage) {
    const generic = 'No active account found with the given credentials';
    if (serverMessage == null || serverMessage.trim().isEmpty) {
      return 'That user ID or password was not recognised.';
    }
    if (serverMessage.toLowerCase().contains(generic.toLowerCase())) {
      return 'That user ID or password was not recognised.';
    }
    return serverMessage;
  }

  static ({String? message, Map<String, String>? fields}) _readErrors(dynamic data) {
    if (data is! Map) return (message: null, fields: null);

    // The backend's own envelope: {"status": false, "message": "..."}
    final envelope = data['message'];
    if (envelope is String && envelope.trim().isNotEmpty) {
      return (message: envelope.trim(), fields: null);
    }

    // DRF field errors: {"amount": ["This field is required."]}
    final fields = <String, String>{};
    data.forEach((key, value) {
      final text = value is List
          ? value.map((e) => e.toString()).join(' ')
          : value?.toString() ?? '';
      if (text.trim().isNotEmpty) fields['$key'] = text.trim();
    });
    if (fields.isEmpty) return (message: null, fields: null);

    final firstDetail = fields['detail'] ?? fields['non_field_errors'];
    return (message: firstDetail ?? fields.values.first, fields: fields);
  }
}
