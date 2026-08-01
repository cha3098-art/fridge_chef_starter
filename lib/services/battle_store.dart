import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';
import '../models/battle.dart';
import '../models/battle_list_item.dart';
import '../models/battle_participant.dart';
import '../models/battle_vote.dart';

/// 배틀(1:1 요리 대결) 상태. battles/battle_participants/battle_votes 테이블과 동기화한다.
/// 초대 링크 기반 비동기 대결의 상태 갱신은 화면에서 명시적으로 다시 불러오는 방식
/// (pull-to-refresh 등)으로 처리한다. battle_queue를 통한 빠른 매칭만 realtime으로
/// 구독한다(watchMatchedBattleId) — 매칭 자체는 DB 트리거가 원자적으로 처리한다.
class BattleStore extends ChangeNotifier {
  BattleStore._();
  static final BattleStore instance = BattleStore._();

  SupabaseClient get _client => Supabase.instance.client;

  /// 상대에게 영향을 주는 행동을 마친 직후 호출 — supabase/functions/send-push가
  /// device_tokens를 조회해서 실제 FCM 푸시를 보낸다. 발신자 본인에게는 함수가 알아서 걸러준다.
  /// 실패해도(오프라인, 함수 미배포 등) 방금 완료된 실제 배틀 행동 자체를 되돌리면 안 되므로 조용히 무시한다.
  Future<void> _notify({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _client.functions.invoke('send-push', body: {
        'userIds': userIds,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      });
    } catch (e) {
      debugPrint('BattleStore._notify failed: $e');
    }
  }

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
        submissionDeadline: row['submission_deadline'] == null
            ? null
            : DateTime.parse(row['submission_deadline'] as String),
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
        comment: row['comment'] as String?,
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

    // 상태를 submitted로 넘기고 3시간 제출 타이머를 시작한다. 이 호출은 상대(호스트가
    // 아닌 쪽)가 하므로, "호스트만 배틀 정보 수정" RLS를 우회하는 RPC로 처리한다.
    await _client
        .rpc('mark_battle_submitted', params: {'target_battle_id': battleId});

    final battle = await fetchBattle(battleId);
    if (battle != null) {
      await _notify(
        userIds: [battle.hostUserId],
        title: tr('상대가 배틀에 참가했어요', 'Someone joined your battle'),
        body: tr('완성 사진을 제출해보세요!', 'Time to submit your finished dish!'),
        data: {'battleId': battleId},
      );
    }
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

