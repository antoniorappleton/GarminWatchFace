"""Gera os recursos gráficos do Tático Navy (ecrã de 176 x 176 px, 1 bit).

Tudo o que o mostrador desenha, exceto os ponteiros, vem de fontes de píxeis:
  f9, f13, f17   texto (DejaVu Sans Condensed Bold, limiar fixo, sem cinzentos)
  f28            HHMM + fuso do Zulu
  f17c, f46      dia do DTG (Navy e Zulu), já em xadrez ("cinzento"), nas duas paridades
  icons          setas de vento, fases da lua, triângulos, serra, bússola
  ring           anel das marcas dos mostradores analógicos, em 4 mosaicos de 88 px

Uso:  python tools/gen_assets.py     (a partir da pasta do projeto)
Requer: Pillow e numpy, e o ficheiro DejaVuSansCondensed-Bold.ttf nesta pasta
(https://dejavu-fonts.github.io, licença livre).
As posições no ecrã estão em source/TaticoNavyView.mc.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
FONT_TTF = os.path.join(TOOLS, "DejaVuSansCondensed-Bold.ttf")
THRESHOLD = 110  # 1 bit: o ecrã MIP só tem preto e branco

UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
DIGITS = "0123456789"
TEXT = DIGITS + UPPER + "abcdefghijklmnopqrstuvwxyz" + " .:%-/"


def art(*rows):
    return np.array([[c == "#" for c in row] for row in rows], bool)


# ---------- Glifos de texto ----------

def text_glyph(font, ch):
    """Devolve (código, máscara, xoffset, yoffset, avanço) de um carácter."""
    adv = int(round(font.getlength(ch)))
    asc, desc = font.getmetrics()
    img = Image.new("L", (adv + 8, asc + desc + 8), 0)
    ImageDraw.Draw(img).text((4, 4), ch, font=font, fill=255)
    mask = np.asarray(img) >= THRESHOLD
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return (ord(ch), np.zeros((1, 1), bool), 0, 0, adv)
    return (ord(ch), mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1],
            int(xs.min()) - 4, int(ys.min()) - 4, adv)


def text_font(name, size, chars, degree=None):
    font = ImageFont.truetype(FONT_TTF, size)
    asc, desc = font.getmetrics()
    glyphs = [text_glyph(font, ch) for ch in chars]
    if degree is not None:
        mask, xo, yo, adv = degree
        glyphs.append((ord("°"), mask, xo, yo, adv))
    return name, asc + desc, asc, glyphs


def checker(glyphs):
    """Dígitos em xadrez, nas duas paridades: '0'-'9' para origem (x + y) par, 'a'-'j' para ímpar.
    Assim o xadrez fica sempre alinhado ao ecrã, seja qual for a posição do dígito."""
    out = []
    for parity, first in ((1, ord("0")), (0, ord("a"))):
        for code, mask, xo, yo, adv in glyphs:
            yy, xx = np.mgrid[0:mask.shape[0], 0:mask.shape[1]]
            lit = mask & (((xx + xo + yy + yo) % 2) == parity)
            out.append((first + code - ord("0"), lit, xo, yo, adv))
    return out


# ---------- Ícones ----------

ARROW_NW = art(
    "#..........",
    "####.......",
    ".######....",
    ".#####.....",
    ".#####.....",
    "..#####....",
    "..#..###...",
    "......###..",
    ".......###.",
    "........###")
ARROW_N = art(
    "....#....",
    "...###...",
    "..#####..",
    ".#######.",
    "...###...",
    "...###...",
    "...###...",
    "...###...",
    "...###...",
    "...###...")
TRI_UP = art("...#...", "...#...", "..###..", "..###..", ".#####.", ".#####.", "#######")
# Serra com sol do Zulu, por cima da assinatura: cristas irregulares,
# sulcos de sombra nas encostas e base recortada.
MOUNTAINS = art(
    "...........................#.......................#.#...",
    "..........................###.....................#####..",
    ".........................#####...................#######.",
    "........................####.#....................#####..",
    ".......................######.##.................#######.",
    ".......................######.###.................#####..",
    "......................####.###.##.......##.........#.#...",
    "....................#######.###.##......###..............",
    "............##.....########.###.###....###.#.............",
    "...........###....##########.###.##...#####..............",
    "..........###.#...###.######..###.##.######.#............",
    "........######.#.#####.######..###.####.####.#...........",
    ".......#######..#.#####.######..##.#.###.###.............",
    ".......###.####..#.##########....##.####.##..............",
    "......####.###...##.###########.###.#####.##.............",
    "....#######.####.###.##############.#############........",
    "...#################.#############.##############........",
    "..###################.############.###############.......",
    ".#####.#########.########.######.######.####.######......",
    "#####...#######..#######...####..#####..####..######.....")
MOON_RING = art(
    "...#####...",
    "..#.....#..",
    ".#.......#.",
    "#.........#",
    "#.........#",
    "#.........#",
    "#.........#",
    "#.........#",
    ".#.......#.",
    "..#.....#..",
    "...#####...")
# Marcas da subjanela do azimute (coordenadas dentro da caixa de 62 px).
COMPASS = [(31, 4), (31, 5), (31, 6), (17, 7), (44, 7), (17, 8), (44, 8), (18, 9), (43, 9),
           (7, 17), (8, 17), (53, 17), (54, 17), (9, 18), (52, 18), (4, 31), (5, 31), (6, 31),
           (56, 31), (57, 31), (58, 31), (9, 43), (52, 43), (7, 44), (8, 44), (53, 44), (54, 44),
           (18, 52), (43, 52), (17, 53), (44, 53), (17, 54), (44, 54), (31, 56), (31, 57), (31, 58)]


def moon(phase):
    """Fase 0..7 (0 = nova, 2 = quarto crescente, 4 = cheia, 6 = quarto minguante)."""
    m = MOON_RING.copy()
    k = math.cos(2 * math.pi * phase / 8)  # posição do terminador: 1 = nova, -1 = cheia
    for y in range(11):
        xs = np.nonzero(MOON_RING[y])[0]
        left, right = xs.min(), xs.max()
        half = (right - left) / 2.0
        for x in range(left, right + 1):
            rel = (x - 5) / half if half else 0
            if phase <= 4 and rel >= k - 1e-6 and phase != 0:
                m[y, x] = True
            if phase > 4 and -rel >= k - 1e-6:
                m[y, x] = True
    return m


def icon_font():
    g = []
    # Setas de vento: A = norte, depois de 45 em 45 graus no sentido dos ponteiros.
    arrows = [ARROW_N, np.rot90(ARROW_NW, -1), np.rot90(ARROW_N, -1), np.rot90(ARROW_NW, -2),
              np.rot90(ARROW_N, -2), np.rot90(ARROW_NW, -3), np.rot90(ARROW_N, -3), ARROW_NW]
    for i, a in enumerate(arrows):
        g.append((ord("A") + i, a, (11 - a.shape[1]) // 2, 0, 11))
    for i in range(8):
        g.append((ord("M") + i, moon(i), 0, 0, 14))
    g.append((ord("^"), TRI_UP, 0, 0, 8))
    g.append((ord("v"), TRI_UP[::-1], 0, 0, 8))
    g.append((ord("m"), MOUNTAINS, 0, 0, MOUNTAINS.shape[1]))
    compass = np.zeros((62, 62), bool)
    for x, y in COMPASS:
        compass[y, x] = True
    g.append((ord("c"), compass, 0, 0, 62))
    return "icons", 62, 62, g


# ---------- Anel das marcas ----------

def ring_font():
    """Minutos finos, horas médias, eixos cardeais grossos; centro em (88, 88)."""
    img = Image.new("1", (176, 176), 0)
    d = ImageDraw.Draw(img)
    for i in range(60):
        r_in, pen = (75, 5) if i % 15 == 0 else (78, 3) if i % 5 == 0 else (82, 1)
        a = math.radians(i * 6)
        sn, cs = math.sin(a), math.cos(a)
        d.line([(88 + r_in * sn, 88 - r_in * cs), (88 + 86 * sn, 88 - 86 * cs)], fill=1, width=pen)
    ring = np.asarray(img).astype(bool)
    g = []
    for i in range(4):
        x, y = 88 * (i % 2), 88 * (i // 2)
        g.append((ord("0") + i, ring[y:y + 88, x:x + 88], 0, 0, 88))
    return "ring", 88, 88, g


# ---------- Escrita (formato BMFont de texto) ----------

def write_font(name, line_height, base, glyphs):
    sheet_w = 256
    x = y = row_h = 0
    pos = []
    for _, m, _, _, _ in glyphs:
        h, w = m.shape
        if x + w + 1 > sheet_w:
            x, y, row_h = 0, y + row_h + 1, 0
        pos.append((x, y))
        x += w + 1
        row_h = max(row_h, h)
    sheet_h = 1 << (y + row_h - 1).bit_length()

    sheet = np.zeros((sheet_h, sheet_w, 4), np.uint8)
    sheet[..., :3] = 255
    lines = []
    for (code, m, xo, yo, adv), (px, py) in zip(glyphs, pos):
        h, w = m.shape
        sheet[py:py + h, px:px + w, 3] = m * 255
        lines.append(f"char id={code} x={px} y={py} width={w} height={h} "
                     f"xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15")
    out = os.path.join(ROOT, "resources", "fonts")
    Image.fromarray(sheet, "RGBA").save(os.path.join(out, name + ".png"))
    with open(os.path.join(out, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write(f'info face="{name}" size={line_height} bold=1 italic=0 charset="" unicode=1 '
                'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1\n')
        f.write(f"common lineHeight={line_height} base={base} scaleW={sheet_w} scaleH={sheet_h} "
                "pages=1 packed=0\n")
        f.write(f'page id=0 file="{name}.png"\nchars count={len(lines)}\n' + "\n".join(lines) + "\n")
    print(f"{name}: {len(glyphs)} glifos, folha {sheet_w}x{sheet_h}")


if __name__ == "__main__":
    # Símbolo de grau desenhado à mão (anel de 5 px), como na folha de design.
    ring5 = art(".###.", "#...#", "#...#", "#...#", ".###.")
    # f9 serve as linhas do Surf e a linha 2 da janela do Surf: também leva o grau.
    ring4 = art(".##.", "#..#", "#..#", ".##.")
    write_font(*text_font("f9", 9, TEXT, degree=(ring4, 0, 2, 5)))
    write_font(*text_font("f13", 13, TEXT, degree=(ring5[1:, 1:] | ring5[:-1, :-1], 1, 3, 6)))
    # f17 também serve a linha 1 da janela: precisa das unidades e dos rumos.
    write_font(*text_font("f17", 17, DIGITS + "-%/KTNESWZkmhft", degree=(ring5, 2, 3, 8)))
    write_font(*text_font("f28", 28, DIGITS + UPPER))
    for name, size in (("f17c", 17), ("f46", 46)):  # dias do DTG em xadrez: Navy e Zulu
        name, lh, base, glyphs = text_font(name, size, DIGITS)
        write_font(name, lh, base, checker(glyphs))
    write_font(*icon_font())
    write_font(*ring_font())
