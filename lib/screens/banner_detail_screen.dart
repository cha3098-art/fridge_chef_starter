import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';

typedef _BannerSection = ({String icon, String headlineKo, String headlineEn, String bodyKo, String bodyEn});
typedef _BannerDetail = ({
  Color themeColor,
  String titleKo,
  String titleEn,
  String subtitleKo,
  String subtitleEn,
  List<_BannerSection> sections,
});

const _bannerDetails = <_BannerDetail>[
  (
    themeColor: Color(0xFFA855F7),
    titleKo: '장마철 식중독 조심! 🦠',
    titleEn: 'Watch out for food poisoning! 🦠',
    subtitleKo: '고온다습한 장마철, 냉장고 속 세균으로부터 우리 가족을 안전하게 지키는 올바른 위생 및 관리 가이드라인',
    subtitleEn: 'Hot, humid weather means faster bacteria growth — here\'s how to keep your fridge and family safe.',
    sections: [
      (
        icon: '🧼',
        headlineKo: '교차 오염 철저히 방지하기',
        headlineEn: 'Prevent cross-contamination',
        bodyKo: '익히지 않은 육류와 생선은 다른 식재료와 닿지 않도록 반드시 밀폐 용기에 담아 냉장고 가장 하단에 보관하세요. 채소류는 씻어서 보관할 경우 물기를 완전히 제거해야 세균 증식을 막을 수 있습니다.',
        bodyEn:
            'Keep raw meat and fish in sealed containers on the bottom shelf so they never touch other ingredients. If you wash vegetables before storing, dry them completely to slow bacteria growth.',
      ),
      (
        icon: '🌡️',
        headlineKo: '냉장고 적정 온도 유지 (70% 법칙)',
        headlineEn: 'Keep the right fridge temperature (the 70% rule)',
        bodyKo: '장마철에는 냉장실 5℃ 이하, 냉동실 -18℃ 이하를 엄격히 유지해 주세요. 냉장고 내부에 음식을 70% 이상 가득 채우면 냉기 순환이 차단되어 내부 온도가 상승하므로 여백을 꼭 확보해야 합니다.',
        bodyEn:
            'During the rainy season, keep the fridge at 5°C or below and the freezer at -18°C or below. Filling it past 70% blocks cold air circulation and raises the internal temperature, so leave some room.',
      ),
      (
        icon: '⏳',
        headlineKo: '유통기한 임박 재료 우선 소비',
        headlineEn: 'Use expiring ingredients first',
        bodyKo: '상하기 쉬운 우유나 두부 등은 앱의 유통기한 D-Day 알림을 확인하고 당일 또는 1일 전에 반드시 열을 가해 요리해서 소비해 주세요.',
        bodyEn:
            'For perishables like milk or tofu, check the app\'s D-Day expiry alerts and cook them thoroughly the day before or the day they expire.',
      ),
    ],
  ),
  (
    themeColor: Color(0xFFEF4444),
    titleKo: 'K-Food 챌린지 & Master 가이드 🇰🇷',
    titleEn: 'K-Food Challenge & Master Guide 🇰🇷',
    subtitleKo: '우리 일상의 한식을 마스터하고 포인트 2배의 기회와 전설의 셰프 타이틀을 거머쥐세요!',
    subtitleEn: 'Master everyday Korean dishes, earn double points, and claim a legendary chef title!',
    sections: [
      (
        icon: '🥇',
        headlineKo: 'K-Food 챌린지란 무엇인가요?',
        headlineEn: 'What is the K-Food Challenge?',
        bodyKo: '김치찌개, 불고기, 비빔밥 등 한국인의 소울 푸드 대표 레시피들을 직접 요리해 보는 도전형 콘텐츠입니다. 재료 매칭율을 확인하고 요리를 완성해 보세요!',
        bodyEn:
            'A cooking challenge built around Korean soul food — kimchi jjigae, bulgogi, bibimbap and more. Check your ingredient match rate and complete the dish!',
      ),
      (
        icon: '⭐',
        headlineKo: 'K-Food Master 등급 달성 기준',
        headlineEn: 'How to reach K-Food Master rank',
        bodyKo: 'K-Food 전용 레시피를 완성하고 자랑하기 게시판에 요리 완료 사진을 올릴 때마다 50P의 포인트와 등급 점수가 즉시 누적됩니다. 포인트를 모아 마이페이지 배지를 획득하세요.',
        bodyEn:
            'Every time you complete a K-Food recipe and post a photo to the showcase board, you earn 50P and rank progress instantly. Collect points to unlock badges on your profile.',
      ),
      (
        icon: '🎁',
        headlineKo: '챌린지 마스터 특별 혜택',
        headlineEn: 'Special perks for Challenge Masters',
        bodyKo: 'K-Food Master가 되면 식사 초대장을 생성하여 카카오톡이나 딥링크로 공유할 때 초대장 수령인과 발송인 모두 포인트를 2배로 적립받는 상시 부스터가 발동됩니다!',
        bodyEn:
            'Once you reach K-Food Master, sharing a meal invite link triggers a standing booster — both sender and recipient earn double points!',
      ),
    ],
  ),
  (
    themeColor: Color(0xFF3B82F6),
    titleKo: '냉장고 셰프 100% 활용 가이드 💡',
    titleEn: 'Get 100% out of Fridge Chef 💡',
    subtitleKo: '냉장실 정리부터 소셜 홈파티까지 앱의 가장 유용하고 편리한 대표 핵심 기능 가이드',
    subtitleEn: 'From organizing your fridge to hosting a social dinner — a guide to the app\'s best features.',
    sections: [
      (
        icon: '📸',
        headlineKo: '카메라 영수증 자동 등록',
        headlineEn: 'Auto-register items from a receipt photo',
        bodyKo: '장보고 받은 마트 영수증을 사진으로 찰칵 찍어보세요. AI OCR 엔진이 텍스트를 분석해 귀찮은 타이핑 없이 식재료명과 유통기한을 냉장고에 1초 만에 쏙 넣어줍니다.',
        bodyEn:
            'Snap a photo of your grocery receipt. The on-device OCR reads the text and adds ingredient names and expiry dates to your fridge instantly — no typing needed.',
      ),
      (
        icon: '🍳',
        headlineKo: 'AI 밀착형 레시피 추천',
        headlineEn: 'AI recipe matching from your fridge',
        bodyKo: '현재 냉장고에 보관 중인 대파, 애호박, 계란 등의 재료들을 기반으로 요리 가능한 매칭율(%)을 실시간 계산하여 부족한 재료와 완벽한 레시피 순서까지 가이드합니다.',
        bodyEn:
            'Based on what\'s actually in your fridge, recipes are matched with a live percentage score, showing exactly what\'s missing and the full cooking steps.',
      ),
      (
        icon: '✉️',
        headlineKo: '소셜 식사 초대장 & 딥링크',
        headlineEn: 'Social meal invites & deep links',
        bodyKo: '내가 만든 요리를 활용해 근사한 식사 초대 링크를 생성해 보세요. 친구가 공유된 딥링크를 누르면 앱이 자동으로 열리며 식사 초대 티켓이 화면에 쫀득하게 팝업됩니다.',
        bodyEn:
            'Turn a dish you made into a shareable invite link. When a friend taps it, the app opens automatically and the invite ticket pops right up.',
      ),
    ],
  ),
];

