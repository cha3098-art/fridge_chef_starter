import 'package:flutter/material.dart';
import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/recipe.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'recipe_detail_screen.dart';

const _cookTimeOptions = ['전체', '15분 이내', '30분 이내', '60분 이내'];
const _difficultyOptions = ['전체', '하', '중', '상'];
const _cuisineOptions = ['전체', '한식', '중식', '양식', '분식'];
const _servingsOptions = ['1인분', '2인분', '3인분', '4인분'];

const _cuisineEmoji = {
  '전체': '🍽️',
  '한식': '🍚',
  '중식': '🥡',
  '양식': '🍝',
  '분식': '🍢',
};

typedef RecommendationFilter = ({
  bool onlyFullMatch,
  String cookTime,
  String difficulty,
  String cuisine,
  int servings,
});

const _defaultFilter = (
  onlyFullMatch: false,
  cookTime: '전체',
  difficulty: '전체',
  cuisine: '전체',
  servings: 1,
);

/// "추천" 탭 — 내 냉장고 재료와 매칭되는 레시피를 보여주는 화면
/// 실제로는 Supabase의 recipes/recipe_ingredients에서 매칭 쿼리로 불러오도록 교체 예정
class RecommendationScreen extends StatefulWidget {
  final Set<String> fridgeIngredientNames;

  const RecommendationScreen({super.key, required this.fridgeIngredientNames});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  RecommendationFilter _filter = _defaultFilter;

  static const _fallbackCount = 5;

