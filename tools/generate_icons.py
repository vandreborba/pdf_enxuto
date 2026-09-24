#!/usr/bin/env python3
"""Gera o ícone do PDF Enxuto (PNG em vários tamanhos + ICO para o Windows).

Uso:
    python3 tools/generate_icons.py            # variante padrão (A)
    python3 tools/generate_icons.py --variants # gera prévias A/B/C para comparação

O ícone é desenhado vetorialmente com Pillow/numpy em resolução alta e
reduzido com LANCZOS, o que dá bordas suaves sem depender de ferramentas
externas (Inkscape, ImageMagick, ...).

A variante padrão ("flat") é sóbria: fundo de cor única, sem degradê.
"""

from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# --------------------------------------------------------------------------
# Paleta
# --------------------------------------------------------------------------
BG_DEEP = (67, 26, 143)  # violeta profundo
BG_MID = (124, 58, 237)  # violeta
BG_LIGHT = (34, 211, 238)  # ciano
SHEET = (255, 255, 255)
FOLD = (221, 214, 254)
LINE = (199, 210, 254)
MARK = (109, 40, 217)  # violeta escuro (setas sobre a folha)
MARK_LIGHT = (255, 255, 255)

SIZES = [1024, 512, 256, 128, 64, 48, 32, 24, 16]
ICO_SIZES = [256, 128, 64, 48, 32, 24, 16]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "icons")
BRAND_DIR = os.path.join(ROOT, "assets", "branding")


# --------------------------------------------------------------------------
# Utilitários
# --------------------------------------------------------------------------
def diagonal_gradient(size: int, stops: list[tuple[int, int, int]]) -> Image.Image:
    """Gradiente linear diagonal suave passando pelas cores informadas."""
    coords = np.linspace(0.0, 1.0, size, dtype=np.float32)
    xx, yy = np.meshgrid(coords, coords)
    t = np.clip((xx * 0.62 + yy * 0.38), 0.0, 1.0)

    n = len(stops) - 1
    arr = np.zeros((size, size, 3), dtype=np.float32)
    for i in range(n):
        lo, hi = i / n, (i + 1) / n
        seg = np.clip((t - lo) / (hi - lo), 0.0, 1.0)
        mask = ((t >= lo) & (t <= hi)).astype(np.float32)
        c_lo = np.array(stops[i], dtype=np.float32)
        c_hi = np.array(stops[i + 1], dtype=np.float32)
        blended = c_lo[None, None, :] * (1 - seg[..., None]) + c_hi[None, None, :] * seg[..., None]
        arr = np.where(mask[..., None] > 0, blended, arr)

    # Preenche a primeira fatia (t < 0) com a cor inicial
    first = np.array(stops[0], dtype=np.float32)
    arr = np.where((t < 0)[..., None], first[None, None, :], arr)
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def rounded_mask(size: int, radius: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def rr(draw: ImageDraw.ImageDraw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def arrow(draw: ImageDraw.ImageDraw, cx, y_from, y_to, shaft_w, head_w, head_h, color):
    """Seta vertical. Aponta para baixo se y_to > y_from, para cima caso contrário."""
    direction = 1 if y_to > y_from else -1
    tip = y_to
    base = tip - direction * head_h
    draw.rectangle(
        (cx - shaft_w / 2, min(y_from, base), cx + shaft_w / 2, max(y_from, base)),
        fill=color,
    )
    draw.polygon(
        [
            (cx - head_w / 2, base),
            (cx + head_w / 2, base),
            (cx, tip),
        ],
        fill=color,
    )


# --------------------------------------------------------------------------
# Variantes do ícone (S = lado do quadrado, em unidades absolutas)
# --------------------------------------------------------------------------
def draw_variant_a(img: Image.Image, S: float) -> None:
    """Folha branca com linhas de texto e duas setas se aproximando."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    x0, x1 = 0.235 * S, 0.765 * S
    y0, y1 = 0.135 * S, 0.865 * S
    fold = 0.155 * S
    radius = 0.032 * S

    # Sombra suave sob a folha
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 + 0.012 * S, y0 + 0.030 * S, x1 + 0.012 * S, y1 + 0.034 * S),
        radius=radius,
        fill=(24, 8, 60, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.022 * S))
    img.alpha_composite(shadow)

    # Folha (canto superior direito cortado)
    d.polygon(
        [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)],
        fill=SHEET,
    )
    # Aba dobrada
    d.polygon([(x1 - fold, y0), (x1, y0 + fold), (x1 - fold, y0 + fold)], fill=FOLD)

    # Linhas de texto (mais juntas embaixo: sensação de aperto)
    lw = 0.036 * S
    lr = lw / 2
    cx = (x0 + x1) / 2
    for y, w in ((0.268, 0.300), (0.352, 0.300), (0.760, 0.300), (0.828, 0.190)):
        half = w * S / 2
        rr(d, (cx - half, y * S - lr, cx + half, y * S + lr), lr, LINE)

    # Setas se aproximando
    arrow(d, cx, 0.455 * S, 0.612 * S, 0.072 * S, 0.190 * S, 0.088 * S, MARK)
    arrow(d, cx, 0.735 * S, 0.640 * S, 0.072 * S, 0.190 * S, 0.088 * S, MARK)

    img.alpha_composite(layer)


def draw_variant_b(img: Image.Image, S: float) -> None:
    """Folha branca + selo circular com setas de compressão."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    x0, x1 = 0.200 * S, 0.720 * S
    y0, y1 = 0.135 * S, 0.865 * S
    fold = 0.150 * S
    radius = 0.032 * S

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 + 0.012 * S, y0 + 0.030 * S, x1 + 0.012 * S, y1 + 0.034 * S),
        radius=radius,
        fill=(24, 8, 60, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.022 * S))
    img.alpha_composite(shadow)

    d.polygon(
        [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)],
        fill=SHEET,
    )
    d.polygon([(x1 - fold, y0), (x1, y0 + fold), (x1 - fold, y0 + fold)], fill=FOLD)

    lw = 0.034 * S
    lr = lw / 2
    for y, x_end in ((0.270, 0.620), (0.352, 0.620), (0.434, 0.520), (0.516, 0.620), (0.598, 0.560)):
        rr(d, (x0 + 0.055 * S, y * S - lr, x_end * S, y * S + lr), lr, LINE)

    # Selo
    bx, by, br = 0.720 * S, 0.720 * S, 0.215 * S
    d.ellipse((bx - br - 0.022 * S, by - br - 0.022 * S, bx + br + 0.022 * S, by + br + 0.022 * S), fill=SHEET)
    d.ellipse((bx - br, by - br, bx + br, by + br), fill=BG_MID)
    arrow(d, bx, by - 0.145 * S, by - 0.030 * S, 0.058 * S, 0.150 * S, 0.070 * S, MARK_LIGHT)
    arrow(d, bx, by + 0.145 * S, by + 0.030 * S, 0.058 * S, 0.150 * S, 0.070 * S, MARK_LIGHT)

    img.alpha_composite(layer)


