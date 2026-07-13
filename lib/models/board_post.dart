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
  final String authorNickname;
  final String? authorTier;
  final bool authorIsKFoodMaster;
  final String title;
  final String content;
  final String? photoPath;
  final DateTime createdAt;
  final Set<String> likedByUserIds;

  /// 지금까지 좋아요 보너스로 실제 지급된 포인트 (좋아요÷10) — 중복 지급 방지용
  int pointsAwarded;

  BoardPost({
    required this.id,
    required this.category,
    required this.authorId,
    required this.authorNickname,
    required this.authorTier,
    required this.authorIsKFoodMaster,
    required this.title,
    required this.content,
    required this.createdAt,
    this.photoPath,
    Set<String>? likedByUserIds,
    this.pointsAwarded = 0,
  }) : likedByUserIds = likedByUserIds ?? <String>{};

  int get likeCount => likedByUserIds.length;
}
