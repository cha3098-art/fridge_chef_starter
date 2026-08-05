import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../screens/board_screen.dart';
import '../screens/kfood_screen.dart';
import '../screens/my_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/recommendation_screen.dart';
import '../theme/app_theme.dart';

class _NavEntry {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavEntry({required this.icon, required this.activeIcon, required this.label});
}

/// 6개 메인 탭(메인/추천/마이/랭킹/게시판/K-Food) 공용 하단 내비게이션 — 토스/인스타그램 스타일의
/// 글래스모피즘 플로팅 필 바. 화면 바닥에 딱 붙는 대신 여백을 두고 반투명 블러 패널로 띄운다.
/// "초대함"은 아이콘이 7개일 때 각 탭이 너무 작아져 가시성이 떨어진다는 피드백으로
/// 하단 메뉴에서 뺐다 — My Menu의 "식사 초대" 아이콘으로는 계속 들어갈 수 있다.
/// fridgeIngredientNames는 냉장고 화면에서만 실제 값을 알 수 있으므로,
/// 마이/랭킹/게시판에서 다른 탭으로 넘어갈 때는 빈 Set을 넘긴다.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final Set<String> fridgeIngredientNames;
  /// true면 main_dashboard_screen.dart의 다크 네이비 배경에 맞춰 어두운 유리 톤으로 칠한다.
  /// 나머지 화면은 기본값(false)으로 라이트 유리 톤을 쓴다.
  final bool dark;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    this.fridgeIngredientNames = const {},
    this.dark = false,
  });

  static const _entries = <_NavEntry>[
    _NavEntry(icon: Icons.kitchen_outlined, activeIcon: Icons.kitchen, label: '메인'),
    _NavEntry(icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant, label: '추천'),
    _NavEntry(icon: Icons.person_outline, activeIcon: Icons.person, label: '마이'),
    _NavEntry(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: '랭킹'),
    _NavEntry(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: '게시판'),
    _NavEntry(icon: Icons.flag_outlined, activeIcon: Icons.flag, label: 'K-Food'),
  ];

  static const _entriesEn = ['Main', 'Recipes', 'My', 'Ranking', 'Board', 'K-Food'];

  void _handleTap(BuildContext context, int index) {
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
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = dark ? DashColors.green : AppColors.green;
    final unselectedColor = dark ? DashColors.inkSoft : const Color(0xFF94A3B8);
    final selectedTint = dark ? DashColors.greenSoft : const Color(0xFFE6F7F5);
    final glassColor = dark ? Colors.black.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.88);
    final glassBorder = dark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.6);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: glassBorder, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: List.generate(_entries.length, (index) {
                final entry = _entries[index];
                final selected = index == currentIndex;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _handleTap(context, index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected ? selectedTint : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              selected ? entry.activeIcon : entry.icon,
                              size: 24,
                              color: selected ? selectedColor : unselectedColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(entry.label, _entriesEn[index]),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? selectedColor : unselectedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