def draw_variant_c(img: Image.Image, S: float) -> None:
    """Folha sendo prensada: duas barras convergindo sobre o documento."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    x0, x1 = 0.245 * S, 0.755 * S
    y0, y1 = 0.185 * S, 0.815 * S
    fold = 0.150 * S
    radius = 0.032 * S

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 + 0.012 * S, y0 + 0.030 * S, x1 + 0.012 * S, y1 + 0.034 * S),
        radius=radius,
        fill=(24, 8, 60, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.022 * S))
    img.alpha_composite(shadow)

    d.polygon(
        [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)],
        fill=SHEET,
    )
    d.polygon([(x1 - fold, y0), (x1, y0 + fold), (x1 - fold, y0 + fold)], fill=FOLD)

    lw = 0.036 * S
    lr = lw / 2
    cx = (x0 + x1) / 2
    for y, w in ((0.300, 0.320), (0.380, 0.320), (0.560, 0.320), (0.640, 0.320)):
        half = w * S / 2
        rr(d, (cx - half, y * S - lr, cx + half, y * S + lr), lr, LINE)

    # Barras de prensa
    bar_h = 0.075 * S
    d.rounded_rectangle(
        (0.150 * S, 0.455 * S - bar_h / 2, 0.850 * S, 0.455 * S + bar_h / 2),
        radius=bar_h / 2,
        fill=MARK,
    )
    d.rounded_rectangle(
        (0.150 * S, 0.545 * S - bar_h / 2, 0.850 * S, 0.545 * S + bar_h / 2),
        radius=bar_h / 2,
        fill=MARK,
    )

    img.alpha_composite(layer)


def draw_variant_flat(img: Image.Image, S: float) -> None:
    """Versao sobria: fundo liso, sem degrade, traco unico de cor."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    x0, x1 = 0.235 * S, 0.765 * S
    y0, y1 = 0.135 * S, 0.865 * S
    fold = 0.150 * S
    radius = 0.028 * S

    d.polygon(
        [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)],
        fill=SHEET,
    )
    d.polygon(
        [(x1 - fold, y0), (x1, y0 + fold), (x1 - fold, y0 + fold)],
        fill=(214, 219, 226),
    )

    lw = 0.034 * S
    lr = lw / 2
    cx = (x0 + x1) / 2
    for y, w in ((0.268, 0.300), (0.352, 0.300), (0.790, 0.300)):
        half = w * S / 2
        rr(d, (cx - half, y * S - lr, cx + half, y * S + lr), lr, (198, 205, 214))

    marca = (62, 76, 94)
    arrow(d, cx, 0.470 * S, 0.610 * S, 0.072 * S, 0.190 * S, 0.088 * S, marca)
    arrow(d, cx, 0.720 * S, 0.630 * S, 0.072 * S, 0.190 * S, 0.088 * S, marca)

    img.alpha_composite(layer)


