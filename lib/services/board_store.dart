import 'package:flutter/foundation.dart';

import '../models/board_post.dart';
import 'chef_points_store.dart';
import 'profile_store.dart';

/// 게시판 상태 (싱글턴, 메모리에만 보관)
/// TODO: Supabase 연동 시 실제 board_posts 테이블 기반으로 교체
class BoardStore extends ChangeNotifier {
  BoardStore._() {
    _seedMockPosts();
  }
  static final BoardStore instance = BoardStore._();

  final List<BoardPost> _posts = [];

  void _seedMockPosts() {
    _posts.addAll([
      BoardPost(
        id: 'seed-1',
        category: BoardCategory.showoff,
        authorId: 'chef_kim',
        authorNickname: '집밥킴',
        authorTier: '중급요리사',
        authorIsKFoodMaster: false,
        title: '오늘 저녁은 두부김치찌개!',
        content: '냉장고 재료만으로 뚝딱 만들었어요. 다들 냉장고 파먹기 도전!',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      BoardPost(
        id: 'seed-2',
        category: BoardCategory.challenge,
        authorId: 'foodlover88',
        authorNickname: '맛잘알',
        authorTier: 'Food Master',
        authorIsKFoodMaster: true,
        title: 'K-Food 8종 완주 챌린지 시작합니다',
        content: '김치찌개부터 짜파구리까지 한 달 안에 다 만들어볼게요. 같이 하실 분?',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  List<BoardPost> postsFor(BoardCategory category) =>
      _posts.where((p) => p.category == category).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void addPost(BoardPost post) {
    _posts.insert(0, post);
    notifyListeners();
  }

  void toggleLike(String postId, String likerUserId) {
    final post = _posts.firstWhere((p) => p.id == postId);
    if (post.likedByUserIds.contains(likerUserId)) {
      post.likedByUserIds.remove(likerUserId);
    } else {
      post.likedByUserIds.add(likerUserId);
    }

    final newPointsAwarded = post.likeCount ~/ 10;
    final delta = newPointsAwarded - post.pointsAwarded;
    post.pointsAwarded = newPointsAwarded;
    if (delta > 0 && post.authorId == ProfileStore.instance.currentProfile?.id) {
      ChefPointsStore.instance.recordBoardLikeBonus(delta, post.title);
    }
    notifyListeners();
  }
}
