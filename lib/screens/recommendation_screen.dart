import 'package:flutter/material.dart';
import '../data/recipe_catalog.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';

const _cookTimeOptions = ['전체', '15분 이내', '30분 이내', '60분 이내'];
const _difficultyOptions = ['전체', '하', '중', '상'];
const _cuisineOptions = ['전체', '한식', '중식', '양식', '분식'];

typedef RecommendationFilter = ({
  bool onlyFullMatch,
  String cookTime,
  String difficulty,
  String cuisine,
});

const _defaultFilter = (
  onlyFullMatch: false,
  cookTime: '전체',
  difficulty: '전체',
  cuisine: '전체',
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

  List<Recipe> get _filtered {
    final list = recipeCatalog.where((r) {
      if (_filter.onlyFullMatch &&
          r.matchedCount(widget.fridgeIngredientNames) < r.requiredIngredients.length) {
        return false;
      }
      if (_filter.cookTime != '전체') {
        final maxMin = int.parse(_filter.cookTime.replaceAll(RegExp(r'[^0-9]'), ''));
        if (r.cookTimeMin > maxMin) return false;
      }
      if (_filter.difficulty != '전체' && r.difficulty != _filter.difficulty) return false;
      if (_filter.cuisine != '전체' && r.cuisineType != _filter.cuisine) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      final matchedA = a.matchedCount(widget.fridgeIngredientNames);
      final matchedB = b.matchedCount(widget.fridgeIngredientNames);
      if (matchedA != matchedB) return matchedB.compareTo(matchedA);
      return a.requiredIngredients.length.compareTo(b.requiredIngredients.length);
    });
    return list;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filter.onlyFullMatch) count++;
    if (_filter.cookTime != '전체') count++;
    if (_filter.difficulty != '전체') count++;
    if (_filter.cuisine != '전체') count++;
    return count;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<RecommendationFilter>(
      context: context,
      backgroundColor: const Color(0xFFFFFEFB),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filtered;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('레시피 추천'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune, color: AppColors.ink),
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '레시피 ${recipes.length}개',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
          Expanded(
            child: recipes.isEmpty
                ? const Center(
                    child: Text('조건에 맞는 레시피가 없어요', style: TextStyle(color: AppColors.inkSoft)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: recipes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      return _RecipeCard(
                        recipe: recipe,
                        fridgeIngredientNames: widget.fridgeIngredientNames,
                        onTap: () => _showComingSoon('레시피 상세는 준비 중이에요'),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.inkSoft,
        backgroundColor: const Color(0xFFFFFEFB),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) return;
          if (index == 0) {
            Navigator.of(context).pop();
            return;
          }
          _showComingSoon('준비 중인 화면이에요');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '냉장고'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '추천'),
          BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: '초대함'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
        ],
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFB),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _matchBg(level),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '재료 $matched/$total',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _matchFg(level)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${recipe.cuisineType} · 난이도 ${recipe.difficulty} · ${recipe.cookTimeMin}분 · ${recipe.caloriesPerServing}kcal',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '부족한 재료: ${missing.join(', ')}',
                style: const TextStyle(fontSize: 11, color: AppColors.red),
              ),
            ],
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
          const Text('필터', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.green,
            title: const Text('냉장고 재료만으로 만들 수 있는 레시피만', style: TextStyle(fontSize: 13)),
            value: _draft.onlyFullMatch,
            onChanged: (v) => setState(() => _draft = (
                  onlyFullMatch: v,
                  cookTime: _draft.cookTime,
                  difficulty: _draft.difficulty,
                  cuisine: _draft.cuisine,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: '조리시간',
            options: _cookTimeOptions,
            selected: _draft.cookTime,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: v,
                  difficulty: _draft.difficulty,
                  cuisine: _draft.cuisine,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: '난이도',
            options: _difficultyOptions,
            selected: _draft.difficulty,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: _draft.cookTime,
                  difficulty: v,
                  cuisine: _draft.cuisine,
                )),
          ),
          const SizedBox(height: 12),
          _FilterSection(
            label: '요리 종류',
            options: _cuisineOptions,
            selected: _draft.cuisine,
            onSelected: (v) => setState(() => _draft = (
                  onlyFullMatch: _draft.onlyFullMatch,
                  cookTime: _draft.cookTime,
                  difficulty: _draft.difficulty,
                  cuisine: v,
                )),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _defaultFilter),
                  child: const Text('초기화'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('적용하기'),
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
                label: Text(option, style: const TextStyle(fontSize: 12)),
                selected: selected == option,
                selectedColor: AppColors.ink,
                backgroundColor: AppColors.paperDeep,
                labelStyle: TextStyle(
                  color: selected == option ? const Color(0xFFFBF8F1) : AppColors.inkSoft,
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
