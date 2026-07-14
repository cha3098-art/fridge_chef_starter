# 냉장고 셰프 (Fridge Chef) — 개발 시작 골격

기획서 → 와이어프레임 → DB 설계 → UI 디자인 단계를 거쳐 만든 개발 시작 코드예요.

## 포함된 것
- `supabase_schema.sql` — Supabase SQL Editor에 바로 실행 가능한 전체 DB 스키마 (11개 테이블 + RLS 보안 정책)
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

## 현재 Supabase로 연동된 부분
- 회원가입/로그인/로그아웃 — `AuthService` + `AuthGate` (Supabase Auth 이메일/비밀번호)
- 프로필 — `ProfileStore`가 `public.users` 테이블과 동기화 (아이디/닉네임 중복확인 포함)
- 내 냉장고 재료 — `FridgeStore`가 `public.ingredients` / `public.user_ingredients` 테이블과 동기화
- 게시판 — `BoardStore`가 `public.board_posts` / `public.board_post_likes`와 동기화
- 요리 포인트/등급 — `ChefPointsStore`가 `public.chef_point_events`와 동기화. 게시글 좋아요 10개당 +1점은
  DB 트리거(`handle_board_like_change`)가 서버에서 자동으로 적립해준다 (좋아요를 누르는 사람과 포인트를
  받는 작성자가 다를 수 있어서 클라이언트가 아니라 서버에서 처리)
- 랭킹 — 데모 사용자 없이 실제 가입한 전체 사용자를 포인트순으로 보여줌

## 아직 로컬/미구현인 부분 (다음 연동 후보)
- 재료 등록의 사진인식 / 영수증스캔 / 냉장고 전체촬영 (실제 이미지 인식 AI 연동 필요 — 어떤 비전 API를
  쓸지는 아직 미정)
- 회원가입 시 프로필 사진 업로드, 게시글 사진 첨부 (둘 다 Supabase Storage 연동 필요 — 현재는 사진을
  골라도 서버에 저장되지 않음)

디자인 목업은 `UI디자인_v3.html` 파일을 참고하면서 화면별로 하나씩 구현하면 됩니다.
