# Rune Puzzle Tactics — 화면 설계서 (Portrait)

> 기준: `lib/screens/rune/*.dart` 현재 구현. 모든 px는 **logical pixel**.
> 전 화면 Portrait 고정 (`SystemChrome.setPreferredOrientations([portraitUp, portraitDown])`).
> 이 문서를 보고 손으로 UI를 다시 코딩할 수 있도록 배치도·스펙·키·l10n 을 모두 명시했다.

---

## 0. 공통 디자인 토큰

### 0.1 컬러 (`lib/theme/app_theme.dart`)

| 토큰 | 값 | 용도 |
|---|---|---|
| `bgMain` | `#12131C` | 화면 배경 중간 |
| 배경 그라데이션 | `#1E2130 → #12131C → #0B0C12` (top→bottom) | 허브/전투/결과 공통 |
| `cardDark` | `#201D3D` | 다이얼로그 카드 |
| `cardDark2` | `#221F42` | 리스트 카드 |
| `cardTop` | `#1B183B` | 헤더/탭 배경 |
| `glassCard` | `#26FFFFFF` | 약한 글래스 |
| `glassCardStrong` | `#33FFFFFF` | 칩/버튼 글래스 |
| `glassBorder` | `#40FFFFFF` | 글래스 테두리 |
| `accent` / `accentGold` | `#FFB300` | 브랜드 골드 (선택/강조) |
| `ctaGradStart→End` | `#FF7E5F → #FF2525` | Primary CTA 그라데이션 |
| `glowNeon` | `#66FF2525` | CTA 외곽 글로우 |
| `playCoinBlue` | `#69B8FF` | Play 재화 |
| `danger` | `#FF6B6B` | HP 경고 / 패배 / 타임아웃 |
| `green` | `#2ED573` | 파티 HP |
| `orange` | `#FFA502` | 파티 만원 경고 |

### 0.2 속성 팔레트 (`RuneElement`)

| 속성 | 이모지 | 색 | 오토스킬 (10매치) |
|---|---|---|---|
| Fire | 🔥 | `#FF5722` | 룬 3칸 폭발 오브 |
| Grass | 🌿 | `#4CAF50` | 파티 최대 HP 15% 회복 |
| Water | 💧 | `#2196F3` | Black 룬 전량 정화 |
| Lightning | ⚡ | `#FFC107` | 타이머 +2초 |
| Poison | ☠️ | `#9C27B0` | 파티 공격력 ×2.0 |
| Black | ◼️ | `#16162B` | (오토스킬 없음) |

> **Light → Lightning 개명 (이름만 변경).** enum 식별자 `light`, 색 `0xFFFFC107`,
> 룬 에셋 `rune_row4.png`(x=188), 카드 배경 `card_yellow.jpg`, 초상화
> `light_face/full.png` 은 **그대로** 둔다 — 저장 데이터(`heroId`·보드 문자)와
> 기존 영장 호환을 끊지 않기 위해서다. 표시 문자열(`element_light`)만 바뀐다.

> **몬스터는 무속성이지만 상성은 스테이지 단위로 존재한다.**
> `StageConfig.weakElement`(×1.5) / `resistElement`(×0.5) 를 `StageGenerator` 가
> 5스테이지 주기로 배정한다(열세는 항상 약점의 바로 다음 속성 — 겹치지 않음이
> 구조적으로 보장된다). 상성 규칙의 단일 권위는 `StageConfig.affinityFor` 다.
>
> **시너지 배율표는 삭제됐다.** "그 속성 룬을 맞출 수 있는 영웅이 몇 명인가"를
> 0.6~1.6 배율표로 옮기면 같은 정보를 두 번 쓰게 된다. 그래서 인원수 자리에
> **공격력 합**(`BattleState.attackForElement`)이 데미지의 밑으로 들어갔고,
> `ElementAffinity` enum · `RuneElement.affinityAgainst` · 영웅 개인
> `affinityBonus`/`affinityResistance` 스탯도 함께 사라졌다.

### 0.3 라운드 / 타이포

```
appCardRadius   16      카드
appButtonRadius 16      버튼
appDialogRadius 24      다이얼로그
appPillRadius   50      알약형 칩
appSheetTopRadius      하단 시트 상단 24

Display   36 / w900 / glowNeon 그림자 2   결과 타이틀
Title     24 / w900 / letterSpacing 1.2   STAGE N (로비)
Title     22 / w900 / letterSpacing 1.2   STAGE N (준비 모달)
Title     18 / w900                       화면 제목 / 전투 STAGE N
Subtitle  15 / w900                       몬스터 이름
Body      13 / w600~w700                  본문
Caption   12 / w400                       보조
Micro      9 / w800 / w900                포트레이트 게이지 라벨
```

### 0.4 상수 (`RuneMeta`)

```
stageEntryCost     1        전투 1회 입장 비용 (Play)
maxStage          30        절대 상한
baseAttack         0        파티 공격력 = 영웅 스탯 합 + 영구 강화 (기초값 없음)
basePartyMaxHp     0        파티 최대 HP = 영웅 스탯 합 + 영구 강화 (기초값 없음)
dailyRewardPlay  10 / dailyRewardHero 10
rewardedAdPlay   10 / rewardedAdHero  10
maxPartySize      4        (HeroRoster)
blackDamage     10        Black 룬 3매치 기본 피해 (StageGenerator)
```

> `baseAttack` / `basePartyMaxHp` 가 0 이라는 게 중요하다 — 파티 수치는 전부
> **영웅 스탯 + 영구 강화**에서 나온다. 따라서 데미지 밸런스는 몬스터 HP/ATK 곡선과
> 스테이지 상성 배율(1.5 / 1.0 / 0.5) 두 축으로만 잡는다.

### 0.5 공통 규칙

- 방향: **Portrait 전용** (가로 잠금)
- 카드: `GlassSurface(blur: 0)` + `color: glassCard` + `border: glassBorder` (radius 16)
- Primary CTA: `GradientButton` — height 52, radius 16, `FF7E5F→FF2525`, `appNeonGlow` 외곽 그림자, 글자 16
- Secondary CTA: `OutlinedButton` — foreground `white70`, side `white24`, vertical padding 12~14
- 모든 여백: `EdgeInsets.all(16)` (리스트), `horizontal 16` (전투 HUD), `20` (결과)

### 0.6 데미지 공식 (속성 축 2개)

```
매칭 데미지 = (매칭 속성의 살아있는 영웅 ATK 합)   // BattleState.attackForElement
            × (1.0 + 0.20 × (콤보 − 1))          // 콤보 (DamageCalculator)
            × affinity(매칭 속성)                  // 약점 1.5 / 중립 1.0 / 열세 0.5

스킬 데미지 = (시전 영웅 개인 ATK) × ratio × affinity   // 콤보·시너지 없음

반격 데미지 = max(1, round(몬스터 ATK × 100 / (100 + 대상 DEF))) − 방어막
```

- 데미지 계산과 UI 배율 표시는 **반드시 같은 값**(`StageConfig.affinityFor`)을
  읽어야 한다. 두 곳이 따로 계산하면 표기가 어긋나고 플레이어가 숫자를 믿지 않게 된다.
