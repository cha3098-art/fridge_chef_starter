# 냉장고 셰프 — 숏폼 광고 영상 프롬프트
## Video 2: "1:1 Cooking Battle" (9:16, ~10s)

---

## Voiceover Script (witty, fast-read, competitive tone, ~10s total)

```
[VO - Energetic, competitive male or female voice, hype-commentator cadence]

"Two cooks. One fridge full of random leftovers. Ten minutes on the clock.
Fridge Chef turns your leftovers into a real 1-on-1 cook-off — votes, points, bragging rights, all live.
Got random ingredients? Go start a battle."
```

**타이밍 가이드**
- 1문장 = 0–3s ("clock"에서 VS 슬램 임팩트와 정확히 싱크)
- 2문장 = 3–7s (투표 카운트가 올라가는 리듬에 맞춰 빠르게)
- 3문장 = 7–10s (CTA 버튼 등장과 동시에 "start a battle" 발화)

---

## Scene 1 — 0:00–0:03s (AI-generated, Runway/Kling)

```
SHOT: Vertical 9:16, hard split-screen down the center. Left: young man in his kitchen, phone on a stand, chopping vegetables fast, competitive glance at his screen. Right: young woman in her kitchen, same setup, stirring a pan quickly. Both confident, energetic. A bold mint-cyan "VS" badge slams into center-frame with a scale-bounce + screen-shake impact. Below it, a small soft-gold pill badge reads "In progress · Votable" briefly.
DURATION: exactly 3 seconds.
CAMERA: static split-screen, impact shake only on the VS slam.
COLOR GRADE: warm off-white base (#F8FAFC), mint-cyan (#2AC1BC) dominant accent, soft carrot-orange (#FF5B1F) secondary energy accent.
NEGATIVE PROMPT: no aggressive/violent imagery, no dark neon esports look, no blood/weapons metaphors.
```

---

## Scene 2 — 0:03–0:07s (REAL SCREEN RECORDING — compositing, not AI-generated)

이 구간은 AI 생성 대신 **실제 앱 화면 녹화본을 폰 목업에 합성**합니다. 아래는 녹화부터 합성까지 그대로 따라 할 수 있는 지침입니다.

### ① 녹화할 실제 화면 (순서대로)
1. `battle_screen.dart`에서 매칭 성사된 배틀 상세 화면 진입 — 상하로 두 참가자 카드(사진 + 코멘트 + 투표 버튼)가 보이는 상태
2. 하단 참가자의 투표 버튼(🗳️ 아이콘) 탭 — 탭 순간 아이콘이 체크(✓)로 바뀌고 투표 수(`voteCount`)가 1 올라가는 실제 애니메이션
3. 상단 카드의 투표 수도 별도로 올라가는 순간 (다른 테스트 계정으로 미리 투표해두거나, 두 번 녹화해서 편집으로 교차 편집)
4. D-Day 타이머 칩(`D-1` 등, `battle_screen.dart` 385–387행)이 보이는 프레임

### ② 녹화 방법
- 실기기 권장 (에뮬레이터 카메라/네트워크 이슈는 `PROJECT_PROMPT.md`의 "알려진 이슈" 참고), 60fps, 1080x2400 이상
- 투표 버튼 탭 전후 각 1초 여유 확보

### ③ 합성 지침
- 목업: Scene 1 배우들 중 한 명이 손에 들고 있는 각도의 클린 스마트폰 프레임 (Rotato/Placeit)에 화면 영역 마스킹 삽입
- 강조 연출: 투표 버튼 탭 프레임에서 0.15초 프리즈 → 체크마크 전환 시 팝(scale bounce) 강조를 After Effects에서 오버레이로 추가 (앱 자체 애니메이션에 편집단 강조 레이어를 얹는 방식)
- **실제 앱에는 두 카드 사이 게이지/비교 바가 없으므로**, 위아래 두 숫자(투표수)를 각각 크롭한 두 개의 화면 녹화 클립을 세로로 나란히 배치하고, 그 사이에 편집 프로그램(After Effects)에서 얇은 민트색 vs 카로트색 비교 바(tug-of-war bar)를 **별도 그래픽 레이어로 직접 애니메이션 제작**해서 얹으세요 — 이건 앱 UI가 아니라 광고 전용 모션 그래픽입니다.
- 사운드: 투표 탭 = 경쾌한 "팝" 사운드, 숫자 올라갈 때 = 슬롯머신 틱 사운드, 타이머 칩 = 낮은 긴장감 있는 tick

