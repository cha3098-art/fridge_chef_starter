import 'package:flutter/material.dart';
import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/recipe.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/ingredient_swap_sheet.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_return_button.dart';
import '../widgets/step_visual.dart';
import 'cooking_mode_screen.dart';

/// 레시피 상세 화면 — 영양정보, 재료(보유 여부 표시), 조리순서를 보여준다
class RecipeDetailScreen extends StatefulWidget {
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
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late int _selectedServings;

  @override
  void initState() {
    super.initState();
    _selectedServings = widget.servings;
  }

  Future<void> _selectAndConsume() async {
    final recipe = widget.recipe;
    final n = _selectedServings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('요리 선택 확인', 'Confirm selection'),
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
        ),
        content: Text(
          tr('${recipe.title} $n인분을 요리할까요?\n냉장고 재료가 차감됩니다.',
              'Cook ${recipe.titleEn} for $n ${n > 1 ? 'servings' : 'serving'}?\nIngredients will be deducted from your fridge.'),
          style: const TextStyle(
              fontSize: 14, color: AppColors.inkSoft, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('취소', 'Cancel'),
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr('요리 시작!', 'Start cooking!'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FridgeStore.instance
          .consumeIngredients(widget.recipe.ingredients, n);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🍳 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(tr('${recipe.title} $n인분 재료를 냉장고에서 차감했어요!',
                      'Deducted $n-serving ingredients from your fridge!')),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.ink,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final fridgeIngredientNames = widget.fridgeIngredientNames;
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final missing = recipe.missingIngredients(fridgeIngredientNames);
    final gradient = cuisineGradient(recipe.cuisineType);

    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Slate 50
        floatingActionButton: const MainReturnButton(),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 180,
              backgroundColor: gradient.last,
              foregroundColor: Colors.white,
              leading: const LabeledBackButton(color: Colors.white),
              leadingWidth: 96,
              iconTheme: const IconThemeData(
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
              ),
              actions: const [
                Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: LanguageToggle()),
                Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: ChefTierBadge()),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  tr(recipe.title, recipe.titleEn),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecipePhoto(
                      photoUrl: recipe.photoUrl,
                      emoji: recipe.emoji,
                      cuisineType: recipe.cuisineType,
                      width: double.infinity,
                      height: 180,
                      emojiSize: 72,
                    ),
                    // 사진이 밝은 톤(흰 접시·밥 등)이어도 뒤로가기 화살표가 항상 또렷하게
                    // 보이도록, 상단에만 은은하게 어두워지는 그라데이션 스크림을 깐다.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black45, Colors.transparent],
                          stops: [0.0, 0.55],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
              sliver: SliverList.list(
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoChip(label: trServings(_selectedServings)),
                      _InfoChip(label: trTag(recipe.cuisineType)),
                      _InfoChip(
                          label:
                              '${tr('난이도', 'Level')} ${trTag(recipe.difficulty)}'),
                      _InfoChip(
                          label: '${recipe.cookTimeMin}${tr('분', 'min')}'),
                      _InfoChip(label: '${recipe.caloriesPerServing}kcal'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MatchBanner(
                      matched: matched, total: total, missing: missing),
                  const SizedBox(height: 20),
                  _SectionTitle(tr('영양정보 (1인분 기준)', 'Nutrition (per serving)')),
                  const SizedBox(height: 10),
                  _NutritionGrid(recipe: recipe),
                  const SizedBox(height: 20),
                  _SectionTitle(tr('재료 (1인분 기준)', 'Ingredients (per serving)')),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFF1F5F9), width: 1),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Column(
                      children: recipe.ingredients
                          .map((ingredient) => _IngredientRow(
                                ingredient: ingredient,
                                owned: fridgeIngredientNames
                                    .contains(ingredient.name),
                                servings: _selectedServings,
                                fridgeIngredientNames: fridgeIngredientNames,
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(tr('조리순서', 'Steps')),
                  const SizedBox(height: 10),
                  Column(
                    children: recipe.steps
                        .map((step) => _StepTile(
                            step: step, recipePhotoUrl: recipe.photoUrl))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  void _startCookingMode() {
    final recipe = widget.recipe;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CookingModeScreen(
          title: tr(recipe.title, recipe.titleEn),
          photoUrl: recipe.photoUrl,
          cuisineType: recipe.cuisineType,
          emoji: recipe.emoji,
          steps: recipe.steps
              .map((s) => tr(s.description, s.descriptionEn))
              .toList(),
          stepImages: recipe.steps.map((s) => s.imageAsset).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _startCookingMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '🍳 요리 시작 (음성 모드)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 인분 스테퍼
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepBtn(
                        icon: Icons.remove,
                        onTap: _selectedServings > 1
                            ? () => setState(() => _selectedServings--)
                            : null,
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          tr('$_selectedServings인분',
                              '$_selectedServings serv.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      _stepBtn(
                        icon: Icons.add,
                        onTap: _selectedServings < 8
                            ? () => setState(() => _selectedServings++)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 요리 선택 CTA
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectAndConsume,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍳', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            tr('요리 선택하기', 'Cook this'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? const Color(0xFFCBD5E1) : AppColors.ink,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.ink,
          letterSpacing: -0.2),
    );
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
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
            letterSpacing: 0.1),
      ),
    );
  }
}

class _MatchBanner extends StatelessWidget {
  final int matched;
  final int total;
  final List<String> missing;

  const _MatchBanner(
      {required this.matched, required this.total, required this.missing});

  @override
  Widget build(BuildContext context) {
    final isFull = missing.isEmpty;
    final bg = isFull ? const Color(0xFFE0F7F6) : const Color(0xFFFEF3C7);
    final fg = isFull ? AppColors.green : const Color(0xFF9C6A15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
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
                    ? tr('냉장고 재료로 바로 만들 수 있어요',
                        'You can make this with what\'s in your fridge')
                    : tr('냉장고 재료 $matched/$total 매칭돼요',
                        '$matched/$total ingredients matched'),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('부족한 재료', 'Missing')}: ${missing.map(trIngredientName).join(', ')}',
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    entries[i].$2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.1),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entries[i].$1,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft, height: 1.4),
                  ),
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
  final Set<String> fridgeIngredientNames;

  const _IngredientRow({
    required this.ingredient,
    required this.owned,
    required this.servings,
    required this.fridgeIngredientNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
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
                    Text(
                      trIngredientName(ingredient.name),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1),
                    ),
                    if (ingredient.isOptional) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.paperDeep,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tr('선택', 'Optional'),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.inkSoft)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                ingredient.localizedQuantityLabelForServings(1),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => showIngredientSwapSheet(
                  context,
                  ingredientName: ingredient.name,
                  fridgeIngredientNames: fridgeIngredientNames,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.paperDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Text(
                    '🔄 대체',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: _ServingsBreakdown(
                ingredient: ingredient, selectedServings: servings),
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

  const _ServingsBreakdown(
      {required this.ingredient, required this.selectedServings});

  @override
  Widget build(BuildContext context) {
    const tiers = [2, 3, 4];
    final spans = <InlineSpan>[
      const TextSpan(
          text: '(', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
    ];
    for (var i = 0; i < tiers.length; i++) {
      final tier = tiers[i];
      final isSelected = tier == selectedServings;
      spans.add(TextSpan(
        text:
            '${trTag('$tier인분')} ${ingredient.localizedQuantityLabelForServings(tier)}',
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? AppColors.ink : AppColors.inkSoft,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ));
      if (i != tiers.length - 1) {
        spans.add(const TextSpan(
            text: ' · ',
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft)));
      }
    }
    spans.add(const TextSpan(
        text: ')', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)));
    return RichText(text: TextSpan(children: spans));
  }
}

class _StepTile extends StatelessWidget {
  final RecipeStep step;
  final String? recipePhotoUrl;
  const _StepTile({required this.step, this.recipePhotoUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: StepVisual(
                imageAsset: step.imageAsset,
                recipePhotoUrl: recipePhotoUrl,
                stepDescription: step.description,
                width: 88,
                height: 88,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xFF2AC1BC), shape: BoxShape.circle),
            child: Text(
              '${step.order}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFFFFF)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(step.description, step.descriptionEn),
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, letterSpacing: 0.1)),
                if (localizedTimerLabel(step.timerSec) != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text(localizedTimerLabel(step.timerSec)!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkSoft)),
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
