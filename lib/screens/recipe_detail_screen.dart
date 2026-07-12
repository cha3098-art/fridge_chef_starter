import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// 레시피 상세 화면 — 영양정보, 재료(보유 여부 표시), 조리순서를 보여준다
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final Set<String> fridgeIngredientNames;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.fridgeIngredientNames,
  });

  @override
  Widget build(BuildContext context) {
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final missing = recipe.missingIngredients(fridgeIngredientNames);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(recipe.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(label: recipe.cuisineType),
              _InfoChip(label: '난이도 ${recipe.difficulty}'),
              _InfoChip(label: '${recipe.cookTimeMin}분'),
              _InfoChip(label: '${recipe.caloriesPerServing}kcal'),
            ],
          ),
          const SizedBox(height: 16),
          _MatchBanner(matched: matched, total: total, missing: missing),
          const SizedBox(height: 20),
          const _SectionTitle('영양정보 (1인분 기준)'),
          const SizedBox(height: 10),
          _NutritionGrid(recipe: recipe),
          const SizedBox(height: 20),
          const _SectionTitle('재료'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFB),
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: recipe.ingredients
                  .map((ingredient) => _IngredientRow(
                        ingredient: ingredient,
                        owned: fridgeIngredientNames.contains(ingredient.name),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('조리순서'),
          const SizedBox(height: 10),
          Column(
            children: recipe.steps.map((step) => _StepTile(step: step)).toList(),
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
                isFull ? '냉장고 재료로 바로 만들 수 있어요' : '냉장고 재료 $matched/$total 매칭돼요',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '부족한 재료: ${missing.join(', ')}',
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
      ('탄수화물', '${recipe.carbsG.toStringAsFixed(0)}g'),
      ('단백질', '${recipe.proteinG.toStringAsFixed(0)}g'),
      ('지방', '${recipe.fatG.toStringAsFixed(0)}g'),
      ('나트륨', '${recipe.sodiumMg.toStringAsFixed(0)}mg'),
    ];

    return Row(
      children: [
        for (var i = 0; i < entries.length; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == entries.length - 1 ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
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

  const _IngredientRow({required this.ingredient, required this.owned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 0.6)),
      ),
      child: Row(
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
                    child: const Text('선택', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                  ),
                ],
              ],
            ),
          ),
          Text(ingredient.quantityLabel, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ],
      ),
    );
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFBF8F1)),
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
