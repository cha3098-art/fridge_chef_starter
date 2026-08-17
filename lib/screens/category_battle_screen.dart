import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/board_post.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
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
