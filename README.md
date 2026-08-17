# 냉장고 셰프 (Fridge Chef) — 개발 시작 골격

기획서 → 와이어프레임 → DB 설계 → UI 디자인 단계를 거쳐 만든 개발 시작 코드예요.

## 포함된 것
- `supabase_schema.sql` — Supabase SQL Editor에 바로 실행 가능한 전체 DB 스키마 (테이블 + RLS 보안 정책 + 트리거)
- `supabase/functions/` — Supabase Edge Functions (AI 이미지 인식, 푸시알림 발송, 배틀 자동 마감)
- `lib/theme/app_theme.dart` — UI디자인_v3의 색상/타이포 토큰을 Flutter 테마로 옮긴 파일
- `lib/screens/fridge_screen.dart` — "내 냉장고" 화면 실제 구현 (하단 탭바, 유통기한 뱃지 포함)
- `lib/main.dart` — 앱 진입점
- `pubspec.yaml` — 필요 패키지 목록

## 로컬에서 실행하는 방법
1. [Flutter SDK 설치](https://docs.flutter.dev/get-started/install)
2. Supabase 연동 (인증 + 내 냉장고 재료는 필수, 아래 스텝을 마쳐야 앱이 실행돼요):
   - [supabase.com](https://supabase.com)에서 프로젝트 생성
   - SQL Editor에서 `supabase_schema.sql` 전체 실행 (프로필 필드 + RLS 정책 + 재료 카탈로그 시드 포함)
   - `lib/supabase_config.dart`를 열어 프로젝트 Settings > API에서 확인한 URL과 anon key를 입력 (anon key는 RLS로 보호되는 공개 키라 커밋해도 안전함)
3. 이 폴더를 열고 터미널에서:
   ```
   flutter pub get
   flutter run
   ```
4. `supabase_config.dart`를 설정하지 않으면 "Supabase 설정이 필요해요" 안내 화면만 뜹니다.

### AI 사진 인식(선택) — Supabase CLI + Edge Functions
사진으로 재료 인식 / 냉장고 전체촬영 기능을 실제로 쓰려면:
1. [Supabase CLI 설치](https://supabase.com/docs/guides/cli) 후 `supabase login`, `supabase link --project-ref <프로젝트-ref>`
2. `supabase functions deploy analyze-fridge-photo`
3. [platform.openai.com](https://platform.openai.com)에서 API 키 발급(결제 수단 등록 필요) 후:
   `supabase secrets set OPENAI_API_KEY=sk-...`

### 배틀 모드 실시간 매칭/푸시알림/자동 마감(선택)
1. [Firebase 콘솔](https://console.firebase.google.com)에서 프로젝트 생성 → Android 앱 등록(패키지명 `com.fourm.fridgechef`) → `google-services.json` 다운로드해서 `android/app/`에 위치
2. Firebase 콘솔 > 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성 → 받은 JSON을 그대로 시크릿으로 등록:
   `supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'`
3. `supabase functions deploy send-push` 와 `supabase functions deploy close-expired-battles --no-verify-jwt`
4. 배틀 투표 자동 마감 크론(5분마다 실행)은 `supabase_schema.sql`의 "18. pg_cron" 섹션에 있음 — `CRON_SECRET` 시크릿을 등록하고, SQL 안의 `Bearer <값>`도 동일한 값으로 맞춰서 실행

## 현재 Supabase로 연동된 부분
- 회원가입/로그인/로그아웃 — `AuthService` + `AuthGate` (Supabase Auth 이메일/비밀번호)
- 프로필 — `ProfileStore`가 `public.users` 테이블과 동기화 (아이디/닉네임 중복확인 포함)
- 내 냉장고 재료 — `FridgeStore`가 `public.ingredients` / `public.user_ingredients` 테이블과 동기화
- 재료 등록 — 검색 등록 + 영수증 스캔(OCR) + **사진으로 재료 인식 / 냉장고 전체촬영**(GPT-4o-mini Vision,
  `analyze-fridge-photo` Edge Function이 카탈로그와 매칭된 결과만 반환)
- 게시판 — `BoardStore`가 `public.board_posts` / `public.board_post_likes`와 동기화, 사진 첨부는
  `board-photos` Storage 버킷에 실제 업로드됨
- 요리 포인트/등급 — `ChefPointsStore`가 `public.chef_point_events`와 동기화. 게시글 좋아요 10개당 +1점은
  DB 트리거(`handle_board_like_change`)가 서버에서 자동으로 적립해준다 (좋아요를 누르는 사람과 포인트를
  받는 작성자가 다를 수 있어서 클라이언트가 아니라 서버에서 처리)
- 랭킹 — 데모 사용자 없이 실제 가입한 전체 사용자를 포인트순으로 보여줌
- 알림 — 댓글 실시간 알림(`RealtimeNotificationManager`) + 유통기한 임박 예약 알림(로컬) + FCM 푸시(배틀
  이벤트, 앱이 백그라운드/종료 상태여도 수신)
- **요리 배틀** — `BattleStore`가 `public.battles` / `battle_participants` / `battle_votes`와 동기화.
  초대 링크 기반 비동기 대결과, `battle_queue` + DB 트리거로 매칭하는 실시간 빠른 매칭 둘 다 지원.
  투표는 호스트가 수동으로 마감하거나, `close-expired-battles`가 24시간 뒤 자동으로 마감(pg_cron, 5분마다 확인)

## 아직 로컬/미구현인 부분
- 회원가입 시 프로필 사진 업로드 (Supabase Storage 연동 필요 — 현재는 사진을 골라도 서버에 저장되지 않음)
- 배틀 승자에게 지급되는 포인트는 승자 본인이 배틀 상세 화면을 한 번 열어야 반영됨 (호스트가 대신
  상대에게 포인트를 적립해줄 수 없는 RLS 구조상의 제약)

디자인 목업은 `UI디자인_v3.html` 파일을 참고하면서 화면별로 하나씩 구현하면 됩니다.
