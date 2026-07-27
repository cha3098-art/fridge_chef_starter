// close-expired-battles
//
// pg_cron이 5분마다 호출하는 서버 타이머. 배틀이 어느 단계에서든 무기한 방치되지 않도록
// 네 가지 정리를 여기서 함께 처리한다:
//   1) voting_ends_at이 지난 배틀(투표 시작 후 2일) — 득표수를 세어 승자를 확정한다
//   2) submission_deadline이 지난 배틀(status=submitted) — 한쪽만 제출했으면 부전승,
//      아무도 제출 안 했으면 취소 처리한다
//   3) 초대 링크 배틀에 상대가 24시간 넘게 안 들어온 경우(status=waiting_opponent) — 매칭이
//      끝내 안 된 것이므로 취소가 아니라 완전히 삭제한다(참가자/투표는 FK cascade로 함께 삭제됨)
//   4) 종료(completed)된 배틀이 전체 10건을 넘으면, 오래된 것부터 초과분을 삭제한다
//      — "전체 배틀" 목록에 끝난 배틀이 무한히 쌓이지 않도록 하는 보관 개수 제한
// 특정 사용자 세션이 아니라 크론이 호출하므로, service role 키로 RLS를 우회해서 전체를 조회한다.
//
// 배포: supabase functions deploy close-expired-battles --no-verify-jwt
//   (--no-verify-jwt: pg_cron 호출은 사용자 로그인 세션이 아니라 아래 CRON_SECRET 헤더로 인증한다)
// 시크릿: supabase secrets set CRON_SECRET=<임의의 긴 무작위 문자열>
// 스케줄 등록은 supabase_schema.sql의 "18. pg_cron" 섹션 참고 (net.http_post로 이 함수를 호출).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { getAccessToken, sendToToken, type ServiceAccount } from '../_shared/fcm.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
const CRON_SECRET = Deno.env.get('CRON_SECRET');

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

interface ParticipantRow {
  id: string;
  user_id: string;
  photo_url: string | null;
}

