import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/cooking_brag.dart';
import '../models/meal_invite.dart';
import '../models/recipe.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../services/meal_invite_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/ai_image_guide_banner.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/framed_post_card.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/main_return_button.dart';
import '../widgets/segmented_tab_bar.dart';
import 'invite_detail_screen.dart';

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1)
    return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

/// 라이트 배경 위 카드 — 헤어라인 보더 + 은은한 드롭 섀도우로 배경과 확실히 구분한다.
BoxDecoration _cardDeco({double radius = AppSpacing.radiusMd}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cardBorder, width: 1.2),
    boxShadow: cardDropShadow(),
  );
}

/// 빈 상태 화면에서 마스코트를 민트 틴트 링 안에 담아 카드 위에서도 또렷하게 도드라지게 한다.
class _GlowMascot extends StatelessWidget {
  const _GlowMascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.green.withValues(alpha: 0.3), width: 1.5),
      ),
      child: const Center(child: FridgeMascot(size: 56)),
    );
  }
}

/// 빈 상태 전용 카드 패널 — 마스코트 + 안내 문구를 하나의 화이트 카드로 감싸 화면 중앙에서
/// 존재감 있게 보여준다.
class _EmptyStateCard extends StatelessWidget {
  final String message;
  const _EmptyStateCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: _cardDeco(radius: AppSpacing.radiusLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GlowMascot(),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareScreen extends StatefulWidget {
  final Set<String> fridgeIngredientNames;
  final int initialTabIndex;
  /// true면 상위 카테고리 화면(세그먼트 탭)에 "식사초대장" 콘텐츠만 끼워 넣는 모드 —
  /// 자체 Scaffold/AppBar/내부 탭바 없이 초대장 목록+만들기 버튼만 반환한다.
  final bool embed;

  const ShareScreen({
    super.key,
    required this.fridgeIngredientNames,
    this.initialTabIndex = 0,
    this.embed = false,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<MealInvite> _invites = [];
  bool _invitesLoaded = false;

  final List<CookingBrag> _brags = [
    CookingBrag(
      title: '계란볶음밥',
      recipeTitle: '계란볶음밥',
      caption: '10분 만에 완성! 생각보다 훨씬 맛있었어요',
      completedAt: DateTime.now().subtract(const Duration(hours: 5)),
      frameCategory: '한식',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex)
      ..addListener(() => setState(() {}));
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final invites = await MealInviteStore.instance.fetchMyInvites();
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _invitesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _invitesLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateInvite() async {
    final draft =
        await showModalBottomSheet<({String recipeTitle, String message})>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CreateInviteSheet(),
    );
    if (draft == null || !mounted) return;

    late final MealInvite result;
    try {
      result = await MealInviteStore.instance.createInvite(
        recipeTitle: draft.recipeTitle,
        message: draft.message,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('초대장 생성에 실패했어요', 'Could not create the invite'))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _invites.insert(0, result));
    final recipe = findRecipeByTitle(result.recipeTitle);
    if (recipe != null) {
      ChefPointsStore.instance.recordInvite(
        recipeTitle: recipe.title,
        difficulty: recipe.difficulty,
        isKFood: recipe.isKFood,
      );
    }
    await Clipboard.setData(ClipboardData(text: result.inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(tr('초대장을 만들고 링크를 복사했어요', 'Invite created and link copied'))),
    );
  }

  Future<void> _openCreateBrag() async {
    final result = await showModalBottomSheet<CookingBrag>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CreateBragSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _brags.insert(0, result));
    final recipe = findRecipeByTitle(result.recipeTitle);
    if (recipe != null) {
      final isFullMatch = recipe.matchLevel(widget.fridgeIngredientNames) ==
          RecipeMatchLevel.full;
      ChefPointsStore.instance.recordCook(
        recipeTitle: recipe.title,
        difficulty: recipe.difficulty,
        isKFood: recipe.isKFood,
        isFullFridgeMatch: isFullMatch,
      );
    }
    final bragId = result.completedAt.millisecondsSinceEpoch;
    final bragLink = 'https://fridgechef.app/brag/$bragId';
    await Clipboard.setData(ClipboardData(text: bragLink));
    if (!mounted) return;
    _showBragLinkDialog(bragLink, result.title);
  }

  void _showBragLinkDialog(String link, String recipeTitle) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('요리 자랑 링크 생성!', 'Brag link created!'),
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('$recipeTitle 요리 자랑 링크를 클립보드에 복사했어요.',
                  'The $recipeTitle brag link was copied to your clipboard.'),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.paperDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                link,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(tr('링크 복사', 'Copy link'),
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('닫기', 'Close'),
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(bool isInviteTab) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: 95 + MediaQuery.of(context).padding.bottom),
      child: FloatingActionButton.extended(
        elevation: 0,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        onPressed: isInviteTab ? _openCreateInvite : _openCreateBrag,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          isInviteTab ? tr('초대장 만들기', 'New Invite') : tr('자랑하기', 'Brag Now'),
          style:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInviteTab = _tabController.index == 0;

    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) {
        if (widget.embed) {
          // 소통공간 허브의 "식사초대장" 탭 전용 — 요리자랑 서브탭은 노출하지 않고
          // 초대장 목록+만들기 버튼만 보여준다.
          return Stack(
            children: [
              _InviteTab(invites: _invites, loaded: _invitesLoaded),
              Positioned(
                right: 20,
                bottom: 95 + MediaQuery.of(context).padding.bottom,
                child: _buildFab(true),
              ),
            ],
          );
        }
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
                child: Image.asset('assets/icon/icon_share.png',
                    width: 58, height: 58, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tr('공유하기', 'Share'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.ink),
                ),
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
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => PillToggle(
                  labels: [tr('식사 초대장', 'Invites'), tr('요리 자랑하기', 'Brags')],
                  index: _tabController.index,
                  onChanged: (i) => _tabController.animateTo(i),
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _InviteTab(invites: _invites, loaded: _invitesLoaded),
            _BragTab(brags: _brags),
          ],
        ),
        floatingActionButton: _buildFab(isInviteTab),
        extendBody: true,
        bottomNavigationBar: MainBottomNav(
            currentIndex: 4, fridgeIngredientNames: widget.fridgeIngredientNames),
        );
      },
    );
  }
}

