import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../network/api_exception.dart';
import '../storage/token_store.dart';
import 'app_time.dart';

/// Getting a report off the phone and to whoever asked for it.
///
/// The backend already renders every report to PDF, so the app does not draw
/// its own - it fetches the same document the desk prints and hands it to the
/// share sheet. That is what makes "send me the ledger" a ten-second job on
/// WhatsApp instead of a trip back to the office.
class ReportSharing {
  ReportSharing({required TokenStore tokens, Dio? dio})
      : _tokens = tokens,
        _dio = dio ?? Dio();

  final TokenStore _tokens;
  final Dio _dio;

  /// Downloads a PDF and opens the share sheet on it.
  ///
  /// [name] becomes the file name, so it should read as something worth
  /// receiving - "Ledger RAJ01" rather than "report".
  Future<void> sharePdf({
    required String path,
    required String name,
    Map<String, dynamic>? query,
  }) async {
    final access = await _tokens.readAccess();

    late final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        '${AppConfig.apiRoot}$path',
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (access != null && access.isNotEmpty) 'Authorization': 'Bearer $access',
            'X-Timezone': AppTime.ianaName,
          },
        ),
      );
    } catch (error) {
      throw ApiException.from(error);
    }

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw ApiException('That report came back empty.');
    }
    // A failure page renders as HTML, not a PDF; catching it here means the
    // user gets a message rather than a share sheet holding a broken file.
    if (bytes.length < 4 || String.fromCharCodes(bytes.take(4)) != '%PDF') {
      throw ApiException('The server did not return a PDF for that report.');
    }

    final file = File('${(await getTemporaryDirectory()).path}/${_fileName(name)}');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [_fileName(name)],
      ),
    );
  }

  String _fileName(String name) {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final stamp = AppTime.apiDate(DateTime.now());
    return '${safe.isEmpty ? 'Report' : safe} $stamp.pdf'.replaceAll(' ', '-');
  }
}