Deno.serve(async (req) => {
  if (!CRON_SECRET || req.headers.get('Authorization') !== `Bearer ${CRON_SECRET}`) {
    return jsonResponse({ error: '인증되지 않은 호출입니다' }, 401);
  }

  const client = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const now = new Date().toISOString();

  let account: ServiceAccount | null = null;
  if (SERVICE_ACCOUNT_JSON) {
    try {
      account = JSON.parse(SERVICE_ACCOUNT_JSON);
    } catch {
      console.error('[close-expired-battles] FIREBASE_SERVICE_ACCOUNT이 유효한 JSON이 아닙니다');
    }
  }
  const accessToken = account ? await getAccessToken(account).catch((e) => {
    console.error('[close-expired-battles] FCM 액세스 토큰 발급 실패:', e);
    return null;
  }) : null;

  async function notifyUsers(
    userIds: string[],
    title: string,
    body: string,
    battleId: string,
  ) {
    if (!account || !accessToken || userIds.length === 0) return;
    const { data: tokenRows } = await client
      .from('device_tokens')
      .select('token')
      .in('user_id', userIds);
    const tokens = (tokenRows ?? []).map((r) => r.token as string);
    await Promise.all(
      tokens.map((t) => sendToToken(accessToken, account!.project_id, t, title, body, { battleId })),
    );
  }

  // 1) 투표 마감 — 득표수를 세어 승자를 확정한다.
  let votingClosed = 0;
  {
    const { data: expiredBattles, error: fetchError } = await client
      .from('battles')
      .select('id')
      .eq('status', 'voting')
      .lt('voting_ends_at', now);
    if (fetchError) {
      console.error('[close-expired-battles] voting 배틀 조회 실패:', fetchError);
    }
    for (const battle of expiredBattles ?? []) {
      const battleId = battle.id as string;

      const [{ data: participants }, { data: votes }] = await Promise.all([
        client.from('battle_participants').select('id, user_id, photo_url').eq('battle_id', battleId),
        client.from('battle_votes').select('voted_for_participant_id').eq('battle_id', battleId),
      ]);
      const participantRows = (participants ?? []) as ParticipantRow[];
      if (participantRows.length === 0) continue;

      const tally = new Map<string, number>(participantRows.map((p) => [p.id, 0]));
      for (const v of votes ?? []) {
        const key = v.voted_for_participant_id as string;
        tally.set(key, (tally.get(key) ?? 0) + 1);
      }
      const winner = [...participantRows].sort(
        (a, b) => (tally.get(b.id) ?? 0) - (tally.get(a.id) ?? 0),
      )[0];

      const { error: updateError } = await client
        .from('battles')
        .update({ status: 'completed', winner_user_id: winner.user_id })
        .eq('id', battleId);
      if (updateError) {
        console.error(`[close-expired-battles] battle ${battleId} 업데이트 실패:`, updateError);
        continue;
      }
      votingClosed++;
      await notifyUsers(
        participantRows.map((p) => p.user_id),
        '배틀 투표가 마감됐어요',
        '결과를 확인해보세요!',
        battleId,
      );
    }
  }

  // 2) 제출 마감(3시간) — 한쪽만 냈으면 부전승, 아무도 안 냈으면 취소.
  // (양쪽 다 냈는데 어떤 이유로 status가 아직 submitted로 남아있다면, 정상 흐름대로
  //  voting으로 넘겨준다 — submitPhoto()가 실패했거나 놓친 경우에 대한 안전망.)
  let submissionResolved = 0;
  {
    const { data: staleSubmissions, error: fetchError } = await client
      .from('battles')
      .select('id')
      .eq('status', 'submitted')
      .lt('submission_deadline', now);
    if (fetchError) {
      console.error('[close-expired-battles] submitted 배틀 조회 실패:', fetchError);
    }
    for (const battle of staleSubmissions ?? []) {
      const battleId = battle.id as string;
      const { data: participants } = await client
        .from('battle_participants')
        .select('id, user_id, photo_url')
        .eq('battle_id', battleId);
      const participantRows = (participants ?? []) as ParticipantRow[];
      if (participantRows.length !== 2) continue;

      const submitted = participantRows.filter((p) => p.photo_url != null);
      const notSubmitted = participantRows.filter((p) => p.photo_url == null);

      if (submitted.length === 2) {
        await client.from('battles').update({
          status: 'voting',
          voting_ends_at: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
        }).eq('id', battleId);
        submissionResolved++;
      } else if (submitted.length === 1) {
        const winner = submitted[0];
        const loser = notSubmitted[0];
        const { error: updateError } = await client
          .from('battles')
          .update({ status: 'completed', winner_user_id: winner.user_id })
          .eq('id', battleId);
        if (updateError) {
          console.error(`[close-expired-battles] battle ${battleId} 부전승 처리 실패:`, updateError);
          continue;
        }
        submissionResolved++;
        await notifyUsers([winner.user_id], '상대가 기권했어요',
          '제한 시간 안에 상대가 사진을 제출하지 않아 부전승으로 이겼어요!', battleId);
        await notifyUsers([loser.user_id], '배틀에서 기권 처리됐어요',
          '제출 시간이 지나 이 배틀은 기권 처리됐어요', battleId);
      } else {
        const { error: updateError } = await client
          .from('battles')
          .update({ status: 'cancelled' })
          .eq('id', battleId);
        if (updateError) {
          console.error(`[close-expired-battles] battle ${battleId} 취소 처리 실패:`, updateError);
          continue;
        }
        submissionResolved++;
        await notifyUsers(participantRows.map((p) => p.user_id), '배틀이 취소됐어요',
          '양쪽 다 제한 시간 안에 사진을 제출하지 않아 배틀이 자동으로 취소됐어요', battleId);
      }
    }
  }

  // 3) 초대 링크 방치(24시간) — 상대가 끝내 안 들어오면 매칭 자체가 성립 안 된 것이므로
  // 완전히 삭제한다(취소 상태로 남겨두지 않음 — 참가자 행은 host 하나뿐이라 cascade로 함께 지워진다).
  let staleInvitesDeleted = 0;
  {
    const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { data: staleInvites, error: fetchError } = await client
      .from('battles')
      .select('id, host_user_id')
      .eq('status', 'waiting_opponent')
      .lt('created_at', dayAgo);
    if (fetchError) {
      console.error('[close-expired-battles] waiting_opponent 배틀 조회 실패:', fetchError);
    }
    for (const battle of staleInvites ?? []) {
      const battleId = battle.id as string;
      // 알림은 삭제 전에 먼저 보낸다 — battleId를 가리키는 알림은 삭제 후에는 무의미하다.
      await notifyUsers([battle.host_user_id as string], '초대가 만료됐어요',
        '상대가 응답하지 않아 배틀이 자동으로 삭제됐어요', battleId);
      const { error: deleteError } = await client.from('battles').delete().eq('id', battleId);
      if (deleteError) {
        console.error(`[close-expired-battles] battle ${battleId} 삭제 실패:`, deleteError);
        continue;
      }
      staleInvitesDeleted++;
    }
  }

  // 4) 종료된 배틀 보관 개수 제한(10건) — "전체 배틀" 목록에 끝난 배틀이 무한정 쌓이지
  // 않도록, completed 배틀이 10건을 넘으면 오래된 것부터 초과분을 삭제한다.
  let completedPruned = 0;
  {
    const { data: completedBattles, error: fetchError } = await client
      .from('battles')
      .select('id')
      .eq('status', 'completed')
      .order('created_at', { ascending: false });
    if (fetchError) {
      console.error('[close-expired-battles] completed 배틀 조회 실패:', fetchError);
    }
    const overflow = (completedBattles ?? []).slice(10);
    for (const battle of overflow) {
      const { error: deleteError } = await client
        .from('battles')
        .delete()
        .eq('id', battle.id as string);
      if (deleteError) {
        console.error(`[close-expired-battles] battle ${battle.id} 보관 개수 초과 삭제 실패:`, deleteError);
        continue;
      }
      completedPruned++;
    }
  }

  return jsonResponse({ votingClosed, submissionResolved, staleInvitesDeleted, completedPruned });
});
