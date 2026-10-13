import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The approved palette from the design deck.
///
/// The app is dark first: figures are the product here and they separate
/// hardest against a dark ground - green and red read apart instantly, and an
/// amber edited row is unmistakable. It also suits when the work happens,
/// which is evening and night matches, often for hours.
class AppColors {
  const AppColors._();

  // Dark - the default.
  static const ground = Color(0xFF070B12);
  static const surface = Color(0xFF0E141F);
  static const line = Color(0xFF1C2634);
  static const ink = Color(0xFFE9EFF8);
  static const muted = Color(0xFF7C8CA1);

  static const brand = Color(0xFF4B85FF);
  static const brandSoft = Color(0xFF132140);

  /// L - lena. A position in your favour.
  static const up = Color(0xFF26D07C);
  static const upSoft = Color(0xFF0C2A1E);

  /// K - khana. A position against you.
  static const down = Color(0xFFFF4D6D);
  static const downSoft = Color(0xFF2B111A);

  /// An entry changed after it was taken. Never let this read as an original.
  static const warn = Color(0xFFFFB020);
  static const warnSoft = Color(0xFF2E2210);

  /// The brand itself - the amber wordmark on navy, as in the web header.
  static const brandNavy = Color(0xFF0B1220);
  static const brandAmber = Color(0xFFFDB022);

  // Light - offered as a second theme, following the phone's own setting.
  static const lGround = Color(0xFFF1F4F9);
  static const lSurface = Color(0xFFFFFFFF);
  static const lLine = Color(0xFFE3E8F0);
  static const lInk = Color(0xFF0F1522);
  static const lMuted = Color(0xFF68748A);
  static const lBrand = Color(0xFF2E5BFF);
  static const lBrandSoft = Color(0xFFEAEFFF);
  static const lUp = Color(0xFF00875A);
  static const lUpSoft = Color(0xFFE4F6EF);
  static const lDown = Color(0xFFD42D46);
  static const lDownSoft = Color(0xFFFDEBEE);
  static const lWarn = Color(0xFF9A5B00);
  static const lWarnSoft = Color(0xFFFFF3DC);
}

/// Semantic colours resolved for whichever theme is active, so a widget can
/// ask for "the colour of a losing position" instead of picking a hex itself.
@immutable
class BookColors extends ThemeExtension<BookColors> {
  const BookColors({
    required this.up,
    required this.upSoft,
    required this.down,
    required this.downSoft,
    required this.warn,
    required this.warnSoft,
    required this.line,
    required this.muted,
    required this.brandSoft,
  });

  final Color up;
  final Color upSoft;
  final Color down;
  final Color downSoft;
  final Color warn;
  final Color warnSoft;
  final Color line;
  final Color muted;
  final Color brandSoft;

  /// The colour a figure should be drawn in, by its sign.
  Color forAmount(num value) => value < 0 ? down : up;

  static const dark = BookColors(
    up: AppColors.up,
    upSoft: AppColors.upSoft,
    down: AppColors.down,
    downSoft: AppColors.downSoft,
    warn: AppColors.warn,
    warnSoft: AppColors.warnSoft,
    line: AppColors.line,
    muted: AppColors.muted,
    brandSoft: AppColors.brandSoft,
  );

  static const light = BookColors(
    up: AppColors.lUp,
    upSoft: AppColors.lUpSoft,
    down: AppColors.lDown,
    downSoft: AppColors.lDownSoft,
    warn: AppColors.lWarn,
    warnSoft: AppColors.lWarnSoft,
    line: AppColors.lLine,
    muted: AppColors.lMuted,
    brandSoft: AppColors.lBrandSoft,
  );

  @override
  BookColors copyWith({
    Color? up,
    Color? upSoft,
    Color? down,
    Color? downSoft,
    Color? warn,
    Color? warnSoft,
    Color? line,
    Color? muted,
    Color? brandSoft,
  }) =>
      BookColors(
        up: up ?? this.up,
        upSoft: upSoft ?? this.upSoft,
        down: down ?? this.down,
        downSoft: downSoft ?? this.downSoft,
        warn: warn ?? this.warn,
        warnSoft: warnSoft ?? this.warnSoft,
        line: line ?? this.line,
        muted: muted ?? this.muted,
        brandSoft: brandSoft ?? this.brandSoft,
      );

  @override
  BookColors lerp(ThemeExtension<BookColors>? other, double t) {
    if (other is! BookColors) return this;
    return BookColors(
      up: Color.lerp(up, other.up, t)!,
      upSoft: Color.lerp(upSoft, other.upSoft, t)!,
      down: Color.lerp(down, other.down, t)!,
      downSoft: Color.lerp(downSoft, other.downSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
    );
  }
}

/// Convenience so widgets read `context.book.down` rather than a long lookup.
extension BookColorsX on BuildContext {
  BookColors get book => Theme.of(this).extension<BookColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

class AppTheme {
  const AppTheme._();

  /// Radii: sharp, instrument-like. Depth comes from hairlines, not shadows.
  static const rCard = 8.0;
  static const rField = 7.0;
  static const rButton = 8.0;
  static const rSheet = 16.0;
  static const rChip = 4.0;

  /// Nothing tappable is smaller than this.
  static const minTouch = 48.0;

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        ground: AppColors.ground,
        surface: AppColors.surface,
        ink: AppColors.ink,
        muted: AppColors.muted,
        brand: AppColors.brand,
        line: AppColors.line,
        book: BookColors.dark,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        ground: AppColors.lGround,
        surface: AppColors.lSurface,
        ink: AppColors.lInk,
        muted: AppColors.lMuted,
        brand: AppColors.lBrand,
        line: AppColors.lLine,
        book: BookColors.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color ground,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color brand,
    required Color line,
    required BookColors book,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
      primary: brand,
      surface: surface,
      onSurface: ink,
      outline: line,
      error: book.down,
    );

    // Every figure is monospaced so columns of numbers line up down the
    // screen - the same reason the desk ledger reads cleanly.
    const mono = 'Roboto Mono';

    final text = TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: ink, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
      bodyLarge: TextStyle(fontSize: 15, color: ink),
      bodyMedium: TextStyle(fontSize: 13.5, color: ink),
      bodySmall: TextStyle(fontSize: 12, color: muted),
      // Small uppercase field labels, set in mono - that pairing is what gives
      // the boards their instrument feel.
      labelSmall: TextStyle(
        fontFamily: mono,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.3,
        color: muted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: ground,
      canvasColor: ground,
      // The chosen row in an open dropdown is marked in a light brand tint
      // rather than Material's grey, which read as a disabled row.
      focusColor: brand.withValues(alpha: 0.08),
      textTheme: text,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        border: _border(line),
        enabledBorder: _border(line),
        focusedBorder: _border(brand, width: 1.6),
        errorBorder: _border(book.down),
        focusedErrorBorder: _border(book.down, width: 1.6),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.7)),
        labelStyle: text.labelSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouch),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouch),
          foregroundColor: ink,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
        ),
      ),
      // Solid brand blue, like every primary action on the web desk -
      // Material's pale container tint read as a disabled button.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? brand : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? brand : muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rSheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      // Toasts on navy in both themes: on the light ground a white toast sat
      // on white and read as part of the form it covered.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandNavy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        actionTextColor: AppColors.brandAmber,
        closeIconColor: Colors.white70,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [book],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(rField),
        borderSide: BorderSide(color: color, width: width),
      );
}
