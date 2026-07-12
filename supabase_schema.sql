-- ============================================================
-- 냉장고 셰프 (Fridge Chef) — Supabase / PostgreSQL 스키마 v1
-- DB_구조설계_v2.md 문서를 기반으로 작성됨
-- 실행: Supabase 대시보드 → SQL Editor → 붙여넣고 Run
-- ============================================================

create extension if not exists "uuid-ossp";

-- 1. users (Supabase Auth의 auth.users와 1:1 연결되는 프로필 테이블)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  social_provider text check (social_provider in ('kakao','google',null)),
  nickname text not null default '냉장고 셰프',
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

create policy "본인 프로필만 조회/수정" on public.users
  for all using (auth.uid() = id);

create policy "본인 냉장고만 접근" on public.user_ingredients
  for all using (auth.uid() = user_id);

create policy "본인 영수증만 접근" on public.receipt_scans
  for all using (auth.uid() = user_id);

create policy "본인 요리기록만 접근" on public.user_recipe_history
  for all using (auth.uid() = user_id);

create policy "본인 초대만 접근" on public.meal_invites
  for all using (auth.uid() = host_user_id);

-- ingredients, recipes, recipe_ingredients, recipe_steps는 공용 참조 데이터라 전체 공개 조회 허용
alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.recipe_steps enable row level security;

create policy "전체 공개 조회" on public.ingredients for select using (true);
create policy "전체 공개 조회" on public.recipes for select using (true);
create policy "전체 공개 조회" on public.recipe_ingredients for select using (true);
create policy "전체 공개 조회" on public.recipe_steps for select using (true);
