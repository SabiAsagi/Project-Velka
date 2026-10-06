# -*- coding: utf-8 -*-
"""옥상 (학교_맵_상세.md 옥상 + 레퍼런스 06).
본관 옥상 좌표: u = 서 -> 동 0~60, v = 북 -> 남 0~18.5 (건물 외곽 기준)."""
from props_base import Props, Frame, wall_item, bench, label
from props_annex import wall_label, rack
from batch import rows_y
from geometry import Rect

EDGE = 0.25          # 난간벽 두께


def _bed(p, u0, v0, u1, v1, key):
    """화단: 낮은 테두리 + 흙 + 관목 (충돌 한 덩어리)"""
    uc, vc, su, sv = (u0 + u1) / 2, (v0 + v1) / 2, u1 - u0, v1 - v0
    p.box("soil", uc, vc, su - 0.3, sv - 0.3, 0.0, 0.3)
    for du, dv, a, b in ((0, -(sv / 2 - 0.075), su, 0.15), (0, sv / 2 - 0.075, su, 0.15),
                         (-(su / 2 - 0.075), 0, 0.15, sv - 0.3), (su / 2 - 0.075, 0, 0.15, sv - 0.3)):
        p.box("planter", uc + du, vc + dv, a, b, 0.0, 0.38)
    nu, nv = max(1, int(su / 2.2)), max(1, int(sv / 2.2))
    for i in range(nu):
        for j in range(nv):
            r = p.rand(key, i, j)
            cu = u0 + su * (i + 0.5) / nu + (r - 0.5) * 0.5
            cv = v0 + sv * (j + 0.5) / nv + (p.rand(key, j, i) - 0.5) * 0.5
            if r > 0.72:      # 작은 나무
                p.cyl("trunk", cu, cv, 0.14, 0.3, 1.3)
                p.cyl("shrub", cu, cv, 1.3, 1.3, 2.0)
                p.cyl("shrub_light", cu, cv, 0.85, 2.0, 2.5)
            else:             # 관목
                d = 0.7 + 0.5 * r
                p.cyl("shrub_light" if r < 0.3 else "shrub", cu, cv, d, 0.3, 0.3 + d * 0.75)
    p.solid(uc, vc, su, sv, 0.0, 0.9)


def _fence(p, u0, v0, u1, v1, gate=None, h=1.2):
    """낮은 철제 울타리 (gate = (변, a0, a1): 그 구간은 비운다). 변: 'n','s','w','e'"""
    sides = {"n": (u0, v0, u1, v0), "s": (u0, v1, u1, v1), "w": (u0, v0, u0, v1), "e": (u1, v0, u1, v1)}
    posts = set()          # 모서리 기둥은 두 변이 함께 쓰므로 한 번만 세운다
    for name, (a, b, c, d) in sides.items():
        horizontal = name in ("n", "s")
        spans = [(a, c)] if horizontal else [(b, d)]
        if gate and gate[0] == name:
            lo, hi = spans[0]
            spans = [(lo, gate[1]), (gate[2], hi)]
        for lo, hi in spans:
            if hi - lo < 0.2:
                continue
            L, m = hi - lo, (lo + hi) / 2
            for hh in (0.25, 0.7, h - 0.03):
                if horizontal:
                    p.box("rail_metal", m, b, L, 0.04, hh, hh + 0.04)
                else:
                    p.box("rail_metal", a, m, 0.04, L, hh, hh + 0.04)
            n = max(1, int(L / 1.6))
            for i in range(n + 1):
                t = lo + L * i / n
                key = (round(t, 2), round(b, 2)) if horizontal else (round(a, 2), round(t, 2))
                if key in posts:
                    continue
                posts.add(key)
                p.box("rail_metal", key[0], key[1], 0.05, 0.05, 0.0, h)
            if horizontal:
                p.solid(m, b, L, 0.08, 0.0, h)
            else:
                p.solid(a, m, 0.08, L, 0.0, h)


def _pole_light(p, u, v):
    p.cyl("metal_dark", u, v, 0.1, 0.0, 2.6)
    p.box("metal_dark", u, v, 0.5, 0.12, 2.6, 2.68)
    p.box("lamp", u, v, 0.4, 0.1, 2.52, 2.6)


def _outdoor_unit(p, u, v, su=2.2, sv=1.5, h=1.6):
    """대형 실외기: 몸체 + 윗면 송풍구"""
    p.box("aircon", u, v, su, sv, 0.12, h, collide=True)
    p.box("metal_dark", u, v, su - 0.2, sv - 0.2, 0.0, 0.12)
    p.cyl("metal_dark", u, v, min(su, sv) * 0.7, h, h + 0.05)
    for k in range(5):
        p.box("metal_dark", u - su / 2 - 0.005, v - sv * 0.3 + sv * 0.15 * k, 0.01, 0.04, 0.3, h - 0.2)


