import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/board_comment.dart';
import '../models/board_post.dart';
import 'chef_points_store.dart';
import 'profile_store.dart';

/// 게시판 상태 (싱글턴). board_posts/board_post_likes 테이블과 동기화한다.
/// 좋아요 10개당 지급되는 포인트는 DB 트리거(handle_board_like_change)가 서버에서 처리한다.
class BoardStore extends ChangeNotifier {
  BoardStore._();
  static final BoardStore instance = BoardStore._();

  SupabaseClient get _client => Supabase.instance.client;

  List<BoardPost> _posts = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<BoardPost> postsFor(BoardCategory category) =>
      _posts.where((p) => p.category == category).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 상세 화면에서 좋아요 등 최신 상태를 반영하기 위해 id로 단건 조회한다
  BoardPost? findById(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 로그아웃 시 캐시를 비운다
  void clear() {
    _posts = [];
    _loaded = false;
    notifyListeners();
  }

  Future<void> loadPosts() async {
    final rows = await _client
        .from('board_posts')
        .select(
          'id, category, author_id, title, content, photo_url, created_at, '
          'users!board_posts_author_id_fkey(username, nickname), '
          'board_post_likes(user_id), '
          'board_comments(count)',
        )
        .order('created_at');
    final pointsByUser = await ChefPointsStore.fetchAllUserPoints();
    _posts = (rows as List).map<BoardPost>((row) {
      final authorId = row['author_id'] as String;
      final points = pointsByUser[authorId];
      final userRow = row['users'] as Map<String, dynamic>?;
      final likeRows = row['board_post_likes'] as List;
      final commentCountRows = row['board_comments'] as List?;
      final commentCount = (commentCountRows != null && commentCountRows.isNotEmpty)
          ? commentCountRows.first['count'] as int
          : 0;
      return BoardPost(
        id: row['id'] as String,
        category: BoardCategory.values.byName(row['category'] as String),
        authorId: authorId,
        authorUsername: userRow?['username'] as String? ?? authorId,
        authorNickname: userRow?['nickname'] as String? ?? '탈퇴한 사용자',
        authorTier: points == null ? null : ChefPointsStore.tierForPoints(points.general),
        authorIsKFoodMaster: (points?.kfood ?? 0) >= ChefPointsStore.kfoodMasterThreshold,
        title: row['title'] as String,
        content: row['content'] as String,
        photoPath: row['photo_url'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        likedByUserIds: {for (final l in likeRows) l['user_id'] as String},
        commentCount: commentCount,
      );
    }).toList();
    _loaded = true;
    notifyListeners();
  }

  /// 게시글 사진을 board-photos 버킷에 업로드하고 공개 URL을 반환한다.
  /// 버킷/정책은 supabase_schema.sql의 "Storage: board-photos 버킷" 섹션 참고.
  Future<String> uploadPhoto(Uint8List bytes, {required String fileExt}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('board-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: false),
        );
    return _client.storage.from('board-photos').getPublicUrl(path);
  }

  /// 게시글 작성 — photoPath는 Supabase Storage에 이미 업로드된 이미지의 URL이어야 한다.
  /// 생성된 게시글의 id를 반환한다 (챌린지 포인트 적립의 dedupe 키로 쓰기 위함).
  Future<String?> addPost({
    required BoardCategory category,
    required String title,
    required String content,
    String? photoPath,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('board_posts')
        .insert({
          'category': category.name,
          'author_id': uid,
          'title': title,
          'content': content,
          if (photoPath != null) 'photo_url': photoPath,
        })
        .select('id')
        .single();
    await loadPosts();
    return row['id'] as String;
  }

  /// 게시글 하나에 달린 댓글을 오래된 순으로 불러온다
  Future<List<BoardComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('board_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at');
    return (rows as List).map<BoardComment>((row) {
      return BoardComment(
        id: row['id'] as String,
        postId: row['post_id'] as String,
        authorId: row['author_id'] as String,
        authorNickname: row['author_nickname'] as String,
        authorUsername: row['author_username'] as String,
        authorTier: row['author_tier'] as String?,
        authorIsKFoodMaster: row['author_is_kfood_master'] as bool? ?? false,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  /// 댓글을 작성한다 — 작성자 닉네임/등급은 현재 시점 값을 그대로 저장한다(비정규화).
  /// 게시판 목록 카드의 댓글 수 표시도 최신으로 맞추기 위해 posts를 다시 불러온다.
  Future<void> addComment({required String postId, required String content}) async {
    final uid = _client.auth.currentUser?.id;
    final profile = ProfileStore.instance.currentProfile;
    if (uid == null || profile == null) throw StateError('로그인 후 이용해주세요');
    await _client.from('board_comments').insert({
      'post_id': postId,
      'author_id': uid,
      'author_nickname': profile.nickname,
      'author_username': profile.username,
      'author_tier': ChefPointsStore.instance.generalTier,
      'author_is_kfood_master': ChefPointsStore.instance.isKFoodMaster,
      'content': content,
    });
    await loadPosts();
  }

  /// 댓글을 삭제한다 — RLS 정책상 본인 댓글만 삭제 가능하다. addComment와 마찬가지로
  /// 목록 카드의 댓글 수를 맞추기 위해 posts를 다시 불러온다.
  Future<void> deleteComment(String commentId) async {
    await _client.from('board_comments').delete().eq('id', commentId);
    await loadPosts();
  }

  /// 게시글을 삭제한다 — RLS 정책상 본인 글만 삭제 가능하며, 좋아요/댓글은 DB에서 cascade로 함께 삭제된다.
  /// 첨부 사진이 있으면 board-photos 버킷에서도 함께 지운다(고아 파일 방지).
  Future<void> deletePost(String postId) async {
    final photoUrl = findById(postId)?.photoPath;
    await _client.from('board_posts').delete().eq('id', postId);
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
    if (photoUrl != null) {
      const marker = '/board-photos/';
      final idx = photoUrl.indexOf(marker);
      if (idx != -1) {
        final storagePath = photoUrl.substring(idx + marker.length);
        try {
          await _client.storage.from('board-photos').remove([storagePath]);
        } catch (_) {
          // DB 행 삭제는 이미 끝났으므로 스토리지 정리 실패는 조용히 무시한다
        }
      }
    }
  }

  Future<void> toggleLike(String postId, String likerUserId) async {
    final post = _posts.firstWhere((p) => p.id == postId);
    if (post.likedByUserIds.contains(likerUserId)) {
      await _client.from('board_post_likes').delete().match({'post_id': postId, 'user_id': likerUserId});
    } else {
      await _client.from('board_post_likes').insert({'post_id': postId, 'user_id': likerUserId});
    }
    await loadPosts();
  }
}
