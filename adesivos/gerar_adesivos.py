"""Gera o PDF (A4, vetorial) com os adesivos coloridos do numpad para a gráfica."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, black, white

# --- Medidas (cm) ---
SMALL = 1.5            # tecla pequena: 1,5 x 1,5
BIG_W = 1.5            # tecla grande: 1,5 x 3,4
BIG_L = 3.4
PITCH = 1.9            # distância entre centros de teclas
RADIUS = 0.15          # canto arredondado
OUT = "adesivos_numpad_A4.pdf"

# --- Cores tiradas da foto ---
C = {
    "preto":   "#1c1c1c",
    "verde":   "#8a9a5b",
    "laranja": "#f2825c",
    "cinza":   "#3d3d3d",
    "azul":    "#2b8fcf",
    "magenta": "#c83d9c",
    "amarelo": "#e3d43a",
    "marrom":  "#a86b4c",
    "escuro":  "#2c2c2c",
    "roxo":    "#7b5ea7",
}

PALETAS = [
    ("Original", C),
    ("Pastel", {
        "preto": "#2e2e3a", "verde": "#a8e6a3", "laranja": "#ffb997", "cinza": "#8d8fa6",
        "azul": "#9ad0f5", "magenta": "#f4a6d7", "amarelo": "#fff3a3", "marrom": "#d9b38c",
        "escuro": "#3a3a4a",
        "roxo": "#b9a7e0",
    }),
    ("Terra", {
        "preto": "#2b2118", "verde": "#8a9a5b", "laranja": "#d9803f", "cinza": "#6b5e52",
        "azul": "#5b8c8c", "magenta": "#b5566b", "amarelo": "#e6c27a", "marrom": "#8c5a3c",
        "escuro": "#3d2f26",
        "roxo": "#7d6b9e",
    }),
    ("Frio", {
        "preto": "#1b2430", "verde": "#4fb286", "laranja": "#e07a5f", "cinza": "#51697a",
        "azul": "#3d5a80", "magenta": "#7b5ea7", "amarelo": "#98c1d9", "marrom": "#8b6f5b",
        "escuro": "#293241",
        "roxo": "#7b5ea7",
    }),
]

# Grade 4 colunas x 5 linhas (linha 0 = topo). (col, row, cor, tipo)
KEYS = [
    (0, 0, "preto"), (1, 0, "verde"), (2, 0, "laranja"), (3, 0, "cinza"),
    (0, 1, "azul"), (1, 1, "azul"), (2, 1, "azul"), (3, 1, "magenta"),
    (0, 2, "amarelo"), (1, 2, "amarelo"), (2, 2, "amarelo"), (3, 2, "marrom"),
    (0, 3, "verde"), (1, 3, "amarelo"), (2, 3, "amarelo"),
    (2, 4, "roxo"),
]
WIDE = (0, 4, "laranja")   # tecla "0": ocupa colunas 0-1 na linha 4 (horizontal)
TALL = (3, 3, "escuro")    # tecla Enter: ocupa linhas 3-4 na coluna 3 (vertical)

TPL_W = 4 * PITCH
TPL_H = 5 * PITCH


def rrect(c, x, y, w, h, color):
    c.setFillColor(HexColor(color))
    c.setStrokeColor(HexColor(color))
    c.setLineWidth(0)
    c.roundRect(x * cm, y * cm, w * cm, h * cm, RADIUS * cm, stroke=0, fill=1)


def template(c, ox, oy, pal=C):
    """Desenha um template completo com canto inferior esquerdo em (ox, oy) cm."""
    def center(col, row):
        return ox + col * PITCH + PITCH / 2, oy + TPL_H - (row * PITCH + PITCH / 2)

    for col, row, color in KEYS:
        cx, cy = center(col, row)
        rrect(c, cx - SMALL / 2, cy - SMALL / 2, SMALL, SMALL, pal[color])

    # tecla larga (0): centro entre col 0 e 1
    col, row, color = WIDE
    cx = ox + (col + 1) * PITCH
    cy = oy + TPL_H - (row * PITCH + PITCH / 2)
    rrect(c, cx - BIG_L / 2, cy - BIG_W / 2, BIG_L, BIG_W, pal[color])

    # tecla alta (Enter): centro entre linha 3 e 4
    col, row, color = TALL
    cx = ox + col * PITCH + PITCH / 2
    cy = oy + TPL_H - (row + 1) * PITCH
    rrect(c, cx - BIG_W / 2, cy - BIG_L / 2, BIG_W, BIG_L, pal[color])


def main():
    c = canvas.Canvas(OUT, pagesize=A4)
    c.setTitle("Adesivos Numpad - A4")
    page_w, page_h = A4[0] / cm, A4[1] / cm

    gap = 1.0
    cols, rows = 2, 2
    block_w = cols * TPL_W + (cols - 1) * gap
    block_h = rows * TPL_H + (rows - 1) * gap
    x0 = (page_w - block_w) / 2
    y0 = page_h - 1.2 - block_h

    i = 0
    for r in range(rows):
        for k in range(cols):
            name, pal = PALETAS[i]
            tx = x0 + k * (TPL_W + gap)
            ty = y0 + (rows - 1 - r) * (TPL_H + gap)
            template(c, tx, ty, pal)
            c.setFillColor(black)
            c.setFont("Helvetica", 7)
            c.drawString(tx * cm, (ty + TPL_H + 0.15) * cm, name)
            i += 1

    # Espaço restante: fileira de adesivos avulsos (reserva) de cada cor
    spare_y = y0 - 2.0
    c.setFillColor(black)
    c.setFont("Helvetica", 7)
    c.drawString(x0 * cm, (spare_y + SMALL + 0.25) * cm, "Reserva (avulsos)")
    x = x0
    for name in ["preto", "verde", "laranja", "cinza", "azul", "magenta", "amarelo", "marrom", "escuro", "roxo"]:
        rrect(c, x, spare_y, SMALL, SMALL, C[name])
        x += SMALL + 0.3
    # grandes de reserva (linha abaixo)
    y2 = spare_y - 2.0
    rrect(c, x0, y2, BIG_L, BIG_W, C["laranja"])
    rrect(c, x0 + BIG_L + 0.4, y2, BIG_L, BIG_W, C["escuro"])
    spare_y = y2

    # Régua de conferência de 5 cm
    ry = spare_y - 1.2
    c.setStrokeColor(black)
    c.setLineWidth(0.5)
    c.line(x0 * cm, ry * cm, (x0 + 5) * cm, ry * cm)
    for i in range(6):
        c.line((x0 + i) * cm, ry * cm, (x0 + i) * cm, (ry + 0.25) * cm)
    c.setFont("Helvetica", 7)
    c.drawString(x0 * cm, (ry - 0.4) * cm,
                 "Régua 5 cm - imprimir em 100% (sem ajustar à página). "
                 "Pequenas 1,5 x 1,5 cm | Grandes 1,5 x 3,4 cm")

    c.showPage()
    c.save()
    print("gerado:", OUT)


if __name__ == "__main__":
    main()
