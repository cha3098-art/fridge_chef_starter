import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 배달의민족/요기요 스타일의 트렌디 푸드테크 톤 — 쨍한 원색 대신 차분한 민트 포인트와
/// 넓은 화이트 스페이스, 얇은 테두리선으로 구분하는 디자인 토큰
class AppColors {
  // 차분한 연그레이 배경 (UX 가이드 Background 값)
  static const paper = Color(0xFFF8FAFC);
  static const paperDeep = Color(0xFFF3F4F6);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE5E7EB);
  static const ink = Color(0xFF111827);
  static const inkSoft = Color(0xFF6B7280);
  // 배민 민트톤을 참고한 시그니처 포인트 컬러 (채도를 낮춘 파스텔 & 뉴트럴 톤)
  static const green = Color(0xFF2AC1BC);
  static const greenSoft = Color(0xFFE0F7F6);
  static const greenDeep = Color(0xFF1C9994);
  static const gold = Color(0xFFF59E0B);
  static const goldSoft = Color(0xFFFEF3C7);
  // 소프트 레드 (UX 가이드 Danger 값)
  static const red = Color(0xFFF43F5E);
  static const redSoft = Color(0xFFFFE1E6);
  // 식욕을 자극하는 오렌지 포인트 색 (UX 가이드 Accent 값)
  static const carrot = Color(0xFFFF5B1F);
  static const carrotSoft = Color(0xFFFFE2D6);

  // 흰 카드를 옅은 배경과 구분할 때 쓰는 아주 얇은 테두리선 (그림자 대신)
  static const cardBorder = Color(0xFFF1F5F9);

  // 그라데이션 배너류는 자체 색으로 배경과 구분되므로 그림자를 걷어내 플랫하게 유지한다
  static const cardShadow = <BoxShadow>[];
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

/// 카드형 컨테이너에 공통으로 쓰는 장식 — 그림자 대신 아주 얇은 테두리선으로 입체감 없이 구분한다
BoxDecoration cardDecoration({double radius = AppSpacing.radiusMd, Color color = AppColors.card}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cardBorder, width: 1),
  );
}

class AppTheme {
  static ThemeData light() {
    // Pretendard는 Google Fonts에 없는 별도 배포 폰트라 assets/fonts에 번들해서 쓴다
    const bodyFont = TextStyle(fontFamily: 'Pretendard');
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
        // 제목(titleLarge/titleMedium)은 w800, 본문(bodyMedium/bodySmall)은 w400으로
        // 굵기 대비를 뚜렷하게 줘서 위계를 명확히 한다
        bodyMedium: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.5,
          letterSpacing: 0.1,
        ),
        bodySmall: bodyFont.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          height: 1.4,
          letterSpacing: 0.15,
        ),
        titleLarge: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleMedium: bodyFont.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
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
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      useMaterial3: true,
    );
  }
}
