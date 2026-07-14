import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/kfood_catalog.dart';
import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/cooking_brag.dart';
import '../models/meal_invite.dart';
import '../models/recipe.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';

const _inviteIdChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

final _allShareableRecipes = <Recipe>[...recipeCatalog, ...kfoodCatalog];

Recipe? _findRecipeByTitle(String title) => _allShareableRecipes
    .cast<Recipe?>()
    .firstWhere((r) => r?.title == title, orElse: () => null);

String _generateInviteId() {
  final random = Random();
  return List.generate(6, (_) => _inviteIdChars[random.nextInt(_inviteIdChars.length)]).join();
}

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1) return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

class ShareScreen extends StatefulWidget {
  final Set<String> fridgeIngredientNames;

  const ShareScreen({super.key, required this.fridgeIngredientNames});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<MealInvite> _invites = [
    MealInvite(
      recipeTitle: '두부김치찌개',
      message: '이번 주말에 같이 만들어 먹어요!',
      inviteLink: 'https://fridgechef.app/invite/${_generateInviteId()}',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<CookingBrag> _brags = [
    CookingBrag(
      recipeTitle: '계란볶음밥',
      caption: '10분 만에 완성! 생각보다 훨씬 맛있었어요',
      completedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreateInvite() async {
    final result = await showModalBottomSheet<MealInvite>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CreateInviteSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _invites.insert(0, result));
    final recipe = _findRecipeByTitle(result.recipeTitle);
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
      SnackBar(content: Text(tr('초대장을 만들고 링크를 복사했어요', 'Invite created and link copied'))),
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
    final recipe = _findRecipeByTitle(result.recipeTitle);
    if (recipe != null) {
      final isFullMatch = recipe.matchLevel(widget.fridgeIngredientNames) == RecipeMatchLevel.full;
      ChefPointsStore.instance.recordCook(
        recipeTitle: recipe.title,
        difficulty: recipe.difficulty,
        isKFood: recipe.isKFood,
        isFullFridgeMatch: isFullMatch,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInviteTab = _tabController.index == 0;

    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            tr('공유하기', 'Share'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.ink,
            ),
          ),
          actions: const [
            Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
            Padding(padding: EdgeInsets.only(right: 16), child: ChefTierBadge()),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.paperDeep,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.inkSoft,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: [
                  Tab(text: tr('식사 초대장', 'Invites')),
                  Tab(text: tr('요리 자랑하기', 'Brags')),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _InviteTab(invites: _invites),
            _BragTab(brags: _brags),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          elevation: 2,
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          onPressed: isInviteTab ? _openCreateInvite : _openCreateBrag,
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            isInviteTab ? tr('초대장 만들기', 'New Invite') : tr('자랑하기', 'Brag Now'),
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
          ),
        ),
        bottomNavigationBar: MainBottomNav(
          currentIndex: 2,
          fridgeIngredientNames: widget.fridgeIngredientNames,
        ),
      ),
    );
  }
}

class _InviteTab extends StatelessWidget {
  final List<MealInvite> invites;
  const _InviteTab({required this.invites});

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FridgeMascot(size: 84),
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('아직 보낸 초대장이 없어요', 'No invites sent yet'),
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      itemCount: invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final invite = invites[index];
        final recipe = _findRecipeByTitle(invite.recipeTitle);
        return Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipePhoto(
                photoUrl: recipe?.photoUrl ??
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Bibimbap_7.jpg/960px-Bibimbap_7.jpg',
                emoji: recipe?.emoji ?? '🍽️',
                cuisineType: recipe?.cuisineType ?? '',
                width: double.infinity,
                height: 120,
                emojiSize: 44,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tr('🍽️ ${invite.recipeTitle} 초대장', '🍽️ ${invite.recipeTitle} Invite'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgoLabel(invite.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"${invite.message}"',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.paperDeep,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              invite.inviteLink,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                                fontFamily: 'Courier',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                await Clipboard.setData(ClipboardData(text: invite.inviteLink));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(tr('링크가 복사됐어요', 'Link copied'))),
                                  );
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.copy_rounded, size: 16, color: AppColors.green),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BragTab extends StatelessWidget {
  final List<CookingBrag> brags;
  const _BragTab({required this.brags});

  @override
  Widget build(BuildContext context) {
    if (brags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FridgeMascot(size: 84),
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('아직 자랑한 요리가 없어요', 'No dishes shared yet'),
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
      itemCount: brags.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final brag = brags[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BragThumbnail(recipeTitle: brag.recipeTitle, photoPath: brag.photoPath),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            brag.recipeTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgoLabel(brag.completedAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      brag.caption,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      );
    }
    final recipe = _findRecipeByTitle(recipeTitle);
    final gradient = cuisineGradient(recipe?.cuisineType ?? '');
    return Container(
      width: 64,
      height: 64,
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
    _selectedRecipe = _allShareableRecipes.first.title;
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
      MealInvite(
        recipeTitle: _selectedRecipe,
        message: message.isEmpty ? '같이 만들어 먹어요!' : message,
        inviteLink: 'https://fridgechef.app/invite/${_generateInviteId()}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            elevation: 2,
            dropdownColor: AppColors.card,
            decoration: InputDecoration(
              labelText: tr('레시피 선택', 'Choose recipe'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            items: _allShareableRecipes
                .map((r) => DropdownMenuItem(
                      value: r.title,
                      child: Text(r.isKFood ? '🇰🇷 ${r.title}' : r.title),
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
            decoration: InputDecoration(
              labelText: tr('초대 메시지', 'Message'),
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                tr('초대장 링크 생성하기', 'Create Invite Link'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateBragSheet extends StatefulWidget {
  const _CreateBragSheet();

  @override
  State<_CreateBragSheet> createState() => _CreateBragSheetState();
}

class _CreateBragSheetState extends State<_CreateBragSheet> {
  late String _selectedRecipe;
  late final TextEditingController _captionController;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _selectedRecipe = _allShareableRecipes.first.title;
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _captionController.dispose();
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
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.green),
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
    Navigator.pop(
      context,
      CookingBrag(
        recipeTitle: _selectedRecipe,
        caption: _captionController.text.trim().isEmpty
            ? tr('$_selectedRecipe 완성했어요!', 'Finished making $_selectedRecipe!')
            : _captionController.text.trim(),
        completedAt: DateTime.now(),
        photoPath: _pickedImage?.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            elevation: 2,
            dropdownColor: AppColors.card,
            decoration: InputDecoration(
              labelText: tr('만든 레시피', 'Recipe you made'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            items: _allShareableRecipes
                .map((r) => DropdownMenuItem(
                      value: r.title,
                      child: Text(r.isKFood ? '🇰🇷 ${r.title}' : r.title),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedRecipe = v);
            },
          ),
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
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openPhotoSourceSheet,
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: Text(
                  tr('완성 요리 사진 추가', 'Add photo'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('요리 한마디 남기기', 'Say a few words'),
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.green, width: 1.5),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                tr('자랑 타임라인에 등록', 'Brag Now'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
