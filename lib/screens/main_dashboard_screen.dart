import 'dart:async';

import 'package:flutter/material.dart';

import '../data/kfood_catalog.dart';
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
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'add_ingredient_screen.dart';
import 'banner_detail_screen.dart';
import '../models/battle.dart';
import '../models/battle_list_item.dart';
import '../services/battle_store.dart';
import 'battle_detail_screen.dart';
import 'battle_screen.dart';
import 'board_screen.dart';
import 'kfood_screen.dart';
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
  final GlobalKey _expiryKey = GlobalKey();
  late Future<_DashboardExtras> _extrasFuture;
  int _currentBannerPage = 0;
  Timer? _rollingTimer;

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
    final statusLabel = battle.status == BattleStatus.voting
        ? tr('투표 중', 'Voting')
        : tr('진행 중', 'Live');
    final statusColor =
        battle.status == BattleStatus.voting ? AppColors.gold : AppColors.carrot;
    final challenger = item.challengerNickname ?? tr('대기 중', 'Waiting');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => BattleDetailScreen(battleId: battle.id)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: FadeTransition(opacity: anim, child: child),
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
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '● $statusLabel',
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
                  const Text('💡 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      tr('영수증만 찍으면 식재료 등록 끝! 바로 써보기',
                          'Snap a receipt and your fridge is stocked instantly!'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
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

  void _scrollToExpiry() {
    final context = _expiryKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
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
                            Text(tr('My Menu', 'My Menu'),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink)),
                            const SizedBox(height: 12),
                            _buildMyMenuGrid(names),
                            const SizedBox(height: 24),
                            _buildRollingBanner(),
                            if (_activeBattles.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildBattleTicker(),
                            ],
                            const SizedBox(height: 24),
                            _buildEventPromoCard(names),
                            const SizedBox(height: 24),
                            _buildExpiryCard(atRisk),
                            const SizedBox(height: 24),
                            _buildFridgeListCard(items),
                            const SizedBox(height: 24),
                            _buildRankingCard(),
                            const SizedBox(height: 24),
                            _buildCommunityFeed(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildFloatingPromoBadge(names),
                ),
              ],
            ),
          ),
          bottomNavigationBar: MainBottomNav(
              currentIndex: 0, fridgeIngredientNames: names, dark: false),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tr('$nickname 님', nickname),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ChefTierBadge(),
                  ],
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
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.greenDeep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMenuGrid(Set<String> names) {
    final menuItems = <({String iconAsset, String label, VoidCallback onTap})>[
      (
        iconAsset: 'assets/icon/menu_receipt.png',
        label: tr('영수증 등록', 'Receipt'),
        onTap: () => _openAddIngredient(tab: 2),
      ),
      (
        iconAsset: 'assets/icon/menu_additem.png',
        label: tr('재료 추가', 'Add item'),
        onTap: () => _openAddIngredient(tab: 0),
      ),
      (
        iconAsset: 'assets/icon/menu_airecipe.png',
        label: tr('AI 추천', 'AI Recipes'),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) =>
                      RecommendationScreen(fridgeIngredientNames: names)),
            ),
      ),
      (
        iconAsset: 'assets/icon/menu_invite.png',
        label: tr('식사 초대', 'Invite'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShareScreen(fridgeIngredientNames: names))),
      ),
      (
        iconAsset: 'assets/icon/menu_kfood.png',
        label: tr('K-Food', 'K-Food'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => KFoodScreen(fridgeIngredientNames: names))),
      ),
      (
        iconAsset: 'assets/icon/menu_expiring.png',
        label: tr('임박 재료', 'Expiring'),
        onTap: _scrollToExpiry,
      ),
      (
        iconAsset: 'assets/icon/menu_battle.png',
        label: tr('배틀', 'Battle'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BattleScreen())),
      ),
      (
        iconAsset: 'assets/icon/menu_board.png',
        label: tr('소통 광장', 'Board'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BoardScreen())),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: cardDropShadow(),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 14,
          childAspectRatio: 0.8,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return GestureDetector(
            onTap: item.onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
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
                  child: ClipOval(
                    child: Image.asset(item.iconAsset, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRollingBanner() {
    final banners = [
      (
        colors: [const Color(0xFF2E0854), const Color(0xFF1E1035)],
        emoji: 'ℹ️',
        title: tr('장마철 식중독 조심! 🦠', 'Watch out for food poisoning! 🦠'),
        subtitle: tr('올바른 냉장고 관리 수칙 확인하기', 'Check proper fridge storage tips'),
      ),
      (
        colors: [const Color(0xFF8B1E1E), const Color(0xFF3F1010)],
        emoji: '🏆',
        title: tr('K-Food 챌린지 도전! 🇰🇷', 'Take the K-Food challenge! 🇰🇷'),
        subtitle: tr('다양한 한식을 요리하고 K-Food Master가 되어보세요',
            'Cook Korean dishes and become a K-Food Master'),
      ),
      (
        colors: [const Color(0xFF0369A1), const Color(0xFF075985)],
        emoji: '🚀',
        title: tr('냉장고 셰프 100% 활용법 💡', 'Get the most out of Fridge Chef 💡'),
        subtitle: tr('재료 등록부터 AI 추천, 요리 배틀, 커뮤니티까지 한눈에',
            'Ingredients, AI recipes, battles, and community — all in one place'),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => BannerDetailScreen(bannerIndex: index)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: banner.colors),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(banner.subtitle,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
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
                            color: Colors.white.withValues(alpha: 0.08),
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
                    ? AppColors.green
                    : AppColors.line,
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
                Text(
                    tr('오늘 만들기 좋은 K-Food 🇰🇷', 'A K-Food pick for today 🇰🇷'),
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.carrotSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('완성 시 +$points점', '+$points pts on finish'),
                    style: const TextStyle(
                        color: AppColors.carrot,
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

  Widget _buildExpiryCard(List<FridgeItem> atRisk) {
    return Container(
      key: _expiryKey,
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
                      child: Text('${item.name} · ${item.ddayLabel}',
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
              itemCount: items.length > 5 ? 5 : items.length,
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
              child: Text(
                  tr('${items.length - 5}개 더보기', '${items.length - 5} more'),
                  style:
                      const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
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
                                color: AppColors.green,
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

  Color _ddayBg() {
    switch (item.ddayLevel) {
      case DdayLevel.ok:
        return AppColors.greenSoft;
      case DdayLevel.warn:
        return AppColors.goldSoft;
      case DdayLevel.bad:
        return AppColors.redSoft;
    }
  }

  Color _ddayText() {
    switch (item.ddayLevel) {
      case DdayLevel.ok:
        return AppColors.green;
      case DdayLevel.warn:
        return AppColors.gold;
      case DdayLevel.bad:
        return AppColors.red;
    }
  }

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
                Text(item.name,
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
                color: _ddayBg(), borderRadius: BorderRadius.circular(8)),
            child: Text(item.ddayLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _ddayText())),
          ),
        ],
      ),
    );
  }
}