class _InviteTab extends StatelessWidget {
  final List<MealInvite> invites;
  final bool loaded;
  const _InviteTab({required this.invites, required this.loaded});

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (invites.isEmpty) {
      return _EmptyStateCard(
          message: tr('아직 보낸 초대장이 없어요', 'No invites sent yet'));
    }
    // 게시판/요리자랑 목록과 동일한 컨벤션 — 좌측 80x80 썸네일 + 우측 텍스트, 플랫 리스트.
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 110),
        itemCount: invites.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFFE2E8F0), height: 1),
        itemBuilder: (context, index) {
          final invite = invites[index];
          final recipe = findRecipeByTitle(invite.recipeTitle);
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => InviteDetailScreen(inviteId: invite.id)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RecipePhoto(
                      photoUrl: recipe?.photoUrl ??
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Bibimbap_7.jpg/960px-Bibimbap_7.jpg',
                      emoji: recipe?.emoji ?? '🍽️',
                      cuisineType: recipe?.cuisineType ?? '',
                      width: 80,
                      height: 80,
                      emojiSize: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('${invite.recipeTitle} 초대장',
                              '${invite.recipeTitle} Invite'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invite.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgoLabel(invite.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BragTab extends StatelessWidget {
  final List<CookingBrag> brags;
  const _BragTab({required this.brags});

  @override
  Widget build(BuildContext context) {
    if (brags.isEmpty) {
      return _EmptyStateCard(
          message: tr('아직 자랑한 요리가 없어요', 'No dishes shared yet'));
    }
    // 게시판 목록(board_screen.dart)과 동일한 컨벤션 — 좌측 80x80 썸네일 + 우측 텍스트,
    // 카드 박스 없이 흰 배경 위 얇은 구분선으로만 행을 나누는 플랫 리스트.
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: brags.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFFE2E8F0), height: 1),
        itemBuilder: (context, index) {
          final brag = brags[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => CookingBragDetailScreen(brag: brag)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BragThumbnail(
                      recipeTitle: brag.recipeTitle, photoPath: brag.photoPath),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brag.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          brag.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgoLabel(brag.completedAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BragThumbnail extends StatelessWidget {
  final String recipeTitle;
  final String? photoPath;
  const _BragThumbnail({required this.recipeTitle, this.photoPath});

  @override
  Widget build(BuildContext context) {
    if (photoPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(photoPath!),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        ),
      );
    }
    final recipe = findRecipeByTitle(recipeTitle);
    final gradient = cuisineGradient(recipe?.cuisineType ?? '');
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(recipe?.emoji ?? '🍽️', style: const TextStyle(fontSize: 28)),
    );
  }
}

/// 요리 자랑 상세 — 업로드해주신 장식 프레임(FramedPostCard)이 곧 카드 틀이 된다.
class CookingBragDetailScreen extends StatelessWidget {
  final CookingBrag brag;
  const CookingBragDetailScreen({super.key, required this.brag});

  @override
  Widget build(BuildContext context) {
    final recipe = findRecipeByTitle(brag.recipeTitle);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: const MainReturnButton(),
      appBar: AppBar(
        leading: const LabeledBackButton(),
        leadingWidth: 96,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tr('요리 자랑', 'Cooking Brag'),
            style: const TextStyle(
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          // 액자 틀 — 사진만 내경 창 안에 고정. 글씨는 액자 밖(아래) 패널로 분리한다.
          FramedPostCard(
            frameCategory: brag.frameCategory,
            onPhotoTap: brag.photoPath == null
                ? null
                : () => _openBragPhotoViewer(context, brag.photoPath!),
            photo: brag.photoPath != null
                ? Image.file(File(brag.photoPath!), fit: BoxFit.cover)
                : RecipePhoto(
                    photoUrl: recipe?.photoUrl ?? '',
                    emoji: recipe?.emoji ?? '🍽️',
                    cuisineType: recipe?.cuisineType ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    emojiSize: 44,
                  ),
          ),
          const SizedBox(height: 16),
          // 액자 바로 아래 독립된 글 패널 — 뽐내기 게시판과 동일한 톤
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brag.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  brag.caption,
                  style: const TextStyle(
                      fontSize: 14, height: 1.4, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Text(
                  _timeAgoLabel(brag.completedAt),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openBragPhotoViewer(BuildContext context, String path) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CreateInviteSheet extends StatefulWidget {
  const _CreateInviteSheet();

  @override
  State<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends State<_CreateInviteSheet> {
  late String _selectedRecipe;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _selectedRecipe = allRecipes.first.title;
    _messageController = TextEditingController(text: '같이 만들어 먹어요!');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _confirm() {
    final message = _messageController.text.trim();
    Navigator.pop(
      context,
      (
        recipeTitle: _selectedRecipe,
        message: message.isEmpty ? '같이 만들어 먹어요!' : message
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 +
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('식사 초대장 만들기', 'New Invite'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            elevation: 2,
            isExpanded: true,
            dropdownColor: AppColors.card,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('레시피 선택', 'Choose recipe'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            items: allRecipes
                .map((r) => DropdownMenuItem(
                      value: r.title,
                      child: Text(
                        r.isKFood
                            ? '🇰🇷 ${tr(r.title, r.titleEn)}'
                            : tr(r.title, r.titleEn),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedRecipe = v);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: tr('초대 메시지', 'Message'),
              alignLabelWithHint: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                tr('초대장 링크 생성하기', 'Create Invite Link'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CreateBragSheet extends StatefulWidget {
  const _CreateBragSheet();

  @override
  State<_CreateBragSheet> createState() => _CreateBragSheetState();
}

/// "만든 레시피" 드롭다운 맨 위에 두는 직접입력 옵션의 값
const _customRecipeValue = '직접입력';

class _CreateBragSheetState extends State<_CreateBragSheet> {
  late String _selectedRecipe;
  late String _selectedFrame;
  late final TextEditingController _titleController;
  late final TextEditingController _captionController;
  late final TextEditingController _customRecipeController;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _selectedRecipe = allRecipes.first.title;
    _selectedFrame = bragFrameCategories.first;
    _titleController = TextEditingController();
    _captionController = TextEditingController();
    _customRecipeController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _customRecipeController.dispose();
    super.dispose();
  }

  Future<void> _openPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null && mounted) setState(() => _pickedImage = picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('사진을 가져오지 못했어요', 'Could not load photo'))),
        );
      }
    }
  }

  void _confirm() {
    final recipeTitle = _selectedRecipe == _customRecipeValue
        ? _customRecipeController.text.trim()
        : _selectedRecipe;
    final title = _titleController.text.trim().isEmpty
        ? recipeTitle
        : _titleController.text.trim();
    Navigator.pop(
      context,
      CookingBrag(
        title: title,
        recipeTitle: recipeTitle,
        caption: _captionController.text.trim().isEmpty
            ? tr('$recipeTitle 완성했어요!', 'Finished making $recipeTitle!')
            : _captionController.text.trim(),
        completedAt: DateTime.now(),
        frameCategory: _selectedFrame,
        photoPath: _pickedImage?.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 +
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('나의 요리 자랑하기', 'Brag About Your Dish'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            tr('테마 액자 프레임 고르기', 'Choose a theme frame'),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bragFrameCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = bragFrameCategories[index];
                final selected = _selectedFrame == category;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedFrame = category),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.ink
                                : AppColors.cardBorder,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            bragFrameAsset(category),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.ink : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: tr('제목', 'Title'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            elevation: 2,
            isExpanded: true,
            dropdownColor: AppColors.card,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('만든 레시피', 'Recipe you made'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: _customRecipeValue,
                child: Text(
                  tr('✏️ 직접입력', '✏️ Type my own'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...allRecipes.map((r) => DropdownMenuItem(
                    value: r.title,
                    child: Text(
                      r.isKFood
                          ? '🇰🇷 ${tr(r.title, r.titleEn)}'
                          : tr(r.title, r.titleEn),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedRecipe = v);
            },
          ),
          if (_selectedRecipe == _customRecipeValue) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customRecipeController,
              style: const TextStyle(color: AppColors.ink),
              decoration: InputDecoration(
                labelText: tr('레시피 이름 직접 입력', 'Type the recipe name'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_pickedImage!.path),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => _pickedImage = null),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.green, width: 1.2),
                  foregroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openPhotoSourceSheet,
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: Text(
                  tr('완성 요리 사진 추가', 'Add photo'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const AiImageGuideBanner(),
          const SizedBox(height: 8),
          Text(
            tr('💡 안내: 사진은 1:1 권장 비율 / 10MB 이하 파일이 적합하며, 자동으로 액자 틀에 맞춰 고정됩니다. (본문은 200자까지 작성 가능)',
                '💡 Tip: a 1:1 photo under 10MB fits best — it will be auto-fit to the frame window. (Caption up to 200 characters)'),
            style: const TextStyle(
                fontSize: 11, color: AppColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _captionController,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: tr('요리 한마디 남기기', 'Say a few words'),
              alignLabelWithHint: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                tr('자랑 타임라인에 등록', 'Brag Now'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
