# -*- coding: utf-8 -*-
"""별관·강당 공용 가구 부품 (방 좌표). 충돌은 가구 묶음마다 단순 사각형 하나."""
from props_base import wall_item, label, facing_rows


def openings_on(ctx, side):
    """방 좌표 변(side)의 문 없는 개구부(배식구·판매창) [(a0, a1, opening)]"""
    out = []
    L = ctx.W if side in ("front", "back") else ctx.D
    for o in ctx.plan.openings:
        ws = ctx._world_side_of_line(o.axis, o.fixed)
        if ws is None or ctx.local_side(ws) != side:
            continue
        a0, a1 = ctx._range(side, o.a0, o.a1, o.axis)
        if a1 < 0.05 or a0 > L - 0.05:
            continue
        out.append((max(a0, 0.0), min(a1, L), o))
    return sorted(out, key=lambda t: t[0])


def wall_label(ctx, side, a, h, text, off=0.03, size=0.004, font=40, color=(0.12, 0.13, 0.16)):
    """벽(side) 앞 off 거리에 방 안쪽을 보는 글자. 카메라가 뒷면을 보게 되는 벽(동·남쪽 벽)은 건너뛴다."""
    if ctx.frame.world_side(side) in ("x1", "z1"):
        return
    W, D = ctx.W, ctx.D
    if side == "front":
        u, v, face = a, off, "back"
    elif side == "back":
        u, v, face = a, D - off, "front"
    elif side == "left":
        u, v, face = off, a, "right"
    else:
        u, v, face = W - off, a, "left"
    x, z = ctx.frame.pt(u, v)
    label(ctx.sw, ctx.container, (x, ctx.y + h, z), text, size, font, color, facing_rows(ctx.frame, face),
          list(ctx.groups) or None)


def steel_table(p, u, v, su, sv, h=0.85, shelf=True, collide=True, mat="stainless"):
    """스테인리스 작업대: 상판 + 아래 선반 + 다리"""
    p.box(mat, u, v, su, sv, h - 0.04, h)
    if shelf:
        p.box("stainless_dark", u, v, su - 0.12, sv - 0.12, 0.16, 0.19)
    for du in (-su / 2 + 0.04, su / 2 - 0.04):
        for dv in (-sv / 2 + 0.04, sv / 2 - 0.04):
            p.box("stainless_dark", u + du, v + dv, 0.04, 0.04, 0.0, h - 0.04)
    if collide:
        p.solid(u, v, su, sv, 0.0, h)


def round_box(p, mat, u, v, d, h0, h1):
    """세로 원통 (솥·통·북 등)"""
    p.cyl(mat, u, v, d, h0, h1)


def stool(p, u, v, mat="stool_seat", h=0.45, size=0.3):
    p.box(mat, u, v, size, size, h - 0.04, h)
    p.box("chair_frame", u, v, 0.05, 0.05, 0.0, h - 0.04)


def _wall_solid(p, W, D, side, a, length, depth, h):
    if side in ("left", "right"):
        p.solid(depth / 2 if side == "left" else W - depth / 2, a, depth, length, 0.0, h)
    else:
        p.solid(a, depth / 2 if side == "front" else D - depth / 2, length, depth, 0.0, h)


def rack(p, W, D, side, a, length, depth=0.5, h=1.9, levels=4, mats=("box", "box", "paint_can"), key="rk", fill=0.75,
         frame="shelf_metal"):
    """벽에 붙은 철제 선반 + 상자류"""
    for da in (-length / 2 + 0.025, length / 2 - 0.025):
        wall_item(p, W, D, side, a + da, 0.05, 0.0, depth, 0.0, h, frame)
    for k in range(levels + 1):
        hh = 0.12 + (h - 0.2) * k / levels
        wall_item(p, W, D, side, a, length - 0.1, 0.0, depth - 0.02, hh, hh + 0.03, frame)
    gap = (h - 0.2) / levels
    n = max(1, int((length - 0.2) / 0.5))
    for k in range(levels):
        hh = 0.15 + (h - 0.2) * k / levels
        for j in range(n):
            if p.rand(key, k, j) > fill:
                continue
            aa = a - length / 2 + 0.1 + (length - 0.2) * (j + 0.5) / n
            bw = 0.3 + 0.12 * p.rand(key, j, k, 2)
            bh = (gap - 0.08) * (0.55 + 0.4 * p.rand(key, k, j, 3))
            wall_item(p, W, D, side, aa, bw, 0.04, depth - 0.12, hh, hh + bh, mats[(j + k) % len(mats)])
    _wall_solid(p, W, D, side, a, length, depth, h)


