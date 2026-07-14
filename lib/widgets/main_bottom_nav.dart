import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../screens/board_screen.dart';
import '../screens/kfood_screen.dart';
import '../screens/my_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/recommendation_screen.dart';
import '../screens/share_screen.dart';
import '../theme/app_theme.dart';

/// 7개 메인 탭(냉장고/추천/초대함/마이/랭킹/게시판/K-Food) 공용 하단 내비게이션.
/// fridgeIngredientNames는 냉장고 화면에서만 실제 값을 알 수 있으므로,
/// 마이/랭킹/게시판에서 다른 탭으로 넘어갈 때는 빈 Set을 넘긴다.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final Set<String> fridgeIngredientNames;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    this.fridgeIngredientNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: AppColors.green,
      unselectedItemColor: AppColors.inkSoft,
      backgroundColor: AppColors.card,
      type: BottomNavigationBarType.fixed,
      iconSize: 20,
      selectedFontSize: 9,
      unselectedFontSize: 9,
      onTap: (index) {
        if (index == currentIndex) return;
        if (index == 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
        late final Widget screen;
        switch (index) {
          case 1:
            screen = RecommendationScreen(fridgeIngredientNames: fridgeIngredientNames);
          case 2:
            screen = ShareScreen(fridgeIngredientNames: fridgeIngredientNames);
          case 3:
            screen = const MyScreen();
          case 4:
            screen = const RankingScreen();
          case 5:
            screen = const BoardScreen();
          default:
            screen = KFoodScreen(fridgeIngredientNames: fridgeIngredientNames);
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.kitchen), label: tr('냉장고', 'Fridge')),
        BottomNavigationBarItem(icon: const Icon(Icons.restaurant), label: tr('추천', 'Recipes')),
        BottomNavigationBarItem(icon: const Icon(Icons.mail_outline), label: tr('초대함', 'Inbox')),
        BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: tr('마이', 'My')),
        BottomNavigationBarItem(icon: const Icon(Icons.emoji_events_outlined), label: tr('랭킹', 'Ranking')),
        BottomNavigationBarItem(icon: const Icon(Icons.forum_outlined), label: tr('게시판', 'Board')),
        const BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: 'K-Food'),
      ],
    );
  }
}
