import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/language_toggle.dart';

/// 레시피 상세 화면 — 영양정보, 재료(보유 여부 표시), 조리순서를 보여준다
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final Set<String> fridgeIngredientNames;
  final int servings;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.fridgeIngredientNames,
    this.servings = 1,
  });

  @override
  Widget build(BuildContext context) {
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final missing = recipe.missingIngredients(fridgeIngredientNames);
    final gradient = cuisineGradient(recipe.cuisineType);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: gradient.last,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: const [
              Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
              Padding(padding: EdgeInsets.only(right: 12), child: ChefTierBadge()),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                ),
              ),
              background: RecipePhoto(
                photoQuery: recipe.photoQuery,
                emoji: recipe.emoji,
                cuisineType: recipe.cuisineType,
                width: double.infinity,
                height: 180,
                emojiSize: 72,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(label: trServings(servings)),
                    _InfoChip(label: trTag(recipe.cuisineType)),
                    _InfoChip(label: '${tr('난이도', 'Level')} ${trTag(recipe.difficulty)}'),
                    _InfoChip(label: '${recipe.cookTimeMin}${tr('분', 'min')}'),
                    _InfoChip(label: '${recipe.caloriesPerServing}kcal'),
                  ],
                ),
                const SizedBox(height: 16),
                _MatchBanner(matched: matched, total: total, missing: missing),
                const SizedBox(height: 20),
                _SectionTitle(tr('영양정보 (1인분 기준)', 'Nutrition (per serving)')),
                const SizedBox(height: 10),
                _NutritionGrid(recipe: recipe),
                const SizedBox(height: 20),
                _SectionTitle(tr('재료 (1인분 기준)', 'Ingredients (per serving)')),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: recipe.ingredients
                        .map((ingredient) => _IngredientRow(
                              ingredient: ingredient,
                              owned: fridgeIngredientNames.contains(ingredient.name),
                              servings: servings,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(tr('조리순서', 'Steps')),
                const SizedBox(height: 10),
                Column(
                  children: recipe.steps.map((step) => _StepTile(step: step)).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink));
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
      ),
    );
  }
}

class _MatchBanner extends StatelessWidget {
  final int matched;
  final int total;
  final List<String> missing;

  const _MatchBanner({required this.matched, required this.total, required this.missing});

  @override
  Widget build(BuildContext context) {
    final isFull = missing.isEmpty;
    final bg = isFull ? AppColors.greenSoft : AppColors.goldSoft;
    final fg = isFull ? AppColors.green : const Color(0xFF9C6A15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFull ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                isFull
                    ? tr('냉장고 재료로 바로 만들 수 있어요', 'You can make this with what\'s in your fridge')
                    : tr('냉장고 재료 $matched/$total 매칭돼요', '$matched/$total ingredients matched'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('부족한 재료', 'Missing')}: ${missing.join(', ')}',
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  final Recipe recipe;
  const _NutritionGrid({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final entries = [
      (tr('탄수화물', 'Carbs'), '${recipe.carbsG.toStringAsFixed(0)}g'),
      (tr('단백질', 'Protein'), '${recipe.proteinG.toStringAsFixed(0)}g'),
      (tr('지방', 'Fat'), '${recipe.fatG.toStringAsFixed(0)}g'),
      (tr('나트륨', 'Sodium'), '${recipe.sodiumMg.toStringAsFixed(0)}mg'),
    ];

    return Row(
      children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == entries.length - 1 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(entries[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(entries[i].$1, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ingredient;
  final bool owned;
  final int servings;

  const _IngredientRow({required this.ingredient, required this.owned, required this.servings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                owned ? Icons.check_circle : Icons.remove_circle_outline,
                size: 16,
                color: owned ? AppColors.green : AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(ingredient.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (ingredient.isOptional) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.paperDeep,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tr('선택', 'Optional'), style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                ingredient.quantityLabelForServings(1),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: _ServingsBreakdown(ingredient: ingredient, selectedServings: servings),
          ),
        ],
      ),
    );
  }
}

/// 1인분 기준 수량 옆에 2/3/4인분일 때의 양을 괄호처럼 나란히 보여준다.
/// 필터에서 선택한 인분수(selectedServings)는 강조 표시한다.
class _ServingsBreakdown extends StatelessWidget {
  final RecipeIngredient ingredient;
  final int selectedServings;

  const _ServingsBreakdown({required this.ingredient, required this.selectedServings});

  @override
  Widget build(BuildContext context) {
    const tiers = [2, 3, 4];
    final spans = <InlineSpan>[
      const TextSpan(text: '(', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
    ];
    for (var i = 0; i < tiers.length; i++) {
      final tier = tiers[i];
      final isSelected = tier == selectedServings;
      spans.add(TextSpan(
        text: '${trTag('$tier인분')} ${ingredient.quantityLabelForServings(tier)}',
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? AppColors.green : AppColors.inkSoft,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ));
      if (i != tiers.length - 1) {
        spans.add(const TextSpan(text: ' · ', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)));
      }
    }
    spans.add(const TextSpan(text: ')', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)));
    return RichText(text: TextSpan(children: spans));
  }
}

class _StepTile extends StatelessWidget {
  final RecipeStep step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            child: Text(
              '${step.order}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                if (step.timerLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text(step.timerLabel!, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