def upright_fridge(p, W, D, side, a, width, depth=0.8, h=1.95, doors=2, mat="stainless"):
    """업소용 냉장·냉동고 (벽 붙임): 몸체 + 문 틈 + 손잡이 + 위 기계실"""
    wall_item(p, W, D, side, a, width, 0.0, depth, 0.0, h, mat, collide=True)
    wall_item(p, W, D, side, a, width - 0.06, 0.0, depth - 0.06, h, h + 0.16, "stainless_dark")
    for i in range(doors):
        c = a - width / 2 + width * (i + 0.5) / doors
        if i:
            wall_item(p, W, D, side, a - width / 2 + width * i / doors, 0.012, depth, 0.006, 0.08, h - 0.05, "metal_dark")
        wall_item(p, W, D, side, c + width / doors * 0.3, 0.03, depth, 0.035, 0.85, 1.25, "metal_dark")
    wall_item(p, W, D, side, a, width - 0.1, depth, 0.004, h * 0.52, h * 0.53, "metal_dark")


def glass_cabinet(p, W, D, side, a, width, depth=0.45, h=1.9, items=("jar",), key="gc", frame="cabinet_wood", base=0.5,
                  rows=3, fill=0.8):
    """유리 진열장 (벽 붙임): 아래 수납칸 + 틀 + 선반 + 앞 유리 + 안의 물건"""
    wall_item(p, W, D, side, a, width, 0.0, depth, 0.0, base, frame)
    wall_item(p, W, D, side, a, width, 0.0, 0.03, base, h, frame)
    for da in (-width / 2 + 0.02, width / 2 - 0.02):
        wall_item(p, W, D, side, a + da, 0.04, 0.03, depth - 0.03, base, h, frame)
    wall_item(p, W, D, side, a, width, 0.0, depth, h, h + 0.04, frame)
    gap = (h - base) / rows
    n = max(1, int((width - 0.2) / 0.28))
    for r in range(rows):
        hh = base + gap * r
        if r:
            wall_item(p, W, D, side, a, width - 0.08, 0.03, depth - 0.06, hh - 0.012, hh + 0.012, frame)
        for j in range(n):
            if p.rand(key, r, j) > fill:
                continue
            aa = a - width / 2 + 0.1 + (width - 0.2) * (j + 0.5) / n
            sz = 0.1 + 0.08 * p.rand(key, j, r, 1)
            ih = (gap - 0.1) * (0.4 + 0.5 * p.rand(key, r, j, 2))
            b = hh + (0.012 if r else 0.0)
            wall_item(p, W, D, side, aa, sz, 0.1, min(sz, depth - 0.2), b, b + ih, items[(j + r) % len(items)])
    wall_item(p, W, D, side, a, width - 0.08, depth - 0.025, 0.012, base + 0.02, h - 0.02, "glass")
    _wall_solid(p, W, D, side, a, width, depth, h)


def pc_desk(p, u, v, w=1.0, d=0.55, end=False):
    """컴퓨터 책상 (앉은 사람은 -v를 본다): 상판, 옆판, 앞 가림판, 모니터, 키보드, 본체, 고정 의자"""
    p.box("office_top", u, v, w, d, 0.70, 0.73)
    p.box("office_panel", u - w / 2 + 0.015, v, 0.03, d - 0.04, 0.0, 0.70)
    if end:
        p.box("office_panel", u + w / 2 - 0.015, v, 0.03, d - 0.04, 0.0, 0.70)
    p.box("office_panel", u, v - d / 2 + 0.03, w - 0.08, 0.02, 0.25, 0.70)
    p.box("monitor", u - 0.08, v - 0.12, 0.5, 0.035, 0.80, 1.1)
    p.box("metal_dark", u - 0.08, v - 0.1, 0.1, 0.08, 0.73, 0.8)
    p.box("keyboard", u - 0.08, v + 0.1, 0.4, 0.13, 0.73, 0.745)
    p.box("pc_tower", u + w / 2 - 0.15, v, 0.18, 0.42, 0.04, 0.46)
    cv = v + d / 2 + 0.3
    p.box("chair_office", u, cv, 0.42, 0.42, 0.42, 0.47)
    p.box("chair_office", u, cv + 0.2, 0.4, 0.04, 0.47, 0.88)
    p.box("metal_dark", u, cv, 0.06, 0.06, 0.0, 0.42)


