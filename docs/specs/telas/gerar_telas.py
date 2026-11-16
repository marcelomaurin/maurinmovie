#!/usr/bin/env python3
"""Gera os wireframes SVG das telas do MaurinMovie (docs/specs/telas/*.svg).

Uso:  python3 docs/specs/telas/gerar_telas.py
Os SVG são wireframes de referência (não são o design final). Os números em
círculos laranja correspondem às legendas das especificações em docs/specs/.
Medidas base vêm do esqueleto atual dos formulários: janela 1100x720,
cabeçalho 76 px (cor $003A3028 em BGR = #28303A), barra de status 40 px.
"""
import os
from xml.sax.saxutils import escape

W, H = 1100, 720
HEAD_H, STEP_H, FOOT_H = 76, 34, 40
TOP = HEAD_H + STEP_H          # 110: início da área de trabalho
BOTTOM = H - FOOT_H            # 680: fim da área de trabalho
LEFT_W, RIGHT_W = 260, 300

C = {
    "head": "#28303A", "side": "#ECECEC", "bg": "#FFFFFF", "line": "#9AA3AD",
    "text": "#1F2933", "muted": "#66717D", "accent": "#2F6FB0",
    "ok": "#2E8B57", "warn": "#D9930D", "err": "#C0392B", "info": "#5B6FB0",
    "sel": "#DCE8F5", "img": "#F3F5F7", "marker": "#E8590C",
}
BADGE = {"aprovado": "ok", "approved": "ok", "ok": "ok", "publicado": "ok",
         "pendente": "warn", "aguardando revisão": "warn", "rascunho": "muted",
         "gerado": "info", "falha": "err", "erro": "err", "cascata": "info",
         "em execução": "accent", "rejeitado": "err", "sincronizado": "ok"}


class Svg:
    def __init__(self, w=W, h=H):
        self.w, self.h, self.parts = w, h, []

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill="none", stroke=C["line"], rx=0, sw=1, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
                 f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def line(self, x1, y1, x2, y2, stroke=C["line"], sw=1, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def text(self, x, y, s, size=12, weight="normal", fill=C["text"], anchor="start", italic=False):
        st = ' font-style="italic"' if italic else ""
        self.add(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" '
                 f'text-anchor="{anchor}"{st}>{escape(str(s))}</text>')

    # ---- componentes -------------------------------------------------
    def button(self, x, y, w, label, primary=False, h=26, danger=False):
        fill = C["accent"] if primary else ("#FBEAEA" if danger else "#F7F8FA")
        fg = "#FFFFFF" if primary else (C["err"] if danger else C["text"])
        self.rect(x, y, w, h, fill=fill, stroke=C["accent"] if primary else C["line"], rx=4)
        self.text(x + w / 2, y + h / 2 + 4, label, 11, "bold" if primary else "normal", fg, "middle")

    def badge(self, x, y, label, kind=None):
        kind = kind or BADGE.get(label, "muted")
        col = C[kind]
        w = 9 + len(label) * 6.2
        self.rect(x, y - 11, w, 15, fill="#FFFFFF", stroke=col, rx=7)
        self.text(x + w / 2, y, label, 9.5, "bold", col, "middle")
        return w

    def panel(self, x, y, w, h, title=None, fill=C["bg"]):
        self.rect(x, y, w, h, fill=fill, stroke=C["line"])
        if title:
            self.rect(x, y, w, 22, fill="#E1E5EA", stroke=C["line"])
            self.text(x + 8, y + 15, title.upper(), 10, "bold", C["muted"])

    def field(self, x, y, w, label, value="", h=24):
        self.text(x, y - 4, label, 10, "bold", C["muted"])
        self.rect(x, y, w, h, fill="#FFFFFF", stroke=C["line"], rx=2)
        self.text(x + 6, y + h / 2 + 4, value, 11)

    def combo(self, x, y, w, label, value):
        self.field(x, y, w, label, value)
        self.text(x + w - 12, y + 16, "▾", 11, fill=C["muted"])

    def check(self, x, y, label, on=True):
        self.rect(x, y - 10, 12, 12, fill="#FFFFFF", stroke=C["line"], rx=2)
        if on:
            self.text(x + 1.5, y, "✔", 11, "bold", C["accent"])
        self.text(x + 18, y, label, 11)

    def listbox(self, x, y, w, h, items, sel=None, row=24):
        """items: str | (texto, badge) | (texto, badge, nível)."""
        self.rect(x, y, w, h, fill="#FFFFFF", stroke=C["line"])
        for i, it in enumerate(items):
            if not isinstance(it, tuple):
                it = (it, None, 0)
            txt, bd, lvl = (list(it) + [None, 0])[:3]
            yy = y + i * row
            if yy + row > y + h:
                break
            if i == sel:
                self.rect(x + 1, yy + 1, w - 2, row - 1, fill=C["sel"], stroke="none")
            ind = 8 + (lvl or 0) * 14
            if lvl:
                self.text(x + ind - 11, yy + row / 2 + 4, "└", 11, fill=C["muted"])
            self.text(x + ind, yy + row / 2 + 4, txt, 11)
            if bd:
                bw = 9 + len(bd) * 6.2
                self.badge(x + w - bw - 8, yy + row / 2 + 4, bd)

    def tabs(self, x, y, labels, active=0, w=None):
        cx = x
        for i, lb in enumerate(labels):
            tw = w or (18 + len(lb) * 7)
            self.rect(cx, y, tw, 24, fill="#FFFFFF" if i == active else "#E1E5EA",
                      stroke=C["line"], rx=3)
            self.text(cx + tw / 2, y + 16, lb, 11, "bold" if i == active else "normal",
                      C["text"] if i == active else C["muted"], "middle")
            cx += tw + 2
        return cx

    def image(self, x, y, w, h, label="", sub=None, border=None):
        self.rect(x, y, w, h, fill=C["img"], stroke=border or C["line"], sw=2 if border else 1)
        self.line(x, y, x + w, y + h, stroke="#D5DAE0")
        self.line(x + w, y, x, y + h, stroke="#D5DAE0")
        if label:
            self.rect(x + w / 2 - len(label) * 3.4 - 6, y + h / 2 - 11, len(label) * 6.8 + 12, 18,
                      fill="#FFFFFF", stroke="none", rx=3)
            self.text(x + w / 2, y + h / 2 + 2, label, 11, "bold", C["muted"], "middle")
        if sub:
            self.text(x + 4, y + h - 6, sub, 9.5, fill=C["muted"])

    def textarea(self, x, y, w, h, lines, mono=False, size=11):
        self.rect(x, y, w, h, fill="#FFFFFF", stroke=C["line"])
        fam = ' font-family="monospace"' if mono else ""
        for i, ln in enumerate(lines):
            yy = y + 16 + i * (size + 5)
            if yy > y + h - 4:
                break
            bold = ln.startswith("**")
            s = ln.strip("*")
            self.add(f'<text x="{x + 8}" y="{yy}" font-size="{size}"{fam} '
                     f'font-weight="{"bold" if bold else "normal"}" fill="{C["text"]}">{escape(s)}</text>')

    def table(self, x, y, cols, rows, widths, sel=None, row=22):
        tw = sum(widths)
        self.rect(x, y, tw, row, fill="#E1E5EA", stroke=C["line"])
        cx = x
        for c, cw in zip(cols, widths):
            self.text(cx + 6, y + 15, c, 10, "bold", C["muted"])
            cx += cw
        for r, data in enumerate(rows):
            yy = y + row * (r + 1)
            self.rect(x, yy, tw, row, fill=C["sel"] if r == sel else "#FFFFFF", stroke="#D5DAE0")
            cx = x
            for val, cw in zip(data, widths):
                if isinstance(val, str) and val.startswith("#"):
                    self.badge(cx + 6, yy + 15, val[1:])
                else:
                    self.text(cx + 6, yy + 15, val, 11)
                cx += cw

    def progress(self, x, y, w, frac, h=10, col=None):
        self.rect(x, y, w, h, fill="#FFFFFF", stroke=C["line"], rx=3)
        self.rect(x, y, max(2, w * frac), h, fill=col or C["accent"], stroke="none", rx=3)

    def marker(self, x, y, n):
        self.add(f'<circle cx="{x}" cy="{y}" r="9" fill="{C["marker"]}"/>')
        self.text(x, y + 4, n, 10, "bold", "#FFFFFF", "middle")

    def track(self, x, y, w, h, label, clips, color="#8FB3D9", labelw=90):
        self.rect(x, y, labelw, h, fill="#E1E5EA", stroke=C["line"])
        self.text(x + 6, y + h / 2 + 4, label, 10.5, "bold")
        self.rect(x + labelw, y, w - labelw, h, fill="#FFFFFF", stroke=C["line"])
        for (a, b, t) in clips:  # a,b em fração da largura útil
            cx = x + labelw + (w - labelw) * a
            cw = (w - labelw) * (b - a)
            self.rect(cx, y + 3, cw, h - 6, fill=color, stroke="#5E7FA3", rx=3)
            self.text(cx + 4, y + h / 2 + 4, t, 9.5)

    def wave(self, x, y, w, h, seed=1, col="#5E7FA3"):
        import math
        pts = []
        for i in range(0, int(w), 3):
            a = abs(math.sin(i * 0.07 * seed) * math.cos(i * 0.019 + seed)) * (h / 2 - 2)
            pts.append(f"M{x + i},{y + h / 2 - a}L{x + i},{y + h / 2 + a}")
        self.add(f'<path d="{"".join(pts)}" stroke="{col}" stroke-width="1.5"/>')

    def ruler(self, x, y, w, labels):
        self.rect(x, y, w, 18, fill="#F7F8FA", stroke=C["line"])
        n = len(labels)
        for i, lb in enumerate(labels):
            xx = x + w * i / max(1, n - 1) if n > 1 else x
            self.line(xx, y + 10, xx, y + 18)
            self.text(min(xx + 2, x + w - 30), y + 10, lb, 9, fill=C["muted"])

    def playhead(self, x, y1, y2):
        self.line(x, y1, x, y2, stroke=C["err"], sw=2)
        self.add(f'<path d="M{x - 5},{y1}L{x + 5},{y1}L{x},{y1 + 7}Z" fill="{C["err"]}"/>')

    def player_controls(self, x, y, w, tc="00:00:12:05 / 00:01:30:00"):
        self.rect(x, y, w, 30, fill="#F7F8FA", stroke=C["line"])
        bx = x + 8
        for s in ["⏮", "◀◀", "▶", "▶▶", "⏭"]:
            self.rect(bx, y + 4, 28, 22, fill="#FFFFFF", stroke=C["line"], rx=3)
            self.text(bx + 14, y + 19, s, 10, anchor="middle")
            bx += 32
        self.text(bx + 8, y + 19, tc, 11, "bold", fill=C["text"])
        self.progress(bx + 190, y + 11, w - (bx - x) - 200, 0.14, h=8)

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="0 0 {self.w} {self.h}" font-family="DejaVu Sans, Arial, sans-serif">'
                f'<rect width="100%" height="100%" fill="{C["bg"]}"/>' + "".join(self.parts) + "</svg>")


