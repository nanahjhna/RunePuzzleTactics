# Rune Puzzle Tactics — 카드 아트 AI 생성 프롬프트

작성 일시: 2026-10-08
기준: `report/card_art_assets.txt` 의 16개 에셋 / 밝은 판타지 모바일 RPG 컨셉

---

## 1. 사용법 (공통)

### 스타일 앵커 (모든 이미지에 붙이는 꼬리)

```
bright fantasy mobile RPG background art, clean painterly render,
soft volumetric light, saturated jewel tones (gold amber, sky blue,
emerald green, rose pink), light bloom, no watermark, no logo, no text
```

아래 16개 프롬프트는 이 앵커가 이미 포함된 **완성형**이다.
필요에 따라 밝기·채도를 한 단어로 조절: `soft pastel`(파스텔 톤) /
`vivid saturated`(선명 고채도) / `golden hour warm`(따뜻한 황금 광).

### 도구별 메모

| 도구 | 팁 |
|---|---|
| Midjourney | 프롬프트 끝에 `--ar 16:9 --no text, watermark, logo` 추가. 광각(2:1 초과)은 지원 범위를 벗어나므로 **가장 넓은 비율로 생성 후 크롭** |
| SDXL / Flux | 프롬프트 그대로 사용하고, **negative prompt**: `text, watermark, logo, letters, low quality, blurry, deformed` |
| Niji | 애니메이션풍. `--style cute` 같은 옵션으로 밝기 보정 가능 |

### 비율 원칙

우리 위젯(`CardArt`)은 `BoxFit.cover` 로 늘려 쓰므로 **정확한 비율이 아니어도 된다.
최종 화면 비율보다 넓게 생성 → 자동 크롭**이 기본 전략이다.
권장 생성 비율은 각 항목의 `--ar` 칸에 표기했다.

---

## 2. A. 전체 배경 (Fill — 카드 전체를 덮는 아트) 11장

### A1. `cardart_lobby_stage.png` — 로비 스테이지 카드 (640×360, ≒16:9, `--ar 16:9`)

```
grand sunlit castle gate on a floating island, golden morning light,
fluttering banners, distant snow mountains, blue sky with soft clouds,
wide composition with an empty sky area on top for UI overlay,
bright fantasy mobile RPG background art, clean painterly render,
soft volumetric light, saturated jewel tones, light bloom,
no characters, no text, no watermark, no logo
```

### A2. `cardart_lobby_party.png` — 로비 파티 요약 카드 (768×176, `--ar 2:1` 크롭)

```
party journey banner, winding meadow path toward a distant floating
castle, buttercup field, soft noon light, light lens bloom, ultra-wide
horizontal strip, calm empty middle band for text overlay,
bright fantasy mobile RPG background art, clean painterly render,
saturated jewel tones, soft volumetric light, no characters,
no text, no watermark, no logo
```

### A3. `cardart_result_reward.png` — 결과 보상 카드 (768×160, `--ar 2:1` 크롭)

```
overflowing open treasure chest with golden coins and glowing purple
gems, sparkle particle bursts, warm stage light, sun rays, ultra-wide
strip, soft darker vignette at the bottom for text overlay,
bright fantasy mobile RPG background art, clean painterly game
illustration, saturated jewel tones, light bloom, no characters,
no text, no watermark, no logo
```

### A4. `cardart_result_party.png` — 결과 파티 요약 카드 (768×384, 2:1, `--ar 2:1`)

```
victory celebration scene, three hero silhouettes raising weapons
before a radiant sunset, confetti and light sparkles, triumphant
banner, saturated warm palette, bottom area softly darkened for UI
text, bright fantasy mobile RPG background art, clean painterly
render, soft volumetric light, light bloom, no text, no watermark,
no logo
```

### A5. `cardart_result_damage.png` — 데미지 분석 카드 (768×512, 3:2, `--ar 3:2`)

```
elemental clash of a fire sword vs water spear with light blue energy
sparks, dynamic diagonal composition, glowing particles, flashy clean
mobile game action art, calm darker area on the left for stats text,
bright fantasy mobile RPG background art, saturated jewel tones,
light bloom, no characters, no text, no watermark, no logo
```

### A6. `cardart_result_stats.png` — 영웅 스탯 카드 (768×384, 2:1, `--ar 2:1`)

```
glowing magic tome with rising star constellation and rainbow ribbons,
floating gem shards, soft celestial light, empty top-left area for
stats text, bright fantasy mobile RPG background art, clean painterly
UI art, saturated jewel tones, light bloom, no characters, no text,
no watermark, no logo
```