def lab_bench(p, u, v, w=2.2, d=0.9, sink=True, stools=3):
    """실험대 (긴 변 = u): 검은 상판, 아래 수납장, 끝의 개수대, 가운데 콘센트 기둥, 양쪽 스툴"""
    p.box("office_panel", u, v, w - 0.1, d - 0.16, 0.0, 0.8)
    p.box("lab_bench", u, v, w, d, 0.8, 0.85)
    if sink:
        p.box("stainless", u + w / 2 - 0.32, v, 0.42, 0.48, 0.85, 0.856)
        p.box("drain", u + w / 2 - 0.32, v, 0.34, 0.4, 0.856, 0.86)
        p.box("steel", u + w / 2 - 0.32, v - 0.27, 0.03, 0.03, 0.85, 1.12)
        p.box("steel", u + w / 2 - 0.32, v - 0.2, 0.03, 0.14, 1.09, 1.12)
    p.box("panel_gray", u - 0.1, v, 0.22, 0.14, 0.85, 1.0)
    for i in range(stools):
        t = -w / 2 + w * (i + 0.5) / stools
        for s in (-1, 1):
            stool(p, u + t, v + s * (d / 2 + 0.27))
    p.solid(u, v, w, d + 0.86, 0.0, 0.88)


def grand_piano(p, u0, v):
    """그랜드 피아노: (u0, v) = 건반 쪽 끝 가운데, 몸통은 +u로 뻗는다. 연주자 의자는 -u 쪽."""
    p.box("piano", u0 + 0.5, v, 1.0, 1.44, 0.62, 0.95)
    p.box("piano", u0 + 1.45, v - 0.27, 0.9, 0.9, 0.62, 0.95)
    p.box("piano", u0 - 0.11, v, 0.22, 1.36, 0.62, 0.74)
    p.box("piano_key", u0 - 0.12, v, 0.16, 1.24, 0.74, 0.752)
    p.box("piano", u0 - 0.07, v, 0.06, 1.2, 0.752, 0.764)
    p.box("piano", u0 + 0.12, v, 0.02, 0.8, 0.95, 1.2)
    p.box("paper", u0 + 0.105, v, 0.004, 0.5, 0.98, 1.18)
    for du, dv in ((0.15, -0.6), (0.15, 0.6), (1.75, -0.27)):
        p.box("piano", u0 + du, v + dv, 0.09, 0.09, 0.0, 0.62)
    p.box("brass", u0 + 0.1, v, 0.1, 0.24, 0.0, 0.08)
    p.box("piano", u0 - 0.6, v, 0.4, 0.75, 0.44, 0.5)
    for dv in (-0.33, 0.33):
        p.box("piano", u0 - 0.6, v + dv, 0.34, 0.05, 0.0, 0.44)
    p.solid(u0 + 0.84, v, 2.12, 1.44, 0.0, 1.0)


def music_seat(p, u, v, dh=0.0, collide=True):
    """의자 + 악보대 (앞 = -v). dh: 단 위에 놓을 때의 높이"""
    p.box("chair_seat", u, v, 0.42, 0.4, dh + 0.42, dh + 0.45)
    p.box("chair_seat", u, v + 0.19, 0.4, 0.03, dh + 0.45, dh + 0.85)
    for du in (-0.19, 0.19):
        p.box("chair_frame", u + du, v, 0.025, 0.36, dh, dh + 0.42)
    p.box("metal_dark", u, v - 0.55, 0.03, 0.03, dh, dh + 1.05)
    p.box("metal_dark", u, v - 0.55, 0.34, 0.04, dh, dh + 0.025)
    p.box("metal_dark", u, v - 0.56, 0.46, 0.02, dh + 1.02, dh + 1.32)
    p.box("paper", u, v - 0.545, 0.4, 0.004, dh + 1.06, dh + 1.3)
    if collide:
        p.solid(u, v - 0.2, 0.5, 0.95, 0.0, 0.9)


