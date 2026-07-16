import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal_invite.dart';

/// 식사 초대장 상태. meal_invites 테이블과 동기화한다.
/// 초대장은 딥링크로 다른 계정(로그인 여부 무관)이 열어볼 수 있어야 하므로
/// select는 공개, insert만 본인으로 제한되어 있다 (supabase_schema.sql 참고).
class MealInviteStore {
  MealInviteStore._();
  static final MealInviteStore instance = MealInviteStore._();

  SupabaseClient get _client => Supabase.instance.client;

  /// 초대장을 생성해 meal_invites에 저장하고, 실제 저장된 id로 된 공유 링크를 포함해 반환한다.
  Future<MealInvite> createInvite({
    required String recipeTitle,
    required String message,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');

    final row = await _client
        .from('meal_invites')
        .insert({
          'host_user_id': uid,
          'recipe_title': recipeTitle,
          'message': message,
        })
        .select('id, recipe_title, message, created_at, users!meal_invites_host_user_id_fkey(nickname)')
        .single();

    final id = row['id'] as String;
    final userRow = row['users'] as Map<String, dynamic>?;
    return MealInvite(
      id: id,
      recipeTitle: row['recipe_title'] as String,
      message: row['message'] as String? ?? '',
      inviteLink: 'https://fridgechef.app/invite/$id',
      createdAt: DateTime.parse(row['created_at'] as String),
      hostNickname: userRow?['nickname'] as String? ?? '냉장고 셰프',
    );
  }

  /// 내가 만든 초대장 목록을 최신순으로 불러온다 (공유하기 화면의 "식사 초대장" 탭용)
  Future<List<MealInvite>> fetchMyInvites() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await _client
        .from('meal_invites')
        .select('id, recipe_title, message, created_at, users!meal_invites_host_user_id_fkey(nickname)')
        .eq('host_user_id', uid)
        .order('created_at');

    return (rows as List).map<MealInvite>((row) {
      final id = row['id'] as String;
      final userRow = row['users'] as Map<String, dynamic>?;
      return MealInvite(
        id: id,
        recipeTitle: row['recipe_title'] as String? ?? '',
        message: row['message'] as String? ?? '',
        inviteLink: 'https://fridgechef.app/invite/$id',
        createdAt: DateTime.parse(row['created_at'] as String),
        hostNickname: userRow?['nickname'] as String? ?? '냉장고 셰프',
      );
    }).toList().reversed.toList();
  }

  /// 딥링크로 들어온 초대장 id로 상세 정보를 조회한다. 없거나 삭제됐으면 null.
  Future<MealInvite?> fetchInvite(String id) async {
    final row = await _client
        .from('meal_invites')
        .select('id, recipe_title, message, created_at, users!meal_invites_host_user_id_fkey(nickname)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final userRow = row['users'] as Map<String, dynamic>?;
    return MealInvite(
      id: row['id'] as String,
      recipeTitle: row['recipe_title'] as String,
      message: row['message'] as String? ?? '',
      inviteLink: 'https://fridgechef.app/invite/$id',
      createdAt: DateTime.parse(row['created_at'] as String),
      hostNickname: userRow?['nickname'] as String? ?? '냉장고 셰프',
    );
  }
}
