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
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';

const _inviteIdChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// 초대장/자랑하기에서 고를 수 있는 전체 레시피 (일반 + K-Food)
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

/// "초대함" 탭 — 식사 초대장 만들기 / 요리 완성 자랑하기
/// 실제로는 Supabase의 meal_invites, user_recipe_history 테이블과 연동하도록 교체 예정
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
      backgroundColor: const Color(0xFFFFFFFF),
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
      backgroundColor: const Color(0xFFFFFFFF),
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

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('공유하기', 'Share')),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
          Padding(padding: EdgeInsets.only(right: 12), child: ChefTierBadge()),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.inkSoft,
          indicatorColor: AppColors.green,
          tabs: [
            Tab(text: tr('초대장', 'Invites')),
            Tab(text: tr('자랑하기', 'Brag')),
          ],
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
        backgroundColor: AppColors.green,
        onPressed: isInviteTab ? _openCreateInvite : _openCreateBrag,
        icon: const Icon(Icons.add),
        label: Text(isInviteTab ? tr('초대장 만들기', 'New Invite') : tr('자랑하기', 'Brag')),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: 2,
        fridgeIngredientNames: widget.fridgeIngredientNames,
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
        child: Text(tr('아직 보낸 초대장이 없어요', 'No invites sent yet'), style: const TextStyle(color: AppColors.inkSoft)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invite = invites[index];
        final recipe = _findRecipeByTitle(invite.recipeTitle);
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipePhoto(
                photoQuery: recipe?.photoQuery ?? 'korean,food',
                emoji: recipe?.emoji ?? '🍽️',
                cuisineType: recipe?.cuisineType ?? '',
                width: double.infinity,
                height: 100,
                emojiSize: 40,
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tr('🍽️ ${invite.recipeTitle} 초대장', '🍽️ ${invite.recipeTitle} Invite'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        Text(
                          _timeAgoLabel(invite.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${invite.message}"',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.paperDeep,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              invite.inviteLink,
                              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: invite.inviteLink));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(tr('링크가 복사됐어요', 'Link copied'))),
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.copy, size: 16, color: AppColors.green),
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
        child: Text(tr('아직 자랑한 요리가 없어요', 'No dishes shared yet'), style: const TextStyle(color: AppColors.inkSoft)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: brags.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final brag = brags[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BragThumbnail(recipeTitle: brag.recipeTitle, photoPath: brag.photoPath),
              const SizedBox(width: 12),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        Text(
                          _timeAgoLabel(brag.completedAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(brag.caption, style: const TextStyle(fontSize: 13, height: 1.4)),
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
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(photoPath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    final recipe = _findRecipeByTitle(recipeTitle);
    final gradient = cuisineGradient(recipe?.cuisineType ?? '');
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(recipe?.emoji ?? '🍽️', style: const TextStyle(fontSize: 24)),
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('초대장 만들기', 'New Invite'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            decoration: InputDecoration(labelText: tr('레시피 선택', 'Choose recipe')),
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
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('메시지', 'Message')),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: Text(tr('초대장 만들기', 'Create Invite'))),
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
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green),
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('요리 자랑하기', 'Brag About It'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            decoration: InputDecoration(labelText: tr('만든 레시피', 'Recipe you made')),
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
          const SizedBox(height: 12),
          if (_pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_pickedImage!.path),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => setState(() => _pickedImage = null),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _openPhotoSourceSheet,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(tr('사진 추가', 'Add photo')),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('한마디 남기기', 'Say a few words')),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: Text(tr('자랑하기', 'Brag'))),
          ),
        ],
      ),
    );
  }
}
