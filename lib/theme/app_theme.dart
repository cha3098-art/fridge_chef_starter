import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 배달의민족류 앱처럼 흰 바탕 위에 포인트 컬러만 쓰는 디자인 토큰
class AppColors {
  static const paper = Color(0xFFFFFFFF);
  static const paperDeep = Color(0xFFF1F1F1);
  static const line = Color(0xFFE7E7E7);
  static const ink = Color(0xFF222222);
  static const inkSoft = Color(0xFF767676);
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
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      useMaterial3: true,
    );
  }
}
