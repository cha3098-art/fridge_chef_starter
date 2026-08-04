import 'package:flutter/material.dart';
import '../data/quick_recipe_catalog.dart';
import '../data/recipe_catalog.dart';
import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/quick_recipe.dart';
import '../models/recipe.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'cooking_mode_screen.dart';
import 'recipe_detail_screen.dart';

const _quickRecipeEmoji = <String, String>{
  '한식': '🍚',
  '중식': '🥢',
  '양식': '🍝',
  '일식': '🍱',
  '분식': '🌶️',
};

const _cookTimeOptions = ['전체', '15분 이내', '30분 이내', '60분 이내'];
const _difficultyOptions = ['전체', '하', '중', '상'];
const _cuisineOptions = ['전체', '한식', '중식', '양식', '분식', '일식', '이탈리아식', '프랑스식'];
const _servingsOptions = ['1인분', '2인분', '3인분', '4인분'];

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
///
/// 상단 요리종류 퀵필터는 재료 등록 화면과 동일한 카카오톡 스타일 캡슐 칩으로 통일했다.
class RecommendationScreen extends StatefulWidget {
  final Set<String> fridgeIngredientNames;

  const RecommendationScreen({super.key, required this.fridgeIngredientNames});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  RecommendationFilter _filter = _defaultFilter;
  bool _showQuickRecipes = false;

  static const _fallbackCount = 5;

  /// 재료 이름 -> 유통기한까지 남은 일수. FridgeStore를 직접 조회하므로 별도 파라미터 전달 없이
  /// "곧 상할 재료를 쓰는 레시피"를 위로 끌어올리는 데 쓴다.
  Map<String, int> get _daysLeftByName {
    final map = <String, int>{};
    for (final item in FridgeStore.instance.items) {
      final days = item.daysLeft;
      if (days != null) map[item.name] = days;
    }
    return map;
  }

  /// 매칭도(%) + 유통기한 긴급도 점수를 합산한 종합 점수 — 높을수록 먼저 보여준다
  double _totalScore(Recipe r, Map<String, int> daysLeftByName) {
    final total = r.requiredIngredients.length;
    final matched = r.matchedCount(widget.fridgeIngredientNames);
    final matchRate = total == 0 ? 0.0 : (matched / total) * 100;
    return matchRate + r.expiryUrgencyScore(daysLeftByName);
  }