- 매칭 데미지의 밑은 인원수가 아니라 **공격력 합**이다. 다른 색 룬을 맞히면 그 색
  영웅의 공격력은 전혀 반영되지 않는다 — 그래서 "어떤 색을 몇 명이나 맞추느냐"가
  곧 데미지다.
- 반격은 `100 / (100 + DEF)` **비례 감쇄**다. 예전 `ATK − DEF` 선형 차감은 탱커
  (DEF 18)의 피해를 1 로 바닥내고, 약한 영웅(DEF 5)에게도 풀 데미지가 그대로
  들어갔다. 두 문제가 동시에 사라진다.
- **밸런스 영향** (기존 대비): 다색 편성의 단일 색 매칭은 크게 약해진다(−59%),
  단색 편성도 약해진다(74 → 60). 반격은 DEF 에만 의존해 크게 증가한다
  (DEF 8: 4 → 11, DEF 18: 1 → 10). 몬스터 HP/ATK 재조정 여지는 남아 있다.

---

## 1. 라우팅 맵

```
/                 TitleView
/runeLobby        RuneMainScreen  ── 하단 탭 4개
    ├ tab 0 Lobby   RuneLobbyTab
    ├ tab 1 Party   RunePartyTab
    ├ tab 2 Shop    RuneShopTab
    └ tab 3 Settings RuneSettingsTab

RuneLobbyTab ──[Start Battle]──▶ StagePrepDialog (showDialog)
StagePrepDialog
  ├ cancel     → 로비 유지 (재화 미소모)
  └ confirm    → Play 1 차감 → pushNamed('/runeBattle', {stage, store, analytics})
                 (모달 안에서 파티를 직접 편집하므로 editParty 전이 없음)
/runeBattle     RuneBattleView → RuneBattleScreen
RuneBattleScreen ──승/패──▶ RuneResultScreen (1.5초 버퍼 후)
  ├ lobby → popUntil → RuneMainScreen tab 0
  ├ next  → Play 1 차감 → 같은 라우트에서 _stage+1 재생
  └ retry → Play 1 차감 → 같은 스테이지 재생
/runeTutorial   RuneTutorialView
```

---

## 2. S0 — 앱 셸 (`RuneMainScreen`)

```
┌───────────────────────────────────────────────┐
│  배경 그라데이션 #1E2130→#12131C→#0B0C12        │
│                                               │
│              IndexedStack(index)               │
│         (탭 0/1/2/3 중 하나만 그려짐)            │
│                                               │
├───────────────────────────────────────────────┤
│  AdBannerWidget        ← blur 밖 별도 패널     │  ← 12px bottom margin
├───────────────────────────────────────────────┤
│  ClipRRect(r24)                                │
│   └ BackdropFilter(blur σ12)                   │
│      └ NavigationBar(transparent)              │  ← 8px gap
│         0 Lobby   1 Party   2 Shop   3 Settings│
└───────────────────────────────────────────────┘
   padding: fromLTRB(12, 0, 12, 12)
```

| 요소 | 스펙 |
|---|---|
| 배경 | `Container(LinearGradient top→bottom)` |
| 본문 | `SafeArea` → (로딩 에러 / `CircularProgressIndicator` / `IndexedStack`) |
| Ad 배너 | `Container(glassCardStrong, r24, border glassBorder, clipBehavior antiAlias)` |
| 탭 바 | `Container(glassCardStrong, r24)` + `BackdropFilter(σ12)` + `NavigationBar` |
| 탭 인디케이터 | `AppColors.accentGold @ 22%` |
| PopScope | `canPop: false` → 탭 0이 아니면 탭 0으로, 0이면 2초 내 두 번 → `SystemNavigator.pop()` |

> **주의**: AdMob 배너는 `BackdropFilter(saveLayer)` 안에 두면 Android에서 렌더링 정지가 걸린다. **배너는 blur 밖**, 탭 바만 blur.

---

## 3. S1 — 로비 (`RuneLobbyTab`) ★핵심 화면

`ListView(padding: EdgeInsets.all(16))` — 세로 스크롤.

```
┌───────────────────────────────────────────────┐
│ ┌─ A. Top Bar (Currency Header) ────────────┐ │ ← mainAxisAlignment.end
│ │  💰 1,250    ⚡ 5 (+)    🦸 2 (+)    🎁 ●  │ │    (우측 정렬, 가로 스크롤 reverse)
│ └────────────────────────────────────────────┘ │    칩 사이는 8px
│                                    14px      │
│ ┌─ B. Stage Selector + CTA ──────────────────┐│
│ │  (‹)          STAGE 12           (›)      ││  ← StepButton 48×48 원형
│ │               3 / 30                        ││  ← 최고클리어 / maxStage
│ │                                             ││
│ │  ★ ALL STAGES CLEARED!   (maxStage 시만)    ││  ← 6px 아래, 8px 여백
│ │  ┌───────────────────────────────────────┐  ││
│ │  │  ▶  Start Battle (STAGE 12)          │  ││  ← GradientButton h52 전체폭
│ │  └───────────────────────────────────────┘  ││    key: start-battle
│ └────────────────────────────────────────────┘ │
│                                    14px      │
│ CURRENT PARTY                                 │ ← _SectionLabel 13 bold white70
│                                    8px       │
│ ┌────────────────────────────────────────────┐ │ ← GlassSurface(v14 h10)
│ │  (🔥)3 (🔥)3 (💧)1 (  +  )                  │ │    ← PartySlots 1×4 (속성 인원수)
│ └────────────────────────────────────────────┘ │
│                                    14px      │
│ PARTY STATS                                   │
│                                    8px       │
│ ┌────────────────────────────────────────────┐ │
│ │  Party ATK                      1,250     │ │ ← _StatRow: 라벨 white54 13
│ │  Party Max HP                   3,400     │ │            값 white 14 w700
│ │  Party  🔥 Fire 3명 · 💧 …                 │ │ ← 값 accent
│ └────────────────────────────────────────────┘ │
│                                    14px      │
│ UPGRADE LEVELS                                │
│                                    8px       │
│ ┌────────────────────────────────────────────┐ │
│ │  Game Currency Gain              Lv.3     │ │ ← 3개 (RuneUpgrades.all)
│ │  Party Attack                   Lv.2     │ │    간격 3px
│ │  Party Max HP                   Lv.2     │ │
│ └────────────────────────────────────────────┘ │
│                                    6px       │
│ ┌────────────────────────────────────────────┐ │
│ │  📈  View Permanent Upgrades              │ │ ← OutlinedButton v12
│ └────────────────────────────────────────────┘ │    key: lobby-permanent-upgrade
│                                    8px       │
└───────────────────────────────────────────────┘
```

### A. 재화 칩 규칙

| 칩 | 라벨 | `+` 아이콘 | 활성 조건 |
|---|---|---|---|
| Game | `currency_game {n}` | 없음 | 항상 활성(충전 불가) |
| Play | `currency_play {n}` | `add_circle` / `check_circle_outline` | 잔액 **0** 일 때만 활성 |
| Hero | `currency_hero {n}` | `add_circle` / `check_circle_outline` | **하루 1회** (00시 리셋) |
| 🎁 일일 보상 | 아이콘만 (`🎁` or `✓`) | — | 수령 가능 시 활성 + 우상단 빨간 점 |

