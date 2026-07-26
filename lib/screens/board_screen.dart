import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/tr.dart';
import '../models/board_comment.dart';
import '../models/board_post.dart';
import '../services/board_store.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../utils/image_compressor.dart';
import '../widgets/chef_badge.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'profile_view_sheet.dart';
import 'sign_up_screen.dart';

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1)
    return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

/// 라이트 배경 위 카드 — 헤어라인 보더 + 드롭 섀도우로 구분한다.
/// 피드 카드는 사진·본문이 섞여 있어 다른 카드보다 살짝 더 또렷한 테두리로 경계를 잡는다.
BoxDecoration _cardDeco({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.line, width: 1.2),
    boxShadow: cardDropShadow(),
  );
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

  @override
  void initState() {
    super.initState();
    if (!BoardStore.instance.isLoaded) BoardStore.instance.loadPosts();
  }

  Future<void> _openCreatePost() async {
    final profile = ProfileStore.instance.currentProfile;
    if (profile == null) {
      final goSignUp = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('회원가입이 필요해요', 'Sign up required')),
          content: Text(tr('게시판에 글을 쓰려면 먼저 가입해주세요.',
              'Please sign up first to post on the board.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('취소', 'Cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('가입하러 가기', 'Go to sign up'))),
          ],
        ),
      );
      if (goSignUp == true && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
      }
      return;
    }

    final result = await showModalBottomSheet<
        ({String title, String content, String? photoPath})>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreatePostSheet(category: _category),
    );
    if (result != null) {
      final postId = await BoardStore.instance.addPost(
        category: _category,
        title: result.title,
        content: result.content,
        photoPath: result.photoPath,
      );
      // 챌린지 게시판은 "요리 완성 인증" 성격이라 게시글당 1회 챌린지 포인트를 지급한다
      if (postId != null && _category == BoardCategory.challenge) {
        await ChefPointsStore.instance
            .recordChallengePost(postId: postId, title: result.title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([BoardStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        final posts = BoardStore.instance.isLoaded
            ? BoardStore.instance.postsFor(_category)
            : null;
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 76,
            titleSpacing: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                      _category == BoardCategory.challenge
                          ? 'assets/icon/icon_challenge_rival.png'
                          : 'assets/icon/icon_board.png',
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _category == BoardCategory.challenge
                        ? tr('챌린지 게시판', 'Challenge Board')
                        : tr('게시판', 'Board'),
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
                  padding: EdgeInsets.only(right: 8), child: LanguageToggle()),
              Padding(
                  padding: EdgeInsets.only(right: 12), child: ChefTierBadge()),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _CategoryButton(
                        label: BoardCategory.showoff.label,
                        selected: _category == BoardCategory.showoff,
                        onTap: () =>
                            setState(() => _category = BoardCategory.showoff),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CategoryButton(
                        label: BoardCategory.challenge.label,
                        selected: _category == BoardCategory.challenge,
                        iconAsset: 'assets/icon/icon_challenge_rival.png',
                        onTap: () =>
                            setState(() => _category = BoardCategory.challenge),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: posts == null
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.green))
                    : posts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _category == BoardCategory.challenge
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        child: Image.asset(
                                            'assets/icon/icon_challenge_rival.png',
                                            width: 84,
                                            height: 84,
                                            fit: BoxFit.cover),
                                      )
                                    : const FridgeMascot(size: 84),
                                const SizedBox(height: AppSpacing.md),
                                Text(tr('아직 글이 없어요', 'No posts yet'),
                                    style: const TextStyle(
                                        color: AppColors.inkSoft)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md, 0, AppSpacing.md, 96),
                            itemCount: posts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) =>
                                _PostCard(post: posts[index]),
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            highlightElevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: _openCreatePost,
            icon: const Icon(Icons.edit_outlined),
            label: Text(tr('글쓰기', 'Write'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          bottomNavigationBar: const MainBottomNav(currentIndex: 5),
        );
      },
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? iconAsset;

  const _CategoryButton(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.iconAsset});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paperDeep,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.ink : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconAsset != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child:
                    Image.asset(iconAsset!, width: 16, height: 16, fit: BoxFit.cover),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 안에서는 height:180 + BoxFit.cover로 미리보기만 보여주고,
/// 탭하면 원본 비율 그대로 전체화면으로 확대해서 보여준다 (핀치 줌 지원)
void _openPhotoViewer(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _PhotoViewerScreen(url: url),
    ),
  );
}