def chrome(app, steps=None, active=0, rev="r0004", state="rascunho", sync="sincronizado",
           left=True, right=True, footer="Pronto", prog=None, project="Filme Exemplo"):
    """Esqueleto comum (docs/specs/00-comum.md §3). Retorna (svg, área central)."""
    s = Svg()
    s.rect(0, 0, W, HEAD_H, fill=C["head"], stroke="none")
    s.text(20, 33, "MaurinMovie  |  " + app, 20, "bold", "#FFFFFF")
    s.text(20, 58, f"Produção: {project}   ·   Projeto: pr_{app.lower()[1:]}_01   ·   Revisão ativa: {rev}",
           11, fill="#C9D1DA")
    bx = 690
    s.text(bx, 30, "Estado:", 10, fill="#C9D1DA")
    s.badge(bx + 42, 30, state)
    s.text(bx, 54, "Sincronização:", 10, fill="#C9D1DA")
    s.badge(bx + 80, 54, sync)
    for i, lb in enumerate(["Abrir", "Salvar", "Revisões", "Log"]):
        s.rect(870 + i * 56, 24, 52, 28, fill="#3B4552", stroke="#56616E", rx=4)
        s.text(896 + i * 56, 42, lb, 11, "normal", "#FFFFFF", "middle")
    s.marker(14, 12, "A")
    # barra de etapas
    s.rect(0, HEAD_H, W, STEP_H, fill="#F4F6F8", stroke=C["line"])
    if steps:
        x = 12
        for i, st in enumerate(steps):
            done, cur = i < active, i == active
            col = C["ok"] if done else (C["accent"] if cur else C["muted"])
            s.add(f'<circle cx="{x + 9}" cy="{HEAD_H + 17}" r="9" fill="{col if (done or cur) else "#FFFFFF"}" stroke="{col}"/>')
            s.text(x + 9, HEAD_H + 21, "✓" if done else str(i + 1), 10, "bold",
                   "#FFFFFF" if (done or cur) else col, "middle")
            s.text(x + 24, HEAD_H + 21, st, 11, "bold" if cur else "normal", col)
            x += 34 + len(st) * 7.2
            if i < len(steps) - 1:
                s.line(x - 6, HEAD_H + 17, x + 4, HEAD_H + 17, stroke=C["line"])
                x += 12
        s.marker(W - 16, HEAD_H + 17, "B")
    # rodapé
    s.rect(0, BOTTOM, W, FOOT_H, fill="#F4F6F8", stroke=C["line"])
    s.text(12, BOTTOM + 25, footer, 11)
    if prog is not None:
        s.progress(640, BOTTOM + 15, 260, prog)
        s.text(908, BOTTOM + 25, f"{int(prog * 100)}%", 11, "bold")
    s.rect(990, BOTTOM + 8, 98, 24, fill="#FFFFFF", stroke=C["line"], rx=4)
    s.text(1039, BOTTOM + 25, "Fila / Log ▴", 11, anchor="middle")
    s.marker(W - 16, BOTTOM - 10, "C")
    x0 = LEFT_W if left else 0
    x1 = W - RIGHT_W if right else W
    if left:
        s.rect(0, TOP, LEFT_W, BOTTOM - TOP, fill=C["side"], stroke=C["line"])
    if right:
        s.rect(W - RIGHT_W, TOP, RIGHT_W, BOTTOM - TOP, fill="#F7F8FA", stroke=C["line"])
    return s, (x0, TOP, x1, BOTTOM)


SCREENS = {}


def screen(name):
    def deco(f):
        SCREENS[name] = f
        return f
    return deco


# =====================================================================
# 00 COMUM
# =====================================================================
@screen("00-esqueleto-comum")
def _():
    s, (x0, y0, x1, y1) = chrome("MApp", ["Etapa 1", "Etapa 2", "Etapa 3", "Salvar"], 1,
                                  footer="Mensagem de status · 2 avisos", prog=0.42)
    s.text(12, y0 + 22, "PAINEL ESQUERDO", 11, "bold", C["muted"])
    s.text(12, y0 + 40, "árvore de cenas / entidades /", 10.5, fill=C["muted"])
    s.text(12, y0 + 54, "itens + ações da etapa", 10.5, fill=C["muted"])
    s.listbox(10, y0 + 66, 240, 300, [("Cena 1", "aprovado"), ("Cena 2", "pendente"),
              ("Segmento 2.1", "gerado", 1), ("Segmento 2.2", "falha", 1), ("Cena 3", "rascunho")], sel=1)
    s.field(10, y0 + 400, 240, "FILTRO", "buscar por nome, alias ou ID")
    s.marker(250, y0 + 10, "D")
    s.rect(x0 + 10, y0 + 10, x1 - x0 - 20, y1 - y0 - 60, fill="#FAFBFC", stroke=C["line"], dash="5,4")
    s.text((x0 + x1) / 2, (y0 + y1) / 2 - 20, "ÁREA CENTRAL", 16, "bold", C["muted"], "middle")
    s.text((x0 + x1) / 2, (y0 + y1) / 2 + 4, "editor / visualizador / timeline do aplicativo", 11,
           fill=C["muted"], anchor="middle")
    s.marker(x1 - 18, y0 + 20, "E")
    bx = x0 + 10
    for lb, p in [("Gerar", False), ("Revisar", False), ("Aprovar", True), ("Rejeitar", False)]:
        s.button(bx, y1 - 40, 100, lb, p, danger=(lb == "Rejeitar"))
        bx += 108
    s.marker(bx + 4, y1 - 27, "F")
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Propriedades", "IA", "Revisões", "Vínculos"], 0)
    s.field(rx + 12, y0 + 52, 276, "ID", "sc_01JD7W3K9M0000000000000002")
    s.field(rx + 12, y0 + 98, 276, "NOME", "Cena 2 — A carta")
    s.combo(rx + 12, y0 + 144, 276, "ESTADO", "aguardando revisão")
    s.text(rx + 12, y0 + 194, "ORIGEM", 10, "bold", C["muted"])
    s.textarea(rx + 12, y0 + 200, 276, 90, ["MScript pr_script_01 r0003", "MVisual pr_visual_01 r0002",
               "sha256 9f2c…a01b  ✔ íntegro"], size=10.5)
    s.text(rx + 12, y0 + 314, "HISTÓRICO", 10, "bold", C["muted"])
    s.listbox(rx + 12, y0 + 320, 276, 120, ["16/11 09:10 gerado (IA)", "16/11 09:40 editado (usuário)",
              "16/11 10:02 regenerado por prompt"])
    s.marker(W - 16, y0 + 40, "G")
    return s


# =====================================================================
# MMENU
# =====================================================================
@screen("01-mmenu-principal")
def _():
    s, (x0, y0, x1, y1) = chrome("MMenu", None, rev="—", state="publicado", right=True,
                                  footer="Produção carregada: 7 projetos · 2 pendências")
    s.text(12, y0 + 22, "PRODUÇÃO ATIVA", 11, "bold", C["muted"])
    s.field(10, y0 + 34, 240, "", "Filme Exemplo (p_01JEXEMPLO)")
    s.button(10, y0 + 68, 240, "Abrir produção...", True)
    s.button(10, y0 + 100, 240, "Nova produção...")
    s.button(10, y0 + 132, 240, "Configurações...")
    s.marker(250, y0 + 80, "1")
    s.text(12, y0 + 186, "RECENTES", 11, "bold", C["muted"])
    s.listbox(10, y0 + 194, 240, 140, ["Filme Exemplo", "Curta Noturno", "Teste Pipeline"], sel=0)
    s.text(12, y0 + 360, "ARTEFATOS / INTEGRIDADE", 11, "bold", C["muted"])
    s.button(10, y0 + 370, 240, "Painel de artefatos...")
    s.button(10, y0 + 402, 240, "Verificar integridade")
    s.button(10, y0 + 434, 240, "Reconstruir catálogo")
    s.text(x0 + 20, y0 + 28, "Aplicativos da suíte", 16, "bold")
    s.marker(x0 + 230, y0 + 22, "2")
    apps = [("MScript", "Roteiro e personagens", "r0003", "aprovado"),
            ("MVisual", "Biblioteca visual", "r0002", "aguardando revisão"),
            ("MBoard", "Storyboard", "r0004", "aprovado"),
            ("MSound", "Vozes e efeitos", "r0001", "rascunho"),
            ("MScene", "Geração de cenas", "4/10 cenas", "pendente"),
            ("MCut", "Montagem e filme final", "—", "rascunho")]
    cw = (x1 - x0 - 60) / 2
    for i, (n, d, r, st) in enumerate(apps):
        cx = x0 + 20 + (i % 2) * (cw + 20)
        cy = y0 + 46 + (i // 2) * 92
        s.rect(cx, cy, cw, 80, fill="#FFFFFF", stroke=C["line"], rx=6)
        s.rect(cx, cy, 6, 80, fill=C["accent"], stroke="none")
        s.text(cx + 16, cy + 24, f"{i + 1} · {n}", 14, "bold")
        s.text(cx + 16, cy + 42, d, 11, fill=C["muted"])
        s.text(cx + 16, cy + 64, "Revisão: " + r, 11)
        s.badge(cx + cw - 9 - len(st) * 6.2 - 10, cy + 64, st)
        s.button(cx + cw - 78, cy + 12, 68, "Abrir ▸", True, h=22)
    s.text(x0 + 20, y0 + 340, "Pendências e sincronizações", 13, "bold")
    s.marker(x0 + 262, y0 + 335, "3")
    s.table(x0 + 20, y0 + 350, ["Evento", "Origem", "Etapa", "Estado"],
            [["evt_…7Q bazuca", "MBoard r0004", "MVisual", "#em execução"],
             ["evt_…2K fala c4", "MBoard r0003", "MScript", "#falha"],
             ["lig. c4→c5", "MScene c4", "—", "#pendente"]],
            [150, 120, 100, 150], sel=1)
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "DETALHES DO PROJETO", 11, "bold", C["muted"])
    s.marker(W - 16, y0 + 18, "4")
    s.table(rx + 8, y0 + 34, ["Campo", "Valor"],
            [["Aplicativo", "MScript"], ["project_id", "pr_script_01"], ["Revisão", "r0003"],
             ["Estado", "approved"], ["Fontes", "—"], ["Atualizado", "16/11 09:12"],
             ["Hash", "✔ íntegro"]], [100, 184])
    s.text(rx + 12, y0 + 232, "REVISÕES", 11, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 240, 284, 110, [("r0003", "aprovado"), ("r0002", "aprovado"), ("r0001", "aprovado")], sel=0)
    s.button(rx + 8, y0 + 362, 284, "Abrir esta revisão no MScript", True)
    s.button(rx + 8, y0 + 394, 284, "Ver dependências")
    s.button(rx + 8, y0 + 426, 284, "Revincular arquivo ausente...")
    return s


