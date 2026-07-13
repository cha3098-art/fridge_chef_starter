import 'package:flutter/foundation.dart';

import '../l10n/tr.dart';
import '../models/chef_points.dart';

/// 앱 전체에서 공유하는 요리 포인트 상태 (싱글턴, 메모리에만 보관)
/// TODO: Supabase 연동 시 user_recipe_history/meal_invites 기반으로 서버 집계하도록 교체
class ChefPointsStore extends ChangeNotifier {
  ChefPointsStore._();
  static final ChefPointsStore instance = ChefPointsStore._();

  final List<PointEvent> _events = [];
  final List<DateTime> _cookTimestamps = [];
  final List<DateTime> _inviteTimestamps = [];
  final Set<String> _triedRecipeTitles = {};
  bool _firstIngredientAwarded = false;
  DateTime? _lastWeeklyMissionAt;

  List<PointEvent> get events => List.unmodifiable(_events.reversed);

  int get generalPoints =>
      _events.where((e) => !e.isKFoodTrack).fold(0, (sum, e) => sum + e.amount);

  int get kfoodPoints => _events.where((e) => e.isKFoodTrack).fold(0, (sum, e) => sum + e.amount);

  static const generalTierThresholds = {30: '초급요리사', 40: '중급요리사', 50: 'Food Master'};
  static const kfoodMasterThreshold = 50;

  String? get generalTier => tierForPoints(generalPoints);

  static String? tierForPoints(int points) {
    String? tier;
    for (final entry in generalTierThresholds.entries) {
      if (points >= entry.key) tier = entry.value;
    }
    return tier;
  }

  /// 다음 등급까지 남은 포인트 (이미 최고 등급이면 null)
  int? get pointsToNextTier {
    final points = generalPoints;
    final remaining = generalTierThresholds.keys
        .where((threshold) => points < threshold)
        .toList()
      ..sort();
    return remaining.isEmpty ? null : remaining.first - points;
  }

  bool get isKFoodMaster => kfoodPoints >= kfoodMasterThreshold;

  int get cooksThisWeek {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _cookTimestamps.where((t) => t.isAfter(weekAgo)).length;
  }

  bool get invitedThisWeek {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _inviteTimestamps.any((t) => t.isAfter(weekAgo));
  }

  void _add(PointReason reason, int amount, bool isKFoodTrack, String labelKo, String labelEn) {
    if (amount <= 0) return;
    _events.add(PointEvent(
      reason: reason,
      amount: amount,
      isKFoodTrack: isKFoodTrack,
      labelKo: labelKo,
      labelEn: labelEn,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// 냉장고에 재료를 처음 등록했을 때 1회 한정 보너스
  void recordFirstIngredientIfNeeded() {
    if (_firstIngredientAwarded) return;
    _firstIngredientAwarded = true;
    _add(PointReason.firstIngredient, 1, false, '냉장고에 첫 재료 등록', 'First fridge item added');
  }

  /// 요리 완성(자랑하기) 시 호출 — 난이도 가중치 + 보너스들을 한 번에 계산한다
  void recordCook({
    required String recipeTitle,
    required String difficulty,
    required bool isKFood,
    required bool isFullFridgeMatch,
  }) {
    final weight = difficultyWeight(difficulty);
    final difficultyEn = trTag(difficulty);
    _cookTimestamps.add(DateTime.now());
    _add(
      PointReason.cook,
      weight,
      false,
      '$recipeTitle 완성 (난이도 $difficulty · +$weight)',
      '$recipeTitle done (Level $difficultyEn · +$weight)',
    );

    if (isKFood) {
      _add(
        PointReason.kfoodCook,
        weight,
        true,
        '$recipeTitle K-Food 완성 (+$weight)',
        '$recipeTitle K-Food done (+$weight)',
      );
    }
    if (isFullFridgeMatch) {
      _add(PointReason.fullMatchCook, 1, false, '냉장고 재료만으로 완성 보너스', 'Fridge-only completion bonus');
    }
    if (!_triedRecipeTitles.contains(recipeTitle)) {
      _triedRecipeTitles.add(recipeTitle);
      _add(PointReason.firstTry, 1, false, '$recipeTitle 첫 도전 보너스', '$recipeTitle first-try bonus');
    }
    _maybeAwardWeeklyMission();
  }

  /// 게시판 글이 좋아요 10개를 새로 넘길 때마다 호출 — amount는 새로 넘긴 만큼의 점수
  void recordBoardLikeBonus(int amount, String postTitle) {
    _add(
      PointReason.boardLikes,
      amount,
      false,
      '"$postTitle" 게시글 좋아요 보너스',
      '"$postTitle" post like bonus',
    );
  }

  /// 초대장 발송 시 호출 — K-Food 레시피면 난이도 가중치의 2배 보너스
  void recordInvite({required String recipeTitle, required String difficulty, required bool isKFood}) {
    _inviteTimestamps.add(DateTime.now());
    if (isKFood) {
      final weight = difficultyWeight(difficulty) * 2;
      _add(
        PointReason.kfoodInviteBonus,
        weight,
        true,
        '$recipeTitle K-Food 초대 보너스 2배 (+$weight)',
        '$recipeTitle K-Food invite bonus 2x (+$weight)',
      );
    }
    _maybeAwardWeeklyMission();
  }

  void _maybeAwardWeeklyMission() {
    final now = DateTime.now();
    if (_lastWeeklyMissionAt != null && now.difference(_lastWeeklyMissionAt!) < const Duration(days: 7)) {
      return;
    }
    if (cooksThisWeek >= 3 && invitedThisWeek) {
      _lastWeeklyMissionAt = now;
      _add(
        PointReason.weeklyMission,
        1,
        false,
        '주간 미션 달성 (7일간 요리 3회 + 초대 이용)',
        'Weekly mission complete (3 cooks + Inbox use in 7 days)',
      );
    }
  }
}
