import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';

/// Everything to do with when something happened.
///
/// The backend stores timestamps in UTC but renders most of them to strings in
/// the server's own timezone before sending them. That is fine for one office
/// and wrong for two: a match closed at 00:30 in India is still the previous
/// evening in Dubai, so the same entry would sit under a different date for
/// each person reading it.
///
/// The app therefore tells the server which timezone it is in, on every single
/// request, and the server renders dates in that zone. [ianaName] is what gets
/// sent. Where the API does hand back a real timestamp we convert it ourselves
/// with [toLocal], which needs no server cooperation at all.
class AppTime {
  const AppTime._();

  static String _iana = 'UTC';

  /// The device's IANA zone, e.g. `Asia/Dubai`. Read once at startup by
  /// [init]; falls back to UTC rather than guessing if the platform cannot say.
  static String get ianaName => _iana;

  static Future<void> init() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      // The plugin returns a TimezoneInfo; its identifier is the IANA name.
      final name = zone.identifier;
      if (name.isNotEmpty) _iana = name;
    } catch (_) {
      // A device that will not report its zone still gets a working app -
      // the server just falls back to its own default.
    }
  }

  /// Parses a timestamp from the API and moves it to the device's zone.
  ///
  /// Returns null for anything unparseable so a single malformed row cannot
  /// take a whole screen down.
  static DateTime? toLocal(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  static final DateFormat _day = DateFormat('dd-MM-yyyy');
  static final DateFormat _dayShort = DateFormat('dd MMM');
  static final DateFormat _dayTime = DateFormat('dd-MM-yyyy HH:mm');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  static String date(DateTime? at) => at == null ? '-' : _day.format(at);
  static String dateShort(DateTime? at) => at == null ? '-' : _dayShort.format(at);
  static String dateTime(DateTime? at) => at == null ? '-' : _dayTime.format(at);
  static String time(DateTime? at) => at == null ? '-' : _time.format(at);

  /// `yyyy-MM-dd` for sending back to the API, in the user's own zone so the
  /// day they picked is the day the server records.
  static String apiDate(DateTime at) => _apiDate.format(at);

  static DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
