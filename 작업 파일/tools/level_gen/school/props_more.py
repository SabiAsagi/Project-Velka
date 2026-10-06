# -*- coding: utf-8 -*-
"""업무·특별실용 가구 부품 (방 좌표, facing: 앉는 사람이 바라보는 방향 +1 = +v쪽 / -1 = -v쪽)"""
from props_base import wall_item


def office_desk(p, u, v, facing=-1, w=1.2, d=0.7, items=("monitor", "papers"), key="od", drawer=True):
    """교사·직원 책상: 상판, 서랍장, 다리, 의자(뒤쪽), 모니터·서류·머그컵"""
    p.box("office_top", u, v, w, d, 0.71, 0.74)
    if drawer:
        p.box("office_drawer", u + w / 2 - 0.22, v, 0.4, d - 0.08, 0.0, 0.7)
    p.box("office_panel", u - w / 2 + 0.03, v, 0.03, d - 0.05, 0.0, 0.71)
    p.box("office_panel", u, v - facing * (d / 2 - 0.03), w - 0.1, 0.02, 0.3, 0.71)
    p.solid(u, v, w, d, 0.0, 0.76)
    cv = v - facing * (d / 2 + 0.3)
    p.box("chair_office", u, cv, 0.46, 0.44, 0.44, 0.5)
    p.box("chair_office", u, cv - facing * 0.22, 0.44, 0.06, 0.5, 0.95)
    p.box("metal_dark", u, cv, 0.06, 0.06, 0.0, 0.44)
    for k in items:
        if k == "monitor":
            p.box("monitor", u - 0.1, v + facing * 0.18, 0.55, 0.04, 0.8, 1.14)
            p.box("metal_dark", u - 0.1, v + facing * 0.2, 0.08, 0.08, 0.74, 0.8)
            p.box("keyboard", u - 0.1, v - facing * 0.08, 0.42, 0.14, 0.74, 0.76)
        elif k == "papers":
            n = 1 + int(p.rand(key, u, v) * 4)
            for i in range(n):
                p.box("paper", u + 0.35, v + 0.05, 0.3, 0.21, 0.74 + i * 0.012, 0.752 + i * 0.012)
        elif k == "mug":
            m = ("mug_red", "mug_blue", "mug_white", "mug_green")[int(p.rand(key, "mug", u) * 4) % 4]
            p.box(m, u - 0.45, v - facing * 0.15, 0.08, 0.08, 0.74, 0.84)
        elif k == "exam":
            for i in range(3):
                p.box("paper_yellow" if i % 2 else "paper", u + 0.3, v - 0.02, 0.3, 0.21, 0.74 + i * 0.03, 0.765 + i * 0.03)
        elif k == "nameplate":
            p.box("wood_dark", u + 0.1, v - facing * (d / 2 - 0.06), 0.24, 0.05, 0.74, 0.8)


def table(p, u, v, su, sv, seats_per_long=3, mat="table_top", chair_mat="chair_seat", along="u", key="tb", legs=True):
    """직사각 테이블 + 긴 변 양쪽 의자. along: 긴 변 방향 ('u' 또는 'v')"""
    p.box(mat, u, v, su, sv, 0.72, 0.75)
    if legs:
        for du in (-su / 2 + 0.06, su / 2 - 0.06):
            for dv in (-sv / 2 + 0.06, sv / 2 - 0.06):
                p.box("desk_frame", u + du, v + dv, 0.05, 0.05, 0.0, 0.72)
    p.solid(u, v, su, sv, 0.0, 0.76)
    L = su if along == "u" else sv
    for i in range(seats_per_long):
        t = -L / 2 + L * (i + 0.5) / seats_per_long
        for side in (-1, 1):
            if along == "u":
                cu, cv = u + t, v + side * (sv / 2 + 0.3)
                back = (cu, cv + side * 0.19)
                p.box(chair_mat, cu, cv, 0.42, 0.4, 0.43, 0.46)
                p.box(chair_mat, back[0], back[1], 0.4, 0.03, 0.46, 0.85)
            else:
                cu, cv = u + side * (su / 2 + 0.3), v + t
                p.box(chair_mat, cu, cv, 0.4, 0.42, 0.43, 0.46)
                p.box(chair_mat, cu + side * 0.19, cv, 0.03, 0.4, 0.46, 0.85)
            p.box("chair_frame", cu, cv, 0.05, 0.05, 0.0, 0.43)


