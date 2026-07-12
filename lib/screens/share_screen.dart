import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/recipe_catalog.dart';
import '../models/cooking_brag.dart';
import '../models/meal_invite.dart';
import '../theme/app_theme.dart';
import 'recommendation_screen.dart';

const _inviteIdChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

String _generateInviteId() {
  final random = Random();
  return List.generate(6, (_) => _inviteIdChars[random.nextInt(_inviteIdChars.length)]).join();
}

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
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
      backgroundColor: const Color(0xFFFFFEFB),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CreateInviteSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _invites.insert(0, result));
    await Clipboard.setData(ClipboardData(text: result.inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('초대장을 만들고 링크를 복사했어요')),
    );
  }

  Future<void> _openCreateBrag() async {
    final result = await showModalBottomSheet<CookingBrag>(
      context: context,
      backgroundColor: const Color(0xFFFFFEFB),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CreateBragSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _brags.insert(0, result));
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isInviteTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('공유하기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.inkSoft,
          indicatorColor: AppColors.green,
          tabs: const [
            Tab(text: '초대장'),
            Tab(text: '자랑하기'),
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
        label: Text(isInviteTab ? '초대장 만들기' : '자랑하기'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.inkSoft,
        backgroundColor: const Color(0xFFFFFEFB),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 2) return;
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            return;
          }
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecommendationScreen(
                  fridgeIngredientNames: widget.fridgeIngredientNames,
                ),
              ),
            );
            return;
          }
          _showComingSoon('준비 중인 화면이에요');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '냉장고'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '추천'),
          BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: '초대함'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
        ],
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
      return const Center(
        child: Text('아직 보낸 초대장이 없어요', style: TextStyle(color: AppColors.inkSoft)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invite = invites[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFB),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      invite.recipeTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  Text(
                    _timeAgoLabel(invite.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(invite.message, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 10),
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
                            const SnackBar(content: Text('링크가 복사됐어요')),
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
      return const Center(
        child: Text('아직 자랑한 요리가 없어요', style: TextStyle(color: AppColors.inkSoft)),
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
            color: const Color(0xFFFFFEFB),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_camera_outlined, color: AppColors.inkSoft),
              ),
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
    _selectedRecipe = recipeCatalog.first.title;
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
          const Text('초대장 만들기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            decoration: const InputDecoration(labelText: '레시피 선택'),
            items: recipeCatalog
                .map((r) => DropdownMenuItem(value: r.title, child: Text(r.title)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedRecipe = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '메시지'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: const Text('초대장 만들기')),
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

  @override
  void initState() {
    super.initState();
    _selectedRecipe = recipeCatalog.first.title;
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(
      context,
      CookingBrag(
        recipeTitle: _selectedRecipe,
        caption: _captionController.text.trim().isEmpty
            ? '$_selectedRecipe 완성했어요!'
            : _captionController.text.trim(),
        completedAt: DateTime.now(),
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
          const Text('요리 자랑하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRecipe,
            decoration: const InputDecoration(labelText: '만든 레시피'),
            items: recipeCatalog
                .map((r) => DropdownMenuItem(value: r.title, child: Text(r.title)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedRecipe = v);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('사진 추가'),
          ),
          const SizedBox(height: 4),
          const Text(
            '사진 추가 기능은 준비 중이에요',
            style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '한마디 남기기'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: const Text('자랑하기')),
          ),
        ],
      ),
    );
  }
}
