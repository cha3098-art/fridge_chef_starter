import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/board_post.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
import '../widgets/tab_tutorial_overlay.dart';
import 'battle_screen.dart';
import 'board_screen.dart';

/// "푸드대결" 대분류 화면 — 상단 세그먼트 탭 [요리 배틀 | 챌린지 게시판]으로 즉시 전환.
class CategoryBattleScreen extends StatefulWidget {
  const CategoryBattleScreen({super.key});

  @override
  State<CategoryBattleScreen> createState() => _CategoryBattleScreenState();
}

class _CategoryBattleScreenState extends State<CategoryBattleScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabTutorialOverlay.showIfNeeded(
        context,
        prefsKey: 'hide_tutorial_tab_3_battle',
        imageAsset: tr('assets/images/tutorial/tab_3_battle.png',
            'assets/images/tutorial/tab_3_battle_en.png'),
        title: tr('⚔️ 흥미진진한 1:1 푸드 배틀', '⚔️ Thrilling 1:1 food battles'),
        bodyLines: [
          tr('동일한 요리 주제로 다른 사용자들과 1:1 요리 대결을 펼쳐보세요.',
              'Challenge other users to a 1:1 cook-off on the same theme.'),
          tr('투표에 참여하거나 배틀에 승리하여 셰프 포인트를 획득할 수 있습니다.',
              'Vote or win battles to earn chef points.'),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
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
                child: Image.asset('assets/icon/icon_challenge_rival.png',
                    width: 58, height: 58, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(tr('푸드대결', 'Battle'),
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
                labels: [tr('요리 배틀', 'Battle'), tr('챌린지 게시판', 'Challenge')],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          ),
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            BattleScreen(embed: true),
            BoardScreen(
                initialCategory: BoardCategory.challenge,
                embed: true,
                lockCategory: true),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: const MainBottomNav(currentIndex: 3),
      ),
    );
  }
}