  /// 추천(재료 1개 이상 보유) / 미일치(보유 재료 0개) 두 그룹으로 나눠 반환한다.
  /// onlyFullMatch가 켜져 있으면 미일치 그룹은 숨긴다 — 단, 그 결과 추천 그룹마저
  /// 텅 비면(보유 재료와 겹치는 레시피가 아예 없으면) 가장 가까운 상위
  /// [_fallbackCount]개를 대신 보여준다 (isFallback = true).
  ({List<Recipe> recommended, List<Recipe> unmatched, bool isFallback})
      _computeRecipes() {
    final daysLeftByName = _daysLeftByName;
    final base = recipeCatalog.where((r) {
      if (_filter.cookTime != '전체') {
        final maxMin =
            int.parse(_filter.cookTime.replaceAll(RegExp(r'[^0-9]'), ''));
        if (r.cookTimeMin > maxMin) return false;
      }
      if (_filter.difficulty != '전체' && r.difficulty != _filter.difficulty)
        return false;
      if (_filter.cuisine != '전체' && r.cuisineType != _filter.cuisine)
        return false;
      return true;
    }).toList();

    int byScore(Recipe a, Recipe b) {
      final scoreA = _totalScore(a, daysLeftByName);
      final scoreB = _totalScore(b, daysLeftByName);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.requiredIngredients.length
          .compareTo(b.requiredIngredients.length);
    }

    final recommended = base
        .where((r) => r.matchedCount(widget.fridgeIngredientNames) > 0)
        .toList()
      ..sort(byScore);

    if (_filter.onlyFullMatch) {
      if (recommended.isNotEmpty) {
        return (
          recommended: recommended,
          unmatched: const [],
          isFallback: false
        );
      }
      final fallback = List<Recipe>.from(base)..sort(byScore);
      return (
        recommended: fallback.take(_fallbackCount).toList(),
        unmatched: const [],
        isFallback: base.isNotEmpty,
      );
    }

    final unmatched = base
        .where((r) => r.matchedCount(widget.fridgeIngredientNames) == 0)
        .toList()
      ..sort(byScore);

    return (recommended: recommended, unmatched: unmatched, isFallback: false);
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
    final recommended = result.recommended;
    final unmatched = result.unmatched;
    final isFallback = result.isFallback;
    final totalCount = recommended.length + unmatched.length;
    final items = <Object>[
      ...recommended,
      if (unmatched.isNotEmpty) const _UnmatchedSectionMarker(),
      ...unmatched,
    ];

    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          leading: const LabeledBackButton(),
          leadingWidth: 96,
          backgroundColor: AppColors.paper,
          elevation: 0,
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
                child: Text(tr('레시피 추천', 'Recipe Picks'),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          titleSpacing: 0,
          actions: [
            const Padding(
                padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
            const Padding(
                padding: EdgeInsets.only(right: 8), child: ChefTierBadge()),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: _openFilterSheet,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
                            ? AppColors.green
                            : AppColors.paperDeep,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _activeFilterCount > 0
                              ? AppColors.green
                              : AppColors.line,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 16,
                            color: _activeFilterCount > 0
                                ? AppColors.paper
                                : AppColors.ink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tr('필터', 'Filter'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _activeFilterCount > 0
                                  ? AppColors.paper
                                  : AppColors.ink,
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
                        decoration: const BoxDecoration(
                            color: AppColors.red, shape: BoxShape.circle),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
            Container(
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.line, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _CuisineCapsuleRow(
                      selected: _filter.cuisine,
                      onSelected: (cuisine) => setState(() => _filter = (
                            onlyFullMatch: _filter.onlyFullMatch,
                            cookTime: _filter.cookTime,
                            difficulty: _filter.difficulty,
                            cuisine: cuisine,
                            servings: _filter.servings,
                          )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _QuickRecipeBadge(
                    active: _showQuickRecipes,
                    onTap: () =>
                        setState(() => _showQuickRecipes = !_showQuickRecipes),
                  ),
                ],
              ),
            ),
            if (_showQuickRecipes) ...[
              Expanded(child: _QuickRecipeGrid(cuisineFilter: _filter.cuisine)),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  tr('레시피 $totalCount개', '$totalCount recipes'),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft),
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
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr(
                              '냉장고 재료만으로 완성되는 레시피가 없어서, 가장 가까운 레시피를 보여드려요',
                              'No recipe matches your fridge exactly, so here are the closest ones',
                            ),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FridgeMascot(size: 84),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                                tr('조건에 맞는 레시피가 없어요',
                                    'No recipes match these filters'),
                                style:
                                    const TextStyle(color: AppColors.inkSoft)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is _UnmatchedSectionMarker) {
                            return const _UnmatchedSectionHeader();
                          }
                          final recipe = item as Recipe;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _RecipeCard(
                              recipe: recipe,
                              fridgeIngredientNames:
                                  widget.fridgeIngredientNames,
                              isUrgent:
                                  recipe.expiryUrgencyScore(_daysLeftByName) >
                                      0,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(
                                    recipe: recipe,
                                    fridgeIngredientNames:
                                        widget.fridgeIngredientNames,
                                    servings: _filter.servings,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
        extendBody: true,
        bottomNavigationBar: MainBottomNav(
          currentIndex: 1,
          fridgeIngredientNames: widget.fridgeIngredientNames,
        ),
      ),
    );
  }
}

/// 카카오톡 채팅 필터 스타일의 둥근 캡슐 칩 — 요리종류 퀵필터를 원형 아이콘 대신
/// 재료 등록 화면의 상단 탭과 같은 언어로 통일한다. 선택된 칩만 진한 배경/흰 글씨.
class _CuisineCapsuleRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CuisineCapsuleRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final cuisine in _cuisineOptions)
            GestureDetector(
              onTap: () => onSelected(cuisine),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      selected == cuisine ? AppColors.ink : AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected == cuisine
                        ? AppColors.ink
                        : AppColors.cardBorder,
                  ),
                  boxShadow: selected == cuisine
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  trTag(cuisine),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        selected == cuisine ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카테고리 선택 바 옆의 "⚡ 5분 초간단" 피치 틴트 뱃지 — 누르면 20종 초간단 레시피
/// 2단 그리드로 전환된다(_showQuickRecipes 토글).
class _QuickRecipeBadge extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _QuickRecipeBadge({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.carrot : AppColors.carrotSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? AppColors.carrot
                : AppColors.carrot.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '⚡ 5분 초간단',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.carrot,
          ),
        ),
      ),
    );
  }
}