  /// onlyFullMatch 조건에서 완전히 일치하는 레시피가 하나도 없으면
  /// 가장 가까운 상위 [_fallbackCount]개를 대신 보여준다 (isFallback = true)
  ({List<Recipe> recipes, bool isFallback}) _computeRecipes() {
    final base = recipeCatalog.where((r) {
      if (_filter.cookTime != '전체') {
        final maxMin = int.parse(_filter.cookTime.replaceAll(RegExp(r'[^0-9]'), ''));
        if (r.cookTimeMin > maxMin) return false;
      }
      if (_filter.difficulty != '전체' && r.difficulty != _filter.difficulty) return false;
      if (_filter.cuisine != '전체' && r.cuisineType != _filter.cuisine) return false;
      return true;
    }).toList();

    base.sort((a, b) {
      final matchedA = a.matchedCount(widget.fridgeIngredientNames);
      final matchedB = b.matchedCount(widget.fridgeIngredientNames);
      if (matchedA != matchedB) return matchedB.compareTo(matchedA);
      return a.requiredIngredients.length.compareTo(b.requiredIngredients.length);
    });

    if (!_filter.onlyFullMatch) return (recipes: base, isFallback: false);

    final fullMatches = base
        .where((r) => r.matchedCount(widget.fridgeIngredientNames) >= r.requiredIngredients.length)
        .toList();
    if (fullMatches.isNotEmpty) return (recipes: fullMatches, isFallback: false);

    return (recipes: base.take(_fallbackCount).toList(), isFallback: base.isNotEmpty);
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filter.onlyFullMatch) count++;
    if (_filter.cookTime != '전체') count++;
    if (_filter.difficulty != '전체') count++;
    if (_filter.cuisine != '전체') count++;
    if (_filter.servings != 1) count++;
    return count;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<RecommendationFilter>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _computeRecipes();
    final recipes = result.recipes;
    final isFallback = result.isFallback;

    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('레시피 추천', 'Recipe Picks')),
        actions: [
          const Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
          const Padding(padding: EdgeInsets.only(right: 8), child: ChefTierBadge()),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0 ? AppColors.ink : AppColors.paperDeep,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _activeFilterCount > 0 ? AppColors.ink : AppColors.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: _activeFilterCount > 0 ? const Color(0xFFFFFFFF) : AppColors.ink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tr('필터', 'Filter'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _activeFilterCount > 0 ? const Color(0xFFFFFFFF) : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              scrollDirection: Axis.horizontal,
              itemCount: _cuisineOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final cuisine = _cuisineOptions[index];
                return _CuisineIcon(
                  cuisine: cuisine,
                  active: _filter.cuisine == cuisine,
                  onTap: () => setState(() => _filter = (
                        onlyFullMatch: _filter.onlyFullMatch,
                        cookTime: _filter.cookTime,
                        difficulty: _filter.difficulty,
                        cuisine: cuisine,
                        servings: _filter.servings,
                      )),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              tr('레시피 ${recipes.length}개', '${recipes.length} recipes'),
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
          if (isFallback)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF9C6A15)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr(
                          '냉장고 재료만으로 완성되는 레시피가 없어서, 가장 가까운 레시피를 보여드려요',
                          'No recipe matches your fridge exactly, so here are the closest ones',
                        ),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9C6A15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: recipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FridgeMascot(size: 84),
                        const SizedBox(height: AppSpacing.md),
                        Text(tr('조건에 맞는 레시피가 없어요', 'No recipes match these filters'), style: const TextStyle(color: AppColors.inkSoft)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      return _RecipeCard(
                        recipe: recipe,
                        fridgeIngredientNames: widget.fridgeIngredientNames,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                              recipe: recipe,
                              fridgeIngredientNames: widget.fridgeIngredientNames,
                              servings: _filter.servings,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: 1,
        fridgeIngredientNames: widget.fridgeIngredientNames,
      ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Set<String> fridgeIngredientNames;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.fridgeIngredientNames,
    required this.onTap,
  });

  Color _matchBg(RecipeMatchLevel level) {
    switch (level) {
      case RecipeMatchLevel.full:
        return AppColors.greenSoft;
      case RecipeMatchLevel.partial:
        return AppColors.goldSoft;
      case RecipeMatchLevel.low:
        return AppColors.paperDeep;
    }
  }

  Color _matchFg(RecipeMatchLevel level) {
    switch (level) {
      case RecipeMatchLevel.full:
        return AppColors.green;
      case RecipeMatchLevel.partial:
        return const Color(0xFF9C6A15);
      case RecipeMatchLevel.low:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final level = recipe.matchLevel(fridgeIngredientNames);
    final missing = recipe.missingIngredients(fridgeIngredientNames);
    final gradient = cuisineGradient(recipe.cuisineType);
    final percent = total == 0 ? 1.0 : matched / total;
    final percentLabel = (percent * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 재료 매칭률을 카드 상단에 프로그레스 바 + 퍼센트로 바로 보여준다
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: AppColors.paperDeep,
                      valueColor: AlwaysStoppedAnimation(_matchFg(level)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _matchBg(level),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    level == RecipeMatchLevel.full ? tr('완성 가능', 'Ready') : '$percentLabel%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _matchFg(level)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(recipe.emoji, style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${trTag(recipe.cuisineType)} · ${tr('난이도', 'Level')} ${trTag(recipe.difficulty)} · ${recipe.cookTimeMin}${tr('분', 'min')} · ${recipe.caloriesPerServing}kcal',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                      Text(
                        tr('재료 $matched/$total개 보유', '$matched/$total items on hand'),
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                      if (missing.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${tr('부족한 재료', 'Missing')}: ${missing.join(', ')}',
                          style: const TextStyle(fontSize: 11, color: AppColors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final RecommendationFilter initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RecommendationFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('필터', 'Filter'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.green,
            title: Text(tr('냉장고 재료만으로 만들 수 있는 레시피만', 'Only recipes I can fully make'), style: const TextStyle(fontSize: 13)),
            value: _draft.onlyFullMatch,
            onChanged: (v) => setState(() => _draft = (
                  onlyFullMatch: v,
                  cookTime: _draft.cookTime,
                  difficulty: _draft.difficulty,
                  cuisine: _draft.cuisine,
                  servings: _draft.servings,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: tr('만드는 양', 'Servings'),
            options: _servingsOptions,
            selected: '${_draft.servings}인분',
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: _draft.cookTime,
                  difficulty: _draft.difficulty,
                  cuisine: _draft.cuisine,
                  servings: int.parse(v.replaceAll(RegExp(r'[^0-9]'), '')),
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: tr('조리시간', 'Cook time'),
            options: _cookTimeOptions,
            selected: _draft.cookTime,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: v,
                  difficulty: _draft.difficulty,
                  cuisine: _draft.cuisine,
                  servings: _draft.servings,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: tr('난이도', 'Difficulty'),
            options: _difficultyOptions,
            selected: _draft.difficulty,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: _draft.cookTime,
                  difficulty: v,
                  cuisine: _draft.cuisine,
                  servings: _draft.servings,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: tr('요리 종류', 'Cuisine'),
            options: _cuisineOptions,
            selected: _draft.cuisine,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: _draft.cookTime,
                  difficulty: _draft.difficulty,
                  cuisine: v,
                  servings: _draft.servings,
                )),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _defaultFilter),
                  child: Text(tr('초기화', 'Reset')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: Text(tr('적용하기', 'Apply')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(trTag(option), style: const TextStyle(fontSize: 12)),
                selected: selected == option,
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.paperDeep,
                labelStyle: TextStyle(
                  color: selected == option ? const Color(0xFFFFFFFF) : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: selected == option ? AppColors.ink : AppColors.line),
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}

/// 배달앱 홈 화면 카테고리 아이콘을 벤치마킹한 요리종류 원형 퀵필터
class _CuisineIcon extends StatelessWidget {
  final String cuisine;
  final bool active;
  final VoidCallback onTap;

  const _CuisineIcon({required this.cuisine, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: cuisine == '전체'
                      ? (active ? [AppColors.green, AppColors.greenDeep] : [AppColors.paperDeep, AppColors.paperDeep])
                      : cuisineGradient(cuisine),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: active
                    ? Border.all(color: AppColors.green, width: 2.5)
                    : Border.all(color: Colors.transparent, width: 2.5),
                boxShadow: active ? AppColors.cardShadow : null,
              ),
              child: Text(_cuisineEmoji[cuisine] ?? '🍽️', style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 4),
            Text(
              trTag(cuisine),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.green : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
