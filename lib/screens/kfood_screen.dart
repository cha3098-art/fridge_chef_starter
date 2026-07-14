import 'package:flutter/material.dart';

import '../data/kfood_catalog.dart';
import '../l10n/tr.dart';
import '../models/recipe.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'recipe_detail_screen.dart';

/// "K-Food 만들기" — 대표 한식 레시피 모음. 완성/초대 시 K-Food 전용 포인트가 쌓인다.
class KFoodScreen extends StatelessWidget {
  final Set<String> fridgeIngredientNames;

  const KFoodScreen({super.key, required this.fridgeIngredientNames});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('K-Food 만들기', 'Make K-Food'),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
          Padding(padding: EdgeInsets.only(right: 12), child: ChefTierBadge()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC23A3A), Color(0xFF1B3A6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('🇰🇷 대한민국 대표 요리', '🇰🇷 Iconic Korean Dishes'),
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('집에서 만드는 K-Food', 'Make K-Food at Home'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('완성하고 자랑하면 K-Food 포인트가 쌓여요 · 초대장은 2배!', 'Finish and brag to earn K-Food points · invites earn double!'),
                  style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.5, letterSpacing: 0.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kfoodCatalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final recipe = kfoodCatalog[index];
              return _KFoodCard(
                recipe: recipe,
                fridgeIngredientNames: fridgeIngredientNames,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: 6,
        fridgeIngredientNames: fridgeIngredientNames,
      ),
      ),
    );
  }
}

class _KFoodCard extends StatelessWidget {
  final Recipe recipe;
  final Set<String> fridgeIngredientNames;

  const _KFoodCard({required this.recipe, required this.fridgeIngredientNames});

  @override
  Widget build(BuildContext context) {
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final isFullMatch = matched >= total;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(
            recipe: recipe,
            fridgeIngredientNames: fridgeIngredientNames,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RecipePhoto(
                  photoUrl: recipe.photoUrl,
                  emoji: recipe.emoji,
                  cuisineType: recipe.cuisineType,
                  width: double.infinity,
                  height: 96,
                  emojiSize: 32,
                ),
                if (isFullMatch)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tr('완성', 'Ready'),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${tr('난이도', 'Level')} ${trTag(recipe.difficulty)} · ${recipe.cookTimeMin}${tr('분', 'min')}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr('재료 $matched/$total', '$matched/$total items'),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
