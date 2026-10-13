/// Rune Puzzle Tactics — 9-slice UI 스프라이트 경로/슬라이스 중앙 정의.
///
/// **왜 Dart 에서 경로를 박지 않고 여기 모아두는가**
///
/// UI 프레임 PNG 는 나중에 실이미지로 교체할 예정이라, 경로 문자열이 여러
/// 파일에 흩어져 있으면 교체할 때마다 grep 이 필요했다. [HeroCard.gradeStars] 처럼
/// 경로를 맵으로 모으는 선례를 따라 여기 상수화했다.
///
/// 교체 절차: 아래 상수의 **경로 문자열**을 실이미지로 바꾸고, 그 이미지의
/// 첫 영점(=알파 0) 위치에 맞춰 **슬라이스 상수를 다시 잰다**. 이미지가
/// 안티에일리어싱 글로우 아트라 규격마다 첫 영점이 다르므로 슬라이스를 공유
/// 상수로 묶지 않는다. 나머지 호출 코드는 손대지 않는다.
///
/// [heroCardAssets]: ../widgets/hero_card.dart
library;

import 'dart:ui' show Rect, Size;

/// 공통 9-slice 코너. 32px 스프라이트 기준 8px (= 1/4).
///
/// 실제 아트가 48x48 로 오면 12px 로 바꿔야 한다. [kUiTileSlice] / [kUiBarSlice] 둘 다
/// 이 값에 맞춰져 있으므로 여기 한 곳만 고치면 된다.
const double kUiSliceCorner = 8;

/// 그리드 타일 외곽 프레임 — 일반 (미보유/보유).
const String kUiTileFrame = 'assets/ui_dummy/tile_frame.png';

/// 그리드 타일 외곽 프레임 — 선택/편성중. 테두리가 2px 이다.
const String kUiTileFrameSel = 'assets/ui_dummy/tile_frame_sel.png';

/// [kUiTileFrame] / [kUiTileFrameSel] 의 9-slice 분할.
///
/// 32px 캔버스에서 테두리 글로우가 index 6(선택본은 7)에 영점을 찍는다.
/// 여기선 8([kUiSliceCorner])로 잘라 여유를 둔다.
final Rect kUiTileSlice = Rect.fromLTRB(
  kUiSliceCorner,
  kUiSliceCorner,
  32 - kUiSliceCorner,
  32 - kUiSliceCorner,
);

// ═══════════════════════════════════════════════════════════════════════
// 아래 스프라이트들은 **테두리 전용**이다. RGB 는 흰색에 가깝고(244~255 그레이스)
// 내부는 투명해서 런타임 `srcIn` 틴트로 아무 색이나 인스턴스된다.
//
// **실아트로 교체되었다.** 예전 `tool/gen_ui_sprites.py` 가 만든 1비트
// (알파 0/255만) 딱딱한 선이 아니라, 안쪽으로 페더링되는 **앤티에일리어싱
// 글로우** 아트다. 테두리 두께만큼만 진하지 않고 5~9px 에 걸쳐 알파가
// 서서히 빠진다. 그래서 슬라이스 규칙이 바뀌었다.
//
//  1. **절단선은 `alpha == 0` 인 첫 인덱스에 둔다.** 글로우를 가로지르면
//     자르면 중심 밴드에 그라데이션이 남고, 그것이 화면 크기만큼 늘어나
//     내부 전체에 늘어진 헤이즈(밴딩)로 보인다.
//  2. **스프라이트마다 글로우 깊이가 다르다.** 아래 슬라이스 상수는 전부 각자
//     실측한 첫 영점 기준이라, 규격이 바뀔 때 스프라이트마다 다시 재야 한다.
//
// 슬라이스를 손댈 때의 절차는 `report/screen-design.md` §10.7 참고.
// ═══════════════════════════════════════════════════════════════════════