@screen("01-mmenu-artefatos")
def _():
    s, (x0, y0, x1, y1) = chrome("MMenu", None, rev="—", state="publicado", right=False,
                                  footer="1.284 artefatos · 2 ausentes · 0 corrompidos")
    s.text(12, y0 + 22, "FILTROS", 11, "bold", C["muted"])
    s.combo(10, y0 + 46, 240, "APLICATIVO", "Todos")
    s.combo(10, y0 + 92, 240, "TIPO", "visual.object.reference")
    s.field(10, y0 + 138, 240, "CENA", "sc_0004")
    s.field(10, y0 + 184, 240, "ENTIDADE / ID", "BAZUCA")
    s.combo(10, y0 + 230, 240, "ESTADO", "Todos")
    s.combo(10, y0 + 276, 240, "INTEGRIDADE", "Somente com problema")
    s.button(10, y0 + 316, 240, "Aplicar filtros", True)
    s.marker(250, y0 + 30, "1")
    s.text(x0 + 20, y0 + 26, "Painel de artefatos", 16, "bold")
    s.table(x0 + 20, y0 + 40, ["artifact_id", "Tipo", "App/Rev", "Cena", "Tamanho", "Estado", "Hash"],
            [["a_…01", "visual.object.reference", "MVisual r0003", "sc_0004", "1,2 MB", "#gerado", "✔"],
             ["a_…02", "visual.object.reference", "MVisual r0003", "sc_0004", "1,1 MB", "#gerado", "✔"],
             ["a_…03", "storyboard.frame", "MBoard r0005", "sc_0004", "0,9 MB", "#pendente", "✔"],
             ["a_…04", "video.segment", "MScene c4 r0002", "sc_0004", "88 MB", "#aprovado", "✘ ausente"],
             ["a_…05", "audio.effect", "MSound r0001", "sc_0004", "0,3 MB", "#aprovado", "✔"]],
            [70, 170, 110, 70, 70, 120, 80], sel=3)
    s.marker(x1 - 20, y0 + 34, "2")
    s.text(x0 + 20, y0 + 200, "Dependências de a_…04", 13, "bold")
    s.marker(x0 + 205, y0 + 195, "3")
    nodes = [("MScript r0003", 0), ("MVisual r0002", 1), ("MBoard r0004", 2), ("MSound r0001", 3),
             ("MScene c4 r0002", 4), ("MCut r0001", 5)]
    for n, i in nodes:
        nx = x0 + 30 + i * 135
        s.rect(nx, y0 + 230, 120, 36, fill="#FFFFFF", stroke=C["err"] if i == 4 else C["line"], rx=5,
               sw=2 if i == 4 else 1)
        s.text(nx + 60, y0 + 253, n, 10.5, "bold", anchor="middle")
        if i < 5:
            s.line(nx + 120, y0 + 248, nx + 135, y0 + 248)
    s.button(x0 + 20, y0 + 300, 200, "Abrir no aplicativo", True)
    s.button(x0 + 228, y0 + 300, 200, "Revincular arquivo...")
    s.button(x0 + 436, y0 + 300, 200, "Exportar relatório")
    s.text(x0 + 20, y0 + 360, "Fila de eventos MMP", 13, "bold")
    s.marker(x0 + 180, y0 + 355, "4")
    s.table(x0 + 20, y0 + 372, ["event_id", "origin → target", "requested_change", "status", "tentativas"],
            [["evt_…7Q", "MBoard → MScript", "objeto pistola→bazuca", "#ok", "1"],
             ["evt_…7Q", "MScript → MVisual", "reindexar sc_0004", "#em execução", "1"],
             ["evt_…2K", "MBoard → MScript", "fala c4 linha 3", "#falha", "3"]],
            [90, 170, 230, 120, 80])
    s.button(x0 + 20, y0 + 480, 160, "Retomar evento")
    s.button(x0 + 188, y0 + 480, 160, "Cancelar evento", danger=True)
    return s