def main_roof(batch, sw, path, fp, y):
    """본관 옥상: T자 보행로, 화단(서·중앙·동)과 벤치 4개, 중앙 원형 의자, 북서 실외기·환기 구역(낮은 울타리),
    북동 저상 물탱크·배관·안테나 구역, 배수구, 조명 4개, CCTV 2개, 피뢰침, 동측 관리용 고정 사다리, 난간 위 철망 틀"""
    p = Props(batch, path, Frame(fp, "z0", y), seed=61)
    W, D = fp.w, fp.d
    # 보행로: 출입문에서 남쪽으로, 가로 띠, 서·동 화단 사이 세로 띠, 중앙 원형 의자 둘레 광장
    p.box("roof_path", 30.0, 8.8, 44.9, 1.5, 0.0, 0.02)
    for u, v0, v1 in ((8.3, 9.55, 17.9), (51.7, 9.55, 17.9), (32.05, 6.4, 8.05), (32.05, 9.55, 11.55)):
        p.box("roof_path", u, (v0 + v1) / 2, 1.5, v1 - v0, 0.0, 0.02)
    p.box("roof_path", 32.0, 14.75, 6.4, 6.4, 0.0, 0.02)
    p.cyl("planter", 32.0, 14.75, 1.8, 0.02, 0.38)
    p.cyl("bench_wood", 32.0, 14.75, 2.1, 0.38, 0.45)
    p.cyl("shrub", 32.0, 14.75, 0.8, 0.45, 1.1)
    p.solid(32.0, 14.75, 1.7, 1.7, 0.0, 0.9)
    # 화단 (남쪽 난간까지 붙여 좁은 틈을 남기지 않는다)
    for i, (u0, u1) in enumerate(((0.3, 7.4), (9.2, 18.6), (21.5, 28.6), (35.4, 42.5), (45.4, 50.8), (52.6, 58.4))):
        _bed(p, u0, 10.5, u1, D - EDGE - 0.05, "bed%d" % i)
    for u in (4.5, 14.0, 48.0, 55.5):
        bench(p, u, 10.05, 1.6, along_u=True)
    # 북서: 실외기·환기장치 구역
    _fence(p, 1.6, 0.6, 17.9, 7.0, ("s", 9.0, 10.4))
    for u in (4.0, 8.6, 13.2):
        _outdoor_unit(p, u, 2.6)
    for u, su in ((5.3, 4.2), (12.6, 4.4)):
        p.box("stainless", u, 5.3, su, 0.9, 0.1, 0.8, collide=True)
        p.box("metal_dark", u, 5.3, su - 0.3, 0.7, 0.0, 0.1)
    # 북동: 저상 물탱크, 배관, 펌프, 통신 안테나
    _fence(p, 46.1, 0.6, 58.3, 7.0, ("s", 51.5, 52.9))
    p.box("planter", 49.6, 3.8, 4.6, 3.4, 0.0, 0.2)
    p.box("tank", 49.6, 3.8, 4.4, 3.2, 0.2, 1.7, collide=True)
    for k in range(5):
        p.box("stainless_dark", 47.6 + 1.0 * k, 3.8, 0.06, 3.24, 0.18, 1.72)
    p.box("metal_dark", 49.6, 3.8, 0.7, 0.7, 1.7, 1.78)
    p.box("pipe", 53.2, 3.8, 2.8, 0.14, 0.5, 0.64)
    p.box("pipe", 54.6, 4.5, 0.14, 1.5, 0.5, 0.64)
    p.box("pump", 54.6, 5.4, 0.7, 0.6, 0.0, 0.7, collide=True)
    p.cyl("metal_dark", 56.3, 2.2, 0.09, 0.0, 4.6)
    for k in range(3):
        p.box("metal_dark", 56.3, 2.2, 1.2 - 0.3 * k, 0.04, 3.4 + 0.45 * k, 3.44 + 0.45 * k)
    p.cyl("aircon", 56.3, 2.55, 0.5, 2.6, 2.7)
    p.box("metal_dark", 56.3, 2.2, 0.6, 0.6, 0.0, 0.08)
    # 배수구, 조명 4개(+CCTV 2대), 피뢰침
    for u, v in ((0.7, 0.7), (59.3, 0.7), (20.0, 17.85), (44.0, 17.85)):
        p.box("drain", u, v, 0.4, 0.4, 0.0, 0.012)
    for i, (u, v) in enumerate(((19.4, 0.7), (44.2, 0.7), (20.0, 17.3), (44.0, 17.3))):
        _pole_light(p, u, v)
        if i < 2:
            p.box("cctv", u, v + 0.18, 0.12, 0.22, 2.2, 2.34)
    p.cyl("steel", 59.2, 1.2, 0.05, 0.0, 5.5)
    p.box("metal_dark", 59.2, 1.2, 0.3, 0.3, 0.0, 0.08)
    # 동측 외벽 관리용 고정 사다리 (난간을 넘는다) + 출입금지 표지
    lu = W - EDGE - 0.08
    for dv in (-0.22, 0.22):
        p.box("ladder", lu, 13.0 + dv, 0.05, 0.05, 0.0, 2.0)
    for k in range(6):
        p.box("ladder", lu, 13.0, 0.04, 0.44, 0.3 + 0.3 * k, 0.34 + 0.3 * k)
    p.box("panel_red", lu, 13.9, 0.02, 0.5, 1.2, 1.55)
    p.box("paper", lu - 0.012, 13.9, 0.004, 0.4, 1.3, 1.45)
    # 난간벽 위 철망 틀 (기둥 + 가로대)
    top = 1.18
    for v in (EDGE / 2, D - EDGE / 2):
        for hh in (1.55, 1.95):
            p.box("rail_metal", W / 2, v, W - 0.3, 0.04, hh, hh + 0.04)
        for i in range(21):
            p.box("rail_metal", 0.3 + (W - 0.6) * i / 20, v, 0.05, 0.05, top, 2.0)
    for u in (EDGE / 2, W - EDGE / 2):
        for hh in (1.55, 1.95):
            p.box("rail_metal", u, D / 2, 0.04, D - 0.6, hh, hh + 0.04)
        for i in range(1, 7):
            p.box("rail_metal", u, 0.3 + (D - 0.6) * i / 7, 0.05, 0.05, top, 2.0)