- 비활성 = `Opacity 0.4`, 단 **탭은 유지** → "아무 반응 없음" 방지 스낵바
- Play 보유 중 탭 → `ad_play_owned`, Hero 오늘 완료 탭 → `ad_hero_daily_done`
- 칩 스펙: `UiPill(frame_pill_l)` 안에 투명 `Material` + `InkWell` + `Padding(h12 v7)`, 텍스트 `accent 13 w700`; 활성 상태는 액센트 골드 테두리

> 재화/일일 보상 칩도 `frame_pill_l` 스프라이트를 사용한다. `Material`/`InkWell`
> 탭 동작은 스프라이트 위젯 안쪽에 유지해 기존 상호작용을 보존한다.

### B. Stage Selector 규칙

```
stage     = clamp(_selectedStage ?? progress.nextStage, 1, progress.selectableMaxStage)
상한      = min(highestCleared + 1, 30)
‹ 활성     = stage > 1
› 활성     = stage < selectableMaxStage
진행도 문구 = "{highestCleared} / 30"     ← 선택 상한이 아니라 실제 클리어 수
```

### 파티 슬롯 규칙 (결정 3 — 🔒 폐지, `+` 로 통일)

파티 편성은 **전 화면이 `PartySlots` 위젯 하나를 공유**한다
(`lib/widgets/party_slots.dart`). 로비 · 파티 탭 · 전투 준비 모달이 각자 그리면
셋이 언제쯤 어긋난다. 배치는 `1×4` 고정, 슬롯 `size 52` / `spacing 6`.

```
편성된 슬롯 = HeroPortrait(size 52, showElementBadge: true)
              + 하단 배지 "{속성N}"  예: "3"  (9px w900 accentGold)
              배경 = black @ 62%, 아래쪽만 radius 999
              탭        → showHeroDetailDialog(영웅 상세)
              롱프레스  → showUnassignHeroDialog(해제 확인)
빈 슬롯   = "+" 카드 (Icons.add_circle_outline), glassCard 배경
              탭 → showHeroPickerSheet(영웅 선택 시트)
              파티가 4/4 면 비활성 + Tooltip(party_slots_full)
```

- 배지에는 **인원수만** 적는다. 배율을 곱하지 않는다 — 같은 속성의 공격력 합이
  이미 그 색 매칭 데미지의 밑(`BattleState.attackForElement`)이라 배율을 겹치면
  같은 정보를 두 번 말하게 되고, 숫자를 잘못 읽게 만든다.
- **전투 HUD 의 🔒 는 유지** — 전투 중에는 파티를 바꾸지 않는다.
  (`HeroPortrait.locked` 의 유일한 사용처)

---

## 4. S2 — 스테이지 준비 모달 (`StagePrepDialog`) ★핵심 화면

```
showDialog(
  barrierColor: black @ 72%
  barrierDismissible: true
  → Dialog(transparent, insetPadding: h20 v24)
    → ConstrainedBox(maxWidth: 420)
      → SingleChildScrollView
        → Container(cardDark, r24, border glassBorder, padding 18/12/18/18)
```

```
        ╔═══════════════════════════════════════════╗  ← 420 max
        ║  (✕)              STAGE 12              (i) ║  ← 22px w900 ls1.2
        ║              Flame Drake                    ║  ← 17px w900
        ║        불타는 야수 · 중급                     ║  ← 12px white54 (subtitle)
        ║                                           ║  ← 14px
        ║  MY ENTRY PARTY                         ║  ← 12px bold white70
        ║  ┌─────────────────────────────────────┐  ║
        ║  │ (🔥) (🔥) (🔥) (💧) (  +  )        │  ║  ← PartySlots 1×4
        ║  └─────────────────────────────────────┘  ║
        ║           약점 🔥        열세 🌿            ║  ← _MonsterAffinityRow 칩 2개
        ║  🔥 Fire 3명  |  💧 Water 1명              ║  ← 12px white60 중앙
        ║                                   12px  ║
        ║  ┌──────────────┐  ┌──────────────┐        ║  ← _MiniStat ×2
        ║  │ Party ATK    │  │ Party Max HP │        ║    r10, glassCard
        ║  │ 1,250        │  │ 3,400        │        ║    라벨 11 white54
        ║  │              │  │              │        ║    값 15 w900 white
        ║  └──────────────┘  └──────────────┘        ║
        ║                                   14px  ║
        ║  ┌─────────────────────────────────────┐  ║  ← playCoinBlue @12%
        ║  │ Entry Cost: 🎟 1        보유: 5     │  ║    border @40%, r12
        ║  └─────────────────────────────────────┘  ║    부족 시 보유 text danger bold
        ║                                   16px  ║
        ║  ┌─────────────────────────────────────────┐  ║
        ║  │           ▶ 전투 출격 ▶                  │  ║  ← GradientButton
        ║  └─────────────────────────────────────────┘  ║
```

### 헤더 버튼 스펙

```
_CircleIconButton: IconButton 38×38, circle, bg glassCard, border glassBorder,
                   icon 20px, padding 0, tooltip
  (✕) → key: stage-prep-close    → pop(cancel)
  (i) → key: stage-prep-info     → AlertDialog(몬스터 정보)
```

> **모달 안에서 파티를 직접 편집한다.** `_StagePrepCard` 는 Stateful 이고,
> `PartySlots` 를 그대로 넣어 `+` 탭 → `showHeroPickerSheet` 가 열린다.
> 별도 "파티 수정하기" 버튼으로 다른 탭에 튕기던 경로는 **삭제**됐다.
> `showStagePrepDialog(progress:, onChanged:)` 로 편성 변경이 부모까지 전파된다.

### 몬스터 정보 본문 (`stage_prep_info_body`)

"몬스터는 무속성이지만 스테이지마다 약점(×1.5)/열세(×0.5)이 있고, 매칭 데미지는
그 색 영웅의 공격력 합 × 콤보 × 상성" 으로 안내한다. 배율 수치를 문장에 복사하지
않고 `StageConfig` 상수를 단일 권위로 삼는다. 준비 모달 본문 위에는
`_MonsterAffinityRow` 칩 두 개가 이미 약점/열세 속성을 직접 보여준다.

### 반환값 2종

| 값 | 트리거 | 재화 | 다음 |
|---|---|---|---|
| `cancel` | ✕ / 바깥 탭 | 미소모 | 로비 유지 |
| `confirm` | [전투 출격 ▶] | **Play 1 차감** | `pushNamed('/runeBattle')` |

> [전투 출격] 은 잔액이 부족하면 `onPressed: null` (글래스 회색 + 글로 없음).

---

## 5. S3 — 전투 화면 (`RuneBattleScreen`) ★핵심 화면

```
LayoutBuilder(constraints) → Stack
└─ Column
   ├─ ① Top Bar
   ├─ ② HUD Rows
   ├─ ③ Expanded → Align(0, 0.08) → AspectRatio(1) → Board Area
   └─ SizedBox 8
```

### ① Top Bar — `padding(h12, v6)`

```
┌───────────────────────────────────────────────┐
│  (48)        STAGE 12            ⏸           │
│              NORMAL                            │  ← boss면 "BOSS (n)", elite면 ELITE
└───────────────────────────────────────────────┘
   좌측 48px 공백(균형)   중앙 STAGE N 18px w900 ls1
                          서브 12px white54      우측 IconButton 일시정지
```

