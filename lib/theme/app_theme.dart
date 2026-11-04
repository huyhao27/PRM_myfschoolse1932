import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

extension AppThemeContext on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}

/// Digits keep a fixed width so score columns line up.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

/// Fade-up page transition that is skipped when the OS asks for less motion.
class _CalmTransitions extends PageTransitionsBuilder {
  const _CalmTransitions();

  static const _inner = FadeUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _inner.buildTransitions(route, context, animation, secondary, child);
  }
}

abstract final class AppTheme {
  static const _body = TextStyle(height: 1.5, color: AppColors.ink);
  static const _head = TextStyle(height: 1.25, color: AppColors.navy);

  // Scale: 12 caption, 14 body-small, 16 body, 18 subtitle, 20 title,
  // 24 headline, 32 display; weights 400 / 600 / 700.
  static final TextTheme textTheme = TextTheme(
    displaySmall: _head.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
    headlineSmall: _head.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
    titleLarge: _head.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
    // Flutter draws text-field and dropdown values with titleMedium, so it
    // stays body-sized and regular weight.
    titleMedium: _body.copyWith(fontSize: 16),
    titleSmall: _head.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: _body.copyWith(fontSize: 16),
    bodyMedium: _body.copyWith(fontSize: 14),
    bodySmall: _body.copyWith(fontSize: 12, color: AppColors.muted),
    labelLarge: _body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: _body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: _body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
  );

  static const _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brandStrong,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandSoft,
    onPrimaryContainer: AppColors.brandStrong,
    secondary: AppColors.brand,
    onSecondary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: AppColors.danger,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.surfaceAlt,
    outline: AppColors.control,
    outlineVariant: AppColors.line,
  );

  static OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: c, width: w),
      );

  static final _buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.control));

  static const _tapSize = Size(64, Space.minTap);

  // A visible keyboard focus ring on every button style.
  static WidgetStateProperty<BorderSide?> _focusSide([Color? rest]) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.navy, width: 2);
        }
        return rest == null ? null : BorderSide(color: rest, width: 1.5);
      });

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surfaceAlt,
      focusColor: AppColors.brandStrong.withValues(alpha: 0.14),
      hoverColor: AppColors.brandStrong.withValues(alpha: 0.06),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _CalmTransitions(),
        TargetPlatform.iOS: _CalmTransitions(),
        TargetPlatform.windows: _CalmTransitions(),
        TargetPlatform.macOS: _CalmTransitions(),
        TargetPlatform.linux: _CalmTransitions(),
        TargetPlatform.fuchsia: _CalmTransitions(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge!.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(_tapSize),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(_buttonShape),
          textStyle: WidgetStatePropertyAll(
              textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled)
                  ? AppColors.brandStrong.withValues(alpha: 0.6)
                  : AppColors.brandStrong),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.2)
                  : s.contains(WidgetState.hovered)
                      ? Colors.white.withValues(alpha: 0.1)
                      : null),
          side: _focusSide(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(_tapSize),
          shape: WidgetStatePropertyAll(_buttonShape),
          textStyle: WidgetStatePropertyAll(
              textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600)),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.disabled)
                  ? AppColors.muted
                  : AppColors.brandStrong),
          side: _focusSide(AppColors.brandStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, Space.minTap)),
          shape: WidgetStatePropertyAll(_buttonShape),
          foregroundColor: const WidgetStatePropertyAll(AppColors.brandStrong),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: _focusSide(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: _focusSide(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandStrong,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sheet)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        constraints: const BoxConstraints(minHeight: Space.minTap),
        border: _border(AppColors.control),
        enabledBorder: _border(AppColors.control),
        disabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.brandStrong, 2),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, 2),
        hintStyle: textTheme.bodyMedium!.copyWith(color: AppColors.muted),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: AppColors.danger),
        errorMaxLines: 3,
        floatingLabelStyle:
            textTheme.labelLarge!.copyWith(color: AppColors.brandStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandStrong,
        side: const BorderSide(color: AppColors.control),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.pill)),
        labelStyle: textTheme.labelLarge!.copyWith(color: AppColors.muted),
        secondaryLabelStyle:
            textTheme.labelLarge!.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        showCheckmark: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.brandStrong : null),
        side: const BorderSide(color: AppColors.control, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sheet)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.brandStrong),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(Radii.control)),
        textStyle: textTheme.bodySmall!.copyWith(color: Colors.white),
      ),
    );
  }
}
