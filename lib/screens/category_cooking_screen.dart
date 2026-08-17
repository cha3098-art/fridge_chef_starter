import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
import '../widgets/tab_tutorial_overlay.dart';
import 'kfood_screen.dart';
import 'recommendation_screen.dart';

/// "요리하기" 대분류 화면 — 상단 세그먼트 탭 [레시피 추천 | K-Food]으로 즉시 전환.
class CategoryCookingScreen extends StatefulWidget {
  const CategoryCookingScreen({super.key});

  @override
  State<CategoryCookingScreen> createState() => _CategoryCookingScreenState();
}

class _CategoryCookingScreenState extends State<CategoryCookingScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabTutorialOverlay.showIfNeeded(
        context,
        prefsKey: 'hide_tutorial_tab_2_cooking',
        imageAsset: tr('assets/images/tutorial/tab_2_cooking.png',
            'assets/images/tutorial/tab_2_cooking_en.png'),
        title: tr('🍳 맞춤 레시피 추천 & K-Food', '🍳 Personalized recipes & K-Food'),
        bodyLines: [
          tr('내 냉장고 속 재료로 만들 수 있는 레시피를 매칭률순으로 추천해 드립니다.',
              "We recommend recipes ranked by how well they match what's in your fridge."),
          tr('인분, 난이도, 조리시간별 맞춤 필터를 설정하고 음성 가이드로 요리해 보세요.',
              'Set filters for servings, difficulty, and cook time, then cook along with voice guidance.'),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FridgeStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        final names = FridgeStore.instance.items.map((i) => i.name).toSet();
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            leading: const LabeledBackButton(),
            leadingWidth: 96,
            backgroundColor: AppColors.paper,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 76,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/icon/icon_recipe.png',
                      width: 58, height: 58, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr('요리하기', 'Cook'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink)),
                ),
              ],
            ),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 16), child: LanguageToggle()),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedTabBar(
                  labels: [tr('레시피 추천', 'Recipes'), tr('K-Food', 'K-Food')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _tab,
            children: [
              RecommendationScreen(fridgeIngredientNames: names, embed: true),
              KFoodScreen(fridgeIngredientNames: names, embed: true),
            ],
          ),
          extendBody: true,
          bottomNavigationBar:
              MainBottomNav(currentIndex: 2, fridgeIngredientNames: names),
        );
      },
    );
  }
}