### ② HUD Rows — `padding(horizontal 16)` · `AnimatedBuilder(_hud + _timerTick)`

```
┌───────────────────────────────────────────────┐
│              Flame Drake                      │  15px w900 white ls0.6 중앙
│                                               │  ← 6px
│            (🔥 WEAK)   (💧 RESIST)            │  _AffinityChip ×2, padding h8 v3, r999
│                                       6px     │  텍스트 11 w800 · 약점 accent / 열세 white38
│              🟥 Monster 850/1000             │  폭 110, label 10, bar 8px danger
│              ▓▓▓▓▓▓▓▓▓▓▓░░░░                 │  r6, track black38
│                                       4px     │
│                                               │
│              [ MonsterSprite ]               │  높이 = clamp(screenH × 0.20, 72, 140)
│                                               │  ← 8px
│  ╭─────────────────────────────────────────╮ │  _SwapTimerBar
│  │ TIMER  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░      3       │ │  padding h10 v6, r pill
│  ╰─────────────────────────────────────────╯ │  10px        8px        8px   34px
│                                      10px     │  TIMER 10px w800 white54
│                                               │  bar 8px  ·  숫자 14 w900 tabular
│  ┌──────────────────┬──────────────────┬───┐ │  ≤3초 → danger 색
│  │ 🛡 Party 850/100 │ ▓▓▓▓▓▓▓▓▓░ 90%  │🌀 x2│ │  활성 아님 → "—" white24
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓░░  │                  │   │ │  ← 10px
│  └──────────────────┴──────────────────┴───┘ │
│                                       10px    │
│     (🔥)     (🔥)     (🔥)     (💧)     (🔒)  │ ← _HeroPortraitHud
│     3/10     3/10     9/10     1/10           │    slot width 54, spaceEvenly
│     ▓▓▓░    ▓▓▓░    ▓▓▓▓▓▓▓▓▓  ▓░            │    portrait 40, gauge h4
└───────────────────────────────────────────────┘
```

### 타이머 바 규칙 (One Swap Decision Timer)

```
remaining = _battle.remainingSeconds      // 절대 데드라인 기준
total     = stage.playerActionTime
active    = 플레이어 턴 && !paused

색:  remaining > 3  → accentGold
     remaining ≤ 3  → danger
숫자: remaining.ceil()   ← "3"은 "2.x 초 남음"을 의미
갱신: 100ms Timer.periodic (Flame 루프와 독립)
드래그 중에도 정지하지 않음 (절대 시각)
일시정지 중 remaining 은 동결 → resume 시 now + t_remaining
```

### 포트레이트 HUD 규칙 (1×5 + 오토스킬)

```
슬롯 폭 54px
 ├─ HeroPortrait(40)
 │   ├─ border: ready ? accentGold : 속성색  (2px)
 │   ├─ dimmed: !active  (opacity 0.45, border 1px)
 │   └─ overlay: _GaugeOverlay (h4, black@55% 배경, chargeRatio 폭)
 ├─ 2px
 └─ 11px 라벨
       charge < 10 → "{charge}/10"        9px w800 white38
       charge = 10 → "{이모지} {스킬명}"    9px w900 accentGold  (FittedBox)
                     예) "🔥 폭발오브" / "💧 Black 정화" / "🌿 회복"
                         "⚡ 시간 +2초" / "☠️ 중독"
잠금 슬롯: HeroPortrait.locked(40) + 11px 공백 (정렬 유지)
           ★ 전투 중에는 파티 편성이 불가 → 여기가 🔒 의 유일한 남은 사용처
```

> `_UnitSlot` / `_HeroPortraitHud` 의 `weakness` 필드와 `_SynergyTag`(×N 배율
> 태그) 는 **둘 다 삭제**됐다. 배율을 붙일 정보 자체가 사라졌기 때문이다 —
> 같은 속성의 공격력 합이 곧 데미지이므로 인원수 배율은 중복 계산이었고, 상성은
> 몬스터가 아니라 **스테이지**가 정해 몬스터 HP 바 위 칩 두 개로 공개한다.
>
> 세로 순서도 **스킬 캡션 → HP 바 → 초상화** 로 바뀌었다. 예전에는 정보행이
> 초상화 아래에 있어서 룬 보드와의 사이에 34px 빈 띠를 만들었다. 정보를 위로 올리면
> 그 간격이 사라지고 "체력이 줄었으니 위험하다"가 화면 위쪽에서 먼저 읽힌다.
> 잠금 슬롯도 같은 순서/높이를 그대로 쓴다.

### ③ 보드 영역

```
AspectRatio(1)  →  GameWidget(RuneBattleGame)  ← Flame 렌더
  Flame 내부: _boardPx = min( max(64, min(vw,vh) - 24), 450 )   ★ 420~450px 클램프
             _tile   = _boardPx / 6
입력 잠금: AbsorbPointer(absorbing:
             !_ready || paused || inputLocked ||
             phase ∈ {resolving, monsterTurn, timeout, victory, defeat, retreat})
흑백 전환: !isPlayerTurn && !playbackActive → ColorFiltered(gray) + black45
          key: board-gray-overlay
```

### 오버레이 4종 (Stack 위에 순서대로)

| 오버레이 | 조건 | 내용 |
|---|---|---|
| Notice 배너 | `_notice != null` (1.4초) | `⏱ 시간 초과!` — danger 테두리, `top` SafeArea, scale 0.85→1.0 |
| Ready 카운트다운 | `!_ready` (1.5초) | `black@72% + BackdropFilter(σ8)` + "Ready... GO!" 42px |
| Result 버퍼 | `_resultPhase != null` (1.5초) | 승/패 오버레이 (VICTORY 44px / DEFEAT) |
| Pause | `_paused` | `black@72% + blur σ8` + "일시정지" 22 + [▶ 재개] 220px GradientButton + [🏠 로비로] |

---

## 6. S4 — 결과 화면 (`RuneResultScreen`)

```
PopScope(canPop: false) → 뒤로가기는 '로비로'와 동일
Scaffold > Container(그라데이션) > SafeArea > Padding(all 20)
> Column(crossAxisAlignment: stretch)
```

