import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light(TextTheme fonts) {
    const primary = AppColors.primary;
    const ink = AppColors.text;
    const white = AppColors.background;
    const tint = AppColors.primaryTint;
    const page = AppColors.primarySoft;
    const border = AppColors.border;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    OutlineInputBorder inputBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    final textTheme = fonts.apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: page,
      canvasColor: white,
      disabledColor: primary,
      shadowColor: primary.withValues(alpha: 0.12),
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: tint,
        onPrimaryContainer: ink,
        secondary: primary,
        secondaryContainer: tint,
        onSecondaryContainer: ink,
        tertiary: primary,
        tertiaryContainer: tint,
        onTertiaryContainer: ink,
        surface: white,
        surfaceContainerLowest: white,
        surfaceContainerLow: page,
        surfaceContainer: page,
        surfaceContainerHigh: tint,
        surfaceContainerHighest: tint,
        onSurface: ink,
        onSurfaceVariant: primary,
        outline: border,
        outlineVariant: border,
        error: ink,
        errorContainer: tint,
        onErrorContainer: ink,
        inverseSurface: ink,
        onInverseSurface: white,
        inversePrimary: tint,
        scrim: ink,
        shadow: primary,
      ),
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: white,
        surfaceTintColor: primary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: white,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        surfaceTintColor: white,
        elevation: 1,
        shadowColor: primary.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: white,
        surfaceTintColor: white,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        textColor: ink,
        selectedColor: primary,
        selectedTileColor: tint,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: page,
        labelStyle:
            const TextStyle(color: primary, fontWeight: FontWeight.w700),
        floatingLabelStyle:
            const TextStyle(color: primary, fontWeight: FontWeight.w800),
        hintStyle: const TextStyle(color: primary),
        helperStyle: const TextStyle(color: primary),
        prefixIconColor: primary,
        suffixIconColor: primary,
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        disabledBorder: inputBorder(border),
        focusedBorder: inputBorder(primary, width: 2),
        errorBorder: inputBorder(ink, width: 2),
        focusedErrorBorder: inputBorder(ink, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          backgroundColor: primary,
          foregroundColor: white,
          disabledBackgroundColor: tint,
          disabledForegroundColor: primary,
          minimumSize: const Size(72, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          foregroundColor: primary,
          side: const BorderSide(color: border),
          minimumSize: const Size(72, 44),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: white,
        selectedColor: primary,
        disabledColor: tint,
        side: BorderSide(color: border),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        surfaceTintColor: white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: white,
        surfaceTintColor: white,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: white),
        actionTextColor: tint,
      ),
    );
  }
}
