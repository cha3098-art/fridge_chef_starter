// send-push
//
// 배틀 상대에게 영향을 주는 행동(참가/사진 제출/투표 마감)이 끝난 직후 클라이언트가 호출한다.
// FCM Legacy 서버 키는 이미 폐지됐으므로 HTTP v1 API를 쓰고, 이건 서비스 계정의 개인키로
// 직접 서명한 JWT를 구글 OAuth2 토큰 엔드포인트와 교환해야 한다 — 그래서 코드가 길다.
//
// 배포:  supabase functions deploy send-push
// 시크릿: supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
//        (Firebase 콘솔 > 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성으로 받은 JSON 그대로)
// 호출(Flutter): supabase.functions.invoke('send-push', body: {'userIds': [...], 'title': ..., 'body': ..., 'data': {...}})

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlEncodeString(s: string): string {
  return base64UrlEncode(new TextEncoder().encode(s));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

// 서비스 계정 개인키로 서명한 JWT를 구글 OAuth2 토큰 엔드포인트와 교환해 access_token을 받는다.
// (한 시간 정도 유효하지만, 실행마다 매번 새로 발급한다 — 함수 인스턴스가 재사용될 만큼
// 트래픽이 많은 앱이 아니라 캐싱까지는 과설계라고 판단했다)
async function getAccessToken(account: ServiceAccount): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600,
  };
  const unsigned = `${base64UrlEncodeString(JSON.stringify(header))}.${base64UrlEncodeString(JSON.stringify(claims))}`;

  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!response.ok) {
    throw new Error(`구글 OAuth2 토큰 발급 실패 (${response.status}): ${await response.text()}`);
  }
  const data = await response.json();
  return data.access_token as string;
}

async function sendToToken(
  accessToken: string,
  projectId: string,
  deviceToken: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<{ token: string; ok: boolean; error?: string }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          data: data ?? {},
        },
      }),
    },
  );
  if (response.ok) return { token: deviceToken, ok: true };
  return { token: deviceToken, ok: false, error: await response.text() };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'POST만 지원합니다' }, 405);
  }
  if (!SERVICE_ACCOUNT_JSON) {
    return jsonResponse({ error: 'FIREBASE_SERVICE_ACCOUNT 시크릿이 설정되어 있지 않습니다' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: '로그인이 필요합니다' }, 401);
  }
  const authedClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: authError } = await authedClient.auth.getUser();
  if (authError || !userData.user) {
    return jsonResponse({ error: '유효하지 않은 세션입니다' }, 401);
  }

  let body: { userIds?: string[]; title?: string; body?: string; data?: Record<string, string> };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: '요청 본문이 유효한 JSON이 아닙니다' }, 400);
  }
  const { userIds, title, body: messageBody, data } = body;
  if (!userIds || userIds.length === 0 || !title || !messageBody) {
    return jsonResponse({ error: 'userIds, title, body가 필요합니다' }, 400);
  }

  // 발신자 본인에게는 보내지 않는다 — 내가 방금 한 행동으로 나한테 알림이 뜨는 건 의미가 없다
  const recipientIds = userIds.filter((id) => id !== userData.user.id);
  if (recipientIds.length === 0) {
    return jsonResponse({ recognized: 0, sent: 0, results: [] });
  }

  const { data: tokenRows, error: tokenError } = await authedClient
    .from('device_tokens')
    .select('token')
    .in('user_id', recipientIds);
  if (tokenError) {
    console.error('[send-push] device_tokens query error:', tokenError);
    return jsonResponse({ error: '기기 토큰 조회에 실패했습니다' }, 500);
  }
  const tokens = (tokenRows ?? []).map((r) => r.token as string);
  if (tokens.length === 0) {
    return jsonResponse({ recognized: recipientIds.length, sent: 0, results: [] });
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(SERVICE_ACCOUNT_JSON);
  } catch {
    return jsonResponse({ error: 'FIREBASE_SERVICE_ACCOUNT이 유효한 JSON이 아닙니다' }, 500);
  }

  try {
    const accessToken = await getAccessToken(account);
    const results = await Promise.all(
      tokens.map((t) => sendToToken(accessToken, account.project_id, t, title, messageBody, data)),
    );
    return jsonResponse({
      recognized: recipientIds.length,
      sent: results.filter((r) => r.ok).length,
      results,
    });
  } catch (err) {
    console.error('[send-push] FCM send error:', err);
    return jsonResponse({ error: err instanceof Error ? err.message : String(err) }, 502);
  }
});
