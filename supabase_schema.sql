-- ============================================================
-- 냉장고 셰프 (Fridge Chef) — Supabase / PostgreSQL 스키마 v1
-- DB_구조설계_v2.md 문서를 기반으로 작성됨
-- 실행: Supabase 대시보드 → SQL Editor → 붙여넣고 Run
-- ============================================================

create extension if not exists "uuid-ossp";

-- 1. users (Supabase Auth의 auth.users와 1:1 연결되는 프로필 테이블)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  email text,
  social_provider text check (social_provider in ('kakao','google',null)),
  nickname text not null unique default '냉장고 셰프',
  gender text,
  nationality text,
  city text,
  bio text,
  photo_url text,
  hide_gender boolean not null default false,
  hide_photo boolean not null default false,
  hide_nationality boolean not null default false,
  hide_city boolean not null default false,
  hide_email boolean not null default false,
  created_at timestamptz not null default now()
);

-- 2. ingredients (재료 마스터)
create table public.ingredients (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  category text,
  unit_default text,
  default_shelf_life_days integer,
  image_url text,
  prep_tip text,
  storage_tip text
);

-- 3. user_ingredients (내 냉장고 — 상시 인벤토리)
create table public.user_ingredients (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric not null default 0,
  unit text,
  expiry_date date,
  added_via text check (added_via in ('manual','photo_recognition','receipt_ocr')) default 'manual',
  status text check (status in ('active','consumed','expired')) default 'active',
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_user_ingredients_user on public.user_ingredients(user_id);
create index idx_user_ingredients_expiry on public.user_ingredients(expiry_date);

-- 4. inventory_adjustments (재고 변동 이력)
create table public.inventory_adjustments (
  id uuid primary key default uuid_generate_v4(),
  user_ingredient_id uuid not null references public.user_ingredients(id) on delete cascade,
  change_type text check (change_type in ('add','consume_by_recipe','manual_edit','expired')) not null,
  quantity_before numeric,
  quantity_after numeric,
  related_recipe_history_id uuid,
  note text,
  created_at timestamptz not null default now()
);

-- 5. receipt_scans (영수증 스캔)
create table public.receipt_scans (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_url text,
  ocr_status text check (ocr_status in ('processing','completed','failed')) default 'processing',
  store_name text,
  scanned_at timestamptz not null default now()
);

-- 6. receipt_items (영수증 인식 항목)
create table public.receipt_items (
  id uuid primary key default uuid_generate_v4(),
  receipt_scan_id uuid not null references public.receipt_scans(id) on delete cascade,
  raw_text text,
  matched_ingredient_id uuid references public.ingredients(id),
  quantity numeric,
  unit text,
  is_confirmed boolean default false,
  is_matched_manually boolean default false
);

-- 7. recipes (레시피 마스터)
create table public.recipes (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  cook_time_min integer,
  difficulty text check (difficulty in ('하','중','상')),
  cuisine_type text check (cuisine_type in ('한식','중식','양식','분식')),
  calories_per_serving integer,
  carbs_g numeric,
  protein_g numeric,
  fat_g numeric,
  sodium_mg numeric,
  video_url text,
  data_source text check (data_source in ('public_data','self_produced','user_submitted')),
  created_at timestamptz not null default now()
);

-- 8. recipe_ingredients (레시피별 필요 재료)
create table public.recipe_ingredients (
  id uuid primary key default uuid_generate_v4(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric,
  unit text,
  is_optional boolean default false
);
create index idx_recipe_ingredients_recipe on public.recipe_ingredients(recipe_id);
create index idx_recipe_ingredients_ingredient on public.recipe_ingredients(ingredient_id);

-- 9. recipe_steps (조리 단계)
create table public.recipe_steps (
  id uuid primary key default uuid_generate_v4(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  step_order integer not null,
  description text not null,
  timer_sec integer
);

-- 10. user_recipe_history (요리 완료 기록)
create table public.user_recipe_history (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id),
  servings integer default 1,
  completed_at timestamptz not null default now(),
  photo_url text
);

-- 11. meal_invites (식사초대하기)
create table public.meal_invites (
  id uuid primary key default uuid_generate_v4(),
  host_user_id uuid not null references public.users(id) on delete cascade,
  recipe_id uuid references public.recipes(id),
  invite_link text,
  message text,
  created_at timestamptz not null default now()
);
-- recipes 테이블이 아직 시딩되어 있지 않아 recipe_id로 정적 카탈로그 레시피를 참조할 수 없으므로,
-- 레시피 제목을 텍스트로 직접 저장한다 (딥링크로 열었을 때 바로 보여주기 위함)
alter table public.meal_invites add column if not exists recipe_title text;

-- 12. board_posts / board_post_likes (게시판)
create table public.board_posts (
  id uuid primary key default uuid_generate_v4(),
  category text check (category in ('showoff','challenge')) not null,
  author_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  content text not null,
  photo_url text,
  points_awarded integer not null default 0,
  created_at timestamptz not null default now()
);
create index idx_board_posts_category on public.board_posts(category);

create table public.board_post_likes (
  post_id uuid not null references public.board_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- 게시글 댓글 — 작성자 닉네임/등급은 작성 시점 값을 그대로 저장한다(비정규화, board_posts와 동일한 방식)
-- author_id에 public.users FK를 걸어 데이터 정합성을 보장한다 (참조 무결성)
create table public.board_comments (
  id uuid default uuid_generate_v4() primary key,
  post_id uuid not null references public.board_posts(id) on delete cascade,
  author_id uuid not null references public.users(id) on delete cascade,
  author_nickname text not null,
  author_username text not null,
  author_tier text,
  author_is_kfood_master boolean not null default false,
  content text not null,
  created_at timestamptz not null default now()
);
create index board_comments_post_id_idx on public.board_comments(post_id);

-- 13. chef_point_events (요리 포인트 적립 내역 — 마이 화면의 "최근 포인트 내역" 원본)
create table public.chef_point_events (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  reason text not null,
  amount integer not null,
  is_kfood_track boolean not null default false,
  label_ko text not null,
  label_en text not null,
  -- 냉장고 첫 재료 등록 같은 1회성 보너스의 중복 지급을 막기 위한 키 (예: 'first_ingredient', 'first_try:김치찌개')
  dedupe_key text,
  created_at timestamptz not null default now()
);
create index idx_chef_point_events_user on public.chef_point_events(user_id);
-- 일반(부분) 유니크 인덱스로 둔다: dedupe_key가 NULL인 행은 서로 다른 값으로 취급되어 몇 개든 허용되고,
-- 값이 있는 경우만 (user_id, dedupe_key) 조합으로 유일함이 강제된다.
-- 이전에 "where dedupe_key is not null" 부분 인덱스로 만들었더니 upsert의 ON CONFLICT(user_id,dedupe_key)가
-- 부분 인덱스를 타겟팅하지 못해 42P10 에러로 모든 dedupe 적립(첫 재료 등록, 첫 도전 보너스 등)이 조용히 실패했다.
create unique index idx_chef_point_events_dedupe on public.chef_point_events(user_id, dedupe_key);

-- 좋아요 10개마다 게시글 작성자에게 +1점을 자동 지급하는 트리거.
-- 좋아요를 누르는 사람과 포인트를 받는 작성자가 다르므로 SECURITY DEFINER로 RLS를 우회해 작성자 대신 적립한다.
create or replace function public.handle_board_like_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post_id uuid;
  like_total integer;
  new_points integer;
  delta integer;
  post_row public.board_posts;
begin
  target_post_id := coalesce(new.post_id, old.post_id);
  select count(*) into like_total from public.board_post_likes where post_id = target_post_id;
  new_points := like_total / 10;

  select * into post_row from public.board_posts where id = target_post_id;
  delta := new_points - post_row.points_awarded;

  update public.board_posts set points_awarded = new_points where id = target_post_id;

  if delta > 0 then
    insert into public.chef_point_events (user_id, reason, amount, is_kfood_track, label_ko, label_en)
    values (
      post_row.author_id,
      'boardLikes',
      delta,
      false,
      '"' || post_row.title || '" 게시글 좋아요 보너스',
      '"' || post_row.title || '" post like bonus'
    );
  end if;

  return null;
end;
$$;

create trigger on_board_like_change
after insert or delete on public.board_post_likes
for each row execute function public.handle_board_like_change();

-- 14. notifications (댓글/유통기한 등 인앱 알림 내역)
create table public.notifications (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null, -- 'comment', 'expiration' 등
  related_id text,     -- 이동할 게시글 ID 등 관련 메타데이터
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notifications_user on public.notifications(user_id);

-- RealtimeNotificationManager가 .stream()으로 구독하려면 이 테이블이 realtime publication에
-- 포함되어 있어야 한다 (테이블을 새로 만들면 기본적으로 포함되지 않는다)
alter publication supabase_realtime add table public.notifications;

-- 댓글이 달리면 게시글 작성자에게 알림을 적립한다.
-- 댓글 작성자와 알림을 받을 작성자가 다르므로 SECURITY DEFINER로 RLS를 우회해 작성자 대신 적립한다
-- (board_comments의 insert 정책은 auth.uid() = author_id만 허용하므로, 클라이언트가 직접
-- 다른 사람의 user_id로 notifications를 insert할 수는 없다 — 이 트리거가 유일한 통로다)
create or replace function public.handle_new_board_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_row public.board_posts;
begin
  select * into post_row from public.board_posts where id = new.post_id;

  if post_row.author_id is not null and post_row.author_id <> new.author_id then
    insert into public.notifications (user_id, title, body, type, related_id)
    values (
      post_row.author_id,
      '새 댓글이 달렸어요',
      new.author_nickname || '님: ' || left(new.content, 40),
      'comment',
      new.post_id
    );
  end if;

  return new;
end;
$$;

create trigger on_board_comment_created
after insert on public.board_comments
for each row execute function public.handle_new_board_comment();

-- ============================================================
-- Row Level Security (RLS) — 각 사용자가 자기 데이터만 접근 가능하도록 설정
-- ============================================================
alter table public.users enable row level security;
alter table public.user_ingredients enable row level security;
alter table public.inventory_adjustments enable row level security;
alter table public.receipt_scans enable row level security;
alter table public.receipt_items enable row level security;
alter table public.user_recipe_history enable row level security;
alter table public.meal_invites enable row level security;

-- users는 랭킹/게시판 화면에서 다른 사람의 닉네임·등급도 보여줘야 하므로 조회는 전체 공개하고,
-- 쓰기(등록/수정/삭제)만 본인으로 제한한다. 비공개 처리가 필요한 필드는 클라이언트에서 UserProfile.toPublicView()로 가린다.
create policy "전체 공개 조회" on public.users
  for select using (true);

create policy "본인 프로필만 생성" on public.users
  for insert with check (auth.uid() = id);

create policy "본인 프로필만 수정" on public.users
  for update using (auth.uid() = id);

create policy "본인 프로필만 삭제" on public.users
  for delete using (auth.uid() = id);

create policy "본인 냉장고만 접근" on public.user_ingredients
  for all using (auth.uid() = user_id);

create policy "본인 영수증만 접근" on public.receipt_scans
  for all using (auth.uid() = user_id);

create policy "본인 요리기록만 접근" on public.user_recipe_history
  for all using (auth.uid() = user_id);

-- 초대장은 딥링크로 다른 사람(비로그인 포함)도 열어볼 수 있어야 하므로 조회는 전체 공개하고,
-- 생성/수정/삭제는 호스트 본인으로 제한한다 (게시판과 동일한 패턴)
create policy "초대장 전체 공개 조회" on public.meal_invites
  for select using (true);

create policy "본인 초대만 생성" on public.meal_invites
  for insert with check (auth.uid() = host_user_id);

create policy "본인 초대만 수정" on public.meal_invites
  for update using (auth.uid() = host_user_id);

create policy "본인 초대만 삭제" on public.meal_invites
  for delete using (auth.uid() = host_user_id);

-- 게시판/포인트는 랭킹·배지 표시를 위해 조회는 전체 공개하고 쓰기만 본인으로 제한한다
alter table public.board_posts enable row level security;
alter table public.board_post_likes enable row level security;
alter table public.board_comments enable row level security;
alter table public.chef_point_events enable row level security;
alter table public.notifications enable row level security;

-- notifications는 본인 것만 읽고 읽음 처리할 수 있다. insert는 클라이언트에서 직접 하지 않고
-- handle_new_board_comment 트리거(SECURITY DEFINER)를 통해서만 이루어진다.
create policy "본인 알림만 조회" on public.notifications
  for select using (auth.uid() = user_id);

create policy "본인 알림만 읽음 처리" on public.notifications
  for update using (auth.uid() = user_id);

create policy "게시글 전체 공개 조회" on public.board_posts for select using (true);
create policy "본인 글만 작성" on public.board_posts for insert with check (auth.uid() = author_id);

create policy "좋아요 전체 공개 조회" on public.board_post_likes for select using (true);
create policy "본인 좋아요만 추가" on public.board_post_likes for insert with check (auth.uid() = user_id);
create policy "본인 좋아요만 삭제" on public.board_post_likes for delete using (auth.uid() = user_id);

create policy "댓글 전체 공개 조회" on public.board_comments for select using (true);
create policy "로그인한 사용자만 댓글 작성" on public.board_comments for insert with check (auth.uid() = author_id);

create policy "포인트 내역 전체 공개 조회" on public.chef_point_events for select using (true);
create policy "본인 포인트 내역만 추가" on public.chef_point_events for insert with check (auth.uid() = user_id);

-- ============================================================
-- Storage: board-photos 버킷 (뽐내기/챌린지 게시글 사진)
-- board_posts.photo_url이 게시글 전체 공개 조회이므로, 실제 이미지 파일도 같은 정책으로 공개한다.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('board-photos', 'board-photos', true)
on conflict (id) do nothing;

create policy "게시판 사진 전체 공개 조회"
  on storage.objects for select
  using (bucket_id = 'board-photos');

create policy "로그인한 사용자만 게시판 사진 업로드"
  on storage.objects for insert
  with check (bucket_id = 'board-photos' and auth.role() = 'authenticated');

create policy "본인이 올린 게시판 사진만 삭제"
  on storage.objects for delete
  using (bucket_id = 'board-photos' and auth.uid() = owner);

-- ============================================================
-- Storage: fridge-scans 버킷 (사진인식/냉장고 전체촬영 임시 스캔 사진)
-- analyze-fridge-photo Edge Function이 OpenAI Vision API에 이 URL을 그대로 전달해야 하므로
-- board-photos와 동일하게 공개 버킷으로 둔다 (경로에 uid+timestamp가 섞여 있어 실질적으로 추측 불가능).
-- 이 사진들은 재료 인식 후 화면에 계속 남는 콘텐츠가 아니라 스캔 1회성 입력이므로,
-- 언젠가 오래된 파일을 정리하는 배치 작업을 붙일 수 있도록 별도 버킷으로 분리했다.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('fridge-scans', 'fridge-scans', true)
on conflict (id) do nothing;

create policy "냉장고 스캔 사진 전체 공개 조회"
  on storage.objects for select
  using (bucket_id = 'fridge-scans');

create policy "로그인한 사용자만 스캔 사진 업로드"
  on storage.objects for insert
  with check (bucket_id = 'fridge-scans' and auth.role() = 'authenticated');

create policy "본인이 올린 스캔 사진만 삭제"
  on storage.objects for delete
  using (bucket_id = 'fridge-scans' and auth.uid() = owner);

-- ingredients, recipes, recipe_ingredients, recipe_steps는 공용 참조 데이터라 전체 공개 조회 허용
alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.recipe_steps enable row level security;

create policy "전체 공개 조회" on public.ingredients for select using (true);
create policy "전체 공개 조회" on public.recipes for select using (true);
create policy "전체 공개 조회" on public.recipe_ingredients for select using (true);
create policy "전체 공개 조회" on public.recipe_steps for select using (true);

-- ============================================================
-- 재료 마스터 시드 데이터 — lib/data/ingredient_catalog.dart 와 동일하게 유지
-- ============================================================
insert into public.ingredients (name, category, unit_default, default_shelf_life_days) values
  ('대파', '채소', '단', 10),
  ('양파', '채소', '개', 30),
  ('애호박', '채소', '개', 7),
  ('시금치', '채소', '단', 5),
  ('마늘', '채소', 'g', 30),
  ('감자', '채소', '개', 21),
  ('돼지고기 앞다리살', '육류', 'g', 4),
  ('소고기 등심', '육류', 'g', 4),
  ('닭가슴살', '육류', 'g', 3),
  ('삼겹살', '육류', 'g', 4),
  ('계란', '유제품', '개', 21),
  ('우유', '유제품', 'ml', 7),
  ('슬라이스치즈', '유제품', '장', 30),
  ('버터', '유제품', 'g', 60),
  ('고등어', '수산', '마리', 2),
  ('새우', '수산', 'g', 2),
  ('두부', '기타', '모', 5),
  ('김치', '기타', 'g', 60),
  ('김', '기타', '봉', 90)
on conflict (name) do nothing;

-- ============================================================
-- 15. battles / battle_participants / battle_votes (배틀 모드 — 비동기 초대 링크 대결, Phase 2)
-- 실시간 매칭(Phase 3)은 아직 없다: 호스트가 배틀을 만들면 meal_invites와 동일하게
-- invite_link로 상대를 초대하고, 각자 완성 사진을 올린 뒤(submitted_at) 다른 사용자들이 투표한다.
-- 승자 확정 로직(winner_user_id 갱신)은 아직 화면/서버 로직이 없어 수동 필드로만 남겨둔다.
-- ============================================================
create table public.battles (
  id uuid primary key default uuid_generate_v4(),
  host_user_id uuid not null references public.users(id) on delete cascade,
  recipe_id uuid references public.recipes(id),
  -- recipes가 아직 다 시딩되지 않은 자유 주제 대결도 가능하도록 텍스트 제목을 별도로 둔다 (meal_invites.recipe_title과 동일한 이유)
  theme_title text,
  status text check (status in ('waiting_opponent','submitted','voting','completed','cancelled')) not null default 'waiting_opponent',
  invite_link text,
  voting_ends_at timestamptz,
  winner_user_id uuid references public.users(id),
  created_at timestamptz not null default now()
);
create index idx_battles_host on public.battles(host_user_id);

-- 상대가 초대 링크로 들어와 참가하면 host/opponent 각각 한 행씩 생긴다 (지금은 1:1 대결만 지원 — role당 battle에 1명).
create table public.battle_participants (
  id uuid primary key default uuid_generate_v4(),
  battle_id uuid not null references public.battles(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text check (role in ('host','opponent')) not null,
  photo_url text,
  submitted_at timestamptz,
  joined_at timestamptz not null default now(),
  unique (battle_id, user_id),
  unique (battle_id, role)
);
create index idx_battle_participants_battle on public.battle_participants(battle_id);
create index idx_battle_participants_user on public.battle_participants(user_id);

-- 1인 1표. 승자 집계(투표수 비교)는 화면 단계에서 붙일 예정이라 지금은 원본 투표 기록만 저장한다.
create table public.battle_votes (
  id uuid primary key default uuid_generate_v4(),
  battle_id uuid not null references public.battles(id) on delete cascade,
  voter_id uuid not null references public.users(id) on delete cascade,
  voted_for_participant_id uuid not null references public.battle_participants(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (battle_id, voter_id)
);
create index idx_battle_votes_battle on public.battle_votes(battle_id);

alter table public.battles enable row level security;
alter table public.battle_participants enable row level security;
alter table public.battle_votes enable row level security;

-- 초대 링크로 비참가자도 대결 현황을 볼 수 있어야 하므로 조회는 전체 공개하고,
-- 생성/상태 수정은 meal_invites와 동일하게 호스트 본인으로 제한한다.
create policy "배틀 전체 공개 조회" on public.battles for select using (true);
create policy "본인이 호스트인 배틀만 생성" on public.battles for insert with check (auth.uid() = host_user_id);
create policy "호스트만 배틀 정보 수정" on public.battles for update using (auth.uid() = host_user_id);

-- 참가자 명단/제출 사진도 대결 화면에서 양쪽 다 보여야 하므로 조회는 전체 공개하고,
-- 등록/제출은 본인 행만 건드릴 수 있다.
create policy "배틀 참가자 전체 공개 조회" on public.battle_participants for select using (true);
create policy "본인만 참가자로 등록" on public.battle_participants for insert with check (auth.uid() = user_id);
create policy "본인 제출물만 수정" on public.battle_participants for update using (auth.uid() = user_id);

create policy "배틀 투표 전체 공개 조회" on public.battle_votes for select using (true);
create policy "본인 명의로만 투표" on public.battle_votes for insert with check (auth.uid() = voter_id);
create policy "본인 투표만 취소" on public.battle_votes for delete using (auth.uid() = voter_id);

-- ============================================================
-- 16. battle_queue (배틀 모드 — 실시간 빠른 매칭, Phase 3)
-- 대기열에 들어온 순서대로 먼저 있던 상대와 즉시 매칭한다. 클라이언트가 서로를 보고
-- 알아서 배틀을 만드는 방식(경쟁 상태 위험)이 아니라, DB 트리거가 행 잠금(for update
-- skip locked)으로 한 쌍만 원자적으로 매칭해서 battles/battle_participants를 직접 만든다.
-- 매칭 결과는 본인 대기열 행의 matched_battle_id 변화를 realtime으로 구독해서 받는다.
-- ============================================================
create table public.battle_queue (
  user_id uuid primary key references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  matched_battle_id uuid references public.battles(id)
);

create or replace function public.handle_battle_queue_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  opponent_row public.battle_queue;
  new_battle_id uuid;
begin
  select * into opponent_row
  from public.battle_queue
  where user_id <> new.user_id and matched_battle_id is null
  order by joined_at
  limit 1
  for update skip locked;

  if opponent_row.user_id is null then
    return new;
  end if;

  insert into public.battles (host_user_id, theme_title, status, invite_link)
  values (new.user_id, '빠른 매칭 배틀', 'submitted', null)
  returning id into new_battle_id;

  insert into public.battle_participants (battle_id, user_id, role) values
    (new_battle_id, new.user_id, 'host'),
    (new_battle_id, opponent_row.user_id, 'opponent');

  update public.battle_queue set matched_battle_id = new_battle_id where user_id = new.user_id;
  update public.battle_queue set matched_battle_id = new_battle_id where user_id = opponent_row.user_id;

  return new;
end;
$$;

create trigger on_battle_queue_insert
after insert on public.battle_queue
for each row execute function public.handle_battle_queue_insert();

alter table public.battle_queue enable row level security;

-- 대기열은 "누가 기다리는지" 자체가 노출되면 안 되므로 본인 행만 보고 넣고 지울 수 있다.
-- matched_battle_id 갱신은 위 트리거(SECURITY DEFINER)를 통해서만 이루어진다.
create policy "본인 대기열 행만 조회" on public.battle_queue for select using (auth.uid() = user_id);
create policy "본인만 대기열 등록" on public.battle_queue for insert with check (auth.uid() = user_id);
create policy "본인만 대기열 취소" on public.battle_queue for delete using (auth.uid() = user_id);

-- BattleStore.watchMatchedBattleId()가 .stream()으로 구독하려면 realtime publication에 포함돼야 한다
alter publication supabase_realtime add table public.battle_queue;

-- ============================================================
-- 17. device_tokens (FCM 푸시알림 — 앱이 백그라운드/종료 상태여도 배틀 이벤트를 알려주기 위함, Phase 3)
-- 한 사용자가 여러 기기를 쓸 수 있어 (user_id, token) 조합을 기본키로 둔다.
-- 실제 발송은 supabase/functions/send-push Edge Function이 담당하고, 클라이언트는
-- 상대에게 영향을 주는 배틀 행동(참가/제출/투표마감)을 완료한 직후 그 함수를 호출한다.
-- ============================================================
create table public.device_tokens (
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.device_tokens enable row level security;
create policy "본인 기기 토큰만 조회" on public.device_tokens for select using (auth.uid() = user_id);
create policy "본인만 기기 토큰 등록" on public.device_tokens for insert with check (auth.uid() = user_id);
create policy "본인만 기기 토큰 갱신" on public.device_tokens for update using (auth.uid() = user_id);
create policy "본인만 기기 토큰 삭제" on public.device_tokens for delete using (auth.uid() = user_id);