def roof_room(ctx):
    """옥상 출입실 (앞 = 남쪽 철문 벽): 출입기록표, 소화기, 분전함, 청소도구, 정원 호스, 원예도구. 계단 옆 통로는 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    dm = doors[0].mid if doors else W / 2
    wall_item(p, W, D, "front", dm + 1.0, 0.3, 0.0, 0.01, 1.25, 1.7, "paper")                 # 출입기록표
    wall_item(p, W, D, "front", dm + 1.0, 0.36, 0.0, 0.02, 1.2, 1.24, "wood_dark")
    wall_item(p, W, D, "front", dm - 1.1, 0.17, 0.04, 0.17, 0.0, 0.56, "extinguisher")
    wall_item(p, W, D, "right", 2.4, 0.7, 0.0, 0.18, 1.0, 1.9, "panel_gray")                   # 분전함 (서쪽 벽)
    wall_item(p, W, D, "right", 2.4, 0.012, 0.18, 0.006, 1.05, 1.85, "metal_dark")
    wall_item(p, W, D, "left", 2.2, 1.0, 0.0, 0.05, 1.5, 1.55, "steel")                        # 청소도구 걸이 (동쪽 벽)
    for k in range(3):
        wall_item(p, W, D, "left", 1.85 + 0.35 * k, 0.03, 0.06, 0.03, 0.25, 1.5, "mop_stick")
        wall_item(p, W, D, "left", 1.85 + 0.35 * k, 0.16, 0.02, 0.1, 0.02, 0.3, "mop_head")
    wall_item(p, W, D, "left", 3.4, 0.45, 0.0, 0.18, 0.9, 1.35, "hose_reel")                   # 정원 호스
    for k in range(2):                                                                          # 원예도구 (삽·갈퀴)
        wall_item(p, W, D, "left", 4.3 + 0.25 * k, 0.03, 0.05, 0.03, 0.0, 1.4, "bench_wood")
        wall_item(p, W, D, "left", 4.3 + 0.25 * k, 0.2, 0.03, 0.04, 0.0, 0.25, "metal_dark")
    wall_item(p, W, D, "left", 5.0, 0.3, 0.02, 0.3, 0.0, 0.3, "watering_can")


def annex_roof(batch, path, fp, y):
    """별관 옥상: 실외기 줄, 환기구, 작은 물탱크 (출입 불가, 멀리서 보이는 윤곽용)"""
    p = Props(batch, path, Frame(fp, "x0", y), seed=71)       # u = 남 -> 북, v = 서 -> 동
    for k in range(5):
        _outdoor_unit(p, 8.0 + 4.0 * k, 3.0, 2.0, 1.4, 1.5)
    for k in range(3):
        p.cyl("stainless", 34.0 + 5.0 * k, 4.0, 0.9, 0.0, 0.9)
        p.cyl("stainless_dark", 34.0 + 5.0 * k, 4.0, 1.1, 0.9, 1.05)
    p.box("tank", 46.0, 13.0, 3.0, 2.4, 0.2, 1.5, collide=True)
    p.box("planter", 46.0, 13.0, 3.2, 2.6, 0.0, 0.2)


def gym_roof(batch, path, fp, y):
    """강당 지붕: 용마루 환기구, 가장자리 홈통 띠"""
    p = Props(batch, path, Frame(fp, "z0", y), seed=73)
    for k in range(5):
        u = 6.0 + 7.0 * k
        p.cyl("stainless", u, fp.d / 2, 1.2, 0.0, 0.7)
        p.cyl("stainless_dark", u, fp.d / 2, 1.5, 0.7, 0.9)
    p.box("roof_metal", fp.w / 2, fp.d / 2, fp.w - 1.2, 0.5, 0.0, 0.25)
