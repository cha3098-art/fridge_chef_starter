# 냉장고 셰프 — 숏폼 광고 영상 프롬프트
## Video 1: "K-Food Unit Conversion" (9:16, ~10s)

---

## Voiceover Script (witty, fast-read, ~10s total)

```
[VO - Bright, playful, quick-tempo female voice, slight comedic beat before the punchline]

"So you found the perfect Korean recipe... and it's basically written in code.
200 grams? Two big-spoons? Yeah, no.
Fridge Chef auto-translates AND converts every measurement — instantly. K-Food, unlocked."
```

**타이밍 가이드**
- 1문장 = 0–3.5s
- 2문장 = 3.5–5s (임팩트용 짧은 pause 포함)
- 3문장 = 5–10s ("instantly"에서 화면의 스파클 애니메이션과 정확히 싱크, "K-Food, unlocked."와 동시에 CTA 버튼 "Start Cooking →" 등장)

---

## Scene 1 — 0:00–0:03s (AI-generated, Runway/Kling)

```
SHOT: Vertical 9:16. Young Western woman on her couch, cozy apartment lighting, phone propped up showing a K-drama clip of sizzling bulgogi. She pauses it, leans in hungrily, then grabs a second phone and opens a food blog. Quick push-in zoom onto her phone screen: a recipe written in Korean, "소고기 200g, 간장 2큰술" visible. Hard zoom onto "200g" and "2큰술" with a subtle red shake/glitch effect and a small ❓ emoji pop-up. Her face shows confused frustration, head tilt. Color grade: warm off-white (#F8FAFC) background tones, no saturated primaries, soft naturalistic apartment lighting.
DURATION: exactly 3 seconds.
CAMERA: handheld phone-POV push-zoom, no pans.
NEGATIVE PROMPT: no other languages on screen besides Korean, no unrelated food, no logos.
```

---

## Scene 2 — 0:03–0:07s (REAL SCREEN RECORDING — compositing, not AI-generated)

이 구간은 AI 생성 대신 **실제 앱 화면 녹화본을 폰 목업에 합성**합니다. 아래는 녹화부터 합성까지 그대로 따라 할 수 있는 지침입니다.

### ① 녹화할 실제 화면 (순서대로)
1. `recipe_detail_screen.dart`에서 불고기류 레시피 상세 화면 진입 (한글 모드, 재료 리스트가 보이는 상태)
2. 우측 상단 언어 토글 캡슐 버튼(`한글` → `EN`) 탭 — 이 탭 순간이 핵심 클라이맥스
3. 탭 직후 화면 전체가 영어로 바뀌는 순간 (재료명 + 수량이 `trIngredientName()` / `localizedQuantity()`로 실시간 변환됨: "소고기 200g" → "Beef 7.05 oz", "간장 2큰술" → "Soy sauce 2 tbsp")
4. 하단 네비게이션에서 "K-Food" 탭으로 스와이프 진입, 카드에 걸린 금색 "2x Points" 펄스 배지가 보이는 프레임까지

### ② 녹화 방법
- Android 에뮬레이터: `adb shell screenrecord` 또는 Android Studio의 내장 스크린 레코더 사용 (실기기 권장 — 에뮬레이터는 프레임 드랍이 있어 애니메이션이 매끄럽지 않을 수 있음, `PROJECT_PROMPT.md`에도 명시된 이슈)
- 해상도: 최소 1080x2400, 60fps로 녹화해야 언어 전환 시 텍스트 크로스디졸브가 매끄럽게 보임
- 언어 토글 탭 전후 각 1초씩 여유를 두고 녹화 시작/종료 (편집 시 트리밍)

