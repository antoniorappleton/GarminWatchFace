"""Gera os recursos gráficos do Tático Navy (ecrã de referência: 176 x 176 px, 1 bit).

- resources/drawables/topo_black.png e topo_white.png
  Curvas de nível (opção E: duas montanhas e um vale), pontilhadas em xadrez
  para parecerem cinzento, com zonas livres à volta dos elementos fixos.
- resources/fonts/small.fnt/.png   (11 px) números secundários e assinatura
- resources/fonts/coord.fnt/.png   (10 px) coordenadas

Uso:  python tools/gen_assets.py     (a partir da pasta do projeto)
Requer: Pillow e numpy. As posições abaixo têm de acompanhar TaticoNavyView.mc.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_TTF = "DejaVuSansCondensed-Bold.ttf"  # fonte livre (licença DejaVu/Bitstream Vera)
W = 176
CX = CY = 88

# ---------- Terreno ----------

LEVELS = 6  # curvas por unidade de altura (opção E = 6; opção F = 8)


def terrain():
    yy, xx = np.mgrid[0:W, 0:W].astype(float)
    wx = xx + 4 * np.sin(yy / 13.0) + 2.5 * np.sin(yy / 6.0 + xx / 17.0)
    wy = yy + 4 * np.cos(xx / 14.0) + 2.5 * np.cos(xx / 7.0 - yy / 19.0)

    def cone(px, py, radius, amp):
        d = np.sqrt((wx - px) ** 2 + (wy - py) ** 2)
        return amp * np.clip(1 - d / radius, 0, None) ** 1.15

    f = cone(42, 122, 52, 1.0) + cone(58, 46, 46, 0.85) - cone(138, 124, 46, 0.8)
    lev = np.floor(f * LEVELS)
    edge = (lev != np.roll(lev, 1, 0)) | (lev != np.roll(lev, 1, 1))
    checker = ((xx + yy).astype(int) % 2) == 0  # um píxel sim, outro não: "cinzento"
    return edge & checker, xx, yy


def free_zones(xx, yy):
    """Zonas onde o terreno não é desenhado (margem à volta dos elementos fixos)."""
    keep_out = np.zeros((W, W), bool)
    # anel das marcas e tudo o que fica fora do mostrador
    keep_out |= (xx - CX) ** 2 + (yy - CY) ** 2 > 76 ** 2

    def rect(x0, y0, x1, y1):
        return (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)

    def circle(x, y, r):
        return (xx - x) ** 2 + (yy - y) ** 2 <= r ** 2

    for i in range(1, 13):
        a = math.radians(i * 30)
        cardinal = i % 3 == 0
        r = 63 if cardinal else 70
        keep_out |= circle(CX + r * math.sin(a), CY - r * math.cos(a), 13 if cardinal else 10)
    keep_out |= rect(CX - 30, CY - 41, CX + 27, CY - 23)   # assinatura
    keep_out |= rect(CX - 40, CY + 5, CX + 40, CY + 27)    # DTG
    keep_out |= rect(CX - 39, CY + 26, CX + 39, CY + 51)   # coordenadas
    keep_out |= circle(CX, CY, 9)                          # eixo dos ponteiros
    return keep_out


def make_topo():
    topo, xx, yy = terrain()
    topo &= ~free_zones(xx, yy)
    out = os.path.join(ROOT, "resources", "drawables")
    for name, rgb in (("topo_black.png", (0, 0, 0)), ("topo_white.png", (255, 255, 255))):
        img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        px = img.load()
        for y, x in zip(*np.nonzero(topo)):
            px[int(x), int(y)] = rgb + (255,)
        img.save(os.path.join(out, name))
    print("terreno:", int(topo.sum()), "píxeis")


# ---------- Fontes (formato BMFont de texto) ----------

def make_font(name, size, chars):
    font = ImageFont.truetype(FONT_TTF, size)
    asc, desc = font.getmetrics()
    glyphs = []
    for ch in chars:
        bbox = font.getbbox(ch)
        adv = int(round(font.getlength(ch)))
        w = max(1, bbox[2] - bbox[0])
        h = max(1, bbox[3] - bbox[1])
        g = Image.new("L", (w, h), 0)
        ImageDraw.Draw(g).text((-bbox[0], -bbox[1]), ch, font=font, fill=255)
        g = g.point(lambda v: 255 if v >= 110 else 0)  # 1 bit: o ecrã MIP é preto e branco
        glyphs.append((ch, g, bbox[0], bbox[1], 3 if ch == " " else adv))

    sheet_w, x, y, row_h, pos = 128, 0, 0, 0, []
    for _, g, _, _, _ in glyphs:
        if x + g.width + 1 > sheet_w:
            x, y, row_h = 0, y + row_h + 1, 0
        pos.append((x, y))
        x += g.width + 1
        row_h = max(row_h, g.height)
    sheet_h = 1 << (y + row_h).bit_length()

    sheet = Image.new("RGBA", (sheet_w, sheet_h), (255, 255, 255, 0))
    lines = []
    for (ch, g, xo, yo, adv), (px, py) in zip(glyphs, pos):
        sheet.paste(Image.new("RGBA", g.size, (255, 255, 255, 255)), (px, py), g)
        lines.append(f"char id={ord(ch)} x={px} y={py} width={g.width} height={g.height} "
                     f"xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15")
    out = os.path.join(ROOT, "resources", "fonts")
    sheet.save(os.path.join(out, name + ".png"))
    with open(os.path.join(out, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write(f'info face="{name}" size={size} bold=1 italic=0 charset="" unicode=1 '
                'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1\n')
        f.write(f"common lineHeight={asc + desc} base={asc} scaleW={sheet_w} scaleH={sheet_h} pages=1 packed=0\n")
        f.write(f'page id=0 file="{name}.png"\nchars count={len(lines)}\n' + "\n".join(lines) + "\n")
    print("fonte", name, size, "px:", len(chars), "caracteres")


if __name__ == "__main__":
    make_topo()
    make_font("small", 11, "0123456789 aelnopt")
    make_font("coord", 10, "0123456789NSEW°'.- ")
