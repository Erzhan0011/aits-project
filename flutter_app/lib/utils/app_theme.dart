import 'package:flutter/material.dart';

class AppTheme {
  // Premium Modern Colors (Orange Brand)
  static const Color primaryOrange = Color(0xFFFF6B35); // Sunset Orange
  static const Color secondaryOrange = Color(0xFFFFA24C); // Soft Orange
  static const Color deepSlate = Color(0xFF1E293B); // Modern Dark Slate
  static const Color softBackground = Color(0xFFF8FAFC); // Clean background
  static const Color surfaceGlass = Colors.white;
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: secondaryOrange,
        surface: surfaceGlass,
        background: softBackground,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: softBackground,
      
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.withOpacity(0.08), width: 1),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: deepSlate,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: deepSlate,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: deepSlate, size: 24),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