/// 각진 테두리 — 1px. 16x16, 반경 0.
///
/// **16px 로 잡은 이유**: 9-slice 는 코너/엣지 타일을 항상 1:1 로 그린다.
/// 스프라이트가 요소보다 작으면 모서리가 잘리지 않아 화면이 아무리 커도
/// 테두리 굵기가 1px 로 유지된다(초상화 130px 등). 32px 로 잡으면 작은 요소
/// (속성 이모지 배지 13px)에서 전체가 축소 렌더링되며 테두리가 0.5px 로 죽는다.
const String kUiFrameSquare1 = 'assets/ui_dummy/frame_square_1.png';

/// 각진 테두리 — 2px. 선택/편성중/강조 상태.
const String kUiFrameSquare2 = 'assets/ui_dummy/frame_square_2.png';

/// 각진 테두리 — 3px. 가차 공개 카드의 공개 상태.
const String kUiFrameSquare3 = 'assets/ui_dummy/frame_square_3.png';

/// 각진 테두리 — 4px. 카드 아트워크 폴백의 **외측** 링(안쪽은 2px 프레임).
const String kUiFrameSquare4 = 'assets/ui_dummy/frame_square_4.png';

/// [kUiFrameSquare1] 의 분할 — 16x16, 글로우 첫 영점 index 6.
const Rect kUiFrameSquare1Slice = Rect.fromLTRB(6, 6, 10, 10);

/// [kUiFrameSquare2] 의 분할 — 16x16, 글로우 첫 영점 index 7.
const Rect kUiFrameSquare2Slice = Rect.fromLTRB(7, 7, 9, 9);

/// [kUiFrameSquare3] 의 분할 — 16x16, 글로우 첫 영점 index 7.
///
/// 내부까지 알파 3 으로 채워져 있던 부분을 정리해 영점을 만든 뒤 여기서 자른다.
const Rect kUiFrameSquare3Slice = Rect.fromLTRB(7, 7, 9, 9);

/// [kUiFrameSquare4] 의 분할 — 20x20, 글로우 첫 영점 index 9.
const Rect kUiFrameSquare4Slice = Rect.fromLTRB(9, 9, 11, 11);

/// 라운드 테두리 — 반경 6, 2px. `PartySlots` 의 빈 `+` 슬롯.
const String kUiFrameRound6 = 'assets/ui_dummy/frame_round6_2.png';

/// [kUiFrameRound6] 의 9-slice 분할 — 24x24 기준 코너 8px(= 반경 6 이상).
const Rect kUiFrameRound6Slice = Rect.fromLTRB(8, 8, 16, 16);

/// 라운드 테두리 — 반경 4, 1px. `GlassSurface` 내부 프레임.
///
/// 8장의 `GlassSurface` 호출부는 전부 `radius` 를 지정하지 않아 기본값 8을 쓴다.
/// 내부 테두리 반경은 `radius / 2` = 4 라 이 규격 하나로 통일된다.
const String kUiFrameRound4 = 'assets/ui_dummy/frame_round4_1.png';

/// [kUiFrameRound4] 의 분할 — 16x16, 글로우 첫 영점 index 6(= 반경과 동일).
const Rect kUiFrameRound4Slice = Rect.fromLTRB(6, 6, 10, 10);

/// 라운드 테두리 — 반경 12, 1px. 입 재화 칩 / 상점 뽑기 버튼.
///
/// 36px 로 잡은 이유는 대상 최소 높이(입 재화 칩 ≈ 38px)보다 작게 잡아야
/// 모서리가 축소 렌더링되지 않기 때문이다.
const String kUiFrameRound12 = 'assets/ui_dummy/frame_round12_1.png';

/// [kUiFrameRound12] 의 분할 — 36x36 기준 코너 12px(= 반경과 동일).
const Rect kUiFrameRound12Slice = Rect.fromLTRB(12, 12, 24, 24);

/// 라운드 테두리 — 반경 14, 1px. 튜토리얼 안내 카드 전용.
const String kUiFrameRound14 = 'assets/ui_dummy/frame_round14_1.png';