```
┌───────────────────────────────────────────────┐
│                                               │ ← Spacer(flex 1)
│  ████████ VICTORY ████████                   │  ShaderMask 그라데이션
│              36px w900 + neon glow            │  승: FFD97A→accentGold→FF7E5F
│                                               │  패: danger→B71C1C
│        STAGE 12 CLEAR                         │  15px white70, 6px
│                                      14px     │
│  ╭─────────────────────────────────────────╮ │
│  │ ⚡   Game Currency            +120     │ │  20px w900 accent
│  ╰─────────────────────────────────────────╯ │  실패 시 "0" white54
│                                      14px     │
│  ╭─────────────────────────────────────────╮ │
│  │ PARTY SUMMARY            ATK 1,250     │ │  13 bold white70 / accent
│  │                                 8px     │ │
│  │ 🔥 Fire          N=3        x9.0       │ │  16px / w70 / N= 12 white54
│  │ 💧 Water         N=1        x1.0       │ │  배율 13 w900 accent
│  │ ⚡ Lightning    N=1        x1.0       │ │
│  ╰─────────────────────────────────────────╯ │
│                                               │ ← Spacer(flex 2)
│  ┌─────────────────────────────────────────┐ │ ← OutlinedButton v14
│  │  🏠  Go to Lobby                        │ │    key: result-lobby
│  └─────────────────────────────────────────┘ │    ★ 항상 먼저
│                                      10px     │
│  ┌─────────────────────────────────────────┐ │
│  │  ▶  Next Stage ▶                        │ │ ← 승리 GradientButton h52
│  └─────────────────────────────────────────┘ │    key: result-next
│           또는                                │
│  ┌─────────────────────────────────────────┐ │
│  │  ↺  Retry (Play 1)                      │ │ ← 패배 GradientButton h52
│  └─────────────────────────────────────────┘ │    key: result-retry
│                                      8px     │
└───────────────────────────────────────────────┘
```

### 버튼 규칙 (사양 2-3)

```
승리: [Go to Lobby]  OutlinedButton  +  [Next Stage ▶]        GradientButton (Primary)
패배: [Go to Lobby]  OutlinedButton  +  [Retry (Play 1)]      GradientButton (Primary)
❌ [Go to Shop] 버튼은 승/패 모두에서 제거됨
   (상점은 재화 부족 다이얼로그의 '상점' 선택과 로비 2번 탭으로만 진입)

[Next]/[Retry] 탭 → playCurrency 사전 검증
  부족 → showPlayShortageDialog
     'ad'   → showRewardedAdOnce() → onRewardAdPlay() → 재시도
     'shop' → _exitToHub('shop') + onShopRequested?.call()
     취소   → 결과 화면 유지
```

---

## 7. S5 — 파티 편성 탭 (`RunePartyTab`)

```
ListView(padding 16)
┌───────────────────────────────────────────────┐
│  파티 편성                        3/5         │  18 w900 accent / 14 (만족 시 orange)
│  파티에 편성할 영웅을 선택하세요                 │  12 white38, 6px
│                                      12px     │
│ ┌──────────────────────────────────────────┐ │
│ │ 🔥 FIRE            보유 4 · 편성 2 · 4x  │ │ ← _ElementHeader
│ │   (🔥)Kael      파티                     │ │    _HeroRow: HeroPortrait(40)
│ │                    [ 편성 해제 ]          │ │    + 이름/속성/스탯
│ │   (🔥)Ember     미보유                   │ │
│ │                    [ 편성 ]              │ │    key: assign-hero-<id>
│ │ 🌿 GRASS          보유 3 · 편성 1 · 1x  │ │    key: unassign-hero-<id>
│ │   ...                                    │ │
│ │ 💧 WATER / ⚡ LIGHTNING / ☠️ POISON         │ │ ← RuneElement.normal 순서
│ └──────────────────────────────────────────┘ │
│                                      14px     │
│  영웅은 상점에서 광고 보상으로 영입할 수 있습니다  │  12 white38
└───────────────────────────────────────────────┘
```

페이지 탭: `[파티]`(page 0) → 속성 5개 (page 1~5, `party-page-<n>`).

### 7.1 [파티] 페이지 = `PartySlots` + 속성 집계 한 줄

`[파티]` 페이지는 **카드 그리드를 두지 않는다.** 로비 · 전투 준비와 **똑같은
`PartySlots` 위젯 1×4** 만 놓고, 그 아래 속성 집계 한 줄만 붙인다. 영웅 목록은
속성 페이지가 이미 보여주고 있으므로 중복시킨다.

```
PartySlots(progress, onChanged)   ← 로비/전투 준비와 인스턴스가 동일
        +
partyElementLine(l10n, progress)   // "🔥 Fire 3명  |  💧 Water 1명"
                                   // 편성된 속성만 노출 (0명 속성은 데미지 0이라 잡음)
```

- 보유 0명이면 슬롯 대신 `party_empty_hint` 문구만 노출한다.
- 속성 페이지의 `_HeroGrid` 는 `reserve` 인자를 **없앴다** — `+` 카드는
  `PartySlots` 가 전담하고, 여기선 편성/해제 버튼(`assign-hero-<id>` /
  `unassign-hero-<id>`)과 상세 팝업(`hero-detail-open-<id>`)만 남긴다.
- 편성 확인은 속성 페이지에서만 **확인 다이얼로그**를 거친다
  (`confirmAssignHero` → `party-assign-confirm-<id>`). `+` 슬롯 경로는
  확인 없이 즉시 편성된다 (명시적 버튼이 아니라 "넣고 싶다"는 클릭이라
  한 번 더 묻는 게 마찰).

---

## 8. S6 — 상점 탭 (`RuneShopTab`)

```
SingleChildScrollView(padding 16)  ← ListView 아님 (전체 실체화 필요)
┌───────────────────────────────────────────────┐
│  상점                  💰 1,250   🦸 2        │  18 w900 accent / _CurrencyChip ×2
│                                      12px     │
│  영구 업그레이드                               │  13 bold white70
│                                      8px      │
│ ┌──────────────────────────────────────────┐ │
│ │  Game Currency Gain            Lv.3/10  │ │ ← _UpgradeCard
│ │  게임 재화 획득량 +5%                      │ │    r16 glassCard
│ │  현재: 15% → 20%              100 💰     │ │
│ │                              [ Lv UP ]  │ │    key: buy-upgrade-<id>
│ └──────────────────────────────────────────┘ │    key: buy-upgrade-partyAttack
│                                    10px      │    key: buy-upgrade-partyMaxHp
│  ← 3개 (RuneUpgrades.all)                    │
│                                      14px     │
│  아이템                                       │
│ ┌──────────────────────────────────────────┐ │
│ │  🌀 Shuffle                 보유 2       │ │ ← _ItemCard
│ │  보드를 재배열합니다            50 💰     │ │    key: buy-item-<type>
│ │                              [ 구매 ]    │ │
│ └──────────────────────────────────────────┘ │    key: buy-item-shuffle
│                                    10px      │    key: buy-item-clearRune
│  ← 2개                                        │
│                                      14px     │
│  영웅 영입                                     │
│ ┌──────────────────────────────────────────┐ │
│ │  🔥 FIRE                                  │ │
│ │   (🔥)Kael    미보유         [ 영입 100🦸] │ │ ← _HeroRow
│ │   (🔥)Ember   보유          [ 소유 중 ]  │ │    key: recruit-hero-<id>
│ └──────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘

구매 실패 → SnackBar
   필요 재화 부족: shop_error_game {n}
   MAX 레벨:      shop_error_max_level
```

---

## 9. S7 — 설정 탭 (`RuneSettingsTab`)