/// 초간단 레시피 20종을 1:1 카드 2단 그리드로 보여준다.
class _QuickRecipeGrid extends StatelessWidget {
  final String cuisineFilter;
  const _QuickRecipeGrid({required this.cuisineFilter});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuickRecipe>>(
      future: QuickRecipeCatalog.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final recipes = cuisineFilter == '전체'
            ? snapshot.data!
            : snapshot.data!
                .where((r) => r.cuisineType == cuisineFilter)
                .toList();
        if (recipes.isEmpty) {
          return Center(
            child: Text('$cuisineFilter 초간단 레시피가 아직 없어요',
                style: const TextStyle(color: AppColors.inkSoft)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) =>
              _QuickRecipeGridCard(recipe: recipes[index]),
        );
      },
    );
  }
}

class _QuickRecipeGridCard extends StatelessWidget {
  final QuickRecipe recipe;
  const _QuickRecipeGridCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final gradient = cuisineGradient(recipe.cuisineType);
    final emoji = _quickRecipeEmoji[recipe.cuisineType] ?? '⚡';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CookingModeScreen(
            title: recipe.title,
            cuisineType: recipe.cuisineType,
            emoji: emoji,
            steps: recipe.steps,
            stepImages: recipe.stepImages,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: cardDropShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 10),
            Text(
              recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.carrotSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '⚡ ${recipe.cookTimeMin}분',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.carrot),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  trTag(recipe.cuisineType),
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// items 리스트에서 "여기부터 미일치 레시피 구역" 위치만 표시하는 마커 — 위젯을 그리지 않고
/// itemBuilder에서 이 타입을 만나면 대신 [_UnmatchedSectionHeader]를 렌더링한다.
class _UnmatchedSectionMarker {
  const _UnmatchedSectionMarker();
}

/// 추천(재료 보유) 그룹과 미일치(보유 재료 0개) 그룹 사이의 구분선 + 안내 헤더.
/// 미일치 레시피도 삭제하지 않고 이 구역 아래에 계속 보여줘서, 부족한 재료만 채우면
/// 바로 도전할 수 있다는 걸 알려준다.
class _UnmatchedSectionHeader extends StatelessWidget {
  const _UnmatchedSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.line, height: 1),
          const SizedBox(height: 12),
          Text(
            tr('💡 부족한 재료를 채워 도전해 보세요',
                "💡 Fill in what's missing to try these"),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Set<String> fridgeIngredientNames;
  final bool isUrgent;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.fridgeIngredientNames,
    required this.isUrgent,
    required this.onTap,
  });

  Color _matchFg(RecipeMatchLevel level) {
    switch (level) {
      case RecipeMatchLevel.full:
        return AppColors.green;
      case RecipeMatchLevel.partial:
        return AppColors.gold;
      case RecipeMatchLevel.low:
        return AppColors.inkSoft;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final matched = recipe.matchedCount(fridgeIngredientNames);
    final total = recipe.requiredIngredients.length;
    final level = recipe.matchLevel(fridgeIngredientNames);
    final missing = recipe.missingIngredients(fridgeIngredientNames);
    final gradient = cuisineGradient(recipe.cuisineType);
    final thumbAccent = gradient.last;
    final percent = total == 0 ? 1.0 : matched / total;
    final percentLabel = (percent * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: cardDropShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 유통기한 임박 재료를 쓰는 레시피는 눈에 띄는 배지로 먼저 알린다
            if (isUrgent) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr('🔥 임박 재료 구출', '🔥 Use it up'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _matchBg(level),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    level == RecipeMatchLevel.full
                        ? tr('완성 가능', 'Ready')
                        : tr('재료매칭율 $percentLabel%', 'Match $percentLabel%'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _matchFg(level)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이모지 대신 실제 요리 사진(RecipePhoto) — 로딩/실패 시엔 기존 그라데이션+이모지로 자연스럽게 대체된다
                Container(
                  width: 74,
                  height: 74,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: thumbAccent.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: RecipePhoto(
                    photoUrl: recipe.photoUrl,
                    emoji: recipe.emoji,
                    cuisineType: recipe.cuisineType,
                    width: 74,
                    height: 74,
                    emojiSize: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(recipe.title, recipe.titleEn),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${trTag(recipe.cuisineType)} · ${tr('난이도', 'Level')} ${trTag(recipe.difficulty)} · ${recipe.cookTimeMin}${tr('분', 'min')} · ${recipe.caloriesPerServing}kcal',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft),
                      ),
                      Text(
                        tr('재료 $matched/$total개 보유',
                            '$matched/$total items on hand'),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.inkSoft),
                      ),
                      if (missing.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.carrotSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${tr('부족한 재료', 'Missing')}: ${missing.map(trIngredientName).join(', ')}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.carrot,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _BuyIngredientsButton(missingIngredients: missing),
                          ],
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

/// "재료 구매" 마이크로 인터랙션 버튼 — 은은하게 팽창하는 글로우 섀도우와 살짝 씰룩이는
/// 장바구니 아이콘으로 시선을 끈다. 아직 실제 장보기 제휴가 연동되어 있지 않으므로,
/// 탭하면 구체적인 할인율/배송시간 같은 없는 혜택을 보여주는 대신 정직하게 "준비 중"을 안내한다.
class _BuyIngredientsButton extends StatefulWidget {
  final List<String> missingIngredients;
  const _BuyIngredientsButton({required this.missingIngredients});

  @override
  State<_BuyIngredientsButton> createState() => _BuyIngredientsButtonState();
}

class _BuyIngredientsButtonState extends State<_BuyIngredientsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowPulse;
  late final Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 3.0, end: 12.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _iconRotation = Tween<double>(begin: -0.05, end: 0.05)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPurchaseSheet(BuildContext context) {
    final missingLabel =
        widget.missingIngredients.map(trIngredientName).join(', ');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '[$missingLabel] ${tr('부족한 재료 장보기', 'Shop for missing ingredients')}',
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              tr('원하시는 마트를 선택해 보세요', 'Pick a grocery partner'),
              style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            _MartOptionTile(
              name: tr('쿠팡 로켓프레시 🚀', 'Coupang Rocket Fresh 🚀'),
              sub: tr('식재료 자동 장바구니 연동 지원 예정', 'Auto cart integration planned'),
              themeColor: const Color(0xFF0073E6),
              onTap: () {
                Navigator.pop(sheetContext);
                _showComingSoonDialog(
                    context, tr('쿠팡 로켓프레시', 'Coupang Rocket Fresh'));
              },
            ),
            const SizedBox(height: 12),
            _MartOptionTile(
              name: tr('마켓컬리 샛별배송 💜', 'Market Kurly 💜'),
              sub: tr('식재료 자동 장바구니 연동 지원 예정', 'Auto cart integration planned'),
              themeColor: const Color(0xFF5F0080),
              onTap: () {
                Navigator.pop(sheetContext);
                _showComingSoonDialog(context, tr('마켓컬리', 'Market Kurly'));
              },
            ),
            const SizedBox(height: 12),
            _MartOptionTile(
              name: tr('배민 B마트 🛵', 'Baemin B Mart 🛵'),
              sub: tr('식재료 자동 장바구니 연동 지원 예정', 'Auto cart integration planned'),
              themeColor: AppColors.green,
              onTap: () {
                Navigator.pop(sheetContext);
                _showComingSoonDialog(context, tr('배민 B마트', 'Baemin B Mart'));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 실제로 연동되어 있지 않은 할인율·배송시간 같은 문구 대신, 정직하게 "준비 중" 상태를 알린다.
  void _showComingSoonDialog(BuildContext context, String martName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('$martName 연동 준비 중', '$martName integration coming soon'),
          style: const TextStyle(
              color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          tr(
            '$martName과의 장보기 연동은 아직 준비 중이에요. 완성되면 부족한 재료를 한 번에 장바구니에 담을 수 있게 될 거예요!',
            "$martName integration isn't ready yet. Once it's live, you'll be able to add missing ingredients to your cart in one tap!",
          ),
          style: const TextStyle(
              color: AppColors.inkSoft, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('확인', 'OK'),
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => GestureDetector(
        onTap: () => _showPurchaseSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.green, Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.3),
                blurRadius: _glowPulse.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: _iconRotation.value,
                child: const Icon(Icons.shopping_cart_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 6),
              Text(
                tr('재료 구매', 'Buy'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MartOptionTile extends StatelessWidget {
  final String name;
  final String sub;
  final Color themeColor;
  final VoidCallback onTap;

  const _MartOptionTile(
      {required this.name,
      required this.sub,
      required this.themeColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.paperDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: themeColor.withValues(alpha: 0.6), size: 14),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('필터', 'Filter'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.ink)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.green,
              title: Text(
                  tr('냉장고 재료만으로 만들 수 있는 레시피만', 'Only recipes I can fully make'),
                  style: const TextStyle(fontSize: 13, color: AppColors.ink)),
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
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label:
                    Text(trTag(option), style: const TextStyle(fontSize: 12)),
                selected: selected == option,
                selectedColor: AppColors.green,
                backgroundColor: AppColors.paperDeep,
                labelStyle: TextStyle(
                  color:
                      selected == option ? AppColors.paper : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                    color:
                        selected == option ? AppColors.green : AppColors.line),
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}