**DURATION: 4초 (실제 화면 녹화 + 합성, AI 생성 아님)**

---

## Scene 3 — 0:07–0:10s (AI-generated, Runway/Kling)

```
SHOT: Vertical 9:16. Fast zoom-punch radial-blur transition into a "Battle Complete" results card: a gold-pastel podium-style card slides up from the bottom, a small crown emoji 👑 pops onto the winning nickname with a bounce, and a gold-gradient tier badge levels up with a shimmer sweep ("Novice Chef → Home Chef"). The same mint-teal cube-shaped mascot (green leaf on top, pastel-mint door face, simple dot eyes, soft smile) hops in from the right wearing a small animated gold crown that wobbles into place, doing an excited double-hop with mint + gold confetti bursting behind it. Bold rounded mint-cyan text types on: "1:1 Battle with what's left in your fridge!" A bright mint-cyan CTA button scales in at the bottom with white bold text: "Start a Battle →" (same rounded-pill button style, size, and scale-in animation as the K-Food ad's CTA, for visual consistency across both ads). Hold final frame on the app logo with a soft pulse glow.
DURATION: exactly 3 seconds.
COLOR GRADE: warm off-white (#F8FAFC), mint-cyan (#2AC1BC), gold (#F59E0B) for crown/victory accents only.
CTA BUTTON SPEC (shared across both ads): rounded-pill shape, solid mint-cyan (#2AC1BC) fill, bold white sans-serif text, subtle drop shadow, scale-in-from-90%-to-100% pop animation over 0.25s.
NEGATIVE PROMPT: do not redesign the mascot, no unrelated leaderboard styles, no dark/neon tones, confetti colors limited to mint + gold only.
```

---

## 참고

Scene 2가 "AI 생성"이 아니라 "실제 녹화 + 합성"인 이유는, 실제 존재하지 않는 UI(투표 게이지 바 등)를 AI가 지어내면 지난번처럼 앱과 무관한 결과물이 나오기 때문입니다 — 대신 실제 화면을 그대로 쓰고, 없는 연출(비교 바, 강조 팝 등)만 편집 단계에서 모션그래픽으로 별도 추가하도록 명확히 분리했습니다.

---

## 🇰🇷 한글 버전 광고 문구 (더빙/자막용)

### 보이스오버 (한글 대본)

```
[내레이션 - 에너지 넘치고 경쟁적인 톤, 스포츠 캐스터 같은 속도감]

"요리사 두 명, 냉장고엔 애매하게 남은 재료들, 제한시간은 단 10분.
냉장고 셰프에서 진짜 1:1 요리 대결이 펼쳐져요 — 투표, 포인트, 자랑거리까지 전부 실시간으로.
애매하게 남은 재료 있으면? 지금 바로 배틀 걸어보세요."
```

**타이밍 가이드** (영문 버전과 동일한 비트 유지)
- 1문장 = 0–3s ("10분"에서 VS 슬램 임팩트와 싱크)
- 2문장 = 3–7s (투표 카운트 올라가는 리듬에 맞춰 빠르게)
- 3문장 = 7–10s (CTA 버튼 등장과 동시에 "배틀 걸어보세요" 발화)

### 화면 자막/텍스트 오버레이 (한글)

| 구간 | 영문 원본 | 한글 버전 |
|---|---|---|
| Scene 1 상태 배지 | "In progress · Votable" | "매칭 중 · 투표 가능" |
| Scene 3 티어 배지 | "Novice Chef → Home Chef" | "초급요리사 → 중급요리사" |
| Scene 3 헤드라인 | "1:1 Battle with what's left in your fridge!" | "냉장고 남은 재료로 1:1 배틀하자!" |
| Scene 3 CTA 버튼 | "Start a Battle →" | "배틀 시작하기 →" |

> 참고: "매칭 중 · 투표 가능"과 "초급요리사"/"중급요리사"는 실제 앱의 원문 그대로입니다([battle_screen.dart](lib/screens/battle_screen.dart) 385행, [tr.dart](lib/l10n/tr.dart)의 티어 사전 기준) — 한글판에서는 화면 녹화본을 영어 전환 없이 그대로 쓰면 자막과 자연스럽게 맞습니다.