### A7. `cardart_settings.png` — 설정 그룹 카드 (512×768, 2:3 세로, `--ar 2:3`)

```
cozy sunlit village plaza with windmill, fountain and flower beds,
afternoon summer light, gentle depth, portrait vertical composition,
upper area softly bright for UI panels, bright fantasy mobile RPG
background art, clean painterly render, saturated jewel tones,
light bloom, no characters, no text, no watermark, no logo
```

### A8. `cardart_shop_gacha.png` — 상점 뽑기 패널 (512×512, 1:1, `--ar 1:1`)

```
ornate golden treasure chest on a summon pedestal with sparkling
colored light beams (red, green, blue, gold) bursting upward,
magical particles, radiant sky, center emphasis, bright fantasy
mobile RPG background art, clean painterly render, saturated jewel
tones, light bloom, no characters, no text, no watermark, no logo
```

### A9. `cardart_main_nav.png` — 하단 탭바 (1024×192, `--ar 21:9` or 16:9 크롭)

```
dreamy pastel gradient sky with tiny stars, clouds and floating light
motes, extremely wide horizontal band, soft and calm so icons stay
readable, low contrast, bright fantasy mobile RPG background art,
clean painterly render, light bloom, no characters, no text,
no watermark, no logo
```

### A10. `cardart_hero_detail.png` — 영웅 상세 다이얼로그 (512×704, `--ar 2:3`)

```
four elemental orbs (fire red, grass green, water blue, gold) orbiting
a radiant center, magical ring patterns, portrait vertical
composition, luminous but soft, subtle darker panel behind the middle
for the hero card, bright fantasy mobile RPG background art, clean
painterly render, saturated jewel tones, light bloom, no characters,
no text, no watermark, no logo
```

### A11. `cardart_gacha_dialog.png` — 가챠 결과 다이얼로그 (512×640, `--ar 4:5`)

> 반투명 Material **뒤**에 깔리므로 다른 아트보다 밝게/진하게 생성해도 된다.

```
brilliant golden light burst with card-shaped rays and rainbow glow,
confetti stars, sparkling festive particles, celebratory clean effect
art, bright fantasy mobile RPG background art, saturated jewel tones,
light bloom, no characters, no text, no watermark, no logo
```

---

## 3. B. 헤더 밴드 (Header — 상단 96px 밴드) 5장

> 모두 1024×256, 화면에는 상단 96px 만 보이고 아래는 fade.
> **상단에 포인트를 몰고, 아래 절반은 단순하게** 두면 fade 후에도 어색하지 않다.

### B1. `cardart_header_party.png` — 파티 편성 프레임 (`--ar 21:9` 크롭)

```
heraldic cloth banner with four element crests (flame, leaf, droplet,
sun) in gold embroidery, bunting flags across the top, soft morning
sky, wide header band, bottom edge gently fades to background color,
bright fantasy mobile RPG background art, clean painterly render,
saturated jewel tones, light bloom, no characters, no text,
no watermark, no logo
```

### B2. `cardart_header_codex.png` — 영웅도감 프레임 (`--ar 21:9` 크롭)

```
open illuminated magic tome with glowing illustrations and gold leaf
edges, sparkles rising from the pages, warm library light, wide header
band, bottom edge gently fades out, bright fantasy mobile RPG
background art, clean painterly render, saturated jewel tones,
light bloom, no characters, no text, no watermark, no logo
```

### B3. `cardart_header_tutorial.png` — 튜토리얼 안내 카드 (`--ar 21:9` 크롭)

```
cheerful wooden signpost and a scroll with golden ribbon, floating
sparkle icons, bright welcoming meadow, wide header band, bottom edge
fades out, no readable letters, bright fantasy mobile RPG background
art, clean painterly render, saturated jewel tones, light bloom,
no characters, no text, no watermark, no logo
```

### B4. `cardart_header_stage_prep.png` — 출격 준비 다이얼로그 (`--ar 21:9` 크롭)

```
heroic battle pennant flag fluttering on a castle watchtower, morning
wind, blue sky, gold trim, adventurous mood, wide header band, bottom
edge fades out, bright fantasy mobile RPG background art, clean
painterly render, saturated jewel tones, light bloom, no characters,
no text, no watermark, no logo
```

### B5. `cardart_header_sheet.png` — 영웅 선택 바텀시트 (`--ar 21:9` 크롭)

