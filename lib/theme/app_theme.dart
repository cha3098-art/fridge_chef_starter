import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// UI디자인_v3.html에서 정의한 디자인 토큰을 Flutter로 옮긴 테마 파일
class AppColors {
  static const paper = Color(0xFFF6F2E8);
  static const paperDeep = Color(0xFFEFE9DA);
  static const line = Color(0xFFDCD2B8);
  static const ink = Color(0xFF23241F);
  static const inkSoft = Color(0xFF6E6656);
  static const green = Color(0xFF3C7A4B);
  static const greenSoft = Color(0xFFE3EEDF);
  static const gold = Color(0xFFD9922C);
  static const goldSoft = Color(0xFFFBEBCF);
  static const red = Color(0xFFB8462F);
  static const redSoft = Color(0xFFF7E4DE);
}

class AppTheme {
  static ThemeData light() {
    final bodyFont = GoogleFonts.notoSansKr(); // Pretendard 미배포 시 대체 폰트
    final monoFont = GoogleFonts.ibmPlexMono();

    return ThemeData(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.ink,
        secondary: AppColors.green,
        surface: AppColors.paper,
      ),
      textTheme: TextTheme(
        bodyMedium: bodyFont.copyWith(color: AppColors.ink, fontSize: 14),
        bodySmall: bodyFont.copyWith(color: AppColors.inkSoft, fontSize: 12),
        titleMedium: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        labelSmall: monoFont.copyWith(
          color: AppColors.inkSoft,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: const Color(0xFFFBF8F1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      useMaterial3: true,
    );
  }
}