def easel(p, u, v, yaw=0.0, mat="canvas"):
    p.box("easel", u, v, 0.06, 0.5, 0.0, 1.6, yaw=yaw, pivot=(u, v))
    p.box("easel", u, v, 0.5, 0.05, 0.75, 0.8, yaw=yaw, pivot=(u, v))
    p.box(mat, u, v - 0.06, 0.6, 0.03, 0.82, 1.45, yaw=yaw, pivot=(u, v))


BOOKS = ("book_a", "book_b", "book_c", "book_old", "file_box")


def book_cart(p, u, v, along="u", key="bc", collide=True):
    """북트럭: 2단 선반 + 책 + 손잡이 기둥"""
    su, sv = (0.9, 0.45) if along == "u" else (0.45, 0.9)
    for h in (0.25, 0.62):
        p.box("cart", u, v, su, sv, h, h + 0.03)
        for k in range(5):
            if p.rand(key, h, k) > 0.75:
                continue
            t = -0.32 + 0.16 * k
            bu, bv = (u + t, v) if along == "u" else (u, v + t)
            bs = (0.12, 0.3) if along == "u" else (0.3, 0.12)
            p.box(BOOKS[k % 4], bu, bv, bs[0], bs[1], h + 0.03, h + 0.22 + 0.06 * p.rand(key, k))
    for du in (-1, 1):
        for dv in (-1, 1):
            p.box("metal_dark", u + du * (su / 2 - 0.03), v + dv * (sv / 2 - 0.03), 0.03, 0.03, 0.05, 1.0)
    if collide:
        p.solid(u, v, su, sv, 0.0, 1.0)


def book_stack(p, a0, a1, c, key, along="u", h=1.75, t=0.55, mat="shelf_wood", fill=0.85):
    """양면 서가. along='u': u방향으로 a0~a1, v=c / along='v': v방향으로 a0~a1, u=c"""
    L, ac = a1 - a0, (a0 + a1) / 2

    def B(m, a, off, la, lt, h0, h1):
        if along == "u":
            p.box(m, a, c + off, la, lt, h0, h1)
        else:
            p.box(m, c + off, a, lt, la, h0, h1)

    B(mat, ac, 0.0, L - 0.08, 0.04, 0.0, h)
    for a in (a0 + 0.02, a1 - 0.02):
        B(mat, a, 0.0, 0.04, t, 0.0, h)
    B(mat, ac, 0.0, L, t, h, h + 0.03)
    levels = max(2, int(h / 0.36))
    step = (h - 0.1) / levels
    for k in range(levels):
        hh = 0.08 + step * k
        for side in (-1, 1):
            B(mat, ac, side * (t / 4 + 0.005), L - 0.08, t / 2 - 0.03, hh - 0.02, hh)
            x, j = a0 + 0.06, 0
            while x < a1 - 0.14:
                j += 1
                w = 0.07 + 0.12 * p.rand(key, k, j, side)
                w = min(w, a1 - 0.06 - x)
                if p.rand(key, side, k, j, 5) < fill:
                    bh = (step - 0.06) * (0.6 + 0.38 * p.rand(key, j, k, side, 2))
                    B(BOOKS[(j + k + (side > 0)) % 4], x + w / 2, side * (t / 4 + 0.012), w, t / 2 - 0.07, hh, hh + bh)
                x += w + 0.006
    if along == "u":
        p.solid(ac, c, L, t, 0.0, h)
    else:
        p.solid(c, ac, t, L, 0.0, h)


def vending(p, W, D, side, a, mat):
    """자판기 (벽 붙임)"""
    wall_item(p, W, D, side, a, 0.7, 0.0, 0.7, 0.0, 1.85, mat, collide=True)
    wall_item(p, W, D, side, a - 0.07, 0.44, 0.7, 0.008, 0.75, 1.65, "vending_panel")
    wall_item(p, W, D, side, a + 0.25, 0.1, 0.7, 0.01, 1.0, 1.3, "metal_dark")
    wall_item(p, W, D, side, a - 0.07, 0.4, 0.7, 0.01, 0.2, 0.4, "metal_dark")
