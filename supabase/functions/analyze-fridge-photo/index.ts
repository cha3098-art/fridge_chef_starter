// analyze-fridge-photo
//
// "사진인식" / "냉장고 전체촬영" 탭에서 호출하는 Edge Function.
// Flutter가 fridge-scans 버킷에 이미 업로드한 사진의 공개 URL을 받아서,
// OpenAI GPT-4o-mini Vision API로 보이는 식재료를 인식하고,
// 우리 ingredients 테이블(재료 카탈로그)과 실제로 일치하는 항목만 매칭해서 돌려준다.
//
// OcrParserService(영수증 스캔)와 동일한 원칙을 따른다: AI가 뭐라고 답하든,
// 카탈로그에 없는 이름은 등록이 안 되므로(FridgeStore.addItems가 조용히 스킵) 반드시
// ingredients 테이블의 실제 이름으로만 매칭해서 반환한다 — 화면에는 매칭된 것만 보여준다.
//
// 배포:  supabase functions deploy analyze-fridge-photo
// 시크릿: supabase secrets set OPENAI_API_KEY=sk-...
// 호출(Flutter): supabase.functions.invoke('analyze-fridge-photo', body: {'imageUrl': url})
//   — functions.invoke는 현재 로그인 세션의 JWT를 Authorization 헤더에 자동으로 실어 보낸다.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

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

// GPT-4o-mini에게 보낼 시스템 프롬프트.
// 순수 JSON 배열(response_format: json_object)은 OpenAI가 최상위 배열을 허용하지 않으므로,
// { "ingredients": [...] } 형태의 객체로 감싸 달라고 명시한다 — 파싱 실패 위험을 줄이기 위함.
const SYSTEM_PROMPT = `Analyze this refrigerator or grocery image. Identify all visible raw food ingredients only.
Do not include cooked dishes, side dishes (반찬), plates, containers, or non-food items.
Respond with strict JSON only, in this exact shape: {"ingredients": ["대파", "두부", "양파"]}
All ingredient names must be written in Korean. If nothing is recognizable, return {"ingredients": []}.`;

interface OpenAiVisionResult {
  ingredients: string[];
}

async function callVisionApi(imageUrl: string): Promise<OpenAiVisionResult> {
  if (!OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY 시크릿이 설정되어 있지 않습니다');
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      response_format: { type: 'json_object' },
      max_tokens: 500,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: SYSTEM_PROMPT },
            { type: 'image_url', image_url: { url: imageUrl } },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI Vision API 호출 실패 (${response.status}): ${errText}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (typeof content !== 'string') {
    throw new Error('OpenAI 응답에서 content를 찾을 수 없습니다');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`OpenAI 응답이 유효한 JSON이 아닙니다: ${content}`);
  }

  const ingredients = (parsed as { ingredients?: unknown }).ingredients;
  if (!Array.isArray(ingredients) || !ingredients.every((x) => typeof x === 'string')) {
    throw new Error('OpenAI 응답의 ingredients 필드가 문자열 배열이 아닙니다');
  }
  return { ingredients };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'POST만 지원합니다' }, 405);
  }

  // 이미지 인식은 OpenAI 호출 비용이 실제로 발생하므로, 로그인한 사용자만 호출할 수 있도록
  // 요청의 Authorization 헤더(JWT)를 검증한다 — 익명 요청은 거부한다.
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

  let body: { imageUrl?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: '요청 본문이 유효한 JSON이 아닙니다' }, 400);
  }

  const imageUrl = body.imageUrl;
  if (!imageUrl || typeof imageUrl !== 'string') {
    return jsonResponse({ error: 'imageUrl이 필요합니다' }, 400);
  }

  let visionResult: OpenAiVisionResult;
  try {
    visionResult = await callVisionApi(imageUrl);
  } catch (err) {
    console.error('[analyze-fridge-photo] vision API error:', err);
    return jsonResponse({ error: err instanceof Error ? err.message : String(err) }, 502);
  }

  // 인증된 클라이언트로 조회한다 — ingredients 테이블은 "전체 공개 조회" 정책이라
  // 별도 service role 키 없이도 안전하게 조회할 수 있다.
  const { data: catalogRows, error: dbError } = await authedClient
    .from('ingredients')
    .select('id, name, category, unit_default, default_shelf_life_days')
    .in('name', visionResult.ingredients);

  if (dbError) {
    console.error('[analyze-fridge-photo] ingredients query error:', dbError);
    return jsonResponse({ error: '재료 카탈로그 조회에 실패했습니다' }, 500);
  }

  const matched = (catalogRows ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    category: row.category,
    unitDefault: row.unit_default,
    defaultShelfLifeDays: row.default_shelf_life_days,
  }));

  return jsonResponse({
    recognized: visionResult.ingredients,
    matched,
  });
});