@screen("01-mmenu-nova-producao")
def _():
    s = Svg(620, 470)
    s.rect(0, 0, 620, 470, fill="#FFFFFF", stroke=C["line"])
    s.rect(0, 0, 620, 34, fill=C["head"], stroke="none")
    s.text(14, 22, "Nova produção — MMenu", 13, "bold", "#FFFFFF")
    s.field(20, 64, 580, "TÍTULO DO FILME", "Filme Exemplo")
    s.field(20, 112, 420, "PASTA-RAIZ (productions/)", "/home/usuario/MaurinMovie/productions")
    s.button(448, 112, 152, "Procurar...")
    s.field(20, 160, 580, "PASTA GERADA (slug__production_id)", "filme-exemplo__p_01JD7W3K9M8X0Q1R2S3T4V5W6Y")
    s.text(20, 208, "PROJETOS A INICIALIZAR", 10, "bold", C["muted"])
    for i, a in enumerate(["MScript", "MVisual", "MBoard", "MSound", "MScene", "MCut"]):
        s.check(24 + (i % 3) * 190, 232 + (i // 3) * 24, a, True)
    s.combo(20, 300, 280, "IDIOMA DO ROTEIRO", "pt-BR")
    s.combo(320, 300, 280, "PERFIL DE PROVEDORES DE IA", "Padrão (local)")
    s.text(20, 352, "Serão criados: production.json, catalog.json, settings/, projects/NN-app/project.json,", 10.5,
           fill=C["muted"])
    s.text(20, 368, "shared/{imports,cache,temp,logs,events}/ e backups/. Nenhuma revisão é criada ainda.", 10.5,
           fill=C["muted"])
    s.button(380, 420, 104, "Cancelar")
    s.button(492, 420, 108, "Criar", True)
    return s


@screen("01-mmenu-configuracoes")
def _():
    s = Svg(900, 640)
    s.rect(0, 0, 900, 640, fill="#FFFFFF", stroke=C["line"])
    s.rect(0, 0, 900, 34, fill=C["head"], stroke="none")
    s.text(14, 22, "Configurações — MMenu  ·  Produção: Filme Exemplo", 13, "bold", "#FFFFFF")
    s.rect(0, 34, 230, 556, fill=C["side"], stroke=C["line"])
    s.listbox(8, 44, 214, 536, [("Geral", None), ("Produção", None), ("IA", None), ("Texto", "ok", 1),
              ("Imagem/Foto", "ok", 1), ("Som — Voz", "ok", 1), ("Som — Efeitos", "pendente", 1), ("Vídeo", "ok", 1),
              ("Visão (opcional)", None, 1), ("Transcrição (opcional)", None, 1), ("Programas", None),
              ("Prompts", None), ("Mídia e render", None), ("Predefinições", None), ("Políticas", None),
              ("Ferramentas e executáveis", "falha"), ("Rede", None), ("Interface e log", None)], sel=4, row=29)
    s.marker(222, 54, "1")
    s.text(246, 60, "IA Imagem/Foto", 16, "bold")
    s.text(246, 80, "Usado por: MVisual, MBoard", 11, fill=C["muted"])
    s.marker(420, 76, "5")
    s.table(246, 92, ["id", "rótulo", "adaptador", "modelo", "★"],
            [["image.default", "Imagem principal", "openai-compatible", "img-model-x", "★"],
             ["image.local", "Imagem local", "local-cli", "sd-local", ""],
             ["image.mock", "Simulado", "mock", "—", ""]], [120, 140, 130, 150, 40], sel=0)
    s.button(246, 186, 70, "+")
    s.button(322, 186, 90, "Duplicar")
    s.button(418, 186, 90, "Remover", danger=True)
    s.button(514, 186, 140, "Definir como padrão")
    s.marker(884, 100, "2")
    s.combo(246, 240, 300, "ADAPTADOR", "openai-compatible")
    s.field(560, 240, 320, "MODELO", "img-model-x")
    s.field(246, 288, 634, "URL BASE", "https://api.exemplo.com/v1")
    s.field(246, 336, 500, "CHAVE DE API (cofre local; JSON guarda só secret_ref)", "••••••••••••••••••••")
    s.button(754, 336, 126, "Mostrar")
    s.field(246, 384, 140, "TIMEOUT (s)", "120")
    s.field(396, 384, 140, "TENTATIVAS", "3")
    s.field(546, 384, 160, "LIMITE / MIN", "30")
    s.field(716, 384, 164, "CUSTO / IMAGEM", "0,04")
    s.field(246, 432, 140, "LARGURA", "1024")
    s.field(396, 432, 140, "ALTURA", "1024")
    s.field(546, 432, 160, "PASSOS", "30")
    s.field(716, 432, 164, "GUIDANCE", "7,0")
    s.field(246, 480, 460, "NEGATIVO PADRÃO", "texto, marca d'água, deformação")
    s.check(720, 498, "Aceita referências")
    s.marker(884, 250, "3")
    s.button(246, 524, 150, "Testar conexão", True)
    s.text(406, 541, "✔ 1,8 s · imagem 64×64 recebida", 11, "bold", C["ok"])
    s.marker(884, 536, "4")
    s.rect(0, 590, 900, 50, fill="#F4F6F8", stroke=C["line"])
    s.button(16, 602, 160, "Restaurar padrões")
    s.button(660, 602, 104, "Cancelar")
    s.button(772, 602, 112, "Salvar", True)
    s.marker(884, 580, "6")
    return s


# =====================================================================
# MSCRIPT
# =====================================================================
SCRIPT_STEPS = ["Sinopse", "Roteiro", "Edição/Revisão", "Validação", "Personagens", "Salvar"]


@screen("02-mscript-sinopse")
def _():
    s, (x0, y0, x1, y1) = chrome("MScript", SCRIPT_STEPS, 0, rev="(nova)", state="rascunho", left=False,
                                  footer="Sinopse não salva")
    s.text(x0 + 20, y0 + 28, "Sinopse e premissas", 16, "bold")
    s.field(x0 + 20, y0 + 56, 500, "TÍTULO PROVISÓRIO", "A Carta do Farol")
    s.combo(x0 + 530, y0 + 56, 120, "FORMATO", "Curta")
    s.field(x0 + 660, y0 + 56, 110, "DURAÇÃO-ALVO", "15 min")
    s.combo(x0 + 20, y0 + 104, 250, "GÊNERO", "Drama / Suspense")
    s.combo(x0 + 280, y0 + 104, 160, "IDIOMA", "pt-BR")
    s.field(x0 + 450, y0 + 104, 320, "PÚBLICO / CLASSIFICAÇÃO", "14 anos")
    s.marker(x0 + 790, y0 + 70, "1")
    s.text(x0 + 20, y0 + 152, "SINOPSE", 10, "bold", C["muted"])
    s.textarea(x0 + 20, y0 + 158, 750, 170, ["Num vilarejo costeiro, Ana, faroleira solitária, encontra uma carta",
               "de 1962 escondida na lanterna do farol. A carta revela que o pai dela não",
               "morreu no naufrágio... (texto livre, sem limite rígido; contador de palavras: 182)"])
    s.marker(x0 + 790, y0 + 170, "2")
    s.text(x0 + 20, y0 + 350, "PREMISSAS / RESTRIÇÕES (uma por linha)", 10, "bold", C["muted"])
    s.textarea(x0 + 20, y0 + 356, 750, 90, ["Época: 1962 e dias atuais", "Máximo 4 locações",
               "Sem violência explícita"])
    s.marker(x0 + 790, y0 + 370, "3")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "PARÂMETROS DA IA (TEXTO)", 11, "bold", C["muted"])
    s.combo(rx + 12, y0 + 46, 276, "PROVEDOR (do MMenu)", "text.default · somente leitura")
    s.field(rx + 12, y0 + 92, 130, "Nº DE CENAS (aprox.)", "10")
    s.field(rx + 158, y0 + 92, 130, "CRIATIVIDADE", "0,7")
    s.check(rx + 14, y0 + 140, "Incluir diálogos")
    s.check(rx + 14, y0 + 162, "Sugerir objetos e figurinos")
    s.button(rx + 12, y0 + 190, 276, "Alterar no MMenu…", h=22)
    s.text(rx + 12, y0 + 232, "PROMPT ADICIONAL (desta geração)", 10, "bold", C["muted"])
    s.textarea(rx + 12, y0 + 238, 276, 100, ["Tom melancólico; final aberto."])
    s.marker(W - 16, y0 + 18, "4")
    s.button(x0 + 20, y1 - 40, 150, "Salvar rascunho")
    s.button(x0 + 620, y1 - 40, 150, "Gerar roteiro ▸", True)
    s.marker(x0 + 790, y1 - 27, "5")
    return s


@screen("02-mscript-roteiro")
def _():
    s, (x0, y0, x1, y1) = chrome("MScript", SCRIPT_STEPS, 2, rev="r0002 (rascunho r0003)", state="rascunho",
                                  footer="Cena 4 alterada · não validada")
    s.text(12, y0 + 22, "CENAS (ordem)", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 330, [("1 · O farol", "aprovado"), ("2 · A carta", "aprovado"),
              ("3 · Cais", "aprovado"), ("4 · Confronto", "pendente"), ("5 · Tempestade", "gerado"),
              ("6 · O barco", "gerado"), ("7 · Memória 1962", "gerado"), ("8 · Retorno", "gerado")], sel=3)
    s.button(10, y0 + 368, 116, "+ Cena")
    s.button(134, y0 + 368, 116, "Excluir", danger=True)
    s.button(10, y0 + 400, 116, "▲ Subir")
    s.button(134, y0 + 400, 116, "▼ Descer")
    s.text(12, y0 + 450, "Arraste para reordenar; o", 10, fill=C["muted"])
    s.text(12, y0 + 464, "scene_id não muda.", 10, fill=C["muted"])
    s.marker(250, y0 + 20, "1")
    s.tabs(x0 + 10, y0 + 8, ["Texto da cena", "Diálogos", "Comparar revisões", "Prompt"], 0)
    s.field(x0 + 10, y0 + 54, 360, "CABEÇALHO", "EXT. CAIS DO VILAREJO — NOITE")
    s.field(x0 + 380, y0 + 54, 140, "DURAÇÃO EST.", "00:01:30")
    s.textarea(x0 + 10, y0 + 90, 510, 360, ["**AÇÃO", "Ana caminha pelo cais sob chuva fina. Rui a espera junto",
               "ao barco, segurando uma pistola antiga.", "", "**RUI", "  (baixo) Você não devia ter aberto aquela carta.",
               "", "**ANA", "  Ela era endereçada a mim.", "", "**AÇÃO", "Rui ergue a pistola. Um trovão ilumina o farol."],
               mono=True)
    s.marker(x0 + 530, y0 + 100, "2")
    s.button(x0 + 10, y1 - 40, 170, "Reescrever por prompt...")
    s.button(x0 + 188, y1 - 40, 160, "Reescrever roteiro...")
    s.button(x0 + 380, y1 - 40, 140, "Validar revisão ▸", True)
    s.marker(x0 + 530, y1 - 27, "3")
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Metadados", "Revisões", "IA"], 0)
    s.field(rx + 12, y0 + 52, 276, "scene_id", "sc_01JD7W…0004")
    s.combo(rx + 12, y0 + 98, 135, "LOCAL", "Cais")
    s.combo(rx + 153, y0 + 98, 135, "PERÍODO", "Noite")
    s.combo(rx + 12, y0 + 144, 276, "CLIMA EMOCIONAL", "Tensão")
    s.text(rx + 12, y0 + 194, "PERSONAGENS PRESENTES", 10, "bold", C["muted"])
    s.listbox(rx + 12, y0 + 200, 276, 52, ["Ana (ch_…01)", "Rui (ch_…03)"], row=24)
    s.text(rx + 12, y0 + 272, "OBJETOS / FIGURINOS SUGERIDOS", 10, "bold", C["muted"])
    s.listbox(rx + 12, y0 + 278, 276, 76, [("pistola antiga", "gerado"), ("capa de chuva de Ana", "gerado"),
              ("barco 'Gaivota'", "aprovado")])
    s.text(rx + 12, y0 + 376, "AVISOS DE CONSISTÊNCIA (IA)", 10, "bold", C["muted"])
    s.textarea(rx + 12, y0 + 382, 276, 80, ["⚠ Rui aparece na cena 3 de terno e", "  aqui de capa — confirmar figurino.",
               "  [Aplicar] [Ignorar]"], size=10.5)
    s.marker(W - 16, y0 + 40, "4")
    return s


@screen("02-mscript-comparar")
def _():
    s, (x0, y0, x1, y1) = chrome("MScript", SCRIPT_STEPS, 2, rev="r0002 × r0003", state="rascunho",
                                  left=False, right=False, footer="3 cenas alteradas · 1 incluída · 0 excluídas")
    s.text(20, y0 + 28, "Comparar revisões", 16, "bold")
    s.combo(220, y0 + 14, 160, "", "r0002 (aprovada)")
    s.text(390, y0 + 32, "×", 14, "bold")
    s.combo(406, y0 + 14, 160, "", "r0003 (rascunho)")
    s.check(590, y0 + 32, "Somente diferenças")
    s.marker(1080, y0 + 24, "1")
    s.panel(20, y0 + 50, 520, 420, "r0002 · cena 4 · Confronto")
    s.panel(560, y0 + 50, 520, 420, "r0003 · cena 4 · Confronto")
    left = ["Rui a espera junto ao barco, segurando", "uma pistola antiga.", "", "RUI: (baixo) Você não devia",
            "ter aberto aquela carta."]
    right = ["Rui a espera junto ao barco, segurando", "uma bazuca enferrujada.", "", "RUI: (baixo) Você não devia",
             "ter lido aquela carta."]
    for i, (a, b) in enumerate(zip(left, right)):
        yy = y0 + 90 + i * 20
        if a != b:
            s.rect(22, yy - 13, 516, 18, fill="#FBEAEA", stroke="none")
            s.rect(562, yy - 13, 516, 18, fill="#E5F4EA", stroke="none")
        s.text(30, yy, a, 11.5)
        s.text(570, yy, b, 11.5)
    s.marker(1080, y0 + 90, "2")
    s.text(20, y0 + 494, "Entidades afetadas: obj pistola (removida da cena 4) · obj bazuca (nova) · fala ch_…03 #2",
           11, fill=C["muted"])
    s.button(20, y1 - 40, 180, "Restaurar trecho da r0002")
    s.button(208, y1 - 40, 160, "Exportar diff (.md)")
    s.button(900, y1 - 40, 180, "Fechar comparação", True)
    return s


@screen("02-mscript-personagens")
def _():
    s, (x0, y0, x1, y1) = chrome("MScript", SCRIPT_STEPS, 4, rev="r0003", state="aprovado",
                                  footer="Mapa de personagens extraído da r0003 · 1 item a conferir")
    s.text(12, y0 + 22, "PERSONAGENS", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 220, [("Ana", "aprovado"), ("Rui", "pendente"), ("Velho Tomé", "aprovado"),
              ("Menina (1962)", "gerado")], sel=1)
    s.button(10, y0 + 258, 240, "Extrair novamente da revisão")
    s.button(10, y0 + 290, 240, "+ Personagem manual")
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 20, y0 + 28, "Rui  ·  ch_01JD7W…0003", 16, "bold")
    s.field(x0 + 20, y0 + 56, 250, "NOME", "Rui")
    s.field(x0 + 280, y0 + 56, 230, "ALIASES", "o pescador; ele; Ruizinho")
    s.text(x0 + 20, y0 + 104, "DESCRIÇÃO FÍSICA (evidência do roteiro)", 10, "bold", C["muted"])
    s.textarea(x0 + 20, y0 + 110, 490, 80, ["Homem de ~60 anos, barba grisalha, mãos calejadas.",
               "↳ cena 3, linha 2: \"o velho pescador de barba grisalha\""])
    s.text(x0 + 20, y0 + 210, "FIGURINOS DESCRITOS POR CENA", 10, "bold", C["muted"])
    s.table(x0 + 20, y0 + 218, ["Cena", "Figurino", "Evidência"],
            [["3", "terno escuro", "linha 4"], ["4", "capa de chuva amarela", "linha 1"], ["7", "macacão de pesca", "linha 2"]],
            [60, 200, 230])
    s.text(x0 + 20, y0 + 330, "OCORRÊNCIAS", 10, "bold", C["muted"])
    s.text(x0 + 20, y0 + 350, "Cenas 3, 4, 6, 8   (4 cenas · 11 falas)", 12)
    s.marker(x0 + 520, y0 + 60, "2")
    s.button(x0 + 20, y1 - 40, 160, "Validar personagem", True)
    s.button(x0 + 188, y1 - 40, 160, "Validar todos")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "METADADOS LIVRES", 11, "bold", C["muted"])
    s.table(rx + 8, y0 + 32, ["Chave", "Valor"], [["idade", "60"], ["voz", "grave, pausada"], ["papel", "antagonista"]],
            [100, 184])
    s.button(rx + 8, y0 + 130, 284, "+ Metadado")
    s.marker(W - 16, y0 + 18, "3")
    return s


# =====================================================================
# MVISUAL
# =====================================================================
VIS_STEPS = ["Importar roteiro", "Indexação", "Geração de referências", "Validação", "Salvar"]


@screen("03-mvisual-indexacao")
def _():
    s, (x0, y0, x1, y1) = chrome("MVisual", VIS_STEPS, 1, rev="r0002", state="rascunho",
                                  footer="Fonte: MScript pr_script_01 r0003 ✔ · 38 entidades · 3 ambiguidades")
    s.tabs(6, y0 + 6, ["Entidades", "Cenas"], 0, w=120)
    s.field(10, y0 + 52, 240, "BUSCAR (nome, alias, ID)", "rui")
    s.listbox(10, y0 + 84, 240, 300, [("Personagens (6)", None), ("Ana", "aprovado", 1), ("Rui", "pendente", 1),
              ("Locais (4)", None), ("Casa de Ana", "aprovado", 1), ("Farol", "aprovado", 1),
              ("Objetos (21)", None), ("Pistola antiga", "gerado", 1), ("Figurinos (7)", None),
              ("Capa amarela (Rui)", "gerado", 1)], sel=2, row=26)
    s.text(12, y0 + 408, "AMBIGUIDADES (3)", 11, "bold", C["warn"])
    s.listbox(10, y0 + 416, 240, 52, ["\"o velho\" = Rui ou Tomé?", "\"barco\" × \"Gaivota\""])
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 20, y0 + 28, "Rui  ·  personagem  ·  ch_…0003", 16, "bold")
    s.text(x0 + 20, y0 + 50, "Aliases: o pescador, ele, Ruizinho   ·   Descrição canônica: homem ~60, barba grisalha",
           11, fill=C["muted"])
    s.text(x0 + 20, y0 + 80, "Ocorrências (entidade → cenas)", 12, "bold")
    s.table(x0 + 20, y0 + 90, ["Cena", "Papel", "Figurino", "Estado", "Evidência"],
            [["3 · Cais", "presente/fala", "terno escuro", "—", "\"o velho pescador…\""],
             ["4 · Confronto", "presente/fala", "capa amarela", "molhado", "\"Rui a espera…\""],
             ["6 · O barco", "mencionado", "—", "—", "\"ele partiu\" (corref.)"],
             ["8 · Retorno", "presente", "macacão", "ferido", "\"Rui manca…\""]],
            [100, 100, 100, 70, 150], sel=1)
    s.marker(x1 - 20, y0 + 84, "2")
    s.text(x0 + 20, y0 + 230, "Relacionamentos", 12, "bold")
    s.listbox(x0 + 20, y0 + 240, 520, 76, ["pai de → Ana (inferido, cena 7)", "usa → Pistola antiga (cenas 4, 8)",
              "possui → Barco 'Gaivota'"])
    s.text(x0 + 20, y0 + 340, "Imagens associadas", 12, "bold")
    s.text(x0 + 20, y0 + 360, "(vazio na etapa 1 — indexação não gera imagens)", 11, fill=C["muted"], italic=True)
    s.button(x0 + 20, y1 - 40, 150, "Mesclar entidades...")
    s.button(x0 + 178, y1 - 40, 150, "Separar entidade...")
    s.button(x0 + 380, y1 - 40, 160, "Concluir indexação ▸", True)
    s.marker(x0 + 550, y1 - 27, "3")
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Ficha", "Atributos", "Histórico"], 0)
    s.combo(rx + 12, y0 + 52, 276, "TIPO", "character")
    s.field(rx + 12, y0 + 98, 276, "NOME CANÔNICO", "Rui")
    s.text(rx + 12, y0 + 146, "ATRIBUTOS", 10, "bold", C["muted"])
    s.table(rx + 8, y0 + 152, ["Atributo", "Valor"], [["idade", "~60"], ["cabelo", "grisalho"], ["altura", "alta"],
            ["marca", "cicatriz mão esq."]], [110, 174])
    s.marker(W - 16, y0 + 40, "4")
    return s


