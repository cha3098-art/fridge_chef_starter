import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
import '../widgets/tab_tutorial_overlay.dart';
import 'add_ingredient_screen.dart';
import 'fridge_management_screen.dart';

/// "냉장고관리" 대분류 화면 — 중간 선택 화면 없이 바로 상단 세그먼트 탭
/// [냉장고 관리 | 재료 등록]으로 콘텐츠를 즉시 전환한다.
class CategoryFridgeScreen extends StatefulWidget {
  const CategoryFridgeScreen({super.key});

  @override
  State<CategoryFridgeScreen> createState() => _CategoryFridgeScreenState();
}

class _CategoryFridgeScreenState extends State<CategoryFridgeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabTutorialOverlay.showIfNeeded(
        context,
        prefsKey: 'hide_tutorial_tab_1_fridge',
        imageAsset: tr('assets/images/tutorial/tab_1_fridge.png',
            'assets/images/tutorial/tab_1_fridge_en.png'),
        title: tr('🧊 스마트한 내 손안의 냉장고', '🧊 Your smart fridge, right in your hand'),
        bodyLines: [
          tr('냉장/냉동/실온별로 보유 중인 재료를 카테고리별로 관리합니다.',
              'Manage what you have by fridge, freezer, and category.'),
          tr('직접 입력, 사진 인식, 영수증 OCR 스캔 등 원하는 방식으로 재료를 추가하세요.',
              "Add ingredients your way — manual entry, photo recognition, or receipt scanning."),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FridgeStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        final names = FridgeStore.instance.items.map((i) => i.name).toSet();
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            leading: const LabeledBackButton(),
            leadingWidth: 96,
            backgroundColor: AppColors.paper,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 76,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/icon/icon_additem.png',
                      width: 58, height: 58, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr('냉장고관리', 'Fridge'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink)),
                ),
              ],
            ),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 16), child: LanguageToggle()),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedTabBar(
                  labels: [tr('냉장고 관리', 'Fridge'), tr('재료 등록', 'Add')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _tab,
            children: const [
              FridgeManagementScreen(embed: true),
              AddIngredientScreen(embed: true),
            ],
          ),
          extendBody: true,
          bottomNavigationBar:
              MainBottomNav(currentIndex: 1, fridgeIngredientNames: names),
        );
      },
    );
  }
}
