import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';
import 'util/report_sharing.dart';

/// The wiring every feature reaches for.
///
/// Kept in one place so a screen never constructs its own client or storage -
/// which is what keeps the token, the timezone header and the refresh retry
/// consistent across the whole app.

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// The sign-out hook is attached by AuthController rather than here, so this
/// file stays free of any dependency on a feature.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokens: ref.watch(tokenStoreProvider)),
);

/// Fetches a rendered report and hands it to the share sheet.
final reportSharingProvider = Provider<ReportSharing>(
  (ref) => ReportSharing(tokens: ref.watch(tokenStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);