@screen("03-mvisual-geracao")
def _():
    s, (x0, y0, x1, y1) = chrome("MVisual", VIS_STEPS, 2, rev="r0002", state="rascunho", sync="pendente",
                                  footer="Gerando 23/38 · 1 falha · tempo est. 00:12:40", prog=0.6)
    s.text(12, y0 + 22, "LOTE DE GERAÇÃO", 11, "bold", C["muted"])
    s.check(14, y0 + 48, "Personagens (6)")
    s.check(14, y0 + 70, "Objetos (21)")
    s.check(14, y0 + 92, "Locais (4)")
    s.check(14, y0 + 114, "Figurinos (7)")
    s.check(14, y0 + 136, "Pular itens já aprovados")
    s.check(14, y0 + 158, "Pular itens já gerados", False)
    s.combo(10, y0 + 196, 240, "PROVEDOR (do MMenu)", "image.default")
    s.field(10, y0 + 242, 115, "RESOLUÇÃO", "1024×1024")
    s.field(135, y0 + 242, 115, "SEMENTE BASE", "4211")
    s.combo(10, y0 + 288, 240, "ESTILO", "realista cinematográfico")
    s.button(10, y0 + 330, 116, "▶ Iniciar", True)
    s.button(134, y0 + 330, 116, "⏸ Pausar")
    s.button(10, y0 + 362, 240, "Retomar falhas")
    s.button(10, y0 + 394, 240, "Alterar no MMenu…")
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 20, y0 + 28, "Fila de geração", 16, "bold")
    s.table(x0 + 20, y0 + 40, ["Entidade", "Vista", "Estado", "Tent.", "Tempo"],
            [["Ana", "frontal", "#gerado", "1", "18 s"], ["Ana", "costas", "#gerado", "1", "17 s"],
             ["Ana", "perfil dir.", "#gerado", "1", "19 s"], ["Ana", "perfil esq.", "#gerado", "1", "18 s"],
             ["Rui", "frontal", "#em execução", "1", "…"], ["Pistola", "frontal", "#falha", "3", "—"],
             ["Farol", "geral", "#pendente", "0", "—"]], [140, 110, 130, 60, 80], sel=4)
    s.marker(x1 - 20, y0 + 34, "2")
    s.text(x0 + 20, y0 + 240, "Detalhe da falha: Pistola · frontal", 12, "bold", C["err"])
    s.textarea(x0 + 20, y0 + 250, 520, 70, ["Provedor retornou HTTP 429 (limite). Próxima tentativa automática em 60 s.",
               "Itens válidos já gerados NÃO serão refeitos."], size=10.5)
    s.text(x0 + 20, y0 + 350, "Prévia ao vivo", 12, "bold")
    for i, v in enumerate(["frontal", "costas", "perfil dir.", "perfil esq."]):
        s.image(x0 + 20 + i * 132, y0 + 360, 124, 124, "Rui" if i == 0 else "", v)
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "PROMPT GERADO (Rui · frontal)", 11, "bold", C["muted"])
    s.textarea(rx + 12, y0 + 30, 276, 160, ["Retrato de corpo inteiro, vista", "frontal, homem ~60 anos, barba",
               "grisalha, cicatriz na mão esquerda,", "fundo cinza neutro, luz difusa,", "escala padrão 1:1, sem figurino",
               "específico (identidade base)."], size=10.5)
    s.field(rx + 12, y0 + 216, 276, "NEGATIVO", "texto, marca d'água, deformação")
    s.text(rx + 12, y0 + 266, "REFERÊNCIAS USADAS", 10, "bold", C["muted"])
    s.listbox(rx + 12, y0 + 272, 276, 52, ["(nenhuma — primeira vista)", "vista frontal será referência das demais"])
    s.marker(W - 16, y0 + 18, "3")
    return s


@screen("03-mvisual-validacao")
def _():
    s, (x0, y0, x1, y1) = chrome("MVisual", VIS_STEPS, 3, rev="r0002", state="aguardando revisão",
                                  footer="Aprovados 14/38 · rejeitados 2 · pendentes 22")
    s.text(12, y0 + 22, "ITENS A REVISAR", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 400, [("Ana · identidade base", "aprovado"), ("Ana · capa de chuva", "pendente"),
              ("Rui · identidade base", "pendente"), ("Rui · capa amarela", "gerado"), ("Pistola antiga", "rejeitado"),
              ("Bazuca", "cascata"), ("Farol · exterior", "aprovado"), ("Casa de Ana · sala", "pendente")], sel=2)
    s.marker(250, y0 + 20, "1")
    s.tabs(x0 + 10, y0 + 8, ["Vistas", "Variantes", "Comparar versões", "Cenas"], 0)
    for i, v in enumerate(["frontal", "costas", "perfil direito", "perfil esquerdo"]):
        s.image(x0 + 12 + i * 133, y0 + 42, 125, 180, "Rui", v, border=C["accent"] if i == 0 else None)
    s.marker(x1 - 20, y0 + 50, "2")
    s.text(x0 + 12, y0 + 248, "Origem textual: cena 3 l.2 · cena 4 l.1   ·   Cenas: 3, 4, 6, 8", 11, fill=C["muted"])
    s.text(x0 + 12, y0 + 276, "COMENTÁRIO / PROMPT DE CORREÇÃO", 10, "bold", C["muted"])
    s.textarea(x0 + 12, y0 + 282, 520, 70, ["Barba mais curta; manter cicatriz visível na mão esquerda."])
    bx = x0 + 12
    for lb, p, d in [("Aprovar", True, False), ("Rejeitar", False, True), ("Corrigir por prompt", False, False),
                     ("Regenerar vista", False, False), ("Editar manualmente...", False, False)]:
        w = 30 + len(lb) * 6.4
        s.button(bx, y0 + 366, w, lb, p, danger=d)
        bx += w + 6
    s.marker(bx + 8, y0 + 379, "3")
    s.text(x0 + 12, y0 + 424, "Aprovar a identidade base NÃO aprova figurinos e variantes (aprovação separada).", 10.5,
           fill=C["warn"])
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Metadados", "Histórico"], 0)
    s.table(rx + 8, y0 + 40, ["Campo", "Valor"], [["asset_id", "a_…v01"], ["modelo", "imagem: padrão"], ["semente", "4211"],
            ["versão", "v2"], ["prompt", "ver ▸"], ["sha256", "3be1…"], ["estado", "pending_review"]], [100, 184])
    s.text(rx + 12, y0 + 232, "HISTÓRICO DE VERSÕES", 10, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 240, 284, 100, [("v2 · regenerado", "gerado"), ("v1 · gerado", "rejeitado")], sel=0)
    s.marker(W - 16, y0 + 40, "4")
    return s


# =====================================================================
# MBOARD
# =====================================================================
BOARD_STEPS = ["Importar fontes", "Geração IA", "Revisão e segmentos", "Ajustes editoriais", "Sincronizar", "Salvar"]


@screen("04-mboard-grade")
def _():
    s, (x0, y0, x1, y1) = chrome("MBoard", BOARD_STEPS, 1, rev="r0004", state="rascunho",
                                  footer="Fontes: MScript r0003 ✔ · MVisual r0002 ✔ · 8/10 cenas · 1 falha", prog=0.8)
    s.text(12, y0 + 22, "CENAS", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 360, [("1 · O farol", "aprovado"), ("2 · A carta", "gerado"), ("3 · Cais", "gerado"),
              ("4 · Confronto", "gerado"), ("4.1 · aproximação", "gerado", 1), ("4.2 · a arma", "gerado", 1),
              ("5 · Tempestade", "falha"), ("6 · O barco", "gerado"), ("7 · Memória", "pendente")], sel=3)
    s.text(12, y0 + 412, "Duração total:", 11, "bold")
    s.text(110, y0 + 412, "00:14:20 / alvo 15:00", 11)
    s.button(10, y0 + 426, 240, "▶ Gerar todas / retomar", True)
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 20, y0 + 26, "Storyboards (quadro inicial → final)", 15, "bold")
    s.marker(x1 - 20, y0 + 20, "2")
    for i, (t, d, st) in enumerate([("1 · O farol", "00:01:10", "aprovado"), ("2 · A carta", "00:02:00", "gerado"),
                                    ("3 · Cais", "00:01:40", "gerado"), ("4 · Confronto", "00:01:30", "gerado")]):
        cy = y0 + 40 + i * 132
        s.rect(x0 + 16, cy, x1 - x0 - 32, 124, fill="#FFFFFF", stroke=C["accent"] if i == 3 else C["line"], rx=5,
               sw=2 if i == 3 else 1)
        s.text(x0 + 26, cy + 18, t, 12, "bold")
        s.badge(x0 + 140, cy + 18, st)
        s.text(x1 - 30, cy + 18, d, 11, "bold", anchor="end")
        s.image(x0 + 26, cy + 26, 130, 88, "inicial")
        s.text(x0 + 166, cy + 74, "→", 16, "bold", C["muted"])
        s.image(x0 + 184, cy + 26, 130, 88, "final")
        s.textarea(x0 + 324, cy + 26, x1 - x0 - 364, 88, ["Falas: RUI (2) · ANA (1)", "Ambiente: chuva fina, noite",
                   "Ativos: ch_…03, ch_…01, ob_pistola", "Segmentos: 2"], size=10.5)
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "PARÂMETROS DE GERAÇÃO", 11, "bold", C["muted"])
    s.combo(rx + 12, y0 + 46, 276, "PROVEDOR (do MMenu)", "image.default · somente leitura")
    s.combo(rx + 12, y0 + 92, 276, "PROPORÇÃO", "16:9 (1920×1080)")
    s.combo(rx + 12, y0 + 138, 276, "ESTILO", "storyboard colorido")
    s.check(rx + 14, y0 + 186, "Usar somente referências aprovadas")
    s.check(rx + 14, y0 + 208, "Gerar falhas apenas (retomar)", False)
    s.button(rx + 12, y0 + 226, 276, "Alterar no MMenu…", h=22)
    s.marker(W - 16, y0 + 18, "3")
    return s


