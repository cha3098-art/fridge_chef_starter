import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';
import 'auth_gate.dart';

/// 앱을 처음 켰을 때만 한 번 보여주는 3장짜리 소개 슬라이드.
/// 완료/건너뛰기 시 SharedPreferences에 기록해 다음부터는 바로 AuthGate로 진입한다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _seenKey = 'has_seen_onboarding';

  /// main.dart에서 앱 시작 시 온보딩을 보여줄지 판단할 때 쓴다
  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> get _onboardingData => [
        {
          'emoji': '⏰',
          'title': tr('버려지는 재료 없이\n똑똑한 냉장고 구출 작전',
              'Smart fridge rescue —\nno more wasted ingredients'),
          'subtitle': tr(
              '냉장고에 재료를 등록하면 유통기한 임박 시점에 맞춰 기기가 알아서 알림을 울려줘요. 상해서 버리는 아까운 식재료를 제로(0)로 만들어 보세요!',
              "Register ingredients and your phone alerts you right before they expire. Let's get food waste down to zero!"),
        },
        {
          'emoji': '🍳',
          'title': tr('있는 재료만 콕 집어\n맞춤형 레시피 추천',
              'Recipes picked from\nwhat you already have'),
          'subtitle': tr(
              '새로 장 볼 필요 없이 지금 냉장고에 있는 재료를 기반으로 매칭률(%)이 가장 높은 레시피를 제안합니다. 터치 한 번으로 저녁 고민 끝!',
              'No need to go shopping — we suggest recipes with the highest match rate based on what\'s already in your fridge. One tap and dinner is sorted!'),
        },
        {
          'emoji': '✉️',
          'title': tr('오늘 저녁은 홈파티!\n식사 초대장 공유',
              'Tonight, a home party!\nShare a meal invite'),
          'subtitle': tr(
              '오늘 만든 근사한 요리를 초대장 링크로 친구들에게 빠르게 공유해 보세요. 링크를 누르면 친구도 앱으로 바로 연결되어 소중한 한 끼를 함께 나눌 수 있어요.',
              "Share today's dish with friends via an invite link. One tap and they're right in the app with you, ready to enjoy the meal together."),
        },
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isLast = _currentPage == _onboardingData.length - 1;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const LanguageToggle(),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      tr('건너뛰기', 'Skip'),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder, width: 1),
                          ),
                          child: Center(
                            child: Text(data['emoji']!, style: const TextStyle(fontSize: 72)),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          data['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          data['subtitle']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.ink : AppColors.line,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLast) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLast ? const Color(0xFF1E1E1E) : AppColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isLast
                            ? tr('냉장고 털러 가기', 'Raid the fridge')
                            : tr('다음 단계', 'Next'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen._seenKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}
