import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 트렌디한 미니멀 대시보드 톤 — 순백 대신 미세한 쿨그레이 배경 위에
/// 카드는 얇은 선 대신 은은한 그림자로 구분하는 디자인 토큰
class AppColors {
  // 미세한 회색빛이 도는 깔끔한 배경 (Tailwind gray-50/100)
  static const paper = Color(0xFFF9FAFB);
  static const paperDeep = Color(0xFFF3F4F6);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE5E7EB);
  static const ink = Color(0xFF111827);
  static const inkSoft = Color(0xFF6B7280);
  // 신선함을 주는 소프트 그린 포인트 컬러 (텍스트/아이콘 대비를 위해 green-500 기준)
  static const green = Color(0xFF22C55E);
  static const greenSoft = Color(0xFFDCFCE7);
  static const greenDeep = Color(0xFF15803D);
  static const gold = Color(0xFFF59E0B);
  static const goldSoft = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);
  // 배너/마스코트에 쓰는 따뜻한 오렌지 포인트 색
  static const carrot = Color(0xFFFB923C);
  static const carrotSoft = Color(0xFFFFEDD5);

  static const cardShadow = [
    BoxShadow(color: Color(0x14111827), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

/// 여백/모서리 반경을 화면마다 다시 정하지 않도록 모아둔 간격 토큰
/// radius는 Tailwind rounded-xl(12)/2xl(16)/3xl(24) 스케일에 맞춘다
class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
}

/// 카드형 컨테이너에 공통으로 쓰는 장식 — 얇은 회색 테두리 대신 부드러운 그림자로 입체감을 준다
BoxDecoration cardDecoration({double radius = AppSpacing.radiusMd, Color color = AppColors.card}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: AppColors.cardShadow,
  );
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
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paperDeep,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide.none,
        ),
        labelStyle: bodyFont.copyWith(color: AppColors.inkSoft, fontSize: 13),
      ),
      textTheme: TextTheme(
        bodyMedium: bodyFont.copyWith(color: AppColors.ink, fontSize: 14, height: 1.5, letterSpacing: 0.1),
        bodySmall: bodyFont.copyWith(color: AppColors.inkSoft, fontSize: 12, height: 1.4, letterSpacing: 0.15),
        titleLarge: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleMedium: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          height: 1.3,
          letterSpacing: -0.1,
        ),
        labelSmall: monoFont.copyWith(
          color: AppColors.inkSoft,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      useMaterial3: true,
    );
  }
}