/// 대시보드 롤링 배너(식중독/K-Food/활용법)를 눌렀을 때 뜨는 상세 안내 화면.
/// main_dashboard_screen.dart와 같은 라이트 AppColors 톤을 쓴다 — 앱 전역 테마가 이미
/// AppTheme.light()라 별도 Theme() 래핑이 필요 없다.
class BannerDetailScreen extends StatelessWidget {
  final int bannerIndex;

  const BannerDetailScreen({super.key, required this.bannerIndex});

  @override
  Widget build(BuildContext context) {
    final detail = _bannerDetails[bannerIndex];
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            tr('상세 안내', 'Details'),
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.ink),
          ),
        ),
        body: Stack(
          children: [
            Positioned(
              top: -100,
              left: MediaQuery.of(context).size.width / 4,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: detail.themeColor.withValues(alpha: 0.10), blurRadius: 80, spreadRadius: 20),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(detail.titleKo, detail.titleEn),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(detail.subtitleKo, detail.subtitleEn),
                      style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.line, height: 32),
                    ...detail.sections.map((section) => Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder, width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: detail.themeColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: detail.themeColor.withValues(alpha: 0.25)),
                                ),
                                child: Center(child: Text(section.icon, style: const TextStyle(fontSize: 22, height: 1.1))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(section.headlineKo, section.headlineEn),
                                      style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      tr(section.bodyKo, section.bodyEn),
                                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.paperDeep,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.line),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          tr('가이드 확인 완료', 'Got it'),
                          style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
