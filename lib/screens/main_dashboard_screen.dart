import 'dart:async';

import 'package:flutter/material.dart';

import '../data/kfood_catalog.dart';
import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/board_post.dart';
import '../models/chef_points.dart';
import '../models/fridge_item.dart';
import '../models/recipe.dart';
import '../services/board_store.dart';
import '../services/chef_points_store.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/tab_tutorial_overlay.dart';
import 'add_ingredient_screen.dart';
import 'banner_detail_screen.dart';
import '../models/battle.dart';
import '../models/battle_list_item.dart';
import '../services/battle_store.dart';
import 'battle_screen.dart';
import 'board_screen.dart';
import 'category_battle_screen.dart';
import 'category_community_screen.dart';
import 'category_cooking_screen.dart';
import 'category_fridge_screen.dart';
import 'my_screen.dart';
import 'ranking_screen.dart';
import 'recipe_detail_screen.dart';
import 'recommendation_screen.dart';
import 'share_screen.dart';

typedef _TopRank = ({String nickname, int points});
typedef _DashboardExtras = ({List<_TopRank> ranks, List<BoardPost> posts});

/// 온보딩 이후 첫 진입 화면 — 7개 탭 화면을 매번 오가지 않아도, 스크롤 한 번으로
/// 냉장고 상태·AI 추천·챌린지 랭킹·커뮤니티까지 한눈에 훑을 수 있는 올인원 대시보드.
/// "냉장고" 탭(MainBottomNav index 0)의 홈 화면 역할을 하며, 실제 재료 목록/유통기한
/// 알림은 이 화면 안에 그대로 포함된다 — 별도의 목업 카드가 아니라 FridgeStore를 직접 구독한다.
/// 음식 앱 특유의 화사한 라이트 톤(AppColors)을 쓴다 — 앱 전역 테마(AppTheme.light())와
/// 동일한 팔레트라 별도 Theme() 래핑 없이도 자연스럽게 앱 전체와 색이 맞는다.
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with SingleTickerProviderStateMixin {
  final PageController _bannerController = PageController();
  late Future<_DashboardExtras> _extrasFuture;
  int _currentBannerPage = 0;
  Timer? _rollingTimer;
  bool _showAllFridgeItems = false;

  // _buildRollingBanner()에 정의된 배너 개수와 항상 일치해야 한다.
  static const _bannerCount = 3;

  late final AnimationController _tooltipController;
  late final Animation<double> _tooltipBounce;
  bool _showTooltip = true;

  List<BattleListItem> _activeBattles = [];
  int _tickerIndex = 0;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    if (!FridgeStore.instance.isLoaded) FridgeStore.instance.loadItems();
    _extrasFuture = _loadExtras();
    _startBannerAutoRolling();
    _loadActiveBattles();

    // 영수증 등록 기능을 놓치지 않도록 위아래로 콩콩 튀는 안내 툴팁 애니메이션.
    _tooltipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _tooltipBounce = Tween<double>(begin: 0.0, end: -8.0).animate(
        CurvedAnimation(parent: _tooltipController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TabTutorialOverlay.showIfNeeded(
        context,
        prefsKey: 'hide_tutorial_tab_0_main',
        imageAsset: tr('assets/images/tutorial/tab_0_main.png',
            'assets/images/tutorial/tab_0_main_en.png'),
        title: tr('👋 냉장고 셰프에 오신 것을 환영합니다!', '👋 Welcome to Fridge Chef!'),
        bodyLines: [
          tr(
              '내 냉장고 재료 등록, 그 재료 활용하여 레시피 (AI)추천, 다른 사용자와 요리 배틀, 커뮤니티까지 한눈에',
              'Register your fridge ingredients, get AI recipe recommendations using them, '
                  'battle other users, and explore the community — all in one place'),
        ],
      );
    });
  }

  @override
  void dispose() {
    _rollingTimer?.cancel();
    _tickerTimer?.cancel();
    _bannerController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveBattles() async {
    final battles = await BattleStore.instance.fetchActiveBattleItems();
    if (!mounted || battles.isEmpty) return;
    setState(() => _activeBattles = battles);
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(
          () => _tickerIndex = (_tickerIndex + 1) % _activeBattles.length);
    });
  }

  /// 현재 진행 중인 배틀을 4초마다 슬라이드로 보여주는 라이브 티커 스트립.
  Widget _buildBattleTicker() {
    if (_activeBattles.isEmpty) return const SizedBox.shrink();
    final item = _activeBattles[_tickerIndex % _activeBattles.length];
    final battle = item.battle;
    final isVoting = battle.status == BattleStatus.voting;
    final isWaiting = battle.status == BattleStatus.waitingOpponent;
    final isCompleted = battle.status == BattleStatus.completed;
    final isCancelled = battle.status == BattleStatus.cancelled;
    final isEnded = isCompleted || isCancelled;
    final statusIcon = isVoting
        ? '🗳️'
        : (isWaiting ? '🙋' : (isCancelled ? '🚫' : (isCompleted ? '🏆' : '⚔️')));
    final statusLabel = isVoting
        ? tr('투표 중', 'Voting')
        : isWaiting
            ? tr('상대 기다리는 중', 'Waiting for opponent')
            : isCancelled
                ? tr('취소된 배틀', 'Battle cancelled')
                : isCompleted
                    ? tr('종료된 배틀', 'Battle ended')
                    : tr('배틀 진행중', 'Battle live');
    final statusColor = isVoting
        ? AppColors.gold
        : (isWaiting
            ? AppColors.inkSoft
            : (isEnded ? AppColors.inkSoft : AppColors.carrot));
    final challenger = item.challengerNickname ?? tr('대기 중', 'Waiting');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BattleScreen()),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        // 오른쪽에서 들어와 왼쪽으로 흘러가는 티커 느낌을 주기 위해 가로 슬라이드를 쓴다.
        transitionBuilder: (child, anim) => ClipRect(
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          ),
        ),
        child: Container(
          key: ValueKey(_tickerIndex),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: 0.10),
                statusColor.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: statusColor.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  '$statusIcon $statusLabel',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.hostNickname}  ⚔️  $challenger',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_activeBattles.length > 1)
                Text(
                  '${_tickerIndex + 1}/${_activeBattles.length}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }

  /// 콩콩 뛰는 신기능 안내 말풍선 — 닫기 버튼으로 사용자가 직접 없앨 수 있다.
  Widget _buildSmartTooltip() {
    return AnimatedBuilder(
      animation: _tooltipBounce,
      builder: (context, child) => Transform.translate(
          offset: Offset(0, _tooltipBounce.value), child: child),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // 로테이션 배너 3번째 슬라이드("냉장고 셰프 100% 활용법")와 자리를 바꿨다 —
          // 신규 사용자 전체 가이드를 항상 보이는 상단 고정 자리로 올리고, 영수증스캔
          // 원탭 숏컷은 로테이션 배너 쪽으로 내렸다(_buildRollingBanner 참고).
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BannerDetailScreen(bannerIndex: 2))),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text('🚀 ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          tr('냉장고 셰프 100% 활용법 살펴보기',
                              'See how to get the most out of Fridge Chef'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showTooltip = false),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 배너를 3초마다 자동으로 다음 페이지로 넘긴다. 사용자가 직접 스와이프해도
  /// onPageChanged가 _currentBannerPage를 갱신해 주므로 다음 자동 롤링도 이어서 맞게 진행된다.
  void _startBannerAutoRolling() {
    _rollingTimer?.cancel();
    _rollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_bannerController.hasClients) return;
      final nextPage = (_currentBannerPage + 1) % _bannerCount;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<_DashboardExtras> _loadExtras() async {
    final profilesFuture = ProfileStore.instance.fetchAll();
    final pointsFuture = ChefPointsStore.fetchAllUserPoints();
    final postsFuture = BoardStore.instance.loadPosts();
    final results =
        await Future.wait([profilesFuture, pointsFuture, postsFuture]);
    final profiles = results[0] as List;
    final pointsByUser = results[1] as Map<String, ({int general, int kfood})>;
    final ranks = profiles
        .map((p) => (
              nickname: p.nickname as String,
              points: pointsByUser[p.id]?.general ?? 0
            ))
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final posts = [
      ...BoardStore.instance.postsFor(BoardCategory.showoff),
      ...BoardStore.instance.postsFor(BoardCategory.challenge),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (ranks: ranks.take(3).toList(), posts: posts.take(2).toList());
  }

  Future<void> _openAddIngredient({int tab = 0}) async {
    final added = await Navigator.of(context).push<List<FridgeItem>>(
      MaterialPageRoute(
          builder: (_) => AddIngredientScreen(initialTabIndex: tab)),
    );
    if (added != null && added.isNotEmpty) {
      await FridgeStore.instance.addItems(added);
      ChefPointsStore.instance.recordFirstIngredientIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [FridgeStore.instance, LocaleStore.instance, ProfileStore.instance]),
      builder: (context, _) {
        if (!FridgeStore.instance.isLoaded) {
          return const Scaffold(
            backgroundColor: AppColors.paper,
            body: Center(
                child: CircularProgressIndicator(color: AppColors.green)),
          );
        }
        final items = FridgeStore.instance.items;
        final names = items.map((i) => i.name).toSet();
        final atRisk = items.where((i) => i.ddayLevel != DdayLevel.ok).toList()
          ..sort((a, b) => (a.daysLeft ?? 999).compareTo(b.daysLeft ?? 999));

        return Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showTooltip) _buildSmartTooltip(),
                            Text(tr('바로가기', 'Quick Menu'),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink)),
                            const SizedBox(height: 12),
                            _buildCategoryCards(),
                            const SizedBox(height: 16),
                            _buildRollingBanner(),
                            if (_activeBattles.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildBattleTicker(),
                            ],
                            const SizedBox(height: 24),
                            _buildEventPromoCard(names),
                            const SizedBox(height: 24),
                            _buildExpiryCard(atRisk, names),
                            const SizedBox(height: 24),
                            _buildFridgeListCard(items),
                            const SizedBox(height: 24),
                            _buildRankingCard(),
                            const SizedBox(height: 24),
                            _buildCommunityFeed(),
                            // 하단 플로팅 내비 바에 가려지지 않도록 여백을 넉넉히 둔다
                            // (ranking_screen.dart과 동일한 120 기준).
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 20,
                  bottom: 95 + MediaQuery.of(context).padding.bottom,
                  child: _buildFloatingPromoBadge(names),
                ),
              ],
            ),
          ),
          extendBody: true,
          bottomNavigationBar:
              MainBottomNav(currentIndex: 0, fridgeIngredientNames: names),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final nickname =
        ProfileStore.instance.currentProfile?.nickname ?? tr('셰프', 'Chef');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icon/icon_square.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('냉장고 셰프', 'Fridge Chef'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenDeep,
                          letterSpacing: -0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('$nickname 님', nickname),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  tr('오늘 냉장고 구출 작전 시작해 볼까요? 🧑‍🍳',
                      "Let's rescue today's fridge! 🧑‍🍳"),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const LanguageToggle(),
          const SizedBox(width: 4),
          // My Menu에서 "마이" 아이콘을 없앤 만큼, 마이페이지로 가는 유일한 입구가 되어
          // 눈에 띄어야 해서 시그니처 민트 톤으로 강조했다(기존엔 무채색 원 버튼이었음).
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MyScreen())),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  /// 대분류 4장을 2x2 컴팩트 그리드로 배치한다 — 예전엔 카드가 화면을 거의 다 채울 만큼
  /// 컸는데("불필요하게 크다"는 피드백으로) 카드 높이를 110px 고정으로 축소해, 하단 배너/
  /// 알림 카드가 스크롤 없이 바로 시야에 들어오게 했다. 각 카드는 해당 대분류 화면
  /// (세그먼트 탭으로 하위 콘텐츠를 즉시 전환하는 단일 화면)으로 바로 이동한다 —
  /// 중간 게이트웨이 선택 화면은 거치지 않는다.
  /// 카드를 통짜 이미지 버튼으로 쓰면 좁은 높이에 맞춰 이미지를 억지로 크롭/왜곡해야 해서
  /// ("화면 비율 훼손" 피드백), 대신 정사각형 이미지 요소(글자 없는 아이콘 아트, cover 핏으로
  /// 원본 비율 유지)와 앱 타이포그래피로 그리는 제목 텍스트를 좌우로 배치하는 카드로 바꿨다.
  Widget _buildCategoryCards() {
    final cards = <({String iconAsset, String koTitle, String enTitle, Widget screen})>[
      (
        iconAsset: 'assets/icon/icon_hub_fridge_glyph.png',
        koTitle: '냉장고관리',
        enTitle: 'Fridge',
        screen: const CategoryFridgeScreen(),
      ),
      (
        iconAsset: 'assets/icon/icon_hub_cook_glyph.png',
        koTitle: '요리하기',
        enTitle: 'Cook',
        screen: const CategoryCookingScreen(),
      ),
      (
        iconAsset: 'assets/icon/icon_hub_battle_glyph.png',
        koTitle: '푸드대결',
        enTitle: 'Battle',
        screen: const CategoryBattleScreen(),
      ),
      (
        iconAsset: 'assets/icon/icon_hub_community_glyph.png',
        koTitle: '소통공간',
        enTitle: 'Community',
        screen: const CategoryCommunityScreen(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 128,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => card.screen)),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(card.iconAsset,
                      width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                Text(tr(card.koTitle, card.enTitle),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRollingBanner() {
    final banners = [
      (
        colors: [const Color(0xFFE6F4F1), const Color(0xFFE6F4F1)],
        emoji: 'ℹ️',
        title: tr('장마철 식중독 조심! 🦠', 'Watch out for food poisoning! 🦠'),
        subtitle: tr('올바른 냉장고 관리 수칙 확인하기', 'Check proper fridge storage tips'),
      ),
      (
        colors: [const Color(0xFFE6F4F1), const Color(0xFFE6F4F1)],
        emoji: '🏆',
        title: tr('K-Food 챌린지 도전! 🇰🇷', 'Take the K-Food challenge! 🇰🇷'),
        subtitle: tr('다양한 한식을 요리하고 K-Food Master가 되어보세요',
            'Cook Korean dishes and become a K-Food Master'),
      ),
      (
        colors: [const Color(0xFFE6F4F1), const Color(0xFFE6F4F1)],
        emoji: '💡',
        title: tr('영수증만 찍으면 식재료 등록 끝!', 'Snap a receipt and you\'re stocked!'),
        subtitle: tr('바로 써보기', 'Try it now'),
      ),
    ];
    return Column(
      children: [
        SizedBox(
          height: 108,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) =>
                setState(() => _currentBannerPage = index),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return GestureDetector(
                // 영수증스캔 슬라이드(2번)는 가이드 페이지 대신 예전처럼 영수증스캔
                // 탭으로 바로 점프한다 — 상단 고정 배너 자리를 "100% 활용법"에게
                // 내주면서 노출 빈도는 줄었지만, 원탭 숏컷 기능 자체는 유지한다.
                onTap: () => index == 2
                    ? _openAddIngredient(tab: 3)
                    : Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                BannerDetailScreen(bannerIndex: index)),
                      ),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: banner.colors),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(banner.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.tealPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(banner.subtitle,
                                style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppColors.tealPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(banner.emoji,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: _currentBannerPage == index ? 16 : 5,
              decoration: BoxDecoration(
                color: _currentBannerPage == index
                    ? AppColors.tealPrimary
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 현재 냉장고 재료와 매칭률이 가장 높은 K-Food 레시피 1개를 골라준다.
  /// kfoodCatalog가 비어 있을 일은 없지만 방어적으로 null을 반환할 수 있게 한다.
  Recipe? _topKFoodMatch(Set<String> names) {
    if (kfoodCatalog.isEmpty) return null;
    var best = kfoodCatalog.first;
    var bestRate = -1.0;
    for (final recipe in kfoodCatalog) {
      final total = recipe.requiredIngredients.length;
      final rate = total == 0 ? 0.0 : recipe.matchedCount(names) / total;
      if (rate > bestRate) {
        bestRate = rate;
        best = recipe;
      }
    }
    return best;
  }

  /// 지금 냉장고 재료로 가장 잘 만들 수 있는 K-Food 1순위를 보여주는 카드.
  /// 포인트는 하드코딩 없이 실제 ChefPointsStore의 난이도별 가중치(difficultyWeight)를 그대로 쓴다.
  Widget _buildEventPromoCard(Set<String> names) {
    final recipe = _topKFoodMatch(names);
    if (recipe == null) return const SizedBox.shrink();
    final matched = recipe.matchedCount(names);
    final total = recipe.requiredIngredients.length;
    final points = difficultyWeight(recipe.difficulty);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              RecipeDetailScreen(recipe: recipe, fridgeIngredientNames: names),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: cardDropShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      tr('오늘 만들기 좋은 K-Food 🇰🇷', 'A K-Food pick for today 🇰🇷'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.paperDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  child: Text(
                    tr('완성 시 +$points점', '+$points pts on finish'),
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: RecipePhoto(
                    photoUrl: recipe.photoUrl,
                    emoji: recipe.emoji,
                    cuisineType: recipe.cuisineType,
                    width: 64,
                    height: 64,
                    emojiSize: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(recipe.title, recipe.titleEn),
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        tr('재료 $matched/$total개 보유 · 난이도 ${trTag(recipe.difficulty)}',
                            '$matched/$total items on hand · Level ${trTag(recipe.difficulty)}'),
                        style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.inkSoft.withValues(alpha: 0.6), size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 배달의민족식 상시 노출 플로팅 숏컷 — 실제 ShareScreen(식사 초대/요리 자랑)으로 이동한다.
  Widget _buildFloatingPromoBadge(Set<String> names) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShareScreen(fridgeIngredientNames: names),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.green, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✉️', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              tr('SNS공유', 'Share'),
              style: const TextStyle(
                  color: AppColors.greenDeep,
                  fontSize: 9,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryCard(List<FridgeItem> atRisk, Set<String> names) {
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: cardDropShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled,
                  color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(tr('임박 재료 알림', 'Expiry alerts'),
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          if (atRisk.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        tr('냉장고가 신선해요! 임박한 재료가 없어요',
                            'Fresh fridge! Nothing expiring soon'),
                        style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            )
          else
            ...atRisk.take(3).map((item) {
              final bad = item.ddayLevel == DdayLevel.bad;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bad ? AppColors.redSoft : AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(bad ? '⏰' : '🔥',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          '${trIngredientName(item.name)} · ${item.ddayLabel}',
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
    if (atRisk.isEmpty) return card;
    // 임박 재료가 있을 때만 탭 가능하게 해서, 그 재료들로 만들 수 있는 레시피
    // 추천 화면으로 바로 이동한다 — RecommendationScreen은 이미 유통기한 임박
    // 재료를 쓰는 레시피에 expiryUrgencyScore 가산점을 줘서 맨 위로 올려준다.
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => RecommendationScreen(fridgeIngredientNames: names)),
      ),
      child: card,
    );
  }

  Widget _buildFridgeListCard(List<FridgeItem> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: cardDropShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('내 냉장고 · ${items.length}', 'My fridge · ${items.length}'),
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              GestureDetector(
                onTap: () => _openAddIngredient(tab: 0),
                child: const Icon(Icons.add_circle_outline,
                    color: AppColors.green, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Column(
              children: [
                const FridgeMascot(size: 64),
                const SizedBox(height: 12),
                Text(tr('냉장고가 비어있어요', 'Your fridge is empty'),
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 13)),
              ],
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllFridgeItems || items.length <= 5
                  ? items.length
                  : 5,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = item.id;
                final row = _DashboardFridgeRow(item: item);
                if (id == null) return row;
                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.red),
                  ),
                  onDismissed: (_) => FridgeStore.instance.deleteItem(id),
                  child: row,
                );
              },
            ),
          if (items.length > 5) ...[
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    setState(() => _showAllFridgeItems = !_showAllFridgeItems),
                child: Text(
                    _showAllFridgeItems
                        ? tr('접기', 'Show less')
                        : tr('${items.length - 5}개 더보기',
                            '${items.length - 5} more'),
                    style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: cardDropShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('실시간 요리왕 랭킹 🏆', 'Live chef ranking 🏆'),
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RankingScreen())),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.inkSoft.withValues(alpha: 0.6), size: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<_DashboardExtras>(
            future: _extrasFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.green))),
                );
              }
              final ranks = snapshot.data!.ranks;
              if (ranks.isEmpty) {
                return Text(tr('아직 랭킹 데이터가 없어요', 'No ranking data yet'),
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 13));
              }
              const medals = ['🥇', '🥈', '🥉'];
              return Column(
                children: List.generate(ranks.length, (index) {
                  final rank = ranks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${medals[index]}  ${rank.nickname}',
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600)),
                        Text('${rank.points} P',
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('우리 동네 요리 자랑 🍳', 'Community showcase 🍳'),
            style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 12),
        FutureBuilder<_DashboardExtras>(
          future: _extrasFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.green))),
              );
            }
            final posts = snapshot.data!.posts;
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: cardDropShadow(),
                ),
                child: Text(tr('아직 등록된 게시글이 없어요', 'No posts yet'),
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 13)),
              );
            }
            return Column(
              children: posts.map((post) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BoardScreen())),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: cardDropShadow(),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: AppColors.paperDeep,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                              child:
                                  Text('🍳', style: TextStyle(fontSize: 24))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                  '${post.authorNickname} · ${post.category.label}',
                                  style: const TextStyle(
                                      color: AppColors.inkSoft, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardFridgeRow extends StatelessWidget {
  final FridgeItem item;
  const _DashboardFridgeRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.paperDeep, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          IngredientAvatar(name: item.name, category: item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trIngredientName(item.name),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(item.quantityLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: item.ddayLevel.ddayBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text(item.ddayLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: item.ddayLevel.ddayText)),
          ),
        ],
      ),
    );
  }
}