  /// 내 참가자 행에 완성 사진(+선택적으로 한마디)을 제출한다. 양쪽 다 제출을 마치면
  /// 배틀 상태를 voting으로 넘긴다.
  Future<void> submitPhoto(
      {required String battleId,
      required String participantId,
      required String photoUrl,
      String? comment}) async {
    final trimmedComment = comment?.trim();
    await _client.from('battle_participants').update({
      'photo_url': photoUrl,
      'comment': (trimmedComment == null || trimmedComment.isEmpty)
          ? null
          : trimmedComment,
      'submitted_at': DateTime.now().toIso8601String(),
    }).eq('id', participantId);

    final participants = await fetchParticipants(battleId);
    final bothSubmitted =
        participants.length == 2 && participants.every((p) => p.hasSubmitted);
    if (bothSubmitted) {
      await _client.from('battles').update({
        'status': BattleStatus.voting.dbValue,
        // 2일 뒤 close-expired-battles Edge Function이 자동으로 마감하고 승자를 확정한다
        // (호스트가 "투표 마감" 버튼을 직접 안 눌러도 배틀이 무기한 방치되지 않는다).
        'voting_ends_at':
            DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      }).eq('id', battleId);
      await _notify(
        userIds: participants.map((p) => p.userId).toList(),
        title: tr('투표가 시작됐어요', 'Voting has started'),
        body: tr('양쪽 다 사진을 제출해서 투표를 받을 수 있어요!',
            'Both dishes are in — go get some votes!'),
        data: {'battleId': battleId},
      );
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

    await _notify(
      userIds: participants.map((p) => p.userId).toList(),
      title: tr('배틀이 종료됐어요', 'The battle is over'),
      body: tr('결과를 확인해보세요!', 'Check out the result!'),
      data: {'battleId': battleId},
    );
  }

  /// battles 목록을 호스트/챌린저 닉네임 + 득표수 + 내 참가/투표 상태까지 채운
  /// BattleListItem으로 변환한다 — 내 배틀 목록, 전체 배틀 목록, 대시보드 티커가 공유한다.
  Future<List<BattleListItem>> _buildListItems(List<Battle> battles) async {
    if (battles.isEmpty) return [];
    final uid = _client.auth.currentUser?.id;

    final battleIds = battles.map((b) => b.id).toList();
    final participantRows = await _client
        .from('battle_participants')
        .select()
        .inFilter('battle_id', battleIds);
    final participants = (participantRows as List)
        .map((r) => _mapParticipant(r as Map<String, dynamic>))
        .toList();

    final userIds = participants.map((p) => p.userId).toSet().toList();
    final nicknames = await fetchNicknames(userIds);
    final genders = await fetchGenders(userIds);

    final voteRows = await _client
        .from('battle_votes')
        .select()
        .inFilter('battle_id', battleIds);
    final votes = (voteRows as List)
        .map((r) => BattleVote(
              id: r['id'] as String,
              battleId: r['battle_id'] as String,
              voterId: r['voter_id'] as String,
              votedForParticipantId: r['voted_for_participant_id'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();

    return battles.map((battle) {
      final parts = participants.where((p) => p.battleId == battle.id).toList();
      final host = parts
          .where((p) => p.role == BattleParticipantRole.host)
          .firstOrNull;
      final challenger = parts
          .where((p) => p.role == BattleParticipantRole.opponent)
          .firstOrNull;
      final battleVotes = votes.where((v) => v.battleId == battle.id).toList();
      final myParticipant = parts.where((p) => p.userId == uid).firstOrNull;
      final myVote = battleVotes
          .where((v) => v.voterId == uid)
          .map((v) => v.votedForParticipantId)
          .firstOrNull;

      return BattleListItem(
        battle: battle,
        hostNickname:
            host == null ? '?' : (nicknames[host.userId] ?? tr('냉장고 셰프', 'Chef')),
        hostParticipantId: host?.id,
        hostVotes: host == null
            ? 0
            : battleVotes.where((v) => v.votedForParticipantId == host.id).length,
        hostGender: host == null ? null : genders[host.userId],
        challengerNickname: challenger == null
            ? null
            : (nicknames[challenger.userId] ?? tr('냉장고 셰프', 'Chef')),
        challengerParticipantId: challenger?.id,
        challengerUserId: challenger?.userId,
        challengerVotes: challenger == null
            ? 0
            : battleVotes
                .where((v) => v.votedForParticipantId == challenger.id)
                .length,
        challengerGender:
            challenger == null ? null : genders[challenger.userId],
        myParticipantId: myParticipant?.id,
        myVoteParticipantId: myVote,
      );
    }).toList();
  }

  /// 내 배틀 목록에 호스트/챌린저 닉네임 + 득표수까지 미리 포함한다 — 배틀 목록 화면의 VS 카드용.
  Future<List<BattleListItem>> fetchMyBattleItems() async {
    final battles = await fetchMyBattles();
    return _buildListItems(battles);
  }

  /// 진행 중인 모든 배틀(호스트/상대 무관) — 누구나 둘러보다 참여하거나 관객으로 투표할 수 있는
  /// 공개 배틀 목록용. battles 테이블 SELECT는 전체 공개라 참여 여부와 무관하게 조회된다.
  /// 종료(completed)된 배틀도 목록에서 사라지지 않고 최신순으로 계속 보이되, 진행 중인 배틀
  /// 아래로 밀려나도록 두 그룹을 따로 불러와 이어붙인다 — 보관 개수(최대 10건) 자체는
  /// close-expired-battles가 서버에서 오래된 것부터 정리한다.
  Future<List<BattleListItem>> fetchOpenBattleItems(
      {int activeLimit = 50, int completedLimit = 10}) async {
    final activeRows = await _client
        .from('battles')
        .select()
        .inFilter('status', ['waiting_opponent', 'submitted', 'voting'])
        .order('created_at', ascending: false)
        .limit(activeLimit);
    final completedRows = await _client
        .from('battles')
        .select()
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(completedLimit);
    final battles = [
      ...(activeRows as List).map((r) => _mapBattle(r as Map<String, dynamic>)),
      ...(completedRows as List).map((r) => _mapBattle(r as Map<String, dynamic>)),
    ];
    return _buildListItems(battles);
  }

  /// 메인 대시보드 라이브 티커용 — submitted/voting 상태인 배틀 최근 N건
  Future<List<BattleListItem>> fetchActiveBattleItems({int limit = 6}) async {
    try {
      // 상대를 기다리는 중인 배틀도 "진행 중" 배너에 포함한다 — 방금 만든 배틀이
      // 매칭 전이라는 이유로 대시보드 배너에서 사라져 보이면 안 되기 때문이다.
      final rows = await _client
          .from('battles')
          .select()
          .inFilter('status', ['waiting_opponent', 'submitted', 'voting'])
          .order('created_at', ascending: false)
          .limit(limit);
      final battles = (rows as List)
          .map((r) => _mapBattle(r as Map<String, dynamic>))
          .toList();
      return _buildListItems(battles);
    } catch (e) {
      debugPrint('BattleStore.fetchActiveBattleItems failed: $e');
      return [];
    }
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

  /// 배틀 카드에 성별 맞춤 마스코트 아바타를 고르기 위한 배치 조회 (users.id → gender).
  /// hide_gender가 켜져 있으면 본인이 비공개로 설정한 값이라 null로 가려서 돌려준다
  /// (아바타 선택도 랜덤 폴백으로 처리됨 — profile_view_sheet.dart와 동일한 원칙).
  Future<Map<String, String?>> fetchGenders(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('users')
        .select('id, gender, hide_gender')
        .inFilter('id', userIds);
    return {
      for (final r in rows as List)
        r['id'] as String: (r['hide_gender'] as bool? ?? false)
            ? null
            : r['gender'] as String?
    };
  }

  /// 참가자 본인(호스트든 상대든)이 배틀을 포기/취소한다. RLS상 battles UPDATE는
  /// 호스트 전용이라(테마·레시피 등은 호스트만 고쳐야 하므로), 참가자 본인 확인만 하는
  /// cancel_battle RPC로 우회한다. 이미 투표 단계 이후면 서버에서 조용히 무시된다.
  Future<void> cancelBattle(String battleId) async {
    final uid = _client.auth.currentUser?.id;
    final participants = await fetchParticipants(battleId);
    await _client
        .rpc('cancel_battle', params: {'target_battle_id': battleId});

    final others =
        participants.map((p) => p.userId).where((id) => id != uid).toList();
    if (others.isNotEmpty) {
      await _notify(
        userIds: others,
        title: tr('상대가 배틀을 취소했어요', 'The battle was cancelled'),
        body: tr('상대방이 배틀을 포기해서 이 배틀은 취소됐어요',
            'Your opponent gave up, so this battle has been cancelled'),
        data: {'battleId': battleId},
      );
    }
  }

  /// 빠른 매칭 대기열에 들어간다. 이미 대기 중이던 행이 있으면(예: 이전 세션이 취소 없이
  /// 끊긴 경우) 지우고 새로 넣어야 INSERT 트리거(handle_battle_queue_insert)가 반드시
  /// 다시 실행된다 — upsert로 기존 행을 UPDATE하면 트리거가 안 걸린다.
  Future<void> joinQueue() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');
    await _client.from('battle_queue').delete().eq('user_id', uid);
    await _client.from('battle_queue').insert({'user_id': uid});
  }

  /// 매칭 대기를 취소한다. 이미 매칭이 잡힌 뒤에는(상대와 배틀이 생성된 뒤) 호출해도 무해하다.
  /// 화면 dispose·뒤로가기 등 여러 경로에서 호출되는 정리용 작업이라, 실패해도
  /// (네트워크 문제 등) 사용자가 화면을 벗어나는 흐름 자체를 막지 않도록 조용히 무시한다.
  Future<void> leaveQueue() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('battle_queue').delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('BattleStore.leaveQueue failed: $e');
    }
  }

  /// 본인 대기열 행의 matched_battle_id 변화를 실시간 구독한다.
  /// 상대가 매칭되면(트리거가 갱신) 배틀 id를 흘려보내고, 대기열에서 빠지면 null을 흘려보낸다.
  Stream<String?> watchMatchedBattleId() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(null);
    return _client
        .from('battle_queue')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .map((rows) =>
            rows.isEmpty ? null : rows.first['matched_battle_id'] as String?);
  }
}
