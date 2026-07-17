import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../models/battle_participant.dart';
import '../models/battle_vote.dart';

/// 배틀(1:1 비동기 요리 대결) 상태. battles/battle_participants/battle_votes 테이블과 동기화한다.
/// 실시간 매칭이 아니라 초대 링크 기반 비동기 대결이라, 상태 갱신은 자동 구독이 아니라
/// 화면에서 명시적으로 다시 불러오는 방식(pull-to-refresh 등)으로 처리한다.
class BattleStore extends ChangeNotifier {
  BattleStore._();
  static final BattleStore instance = BattleStore._();

  SupabaseClient get _client => Supabase.instance.client;

  Battle _mapBattle(Map<String, dynamic> row) => Battle(
        id: row['id'] as String,
        hostUserId: row['host_user_id'] as String,
        recipeId: row['recipe_id'] as String?,
        themeTitle: row['theme_title'] as String?,
        status: BattleStatusDb.fromDbValue(row['status'] as String),
        inviteLink: row['invite_link'] as String?,
        votingEndsAt: row['voting_ends_at'] == null
            ? null
            : DateTime.parse(row['voting_ends_at'] as String),
        winnerUserId: row['winner_user_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  BattleParticipant _mapParticipant(Map<String, dynamic> row) =>
      BattleParticipant(
        id: row['id'] as String,
        battleId: row['battle_id'] as String,
        userId: row['user_id'] as String,
        role: BattleParticipantRoleDb.fromDbValue(row['role'] as String),
        photoPath: row['photo_url'] as String?,
        submittedAt: row['submitted_at'] == null
            ? null
            : DateTime.parse(row['submitted_at'] as String),
        joinedAt: DateTime.parse(row['joined_at'] as String),
      );

  /// 배틀을 만들고, 호스트 본인을 첫 참가자(role=host)로 등록한다.
  Future<Battle> createBattle({String? recipeId, String? themeTitle}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');

    final row = await _client
        .from('battles')
        .insert({
          'host_user_id': uid,
          if (recipeId != null) 'recipe_id': recipeId,
          if (themeTitle != null) 'theme_title': themeTitle,
        })
        .select()
        .single();
    final battle = _mapBattle(row);

    await _client.from('battles').update({
      'invite_link': 'https://fridgechef.app/battle/${battle.id}',
    }).eq('id', battle.id);

    await _client.from('battle_participants').insert({
      'battle_id': battle.id,
      'user_id': uid,
      'role': 'host',
    });

    return fetchBattle(battle.id).then((b) => b!);
  }

  /// 딥링크나 배틀 목록에서 단건 조회. 없으면 null.
  Future<Battle?> fetchBattle(String id) async {
    final row =
        await _client.from('battles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return _mapBattle(row);
  }

  Future<List<BattleParticipant>> fetchParticipants(String battleId) async {
    final rows = await _client
        .from('battle_participants')
        .select()
        .eq('battle_id', battleId)
        .order('joined_at');
    return (rows as List)
        .map((r) => _mapParticipant(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<BattleVote>> fetchVotes(String battleId) async {
    final rows =
        await _client.from('battle_votes').select().eq('battle_id', battleId);
    return (rows as List)
        .map((r) => BattleVote(
              id: r['id'] as String,
              battleId: r['battle_id'] as String,
              voterId: r['voter_id'] as String,
              votedForParticipantId: r['voted_for_participant_id'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  /// 내가 호스트이거나 참가자로 들어가 있는 배틀 목록 — 배틀 화면의 "내 배틀" 목록용.
  Future<List<Battle>> fetchMyBattles() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final participantRows = await _client
        .from('battle_participants')
        .select('battle_id')
        .eq('user_id', uid);
    final battleIds =
        (participantRows as List).map((r) => r['battle_id'] as String).toSet();
    if (battleIds.isEmpty) return [];

    final rows = await _client
        .from('battles')
        .select()
        .inFilter('id', battleIds.toList())
        .order('created_at');
    return (rows as List)
        .map((r) => _mapBattle(r as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  /// 초대 링크로 들어온 상대가 참가한다 — 이미 opponent가 있으면 실패(DB unique 제약).
  Future<void> joinBattle(String battleId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');
    await _client.from('battle_participants').insert({
      'battle_id': battleId,
      'user_id': uid,
      'role': 'opponent',
    });
  }

  /// 완성 사진을 board-photos 버킷에 업로드한다 (게시판과 동일한 공개 버킷 재사용).
  Future<String> uploadBattlePhoto(Uint8List bytes,
      {required String fileExt}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');
    final path =
        '$uid/battle-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from('board-photos').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(contentType: 'image/$fileExt', upsert: false),
        );
    return _client.storage.from('board-photos').getPublicUrl(path);
  }

  /// 내 참가자 행에 완성 사진을 제출한다. 양쪽 다 제출을 마치면 배틀 상태를 voting으로 넘긴다.
  Future<void> submitPhoto(
      {required String battleId,
      required String participantId,
      required String photoUrl}) async {
    await _client.from('battle_participants').update({
      'photo_url': photoUrl,
      'submitted_at': DateTime.now().toIso8601String(),
    }).eq('id', participantId);

    final participants = await fetchParticipants(battleId);
    final bothSubmitted =
        participants.length == 2 && participants.every((p) => p.hasSubmitted);
    if (bothSubmitted) {
      await _client
          .from('battles')
          .update({'status': BattleStatus.voting.dbValue}).eq('id', battleId);
    }
  }

  /// 1인 1표 — 이미 투표했으면 대상만 바꾼다 (unique(battle_id, voter_id) 위에 upsert).
  Future<void> vote(
      {required String battleId, required String participantId}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');
    await _client.from('battle_votes').upsert(
      {
        'battle_id': battleId,
        'voter_id': uid,
        'voted_for_participant_id': participantId,
      },
      onConflict: 'battle_id,voter_id',
    );
  }

  /// 호스트가 투표를 마감하고 승자를 확정한다 — 득표수를 직접 세어 반영한다(동점이면 첫 참가자 승).
  Future<void> finalizeBattle(String battleId) async {
    final votes = await fetchVotes(battleId);
    final participants = await fetchParticipants(battleId);
    if (participants.isEmpty) return;

    final tally = <String, int>{for (final p in participants) p.id: 0};
    for (final v in votes) {
      tally[v.votedForParticipantId] =
          (tally[v.votedForParticipantId] ?? 0) + 1;
    }
    participants.sort((a, b) => (tally[b.id] ?? 0).compareTo(tally[a.id] ?? 0));
    final winner = participants.first;

    await _client.from('battles').update({
      'status': BattleStatus.completed.dbValue,
      'winner_user_id': winner.userId,
    }).eq('id', battleId);
  }

  /// 참가자 카드에 닉네임을 보여주기 위한 배치 조회 (users.id → nickname)
  Future<Map<String, String>> fetchNicknames(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('users')
        .select('id, nickname')
        .inFilter('id', userIds);
    return {
      for (final r in rows as List)
        r['id'] as String: r['nickname'] as String? ?? '냉장고 셰프'
    };
  }

  Future<void> cancelBattle(String battleId) async {
    await _client
        .from('battles')
        .update({'status': BattleStatus.cancelled.dbValue}).eq('id', battleId);
  }
}
