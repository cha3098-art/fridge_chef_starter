import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/tr.dart';
import '../models/board_post.dart';
import '../models/user_profile.dart';
import '../services/board_store.dart';
import '../services/chef_points_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/chef_badge.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'profile_view_sheet.dart';
import 'sign_up_screen.dart';

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1) return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

/// "게시판" — 뽐내기 게시판 / 챌린지 게시판 두 하위 게시판을 오가며 글을 쓰고 좋아요를 누른다.
/// 좋아요 10개당 작성자에게 +1점이 지급된다.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardCategory _category = BoardCategory.showoff;

  Future<void> _openCreatePost() async {
    final profile = ProfileStore.instance.currentProfile;
    if (profile == null) {
      final goSignUp = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('회원가입이 필요해요', 'Sign up required')),
          content: Text(tr('게시판에 글을 쓰려면 먼저 가입해주세요.', 'Please sign up first to post on the board.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('취소', 'Cancel'))),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('가입하러 가기', 'Go to sign up'))),
          ],
        ),
      );
      if (goSignUp == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
      }
      return;
    }

    final result = await showModalBottomSheet<BoardPost>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreatePostSheet(category: _category, profile: profile),
    );
    if (result != null) BoardStore.instance.addPost(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('게시판', 'Board')),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
          Padding(padding: EdgeInsets.only(right: 12), child: ChefTierBadge()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _CategoryButton(
                    label: BoardCategory.showoff.label,
                    selected: _category == BoardCategory.showoff,
                    onTap: () => setState(() => _category = BoardCategory.showoff),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryButton(
                    label: BoardCategory.challenge.label,
                    selected: _category == BoardCategory.challenge,
                    onTap: () => setState(() => _category = BoardCategory.challenge),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: BoardStore.instance,
              builder: (context, _) {
                final posts = BoardStore.instance.postsFor(_category);
                if (posts.isEmpty) {
                  return Center(
                    child: Text(tr('아직 글이 없어요', 'No posts yet'), style: const TextStyle(color: AppColors.inkSoft)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PostCard(post: posts[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        onPressed: _openCreatePost,
        icon: const Icon(Icons.edit_outlined),
        label: Text(tr('글쓰기', 'Write')),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 5),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paperDeep,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final BoardPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final myId = ProfileStore.instance.currentProfile?.id;
    final liked = myId != null && post.likedByUserIds.contains(myId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  final profile = ProfileStore.instance.findById(post.authorId);
                  if (profile != null) showProfileView(context, profile);
                },
                child: Row(
                  children: [
                    Text(post.authorNickname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '@${post.authorId}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ChefBadge(
                generalTier: post.authorTier,
                isKFoodMaster: post.authorIsKFoodMaster,
                showLabel: false,
                medalSize: 15,
              ),
              const Spacer(),
              Text(_timeAgoLabel(post.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(post.content, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (post.photoPath != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(post.photoPath!),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: myId == null
                ? null
                : () => BoardStore.instance.toggleLike(post.id, myId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: liked ? AppColors.red : AppColors.inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: TextStyle(fontSize: 12, color: liked ? AppColors.red : AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final BoardCategory category;
  final UserProfile profile;

  const _CreatePostSheet({required this.category, required this.profile});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  XFile? _photo;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      // 게시판 용량을 작게 유지하기 위해 낮은 화질/크기로 압축해서 가져온다
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 40,
      );
      if (picked != null && mounted) setState(() => _photo = picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('사진을 가져오지 못했어요', 'Could not load photo'))),
        );
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;
    final profile = widget.profile;
    Navigator.pop(
      context,
      BoardPost(
        id: 'post-${DateTime.now().microsecondsSinceEpoch}',
        category: widget.category,
        authorId: profile.id,
        authorNickname: profile.nickname,
        authorTier: ChefPointsStore.instance.generalTier,
        authorIsKFoodMaster: ChefPointsStore.instance.isKFoodMaster,
        title: title,
        content: content,
        photoPath: _photo?.path,
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
          Text(
            tr('${widget.category.label}에 글쓰기', 'Write on ${widget.category.label}'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: tr('제목', 'Title')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: InputDecoration(labelText: tr('내용', 'Content')),
          ),
          const SizedBox(height: 12),
          if (_photo != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_photo!.path),
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () => setState(() => _photo = null),
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
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_outlined),
              label: Text(tr('사진 추가 (저용량으로 첨부돼요)', 'Add photo (attached at low size)')),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _submit, child: Text(tr('등록하기', 'Post'))),
          ),
        ],
      ),
    );
  }
}
