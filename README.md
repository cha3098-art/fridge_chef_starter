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
2. 이 폴더를 열고 터미널에서:
   ```
   flutter pub get
   flutter run
   ```
3. Supabase 연동하려면:
   - [supabase.com](https://supabase.com)에서 프로젝트 생성
   - SQL Editor에서 `supabase_schema.sql` 실행
   - `lib/main.dart`의 주석 처리된 Supabase 초기화 코드에 URL/anon key 입력 후 주석 해제

## 다음에 만들어야 할 화면 (우선순위)
1. 재료 등록 (검색 / 사진인식 / 영수증스캔)
2. 추천 리스트 + 필터 바텀시트
3. 레시피 상세 + 영양정보
4. 공유하기(초대/자랑)

디자인 목업은 `UI디자인_v3.html` 파일을 참고하면서 화면별로 하나씩 구현하면 됩니다.
