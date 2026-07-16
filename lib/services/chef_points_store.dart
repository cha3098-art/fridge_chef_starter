import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';
import '../models/chef_points.dart';

/// 앱 전체에서 공유하는 요리 포인트 상태 (싱글턴). chef_point_events 테이블과 동기화한다.
/// 게시판 좋아요 보너스는 DB 트리거(handle_board_like_change)가 서버에서 대신 적립해준다.
class ChefPointsStore extends ChangeNotifier {
  ChefPointsStore._();
  static final ChefPointsStore instance = ChefPointsStore._();

  SupabaseClient get _client => Supabase.instance.client;

  List<PointEvent> _events = [];
  bool _loaded = false;
  DateTime? _lastWeeklyMissionAt;

  List<PointEvent> get events => List.unmodifiable(_events.reversed);
  bool get isLoaded => _loaded;

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
    return _events.where((e) => e.reason == PointReason.cook && e.timestamp.isAfter(weekAgo)).length;
  }

  bool get invitedThisWeek {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _events.any((e) => e.reason == PointReason.kfoodInviteBonus && e.timestamp.isAfter(weekAgo));
  }

  /// 로그아웃 시 캐시를 비운다
  void clear() {
    _events = [];
    _loaded = false;
    _lastWeeklyMissionAt = null;
    notifyListeners();
  }

  Future<void> loadEvents() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _events = [];
      _loaded = true;
      notifyListeners();
      return;
    }
    final rows = await _client
        .from('chef_point_events')
        .select()
        .eq('user_id', uid)
        .order('created_at');
    _events = (rows as List).map<PointEvent>((row) => PointEvent(
          reason: PointReason.values.byName(row['reason'] as String),
          amount: row['amount'] as int,
          isKFoodTrack: row['is_kfood_track'] as bool,
          labelKo: row['label_ko'] as String,
          labelEn: row['label_en'] as String,
          timestamp: DateTime.parse(row['created_at'] as String),
        )).toList();
    _lastWeeklyMissionAt = _events
        .where((e) => e.reason == PointReason.weeklyMission)
        .map((e) => e.timestamp)
        .fold<DateTime?>(null, (latest, t) => latest == null || t.isAfter(latest) ? t : latest);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _add(
    PointReason reason,
    int amount,
    bool isKFoodTrack,
    String labelKo,
    String labelEn, {
    String? dedupeKey,
  }) async {
    if (amount <= 0) return;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final row = {
      'user_id': uid,
      'reason': reason.name,
      'amount': amount,
      'is_kfood_track': isKFoodTrack,
      'label_ko': labelKo,
      'label_en': labelEn,
      'dedupe_key': dedupeKey,
    };
    try {
      if (dedupeKey != null) {
        await _client.from('chef_point_events').upsert(
              row,
              onConflict: 'user_id,dedupe_key',
              ignoreDuplicates: true,
            );
      } else {
        await _client.from('chef_point_events').insert(row);
      }
      await loadEvents();
    } catch (e) {
      debugPrint('ChefPointsStore._add failed (reason=${reason.name}): $e');
      // 게이미피케이션 보너스라 실패해도 조용히 무시한다 (재시도 없음)
    }
  }

  /// 냉장고에 재료를 처음 등록했을 때 1회 한정 보너스
  Future<void> recordFirstIngredientIfNeeded() {
    return _add(
      PointReason.firstIngredient,
      1,
      false,
      '냉장고에 첫 재료 등록',
      'First fridge item added',
      dedupeKey: 'first_ingredient',
    );
  }

  /// 요리 완성(자랑하기) 시 호출 — 난이도 가중치 + 보너스들을 한 번에 계산한다
  Future<void> recordCook({
    required String recipeTitle,
    required String difficulty,
    required bool isKFood,
    required bool isFullFridgeMatch,
  }) async {
    final weight = difficultyWeight(difficulty);
    final difficultyEn = trTag(difficulty);
    await _add(
      PointReason.cook,
      weight,
      false,
      '$recipeTitle 완성 (난이도 $difficulty · +$weight)',
      '$recipeTitle done (Level $difficultyEn · +$weight)',
    );

    if (isKFood) {
      await _add(
        PointReason.kfoodCook,
        weight,
        true,
        '$recipeTitle K-Food 완성 (+$weight)',
        '$recipeTitle K-Food done (+$weight)',
      );
    }
    if (isFullFridgeMatch) {
      await _add(PointReason.fullMatchCook, 1, false, '냉장고 재료만으로 완성 보너스', 'Fridge-only completion bonus');
    }
    await _add(
      PointReason.firstTry,
      1,
      false,
      '$recipeTitle 첫 도전 보너스',
      '$recipeTitle first-try bonus',
      dedupeKey: 'first_try:$recipeTitle',
    );
    await _maybeAwardWeeklyMission();
  }

  /// 챌린지 게시판에 요리 완성 인증을 올렸을 때 호출 — 게시글당 1회, 고정 포인트
  /// (challenge_post:$postId로 중복 적립을 막는다)
  Future<void> recordChallengePost({required String postId, required String title}) async {
    await _add(
      PointReason.challengePost,
      2,
      false,
      '"$title" 챌린지 인증 완료 (+2)',
      '"$title" challenge verified (+2)',
      dedupeKey: 'challenge_post:$postId',
    );
    await _maybeAwardWeeklyMission();
  }

  /// 초대장 발송 시 호출 — K-Food 레시피면 난이도 가중치의 2배 보너스
  Future<void> recordInvite({required String recipeTitle, required String difficulty, required bool isKFood}) async {
    if (isKFood) {
      final weight = difficultyWeight(difficulty) * 2;
      await _add(
        PointReason.kfoodInviteBonus,
        weight,
        true,
        '$recipeTitle K-Food 초대 보너스 2배 (+$weight)',
        '$recipeTitle K-Food invite bonus 2x (+$weight)',
      );
    }
    await _maybeAwardWeeklyMission();
  }

  Future<void> _maybeAwardWeeklyMission() async {
    final now = DateTime.now();
    if (_lastWeeklyMissionAt != null && now.difference(_lastWeeklyMissionAt!) < const Duration(days: 7)) {
      return;
    }
    if (cooksThisWeek >= 3 && invitedThisWeek) {
      _lastWeeklyMissionAt = now;
      await _add(
        PointReason.weeklyMission,
        1,
        false,
        '주간 미션 달성 (7일간 요리 3회 + 초대 이용)',
        'Weekly mission complete (3 cooks + Inbox use in 7 days)',
      );
    }
  }

  /// 랭킹/게시판에서 다른 사용자의 등급·배지를 보여주기 위한 전체 포인트 배치 조회
  /// (일반 포인트, K-Food 포인트를 user_id별로 합산해서 반환)
  static Future<Map<String, ({int general, int kfood})>> fetchAllUserPoints() async {
    final rows = await Supabase.instance.client
        .from('chef_point_events')
        .select('user_id, amount, is_kfood_track');
    final totals = <String, (int, int)>{};
    for (final row in rows as List) {
      final userId = row['user_id'] as String;
      final amount = row['amount'] as int;
      final isKFood = row['is_kfood_track'] as bool;
      final current = totals[userId] ?? (0, 0);
      totals[userId] = isKFood ? (current.$1, current.$2 + amount) : (current.$1 + amount, current.$2);
    }
    return totals.map((userId, t) => MapEntry(userId, (general: t.$1, kfood: t.$2)));
  }
}