/// [kUiFrameRound14] 의 분할 — 40x40 기준 코너 14px(= 반경과 동일).
const Rect kUiFrameRound14Slice = Rect.fromLTRB(14, 14, 26, 26);

/// 라운드 테두리 — 반경 24, 1px. `appDialogRadius` 를 쓰는 대형 패널
/// (출격준비 다이얼로그 / 하단 네비바 / AdMob 배널).
///
/// **52px 인 이유**: 슬라이스가 반경(24) 이상이어야 하므로 스프라이트는 최소
/// 50px. 대상 중 가장 낮은 게 AdMob 배널 패널(높이 정확히 50)이라 52가 최소
/// 손실(0.96배)이다. 64로 잡으면 0.78배로 줄어 1px 테두리가 눈에 띄게 뭉개진다.
const String kUiFrameRound24 = 'assets/ui_dummy/frame_round24_1.png';

/// [kUiFrameRound24] 의 분할 — 52x52 기준 코너 24px(= 반경과 동일).
const Rect kUiFrameRound24Slice = Rect.fromLTRB(24, 24, 28, 28);

/// 원형 테두리 — 반경 18.5, 1px. `_CircleIconButton` (38x38 고정 크기).
///
/// **슬라이스 자르기를 하지 않는다.** 이 원은 크기가 고정이라 9-slice 로
/// 나눌 이유가 없다. [kUiCircleRingSlice] 는 이미지 전체를 덮는 값이라
/// `Image.asset` 가 스케일만 하고 자르지 않는다.
const String kUiCircleRing38 = 'assets/ui_dummy/circle_ring_38.png';

/// [kUiCircleRing38] 전체(0,0,38,38). 자르기 아님 — 38x38 고정이라 통째로 쓴다.
const Rect kUiCircleRingSlice = Rect.fromLTWH(0, 0, 38, 38);

/// 상단 캡 — **위쪽에만** 테두리, 반경 24, 1px. 바텀시트(`Border(top:)` 대체).
///
/// 반경이 시트 라운드(`appSheetTopRadius` = 24)와 같아야 한다. 더 작으면
/// 바깥 `ClipRRect` 가 모서리를 잘라내며 테두리 호와 클립 호가 어긋나 틈이
/// 생긴다. 좌우 세로선이 생기는 건 의도된 변화다(옛 `Border(top:)` 는 좌우에
/// 선이 없었다).
///
/// 9-slice 로는 "테두리가 없는 아래변" 을 표현할 수 없다. 대신 위 밴드를
/// 반경(24)만큼 떼어 코너 호 + 수평선을 통째로 늘리고, 아래 밴드는 좌우
/// 세로선만 늘리게 만든다. → [kUiSheetCapSlice] 의 `top` 이 24 인 이유.
const String kUiSheetCapTop = 'assets/ui_dummy/sheet_cap_top.png';

/// [kUiSheetCapTop] 의 분할 — 52x52 기준 가로 코너 24 / 세로 위 24.
const Rect kUiSheetCapSlice = Rect.fromLTRB(24, 24, 28, 50);

// ── pill (칩/배지) ────────────────────────────────────────────────────────
//
// pill 은 반경이 **늘어나지 않는다**. 예전 `BorderRadius.circular(999)` 는
// 높이 9px 배지부터 높이 35px 가차 요약까지 모두 완전 둥근데, 스프라이트 하나로
// 통일하면 큰 칩이 각진 직사각형으로 degrade 된다. 그래서 실제 사용 높이
// 3단계에 맞춰 스프라이트를 3벌 만들었다. → `UiPillSize`

/// pill — 반경 5.5, 1px. 높이 약 9px (그리드 타일 배지).
const String kUiPillSmall = 'assets/ui_dummy/frame_pill_s.png';

/// pill — 반경 9.5, 1px. 높이 약 20px (HUD/상점/상세 칩).
const String kUiPillMedium = 'assets/ui_dummy/frame_pill_m.png';

/// pill — 반경 17.5, 2px. 높이 약 35px (가차 신정합계).
const String kUiPillLarge = 'assets/ui_dummy/frame_pill_l.png';