### ③ 합성(Compositing) 지침
- 툴: After Effects, Premiere Pro, 또는 CapCut(모바일 간편 버전) — 폰 목업 오버레이는 Rotato, Placeit, 또는 Figma의 무료 디바이스 목업 플러그인 사용 추천
- 배경: Scene 1의 마지막 프레임(그녀의 손) 위에 깨끗한 베젤리스 스마트폰 프레임을 얹고, 그 화면 영역에 방금 녹화한 영상을 마스킹하여 삽입
- 모서리: 목업의 화면 모서리 반경에 맞춰 녹화본에 corner radius mask 적용 (각지지 않게)
- 강조 연출: 언어 토글 탭 프레임에서 0.2초 정지(freeze-frame) 후 배속(1.5x) 재생으로 전환 임팩트 강조, 수량이 바뀌는 순간(200g→7.05 oz)에 민트색(#2AC1BC) 파티클/스파클 오버레이를 애프터이펙트로 별도 합성 (앱 자체엔 이 파티클이 없으므로 편집 단계에서 추가)
- 사운드: 토글 탭 = 짧은 "띡" 효과음, 텍스트 전환 = 부드러운 "쉬익" 스와이프 사운드

**DURATION: 4초 (실제 화면 녹화 + 합성, AI 생성 아님)**

---

## Scene 3 — 0:07–0:10s (AI-generated, Runway/Kling)

```
SHOT: Vertical 9:16. Whip-pan/zoom transition into an appetizing overhead shot of a finished, plated Korean bulgogi dish, steam rising, warm food-photography lighting. From the bottom of frame, a small rounded mint-teal cube-shaped mascot bounces into view — it has a tiny green leaf sprouting from its top-left corner, a lighter pastel-mint door panel on its face with simple black dot eyes and a soft curved smile. It does a happy bounce-in-place (squash and stretch) and gives a thumbs-up. Bold rounded mint-cyan (#2AC1BC) sans-serif text types on over a soft white card: "Master K-Food easily!" Smaller warm-gray subtext fades in below: "Fridge Chef — cook Korean food without the guesswork." A bright mint-cyan CTA button then scales in at the bottom with white bold text: "Start Cooking →" (same rounded-pill button style, size, and scale-in animation as the Battle ad's CTA, for visual consistency across both ads). Hold final frame on the app logo with a soft mint glow pulse.
DURATION: exactly 3 seconds.
COLOR GRADE: warm off-white background (#F8FAFC), mint-cyan accent (#2AC1BC), soft pastel mint (#E0F7F6).
CTA BUTTON SPEC (shared across both ads): rounded-pill shape, solid mint-cyan (#2AC1BC) fill, bold white sans-serif text, subtle drop shadow, scale-in-from-90%-to-100% pop animation over 0.25s.
NEGATIVE PROMPT: do not redesign the mascot, no other characters, no unrelated logos, no dark/neon tones.
```

---

## 참고

Scene 2가 "AI 생성"이 아니라 "실제 녹화 + 합성"인 이유는, 실제 존재하지 않는 UI를 AI가 지어내면 지난번처럼 앱과 무관한 결과물이 나오기 때문입니다 — 대신 실제 화면을 그대로 쓰고, 없는 연출(스파클 등)만 편집 단계에서 모션그래픽으로 별도 추가하도록 명확히 분리했습니다.

---

## 🇰🇷 한글 버전 광고 문구 (더빙/자막용)

### 보이스오버 (한글 대본)

```
[내레이션 - 밝고 위트있게, 빠른 템포, 마지막 문장에서 살짝 강조]

"완벽한 레시피를 찾았는데... 이건 뭐 암호문이네.
200그램? 큰술 두 개? 됐고요.
냉장고 셰프가 언어부터 계량 단위까지 한 번에 바꿔드려요. K-Food, 이제 안 어려워요."
```

**타이밍 가이드** (영문 버전과 동일한 비트 유지)
- 1문장 = 0–3.5s
- 2문장 = 3.5–5s
- 3문장 = 5–10s ("바꿔드려요"에서 스파클 애니메이션과 싱크)

### 화면 자막/텍스트 오버레이 (한글)

| 구간 | 영문 원본 | 한글 버전 |
|---|---|---|
| Scene 2 (실제 앱 UI) | 2x Points 배지 | 포인트 2배 |
| Scene 3 헤드라인 | "Master K-Food easily!" | "K-Food, 이제 쉽게 마스터하세요!" |
| Scene 3 서브텍스트 | "Fridge Chef — cook Korean food without the guesswork." | "냉장고 셰프 — 감으로 요리하지 마세요." |
| Scene 3 CTA 버튼 | "Start Cooking →" | "요리 시작하기 →" |

> 참고: Scene 2의 "포인트 2배"는 실제 앱의 원래 한글 문구([kfood_screen.dart](lib/screens/kfood_screen.dart) 33행 주석 기준)라 영문판/한글판 모두 화면 녹화본 그대로 쓰면 됩니다 — 이 자막만 별도로 바꿀 필요 없어요.
