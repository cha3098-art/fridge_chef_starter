import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/board_post.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
import '../widgets/tab_tutorial_overlay.dart';
import 'board_screen.dart';
import 'share_screen.dart';

/// "소통공간" 대분류 화면 — 상단 세그먼트 탭 [일반 게시판 | 식사 초대장]으로 즉시 전환.
class CategoryCommunityScreen extends StatefulWidget {
  const CategoryCommunityScreen({super.key});

  @override
  State<CategoryCommunityScreen> createState() => _CategoryCommunityScreenState();
}

class _CategoryCommunityScreenState extends State<CategoryCommunityScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabTutorialOverlay.showIfNeeded(
        context,
        prefsKey: 'hide_tutorial_tab_4_community',
        imageAsset: tr('assets/images/tutorial/tab_4_community.png',
            'assets/images/tutorial/tab_4_community_en.png'),
        title: tr('💬 요리 자랑 & 밥약속 초대장', '💬 Brag your dishes & meal invites'),
        bodyLines: [
          tr('완성된 나만의 요리 사진을 공유하고 자랑해 보세요.',
              "Share and show off photos of the dishes you've made."),
          tr('정성껏 만든 레시피로 친구에게 보낼 밥약속 초대장을 쉽게 생성할 수 있습니다.',
              "Easily create a meal invite to send to friends for a recipe you'd like to share."),
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
                  child: Image.asset('assets/icon/icon_board.png',
                      width: 58, height: 58, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr('소통공간', 'Community'),
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
                  labels: [tr('일반 게시판', 'General'), tr('식사 초대장', 'Invites')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _tab,
            children: [
              const BoardScreen(
                  initialCategory: BoardCategory.showoff,
                  embed: true,
                  lockCategory: true),
              ShareScreen(
                  fridgeIngredientNames: names, initialTabIndex: 0, embed: true),
            ],
          ),
          extendBody: true,
          bottomNavigationBar:
              MainBottomNav(currentIndex: 4, fridgeIngredientNames: names),
        );
      },
    );
  }
}