/// [kUiPillSmall] 의 분할 — 24x12 기준 코너 가로 6 / 세로 3.
const Rect kUiPillSmallSlice = Rect.fromLTRB(6, 3, 18, 9);

/// [kUiPillMedium] 의 분할 — 32x20, 글로우 첫 영점 index 6.
const Rect kUiPillMediumSlice = Rect.fromLTRB(6, 6, 26, 14);

/// [kUiPillLarge] 의 분할 — 48x36 기준 코너 가로 12 / 세로 9.
const Rect kUiPillLargeSlice = Rect.fromLTRB(12, 9, 36, 27);

// ── 바 ────────────────────────────────────────────────────────────────────

/// 바 껍데기 — 반경 2, 1px 테두리만(내부 투명).
const String kUiBarShell = 'assets/ui_dummy/bar_shell.png';

/// 바 배경(트랙) — 반경 2 단색. `srcIn` 틴트로 배경을 입힌다.
const String kUiBarTrack = 'assets/ui_dummy/bar_track.png';

/// 바 채움 — 반경 2 단색. [kUiBarTrack] 과 같은 규격이라 실루엣이 일치한다.
const String kUiBarFill = 'assets/ui_dummy/bar_fill.png';

/// 바 스프라이트의 실제 규격 (px). [kUiBarSlice] / [kUiBarBorder] 이 여기서
/// 파생되므로 규격을 명시한다 — 상수를 흩어 두면 언젠가 그림 크기만 바뀌고
/// 슬라이스가 뒤처진다.
const double kUiBarAssetWidth = 32;
const double kUiBarAssetHeight = 8;

/// [kUiBarShell] / [kUiBarTrack] / [kUiBarFill] 의 9-slice 분할.
///
/// 32x8 이고 반경이 2 다. **가로 코너는 3px / 세로 코너는 1px 만** 잡아
/// 여백을 (6, 2) 로 억제한다.
///
/// 예전엔 가로로 [kUiSliceCorner](8) 만큼씩 잘랐다. 그런데 9-slice 는
/// "그림 − 슬라이스" 만큼을 **양쪽 여백으로 소비**하는데, 8px씩 자르면
/// 여백이 가로 16px 로 커진다. 그 여백이 판 크기보다 크면 Flutter 가
/// `sourceSize == inputSize` assert 로 죽는다. 실제로 두 경계가 있다:
///
///  - **높이 3px 인 피티 진행바**([rune_shop_tab] 뽑기 패널) → 3 − 2 = 1 이라
///    살았지만, 예전 값(세로 2px씩 = 여백 4px)에서는 **3 − 4 = −1** 이라 터졌다.
///  - **값이 거의 찬 채움 판**(`width = w × value`) → 값이 작으면 판이 몇 px
///    밖에 안 돼 같은 assert 로 터진다. 260ms 동안 매 프레임 위험하다.
///
/// 여백을 최소로 줄이면 두 위험 구간이 함께 사라진다. 반경 2 캡을 온전히
/// 담는 데 가로 3px / 세로 2px 면 충분하므로 세로 1px(여백 2)도 안전하다.
const Rect kUiBarSlice = Rect.fromLTRB(
  3,
  1,
  kUiBarAssetWidth - 3,
  kUiBarAssetHeight - 1,
);

/// [kUiBarSlice] 가 **그림에서 소비하는 여백**(가로 합, 세로 합) = (6, 2).
///
/// 이 값 이하로 그려진 판은 9-slice 로 그릴 수 없다(위 assert). `UiBar` 가
/// 이 크기를 넘는지 확인해 못 넘으면 슬라이스를 빼고 통째로 늘린다.
const Size kUiBarBorder = Size(6, 2);