VARIANTS = {
    "a": draw_variant_a,
    "b": draw_variant_b,
    "c": draw_variant_c,
    "flat": draw_variant_flat,
}

# Cores do fundo por variante (a "flat" usa uma cor unica).
FUNDOS = {
    "flat": (62, 76, 94),
}


# --------------------------------------------------------------------------
# Composição
# --------------------------------------------------------------------------
def build_icon(size: int, variant: str = "a", ss: int = 2) -> Image.Image:
    S = size * ss
    if variant in FUNDOS:
        bg = Image.new("RGB", (S, S), FUNDOS[variant])
    else:
        bg = diagonal_gradient(S, [BG_DEEP, BG_MID, BG_LIGHT])
    icon = bg.convert("RGBA")

    draw = VARIANTS[variant]
    draw(icon, S)

    if variant not in FUNDOS:
        # Brilho superior discreto (só nas variantes com degradê).
        gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gloss)
        gd.ellipse(
            (-0.45 * S, -1.05 * S, 1.45 * S, 0.62 * S),
            fill=(255, 255, 255, 26),
        )
        icon.alpha_composite(gloss)

    mask = rounded_mask(S, 0.225 * S)
    icon.putalpha(Image.composite(icon.getchannel("A"), Image.new("L", (S, S), 0), mask))
    return icon.resize((size, size), Image.LANCZOS)


def preview(variant: str, path: str, sizes=(16, 24, 32, 48, 64, 128, 256)) -> None:
    pad = 24
    width = sum(sizes) + pad * (len(sizes) + 1)
    height = max(sizes) + pad * 2
    canvas = Image.new("RGB", (width, height), (245, 243, 250))
    x = pad
    for s in sizes:
        canvas.paste(build_icon(s, variant, ss=4), (x, pad + (max(sizes) - s) // 2), build_icon(s, variant, ss=4))
        x += s + pad
    canvas.save(path)
    print("prévia:", path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--variants", action="store_true", help="gera prévias das variantes A/B/C")
    parser.add_argument("--variant", default="flat", choices=sorted(VARIANTS))
    args = parser.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(BRAND_DIR, exist_ok=True)

    if args.variants:
        for name in sorted(VARIANTS):
            preview(name, os.path.join(BRAND_DIR, f"preview_{name}.png"))
        return

    master = build_icon(1024, args.variant, ss=2)
    master.save(os.path.join(OUT_DIR, "icon.png"))
    print("gerado:", os.path.join(OUT_DIR, "icon.png"))

    for s in SIZES:
        master.resize((s, s), Image.LANCZOS).save(os.path.join(OUT_DIR, f"icon_{s}.png"))
    print("tamanhos:", ", ".join(str(s) for s in SIZES))

    ico_path = os.path.join(OUT_DIR, "icon.ico")
    master.save(ico_path, sizes=[(s, s) for s in ICO_SIZES])
    print("gerado:", ico_path)

    preview(args.variant, os.path.join(BRAND_DIR, "icon_scales.png"))


if __name__ == "__main__":
    main()
