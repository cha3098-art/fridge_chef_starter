import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/segmented_tab_bar.dart';
import 'my_screen.dart';
import 'ranking_screen.dart';

/// "마이페이지" 대분류 화면 — 상단 세그먼트 탭 [마이 화면 | 랭킹 순위]로 즉시 전환.
class CategoryMyScreen extends StatefulWidget {
  const CategoryMyScreen({super.key});

  @override
  State<CategoryMyScreen> createState() => _CategoryMyScreenState();
}

class _CategoryMyScreenState extends State<CategoryMyScreen> {
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
                child: Image.asset('assets/icon/icon_my.png',
                    width: 58, height: 58, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(tr('마이페이지', 'My Page'),
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
                labels: [tr('마이 화면', 'My'), tr('랭킹 순위', 'Ranking')],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          ),
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            MyScreen(embed: true),
            RankingScreen(embed: true),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: const MainBottomNav(currentIndex: 5),
      ),
    );
  }
}