```
ListView(padding 16)
┌───────────────────────────────────────────────┐
│  설정                                         │  18 w900 accent
│                                      12px     │
│ ┌──────────────────────────────────────────┐ │
│ │  튜토리얼                                  │ │  13 bold white70
│ │  ┌────────────────────────────────────┐  │ │
│ │  │ 🎓  튜토리얼 다시보기              │  │ │  key: replay-tutorial
│ │  └────────────────────────────────────┘  │ │
│ │  ───────────  (Divider white12 h1) ───── │ │  12px 위아래
│ │  언어                                      │ │
│ │  현재 언어: 한국어      [ 🌐 변경 ]        │ │  key: select-language
│ │  ───────────  (Divider white12 h1) ───── │ │  선택 즉시 적용 (재시작 없음)
│ │  데이터                                    │ │
│ ┌──────────────────────────────────────┐  │ │
│ │  🗑  진행도 초기화                    │  │ │  danger foreground
│ └──────────────────────────────────────┘  │ │  key: reset-progress
│ └──────────────────────────────────────────┘ │  danger @50% border
│                                      16px     │
│              Rune Puzzle Tactics v1.0        │  11 white24 중앙
└───────────────────────────────────────────────┘
```

---

## 10. 재사용 위젯 레퍼런스

### 10.1 `HeroPortrait` (`lib/widgets/hero_portrait.dart`)

```
HeroPortrait(hero, size=48, dimmed, overlay, borderColor, showElementBadge)
HeroPortrait.locked(size, overlay)

  Opacity(dimmed ? 0.45 : 1.0)
   └ UiFrame.square1/square2(size × size, bg cardDark, 테두리 = base 색)
      └ Stack(expand, Clip.none)          ← 배지 넘침 때문에 클립 off
         ├ content:
         │   1) portraitAssetPath != null → Image.asset(errorBuilder: → 2)
         │   2) 속성색 @22% 배경 + 속성 이모지 (fontSize = size × 0.52)
         │   3) locked → "🔒" (size × 0.42) + white@6% 배경
         ├ showElementBadge → 우상단 속성 이모지 뱃지 (UiFrame.square1, size × 0.24)
         └ overlay → Positioned(bottom) 하단 전체폭 오버레이

locked 는 전투 HUD 의 빈 출전 슬롯 전용이다. 파티 편성 빈 자리는 🔒 가 아니라
`+` 다 (PartySlots).
```

> 테두리는 `Container(border: Border.all)` → `UiFrame` 9-slice 스프라이트로 교체됨
> (`lib/widgets/ui_frame.dart`). `dimmed` 신호는 테두리 굵기(2px↔1px)였고 이제
> 스프라이트 2벌(`square1`/`square2`)이 그 역할을 한다. 스프라이트는 16x16 이라
> 화면이 커도 테두리가 1px 로 유지된다(9-slice 코너는 항상 1:1).
>
> `PartyPortraitGrid` 와 그 내부 `_SynergyBadge` 는 **삭제**됐다.
> `PartySlots` 가 그 자리를 넘어선다 (아래 10.5).

### 10.5 `PartySlots` (`lib/widgets/party_slots.dart`) — 파티 편성 단일 진실

```
PartySlots(progress, onChanged, size=52, spacing=6,
           onHeroTap?, onHeroLongPress?, onEmptyTap?)
  Row(1×4)
   ├─ 편성됨 → InkWell(onHeroTap)
   │          HeroPortrait(size, showElementBadge: true, overlay: _ElementCountBadge)
   │          _ElementCountBadge = "{N}" 9px w900 accentGold   ← 배율 없음
   │                            black@62% 배경, 아래쪽만 r999
   │          LongPress → onHeroLongPress
   └─ 빈 자리 → InkWell(onEmptyTap ?? 비활성)
              "+" 카드 (Icons.add_circle_outline, glassCard, accentGold 1.5 border)
              Tooltip: party_slots_full (4/4 일 때)

사용처: 로비 · 파티 탭 [파티] 페이지 · 전투 준비 모달 (3곳 전부)
```

### 10.6 `lib/widgets/party_editor.dart` — 파티 편성 플로우 공용 헬퍼

```
heroDisplayName(l10n, hero)        // 영웅 고유 이름 ("엠버", "마리스" …)
partyElementLine(l10n, progress)    // "🔥 Fire 3명  |  💧 Water 1명"
showHeroPickerSheet(ctx, progress, onChanged)   // ← `+` 슬롯 진입점
showUnassignHeroDialog(ctx, hero, progress, onChanged)  // 롱프레스 해제 확인
confirmAssignHero(ctx, hero, progress, onChanged)        // 속성 페이지 편성 확인
```

`showHeroPickerSheet` = `showModalBottomSheet(isScrollControlled, backgroundColor:
transparent)` → `GlassBottomSheet` → 헤더(`party_picker_title` +
`party_picker_counter`) → 4열 `GridView`(shrinkWrap, `childAspectRatio 0.62`) →
`party_picker_hint`. 타일은 `HeroPortrait(56×66)` + 표시명 + 편성 중이면
`party_picker_assigned` 배지 + `dimmed`. **탭 즉시 편성** (확정 버튼 없음).

> `lib/widgets/` 는 `lib/screens/` 을 import 하지 않는다. 영웅 상세 팝업 같은
> 화면 전용 동작은 호출부가 람다로 넘긴다.

### 10.2 `_HpBar` / HP Bar 규칙

```
label(10 compact / 12 normal, white70)  "{label}  {value} / {max}"
1~2px
UiBar(
  value: hp / maxHp,
  height: compact 8 / normal 12,
  trackColor: black38,
  fillColor: danger(몬스터) / green(파티),
)
```

> `ClipRRect + LinearProgressIndicator` → `UiBar` 로 교체됨(`lib/widgets/ui_bar.dart`).
> 트랙/채움/테두리를 9-slice 스프라이트 3장으로 쌓는다. 층 순서는
> `트랙 → 채움 → 껍데기` — 껍데기를 맨 위에 두어야 값이 작아도 테두리가 안 가려진다.
> 반경은 스프라이트에 구워져 있어 `LinearProgressIndicator` 처럼 높이마다 라운드를
> 따로 줄 수 없다.

### 10.3 `GradientButton` (Primary CTA 규칙 1)

```
height 52 · radius 16 · fontSize 16
활성: LinearGradient(FF7E5F → FF2525) + appNeonGlow 외곽 shadow
비활성: glassCardStrong 단색 + white38 텍스트 + 글로 없음
구조: Container(decoration) > Material(transparent) > Ink(gradient) > InkWell > Row(icon 20 + 8 + Flexible(Text))
```

### 10.4 `GlassSurface`

```
GlassSurface(padding, blur)
  → blur > 0 ? BackdropFilter(σ) : Container
  bg glassCard · radius appCardRadius(16) · border glassBorder
```

### 10.7 UI 크롬 스프라이트 규칙 (`lib/theme/ui_sprites.dart`)

`Container(border: Border.all(...))` 로 그리고 있던 **테두리만** 9-slice PNG로
바꾼다. 채움색·`BoxShadow`·그라데이션·`BackdropFilter` 는 그대로 Flutter `Color`
다 — 9-slice 로 늘리면 그림자가 두께만큼 부풀고, 효과는 색이 아니다.

| 위젯 | 치환 대상 | 파일 |
|---|---|---|
| `UiFrame` | `Border.all` 프레임 (초상화/속성탭/영웅슬롯/가차카드/빈슬롯 + 대형 패널 10곳) | `lib/widgets/ui_frame.dart` |
| `UiPill` | `r999` 칩·배지 (로비 재화/보상 포함) | `lib/widgets/ui_pill.dart` |
| `UiBar` | `ClipRRect + LinearProgressIndicator` 5곳 | `lib/widgets/ui_bar.dart` |

