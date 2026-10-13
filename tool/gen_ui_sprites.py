#!/usr/bin/env python3
"""Rune Puzzle Tactics — UI 테두리 스프라이트 생성기.

Flutter 위젯(`Container` + `BoxDecoration.border`)으로 그리고 있던 UI 크롬의
**테두리만** 9-slice PNG 로 뽑아내는 스크립트. 채움색·그라데이션·그림자는
여전히 Flutter `Color` 다 (§ `lib/widgets/ui_frame.dart`).

## 왜 9-slice 스프라이트를 직접 그리는가

`Image.asset(centerSlice:)` 의 코너/엣지 타일은 **항상 1:1 로 그려진다**(9-slice
특성). 스프라이트를 화면 크기보다 작게 잡으면 모서리가 잘리지 않고 테두리
굵기가 그대로 보존된다. 반대로 화면 크기보다 크게 잡으면 전체가 축소 렌더링되며
1px 테두리가 0.5px 로 죽는다. 그래서 **각 스프라이트 크기 = 그 요소가 실제로
그려지는 최소 크기** 로 맞춘다.

## 그리기 규칙

1. **선만** 그린다. 내부는 완전 투명. 선 색상은 흰색(`#FFFFFF`) 고정.
   → 런타임에 `srcIn` 틴트로 임의 색 인스턴스 (`PixelSprite.color`).
2. **앤티에일리어싱 없음.** 1x 정수 좌표로 픽셀 판정을 직접 한다. 앱이
   `FilterQuality.none` 을 쓰므로 부드러운 가장자리가 오히려 흐릿해 보인다.
3. **centerSlice 중심 밴드의 폭·높이는 반드시 > 0.**
   Flutter 의 `Slice` 는 `src.width -> dst.width` 로 나누므로, 0 이 나오면
   나눗셈 오류가 난다. 즉 `W x H` 스프라이트에 `Rect.fromLTRB(r, r, r, r)`
   을 주면서 `2r >= W` (또는 `>= H`) 가 되면 위험하다. pill 은 반경을
   `(H-1)/2` 로 잡아 이 함정을 피한다.

## 사용법

    python tool/gen_ui_sprites.py

멱등 — 다시 돌리면 같은 파일을 덮어쓴다. 규격이 바뀌면 여기만 고치면 된다.
경로 상수는 `lib/theme/ui_sprites.dart` 한 곳에 모여 있다.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "ui_dummy"

WHITE = (255, 255, 255, 255)


# ── 픽셀 판정 헬퍼 ────────────────────────────────────────────────────────


def inside_rounded(px: float, py: float, x0: float, y0: float, x1: float, y1: float, r: float) -> bool:
    """점 `(px, py)` 가 라운드 사각형 안인가. 좌표는 픽셀 **중심** 기준."""
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    if r <= 0:
        return True
    cx = None
    if px < x0 + r:
        cx = x0 + r
    elif px > x1 - r:
        cx = x1 - r
    cy = None
    if py < y0 + r:
        cy = y0 + r
    elif py > y1 - r:
        cy = y1 - r
    # 코너 영역이 아니면 사각형의 직선 변 위다.
    if cx is None or cy is None:
        return True
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def _ring_mask(w: int, h: int, radius: float, width: float) -> list[list[bool]]:
    """바깥 라운드 사각형은 있고, 안쪽으로 `width` 만큼 파인 **링** 마스크.

    경계는 **픽셀 중심 좌표계**로 잡는다(`0.5` ~ `w - 0.5`). 이미지 인덱스
    좌표(`0` ~ `w-1`)로 잡으면 마지막 행/열의 중심(`w-0.5`)이 바깥 경계를
    넘어가 그 픽셀이 잘린다.
    """
    mask = [[False] * w for _ in range(h)]
    x0, y0 = 0.5, 0.5
    x1, y1 = w - 0.5, h - 0.5
    inner_r = max(0.0, radius - width)
    for y in range(h):
        py = y + 0.5
        for x in range(w):
            px = x + 0.5
            if not inside_rounded(px, py, x0, y0, x1, y1, radius):
                continue
            if inside_rounded(px, py, x0 + width, y0 + width, x1 - width, y1 - width, inner_r):
                continue
            mask[y][x] = True
    return mask


def _fill_mask(w: int, h: int, radius: float) -> list[list[bool]]:
    """라운드 사각형 전체를 채우는 마스크."""
    mask = [[False] * w for _ in range(h)]
    x0, y0 = 0.5, 0.5
    x1, y1 = w - 0.5, h - 0.5
    for y in range(h):
        py = y + 0.5
        for x in range(w):
            if inside_rounded(x + 0.5, py, x0, y0, x1, y1, radius):
                mask[y][x] = True
    return mask


def _cap_top_mask(w: int, h: int, radius: float, width: float) -> list[list[bool]]:
    """**상단에만** 테두리가 있는 '캡' 마스크(하단은 열림).

    바텀시트처럼 위쪽 모서리만 둥글고 나머지는 직각인 패널용. 라운드 사각형
    링의 위쪽 부분만 취한 뒤, 아래로 좌우 세로선을 1px 통으로 이어 붙인다.

    **9-slice 분할이 이 형태를 표현하는 방식**: `Rect.fromLTRB(r, r, W-r, H-2)`
    로 자르면
      - 위 밴드(높이 r) = 코너 호 + 수평선 → 가로로 늘어나도 선이다.
      - 아랫 밴드(높이 H-r-2) = 좌우 세로선 + 가운데 투명 → 세로로 늘어나도 선이다.
    9-slice 가 '테두리가 없는 아래변' 을 표현하는 단위 구성이 딱 이것이다.
    """
    ring = _ring_mask(w, h, radius, width)
    # 코너 호의 세로 범위는 픽셀 중심 좌표로 `radius + 0.5` 까지다.
    keep_through = radius + 0.5
    mask = [
        [ring[y][x] and (y + 0.5) <= keep_through for x in range(w)] for y in range(h)
    ]
    for y in range(int(radius) + 1, h):
        mask[y][0] = True
        mask[y][w - 1] = True
    return mask


def _paint(w: int, h: int, mask: list[list[bool]], color: tuple[int, int, int, int] = WHITE) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if row[x]:
                px[x, y] = color
    return img


# ── 생성기 ────────────────────────────────────────────────────────────────


def _ring(name: str, size: int, radius: float, width: float) -> None:
    _emit(name, _paint(size, size, _ring_mask(size, size, radius, width)))


def _ring_rect(name: str, w: int, h: int, radius: float, width: float) -> None:
    _emit(name, _paint(w, h, _ring_mask(w, h, radius, width)))


def _cap_top(name: str, w: int, h: int, radius: float, width: float) -> None:
    _emit(name, _paint(w, h, _cap_top_mask(w, h, radius, width)))


def _circle_ring(name: str, size: int, width: float) -> None:
    """원형 테두리. 반경을 `(size-1)/2` 로 잡아야 `inside_rounded` 의 두 코너
    중심(`x0+r` / `x1-r`)이 하나의 점이 되어 동심원이 된다."""
    _emit(name, _paint(size, size, _ring_mask(size, size, (size - 1) / 2, width)))


def _filled(name: str, w: int, h: int, radius: float) -> None:
    _emit(name, _paint(w, h, _fill_mask(w, h, radius)))


def _emit(name: str, img: Image.Image) -> None:
    path = OUT_DIR / name
    img.save(path, optimize=True)
    print(f"  {name:24s} {img.size[0]}x{img.size[1]}")


def build_all() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"writing to {OUT_DIR}")

    # ── 각진 프레임 (반경 0) ───────────────────────────────────────────
    # 16px 로 잡은 이유: 코너/엣지 타일이 1:1 로 그려지므로 화면이 아무리
    # 커도(초상화 130px 등) 테두리 굵기가 1px 로 유지된다. 32px 로 잡으면
    # 작은 요소(속성 이모지 배지 13px)에서 전체가 축소 렌더링되며 0.5px 로 죽는다.
    _ring("frame_square_1.png", 16, 0.0, 1.0)
    _ring("frame_square_2.png", 16, 0.0, 2.0)
    _ring("frame_square_3.png", 16, 0.0, 3.0)

    # 4px = 각진 테두리의 최대 두께. 카드 아트워크 폴백의 외측 링.
    # 슬라이스는 두께 이상이면 되고 20/2 보다 작기만 하면 된다(중심 밴드 > 0).
    _ring("frame_square_4.png", 20, 0.0, 4.0)

    # ── 라운드 프레임 ──────────────────────────────────────────────────
    # 반경 6 이므로 코너 박스(=슬라이스 8) 안에 들어간다.
    _ring("frame_round6_2.png", 24, 6.0, 2.0)

    # 반경 4 = `GlassSurface` 의 기본(radius 8 의 절반). 16px 로 작게 잡아야
    # 좁은 패널(결과 화면 요약 행)에서 전체가 축소 렌더링되지 않는다.
    _ring("frame_round4_1.png", 16, 4.0, 1.0)

    # 반경 12 (슬라이스 >= 반경). 대상 최소 높이:
    #   - 입 재화 칩(세로 패딩 10 + 아이콘 18) ≈ 38px  → 36px 스프라이트가 1:1
    #   - 상점 `_PullButton` (세로 패딩 12 + 라벨 2행)  ≈ 60px
    _ring("frame_round12_1.png", 36, 12.0, 1.0)

    # 반경 14. 튜토리얼 안내 카드 전용(폭이 화면 - 32 라 항상 크다).
    _ring("frame_round14_1.png", 40, 14.0, 1.0)

    # 반경 24 = `appDialogRadius`. 슬라이스가 반경 이상이어야 하므로 스프라이트는
    # 최소 50px. 대상 중 가장 낮은 게 AdMob 배널 패널(높이 정확히 50)이므로
    # **52** 로 잡아 축소를 0.96배까지 눌렀다. 64 로 잡으면 0.78배로 줄어들어
    # 1px 테두리가 눈에 띄게 뭉개진다.
    _ring("frame_round24_1.png", 52, 24.0, 1.0)

    # ── 원형 테두리 ───────────────────────────────────────────────────
    # `_CircleIconButton` 은 38x38 로 크기가 고정이라 9-slice 가 필요 없다.
    # 슬라이스 자르기를 하지 않고 통째로 스케일한다.
    _circle_ring("circle_ring_38.png", 38, 1.0)

    # ── 상단 캡 (부분 테두리) ─────────────────────────────────────────
    # 바텀시트: 위쪽 24px 만 둥글고 그 아래는 직각. `Border(top:)` 을 대체한다.
    #
    # **반경 24 인 이유**: 시트 자체의 라운드(`appSheetTopRadius`)와 같아야
    # 한다. 스프라이트 반경이 시트보다 작으면 `ClipRRect` 가 모서리를 잘라내며
    # 테두리 호와 클립 호가 어긋나 코너에 틈이 생긴다.
    # **높이 52 인 이유**: 9-slice 의 상단 밴드 높이가 반경(24) 이상이어야
    # 코너 호가 그 밴드 안에 들어간다. 그래서 슬라이스 위가 24 가 된다.
    _cap_top("sheet_cap_top_generated.png", 52, 52, 24.0, 1.0)

    # ── pill (칩/배지) ─────────────────────────────────────────────────
    # 반경을 (H-1)/2 로 잡으면 좌우 캡이 완전한 스테디움이 되고,
    # 중심 밴드 폭·높이도 0 이 되지 않는다.
    #   S: 24x12 — rune_grid 타일 배지 (실제 높이 약 9px)
    #   M: 32x20 — HUD/상점/상세 칩 (약 20px)
    #   L: 48x36 — 가차 신정합계 (약 35px)
    _ring_rect("frame_pill_s.png", 24, 12, (12 - 1) / 2, 1.0)
    _ring_rect("frame_pill_m.png", 32, 20, (20 - 1) / 2, 1.0)
    _ring_rect("frame_pill_l.png", 48, 36, (36 - 1) / 2, 2.0)

    # ── 바 ────────────────────────────────────────────────────────────
    # 껍데기(테두리만) / 트랙(배경) / 채움. 셋 다 흰색으로 그려서 런타임 `srcIn`
    # 틴트로 각각 다른 색을 입힌다.
    # 예전 bar_shell.png 은 "흰 테두리 + 흰@38 채움" 을 한 장에 굽고 있어서
    # 트랙 알파(black38 / glassCard)가 쓰이는 곳마다 달라 못 썼다. 링만 남긴다.
    #
    # 셋 다 **같은 반경(2)/같은 분할** 이다. 채움만 각지게 그리면 값이 작을 때
    # 좌측 코너가 트랙의 둥근 모서리를 2px 뚫고 나간다. 반경을 맞추면 어디서든
    # 실루엣이 일치한다(단, 채움의 우측 끝도 둥글게 마감된다 — 값이 100% 면
    # 트랙과 정확히 겹쳐서 보이지 않는다).
    _ring_rect("bar_shell.png", 32, 8, 2.0, 1.0)
    _filled("bar_track.png", 32, 8, 2.0)
    _filled("bar_fill.png", 32, 8, 2.0)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.parse_args()
    build_all()
    print("done")


if __name__ == "__main__":
    main()