def carrel(p, u, v, facing=-1, w=0.8, d=0.6, lamp=False, items=(), key="cr"):
    """칸막이 개인석: 책상 + 양옆·앞 가림판 (앉은 사람 시선은 가리되 카메라에서 몸 전체를 숨기지 않는 1.2m)"""
    p.box("desk_top", u, v, w, d, 0.71, 0.74)
    p.box("carrel_panel", u - w / 2 + 0.015, v, 0.03, d, 0.0, 1.2)
    p.box("carrel_panel", u + w / 2 - 0.015, v, 0.03, d, 0.0, 1.2)
    p.box("carrel_panel", u, v + facing * (d / 2 - 0.015), w, 0.03, 0.74, 1.2)
    cv = v - facing * (d / 2 + 0.28)
    p.box("chair_seat", u, cv, 0.4, 0.4, 0.43, 0.46)
    p.box("chair_seat", u, cv - facing * 0.19, 0.4, 0.03, 0.46, 0.85)
    p.solid(u, v - facing * 0.25, w, d + 0.5, 0.0, 0.8)
    if lamp:
        p.box("lamp", u - w / 2 + 0.15, v + facing * 0.15, 0.12, 0.12, 0.74, 1.08)
    for k in items:
        if k == "books":
            p.box("book_b", u + 0.1, v, 0.24, 0.18, 0.74, 0.8)
        elif k == "bag":
            p.box("bag", u + w / 2 - 0.18, cv, 0.28, 0.14, 0.0, 0.42)
        elif k == "number":
            p.box("paper", u, v + facing * (d / 2 - 0.035), 0.12, 0.004, 1.02, 1.1)


def sofa(p, u, v, length, facing=1, along="u", mat="sofa"):
    """소파: 앉는 면 + 등받이 + 팔걸이 (facing: 앉은 사람이 보는 방향)"""
    if along == "u":
        p.box(mat, u, v, length, 0.8, 0.0, 0.42, collide=True)
        p.box(mat, u, v - facing * 0.32, length, 0.16, 0.42, 0.85)
        for s in (-1, 1):
            p.box(mat, u + s * (length / 2 - 0.08), v, 0.16, 0.8, 0.42, 0.62)
    else:
        p.box(mat, u, v, 0.8, length, 0.0, 0.42, collide=True)
        p.box(mat, u - facing * 0.32, v, 0.16, length, 0.42, 0.85)
        for s in (-1, 1):
            p.box(mat, u, v + s * (length / 2 - 0.08), 0.8, 0.16, 0.42, 0.62)


def bed(p, u, v, along="v", length=2.0, width=0.95):
    """보건실 침대: 철제 프레임 + 매트리스 + 베개 (along = 머리-발 방향)"""
    su, sv = (width, length) if along == "v" else (length, width)
    p.box("bed_frame", u, v, su, sv, 0.0, 0.45, collide=True)
    p.box("bed", u, v, su - 0.04, sv - 0.04, 0.45, 0.6)
    if along == "v":
        p.box("pillow", u, v + sv / 2 - 0.25, su - 0.2, 0.3, 0.6, 0.68)
        p.box("bed_frame", u, v + sv / 2 - 0.02, su, 0.04, 0.45, 0.95)
    else:
        p.box("pillow", u + su / 2 - 0.25, v, 0.3, sv - 0.2, 0.6, 0.68)
        p.box("bed_frame", u + su / 2 - 0.02, v, 0.04, sv, 0.45, 0.95)


def blinds(ctx, side, kind_filter=("A",), drop=0.55):
    """외부창 안쪽 블라인드 (창 윗부분을 drop 비율만큼 가림)"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for w in ctx.windows_on(side):
        if w.kind not in kind_filter:
            continue
        top = w.y1 - 0.02
        h = (w.y1 - w.y0) * drop
        wall_item(p, W, D, side, w.mid, w.a1 - w.a0 + 0.05, 0.19, 0.02, top - h, top, "blind")
        wall_item(p, W, D, side, w.mid, w.a1 - w.a0 + 0.1, 0.17, 0.05, top, top + 0.06, "frame_alu")


def curtains_full(ctx, side, mat="curtain_heavy"):
    """두꺼운 커튼 (방송실·음악실): 창마다 양옆으로 모아 둔 커튼"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for w in ctx.windows_on(side):
        for a in (w.a0 - 0.15, w.a1 + 0.15):
            wall_item(p, W, D, side, a, 0.35, 0.12, 0.08, 0.3, w.y1 + 0.25, mat)
        wall_item(p, W, D, side, w.mid, w.a1 - w.a0 + 0.8, 0.16, 0.04, w.y1 + 0.25, w.y1 + 0.3, "frame_alu")


def whiteboard_wall(p, W, D, side, a, width=1.8, h0=0.9, h1=2.0):
    wall_item(p, W, D, side, a, width + 0.06, 0.0, 0.03, h0 - 0.03, h1 + 0.03, "frame_alu")
    wall_item(p, W, D, side, a, width, 0.03, 0.01, h0, h1, "whiteboard")
    wall_item(p, W, D, side, a, width, 0.03, 0.08, h0 - 0.05, h0 - 0.02, "frame_alu")
