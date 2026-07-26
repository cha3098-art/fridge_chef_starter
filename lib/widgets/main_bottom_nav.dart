import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../screens/board_screen.dart';
import '../screens/kfood_screen.dart';
import '../screens/my_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/recommendation_screen.dart';
import '../theme/app_theme.dart';

/// 6개 메인 탭(냉장고/추천/마이/랭킹/게시판/K-Food) 공용 하단 내비게이션.
/// "초대함"은 아이콘이 7개일 때 각 탭이 너무 작아져 가시성이 떨어진다는 피드백으로
/// 하단 메뉴에서 뺐다 — My Menu의 "식사 초대" 아이콘으로는 계속 들어갈 수 있다.
/// fridgeIngredientNames는 냉장고 화면에서만 실제 값을 알 수 있으므로,
/// 마이/랭킹/게시판에서 다른 탭으로 넘어갈 때는 빈 Set을 넘긴다.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final Set<String> fridgeIngredientNames;
  /// true면 main_dashboard_screen.dart의 다크 네이비 배경에 맞춰 DashColors로 칠한다.
  /// 나머지 화면은 기본값(false)으로 기존 라이트 테마를 그대로 쓴다.
  final bool dark;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    this.fridgeIngredientNames = const {},
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: dark ? DashColors.green : AppColors.green,
      unselectedItemColor: dark ? DashColors.inkSoft : AppColors.inkSoft,
      backgroundColor: dark ? DashColors.card : AppColors.card,
      type: BottomNavigationBarType.fixed,
      iconSize: 26,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
            screen = const MyScreen();
          case 3:
            screen = const RankingScreen();
          case 4:
            screen = const BoardScreen();
          default:
            screen = KFoodScreen(fridgeIngredientNames: fridgeIngredientNames);
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.kitchen_outlined),
          activeIcon: const Icon(Icons.kitchen),
          label: tr('냉장고', 'Fridge'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.restaurant_outlined),
          activeIcon: const Icon(Icons.restaurant),
          label: tr('추천', 'Recipes'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: tr('마이', 'My'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.emoji_events_outlined),
          activeIcon: const Icon(Icons.emoji_events),
          label: tr('랭킹', 'Ranking'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.forum_outlined),
          activeIcon: const Icon(Icons.forum),
          label: tr('게시판', 'Board'),
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.flag_outlined),
          activeIcon: Icon(Icons.flag),
          label: 'K-Food',
        ),
      ],
    );
  }
}
