/// board_comments 테이블에 대응하는 게시글 댓글 한 건.
/// 작성자 정보는 댓글 작성 시점의 닉네임/등급을 그대로 저장한다(비정규화) —
/// 이후 작성자의 등급이 바뀌어도 과거 댓글에 표시된 배지는 바뀌지 않는다.
class BoardComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String authorUsername;
  final String? authorTier;
  final bool authorIsKFoodMaster;
  final String content;
  final DateTime createdAt;

  const BoardComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorNickname,
    required this.authorUsername,
    required this.authorTier,
    required this.authorIsKFoodMaster,
    required this.content,
    required this.createdAt,
  });
}
