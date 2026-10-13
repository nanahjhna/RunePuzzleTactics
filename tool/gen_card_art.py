#!/usr/bin/env python3
"""Rune Puzzle Tactics — 카드 아트(더미 배경/헤더) 생성기.

각 화면의 **카드형 섹션**(글래스 카드 / 9-slice 프레임 패널 / 다이얼로그) 뒤에
깔리는 더미 배경·헤더 이미지를 만든다. 실아트가 나오기 전까지 "이 자리에
이미지가 들어간다"는 감각을 화면 전체에 심는 용도다.

## 레이어 규칙 (이 이미지가 그려지는 자리)

이미지는 `PixelSprite.art` 자리에 들어간다:

    카드 배경색(`background`)  →  [ 카드 아트 ]  →  9-slice 프레임  →  콘텐츠

즉 배경색 **위**, 콘텐츠 **아래**다. 그래서:

1. **알파를 낮게 굽는다.** 기본 200/255 — 카드 배경색과 섞여 흰 텍스트가
   그 위에서도 읽힌다. 다이얼로그 뒤에 깔리는 것([cardart_gacha_dialog])만
   240 으로 올려 반투명 Material 을 뚫는다.
2. **모서리 알파가 0 으로 빠진다(라운드 마스크).** `UiFrame` 은 `Stack` 을
   직각으로 클립하므로, 이미지를 굽는 쪽에서 라운드를 해결해야 카드 모서리에
   각진 테두리가 삐져나오지 않는다. 다이얼로그 형태 반경이 바뀌어도 안전하다.
3. **헤더형은 아래쪽으로도 fade 한다.** 상단 밴드만 그리고 나머지는 카드색이
   그대로 보여야 "헤더"로 읽힌다.
4. **9-slice 가 아니다.** 슬라이스 재측정 없이 `BoxFit.cover` 로 늘리므로
   경로 상수만 바꾸면 실아트로 교체된다.

## 팔레트

색은 전부 `lib/theme/app_theme.dart` 의 포인트 컬러
(골드/블루/레드/퍼플/그린)를 다크 인디고 배경(`BASE_TOP/BASE_BOTTOM`)으로
섞은 값이다. 새 이미지를 넣을 때도 이 두 상수로 섞는다.

## 사용법

    python tool/gen_card_art.py

멱등 — 다시 돌리면 같은 파일을 덮어쓴다. 경로 상수는
`lib/theme/ui_sprites.dart` 의 `kCardArt*` 한 곳에 모여 있다.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "ui_dummy"

# 카드 아래에 깔리는 다크 인디고. 모든 아트 색을 여기로 섞는다.
BASE_TOP = (0x24, 0x20, 0x46)
BASE_BOTTOM = (0x16, 0x14, 0x2E)

RGB = tuple[int, int, int]


# ── 색 보조 ────────────────────────────────────────────────────────────────


def _mix(a: RGB, b: RGB, t: float) -> RGB:
    """`b` 쪽으로 `t`(0~1)만큼 섞는다. t=0 이면 `a` 그대로."""
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))  # type: ignore[return-value]


def _palette(accent: RGB) -> tuple[RGB, RGB]:
    """포인트 컬러 → (그라데이션 위/아래) 쌍."""
    return _mix(accent, BASE_TOP, 0.60), _mix(accent, BASE_BOTTOM, 0.84)


# ── 레이어 생성 ────────────────────────────────────────────────────────────


def _gradient(w: int, h: int, top: RGB, bottom: RGB) -> Image.Image:
    """세로 그라데이션 RGB."""
    grad = Image.linear_gradient("L").resize((w, h), Image.Resampling.BILINEAR)
    return ImageOps.colorize(grad, top, bottom).convert("RGB")


def _pattern(w: int, h: int, kind: str, accent: RGB, alpha: int) -> Image.Image:
    """텍스처 레이어(투명 RGBA). 카드 성격을 패턴으로 구분한다."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = (*accent, alpha)

    if kind == "stripes":  # 45° 대각선 — 역동적인 카드(스테이지/데미지)
        step = max(18, w // 22)
        for x in range(-h, w + h, step):
            d.line([(x, 0), (x + h, h)], fill=c, width=2)
    elif kind == "scan":  # 가로 스캔라인 — 목록/요약성 카드
        for y in range(0, h, 7):
            d.line([(0, y), (w, y)], fill=c, width=1)
    elif kind == "lattice":  # 마름모 격자 — 뽑기/편성 계열
        step = max(26, w // 14)
        for x in range(-h, w + h, step):
            d.line([(x, 0), (x + h, h)], fill=c, width=1)
            d.line([(x, h), (x + h, 0)], fill=c, width=1)
    elif kind == "dots":  # 도트 그리드 — 정보성 카드(설정/요약)
        step = max(20, w // 18)
        r = max(2, step // 14)
        for y in range(step // 2, h, step):
            for x in range(step // 2, w, step):
                d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    elif kind == "arcs":  # 동심 호 — 영웅/가차 계열(마법진 뉘앙스)
        cx, cy = int(w * 0.76), int(h * 0.28)
        step = max(26, w // 12)
        for rad in range(min(w, h) // 5, max(w, h), step):
            d.ellipse(
                [cx - rad, cy - rad, cx + rad, cy + rad],
                outline=c,
                width=2,
            )
    return layer


def _glow(w: int, h: int, accent: RGB, alpha: int, at: tuple[float, float]) -> Image.Image:
    """모서리 쪽 동심 글로우(블러로 부드럽게)."""
    cx, cy = int(w * at[0]), int(h * at[1])
    r = int(max(w, h) * 0.42)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=r * 0.5))
    glow = Image.new("RGBA", (w, h), (*accent, 255))
    glow.putalpha(mask)
    return glow


def _alpha(w: int, h: int, base: int, header: bool) -> Image.Image:
    """최종 알파 채널.

    라운드 마스크를 **이미지에 굽는다** — `UiFrame` / 다이얼로그가 이미지를
    라운드로 클립해주지 않으므로 모서리가 각져 보이는 문제를 여기서 해결한다.
    """
    fade = max(10, min(w, h) // 16)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [fade, fade, w - 1 - fade, h - 1 - fade],
        radius=min(fade * 2, w // 2, h // 2),
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius=fade * 0.55))
    alpha = mask.point(lambda v: int(v * base / 255))

    if header:
        # 아래 40% 구간을 255 → 0 으로 흘려 보낸다(밴드 아래로 카드색 노출).
        cut = 150
        lut = [255 if v <= cut else int(255 * (255 - v) / (255 - cut)) for v in range(256)]
        ramp = Image.linear_gradient("L").resize((w, h), Image.Resampling.BILINEAR)
        alpha = ImageChops.multiply(alpha, ramp.point(lambda v: lut[v]))
    return alpha


# ── 스펙 ────────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class CardArtSpec:
    name: str
    size: tuple[int, int]
    accent: RGB
    pattern: str
    alpha: int = 200
    header: bool = False
    glow_at: tuple[float, float] = (0.26, 0.2)
    comment: str = field(default="", kw_only=True)


# 화면별 카드 섹션과 1:1 로 대응한다. 수정 시 `lib/theme/ui_sprites.dart` 의
# `kCardArt*` 상수와 **같은 이름**을 유지할 것.
SPECS: list[CardArtSpec] = [
    # ── 글래스 카드 (GlassSurface 8곳) ──
    CardArtSpec("cardart_lobby_stage", (640, 360), (0xFF, 0xB3, 0x00), "stripes", comment="로비 스테이지 카드"),
    CardArtSpec("cardart_lobby_party", (768, 176), (0x1E, 0x90, 0xFF), "scan", comment="로비 파티 요약 카드"),
    CardArtSpec("cardart_result_reward", (768, 160), (0x2E, 0xD5, 0x73), "lattice", comment="결과 보상 카드"),
    CardArtSpec("cardart_result_party", (768, 384), (0x9B, 0x59, 0xB6), "dots", comment="결과 파티 요약 카드"),
    CardArtSpec("cardart_result_damage", (768, 512), (0xFF, 0x47, 0x57), "stripes", comment="데미지 분석 카드"),
    CardArtSpec("cardart_result_stats", (768, 384), (0x9B, 0x59, 0xB6), "scan", comment="영웅 스탯 카드"),
    CardArtSpec("cardart_settings", (512, 768), (0x1E, 0x90, 0xFF), "dots", comment="설정 그룹 카드"),
    CardArtSpec("cardart_shop_gacha", (512, 512), (0xFF, 0xB3, 0x00), "lattice", comment="상점 뽑기 패널 카드"),
    # ── 9-slice 프레임 패널 ──
    CardArtSpec("cardart_main_nav", (1024, 192), (0x1E, 0x90, 0xFF), "scan", alpha=210, comment="하단 탭바 카드"),
    # ── 다이얼로그 (CardArtBackdrop) ──
    CardArtSpec("cardart_hero_detail", (512, 704), (0xFF, 0xB3, 0x00), "arcs", alpha=205, comment="영웅 상세 다이얼로그"),
    CardArtSpec(
        "cardart_gacha_dialog",
        (512, 640),
        (0xFF, 0xB3, 0x00),
        "arcs",
        alpha=240,
        glow_at=(0.5, 0.18),
        comment="가차 결과 다이얼로그(Material 뒤)",
    ),
    # ── 헤더 밴드 (CardArt.header) ──
    CardArtSpec("cardart_header_party", (1024, 256), (0x9B, 0x59, 0xB6), "lattice", header=True, comment="파티 편성 프레임"),
    CardArtSpec("cardart_header_codex", (1024, 256), (0xFF, 0xB3, 0x00), "stripes", header=True, comment="영웅도감 프레임"),
    CardArtSpec("cardart_header_tutorial", (1024, 256), (0xFF, 0xB3, 0x00), "dots", header=True, comment="튜토리얼 안내 카드"),
    CardArtSpec("cardart_header_stage_prep", (1024, 256), (0xFF, 0x47, 0x57), "stripes", header=True, comment="출격 준비 다이얼로그"),
    CardArtSpec("cardart_header_sheet", (1024, 256), (0x9B, 0x59, 0xB6), "scan", header=True, comment="영웅 선택 바텀시트"),
]


# ── 빌드 ────────────────────────────────────────────────────────────────────


def build_one(spec: CardArtSpec) -> Image.Image:
    w, h = spec.size
    top, bottom = _palette(spec.accent)

    rgb = _gradient(w, h, top, bottom).convert("RGBA")
    rgb = Image.alpha_composite(rgb, _pattern(w, h, spec.pattern, spec.accent, 20))
    rgb = Image.alpha_composite(rgb, _glow(w, h, spec.accent, 90, spec.glow_at))

    rgb.putalpha(_alpha(w, h, spec.alpha, spec.header))
    return rgb


def build_all() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"writing to {OUT_DIR}")
    for spec in SPECS:
        img = build_one(spec)
        path = OUT_DIR / f"{spec.name}.png"
        img.save(path, optimize=True)
        kind = "header" if spec.header else "fill  "
        print(
            f"  {spec.name:30s} {img.size[0]:4d}x{img.size[1]:<4d} "
            f"a={spec.alpha:<3d} {kind} {spec.pattern:8s} {spec.comment}"
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.parse_args()
    build_all()
    print("done")


if __name__ == "__main__":
    main()
