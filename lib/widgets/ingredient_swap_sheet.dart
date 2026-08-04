import 'package:flutter/material.dart';

import '../services/ingredient_swap_service.dart';
import '../theme/app_theme.dart';

/// 레시피 재료 옆 [🔄 대체] 칩을 눌렀을 때 뜨는 대체 재료 가이드 바텀시트.
/// 냉장고 보유 재료 기반 추천(1순위)을 대체 룰(2순위)보다 위에 보여준다.
Future<void> showIngredientSwapSheet(
  BuildContext context, {
  required String ingredientName,
  required Set<String> fridgeIngredientNames,
}) {
  final suggestions = IngredientSwapService.suggestFor(
    ingredientName: ingredientName,
    fridgeIngredientNames: fridgeIngredientNames,
  )..sort((a, b) =>
      (b.ownedSubstituteName != null ? 1 : 0) -
      (a.ownedSubstituteName != null ? 1 : 0));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
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
            const SizedBox(height: 16),
            Text(
              '🔄 $ingredientName 대체 재료 가이드',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            if (suggestions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Text(
                  '등록된 대체 재료 정보가 아직 없어요.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              )
            else
              ...suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SwapCard(suggestion: s),
                  )),
          ],
        ),
      ),
    ),
  );
}

class _SwapCard extends StatelessWidget {
  final IngredientSwapSuggestion suggestion;
  const _SwapCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final isPriority = suggestion.ownedSubstituteName != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isPriority
              ? AppColors.green.withValues(alpha: 0.5)
              : AppColors.carrot.withValues(alpha: 0.3),
          width: isPriority ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPriority ? AppColors.green : AppColors.carrotSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPriority ? '1순위 · 냉장고 보유' : '2순위 · 기본 대체 룰',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isPriority ? Colors.white : AppColors.carrot,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.message,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.swap.tip,
            style: const TextStyle(
                fontSize: 12, color: AppColors.inkSoft, height: 1.4),
          ),
        ],
      ),
    );
  }
}