@screen("04-mboard-segmentos")
def _():
    s, (x0, y0, x1, y1) = chrome("MBoard", BOARD_STEPS, 2, rev="r0004", state="rascunho",
                                  footer="Cena 4: soma dos segmentos 00:01:30 = duração da cena ✔")
    s.text(12, y0 + 22, "CENA 4 · SEGMENTOS", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 120, [("4 · Confronto (pai)", "gerado"), ("4.1 · 00:00:50", "gerado", 1),
              ("4.2 · 00:00:40", "pendente", 1)], sel=1)
    s.field(10, y0 + 180, 110, "DIVIDIR EM N", "2")
    s.combo(130, y0 + 180, 120, "CRITÉRIO", "por falas")
    s.button(10, y0 + 214, 240, "Subdividir...", True)
    s.button(10, y0 + 246, 240, "Desfazer subdivisão")
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 16, y0 + 26, "Segmento 4.1 — aproximação", 15, "bold")
    s.image(x0 + 16, y0 + 40, 255, 160, "quadro inicial", "a_…f10 (abre a cena)")
    s.image(x0 + 285, y0 + 40, 255, 160, "quadro final", "a_…f11 = inicial do 4.2", border=C["ok"])
    s.marker(x1 - 20, y0 + 50, "2")
    s.text(x0 + 16, y0 + 222, "Linha de segmentos (quadros de fronteira compartilhados)", 11, "bold")
    fx = x0 + 16
    for i, lb in enumerate(["f10", "f11", "f12"]):
        s.image(fx + i * 190, y0 + 232, 80, 50, lb, border=C["ok"] if i == 1 else None)
        if i < 2:
            s.rect(fx + i * 190 + 80, y0 + 250, 110, 14, fill="#DCE8F5", stroke=C["accent"], rx=3)
            s.text(fx + i * 190 + 135, y0 + 261, f"4.{i + 1} · {'50 s' if i == 0 else '40 s'}", 9.5, "bold",
                   anchor="middle")
    s.text(x0 + 16, y0 + 304, "O mesmo asset_id f11 é o final do 4.1 e o inicial do 4.2 (sem redesenho).", 10.5,
           fill=C["muted"])
    s.field(x0 + 16, y0 + 336, 120, "DURAÇÃO (s)", "50")
    s.text(x0 + 150, y0 + 330, "FALAS DO SEGMENTO", 10, "bold", C["muted"])
    s.textarea(x0 + 150, y0 + 336, 390, 60, ["RUI: Você não devia ter aberto aquela carta.", "ANA: Ela era endereçada a mim."],
               size=10.5)
    bx = x0 + 16
    for lb, p, d in [("Aprovar", True, False), ("Rejeitar", False, True), ("Substituir quadro...", False, False),
                     ("Regenerar por prompt", False, False)]:
        w = 30 + len(lb) * 6.4
        s.button(bx, y1 - 40, w, lb, p, danger=d)
        bx += w + 6
    s.marker(bx + 8, y1 - 27, "3")
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Propriedades", "Referências", "Orientações"], 0)
    s.table(rx + 8, y0 + 40, ["Campo", "Valor"], [["segment_id", "sg_…0401"], ["parent_board", "bd_…04"], ["ordem", "1"],
            ["início", "00:00:00"], ["fim", "00:00:50"], ["estado", "generated"]], [100, 184])
    s.text(rx + 12, y0 + 214, "ATIVOS VISUAIS USADOS", 10, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 222, 284, 76, ["Rui · capa amarela (MVisual a_…)", "Ana · capa de chuva", "Cais · noite"])
    s.marker(W - 16, y0 + 40, "4")
    return s


@screen("04-mboard-sincronizacao")
def _():
    s, (x0, y0, x1, y1) = chrome("MBoard", BOARD_STEPS, 4, rev="r0004 → r0005", state="aprovado", sync="em execução",
                                  left=False, footer="Transação tx_…9A em execução · etapa 2 de 3", prog=0.55)
    s.text(20, y0 + 28, "Ajuste aprovado — sincronização em cascata", 16, "bold")
    s.text(20, y0 + 50, "Alteração: cena 4 · objeto \"pistola antiga\" → \"bazuca enferrujada\"  ·  event_id evt_01JD…7Q  ·  "
           "idempotency_key 7Q-r0004", 11, fill=C["muted"])
    s.marker(780, y0 + 24, "1")
    stages = [("1  MScript", "r0003 → r0004", "aprovado", "Cena 4 atualizada; IDs preservados"),
              ("2  MVisual", "r0002 → r0003", "em execução", "Gerando vistas da bazuca (2/4)"),
              ("3  MBoard", "r0004 → r0005", "pendente", "Regenerar quadros 4.1 f11 e 4.2 f12")]
    for i, (a, r, st, d) in enumerate(stages):
        cy = y0 + 76 + i * 96
        s.rect(20, cy, 760, 80, fill="#FFFFFF", stroke=C["line"], rx=6)
        s.text(36, cy + 26, a, 14, "bold")
        s.text(36, cy + 48, r, 11, fill=C["muted"])
        s.badge(180, cy + 26, st)
        s.text(180, cy + 50, d, 11)
        if st == "em execução":
            s.progress(180, cy + 60, 400, 0.5, h=8)
        if i < 2:
            s.text(400, cy + 92, "▼", 12, fill=C["muted"], anchor="middle")
    s.marker(780, y0 + 90, "2")
    s.text(20, y0 + 384, "Regras: uma etapa só inicia após a anterior publicar a revisão; falha deixa a transação "
           "pendente e retomável;", 10.5, fill=C["muted"])
    s.text(20, y0 + 400, "o evento não é reenviado ao MBoard pelo MScript (evita laço); 'sincronizado' só ao fim da "
           "etapa 3 com integridade.", 10.5, fill=C["muted"])
    s.button(20, y1 - 40, 140, "Retomar")
    s.button(168, y1 - 40, 140, "Cancelar", danger=True)
    s.button(316, y1 - 40, 180, "Abrir MVisual na r0003")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "LOG DA TRANSAÇÃO", 11, "bold", C["muted"])
    s.textarea(rx + 8, y0 + 30, 284, 420, ["10:02:11 tx criada (MBoard r0004)", "10:02:11 → MScript evt enfileirado",
               "10:02:19 MScript publicou r0004", "10:02:20 → MVisual evt enfileirado", "10:02:31 MVisual reindexou sc_0004",
               "10:02:31 MVisual: ob_bazuca criado", "10:03:05 vista frontal ok", "10:03:40 vista traseira ok",
               "10:03:41 gerando perfil direito…"], mono=True, size=10)
    s.marker(W - 16, y0 + 18, "3")
    return s


# =====================================================================
# MSOUND
# =====================================================================
SOUND_STEPS = ["Banco sonoro (IA A)", "Validação isolada", "Vinculação e prévia", "Salvar"]


@screen("05-msound-vozes")
def _():
    s, (x0, y0, x1, y1) = chrome("MSound", SOUND_STEPS, 1, rev="r0001", state="rascunho",
                                  footer="Vozes 2/4 aprovadas · Efeitos 9/31 aprovados")
    s.tabs(6, y0 + 6, ["Vozes", "Efeitos"], 0, w=120)
    s.listbox(10, y0 + 40, 240, 200, [("Ana", "aprovado"), ("Rui", "pendente"), ("Velho Tomé", "aprovado"),
              ("Menina (1962)", "gerado")], sel=1)
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 16, y0 + 26, "Perfil vocal — Rui (ch_…0003 · voice_…r1)", 15, "bold")
    sliders = [("Timbre", "grave", 0.25), ("Tonalidade", "-3 st", 0.35), ("Ritmo", "lento", 0.3),
               ("Expressividade", "contida", 0.4), ("Velocidade", "0,9×", 0.45)]
    for i, (n, v, f) in enumerate(sliders):
        yy = y0 + 56 + i * 34
        s.text(x0 + 16, yy + 4, n, 11, "bold")
        s.rect(x0 + 130, yy - 3, 300, 6, fill="#E1E5EA", stroke="none", rx=3)
        s.add(f'<circle cx="{x0 + 130 + 300 * f}" cy="{yy}" r="7" fill="{C["accent"]}"/>')
        s.text(x0 + 446, yy + 4, v, 11)
    s.combo(x0 + 16, y0 + 240, 200, "SOTAQUE", "litorâneo (pt-BR)")
    s.combo(x0 + 226, y0 + 240, 200, "EMOÇÃO DO TESTE", "tensa")
    s.marker(x1 - 20, y0 + 60, "2")
    s.text(x0 + 16, y0 + 290, "FRASE DE TESTE (síntese pela IA B)", 10, "bold", C["muted"])
    s.field(x0 + 16, y0 + 296, 420, "", "Você não devia ter aberto aquela carta.")
    s.button(x0 + 444, y0 + 296, 96, "▶ Sintetizar", True, h=24)
    s.rect(x0 + 16, y0 + 330, 524, 60, fill="#FFFFFF", stroke=C["line"])
    s.wave(x0 + 20, y0 + 332, 516, 56, seed=2)
    s.player_controls(x0 + 16, y0 + 394, 524, "00:00:01,2 / 00:00:02,8")
    s.marker(x1 - 20, y0 + 340, "3")
    bx = x0 + 16
    for lb, p, d in [("Aprovar perfil", True, False), ("Rejeitar", False, True), ("Refazer identidade (IA A)", False, False)]:
        w = 30 + len(lb) * 6.4
        s.button(bx, y1 - 40, w, lb, p, danger=d)
        bx += w + 6
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Síntese", "Permissões", "Histórico"], 0)
    s.table(rx + 8, y0 + 40, ["Campo", "Valor"], [["IA A (do MMenu)", "text.default"], ["IA B (do MMenu)", "voice.default"],
            ["semente", "88"], ["config", "sha256 1a9…"], ["origem", "sintética"], ["licença", "interna"]], [110, 174])
    s.text(rx + 12, y0 + 200, "CLONAGEM DE VOZ REAL", 10, "bold", C["muted"])
    s.check(rx + 14, y0 + 222, "Usa amostra de pessoa real", False)
    s.text(rx + 14, y0 + 244, "Exige termo de autorização anexado", 10.5, fill=C["warn"])
    s.button(rx + 8, y0 + 256, 284, "Anexar autorização...")
    s.marker(W - 16, y0 + 40, "4")
    return s


