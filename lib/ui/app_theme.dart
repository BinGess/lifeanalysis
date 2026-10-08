import 'package:flutter/material.dart';

/// Shared visual rules: neutral surfaces, jade actions and restrained soft depth.
class AppTheme {
  static const radius = 24.0;
  static const fieldRadius = 18.0;
  static const pageWidth = 720.0;

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff286653),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xff92d3b5) : const Color(0xff286653),
          onPrimary: dark ? const Color(0xff10382a) : const Color(0xffffffff),
          surface: dark ? const Color(0xff262927) : const Color(0xffffffff),
          surfaceContainerLow: dark
              ? const Color(0xff191c1a)
              : const Color(0xfff0f1ee),
          surfaceContainerHighest: dark
              ? const Color(0xff363b37)
              : const Color(0xffe5e7e2),
          primaryContainer: dark
              ? const Color(0xff284e3e)
              : const Color(0xffdeeee4),
          onPrimaryContainer: dark
              ? const Color(0xffc4ebd6)
              : const Color(0xff214f3a),
          surfaceContainer: dark
              ? const Color(0xff202421)
              : const Color(0xfff7f8f5),
          secondary: dark ? const Color(0xffbfc6bf) : const Color(0xff616961),
          onSecondary: dark ? const Color(0xff202421) : Colors.white,
          onSurface: dark ? const Color(0xfff0f2ee) : const Color(0xff292e2b),
          onSurfaceVariant: dark
              ? const Color(0xffbfc6bf)
              : const Color(0xff616961),
          outline: dark ? const Color(0xff8c968d) : const Color(0xff7d877e),
          outlineVariant: dark
              ? const Color(0xff48504a)
              : const Color(0xffd9ded8),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: colors.outline),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.surfaceContainerLow,
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: colors.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: colors.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: colors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.75,
          color: colors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.65,
          color: colors.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.65,
          color: colors.onSurfaceVariant,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        iconTheme: IconThemeData(color: colors.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        height: 80,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: const EdgeInsets.all(18),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        hintStyle: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shape,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor: colors.onSurfaceVariant,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          side: BorderSide(color: colors.outline),
          foregroundColor: colors.primary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: colors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        iconColor: colors.primary,
        textColor: colors.onSurface,
        minVerticalPadding: 14,
        shape: shape,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        checkmarkColor: colors.primary,
        selectedColor: colors.primaryContainer,
        labelStyle: TextStyle(color: colors.onSurface, fontSize: 14),
        side: BorderSide(color: colors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        showCheckmark: true,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colors.primary,
        collapsedIconColor: colors.primary,
        textColor: colors.onSurface,
        collapsedTextColor: colors.onSurface,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        backgroundColor: colors.surface,
        collapsedBackgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        space: 24,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(color: colors.surface),
        shape: shape,
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const SoftCard({super.key, required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x60000000) : const Color(0x18283129),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: dark ? const Color(0x104a514b) : const Color(0x99ffffff),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