스프라이트는 `tool/gen_ui_sprites.py` 가 만든다(Pillow). 규칙:

1. **선만** 그린다. 내부 투명, 선은 흰색 고정 → `srcIn` 틴트로 임의 색 인스턴스.
2. **앤티에일리어싱 없음.** 앱이 `FilterQuality.none` 을 쓴다.
3. **스프라이트 크기 ≤ 요소 최소 렌더 크기.** 9-slice 코너는 항상 1:1 이라
   작게 잡을수록(그리고 화면이 클수록) 테두리 굵기가 그대로 1px 다. 반대로
   크게 잡으면 작은 요소에서 전체가 축소 렌더링되며 0.5px 로 죽는다.
4. **centerSlice 중심 밴드 폭·높이 > 0.** Flutter `Slice` 가 `src → dst` 로
   나누므로 0 이 나오면 죽는다. pill 반경은 `(H-1)/2` 로 잡아 이 함정을 피한다.
5. **위젯이 바뀌면 인접 픽셀 알파가 스미딩된다.** 테두리를 넣을 때
   `UiFrame.insets` 를 테두리 두께만큼 줘야 내용이 테두리 위에 안 걸린다
   (`UiPill`은 `padding` 이 그 역할을 한다).
6. **슬라이스 상단 = 반경 이상이어야 한다.** 라운드 프레임의 코너 호가 상단
   밴드에 통째로 들어 있어야 한다(`frame_round24` = 52px, 슬라이스 24). 캡
   스프라이트도 예외가 아니다.
7. **부분 테두리는 전용 캡 규격으로.** 9-slice 는 "테두리가 없는 변" 을 못
   표현한다 → 상단 밴드(코너 호 + 수평선) / 하단 밴드(좌우 세로선)로 나눈다
   (`sheet_cap_top` = 52x52, 슬라이스 `LTRB(24, 24, 28, 50)`).
8. **크기가 고정된 원은 9-slice 대상이 아니다.** `_CircleIconButton`(38x38)은
   슬라이스를 이미지 전체로 두고 통째로 스케일한다(`circle_ring_38`).

### 10.8 규격 ↔ 사용처 (9-slice 반경과 최소 크기)

| 스프라이트 | 규격 | 슬라이스 | 최소 대상 크기 | 사용처 |
|---|---|---|---|---|
| `frame_square_1/2/3` | 16x16 각진 1/2/3px | 4,4,12,12 | 8px (이모지 배지) | 초상화·속성탭·영웅슬롯 |
| `frame_square_4` | 20x20 각진 4px | 5,5,15,15 | 10px | 카드 아트워크 폴백 외측 링 |
| `frame_round4_1` | 16x16 r4 1px | 4,4,12,12 | 8px | `GlassSurface` 내부 (호출 8장) |
| `frame_round6_2` | 24x24 r6 2px | 8,8,16,16 | 16px | `PartySlots` 빈 `+` 슬롯 |
| `frame_round12_1` | 36x36 r12 1px | 12,12,24,24 | 24px | 입 재화 칩(38) · `_PullButton`(60) |
| `frame_round14_1` | 40x40 r14 1px | 14,14,26,26 | 28px | 튜토리얼 안내 카드 |
| `frame_round24_1` | 52x52 r24 1px | 24,24,28,28 | **48px** | 출격준비 다이얼로그 · 하단 네비바 · AdMob 패널(50) |
| `circle_ring_38` | 38x38 원 1px | (전체) | 38px 고정 | `_CircleIconButton` |
| `sheet_cap_top` | 52x52 r24 1px 상단만 | 24,24,28,50 | 50px | `GlassBottomSheet` |
| `tile_frame` / `tile_frame_sel` | 32x32 타일 프레임 | `kUiTileSlice` | 룬 그리드 타일 | 일반/선택된 룬 타일 |
| `frame_pill_s/m/l` | 24x12 / 32x20 / 48x36 | 크기별 pill 분할 | 작은 배지 / 보통 칩 / 큰 칩 | 룬 타일 배지 / HUD·상점·영웅 상세 / 로비 재화·보상 및 가차 합계 |
| `bar_track/fill/shell` | 32x8, r2 | 8,2,24,6 | 높이 3px 이상 | 전투 HUD 및 상점 HP·진행률 바 |

`frame_round24_1` 가 52 인 이유: 슬라이스가 반경(24) 이상이어야 하므로 최소
50px 이고, 대상 중 가장 낮은 AdMob 배널 패널의 높이가 정확히 50 이다. 64 로
잡으면 0.78 배로 줄 테두리가 뭉개진다.

### 10.9 큰 패널을 스프라이트로 옮길 때의 함정

- **`StackFit.expand` 는 피한다.** 패널 높이가 콘텐츠로 결정되는 곳(바텀시트)
  에서 `expand` 면 높이가 무한대 제약을 받아 `Column` 이 터진다 → `loose`.
- **`Padding` 원인이면 `insets` 로 옮긴다.** `UiFrame.insets` 가 곧
  `Padding(padding: insets)` 다. 원래 `padding` 이 없던 곳(AdMob 패널·네비바)
  은 `EdgeInsets.zero` 를 명시해야 한다 — 기본값(두께만큼)이 레이아웃을
  바꾼다(AdMob 이 50 → 48 로 줄어든다).
- **`Material` 을 지우면 잉크가 죽는다.** 테두리만 옮기고 채움색을 프레임으로
  바꾼 곳은 `Material(color: Colors.transparent)` 를 남겨야 스플래시가 그려진다
  (상점 `_PullButton`, 속성탭, `_CircleIconButton`).
- **클립 반경과 스프라이트 반경이 같아야 한다.** 바텀시트는 바깥
  `ClipRRect(r24)` + 스프라이트 r24 이 일치해야 코너에 틈이 안 생긴다.
- **`BackdropFilter(saveLayer)` 안의 9-slice 는 안전하다.** 레이어 복사가 필요한
  것은 AdMob **플랫폼 뷰** 다(Gradients/BoxShadow 는 반대로 9-slice 로 옮기지
  못한다 — 두께만큼 부풀어 오간다).

스프라이트 경로/분할 상수는 `ui_sprites.dart` 한 곳에 모아뒀다 — 교체 시 거기만
고치면 된다.

---

## 11. l10n 키 cheatsheet (5개 언어 동시 유지: en/ko/ja/zh-Hans/zh-Hant)