@screen("05-msound-previa")
def _():
    s, (x0, y0, x1, y1) = chrome("MSound", SOUND_STEPS, 2, rev="r0001", state="rascunho", left=False, right=False,
                                  footer="Prévia somente áudio · cena 4 · 00:01:30 · 14 eventos")
    s.text(20, y0 + 28, "Prévia sonora sincronizada — cena 4 · Confronto (storyboard MBoard r0004)", 15, "bold")
    s.marker(1080, y0 + 24, "1")
    s.ruler(20, y0 + 44, 1060, ["00:00", "00:15", "00:30", "00:45", "01:00", "01:15", "01:30"])
    s.track(20, y0 + 64, 1060, 26, "Segmentos", [(0, 0.555, "4.1 aproximação"), (0.555, 1, "4.2 a arma")], "#E3E8EF")
    s.track(20, y0 + 94, 1060, 34, "Voz · Rui", [(0.08, 0.3, "\"Você não devia…\""), (0.62, 0.74, "\"Solte!\"")])
    s.track(20, y0 + 132, 1060, 34, "Voz · Ana", [(0.33, 0.48, "\"Ela era endereçada…\"")], "#B7D7B0")
    s.track(20, y0 + 170, 1060, 34, "FX objeto", [(0.56, 0.6, "clique"), (0.75, 0.8, "disparo"), (0.8, 0.95, "explosão")],
            "#F2C38B")
    s.track(20, y0 + 208, 1060, 34, "Ambiente", [(0, 1, "chuva fina + mar (loop)")], "#CFC3E8")
    s.playhead(20 + 90 + 970 * 0.34, y0 + 44, y0 + 246)
    s.marker(1080, y0 + 110, "2")
    s.player_controls(20, y0 + 256, 1060, "00:00:30,6 / 00:01:30,0")
    s.text(20, y0 + 312, "Evento selecionado", 12, "bold")
    s.marker(160, y0 + 307, "3")
    s.table(20, y0 + 322, ["event", "asset", "entidade", "início", "fim", "volume", "camada"],
            [["te_…07", "fx disparo v1", "ob_bazuca", "00:01:07,5", "00:01:09,0", "-3 dB", "FX objeto"]],
            [90, 150, 120, 110, 110, 80, 120], sel=0)
    s.button(20, y1 - 40, 160, "Vincular som...", True)
    s.button(188, y1 - 40, 160, "Sugerir marcações (IA)")
    s.button(356, y1 - 40, 160, "Salvar prévia")
    s.text(560, y1 - 22, "Prévia de ensaio, não é áudio final do filme.", 11, fill=C["warn"])
    return s


# =====================================================================
# MSCENE
# =====================================================================
SCENE_STEPS = ["Selecionar cena", "Gerar segmentos", "Revisar e costurar", "Ligação entre cenas", "Salvar"]


@screen("06-mscene-geracao")
def _():
    s, (x0, y0, x1, y1) = chrome("MScene", SCENE_STEPS, 1, rev="cena 4 · r0002", state="rascunho",
                                  footer="Gerando segmento 4.2 · 00:00:22 / 00:00:40", prog=0.55)
    s.text(12, y0 + 22, "SEQUÊNCIA DE CENAS", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 250, [("1 · O farol", "aprovado"), ("2 · A carta", "aprovado"), ("3 · Cais", "aprovado"),
              ("4 · Confronto (atual)", "em execução"), ("5 · Tempestade", "rascunho"), ("6 · O barco", "rascunho")], sel=3)
    s.text(12, y0 + 300, "Só a próxima cena pode ser", 10.5, fill=C["muted"])
    s.text(12, y0 + 314, "iniciada; não há geração em lote.", 10.5, fill=C["muted"])
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 16, y0 + 26, "Cena 4 · Confronto — verificação de entradas", 15, "bold")
    s.table(x0 + 16, y0 + 38, ["Fonte", "Projeto/Revisão", "Integridade"],
            [["MScript", "pr_script_01 r0004", "#ok"], ["MVisual", "pr_visual_01 r0003", "#ok"],
             ["MBoard", "pr_board_01 r0005", "#ok"], ["MSound", "pr_sound_01 r0001", "#ok"]], [100, 250, 170])
    s.marker(x1 - 20, y0 + 44, "2")
    s.text(x0 + 16, y0 + 166, "Segmentos", 12, "bold")
    for i, (lb, st, pr) in enumerate([("4.1 · 50 s", "gerado", 1.0), ("4.2 · 40 s", "em execução", 0.55)]):
        cy = y0 + 176 + i * 120
        s.rect(x0 + 16, cy, 524, 110, fill="#FFFFFF", stroke=C["line"], rx=5)
        s.image(x0 + 26, cy + 10, 150, 90, "vídeo", lb)
        s.text(x0 + 190, cy + 24, "Segmento " + lb, 12, "bold")
        s.badge(x0 + 190, cy + 46, st)
        s.text(x0 + 190, cy + 70, "Quadro inicial/final do MBoard · áudio-guia MSound", 10.5, fill=C["muted"])
        s.progress(x0 + 190, cy + 82, 330, pr, h=8)
    s.marker(x1 - 20, y0 + 180, "3")
    s.button(x0 + 16, y1 - 40, 170, "▶ Gerar próximo segmento", True)
    s.button(x0 + 194, y1 - 40, 170, "Regenerar só o 4.2")
    s.button(x0 + 372, y1 - 40, 168, "⏸ Pausar")
    rx = W - RIGHT_W
    s.tabs(rx + 6, y0 + 6, ["Entrada da IA", "Parâmetros"], 0)
    s.text(rx + 12, y0 + 50, "REFERÊNCIAS ENVIADAS", 10, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 58, 284, 124, ["Quadro inicial a_…f11", "Quadro final a_…f12", "Rui · vistas aprovadas (4)",
              "Bazuca · vistas (4)", "Cais · noite (3)"])
    s.text(rx + 12, y0 + 202, "ÁUDIO-GUIA E MARCAÇÕES", 10, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 210, 284, 76, ["Voz Rui te_…05 00:00:12–00:00:15", "FX disparo te_…07", "Ambiente chuva"])
    s.combo(rx + 12, y0 + 314, 276, "PROVEDOR (do MMenu)", "video.default")
    s.check(rx + 14, y0 + 362, "Sincronia labial pelas falas")
    s.button(rx + 12, y0 + 376, 276, "Alterar no MMenu…", h=22)
    s.marker(W - 16, y0 + 40, "4")
    return s


@screen("06-mscene-ligacao")
def _():
    s, (x0, y0, x1, y1) = chrome("MScene", SCENE_STEPS, 3, rev="cena 4 · r0002", state="aprovado", left=False,
                                  footer="Ligação 3→4 aprovada · 4→5 pendente (cena 5 inexistente)")
    s.text(20, y0 + 28, "Validação da ligação entre cenas", 16, "bold")
    s.marker(780, y0 + 24, "1")
    for i, (lb, st, ex) in enumerate([("Cena 3 (anterior)", "aprovado", True), ("Cena 4 (atual)", "aprovado", True),
                                      ("Cena 5 (próxima)", "pendente", False)]):
        cx = 20 + i * 256
        if ex:
            s.image(cx, y0 + 44, 240, 136, lb)
        else:
            s.rect(cx, y0 + 44, 240, 136, fill="#FFF8E8", stroke=C["warn"], dash="6,4")
            s.text(cx + 120, y0 + 108, "ainda não gerada", 12, "bold", C["warn"], "middle")
            s.text(cx + 120, y0 + 126, "ligação fica pendente", 10.5, fill=C["warn"], anchor="middle")
        s.text(cx, y0 + 198, lb, 11, "bold")
        s.badge(cx + 150, y0 + 198, st)
    s.player_controls(20, y0 + 212, 752, "00:01:28 (últimos 5 s da cena 3)")
    s.marker(780, y0 + 225, "2")
    s.text(20, y0 + 270, "Checklist da transição 3 → 4", 12, "bold")
    items = ["Imagem/posição", "Cenário", "Objetos", "Figurino", "Som", "Ritmo", "Iluminação", "Ação/cronologia"]
    for i, it in enumerate(items):
        s.check(24 + (i % 4) * 190, y0 + 294 + (i // 4) * 24, it, True)
    s.text(20, y0 + 360, "COMENTÁRIO", 10, "bold", C["muted"])
    s.textarea(20, y0 + 366, 752, 50, ["Chuva começa 1 s antes do corte, ok."])
    s.button(20, y1 - 40, 200, "Aprovar ligação 3 → 4", True)
    s.button(228, y1 - 40, 200, "Reprovar e revisar trecho", danger=True)
    s.button(436, y1 - 40, 200, "Ligação 4 → 5: pendente")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "ESTADO DA CENA 4", 11, "bold", C["muted"])
    s.table(rx + 8, y0 + 30, ["Marca", "Valor"], [["cena_aprovada", "✔"], ["ligacao_anterior_aprovada", "✔"],
            ["ligacao_posterior_pendente", "✔"], ["finalizada", "—"]], [190, 94])
    s.marker(W - 16, y0 + 18, "3")
    return s


# =====================================================================
# MCUT
# =====================================================================
CUT_STEPS = ["Montagem e cortes", "Transições", "Sessões de público", "Análise e correções", "Salvar e render"]


@screen("07-mcut-timeline")
def _():
    s, (x0, y0, x1, y1) = chrome("MCut", CUT_STEPS, 0, rev="r0001", state="rascunho", left=False,
                                  footer="10 cenas na ordem do roteiro (MScript r0004) · 1 pendência: cena 9 sem vídeo aprovado")
    s.image(20, y0 + 12, 500, 250, "PLAYER DO FILME", "cena 4 · MScene c4 r0002")
    s.player_controls(20, y0 + 266, 500, "00:05:12:08 / 00:14:20:00")
    s.marker(530, y0 + 20, "1")
    s.text(540, y0 + 28, "Corte selecionado", 12, "bold")
    s.field(540, y0 + 52, 110, "IN", "00:00:01:12")
    s.field(660, y0 + 52, 110, "OUT", "00:01:28:00")
    s.text(540, y0 + 104, "Aparar é não destrutivo: o vídeo da cena", 10.5, fill=C["muted"])
    s.text(540, y0 + 118, "no MScene permanece intacto.", 10.5, fill=C["muted"])
    s.button(540, y0 + 136, 230, "Marcar ponto (M)")
    s.button(540, y0 + 168, 230, "Abrir cena no MScene (r0002)...")
    s.marker(780, y0 + 60, "2")
    s.ruler(20, y0 + 314, 760, ["00:00", "02:00", "04:00", "06:00", "08:00", "10:00", "12:00", "14:20"])
    clips = [(0, .08, "1"), (.08, .22, "2"), (.22, .34, "3"), (.34, .45, "4"), (.45, .55, "5"), (.55, .64, "6"),
             (.64, .76, "7"), (.76, .85, "8"), (.85, .93, "9 ⚠"), (.93, 1, "10")]
    s.track(20, y0 + 334, 760, 44, "Vídeo", clips)
    s.track(20, y0 + 382, 760, 30, "Transições", [(.075, .085, "F"), (.335, .345, "×"), (.545, .56, "F")], "#F2C38B")
    s.track(20, y0 + 416, 760, 30, "Marcas", [(.36, .365, "▲"), (.7, .705, "▲")], "#CFC3E8")
    s.playhead(20 + 90 + 670 * 0.36, y0 + 314, y0 + 446)
    s.marker(790, y0 + 350, "3")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "CENAS (ordem narrativa)", 11, "bold", C["muted"])
    s.table(rx + 8, y0 + 30, ["#", "Cena", "Rev.", "Estado"],
            [["1", "O farol", "r0001", "#aprovado"], ["2", "A carta", "r0002", "#aprovado"], ["3", "Cais", "r0001", "#aprovado"],
             ["4", "Confronto", "r0002", "#aprovado"], ["5", "Tempestade", "r0001", "#aprovado"],
             ["9", "Farol aceso", "—", "#pendente"]], [30, 110, 60, 84], sel=3)
    s.marker(W - 16, y0 + 18, "4")
    return s