class _PhotoViewerScreen extends StatelessWidget {
  final String url;
  const _PhotoViewerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 피드 카드 — 본문은 최대 3줄까지만 보여주고, 카드를 탭하면 [BoardDetailScreen]으로 이동해
/// 전체 글과 댓글을 볼 수 있다. 글 길이와 무관하게 카드 자체는 항상 일정한 크기를 유지한다.
class _PostCard extends StatelessWidget {
  final BoardPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final myId = ProfileStore.instance.currentProfile?.id;
    final liked = myId != null && post.likedByUserIds.contains(myId);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BoardDetailScreen(post: post)),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () async {
                    final profile =
                        await ProfileStore.instance.fetchById(post.authorId);
                    if (profile != null && context.mounted)
                      showProfileView(context, profile);
                  },
                  child: Row(
                    children: [
                      Text(
                        post.authorNickname,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: -0.1,
                            color: AppColors.ink),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '@${post.authorUsername}',
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
                Text(_timeAgoLabel(post.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 5),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.ink),
            ),
            if (post.photoPath != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openPhotoViewer(context, post.photoPath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.photoPath!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            InkWell(
              onTap: myId == null
                  ? null
                  : () => BoardStore.instance.toggleLike(post.id, myId),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: liked ? AppColors.redSoft : AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: liked ? AppColors.red : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${post.likeCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: liked ? AppColors.red : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final BoardCategory category;

  const _CreatePostSheet({required this.category});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  Uint8List? _previewBytes;
  String? _uploadedUrl;
  bool _uploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
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
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 88);
      if (picked == null || !mounted) return;
      // 업로드 용량/대기 시간을 줄이기 위해 서버로 보내기 전에 한 번 더 압축한다
      final originalSize = await File(picked.path).length();
      final compressedFile =
          await ImageCompressor.compressImage(File(picked.path));
      final bytes = await compressedFile.readAsBytes();
      debugPrint(
          '[compress] original: ${(originalSize / 1024).toStringAsFixed(0)}KB -> compressed: ${(bytes.length / 1024).toStringAsFixed(0)}KB');
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _uploadedUrl = null;
        _uploading = true;
      });
      final ext = compressedFile.path.contains('.')
          ? compressedFile.path.split('.').last.toLowerCase()
          : 'jpg';
      final url = await BoardStore.instance.uploadPhoto(bytes, fileExt: ext);
      if (!mounted) return;
      setState(() {
        _uploadedUrl = url;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewBytes = null;
        _uploadedUrl = null;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('사진 업로드에 실패했어요', 'Could not upload the photo'))),
      );
    }
  }

  void _removePhoto() => setState(() {
        _previewBytes = null;
        _uploadedUrl = null;
      });

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty || _uploading) return;
    Navigator.pop(
        context, (title: title, content: content, photoPath: _uploadedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('${widget.category.label}에 글쓰기',
                'Write on ${widget.category.label}'),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
                color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          if (_previewBytes == null)
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        color: AppColors.green, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      tr('📸 사진 첨부하기', '📸 Add a photo'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _previewBytes!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_uploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: _removePhoto,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(labelText: tr('제목', 'Title')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(labelText: tr('내용', 'Content')),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _uploading ? null : _submit,
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(tr('등록하기', 'Post'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 게시글 상세 화면 — 피드에서 생략된 본문 전체와 원본 사진을 보여주고, 댓글을 달 수 있다
class BoardDetailScreen extends StatefulWidget {
  final BoardPost post;
  const BoardDetailScreen({super.key, required this.post});

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  final _commentController = TextEditingController();
  Future<List<BoardComment>>? _commentsFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = BoardStore.instance.fetchComments(widget.post.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) return;

    if (ProfileStore.instance.currentProfile == null) {
      final goSignUp = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('회원가입이 필요해요', 'Sign up required')),
          content: Text(tr('댓글을 달려면 먼저 가입해주세요.',
              'Please sign up first to leave a comment.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(tr('취소', 'Cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(tr('가입하러 가기', 'Go to sign up'))),
          ],
        ),
      );
      if (goSignUp == true && mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      await BoardStore.instance
          .addComment(postId: widget.post.id, content: text);
      _commentController.clear();
      final refreshed = BoardStore.instance.fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _commentsFuture = refreshed;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('댓글 등록에 실패했어요', 'Could not post the comment'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([BoardStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        // 좋아요 등 최신 상태를 반영하되, 스토어에서 사라진 경우(삭제 등) 대비해 원본 post로 폴백한다
        final post =
            BoardStore.instance.findById(widget.post.id) ?? widget.post;
        final myId = ProfileStore.instance.currentProfile?.id;
        final liked = myId != null && post.likedByUserIds.contains(myId);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8FAFC),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              post.category.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            final profile = await ProfileStore.instance
                                .fetchById(post.authorId);
                            if (profile != null && context.mounted)
                              showProfileView(context, profile);
                          },
                          child: Row(
                            children: [
                              Text(
                                post.authorNickname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.1),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '@${post.authorUsername}',
                                style: const TextStyle(
                                  fontSize: 12,
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
                          medalSize: 16,
                        ),
                        const Spacer(),
                        Text(_timeAgoLabel(post.createdAt),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      post.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          height: 1.3),
                    ),
                    if (post.photoPath != null) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _openPhotoViewer(context, post.photoPath!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            post.photoPath!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(post.content,
                        style: const TextStyle(
                            fontSize: 14, height: 1.6, letterSpacing: 0.1)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: myId == null
                          ? null
                          : () => BoardStore.instance.toggleLike(post.id, myId),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 14),
                        decoration: BoxDecoration(
                          color: liked
                              ? const Color(0xFFFFE1E6)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: liked ? AppColors.red : AppColors.inkSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.likeCount}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    liked ? AppColors.red : AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FutureBuilder<List<BoardComment>>(
                      future: _commentsFuture,
                      builder: (context, snapshot) {
                        final comments = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('댓글 ${comments?.length ?? 0}개',
                                  '${comments?.length ?? 0} comments'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 12),
                            if (comments == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else if (comments.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  tr('아직 댓글이 없어요. 첫 댓글을 남겨보세요!',
                                      'No comments yet. Be the first to comment!'),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.inkSoft),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFF1F5F9), width: 1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md),
                                child: Column(
                                  children: [
                                    for (final c in comments)
                                      _CommentTile(comment: c)
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: tr('댓글을 남겨보세요', 'Leave a comment'),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _submitComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _submitting ? null : _submitComment,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              _submitting ? AppColors.inkSoft : AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
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

class _CommentTile extends StatelessWidget {
  final BoardComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment.authorNickname,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: -0.1),
              ),
              const SizedBox(width: 4),
              ChefBadge(
                generalTier: comment.authorTier,
                isKFoodMaster: comment.authorIsKFoodMaster,
                showLabel: false,
                medalSize: 13,
              ),
              const SizedBox(width: 4),
              Text(_timeAgoLabel(comment.createdAt),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.content,
              style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