```dart
// 로비
currency_game/play/hero {n}   ad_reward_play/hero {n}   ad_reward_granted {n}
ad_play_owned   ad_hero_daily_done   ad_load_failed
daily_reward_title/desc {play}{hero}   daily_reward_claim
lobby_battle_start {n}          // "Start Battle (STAGE {n})"
lobby_stage_prev/next           lobby_stage_progress {cleared}
lobby_max_stage_banner
lobby_current_party             lobby_party_stats
lobby_party_base_attack         lobby_party_max_hp
lobby_upgrade_levels
battle_monster_weak/resist      // 몬스터 상성 칩 (전투 HUD · 전투 준비 모달)
party_count_unit {n}            // 속성 인원수 표기 ("3" / "3명")
lobby_view_upgrades
common_stage {n}                // "STAGE {n}"
common_cancel   common_retry

// 준비 모달
stage_prep_party  stage_prep_confirm
stage_prep_play_held {n}   stage_prep_info_body   stage_prep_title
entry_cost_label {n}          // "입장 비용: 🎟 {n}"

// 파티 편성 (공용 — widgets/party_editor.dart)
party_slot_add_tooltip   party_slots_full   party_synergy_none
party_picker_title  party_picker_counter {total}{max}
party_picker_assigned  party_picker_empty  party_picker_hint
party_unassign_confirm_title  party_unassign_confirm_message {hero}
party_assign_confirm_title/_message {hero}   party_assign_yes  party_assign_no
party_empty_hint                 // "상점 탭에서 영웅을 영입하세요"
hero_name_<heroId>              // 영웅 고유 이름 (hero_name_fire_a …)

// 전투
hp_monster  hp_party
battle_type_normal  battle_type_elite  battle_type_boss {n}
battle_pause_tooltip  battle_paused  battle_resume  battle_go_lobby
battle_ready_go
battle_timer_label             // "TIMER" / "제한시간"
battle_notice_timeout          // ⏱ 타임아웃 배너
// battle_synergy_hint 는 삭제 — 배율표가 없어졌고 상성은 칩으로 직접 보인다.

// 결과
result_victory  result_defeat
result_clear {n}  result_defeated {n}
result_game_win  result_game_loss
party_summary  result_attack {n}
result_btn_lobby        // "로비로 이동"
result_btn_next {n}     // "다음 스테이지 ▶"  (파라미터 미사용)
result_btn_retry {n}    // "재도전 (Play {n})"
result_btn_shop         // (버튼 제거됨, 키 유지)

// 탭
nav_lobby  nav_party  nav_shop  nav_settings
party_title  party_desc  party_counter {total}{max}
party_recruit_hint  party_in_party  party_tab_all  party_empty_hint
shop_title  shop_upgrades_header
gacha_header  gacha_single  gacha_ten  gacha_cost {n}  gacha_confirm
gacha_rates_header  gacha_codex_progress {owned}{total}
gacha_badge_new  gacha_badge_promote  gacha_badge_max
gacha_promote_to {from}{to}  gacha_empty_pool
gacha_error_hero {n}  gacha_error_hero_count {n}{count}
rarity_r  rarity_sr  rarity_ssr  rarity_ur
shop_max_level  shop_owned_badge  shop_error_game {n}  shop_error_max_level
hero_codex_title  hero_codex_desc  hero_detail_open
upgrade_name_<id>  upgrade_desc_<id>
item_name_<type>   item_desc_<type>
settings_title  settings_section_tutorial  settings_replay_tutorial
settings_language  settings_language_current {name}  settings_language_select
settings_section_data  settings_reset_progress
settings_reset_dialog_title/msg  settings_reset_confirm  settings_footer
main_reset_done  main_load_error  exit_confirm
```

> ⚠️ 키 추가 규칙: `lib/l10n/app_strings.dart` 의 `_en` / `_ko` / `_ja` **3개 테이블에 반드시 동일 키로 추가**. 현재 각 287개로 동기화 완료.
>
> 삭제된 키: `weakness_label` / `weakness_label_short` / `weakness_hero_required` /
> `affinity_cycle_hint` / `stage_prep_edit_party` /
> `tutorial_title_weakness` / `tutorial_msg_weakness`
> (`affinity_same|advantage|neutral|disadvantage` 는 `rune_result_screen` 이
> `affinity_${relation.name}` 로 동적 조회하므로 **유지**한다.)

---

## 12. ValueKey cheatsheet (테스트/자동화)

```
로비       start-battle                lobby-permanent-upgrade
           stage-prev   stage-next
준비 모달   stage-prep-dialog  stage-prep-confirm
           stage-prep-close  stage-prep-info
전투       board-gray-overlay   item-slot
           battle-hero-0 … battle-hero-3        // 정원 4 (구 battle-synergy-chip 삭제)
결과       result-lobby  result-next  result-retry        (result-shop 제거)
파티       party-page-<n>                      // 0 = 전체, 1~5 = 속성
           assign-hero-<id>   unassign-hero-<id>
           hero-detail-open-<id>
           party-assign-confirm-<id>  party-assign-yes-<id>  party-assign-no-<id>
상점       buy-upgrade-<id>  buy-item-<type>  recruit-hero-<id>
설정       replay-tutorial  select-language  reset-progress
```

> `stage-prep-edit-party`, `party-hero-<id>`, `party-add-<id>`, `hero-add-<id>` 는
> **삭제**됐다 (파티 편성이 `PartySlots` + `showHeroPickerSheet` 로 이관).

---

## 13. 손코딩 추천 순서

| 순서 | 화면 | 선행 조건 |
|---|---|---|
| 1 | `HeroPortrait` + `PartySlots` + `party_editor` | 없음 (모든 화면의 선행 요소) |
| 2 | 앱 셸 `RuneMainScreen` (탭 바) | 셸 없으면 탭 전환 불가 |
| 3 | S6 상점 → S7 설정 (간단한 리스트) | `RuneProgress` API |
| 4 | S5 파티 편성 | 1, `HeroPool` / `RuneProgress.partyCount` |
| 5 | S1 로비 (Top Bar → Stage Selector → 슬롯 → 스탷) | 1, 2 |
| 6 | S2 준비 모달 | 1, 5 |
| 7 | S3 전투 HUD (타이머 · 포트레이트) — 보드 제외 | 1, `BattleState` |
| 8 | S3 보드 (Flame) | 7 |
| 9 | S4 결과 | `RuneProgress.recordClear` |

---

## 14. 주의할 함정 7가지

1. **AdMob 배너는 `BackdropFilter` 밖** — 안에 넣으면 Android 실기에서 화면 멈춤/검정 렌더링
2. **Flame은 계산하지 않는다** — 오토스킬/데미지는 `BattleResolveResult` 에 이미 계산돼 있고, `RuneBattleGame` 은 `cascadeSteps` → `autoSkillEvents` → 데미지 → `monsterAttackEvent` 순으로 **재생만** 한다
3. **속성 축은 두 개다** — `attackForElement`(그 색 ATK 합)과 `StageConfig.affinityFor`(1.5/1.0/0.5). 인원수 배율을 다시 얹으면 같은 정보를 두 번 쓴다
4. **타이머는 절대 시각** — 드래그/홀드 중에도 정지하지 않는다. 일시정지만 동결 후 재개
5. **`AbsorbPointer` vs `IgnorePointer`** — 해석 중 스크롤/제스처 전파까지 막아야 하므로 `AbsorbPointer`
6. **`RuneLobbyView` 는 `RuneMainScreen` 의 typedef** — 라우트/테스트가 참조하므로 삭제 금지
7. **상성 배율은 `StageConfig.affinityFor` 단일 권위** — 데미지 계산(`DamageCalculator`)과 UI 칩이
   각자 1.5 를 하드코딩하면 표기가 어긋나고 플레이어가 숫자를 믿지 않게 된다. 밸런스 조정도
   `StageConfig.weakAffinity` / `resistAffinity` 상수에서만 한다.