@screen("07-mcut-transicoes")
def _():
    s, (x0, y0, x1, y1) = chrome("MCut", CUT_STEPS, 1, rev="r0001", state="rascunho", left=False, right=True,
                                  footer="Transição 3→4: fade cruzado 1,0 s")
    s.text(20, y0 + 28, "Transição entre cena 3 e cena 4", 15, "bold")
    s.image(20, y0 + 44, 360, 202, "fim da cena 3")
    s.image(420, y0 + 44, 360, 202, "início da cena 4")
    s.text(400, y0 + 150, "⇄", 20, "bold", C["muted"], "middle")
    s.player_controls(20, y0 + 254, 760, "prévia: -2 s … +2 s")
    s.marker(790, y0 + 60, "1")
    s.text(20, y0 + 320, "Tipo", 12, "bold")
    tx = 20
    for i, t in enumerate(["Corte seco", "Fade in", "Fade out", "Fade cruzado", "Fade p/ preto", "Wipe"]):
        s.button(tx, y0 + 330, 118, t, i == 3)
        tx += 124
    s.field(20, y0 + 390, 140, "DURAÇÃO (s)", "1,0")
    s.combo(180, y0 + 390, 200, "CURVA", "suave (ease-in-out)")
    s.combo(400, y0 + 390, 200, "ÁUDIO", "crossfade junto")
    s.marker(790, y0 + 340, "2")
    s.button(20, y1 - 40, 160, "Aplicar", True)
    s.button(188, y1 - 40, 160, "Comparar A/B")
    s.button(356, y1 - 40, 200, "Aplicar a todas as cenas...")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "TRANSIÇÕES DO FILME", 11, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 30, 284, 260, [("1→2 fade cruzado 0,5 s", None), ("2→3 corte seco", None),
              ("3→4 fade cruzado 1,0 s", None), ("4→5 corte seco", None), ("5→6 fade p/ preto 2 s", None),
              ("início: fade in 2 s", None), ("fim: fade out 3 s", None)], sel=2)
    s.marker(W - 16, y0 + 18, "3")
    return s


@screen("07-mcut-publico")
def _():
    s, (x0, y0, x1, y1) = chrome("MCut", CUT_STEPS, 2, rev="r0002", state="aprovado", left=True, right=False,
                                  footer="Sessão ss_…03 · 7/10 participantes responderam")
    s.text(12, y0 + 22, "SESSÕES", 11, "bold", C["muted"])
    s.listbox(10, y0 + 30, 240, 120, [("ss_01 · r0001 · filme", "aprovado"), ("ss_02 · r0001 · cena 4", "aprovado"),
              ("ss_03 · r0002 · filme", "em execução")], sel=2)
    s.button(10, y0 + 158, 240, "+ Nova sessão...", True)
    s.button(10, y0 + 190, 240, "Reavaliação de fragmento...")
    s.marker(250, y0 + 20, "1")
    s.text(x0 + 20, y0 + 28, "Sessão ss_03 — Filme r0002 (completo)", 15, "bold")
    s.combo(x0 + 20, y0 + 56, 200, "IDENTIFICAÇÃO", "anônima")
    s.combo(x0 + 230, y0 + 56, 200, "ACESSO", "link + código")
    s.field(x0 + 440, y0 + 56, 140, "PRAZO", "20/11/2026")
    s.check(x0 + 600, y0 + 74, "Termo de consentimento exigido")
    s.marker(x1 - 20, y0 + 60, "2")
    s.text(x0 + 20, y0 + 110, "Participantes", 12, "bold")
    s.table(x0 + 20, y0 + 120, ["Participante", "Convite", "Consentimento", "Progresso"],
            [["P01 (anônimo)", "enviado", "✔", "#aprovado"], ["P02 (anônimo)", "enviado", "✔", "#aprovado"],
             ["P03 (anônimo)", "enviado", "—", "#pendente"]], [180, 120, 140, 160])
    s.marker(x1 - 20, y0 + 124, "3")
    s.text(x0 + 20, y0 + 240, "Formulário do participante (prévia)", 12, "bold")
    s.rect(x0 + 20, y0 + 250, 800, 170, fill="#FAFBFC", stroke=C["line"], rx=5)
    s.image(x0 + 30, y0 + 260, 220, 124, "cena 4", "00:05:12 – 00:06:42")
    s.text(x0 + 266, y0 + 278, "Cena 4 · Confronto", 12, "bold")
    s.text(x0 + 266, y0 + 300, "Nota:", 11)
    for i in range(5):
        s.text(x0 + 306 + i * 22, y0 + 302, "★" if i < 4 else "☆", 18, fill=C["warn"])
    s.text(x0 + 266, y0 + 326, "Comentário:", 11)
    s.rect(x0 + 266, y0 + 334, 540, 50, fill="#FFFFFF", stroke=C["line"])
    s.text(x0 + 274, y0 + 352, "A explosão é alta demais em relação às falas.", 11)
    s.button(x0 + 646, y0 + 390, 160, "Próxima cena ▸", True)
    return s


@screen("07-mcut-analise")
def _():
    s, (x0, y0, x1, y1) = chrome("MCut", CUT_STEPS, 3, rev="r0002", state="aprovado", left=False, right=True,
                                  footer="Análise an_…02 · compara r0001 × r0002 · 10 + 7 respostas")
    s.text(20, y0 + 28, "Notas médias por cena (r0001 × r0002)", 15, "bold")
    s.marker(780, y0 + 24, "1")
    bx0, by0, bh = 50, y0 + 60, 200
    s.line(bx0, by0 + bh, 770, by0 + bh)
    vals = [(4.2, 4.3), (3.9, 4.0), (4.0, 4.1), (2.6, 3.8), (3.7, 3.6), (4.1, 4.1), (3.2, 3.3), (4.4, 4.5), (0, 0), (3.8, 4.0)]
    for i, (a, b) in enumerate(vals):
        gx = bx0 + 12 + i * 71
        if a == 0:
            s.text(gx + 21, by0 + bh - 22, "sem", 9, fill=C["muted"], anchor="middle")
            s.text(gx + 21, by0 + bh - 10, "resp.", 9, fill=C["muted"], anchor="middle")
        else:
            s.rect(gx, by0 + bh - a / 5 * bh, 20, a / 5 * bh, fill="#B9C6D6", stroke="none")
            s.rect(gx + 22, by0 + bh - b / 5 * bh, 20, b / 5 * bh, fill=C["accent"], stroke="none")
        s.text(gx + 21, by0 + bh + 16, f"c{i + 1}", 10, anchor="middle", fill=C["muted"])
    s.rect(560, y0 + 40, 10, 10, fill="#B9C6D6", stroke="none")
    s.text(576, y0 + 49, "r0001", 10)
    s.rect(620, y0 + 40, 10, 10, fill=C["accent"], stroke="none")
    s.text(636, y0 + 49, "r0002", 10)
    s.text(20, y0 + 300, "Achados (IA sugere; decisão é do responsável)", 12, "bold")
    s.marker(392, y0 + 295, "2")
    s.table(20, y0 + 310, ["Cena", "Problema recorrente", "Evidência", "Ação proposta", "Software"],
            [["4", "som: explosão alta", "5 de 7 comentários", "remixar FX -6 dB", "MSound"],
             ["7", "ritmo lento", "média 3,3; 4 comentários", "aparar 15 s", "MCut"],
             ["9", "sem resposta", "vídeo pendente", "gerar cena 9", "MScene"]],
            [50, 170, 170, 170, 100], sel=0)
    s.button(20, y1 - 40, 230, "Aprovar correção → abrir MSound", True)
    s.button(258, y1 - 40, 160, "Rejeitar achado")
    s.button(426, y1 - 40, 200, "Exportar relatório")
    rx = W - RIGHT_W
    s.text(rx + 12, y0 + 22, "CICLOS DE CORREÇÃO", 11, "bold", C["muted"])
    s.listbox(rx + 8, y0 + 30, 284, 150, [("cc_01 cena 4 voz", "aprovado"), ("cc_02 cena 4 FX", "em execução"),
              ("cc_03 cena 7 ritmo", "pendente")], sel=1)
    s.text(rx + 12, y0 + 204, "RASTRO DO CICLO cc_02", 10, "bold", C["muted"])
    s.textarea(rx + 8, y0 + 212, 284, 200, ["feedback fb_…11, fb_…14", "→ decisão (usuário) 16/11", "→ MSound r0001 → r0002",
               "→ MScene c4 r0002 → r0003", "→ MCut r0002 → r0003 (pend.)", "→ reavaliação fragmento (pend.)"], size=10.5)
    s.marker(W - 16, y0 + 18, "3")
    return s


@screen("07-mcut-exportacao")
def _():
    s, (x0, y0, x1, y1) = chrome("MCut", CUT_STEPS, 4, rev="r0003", state="aprovado", left=False, right=False,
                                  footer="Renderizando 00:06:10 / 00:14:20 · cena 5", prog=0.43)
    s.text(20, y0 + 28, "Verificação antes do render", 15, "bold")
    s.marker(560, y0 + 24, "1")
    checks = [("Ordem igual à do roteiro MScript r0004", True), ("10/10 cenas com vídeo aprovado", True),
              ("Hashes de mídia íntegros", True), ("Transições configuradas", True), ("Áudio presente em todas as cenas", True),
              ("Nenhuma pendência de montagem", True)]
    for i, (t, ok) in enumerate(checks):
        s.text(24, y0 + 56 + i * 22, ("✔ " if ok else "✘ ") + t, 11.5, fill=C["ok"] if ok else C["err"])
    s.text(600, y0 + 28, "Parâmetros de exportação", 15, "bold")
    s.marker(1080, y0 + 24, "2")
    s.combo(600, y0 + 56, 230, "CONTÊINER", "MP4")
    s.combo(840, y0 + 56, 230, "CODEC DE VÍDEO", "H.264")
    s.combo(600, y0 + 102, 230, "RESOLUÇÃO", "1920×1080")
    s.combo(840, y0 + 102, 230, "QUADROS/S", "24")
    s.combo(600, y0 + 148, 230, "CODEC DE ÁUDIO", "AAC 48 kHz estéreo")
    s.field(840, y0 + 148, 230, "QUALIDADE (CRF)", "18")
    s.field(600, y0 + 194, 470, "ARQUIVO DE SAÍDA", "video/exports/filme-exemplo_r0003_1080p.mp4")
    s.text(20, y0 + 260, "Renderizações", 15, "bold")
    s.marker(170, y0 + 255, "3")
    s.table(20, y0 + 272, ["export_id", "Revisão", "Formato", "Duração", "sha256", "Estado"],
            [["ex_…03", "r0003", "MP4 1080p", "00:14:20", "—", "#em execução"],
             ["ex_…02", "r0002", "MP4 720p", "00:14:35", "77ac…", "#aprovado"],
             ["ex_…01", "r0001", "MP4 720p", "00:14:50", "—", "#falha"]], [140, 100, 160, 120, 160, 160], sel=0)
    s.button(20, y1 - 40, 180, "Salvar revisão do filme")
    s.button(208, y1 - 40, 180, "▶ Renderizar filme", True)
    s.button(396, y1 - 40, 180, "Cancelar render", danger=True)
    s.button(584, y1 - 40, 200, "Abrir relatório de exportação")
    return s


def main():
    out = os.path.dirname(os.path.abspath(__file__))
    for name, fn in SCREENS.items():
        with open(os.path.join(out, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(fn().svg())
    print(f"{len(SCREENS)} telas geradas em {out}")


if __name__ == "__main__":
    main()
