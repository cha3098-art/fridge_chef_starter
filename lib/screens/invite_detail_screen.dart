import 'package:flutter/material.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/meal_invite.dart';
import '../services/meal_invite_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import 'recipe_detail_screen.dart';

/// 딥링크(https://fridgechef.app/invite/{id})로 진입했을 때 보여주는 초대장 상세 화면.
/// 로그인 여부와 무관하게 누구나 열어볼 수 있다 (meal_invites의 select RLS가 전체 공개).
class InviteDetailScreen extends StatefulWidget {
  final String inviteId;
  const InviteDetailScreen({super.key, required this.inviteId});

  @override
  State<InviteDetailScreen> createState() => _InviteDetailScreenState();
}

class _InviteDetailScreenState extends State<InviteDetailScreen> {
  late final Future<MealInvite?> _inviteFuture = MealInviteStore.instance.fetchInvite(widget.inviteId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tr('식사 초대장', 'Meal Invite'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<MealInvite?>(
        future: _inviteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final invite = snapshot.data;
          if (invite == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FridgeMascot(size: 84),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tr('초대장을 찾을 수 없어요', "Couldn't find this invite"),
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                ],
              ),
            );
          }

          final recipe = findRecipeByTitle(invite.recipeTitle);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: cardDecoration(radius: AppSpacing.radiusLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    tr('${invite.hostNickname}님이 식사에 초대했어요!', '${invite.hostNickname} invited you to cook!'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: RecipePhoto(
                      photoUrl: recipe?.photoUrl ??
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Bibimbap_7.jpg/960px-Bibimbap_7.jpg',
                      emoji: recipe?.emoji ?? '🍽️',
                      cuisineType: recipe?.cuisineType ?? '',
                      width: double.infinity,
                      height: 160,
                      emojiSize: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    invite.recipeTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  if (invite.message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${invite.message}"',
                      style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic, color: AppColors.ink),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (recipe != null)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                              recipe: recipe,
                              fridgeIngredientNames: const {},
                              servings: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          tr('레시피 보러 가기', 'View Recipe'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