// ═══════════════════════════════════════════════════════════════════════
// 카드 아트 — 카드형 섹션 뒤에 깔리는 **더미 배경/헤더 이미지**
// ═══════════════════════════════════════════════════════════════════════
//
// `tool/gen_card_art.py` 가 만든 더미다. 화면의 카드형 섹션(글래스 카드 /
// 9-slice 프레임 패널 / 다이얼로그)이 이미지를 얼마나 먹는지 감을 잡기 위한
// 것이며, 실아트가 나오면 **경로 문자열만** 바꾸면 된다.
//
// **9-slice 가 아니다.** `BoxFit.cover` 로 늘려 쓰므로 슬라이스 재측정 없이
// 교체된다. 대신 이미지에 라운드 마스크와 가장자리 알파가 굽혀 있어 카드
// 모서리가 각져 보이지 않는다(프레임이 이미지를 클립해 주지 않기 때문).
//
// 층위 — 배경색 위 / 콘텐츠 아래:
//     카드 배경색 → [CardArt] → 9-slice 프레임 → 콘텐츠
//
// 사용처 매핑은 `lib/widgets/card_art.dart` 문서 참조.

/// 로비 통합 스테이지 카드(`rune_lobby_tab._StageCard`) 배경.
const String kCardArtLobbyStage = 'assets/ui_dummy/cardart_lobby_stage.png';

/// 로비 현재 파티 요약 카드 배경.
const String kCardArtLobbyParty = 'assets/ui_dummy/cardart_lobby_party.png';

/// 결과 화면 — Game Currency 보상 카드 배경.
const String kCardArtResultReward = 'assets/ui_dummy/cardart_result_reward.png';

/// 결과 화면 — 파티 요약(속성별 인원/공격력) 카드 배경.
const String kCardArtResultParty = 'assets/ui_dummy/cardart_result_party.png';

/// 결과 화면 — 데미지 분석 카드 배경.
const String kCardArtResultDamage = 'assets/ui_dummy/cardart_result_damage.png';

/// 결과 화면 — 영웅 개별 스탯 카드 배경.
const String kCardArtResultStats = 'assets/ui_dummy/cardart_result_stats.png';

/// 설정 탭 — 설정 그룹 카드 배경.
const String kCardArtSettings = 'assets/ui_dummy/cardart_settings.png';

/// 상점 탭 — 뽑기 패널(`_GachaPanel`) 카드 배경.
const String kCardArtShopGacha = 'assets/ui_dummy/cardart_shop_gacha.png';

/// 메인 화면 — 하단 탭 바 카드 배경.
const String kCardArtMainNav = 'assets/ui_dummy/cardart_main_nav.png';

/// 영웅 상세 다이얼로그 배경 (`CardArtBackdrop`).
const String kCardArtHeroDetail = 'assets/ui_dummy/cardart_hero_detail.png';

/// 가차 결과 다이얼로그 — `AlertDialog` **뒤**에 깔린다(반투명 Material을
/// 뚫고 보이도록 알파 240 으로 굽고, 모서리는 형태 밖으로 삐져나오지 않게
/// 라운드 마스크가 있다).
const String kCardArtGachaDialog = 'assets/ui_dummy/cardart_gacha_dialog.png';

// ── 헤더 밴드 (상단만 아트, 아래로 fade) ──────────────────────────────────

/// 파티 탭 — 편성 프레임 `_InventoryFrame` 헤더.
const String kCardArtHeaderParty = 'assets/ui_dummy/cardart_header_party.png';

/// 파티 탭 — 영웅도감 프레임 `_InventoryFrame` 헤더.
const String kCardArtHeaderCodex = 'assets/ui_dummy/cardart_header_codex.png';

/// 튜토리얼 안내 카드(`_buildInstructionCard`) 헤더.
const String kCardArtHeaderTutorial = 'assets/ui_dummy/cardart_header_tutorial.png';

/// 출격 준비 다이얼로그(`_StagePrepCard`) 헤더.
const String kCardArtHeaderStagePrep = 'assets/ui_dummy/cardart_header_stage_prep.png';

/// 영웅 선택 바텀시트(`GlassBottomSheet`) 헤더.
const String kCardArtHeaderSheet = 'assets/ui_dummy/cardart_header_sheet.png';
