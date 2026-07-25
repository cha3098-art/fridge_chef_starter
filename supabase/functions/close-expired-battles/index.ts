// close-expired-battles
//
// pg_cron이 주기적으로 호출하는 서버 타이머 — 호스트가 "투표 마감" 버튼을 직접 안 눌러도
// voting_ends_at이 지난 배틀은 여기서 자동으로 득표수를 세어 승자를 확정하고 양쪽에 푸시로 알린다.
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
}

Deno.serve(async (req) => {
  if (!CRON_SECRET || req.headers.get('Authorization') !== `Bearer ${CRON_SECRET}`) {
    return jsonResponse({ error: '인증되지 않은 호출입니다' }, 401);
  }

  const client = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: expiredBattles, error: fetchError } = await client
    .from('battles')
    .select('id')
    .eq('status', 'voting')
    .lt('voting_ends_at', new Date().toISOString());
  if (fetchError) {
    console.error('[close-expired-battles] battles 조회 실패:', fetchError);
    return jsonResponse({ error: '만료된 배틀 조회에 실패했습니다' }, 500);
  }
  if (!expiredBattles || expiredBattles.length === 0) {
    return jsonResponse({ closed: 0 });
  }

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

  let closedCount = 0;
  for (const battle of expiredBattles) {
    const battleId = battle.id as string;

    const [{ data: participants }, { data: votes }] = await Promise.all([
      client.from('battle_participants').select('id, user_id').eq('battle_id', battleId),
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
    closedCount++;

    if (account && accessToken) {
      const { data: tokenRows } = await client
        .from('device_tokens')
        .select('token')
        .in('user_id', participantRows.map((p) => p.user_id));
      const tokens = (tokenRows ?? []).map((r) => r.token as string);
      await Promise.all(
        tokens.map((t) =>
          sendToToken(
            accessToken,
            account.project_id,
            t,
            '배틀 투표가 마감됐어요',
            '결과를 확인해보세요!',
            { battleId },
          )
        ),
      );
    }
  }

  return jsonResponse({ closed: closedCount });
});
