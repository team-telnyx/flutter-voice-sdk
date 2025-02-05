import 'package:flutter/material.dart';

// Theme colors
const surfaceColor = Color(0xFFFEFDF5);
const darkSurfaceColor = Color(0xFFf6f4e6);
const primaryColor = Colors.black;
const secondaryColor = Colors.white;
const disabledColor = Color(0xFF808080); // Gray for disabled state
const telnyx_soft_black = Color(0xFF272727);
const telnyx_grey = Color(0xFF525252);
const telnyx_green = Color(0xFF00E3AA);
const active_text_field_color = Color(0xFF008563);
const call_control_color = Color(0xFFF5F3E4);

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: secondaryColor,
        secondary: secondaryColor,
        onSecondary: primaryColor,
        surface: darkSurfaceColor,
      ),

      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: telnyx_soft_black,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: telnyx_soft_black,
        ),
        labelMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: telnyx_grey,
        ),
        labelSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: telnyx_grey,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        labelStyle: const TextStyle(color: primaryColor),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return disabledColor;
              }
              return primaryColor;
            },
          ),
          foregroundColor: WidgetStateProperty.all(secondaryColor),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(style: BorderStyle.solid, color: Colors.red, width: 2),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return disabledColor;
              }
              return secondaryColor;
            },
          ),
          foregroundColor: WidgetStateProperty.all(primaryColor),
        ),
      ),

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: primaryColor,
        elevation: 0,
      ),

      // Scaffold background color
      scaffoldBackgroundColor: surfaceColor,
    );
  }
}
