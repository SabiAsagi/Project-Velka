# -*- coding: utf-8 -*-
"""화장실·탈의실·청소도구함 (가이드라인 4장, 학교_맵_상세.md 별관 화장실 구성).
좌표: 문이 있는 벽 = 앞(v=0)."""
from props_base import wall_item, cabinet, shelf_unit, bench, plant


def toilet(ctx, men=False):
    """들어가자마자 칸이 보이지 않게 짧은 가림벽, 입구 가까이 세면대·거울, 안쪽 대변기 칸, 남자는 소변기 구간"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    dm = doors[0].mid if doors else W / 2
    # 가림벽 (문 앞에서 1.25m 안쪽)
    sw0, sw1 = max(0.3, dm - 0.85), min(W - 0.3, dm + 0.85)
    p.box("toilet_partition", (sw0 + sw1) / 2, 1.3, sw1 - sw0, 0.06, 0.0, 2.1, collide=True)
    # 세면대·거울: 문에서 먼 쪽 앞 벽 구간
    left_room = dm - 0.0
    if dm > W / 2:
        s0, s1 = 0.35, max(0.35, dm - 0.9)
    else:
        s0, s1 = min(W - 0.35, dm + 0.9), W - 0.35
    n_sink = 2 if (s1 - s0) >= 1.4 else 1
    for i in range(n_sink):
        u = s0 + (s1 - s0) * (i + 0.5) / n_sink
        p.box("counter_white", u, 0.28, 0.6, 0.5, 0.78, 0.86, collide=True)
        p.box("porcelain", u, 0.28, 0.42, 0.34, 0.86, 0.9)
        p.box("steel", u, 0.08, 0.04, 0.1, 0.9, 1.08)
        p.box("mirror", u, 0.02, 0.5, 0.02, 1.2, 1.85)
        p.box("soap", u + 0.28, 0.05, 0.08, 0.06, 1.1, 1.24)
    # 칸: 뒤 벽을 따라
    stall_d = 1.45 if D > 3.6 else 1.25
    v0 = D - stall_d
    usable0, usable1 = 0.1, W - 0.1
    urinals = 0
    if men:
        urinals = 3 if W > 4.2 else 2
        usable1 = W - 0.1 - urinals * 0.62 - 0.25
    n = max(1, int((usable1 - usable0) / 0.95))
    n = min(n, 2 if men else 4)
    sw_ = (usable1 - usable0) / n
    for i in range(n + 1):
        u = usable0 + sw_ * i
        p.box("stall_panel", u, D - stall_d / 2, 0.03, stall_d, 0.12, 2.0, collide=True)
    for i in range(n):
        u = usable0 + sw_ * (i + 0.5)
        # 칸 문 (조금 열린 것도)
        ajar = p.rand("stall", i) > 0.6
        p.box("stall_door", u + (0.12 if ajar else 0.0), v0, sw_ - 0.12, 0.03, 0.12, 2.0, yaw=(25.0 if ajar else 0.0))
        if not ajar:
            p.solid(u, v0, sw_ - 0.1, 0.05, 0.0, 2.0)
        p.box("porcelain", u, D - 0.45, 0.38, 0.55, 0.0, 0.42)
        p.box("porcelain", u, D - 0.12, 0.42, 0.18, 0.42, 0.8)
        p.box("steel", u + sw_ / 2 - 0.2, D - 0.8, 0.12, 0.1, 0.7, 0.82)
    for i in range(urinals):
        u = W - 0.45 - i * 0.62
        p.box("porcelain", u, D - 0.2, 0.36, 0.3, 0.45, 1.05)
        p.box("toilet_partition", u - 0.31, D - 0.3, 0.03, 0.45, 0.6, 1.5)
    p.box("bin_gray", 0.25 if dm > W / 2 else W - 0.25, 1.7, 0.3, 0.3, 0.0, 0.5)
    p.box("drain", W / 2, (1.35 + v0) / 2, 0.2, 0.2, 0.0, 0.006)
    wall_item(p, W, D, "left", D * 0.45, 0.25, 0.0, 0.15, 0.9, 1.15, "hose_reel")
    wall_item(p, W, D, "front", s0 + 0.1, 0.21, 0.0, 0.004, 1.3, 1.6, "paper")


def changing(ctx):
    """벽을 따라 락커, 가운데 긴 벤치, 옷걸이와 거울"""
    p, W, D = ctx.p, ctx.W, ctx.D
    L = max(0.5, D - 1.7)
    for side in ("left", "right"):
        wall_item(p, W, D, side, 1.4 + L / 2, L, 0.0, 0.45, 0.0, 1.8, "locker", collide=True)
        n = int(L / 0.4)
        for i in range(n + 1):
            wall_item(p, W, D, side, 1.4 + i * L / n, 0.012, 0.45, 0.006, 0.02, 1.78, "locker_line")
    if W > 2.2:
        bench(p, W / 2, 1.4 + L / 2, max(0.8, L - 0.8), along_u=False)
    wall_item(p, W, D, "back", W / 2, 0.6, 0.0, 0.02, 1.0, 1.8, "mirror")
    for i in range(4):
        wall_item(p, W, D, "back", W / 2 - 0.9 + i * 0.6 if W > 2.4 else W / 2, 0.05, 0.0, 0.08, 1.6, 1.66, "steel")


def closet(ctx):
    """걸레 세척용 수조, 선반, 대걸레 걸이, 양동이"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "back", W * 0.3, 0.7, 0.0, 0.55, 0.0, 0.45, "counter_white", collide=True)
    wall_item(p, W, D, "back", W * 0.3, 0.5, 0.05, 0.35, 0.42, 0.46, "drain")
    wall_item(p, W, D, "back", W * 0.3, 0.05, 0.0, 0.2, 0.6, 0.7, "steel")
    wall_item(p, W, D, "right", D * 0.6, min(1.3, D - 2.0), 0.0, 0.42, 0.0, 1.7, "shelf_metal", collide=True)
    for i in range(4):
        wall_item(p, W, D, "right", D * 0.6 - 0.45 + 0.3 * i, 0.12, 0.08, 0.26, 0.9 + 0.4 * (i % 2), 1.1 + 0.4 * (i % 2),
                  ("bottle", "box", "bin_blue", "box")[i])
    wall_item(p, W, D, "left", D * 0.55, 1.0, 0.0, 0.05, 1.5, 1.55, "steel")
    for i in range(4):
        wall_item(p, W, D, "left", D * 0.55 - 0.36 + 0.24 * i, 0.03, 0.06, 0.03, 0.25, 1.5, "mop_stick")
        wall_item(p, W, D, "left", D * 0.55 - 0.36 + 0.24 * i, 0.16, 0.02, 0.1, 0.02, 0.3, "mop_head")
    for i, m in enumerate(("bucket_blue", "bucket_red")):
        p.box(m, W * 0.55 + 0.35 * i, D - 1.0, 0.3, 0.3, 0.0, 0.32)
    ctx.anchor("closet", W * 0.55 + 0.17, D - 1.0, W * 0.55 + 0.17, max(0.5, D - 1.9))      # 양동이·대걸레 앞
