import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../screens/category_battle_screen.dart';
import '../screens/category_community_screen.dart';
import '../screens/category_cooking_screen.dart';
import '../screens/category_fridge_screen.dart';
import '../screens/category_my_screen.dart';
import '../theme/app_theme.dart';

class _NavEntry {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavEntry({required this.icon, required this.activeIcon, required this.label});
}

/// 6개 메인 탭(메인/냉장고관리/요리하기/푸드대결/소통공간/마이) 공용 하단 내비게이션.
/// 디자인 스펙에 따라 화면 바닥에 딱 붙는 평평한 흰색 고정 바(높이 65, 상단 헤어라인
/// #E2E8F0)로 통일했다 — 예전의 반투명 블러 플로팅 필 바는 "색상 도배" 피드백으로 걷어냈다.
/// 레시피 추천/K-Food/요리배틀/게시판/식사초대장/랭킹 등은 각각 냉장고관리·요리하기·
/// 푸드대결·소통공간·마이페이지 대분류 화면 아래 세그먼트 탭으로 편입됐으므로,
/// 이 탭들에서 직접 그 화면들로 가진 않고 대응하는 대분류 화면으로 이동한다.
/// fridgeIngredientNames는 냉장고 화면에서만 실제 값을 알 수 있으므로,
/// 다른 탭에서는 빈 Set을 넘겨도 무방하다(각 대분류 화면이 FridgeStore에서 직접 다시 읽는다).
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final Set<String> fridgeIngredientNames;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    this.fridgeIngredientNames = const {},
  });

  static const _entries = <_NavEntry>[
    _NavEntry(icon: Icons.home_outlined, activeIcon: Icons.home, label: '메인'),
    _NavEntry(icon: Icons.kitchen_outlined, activeIcon: Icons.kitchen, label: '냉장고관리'),
    _NavEntry(icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant, label: '요리하기'),
    _NavEntry(
        icon: Icons.local_fire_department_outlined,
        activeIcon: Icons.local_fire_department,
        label: '푸드대결'),
    _NavEntry(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: '소통공간'),
    _NavEntry(icon: Icons.person_outline, activeIcon: Icons.person, label: '마이'),
  ];

  static const _entriesEn = ['Main', 'Fridge', 'Cook', 'Battle', 'Community', 'My'];

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    late final Widget screen;
    switch (index) {
      case 1:
        screen = const CategoryFridgeScreen();
      case 2:
        screen = const CategoryCookingScreen();
      case 3:
        screen = const CategoryBattleScreen();
      case 4:
        screen = const CategoryCommunityScreen();
      default:
        screen = const CategoryMyScreen();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLine, width: 1)),
      ),
      child: SizedBox(
        height: 65,
        child: Row(
          children: List.generate(_entries.length, (index) {
            final entry = _entries[index];
            final selected = index == currentIndex;
            final color = selected ? AppColors.tealPrimary : AppColors.textSub;
            return Expanded(
              child: InkWell(
                onTap: () => _handleTap(context, index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? entry.activeIcon : entry.icon, size: 24, color: color),
                    const SizedBox(height: 3),
                    Text(
                      tr(entry.label, _entriesEn[index]),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
