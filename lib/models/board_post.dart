import '../l10n/tr.dart';

enum BoardCategory { showoff, challenge }

extension BoardCategoryLabel on BoardCategory {
  String get label => this == BoardCategory.showoff
      ? tr('뽐내기 게시판', 'Showoff Board')
      : tr('챌린지 게시판', 'Challenge Board');
}

/// 게시판 글 한 건 — 좋아요는 사용자 id 집합으로 관리해 중복 좋아요를 막는다
class BoardPost {
  final String id;
  final BoardCategory category;
  final String authorId;
  final String authorUsername;
  final String authorNickname;
  final String? authorTier;
  final bool authorIsKFoodMaster;
  final String title;
  final String content;
  /// board_posts.photo_url — Supabase Storage(또는 외부 CDN)의 이미지 URL. 로컬 파일 경로가 아니다.
  final String? photoPath;
  final DateTime createdAt;
  final Set<String> likedByUserIds;
  final int commentCount;

  BoardPost({
    required this.id,
    required this.category,
    required this.authorId,
    required this.authorUsername,
    required this.authorNickname,
    required this.authorTier,
    required this.authorIsKFoodMaster,
    required this.title,
    required this.content,
    required this.createdAt,
    this.photoPath,
    this.commentCount = 0,
    Set<String>? likedByUserIds,
  }) : likedByUserIds = likedByUserIds ?? <String>{};

  int get likeCount => likedByUserIds.length;
}