```
sparkling starry sky with shooting stars and floating lamp spirits,
magical scout banner, dreamy blue-purple pastel, wide header band,
bottom edge fades out, bright fantasy mobile RPG background art, clean
painterly render, saturated jewel tones, light bloom, no characters,
no text, no watermark, no logo
```

---

## 4. 적용 시 유의사항

### ① 가독성 (밝은 아트 × 흰 텍스트)

현재 더미 아트는 **낮은 알파(200~240) + 어두운 카드색**에 의존해서 흰 텍스트를
살린다. 밝은 실아트로 바꾸면 흰 텍스트가 묻힐 수 있다. 대응 방법 2가지:

- **`opacity` 파라미터로 낮추기** — `CardArt.fill(..., opacity: 0.65)`,
  `CardArtBackdrop(..., opacity: 0.65)` 처럼 위젯 인자만 조정하면 어두운
  카드 배경색과 섞여 텍스트가 살아난다. (`opacity` 기본값 1, 위젯에서 지원)
- **프롬프트에 스크림 넣기** — `soft dark scrim at bottom/edges for text` 를
  추가해 이미지 자체에 어두운 여백을 만든다.

### ② 모서리 라운드 마스크

현재 16장은 **모서리 알파 0 + 라운드 마스크가 이미지에 굽혀** 있다.
AI로 생성한 사각 이미지를 그대로 덮으면 카드 모서리가 각져 보인다.
생성 이미지에는 아래 중 하나를 한다:

- **같은 규격으로 모서리 페이드 처리 후 교체**, 또는
- `opacity` 를 1 미만으로 두고 카드 배경색 위에 얹어 경계를 흐린다.

### ③ 교체 방법 (코드 수정 최소화)

1. `assets/ui_dummy/cardart_*.png` 를 같은 이름/비율로 덮어쓴다
   (또는 `lib/theme/ui_sprites.dart` 의 `kCardArt*` 경로 문자열만 변경).
2. 각 화면의 `art:` 인자/`CardArtBackdrop` 호출부는 **건드릴 필요 없음**.
3. 헤더형(`cardart_header_*`)은 **상단 1/3에 포인트**를 배치한 이미지를 쓰면
   fade 없이도 밴드로 잘린다.

### ④ 크롭 기준 (파일명 ↔ 화면 비율)

| 파일명 | 픽셀 | 화면 비율 | 생성 `--ar` 권장 |
|---|---|---|---|
| cardart_lobby_stage.png | 640×360 | 16:9 | 16:9 |
| cardart_lobby_party.png | 768×176 | 4.4:1 | 2:1 → 크롭 |
| cardart_result_reward.png | 768×160 | 4.8:1 | 2:1 → 크롭 |
| cardart_result_party.png | 768×384 | 2:1 | 2:1 |
| cardart_result_damage.png | 768×512 | 3:2 | 3:2 |
| cardart_result_stats.png | 768×384 | 2:1 | 2:1 |
| cardart_settings.png | 512×768 | 2:3 | 2:3 |
| cardart_shop_gacha.png | 512×512 | 1:1 | 1:1 |
| cardart_main_nav.png | 1024×192 | 5.3:1 | 21:9 or 16:9 → 크롭 |
| cardart_hero_detail.png | 512×704 | ~2:3 | 2:3 |
| cardart_gacha_dialog.png | 512×640 | 4:5 | 4:5 |
| cardart_header_party.png | 1024×256 | 4:1(밴드) | 21:9 → 상단 크롭 |
| cardart_header_codex.png | 1024×256 | 4:1(밴드) | 21:9 → 상단 크롭 |
| cardart_header_tutorial.png | 1024×256 | 4:1(밴드) | 21:9 → 상단 크롭 |
| cardart_header_stage_prep.png | 1024×256 | 4:1(밴드) | 21:9 → 상단 크롭 |
| cardart_header_sheet.png | 1024×256 | 4:1(밴드) | 21:9 → 상단 크롭 |

---

## 5. 생성 체크리스트

- [ ] A1~A11 저장 후: 화면 비율에 맞게 크롭 (위 표 기준)
- [ ] 헤더 5장은 상단 1/3 포인트 확인
- [ ] 알파 있는 PNG로 저장 (배경 합성이므로 JPG 금지)
- [ ] `CardArt` 화면에서 흰 텍스트 가독성 확인 → 필요 시 `opacity` 조정
- [ ] 교체 후 `flutter analyze` (경로 상수 수정 시에만 필요)