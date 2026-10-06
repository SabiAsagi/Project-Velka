# -*- coding: utf-8 -*-
"""별관 1~3층 방 배치 (학교_맵_상세.md 별관 층별 구성 + 레퍼런스 07~09).
동쪽 큰 방: 앞(v=0) = 복도 벽, u = 남 -> 북 (도면 왼쪽 -> 오른쪽), v = 복도 -> 운동장 쪽 창.
서쪽 지원실: 앞(v=0) = 복도 벽, u = 북 -> 남 (도면 오른쪽 -> 왼쪽), v = 복도 -> 서쪽 외벽."""
from props_base import wall_item, cabinet, shelf_unit, shelf_along, bench, plant, bins, label, facing_rows
from props_more import office_desk, table, sofa, blinds, curtains_full, whiteboard_wall
from props_annex import (openings_on, wall_label, steel_table, round_box, stool, rack, upright_fridge, glass_cabinet,
                         pc_desk, lab_bench, grand_piano, music_seat, easel, book_cart, book_stack, vending)

# ------------------------------------------------------------------ 1층: 급식실

CAF_COLS = [3.66 + 2.81 * i for i in range(10)]   # 세로 식탁 열 10개 (레퍼런스 간격)
CAF_TL = 0.75                                      # 식탁 하나 길이
CAF_V = (2.9, 6.35)                                # 위·아래 반열 시작 v (사이 1.2m 주 통로)


def _caf_block(p, u, v0, n):
    """세로(v)로 이어 붙인 급식 식탁 n개 + 양옆 고정 스툴. 충돌은 한 덩어리."""
    L = n * CAF_TL
    vc = v0 + L / 2
    p.box("caf_table", u, vc, 0.7, L, 0.70, 0.74)
    for i in range(1, n):
        p.box("stainless_dark", u, v0 + i * CAF_TL, 0.7, 0.014, 0.71, 0.743)
    for i in range(n):
        tv = v0 + (i + 0.5) * CAF_TL
        p.box("chair_frame", u, tv, 0.06, 0.4, 0.0, 0.70)
        for k in (-1, 1):
            sv = tv + k * CAF_TL * 0.25
            p.box("chair_frame", u, sv, 1.2, 0.035, 0.22, 0.255)
            for s in (-1, 1):
                p.box("caf_stool", u + s * 0.6, sv, 0.28, 0.28, 0.41, 0.45)
                p.box("chair_frame", u + s * 0.6, sv, 0.05, 0.05, 0.255, 0.41)
    p.solid(u, vc, 1.48, L, 0.0, 0.76)


def cafeteria(ctx):
    """급식실: 세로 식탁 열 10개(열마다 3 + 주 통로 + 3), 교직원 식탁 3개, 서쪽 벽 긴 음수대, 동쪽 배식대(2m 줄)와
    식판 반납구(1.5m 줄), 식단 게시판, AED·소화기·분리수거대. 입장 -> 식판 -> 배식 -> 식사 -> 반납 동선이 겹치지 않는다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    for u in CAF_COLS:
        for v0 in CAF_V:
            _caf_block(p, u, v0, 3)
    for i, (ci, v) in enumerate(((1, 3.3), (4, 7.9), (7, 4.6), (8, 6.8))):   # 치우지 않은 식판 몇 개
        u = CAF_COLS[ci]
        p.box("tray", u + 0.12, v, 0.36, 0.28, 0.74, 0.755)
        p.box(("food_rice", "food_soup", "food_green", "food_yellow")[i], u + 0.05, v - 0.05, 0.1, 0.1, 0.755, 0.775)
        p.box("bottle", u - 0.2, v + 0.1, 0.07, 0.07, 0.74, 0.84)
    for i, u in enumerate((4.6, 7.4, 10.2)):                                 # 교직원 식탁 (8석씩)
        table(p, u, 1.4, 2.0, 0.75, 4, along="u", key="stf%d" % i)
        p.box("box", u - 0.6, 1.4, 0.24, 0.12, 0.75, 0.83)
        p.box("stainless", u + 0.5, 1.4, 0.12, 0.12, 0.75, 0.95)
    # 급식 확인대 (학생증 단말·손 소독제)
    p.box("office_panel", 1.75, 1.95, 1.1, 0.55, 0.0, 1.0, collide=True)
    p.box("office_top", 1.75, 1.95, 1.16, 0.6, 1.0, 1.04)
    p.box("terminal", 1.55, 1.95, 0.2, 0.25, 1.04, 1.2)
    p.box("bottle", 2.1, 1.9, 0.08, 0.08, 1.04, 1.26)
    # 서쪽(왼쪽) 벽: 긴 음수대, AED, 소화기 / 창가 구석 분리수거대
    fa, fl = 7.65, 2.7
    wall_item(p, W, D, "left", fa, fl, 0.0, 0.5, 0.0, 0.76, "stainless", collide=True)
    wall_item(p, W, D, "left", fa, fl - 0.1, 0.08, 0.36, 0.76, 0.768, "stainless_dark")
    wall_item(p, W, D, "left", fa, fl, 0.0, 0.03, 0.76, 1.3, "stainless")
    for i in range(5):
        a = fa - fl / 2 + fl * (i + 0.5) / 5
        wall_item(p, W, D, "left", a, 0.03, 0.05, 0.03, 0.768, 1.02, "steel")
        wall_item(p, W, D, "left", a, 0.03, 0.08, 0.14, 0.99, 1.02, "steel")
    wall_item(p, W, D, "left", fa, 0.9, 0.0, 0.02, 1.55, 1.8, "sign_blue")
    bins(p, 2.2, D - 0.3, 3)
    wall_item(p, W, D, "left", 3.05, 0.4, 0.0, 0.16, 1.1, 1.55, "aed")
    wall_item(p, W, D, "left", 3.05, 0.3, 0.0, 0.01, 1.65, 1.85, "sign_green")
    wall_item(p, W, D, "left", 2.45, 0.17, 0.04, 0.17, 0.0, 0.56, "extinguisher")
    wall_item(p, W, D, "left", 2.45, 0.09, 0.08, 0.09, 0.56, 0.66, "metal_dark")
    # 출입문 매트, 손 소독대
    fd = ctx.doors_on("front")
    dm = fd[0].mid if fd else W / 2
    p.box("mat_dark", dm, 0.95, 2.2, 1.5, 0.0, 0.012)
    ld = ctx.doors_on("left")
    if ld:
        p.box("mat_dark", 0.95, ld[0].mid, 1.5, 2.2, 0.0, 0.012)
    p.box("purifier", dm - 1.6, 0.25, 0.3, 0.3, 0.0, 1.05)
    _caf_serving(ctx)
    # 복도 쪽 벽: 식단 게시판, 시계, 영양 게시물, 벽걸이 냉난방기
    mb = 28.4
    wall_item(p, W, D, "front", mb, 1.5, 0.0, 0.03, 1.15, 2.15, "frame_alu")
    wall_item(p, W, D, "front", mb, 1.4, 0.03, 0.01, 1.2, 2.1, "chalkboard")
    for k in range(5):
        wall_item(p, W, D, "front", mb, 1.0, 0.04, 0.004, 1.3 + 0.13 * k, 1.34 + 0.13 * k, "chalk")
    wall_label(ctx, "front", mb, 1.98, "오늘의 식단", 0.06, 0.0035, 40, (0.95, 0.95, 0.9))
    wall_item(p, W, D, "front", 13.2, 0.36, 0.0, 0.05, 2.4, 2.76, "clock_rim")
    wall_item(p, W, D, "front", 13.2, 0.3, 0.05, 0.01, 2.43, 2.73, "clock_face")
    for k, m in enumerate(("paper", "paper_yellow", "art_green", "paper_blue")):
        wall_item(p, W, D, "front", 19.6 + 0.75 * k, 0.5, 0.0, 0.005, 1.25, 1.95, m)
    for u in (6.0, 22.5, 30.6):
        wall_item(p, W, D, "front", u, 1.0, 0.0, 0.24, 2.75, 3.05, "aircon")
    blinds(ctx, "back", drop=0.3)


def _caf_serving(ctx):
    """동쪽: 조리실 벽에서 띄운 배식대(식판 레일·가림 유리·음식 통), 식판·수저 받는 곳, 반납대와 잔반통"""
    p, W, D = ctx.p, ctx.W, ctx.D
    ops = openings_on(ctx, "right")
    cu0, cu1 = W - 1.85, W - 1.05
    cv0, cv1 = 0.8, 4.45
    cu, cv = (cu0 + cu1) / 2, (cv0 + cv1) / 2
    p.box("stainless", cu, cv, cu1 - cu0, cv1 - cv0, 0.0, 0.86, collide=True)
    p.box("stainless_dark", cu, cv, cu1 - cu0 + 0.04, cv1 - cv0 + 0.04, 0.86, 0.9)
    p.box("stainless", cu0 - 0.17, cv, 0.28, cv1 - cv0, 0.78, 0.8)
    for dv in (cv0 + 0.1, cv, cv1 - 0.1):
        p.box("stainless_dark", cu0 - 0.17, dv, 0.26, 0.04, 0.0, 0.78)
    p.box("glass", cu0 + 0.1, cv, 0.012, cv1 - cv0 - 0.3, 1.12, 1.5)
    for dv in (cv0 + 0.15, cv1 - 0.15):
        p.box("stainless_dark", cu0 + 0.1, dv, 0.03, 0.03, 0.9, 1.5)
    for i, m in enumerate(("food_rice", "food_soup", "food_red", "food_green", "food_yellow", "food_green")):
        v = cv0 + 0.35 + i * 0.58
        p.box("stainless", cu + 0.1, v, 0.5, 0.46, 0.9, 0.93)
        p.box(m, cu + 0.1, v, 0.44, 0.4, 0.93, 0.945)
    steel_table(p, cu0 - 0.95, 0.42, 1.3, 0.55, 0.85)
    for k in range(2):
        p.box("tray", cu0 - 1.3 + 0.55 * k, 0.42, 0.42, 0.32, 0.85, 0.97 + 0.06 * k)
    p.box("stainless", cu0 - 0.45, 0.42, 0.24, 0.3, 0.85, 1.0)
    for a0, a1, _ in ops:                                   # 배식구·반납구 창턱 판
        p.box("stainless", W + 0.075, (a0 + a1) / 2, 0.27, a1 - a0 - 0.02, 0.95, 0.972)
    if ops:
        a0, a1, _ = ops[0]
        wall_item(p, W, D, "right", (a0 + a1) / 2, a1 - a0 + 0.2, 0.0, 0.14, 2.06, 2.3, "steel_frame")
    if len(ops) > 1:
        r0, r1, _ = ops[1]
        ra = (r0 + r1) / 2
        wall_item(p, W, D, "right", ra, r1 - r0 + 0.1, 0.0, 0.7, 0.0, 0.9, "stainless", collide=True)
        p.box("tray", W - 0.35, ra - 0.5, 0.42, 0.32, 0.9, 1.02)
        p.box("tray", W - 0.38, ra + 0.1, 0.42, 0.32, 0.9, 0.96)
        p.box("stainless_dark", W - 0.35, ra + 0.7, 0.3, 0.3, 0.9, 1.05)
        for k, m in enumerate(("bin_gray", "bin_blue")):
            round_box(p, m, W - 1.05, r0 + 0.35 + 0.65 * k, 0.44, 0.0, 0.62)


# ------------------------------------------------------------------ 1층: 조리실·세척실·휴게실·식품 창고

def kitchen(ctx):
    """조리실: 복도 벽의 냉장·냉동고와 식기 소독고, 배식구 안쪽 전달대, 전처리 작업대, 국솥 2기·취반기·가스 레인지와
    대형 배기 후드, 세척실 쪽 작업대, 바닥 배수로. 가운데 작업 통로는 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(3):
        upright_fridge(p, W, D, "front", 1.4 + 1.0 * i, 0.98, 0.8, 1.95, 2 if i else 1)
    for i in range(2):
        a = 6.2 + 0.92 * i
        wall_item(p, W, D, "front", a, 0.9, 0.0, 0.65, 0.0, 1.8, "stainless", collide=True)
        wall_item(p, W, D, "front", a, 0.7, 0.65, 0.01, 0.9, 1.6, "glass_dark")
        wall_item(p, W, D, "front", a + 0.3, 0.03, 0.65, 0.04, 0.8, 1.2, "metal_dark")
    wall_item(p, W, D, "front", 8.6, 1.4, 0.0, 0.6, 0.0, 0.85, "stainless", collide=True)     # 개수대
    wall_item(p, W, D, "front", 8.6, 1.0, 0.1, 0.4, 0.85, 0.857, "stainless_dark")
    wall_item(p, W, D, "front", 8.6, 0.03, 0.04, 0.03, 0.857, 1.2, "steel")
    wall_item(p, W, D, "front", 8.6, 1.5, 0.0, 0.35, 1.45, 1.48, "stainless")                  # 벽 선반과 솥
    for k in range(3):
        round_box(p, "stainless_dark", 8.1 + 0.5 * k, 0.19, 0.3, 1.48, 1.68)
    wall_item(p, W, D, "front", 5.5, 0.17, 0.04, 0.17, 0.0, 0.56, "extinguisher")
    wall_item(p, W, D, "front", 5.5, 0.21, 0.0, 0.004, 1.3, 1.6, "paper")
    ops = openings_on(ctx, "left")
    if ops:                                                                                    # 배식구 안쪽 전달대
        a0, a1, _ = ops[0]
        wall_item(p, W, D, "left", (a0 + a1) / 2, a1 - a0, 0.0, 0.6, 0.0, 0.9, "stainless", collide=True)
        for k in range(4):
            v = a0 + 0.5 + k * 0.85
            p.box("stainless_dark", 0.3, v, 0.36, 0.55, 0.9, 1.06)
            p.box(("food_rice", "food_soup", "food_red", "food_green")[k], 0.3, v, 0.3, 0.49, 1.06, 1.07)
    # 전처리 작업대 두 개 (가운데 통로 u 4.2~5.5 비움)
    steel_table(p, 2.85, 2.175, 2.3, 0.65)
    steel_table(p, 7.05, 2.175, 3.1, 0.65)
    p.box("food_green", 2.3, 2.175, 0.4, 0.3, 0.85, 0.87)
    p.box("counter_white", 3.25, 2.15, 0.4, 0.3, 0.85, 0.87)
    round_box(p, "stainless", 6.2, 2.175, 0.36, 0.85, 1.0)
    round_box(p, "stainless", 6.75, 2.2, 0.3, 0.85, 0.97)
    p.box("bin_green", 7.6, 2.175, 0.5, 0.36, 0.85, 1.1)
    p.box("box", 8.2, 2.175, 0.4, 0.3, 0.85, 1.05)
    _kitchen_line(ctx)


def _kitchen_line(ctx):
    """가열 라인(국솥 2기·취반기·가스 레인지)과 배기 후드, 세척실 쪽 작업대, 오른쪽 벽 설비, 바닥 배수로"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for u in (2.2, 3.55):
        round_box(p, "stainless", u, 3.95, 1.0, 0.0, 0.85)
        round_box(p, "stainless_dark", u, 3.95, 0.9, 0.85, 0.9)
        p.box("metal_dark", u, 3.95, 0.3, 0.05, 0.9, 0.96)
        p.solid(u, 3.95, 1.0, 1.0, 0.0, 0.9)
    p.box("stainless", 6.0, 3.95, 0.85, 0.8, 0.0, 1.55, collide=True)
    for k in range(3):
        p.box("stainless_dark", 6.0, 3.95 - 0.408, 0.75, 0.01, 0.15 + 0.48 * k, 0.55 + 0.48 * k)
        p.box("metal_dark", 6.0, 3.95 - 0.425, 0.4, 0.02, 0.5 + 0.48 * k, 0.53 + 0.48 * k)
    p.box("stainless", 7.75, 3.95, 1.9, 0.8, 0.0, 0.82, collide=True)
    for k in range(3):
        p.box("metal_dark", 7.15 + 0.6 * k, 3.95, 0.42, 0.42, 0.82, 0.86)
    round_box(p, "stainless_dark", 7.15, 3.95, 0.5, 0.86, 1.2)
    round_box(p, "metal_dark", 8.35, 3.95, 0.5, 0.86, 0.95)
    p.box("stainless", 5.15, 3.95, 7.3, 1.45, 2.05, 2.4)
    p.box("stainless_dark", 5.15, 3.95, 7.1, 1.25, 2.0, 2.05)
    for u in (3.0, 7.2):
        p.box("stainless", u, 3.95, 0.5, 0.5, 2.4, 3.55)
    steel_table(p, 2.85, 5.675, 2.9, 0.55)
    steel_table(p, 6.3, 5.675, 1.6, 0.55)
    for k in range(2):
        p.box("tray", 2.0 + 0.6 * k, 5.675, 0.42, 0.32, 0.85, 1.0 + 0.1 * k)
    p.box("stainless_dark", 6.3, 5.675, 0.4, 0.35, 0.85, 1.3)
    rack(p, W, D, "right", 1.45, 1.5, 0.5, 1.8, 4, ("stainless", "box", "stainless_dark"), "krk")
    wall_item(p, W, D, "right", 4.6, 0.5, 0.0, 0.42, 0.7, 0.85, "porcelain")
    wall_item(p, W, D, "right", 4.6, 0.03, 0.04, 0.03, 0.85, 1.1, "steel")
    wall_item(p, W, D, "right", 5.7, 0.8, 0.0, 0.03, 1.55, 1.6, "steel")
    for k in range(2):
        wall_item(p, W, D, "right", 5.5 + 0.4 * k, 0.3, 0.03, 0.04, 0.9, 1.55, "apron")
    p.box("drain_grate", 5.1, 4.92, 8.0, 0.2, 0.0, 0.008)
    p.box("drain_grate", 4.88, 3.7, 0.2, 5.0, 0.0, 0.012)


def wash(ctx):
    """세척실 (조리실에 벽 없이 붙음): 반납구 안쪽 받침대, 불림 이중 싱크, 대형 세척기, 건조대, 식기 소독고, 배수로"""
    p, W, D = ctx.p, ctx.W, ctx.D
    ops = openings_on(ctx, "left")
    if ops:
        a0, a1, _ = ops[0]
        wall_item(p, W, D, "left", (a0 + a1) / 2 + 0.05, a1 - a0 - 0.1, 0.0, 0.7, 0.0, 0.9, "stainless", collide=True)
        p.box("tray", 0.35, a0 + 0.6, 0.42, 0.32, 0.9, 1.08)
        p.box("bucket_blue", 0.35, a0 + 1.4, 0.3, 0.3, 0.9, 1.15)
    wall_item(p, W, D, "back", 1.75, 1.6, 0.0, 0.7, 0.0, 0.85, "stainless", collide=True)
    for k in (-1, 1):
        wall_item(p, W, D, "back", 1.75 + 0.4 * k, 0.62, 0.12, 0.46, 0.85, 0.857, "stainless_dark")
        wall_item(p, W, D, "back", 1.75 + 0.4 * k, 0.03, 0.03, 0.03, 0.857, 1.25, "steel")
        wall_item(p, W, D, "back", 1.75 + 0.4 * k, 0.03, 0.06, 0.2, 1.22, 1.25, "steel")
    wall_item(p, W, D, "back", 3.7, 1.9, 0.0, 0.75, 0.0, 0.9, "stainless", collide=True)
    wall_item(p, W, D, "back", 3.7, 1.1, 0.06, 0.65, 0.9, 1.7, "stainless")
    wall_item(p, W, D, "back", 3.7, 0.5, 0.71, 0.02, 1.1, 1.5, "glass_dark")
    wall_item(p, W, D, "back", 3.7, 0.25, 0.75, 0.03, 0.55, 0.75, "control_panel")
    rack(p, W, D, "back", 5.6, 1.5, 0.55, 1.7, 4, ("tray", "stainless", "tray"), "dry", 0.9, "stainless_dark")
    wall_item(p, W, D, "right", 1.0, 1.5, 0.0, 0.6, 0.0, 1.8, "stainless", collide=True)
    wall_item(p, W, D, "right", 1.0, 1.3, 0.6, 0.01, 0.4, 1.6, "glass_dark")
    p.box("drain_grate", 3.4, D - 1.0, 5.0, 0.2, 0.0, 0.008)
    p.box("rubber_mat", 1.75, D - 1.5, 1.5, 0.6, 0.0, 0.014)


def staff_lounge(ctx):
    """직원 휴게실: 개인 사물함, 짧은 벤치, 소형 냉장고와 전자레인지, 앞치마 걸이"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "right", 1.0, 1.5, 0.0, 0.45, 0.0, 1.8, "locker_gray", collide=True)
    for i in range(1, 4):
        wall_item(p, W, D, "right", 0.25 + 0.375 * i, 0.012, 0.45, 0.006, 0.03, 1.77, "locker_line")
    bench(p, 1.5, 2.0, 0.9, along_u=True)
    p.box("fridge_small", 0.33, D - 0.33, 0.55, 0.55, 0.0, 0.85, collide=True)
    p.box("monitor_old", 0.33, D - 0.33, 0.45, 0.35, 0.85, 1.12)
    wall_item(p, W, D, "left", 1.6, 0.7, 0.0, 0.03, 1.55, 1.6, "steel")
    for k in range(2):
        wall_item(p, W, D, "left", 1.4 + 0.4 * k, 0.3, 0.03, 0.04, 0.9, 1.55, "apron")
    blinds(ctx, "back", drop=0.4)


def food_storage(ctx):
    """조리 식품 창고: 건식 선반, 곡물·가루 포대 팔레트, 냉장고·냉동고, 냉동 평대, 손수레, 입출고 기록대, 포충등"""
    p, W, D = ctx.p, ctx.W, ctx.D
    p.box("pallet", 0.45, 1.85, 0.8, 0.9, 0.0, 0.14)
    for k in range(3):
        p.box("sack", 0.45, 1.85, 0.7 - 0.06 * k, 0.8 - 0.05 * k, 0.14 + 0.2 * k, 0.34 + 0.2 * k)
    p.solid(0.45, 1.85, 0.8, 0.9, 0.0, 0.75)
    rack(p, W, D, "left", 6.75, 5.1, 0.5, 1.9, 4, ("box", "paint_can", "sack", "box"), "fs1")
    p.box("cart", W - 0.45, 0.65, 0.5, 0.7, 0.0, 0.22)
    p.box("metal_dark", W - 0.45, 0.98, 0.46, 0.04, 0.22, 1.1)
    for i in range(2):
        upright_fridge(p, W, D, "right", 2.0 + 0.95 * i, 0.93, 0.78, 1.95, 2)
    rack(p, W, D, "right", 4.85, 2.6, 0.5, 1.9, 4, ("paint_can", "box", "box"), "fs2")
    wall_item(p, W, D, "right", 8.8, 1.0, 0.0, 0.7, 0.0, 0.9, "fridge_small", collide=True)
    wall_item(p, W, D, "right", 8.8, 0.96, 0.02, 0.66, 0.9, 0.93, "stainless")
    wall_item(p, W, D, "back", 1.6, 0.9, 0.0, 0.5, 0.72, 0.75, "office_top")
    wall_item(p, W, D, "back", 1.6, 0.84, 0.03, 0.44, 0.0, 0.72, "office_panel", collide=True)
    wall_item(p, W, D, "back", 1.4, 0.3, 0.12, 0.22, 0.75, 0.77, "attendance")
    wall_item(p, W, D, "back", 1.9, 0.3, 0.1, 0.3, 0.75, 0.87, "stainless")
    wall_item(p, W, D, "back", 1.6, 0.5, 0.0, 0.1, 2.5, 2.62, "uv_lamp")


# ------------------------------------------------------------------ 1층: 매점·지원실·열린 공간

def shop(ctx):
    """매점: 복도 쪽 판매창과 계산대, 가운데 진열대, 뒤 벽 진열 선반, 음료 냉장고 2대, 아이스크림 냉동고. 창고와는 직원용 내부문"""
    p, W, D = ctx.p, ctx.W, ctx.D
    ops = openings_on(ctx, "front")
    a0, a1 = (ops[0][0], ops[0][1]) if ops else (1.7, 4.4)
    ca = (a0 + a1) / 2
    wall_item(p, W, D, "front", ca, a1 - a0, 0.0, 0.6, 0.0, 0.86, "counter_wood", collide=True)
    wall_item(p, W, D, "front", ca, a1 - a0 + 0.04, 0.0, 0.64, 0.86, 0.9, "counter_top")
    p.box("counter_top", ca, -0.075, a1 - a0 - 0.02, 0.33, 0.9, 0.925)          # 벽 구멍을 지나는 판매대 판
    p.box("terminal", a1 - 0.45, 0.3, 0.36, 0.34, 0.9, 1.12)
    p.box("monitor", a1 - 0.45, 0.45, 0.3, 0.03, 1.12, 1.34)
    for k, m in enumerate(("art_red", "art_yellow", "art_blue", "art_green")):
        p.box(m, a0 + 0.3 + 0.42 * k, 0.32, 0.3, 0.22, 0.9, 1.0)
    stool(p, ca, 1.05, "chair_office", 0.6, 0.36)
    shelf_unit(p, 2.7, 2.55, 1.6, 0.5, 1.4, 3, 0.9, "shelf_metal", ("art_red", "art_yellow", "paper_blue", "art_green", "box"), "gd")
    shelf_along(p, W, D, "back", 2.0, 3.4, 0.4, 1.7, 4, 0.9, "shelf_metal", "sbk", ("art_yellow", "box", "art_red", "paper_blue"))
    for i in range(2):
        a = 3.0 + 0.66 * i
        wall_item(p, W, D, "right", a, 0.64, 0.0, 0.7, 0.0, 1.95, "office_drawer", collide=True)
        wall_item(p, W, D, "right", a, 0.54, 0.7, 0.012, 0.25, 1.75, "glass_dark")
        for k in range(4):
            wall_item(p, W, D, "right", a, 0.44, 0.712, 0.006, 0.4 + 0.34 * k, 0.52 + 0.34 * k,
                      ("art_red", "art_blue", "art_green", "art_yellow")[(k + i) % 4])
    wall_item(p, W, D, "right", 1.9, 0.9, 0.0, 0.6, 0.0, 0.85, "fridge_small", collide=True)
    wall_item(p, W, D, "right", 1.9, 0.84, 0.03, 0.54, 0.85, 0.87, "glass_dark")
    for k in range(3):
        p.box("box", 0.3, 1.62 + 0.02 * k, 0.5 - 0.04 * k, 0.42, 0.36 * k, 0.36 * (k + 1))
    # 복도 쪽 간판 (판매창 위)
    p.box("sign_board", ca, -0.166, a1 - a0 + 0.3, 0.03, 2.25, 2.62)
    x, z = ctx.frame.pt(ca, -0.2)
    label(ctx.sw, ctx.container, (x, ctx.y + 2.43, z), "매 점", 0.006, 64, (0.2, 0.14, 0.08), facing_rows(ctx.frame, "front"))


def shop_storage(ctx):
    """매점 창고: 벽면 선반, 음료 상자 더미, 가운데 팔레트 (복도 문과 매점 내부문을 잇는 통로는 비움)"""
    p, W, D = ctx.p, ctx.W, ctx.D
    rack(p, W, D, "left", 2.85, 2.7, 0.5, 1.9, 4, ("box", "art_red", "box", "art_yellow"), "ss1")
    rack(p, W, D, "back", 2.75, 3.0, 0.5, 1.7, 4, ("box", "paper_blue", "box"), "ss2")
    for k in range(3):
        for j in range(2):
            p.box(("vending_blue", "vending_red")[(k + j) % 2], W - 0.35, 0.6 + 0.62 * k, 0.5, 0.52, 0.32 * j, 0.32 * (j + 1))
    p.solid(W - 0.35, 1.22, 0.55, 1.85, 0.0, 0.66)
    p.box("pallet", 1.3, 2.5, 1.0, 0.9, 0.0, 0.14)
    p.box("box", 1.3, 2.5, 0.9, 0.8, 0.14, 0.8, collide=True)
    p.box("box", 1.2, 2.45, 0.5, 0.4, 0.8, 1.15)


def nutrition_office(ctx):
    """영양교사실: 책상, 창 아래 낮은 수납장(식단 자료), 문서장, 급식 일정표, 보존식 냉장고. 급식행정실과 내부문"""
    p, W, D = ctx.p, ctx.W, ctx.D
    office_desk(p, 3.35, 2.25, facing=-1, w=1.4, items=("monitor", "papers", "mug"), key="nt")
    wall_item(p, W, D, "right", 1.0, 1.2, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "right", 1.0, 0.012, 0.45, 0.006, 0.05, 1.85, "metal_dark")
    whiteboard_wall(p, W, D, "right", 3.1, 1.4)
    for k in range(4):
        wall_item(p, W, D, "right", 2.65 + 0.3 * k, 0.21, 0.04, 0.004, 1.2 + 0.2 * (k % 2), 1.5 + 0.2 * (k % 2), "paper_yellow" if k % 2 else "paper")
    wall_item(p, W, D, "back", W / 2, W - 0.8, 0.0, 0.4, 0.0, 0.8, "cabinet_wood", collide=True)
    for k in range(3):
        wall_item(p, W, D, "back", 1.0 + 0.3 * k, 0.24, 0.06, 0.28, 0.8, 1.1, "file_box")
    plant(p, W - 0.7, D - 0.2, 0.8, 0.16)
    wall_item(p, W, D, "left", 0.45, 0.55, 0.0, 0.55, 0.0, 0.85, "fridge_small", collide=True)
    blinds(ctx, "back", drop=0.35)


def meal_admin(ctx):
    """급식행정실: 책상, 문서장, 복합기, 발주·검수 서류 상자, 급식 일정표"""
    p, W, D = ctx.p, ctx.W, ctx.D
    office_desk(p, 1.5, 2.3, facing=-1, w=1.4, items=("monitor", "papers", "exam"), key="ma")
    wall_item(p, W, D, "left", 0.9, 1.2, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "left", 0.9, 0.012, 0.45, 0.006, 0.05, 1.85, "metal_dark")
    whiteboard_wall(p, W, D, "left", 2.2, 1.1, 1.1, 1.9)
    wall_label(ctx, "left", 2.2, 1.78, "6월 급식 일정", 0.05, 0.0028, 36)
    shelf_along(p, W, D, "left", 3.45, 1.1, 0.35, 1.5, 3, 0.9, key="mas", book_mats=("file_box", "box", "paper"))
    wall_item(p, W, D, "right", 0.75, 0.7, 0.0, 0.6, 0.0, 1.15, "copier", collide=True)
    wall_item(p, W, D, "back", W / 2, W - 0.8, 0.0, 0.4, 0.0, 0.8, "cabinet_wood", collide=True)
    for k in range(5):
        wall_item(p, W, D, "back", 1.4 + 0.42 * k, 0.36, 0.05, 0.3, 0.8, 1.05 + 0.1 * (k % 2), "box" if k % 2 else "file_box")
    blinds(ctx, "back", drop=0.35)


def alcove_meal(ctx):
    """1층 열린 급식 안내 공간 (문 없이 복도와 이어짐): 주간 식단표, 영양·알레르기 안내, 벤치, 세움 간판"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "back", W / 2, 2.3, 0.0, 0.03, 0.95, 1.7, "frame_alu")
    wall_item(p, W, D, "back", W / 2, 2.2, 0.03, 0.01, 1.0, 1.65, "whiteboard")
    for k in range(5):
        wall_item(p, W, D, "back", W / 2 - 0.84 + 0.42 * k, 0.36, 0.04, 0.004, 1.08, 1.56, ("paper", "paper_yellow")[k % 2])
    wall_item(p, W, D, "left", D * 0.5, 1.9, 0.0, 0.02, 1.0, 1.9, "cork")
    for k, m in enumerate(("art_green", "paper", "paper_pink", "paper_blue")):
        wall_item(p, W, D, "left", D * 0.5 - 0.66 + 0.44 * k, 0.32, 0.02, 0.004, 1.15 + 0.1 * (k % 2), 1.62 + 0.1 * (k % 2), m)
    wall_label(ctx, "left", D * 0.5, 2.08, "급식 안내", 0.03, 0.004, 44)
    bench(p, W / 2, D - 1.3, 1.6, along_u=True)
    p.box("paper_blue", W - 0.45, 0.7, 0.5, 0.04, 0.25, 1.8)
    p.box("metal_dark", W - 0.45, 0.7, 0.55, 0.3, 0.0, 0.04)


def alcove_gallery(ctx):
    """2층 작품 전시 공간: 벽면 전시 패널과 액자, 전시대 두 개, 화분"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "back", W / 2, 2.6, 0.0, 0.04, 0.6, 1.72, "backdrop")
    for k, m in enumerate(("art_red", "art_blue", "art_yellow", "art_green", "canvas")):
        wall_item(p, W, D, "back", W / 2 - 1.0 + 0.5 * k, 0.4, 0.04, 0.02, 0.95 + 0.12 * (k % 2), 1.45 + 0.12 * (k % 2), "frame_wood")
        wall_item(p, W, D, "back", W / 2 - 1.0 + 0.5 * k, 0.32, 0.06, 0.004, 0.99 + 0.12 * (k % 2), 1.41 + 0.12 * (k % 2), m)
    for k, m in enumerate(("canvas", "art_blue", "paper_pink")):
        wall_item(p, W, D, "left", 1.2 + 1.0 * k, 0.7, 0.0, 0.03, 1.1, 1.75, "frame_wood")
        wall_item(p, W, D, "left", 1.2 + 1.0 * k, 0.6, 0.03, 0.004, 1.15, 1.7, m)
    wall_label(ctx, "left", 2.2, 2.0, "학생 작품 전시", 0.03, 0.004, 44)
    for i, (u, v, m) in enumerate(((0.9, 2.6, "plaster"), (2.3, 3.1, "clay"))):
        p.box("counter_white", u, v, 0.45, 0.45, 0.0, 0.9, collide=True)
        p.box(m, u, v, 0.24, 0.24, 0.9, 1.25)
    plant(p, W - 0.4, D - 0.4, 0.0, 0.3)


def alcove_lockers(ctx):
    """3층 사물함·반납 공간: 가방 사물함 3칸 묶음, 도서 반납함, 이용 안내"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(3):
        a = 0.62 + 1.0 * i
        wall_item(p, W, D, "back", a, 0.95, 0.0, 0.45, 0.0, 1.6, "locker_blue", collide=True)
        for k in range(1, 4):
            wall_item(p, W, D, "back", a, 0.9, 0.45, 0.006, 0.4 * k - 0.006, 0.4 * k + 0.006, "locker_line")
        wall_item(p, W, D, "back", a, 0.012, 0.45, 0.006, 0.03, 1.57, "locker_line")
    p.box("book_return", 0.32, 1.4, 0.55, 0.6, 0.0, 1.1, collide=True)
    p.box("metal_dark", 0.6, 1.4, 0.012, 0.4, 0.85, 0.9)
    wall_item(p, W, D, "left", 1.4, 0.7, 0.0, 0.01, 1.3, 1.7, "sign_blue")
    wall_label(ctx, "left", 1.4, 1.5, "도서 반납함", 0.03, 0.003, 36, (0.95, 0.95, 0.92))
    wall_item(p, W, D, "left", 2.9, 0.42, 0.0, 0.004, 1.2, 1.8, "paper")
    bench(p, W - 0.3, 2.0, 1.2, along_u=False)


def annex_passage(ctx):
    """별관 1층 출입 통로: 학생 출입구는 매트·우산꽂이·안내, 반입구는 식자재 상자·손수레"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = [d for d in ctx.doors if d.kind in ("glass_entry", "fire2")]
    if not doors:
        return
    d = doors[0]
    p.box("mat_dark", d.mid, 1.0, min(W - 0.3, 1.6), 1.5, 0.0, 0.012)
    if d.kind == "glass_entry":
        p.box("bin_gray", 0.25 if d.mid > W / 2 else W - 0.25, 2.3, 0.3, 0.3, 0.0, 0.6)
        for k in range(3):
            p.box("umbrella", (0.2 if d.mid > W / 2 else W - 0.3) + 0.05 * k, 2.3, 0.035, 0.035, 0.3, 0.9 + 0.05 * k)
        p.box("wet_sign", W / 2, 7.4, 0.3, 0.05, 0.0, 0.6, yaw=15.0)
    else:
        side = "left" if ctx.kind_of("left") == "exterior" else "right"
        u = 0.3 if side == "left" else W - 0.3
        for k in range(3):
            p.box("box", u, 4.6 + 0.55 * k, 0.45, 0.5, 0.0, 0.36)
        p.box("box", u, 4.9, 0.4, 0.45, 0.36, 0.7)
        p.solid(u, 5.15, 0.5, 1.7, 0.0, 0.75)
        wall_item(p, W, D, side, 6.9, 0.5, 0.0, 0.004, 1.3, 1.65, "paper_yellow")


# ------------------------------------------------------------------ 2층: 음악실·미술실

def _board(ctx, a, width, mat="chalkboard", h0=0.9, h1=2.1):
    """복도 쪽(앞) 벽의 칠판·화이트보드: 틀 + 판 + 받침"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "front", a, width + 0.1, 0.0, 0.03, h0 - 0.03, h1 + 0.03, "frame_alu")
    wall_item(p, W, D, "front", a, width, 0.03, 0.012, h0, h1, mat)
    wall_item(p, W, D, "front", a, width, 0.03, 0.09, h0 - 0.05, h0 - 0.02, "frame_alu")


def _clock(ctx, side, a, h=2.45):
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, side, a, 0.32, 0.0, 0.05, h, h + 0.32, "clock_rim")
    wall_item(p, W, D, side, a, 0.26, 0.05, 0.01, h + 0.03, h + 0.29, "clock_face")


def music_room(ctx):
    """음악실: 오선 칠판, 그랜드 피아노, 교사용 책상, 의자·악보대 24석(가운데 1.2m 통로), 창가 소형 합주 무대,
    양쪽 벽 악기 보관대와 흡음 패널, 두꺼운 커튼"""
    p, W, D = ctx.p, ctx.W, ctx.D
    bc = 4.15
    _board(ctx, bc, 3.2)
    for g in range(2):                                             # 오선 두 단
        for k in range(5):
            h = 1.2 + 0.5 * g + 0.045 * k
            wall_item(p, W, D, "front", bc, 3.0, 0.042, 0.003, h, h + 0.006, "chalk")
    for u in (2.15, 6.15):
        wall_item(p, W, D, "front", u, 0.3, 0.0, 0.22, 2.3, 2.75, "speaker")
    _clock(ctx, "front", 6.55)
    grand_piano(p, 1.9, 2.45)
    p.box("wood_dark", 2.6, 2.3, 0.12, 0.12, 0.95, 1.15)           # 메트로놈
    office_desk(p, 5.3, 2.2, facing=1, w=1.3, items=("papers", "mug"), key="mt")
    for r, v in enumerate((4.7, 5.7, 6.7, 7.7)):
        for u in (2.1, 3.1, 4.1, 5.95, 6.95, 7.95):
            music_seat(p, u, v)
    # 창가 소형 합주 무대 (단 높이 0.2)
    p.box("riser", 5.05, 8.755, 7.3, 1.01, 0.0, 0.2, collide=True)
    for u in (2.6, 4.0, 6.1, 7.5):
        music_seat(p, u, 8.95, dh=0.2, collide=False)
    p.box("instrument_wood", 5.05, 8.9, 1.2, 0.5, 0.95, 1.0)       # 실로폰
    for du in (-0.55, 0.55):
        p.box("metal_dark", 5.05 + du, 8.9, 0.04, 0.4, 0.2, 0.95)
    p.solid(5.05, 8.755, 7.3, 1.01, 0.0, 1.2)
    # 왼쪽 벽: 기타·현악기 케이스 보관대 / 오른쪽 벽: 장구·북 보관대, 흡음 패널
    wall_item(p, W, D, "left", 5.6, 4.2, 0.0, 0.42, 0.0, 0.5, "shelf_wood", collide=True)
    wall_item(p, W, D, "left", 5.6, 4.2, 0.0, 0.42, 1.7, 1.74, "shelf_wood")
    for a in (3.52, 7.68):
        wall_item(p, W, D, "left", a, 0.04, 0.0, 0.42, 0.5, 1.7, "shelf_wood")
    for k in range(7):
        wall_item(p, W, D, "left", 3.8 + 0.6 * k, 0.36, 0.06, 0.16, 0.5, 1.5 - 0.15 * (k % 2), "case_black" if k % 3 else "instrument_wood")
    for k in range(5):
        wall_item(p, W, D, "left", 3.9 + 0.85 * k, 0.7, 0.0, 0.04, 1.95, 2.65, "acoustic_a" if k % 2 else "acoustic_b")
    wall_item(p, W, D, "right", 5.6, 4.2, 0.0, 0.5, 0.0, 0.45, "shelf_wood", collide=True)
    for k in range(4):
        a = 4.1 + 1.0 * k
        if k % 2 == 0:                                             # 장구
            wall_item(p, W, D, "right", a, 0.5, 0.08, 0.34, 0.45, 0.8, "drum_shell")
            for da in (-0.26, 0.26):
                wall_item(p, W, D, "right", a + da, 0.02, 0.05, 0.4, 0.42, 0.83, "drum_head")
        else:                                                      # 북
            wall_item(p, W, D, "right", a, 0.3, 0.06, 0.4, 0.45, 0.86, "drum_shell")
            for da in (-0.16, 0.16):
                wall_item(p, W, D, "right", a + da, 0.02, 0.04, 0.44, 0.44, 0.88, "drum_head")
    for k in range(5):
        wall_item(p, W, D, "right", 3.9 + 0.85 * k, 0.7, 0.0, 0.04, 1.3, 2.2, "acoustic_b" if k % 2 else "acoustic_a")
    curtains_full(ctx, "back")


def music_prep(ctx):
    """음악 준비실: 잠금형 고가 악기장, 악기 케이스 선반, 타악기(팀파니·큰북), 보면대 묶음, 악기 이동 카트, 첼로 케이스"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for a in (1.05, 3.6):
        cabinet(p, a, D - 0.28, 1.5, 0.5, 1.7, "cabinet_metal", 2)
        p.box("panel_red", a + 0.1, D - 0.55, 0.08, 0.02, 0.9, 1.0)
    rack(p, W, D, "left", 2.55, 2.0, 0.45, 1.8, 3, ("case_black", "instrument_wood", "case_black"), "mp1", 0.85, "shelf_wood")
    p.box("drum_shell", W - 0.45, 2.3, 0.45, 0.8, 0.35, 1.15, collide=True)
    for du in (-0.235, 0.235):
        p.box("drum_head", W - 0.45 + du, 2.3, 0.02, 0.76, 0.37, 1.13)
    p.box("metal_dark", W - 0.45, 2.3, 0.5, 0.5, 0.0, 0.35)
    for u in (W - 0.55, W - 1.35):
        round_box(p, "brass", u, 0.6, 0.7, 0.45, 0.85)
        round_box(p, "drum_head", u, 0.6, 0.66, 0.85, 0.87)
        p.box("metal_dark", u, 0.6, 0.4, 0.4, 0.0, 0.45)
        p.solid(u, 0.6, 0.66, 0.66, 0.0, 0.87)
    for k in range(6):
        p.box("metal_dark", 0.3 + 0.1 * k, 0.3, 0.03, 0.03, 0.0, 1.2)
    p.box("box", 0.55, 0.3, 0.7, 0.35, 0.0, 0.25)
    p.box("cart", 2.4, 2.6, 0.55, 0.95, 0.15, 0.2)
    p.box("cart", 2.4, 2.6, 0.55, 0.95, 0.75, 0.8)
    for du in (-0.25, 0.25):
        for dv in (-0.45, 0.45):
            p.box("metal_dark", 2.4 + du, 2.6 + dv, 0.03, 0.03, 0.0, 0.95)
    p.box("case_black", 2.4, 2.6, 0.4, 0.8, 0.8, 0.95)
    p.solid(2.4, 2.6, 0.55, 0.95, 0.0, 0.95)
    for k in range(2):
        p.box("case_black", W - 0.25, 3.3 + 0.45 * k, 0.35, 0.4, 0.0, 1.3)


def _art_table(p, u, v, i):
    """6인용 작업대 + 스툴 6개 (충돌 한 덩어리), 작업 중인 그림·물통"""
    p.box("workbench", u, v, 2.0, 1.0, 0.72, 0.78)
    for du in (-0.9, 0.9):
        for dv in (-0.4, 0.4):
            p.box("desk_frame", u + du, v + dv, 0.06, 0.06, 0.0, 0.72)
    for k in range(3):
        for s in (-1, 1):
            stool(p, u - 0.65 + 0.65 * k, v + s * 0.78)
    mats = ("paper", "art_blue", "paper_yellow", "art_red", "paper_pink", "art_green")
    for k in range(3):
        if (i + k) % 3 != 2:
            p.box(mats[(i * 2 + k) % 6], u - 0.6 + 0.6 * k, v - 0.2 + 0.2 * (k % 2), 0.42, 0.3, 0.78, 0.785)
    round_box(p, "bucket_blue", u + 0.75, v + 0.25, 0.16, 0.78, 0.92)
    p.solid(u, v, 2.0, 1.86, 0.0, 0.8)


def art_room(ctx):
    """미술실: 화이트보드, 교사 시범 작업대(석고상·정물), 6인용 작업대 4개와 스툴, 세척 싱크, 재료장, 작품 건조대, 이젤"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _board(ctx, 5.7, 3.0, "whiteboard")
    _clock(ctx, "front", 7.3, 2.5)
    p.box("workbench", 5.7, 2.2, 3.2, 0.75, 0.0, 0.85, collide=True)
    p.box("plaster", 4.7, 2.2, 0.28, 0.26, 0.85, 1.3)
    p.box("plaster", 4.7, 2.2, 0.2, 0.2, 1.3, 1.5)
    p.box("cloth", 5.8, 2.2, 0.7, 0.5, 0.85, 0.86)
    round_box(p, "pot", 5.7, 2.2, 0.22, 0.86, 1.1)
    p.box("art_red", 5.97, 2.15, 0.1, 0.1, 0.86, 0.95)
    p.box("art_yellow", 6.07, 2.3, 0.09, 0.09, 0.86, 0.94)
    p.box("paper", 6.75, 2.2, 0.42, 0.3, 0.85, 0.86)
    for i, (u, v) in enumerate(((2.9, 4.9), (7.35, 4.9), (2.9, 7.5), (7.35, 7.5))):
        _art_table(p, u, v, i)
    # 왼쪽 벽: 세척 싱크, 학생 작품 게시 / 오른쪽 벽: 재료장, 작품 건조대
    wall_item(p, W, D, "left", 4.3, 2.2, 0.0, 0.55, 0.0, 0.82, "stainless", collide=True)
    wall_item(p, W, D, "left", 4.3, 2.0, 0.1, 0.36, 0.82, 0.828, "stainless_dark")
    wall_item(p, W, D, "left", 4.3, 2.2, 0.0, 0.02, 0.82, 1.4, "counter_white")
    for k in range(3):
        wall_item(p, W, D, "left", 3.6 + 0.7 * k, 0.03, 0.04, 0.03, 0.828, 1.1, "steel")
        wall_item(p, W, D, "left", 3.6 + 0.7 * k, 0.03, 0.07, 0.14, 1.07, 1.1, "steel")
    wall_item(p, W, D, "left", 7.4, 2.2, 0.0, 0.02, 1.0, 2.0, "cork")
    for k, m in enumerate(("art_red", "art_yellow", "paper", "art_blue", "art_green", "paper_pink")):
        wall_item(p, W, D, "left", 6.55 + 0.34 * k, 0.28, 0.02, 0.004, 1.15 + 0.3 * (k % 2), 1.5 + 0.3 * (k % 2), m)
    wall_item(p, W, D, "right", 3.65, 1.5, 0.0, 0.5, 0.0, 1.9, "cabinet_wood", collide=True)
    for da in (-0.375, 0.0, 0.375):
        wall_item(p, W, D, "right", 3.65 + da, 0.012, 0.5, 0.006, 0.05, 1.85, "wood_dark")
    wall_item(p, W, D, "right", 5.8, 1.6, 0.0, 0.5, 0.0, 1.6, "drying_rack", collide=True)
    for k in range(5):
        wall_item(p, W, D, "right", 5.8, 1.5, 0.5, 0.012, 0.25 + 0.28 * k, 0.28 + 0.28 * k, ("art_yellow", "paper", "art_red")[k % 3])
    for u, v, yaw, m in ((0.9, 8.75, 20.0, "canvas"), (5.1, 8.85, 0.0, "art_blue"), (9.4, 8.75, -20.0, "canvas")):
        easel(p, u, v, yaw, m)
    blinds(ctx, "back", drop=0.25)


def art_prep(ctx):
    """미술 준비실: 종이 서랍장, 재료 선반(물감·점토), 잠금형 유해 재료장, 캔버스 묶음, 작업대, 이젤"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "left", 2.6, 1.6, 0.0, 0.75, 0.0, 1.0, "map_cabinet", collide=True)
    for k in range(5):
        wall_item(p, W, D, "left", 2.6, 1.5, 0.75, 0.006, 0.12 + 0.17 * k, 0.14 + 0.17 * k, "metal_dark")
    wall_item(p, W, D, "left", 2.4, 0.9, 0.1, 0.6, 1.0, 1.08, "paper")
    rack(p, W, D, "back", 1.4, 2.2, 0.45, 1.7, 4, ("art_red", "art_blue", "box", "art_yellow", "clay"), "ap1", 0.85, "shelf_wood")
    cabinet(p, 3.6, D - 0.28, 1.0, 0.5, 1.7, "safety_yellow", 2)
    p.box("panel_red", 3.6, D - 0.55, 0.3, 0.012, 1.25, 1.4)
    for k in range(5):
        p.box("canvas", W - 0.08 - 0.05 * k, 2.6, 0.03, 1.2 - 0.1 * k, 0.0, 0.9 + 0.1 * (k % 2))
    p.solid(W - 0.18, 2.6, 0.32, 1.2, 0.0, 1.0)
    p.box("workbench", 2.85, 2.6, 1.1, 0.7, 0.0, 0.8, collide=True)
    p.box("cutting_mat", 2.85, 2.6, 0.6, 0.45, 0.8, 0.81)
    p.box("metal_dark", 3.2, 2.5, 0.05, 0.3, 0.81, 0.84)
    for k in range(3):
        p.box("clay", 3.5 + 0.38 * k, 0.4, 0.34, 0.5, 0.0, 0.22 + 0.2 * (k % 2))
    easel(p, 0.6, 0.8, 30.0)


# ------------------------------------------------------------------ 2층: 과학실·컴퓨터실

SCI_ROWS = (4.1, 5.9, 7.7)       # 실험대 줄 (v)
SCI_COLS = (2.65, 7.6)           # 실험대 열 (u), 가운데 통로


def _science_common(ctx, second):
    """두 과학실 공통: 칠판, 교사 시범대(개수대), 실험대 6개(2열 3줄), 안전 게시물, 소화기"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _board(ctx, 5.1, 3.5)
    _clock(ctx, "front", 7.15, 2.5)
    p.box("office_panel", 5.1, 2.3, 4.9, 0.7, 0.0, 0.86, collide=True)
    p.box("lab_bench", 5.1, 2.3, 5.0, 0.8, 0.86, 0.91)
    p.box("stainless", 7.15, 2.3, 0.42, 0.48, 0.91, 0.916)
    p.box("drain", 7.15, 2.3, 0.34, 0.4, 0.916, 0.92)
    p.box("steel", 7.15, 2.03, 0.03, 0.03, 0.91, 1.2)
    p.box("steel", 7.15, 2.1, 0.03, 0.14, 1.17, 1.2)
    for v in SCI_ROWS:
        for u in SCI_COLS:
            lab_bench(p, u, v, 2.2, 0.9, sink=second)
    wall_item(p, W, D, "front", 2.95, 0.3, 0.0, 0.004, 1.25, 1.7, "paper_yellow")     # 실험 안전 수칙
    wall_item(p, W, D, "front", 7.7, 0.35, 0.0, 0.14, 1.3, 1.6, "first_aid")
    wall_item(p, W, D, "front", 8.05, 0.17, 0.04, 0.17, 0.0, 0.56, "extinguisher")
    blinds(ctx, "back", drop=0.3)


def science1(ctx):
    """제1과학실 (물리·지구과학): 전기 콘센트 실험대, 측정기 보관장, 광학 실험대, 장비 보관장, 지구본·천체 모형, 망원경, 별자리표"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _science_common(ctx, False)
    p.box("globe", 4.0, 2.3, 0.3, 0.3, 0.97, 1.27)                   # 시범대 위 지구본
    p.box("metal_dark", 4.0, 2.3, 0.12, 0.12, 0.91, 0.97)
    p.box("instrument_wood", 5.6, 2.3, 0.9, 0.14, 0.91, 1.05)        # 빗면 실험 장치
    p.box("panel_gray", 3.2, 2.3, 0.22, 0.16, 0.91, 1.03)            # 전원 장치
    glass_cabinet(p, W, D, "left", 4.4, 2.0, 0.45, 1.9, ("panel_gray", "microscope", "steel", "box"), "s1a", "cabinet_metal")
    wall_item(p, W, D, "left", 6.9, 1.8, 0.0, 0.5, 0.0, 0.85, "cabinet_wood", collide=True)
    wall_item(p, W, D, "left", 6.9, 1.6, 0.2, 0.06, 0.85, 0.9, "metal_dark")          # 광학대 레일
    for k in range(4):
        wall_item(p, W, D, "left", 6.3 + 0.4 * k, 0.05, 0.14, 0.18, 0.9, 1.12, "steel")
    glass_cabinet(p, W, D, "right", 4.4, 2.0, 0.45, 1.9, ("box", "steel", "globe", "panel_gray"), "s1b", "cabinet_metal")
    wall_item(p, W, D, "right", 6.6, 1.3, 0.0, 0.004, 1.2, 2.1, "poster_night")
    wall_label(ctx, "right", 6.6, 2.22, "계절별 별자리", 0.03, 0.003, 36)
    round_box(p, "globe", 3.6, D - 0.5, 0.62, 0.75, 1.35)            # 큰 천체 모형
    p.box("metal_dark", 3.6, D - 0.5, 0.1, 0.1, 0.0, 0.75)
    p.box("metal_dark", 3.6, D - 0.5, 0.5, 0.5, 0.0, 0.05)
    p.box("steel", 6.65, D - 0.5, 0.14, 0.75, 1.3, 1.44, yaw=25.0)   # 망원경
    for du, dv in ((-0.25, -0.2), (0.25, -0.2), (0.0, 0.25)):
        p.box("metal_dark", 6.65 + du, D - 0.5 + dv, 0.04, 0.04, 0.0, 1.3)


def science2(ctx):
    """제2과학실 (화학·생물): 급배수 실험대, 흄 후드, 표본장, 잠금식 약품장, 인체 해부·발성기관·골격 모형,
    비상 샤워·세안 장치(오른쪽 문에서 직선 통로), 주기율표"""
    p, W, D = ctx.p, ctx.W, ctx.D
    _science_common(ctx, True)
    for k in range(3):
        round_box(p, "jar", 3.6 + 0.3 * k, 2.3, 0.12, 0.91, 1.05 + 0.04 * k)       # 비커
    p.box("microscope", 5.9, 2.3, 0.2, 0.25, 0.91, 1.28)
    # 왼쪽 벽: 흄 후드(앞쪽), 표본장, 잠금식 약품장
    a = 2.3
    wall_item(p, W, D, "left", a, 1.6, 0.0, 0.8, 0.0, 0.9, "fume_hood", collide=True)
    wall_item(p, W, D, "left", a, 1.5, 0.05, 0.7, 0.9, 0.91, "lab_bench")
    wall_item(p, W, D, "left", a, 1.6, 0.0, 0.8, 1.75, 2.35, "fume_hood")
    for da in (-0.78, 0.78):
        wall_item(p, W, D, "left", a + da, 0.04, 0.0, 0.8, 0.9, 1.75, "fume_hood")
    wall_item(p, W, D, "left", a, 1.52, 0.0, 0.03, 0.91, 1.75, "fume_hood")
    wall_item(p, W, D, "left", a, 1.52, 0.74, 0.012, 1.3, 1.75, "glass")
    wall_item(p, W, D, "left", a, 0.3, 0.2, 0.3, 2.35, 3.5, "stainless")
    p.solid(0.4, a, 0.8, 1.6, 0.0, 2.3)
    glass_cabinet(p, W, D, "left", 4.7, 2.4, 0.45, 1.9, ("jar", "bone", "jar", "anatomy_red"), "s2a", "cabinet_wood")
    wall_item(p, W, D, "left", 6.7, 1.0, 0.0, 0.5, 0.0, 1.8, "safety_yellow", collide=True)
    wall_item(p, W, D, "left", 6.7, 0.012, 0.5, 0.006, 0.05, 1.75, "metal_dark")
    wall_item(p, W, D, "left", 6.7, 0.4, 0.5, 0.008, 1.2, 1.4, "panel_red")
    # 오른쪽 벽은 비상 샤워까지 직선 통로를 비우고 얇은 게시물만
    wall_item(p, W, D, "right", 4.8, 1.7, 0.0, 0.004, 1.15, 2.15, "periodic")
    wall_label(ctx, "right", 4.8, 2.27, "원소 주기율표", 0.03, 0.003, 36)
    wall_item(p, W, D, "right", 2.0, 0.7, 0.0, 0.2, 1.0, 1.6, "cabinet_metal")       # 보안경 보관함
    su, sv = W - 0.45, D - 0.45
    p.box("floor_mark_yellow", su, sv, 0.9, 0.9, 0.0, 0.006)
    p.box("safety_yellow", su + 0.33, sv, 0.06, 0.06, 0.0, 2.3)
    p.box("safety_yellow", su + 0.15, sv, 0.36, 0.05, 2.24, 2.3)
    round_box(p, "safety_yellow", su, sv, 0.3, 2.12, 2.22)
    p.box("metal_dark", su - 0.2, sv, 0.02, 0.02, 1.5, 2.12)
    p.box("safety_yellow", su - 0.2, sv, 0.14, 0.02, 1.4, 1.5)
    round_box(p, "safety_green", su + 0.18, sv - 0.25, 0.3, 1.0, 1.08)
    p.box("safety_yellow", su + 0.33, sv - 0.12, 0.05, 0.26, 0.96, 1.0)
    wall_item(p, W, D, "right", D - 0.45, 0.5, 0.0, 0.01, 1.85, 2.1, "sign_green")
    wall_label(ctx, "right", D - 0.45, 1.975, "비상 샤워", 0.03, 0.0028, 32, (0.95, 0.97, 0.95))
    # 창 사이 벽 앞: 인체 해부 모형, 발성기관 모형, 골격 모형
    for u, body, top in ((5.75, "anatomy_skin", "anatomy_red"), (6.4, "anatomy_red", "anatomy_skin")):
        p.box("counter_white", u, D - 0.33, 0.42, 0.42, 0.0, 0.85, collide=True)
        p.box(body, u, D - 0.33, 0.3 if u < 6 else 0.16, 0.2, 0.85, 1.3 if u < 6 else 1.1)
        p.box(top, u, D - 0.33, 0.16 if u < 6 else 0.1, 0.16, 1.3 if u < 6 else 1.1, 1.52 if u < 6 else 1.22)
    p.box("metal_dark", 6.98, D - 0.3, 0.3, 0.3, 0.0, 0.04)
    p.box("metal_dark", 6.98, D - 0.22, 0.03, 0.03, 0.04, 1.75)
    p.box("bone", 6.98, D - 0.3, 0.3, 0.14, 0.95, 1.45)
    p.box("bone", 6.98, D - 0.3, 0.16, 0.16, 1.5, 1.7)
    for du in (-0.08, 0.08):
        p.box("bone", 6.98 + du, D - 0.3, 0.05, 0.06, 0.06, 0.95)


def science_prep(ctx):
    """공동 과학 준비실 (잠금): 실험기구 유리장, 위험물 캐비닛, 폐기물 통, 시약장, 배양기, 교사용 준비대(현미경), 실험복"""
    p, W, D = ctx.p, ctx.W, ctx.D
    glass_cabinet(p, W, D, "back", 2.3, 3.6, 0.45, 1.7, ("jar", "bottle", "microscope", "paper"), "sp1", "cabinet_metal")
    wall_item(p, W, D, "left", 2.0, 1.0, 0.0, 0.5, 0.0, 1.7, "safety_yellow", collide=True)
    wall_item(p, W, D, "left", 2.0, 0.012, 0.5, 0.006, 0.05, 1.65, "metal_dark")
    wall_item(p, W, D, "left", 2.0, 0.4, 0.5, 0.008, 1.15, 1.35, "panel_red")
    for k, m in enumerate(("bin_yellow", "bucket_red")):
        p.box(m, 0.28, 3.05 + 0.45 * k, 0.36, 0.36, 0.0, 0.5)
    wall_item(p, W, D, "right", 2.1, 1.2, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "right", 2.1, 0.012, 0.45, 0.006, 0.05, 1.85, "metal_dark")
    wall_item(p, W, D, "right", 2.2, 0.08, 0.45, 0.02, 0.95, 1.05, "panel_red")
    wall_item(p, W, D, "right", 3.3, 0.6, 0.0, 0.55, 0.0, 0.9, "fridge_small", collide=True)
    wall_item(p, W, D, "right", 3.3, 0.3, 0.55, 0.008, 0.6, 0.75, "screen_on")
    p.box("office_panel", 2.5, 2.6, 1.5, 0.65, 0.0, 0.84, collide=True)
    p.box("lab_bench", 2.5, 2.6, 1.6, 0.7, 0.84, 0.89)
    for k in range(3):
        p.box("microscope", 2.0 + 0.45 * k, 2.55, 0.18, 0.22, 0.89, 1.24)
    p.box("paper", 3.05, 2.75, 0.3, 0.2, 0.89, 0.895)
    wall_item(p, W, D, "right", 0.75, 0.9, 0.0, 0.03, 1.6, 1.65, "steel")
    for k in range(3):
        wall_item(p, W, D, "right", 0.45 + 0.3 * k, 0.26, 0.03, 0.05, 0.8, 1.6, "apron")


COM_ROWS = (3.3, 4.4, 5.5)        # 컴퓨터 책상 줄 (책상 중심 v), 그 뒤 1.2m 가로 통로
COM_LAST = 7.8
COM_LEFT, COM_RIGHT = (1.55, 2.55, 3.55), (5.85, 6.85, 7.85)


def computer_room(ctx):
    """컴퓨터실: 스크린과 교사용 제어석, 학생용 컴퓨터 26대(가운데 1.3m·가로 1.2m 통로, 의자 고정), 프로젝터,
    바닥 케이블 덕트, 프린터, 냉방기, 이용 수칙"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "front", 6.2, 2.5, 0.0, 0.1, 2.2, 2.32, "frame_alu")
    wall_item(p, W, D, "front", 6.2, 2.4, 0.03, 0.01, 0.75, 2.2, "screen_white")
    p.box("pc_tower", 6.2, 3.3, 0.35, 0.3, 2.75, 2.9)
    p.box("metal_dark", 6.2, 3.3, 0.04, 0.04, 2.9, 3.58)
    # 교사용 제어석 (학생을 바라봄)
    p.box("office_top", 5.05, 1.75, 4.3, 0.7, 0.71, 0.74)
    p.box("office_panel", 5.05, 2.07, 4.2, 0.03, 0.0, 0.71)
    for u in (2.92, 7.18):
        p.box("office_panel", u, 1.72, 0.03, 0.62, 0.0, 0.71)
    p.solid(5.05, 1.75, 4.3, 0.7, 0.0, 0.76)
    for u in (4.3, 5.4):
        p.box("monitor", u, 1.9, 0.52, 0.04, 0.8, 1.12)
        p.box("metal_dark", u, 1.88, 0.1, 0.08, 0.74, 0.8)
        p.box("keyboard", u, 1.62, 0.42, 0.14, 0.74, 0.755)
    p.box("console", 6.5, 1.75, 0.6, 0.35, 0.74, 0.86)
    p.box("chair_office", 4.85, 0.98, 0.46, 0.44, 0.44, 0.5)
    p.box("chair_office", 4.85, 0.76, 0.44, 0.06, 0.5, 0.95)
    p.box("metal_dark", 4.85, 0.98, 0.06, 0.06, 0.0, 0.44)
    # 학생석: 세 줄은 3 + 3, 가로 통로 뒤 마지막 줄은 4 + 4 (모두 26대)
    for v in COM_ROWS:
        for cols in (COM_LEFT, COM_RIGHT):
            for i, u in enumerate(cols):
                pc_desk(p, u, v, 1.0, 0.55, end=(i == 2))
            p.solid(cols[1], v + 0.26, 3.0, 1.07, 0.0, 0.9)
    last = ((0.55,) + COM_LEFT, COM_RIGHT + (8.85,))
    for cols in last:
        for i, u in enumerate(cols):
            pc_desk(p, u, COM_LAST, 1.0, 0.55, end=(i == 3))
        p.solid((cols[0] + cols[-1]) / 2, COM_LAST + 0.26, 4.0, 1.07, 0.0, 0.9)
    # 바닥 케이블 덕트: 왼쪽 벽을 따라 한 줄 + 줄마다 가지
    p.box("cable_duct", 0.1, 5.6, 0.12, 6.8, 0.0, 0.02)
    for v in COM_ROWS + (COM_LAST,):
        p.box("cable_duct", 0.61, v - 0.34, 0.88, 0.1, 0.0, 0.018)
        p.box("cable_duct", 4.7, v - 0.34, 1.28, 0.1, 0.0, 0.018)
    # 오른쪽 벽: 프린터 탁자, 이용 수칙 / 구석 냉방기
    wall_item(p, W, D, "right", 3.9, 1.4, 0.0, 0.6, 0.0, 0.72, "office_drawer", collide=True)
    wall_item(p, W, D, "right", 3.6, 0.6, 0.06, 0.48, 0.72, 1.02, "copier")
    wall_item(p, W, D, "right", 4.3, 0.36, 0.1, 0.4, 0.72, 0.9, "box")
    wall_item(p, W, D, "right", 5.6, 0.6, 0.0, 0.004, 1.2, 1.95, "paper_blue")
    wall_label(ctx, "right", 5.6, 2.07, "컴퓨터실 이용 수칙", 0.03, 0.0028, 34)
    p.box("aircon", W - 0.3, D - 0.33, 0.5, 0.36, 0.0, 1.8, collide=True)
    blinds(ctx, "back", drop=0.5)


def computer_prep(ctx):
    """컴퓨터 기자재실: 서버 랙 2대, UPS, 독립 냉방기, 예비 본체 선반, 케이블 작업대, 충전함"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(2):
        a = 0.6 + 0.72 * i
        wall_item(p, W, D, "back", a, 0.62, 0.0, 0.9, 0.0, 2.0, "rack", collide=True)
        for k in range(6):
            wall_item(p, W, D, "back", a, 0.5, 0.9, 0.006, 0.3 + 0.27 * k, 0.42 + 0.27 * k, "stainless_dark")
            wall_item(p, W, D, "back", a - 0.18, 0.03, 0.906, 0.004, 0.34 + 0.27 * k, 0.36 + 0.27 * k, "led_green")
    wall_item(p, W, D, "back", 2.1, 0.5, 0.0, 0.7, 0.0, 0.7, "office_drawer", collide=True)
    wall_item(p, W, D, "back", 2.1, 0.06, 0.7, 0.004, 0.5, 0.56, "led_green")
    wall_item(p, W, D, "back", W - 0.45, 0.6, 0.0, 0.4, 0.0, 1.85, "aircon", collide=True)
    rack(p, W, D, "right", 2.5, 2.0, 0.5, 1.8, 3, ("pc_tower", "monitor_old", "box"), "cp1")
    wall_item(p, W, D, "left", 2.4, 1.6, 0.0, 0.65, 0.72, 0.76, "office_top")
    wall_item(p, W, D, "left", 2.4, 1.5, 0.03, 0.55, 0.0, 0.72, "office_panel", collide=True)
    for k in range(2):
        wall_item(p, W, D, "left", 1.95 + 0.5 * k, 0.3, 0.15, 0.3, 0.76, 0.88, "cable_reel")
    wall_item(p, W, D, "left", 3.0, 0.45, 0.08, 0.04, 0.84, 1.14, "monitor")
    wall_item(p, W, D, "front", 3.9, 0.9, 0.0, 0.5, 0.0, 1.2, "charge_box", collide=True)
    wall_item(p, W, D, "front", 3.9, 0.012, 0.5, 0.006, 0.05, 1.15, "metal_dark")


# ------------------------------------------------------------------ 3층: 도서관

LIB_R1, LIB_R2 = 1.575, 3.425                      # 서가 두 줄의 중심 v (두께 0.55, 사이 1.3m)
LIB_ROW1 = ((10.9, 13.9), (15.1, 18.1), (19.3, 21.1), (23.5, 26.5), (27.7, 30.7))   # 가운데 하나는 짧게 (순환 동선)
LIB_ROW2 = ((10.9, 13.9), (15.1, 18.1), (23.5, 26.5), (27.7, 30.7))
LIB_TABLES = (12.4, 17.6, 25.0, 30.2)              # 6인용 열람 테이블 중심 u
LIB_TABLE_V = 6.0


def _window_seat(p, u, D):
    """창가 1인석: 창을 보는 책상 + 낮은 옆 칸막이 + 의자 + 스탠드 (충돌 한 덩어리)"""
    v = D - 0.33
    p.box("desk_top", u, v, 0.95, 0.5, 0.71, 0.74)
    for du in (-0.46, 0.46):
        p.box("carrel_panel", u + du, v, 0.03, 0.5, 0.0, 0.84)
    cv = v - 0.55
    p.box("chair_seat", u, cv, 0.4, 0.4, 0.43, 0.46)
    p.box("chair_seat", u, cv - 0.19, 0.4, 0.03, 0.46, 0.85)
    p.box("chair_frame", u, cv, 0.05, 0.05, 0.0, 0.43)
    p.box("lamp", u + 0.3, v + 0.05, 0.1, 0.1, 0.74, 1.05)
    p.solid(u, v - 0.3, 0.98, 1.1, 0.0, 0.8)


def library(ctx):
    """도서관: 서쪽 정기간행물·소파, 가운데 양면 서가 11개(주 통로는 끝까지 직선), 남측 6인용 열람 테이블 4개,
    창가 1인석 10개, 동쪽 출입구의 도난 방지 게이트·대출 반납 데스크·예약 선반·신간 진열대·정보검색 2대"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i, (a0, a1) in enumerate(LIB_ROW1):
        book_stack(p, a0, a1, LIB_R1, "r1%d" % i)
    for i, (a0, a1) in enumerate(LIB_ROW2):
        book_stack(p, a0, a1, LIB_R2, "r2%d" % i)
    book_stack(p, 1.3, 3.7, 32.2, "v1", along="v")
    book_stack(p, 5.0, 7.0, 21.3, "v2", along="v")
    for i, u in enumerate(LIB_TABLES):
        table(p, u, LIB_TABLE_V, 2.4, 1.0, 3, along="u", key="lt%d" % i)
        p.solid(u, LIB_TABLE_V, 2.4, 2.0, 0.0, 0.8)
        if i % 2 == 0:
            p.box("book_b", u - 0.5, LIB_TABLE_V + 0.1, 0.24, 0.18, 0.75, 0.8)
            p.box("paper", u + 0.4, LIB_TABLE_V - 0.15, 0.3, 0.21, 0.75, 0.755)
    for i in range(10):
        _window_seat(p, 3.0 + 3.45 * i, D)
    # 추천 도서 진열 탁자, 북트럭, 발받침 (서가 사이 빈 자리)
    p.box("table_top", 21.9, 3.3, 1.2, 0.7, 0.72, 0.76)
    p.box("shelf_wood", 21.9, 3.3, 1.1, 0.6, 0.0, 0.72, collide=True)
    for k in range(4):
        p.box(("book_a", "book_c", "book_b", "book_a")[k], 21.5 + 0.27 * k, 3.3, 0.18, 0.04, 0.76, 1.02)
    book_cart(p, 21.75, 1.6, along="u", key="lc1")
    p.box("stool_seat", 15.3, 2.08, 0.4, 0.35, 0.0, 0.3)
    _lib_periodicals(ctx)
    _lib_entrance(ctx)
    # 복도 쪽 벽: 정숙 안내, 시계 / 창 블라인드
    wall_item(p, W, D, "front", 20.15, 0.5, 0.0, 0.01, 1.5, 1.8, "sign_blue")
    wall_label(ctx, "front", 20.15, 1.65, "정 숙", 0.03, 0.0035, 40, (0.95, 0.95, 0.92))
    _clock(ctx, "front", 24.4)
    blinds(ctx, "back", drop=0.25)


def _lib_periodicals(ctx):
    """서쪽 구역: 잡지 진열대, 신문 걸이, 낮은 소파 3개, 낮은 서가, 오래된 졸업사진, 구역 경계의 낮은 추천 서가"""
    p, W, D = ctx.p, ctx.W, ctx.D
    p.box("shelf_wood", 3.9, 2.15, 3.0, 0.5, 0.0, 0.45, collide=True)
    p.box("shelf_wood", 3.9, 2.15, 3.0, 0.06, 0.45, 1.3)
    for s in (-1, 1):
        for r in range(2):
            for k in range(8):
                m = ("magazine_a", "magazine_b", "magazine_c", "paper")[(k + r + (s > 0)) % 4]
                p.box(m, 2.58 + 0.38 * k, 2.15 + s * 0.06, 0.3, 0.03, 0.5 + 0.4 * r, 0.82 + 0.4 * r)
    p.solid(3.9, 2.15, 3.0, 0.5, 0.0, 1.3)
    p.box("shelf_wood", 7.4, 2.15, 0.9, 0.45, 0.0, 1.1, collide=True)
    for k in range(4):
        p.box("paper", 7.1 + 0.2 * k, 2.15, 0.02, 0.5, 0.45, 1.25)
    for i, u in enumerate((2.3, 4.3, 6.3)):
        sofa(p, u, 4.75, 1.5, facing=-1, along="u", mat=("sofa_blue", "sofa_green", "sofa_blue")[i])
    p.box("table_low", 4.3, 3.7, 1.0, 0.5, 0.0, 0.4, collide=True)
    p.box("magazine_b", 4.1, 3.7, 0.22, 0.3, 0.4, 0.41)
    shelf_along(p, W, D, "left", 5.0, 3.6, 0.35, 1.1, 2, 0.8, "shelf_wood", "lbk", ("magazine_c", "book_c", "paper", "book_old"))
    for k in range(5):
        wall_item(p, W, D, "left", 3.6 + 0.7 * k, 0.5, 0.0, 0.03, 1.45, 1.85, "frame_wood")
        wall_item(p, W, D, "left", 3.6 + 0.7 * k, 0.42, 0.03, 0.004, 1.49, 1.81, "photo")
    plant(p, 0.45, D - 0.45, 0.0, 0.3)
    book_stack(p, 1.6, 3.6, 9.6, "dv1", along="v", h=1.1, t=0.4)
    book_stack(p, 5.1, 6.9, 9.6, "dv2", along="v", h=1.1, t=0.4)


def _lib_entrance(ctx):
    """동쪽 출입 구역: 도난 방지 게이트, 대출·반납 데스크(앞 1.5m 대기 공간), 예약 선반, 반납함, 가방 사물함,
    신간 진열대, 정보검색 2대와 프린터, 신간 안내판"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = [d for d in ctx.doors_on("front") if d.mid > W - 6.0]
    dm = doors[0].mid if doors else W - 1.85
    for u in (dm - 0.65, dm + 0.65):
        p.box("gate_panel", u, 1.9, 0.08, 0.9, 0.0, 1.55, collide=True)
        p.box("gate_stripe", u, 1.9, 0.09, 0.5, 0.55, 1.15)
    # 대출·반납 데스크 (사서는 복도 벽 쪽에 앉는다)
    du0, du1 = dm - 4.45, dm - 1.15
    dc = (du0 + du1) / 2
    p.box("counter_wood", dc, 1.6, du1 - du0, 0.7, 0.0, 0.74, collide=True)
    p.box("counter_top", dc, 1.6, du1 - du0 + 0.04, 0.74, 0.74, 0.78)
    p.box("counter_wood", dc, 1.87, du1 - du0, 0.2, 0.78, 1.06)
    p.box("counter_top", dc, 1.87, du1 - du0 + 0.04, 0.26, 1.06, 1.09)
    for k, u in enumerate((dc - 0.9, dc + 0.8)):
        p.box("monitor", u, 1.5, 0.5, 0.04, 0.84, 1.16)
        p.box("metal_dark", u, 1.52, 0.1, 0.08, 0.78, 0.84)
        p.box("keyboard", u, 1.38, 0.42, 0.14, 0.78, 0.795)
        p.box("chair_office", u, 0.85, 0.46, 0.44, 0.44, 0.5)
        p.box("chair_office", u, 0.63, 0.44, 0.06, 0.5, 0.95)
        p.box("metal_dark", u, 0.85, 0.06, 0.06, 0.0, 0.44)
    for k in range(3):
        p.box(("book_a", "book_b", "book_c")[k], dc + 0.1, 1.5, 0.26, 0.19, 0.78 + 0.035 * k, 0.815 + 0.035 * k)
    p.box("sign_blue", dc, 1.978, 1.5, 0.014, 0.8, 1.03)                                           # 흰 글자가 읽히게 짙은 판을 댄다
    x, z = ctx.frame.pt(dc, 1.995)
    label(ctx.sw, ctx.container, (x, ctx.y + 0.915, z), "대출 · 반납", 0.0045, 44, (0.96, 0.96, 0.92), facing_rows(ctx.frame, "back"))
    shelf_along(p, W, D, "front", dm - 3.1, 2.4, 0.35, 1.2, 3, 0.7, "shelf_wood", "rsv")          # 예약 도서 선반
    book_cart(p, dm - 6.95, 2.2, along="v", key="lc2")
    p.box("book_return", W - 0.3, 1.9, 0.5, 0.6, 0.0, 1.05, collide=True)                          # 반납함
    p.box("metal_dark", W - 0.56, 1.9, 0.012, 0.4, 0.8, 0.85)
    wall_item(p, W, D, "right", 3.2, 1.4, 0.0, 0.45, 0.0, 1.25, "locker_gray", collide=True)       # 가방 사물함
    for k in range(1, 4):
        wall_item(p, W, D, "right", 2.5 + 0.35 * k, 0.012, 0.45, 0.006, 0.03, 1.22, "locker_line")
    wall_item(p, W, D, "right", 3.2, 1.36, 0.45, 0.006, 0.62, 0.632, "locker_line")
    # 신간 진열대, 정보검색 2대, 프린터
    nu = dm - 5.75
    p.box("shelf_wood", nu, 2.98, 1.4, 0.55, 0.0, 0.9, collide=True)
    p.box("shelf_wood", nu, 2.74, 1.4, 0.06, 0.9, 1.35)
    for k in range(4):
        p.box(("book_a", "magazine_b", "book_c", "magazine_a")[k], nu - 0.5 + 0.33 * k, 2.8, 0.24, 0.03, 0.95, 1.3)
        p.box(("book_b", "book_a", "magazine_c", "book_c")[k], nu - 0.5 + 0.33 * k, 3.0, 0.24, 0.3, 0.9, 0.94)
    for k, u in enumerate((dm - 5.25, dm - 3.65)):
        p.box("office_panel", u, 5.9, 0.9, 0.55, 0.0, 1.0, collide=True)
        p.box("office_top", u, 5.9, 1.0, 0.6, 1.0, 1.04)
        p.box("monitor", u, 5.75, 0.5, 0.04, 1.1, 1.42)
        p.box("metal_dark", u, 5.77, 0.1, 0.08, 1.04, 1.1)
        p.box("keyboard", u, 6.02, 0.42, 0.14, 1.04, 1.055)
    p.box("office_drawer", dm - 1.95, 5.9, 0.6, 0.6, 0.0, 0.7, collide=True)
    p.box("copier", dm - 1.95, 5.9, 0.5, 0.45, 0.7, 1.0)
    bu = dm - 6.05
    wall_item(p, W, D, "front", bu, 1.5, 0.0, 0.02, 1.0, 1.9, "cork")
    for k, m in enumerate(("book_a", "magazine_b", "book_c", "paper")):
        wall_item(p, W, D, "front", bu - 0.5 + 0.34 * k, 0.26, 0.02, 0.004, 1.2, 1.56, m)
    wall_label(ctx, "front", bu, 1.75, "이달의 신간", 0.03, 0.003, 36)


def group_study(ctx):
    """그룹학습실: 이동식 테이블 4개와 의자 16개, 화이트보드, 대형 디스플레이와 장식장(HDMI), 발표용 이동식 책상"""
    p, W, D = ctx.p, ctx.W, ctx.D
    whiteboard_wall(p, W, D, "front", 5.55, 1.7, 0.9, 2.0)
    wall_item(p, W, D, "front", 7.5, 1.8, 0.0, 0.06, 1.05, 2.1, "tv")
    wall_item(p, W, D, "front", 7.5, 1.4, 0.0, 0.4, 0.0, 0.5, "cabinet_wood", collide=True)
    wall_item(p, W, D, "front", 7.5, 0.12, 0.4, 0.01, 0.3, 0.38, "metal_dark")
    p.box("lectern", 5.3, 1.5, 0.6, 0.45, 0.0, 1.05, collide=True)
    p.box("lectern_top", 5.3, 1.5, 0.66, 0.5, 1.05, 1.09)
    for i, (u, v) in enumerate(((3.2, 3.7), (7.0, 3.7), (3.2, 6.7), (7.0, 6.7))):
        table(p, u, v, 1.6, 0.8, 2, along="u", key="gs%d" % i)
        p.solid(u, v, 1.6, 1.8, 0.0, 0.8)
        if i % 2 == 0:
            p.box("paper", u - 0.3, v, 0.3, 0.21, 0.75, 0.755)
            p.box("book_b", u + 0.35, v + 0.1, 0.24, 0.18, 0.75, 0.79)
    plant(p, W - 0.45, D - 0.45, 0.0, 0.3)
    _clock(ctx, "front", 1.0)
    blinds(ctx, "back", drop=0.3)
    blinds(ctx, "right", drop=0.3)


def librarian_office(ctx):
    """사서실: 책상 2개(창 쪽), 문서장, CCTV 모니터, 작은 회의 테이블"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i, u in enumerate((1.05, 2.55)):
        office_desk(p, u, 3.7, facing=1, w=1.3, items=("monitor", "papers", "mug") if i == 0 else ("monitor", "exam"), key="lo%d" % i)
    table(p, 3.65, 2.0, 0.8, 0.9, 1, along="v", key="lm")
    wall_item(p, W, D, "left", 2.1, 1.2, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "left", 2.1, 0.012, 0.45, 0.006, 0.05, 1.85, "metal_dark")
    wall_item(p, W, D, "left", 3.2, 0.72, 0.0, 0.05, 1.35, 1.82, "monitor")
    for k in range(4):
        wall_item(p, W, D, "left", 3.03 + 0.34 * (k % 2), 0.3, 0.05, 0.004, 1.4 + 0.21 * (k // 2), 1.58 + 0.21 * (k // 2), "screen_on")
    wall_item(p, W, D, "right", 3.3, 0.9, 0.0, 0.3, 1.2, 1.9, "mailbox")
    blinds(ctx, "back", drop=0.4)


def book_work(ctx):
    """도서 정리실: 분류 작업대(라벨 프린터·수리 도구), 반납 카트 2대, 수리 대기 서가, 신간 상자, 창 아래 수납장"""
    p, W, D = ctx.p, ctx.W, ctx.D
    p.box("workbench", 2.45, 2.75, 1.9, 0.9, 0.0, 0.8, collide=True)
    for k in range(4):
        p.box(("book_a", "book_b", "book_c", "book_old")[k], 1.8 + 0.4 * k, 2.65, 0.3, 0.22, 0.8, 0.86 + 0.05 * (k % 3))
    p.box("copier", 3.1, 2.95, 0.3, 0.25, 0.8, 0.98)
    p.box("tape", 2.2, 3.0, 0.1, 0.1, 0.8, 0.85)
    for i, v in enumerate((1.75, 2.9)):
        book_cart(p, 0.4, v, along="v", key="bw%d" % i)
    shelf_along(p, W, D, "right", 2.7, 2.2, 0.35, 1.8, 4, 0.6, key="bws")
    wall_item(p, W, D, "back", W / 2, W - 1.0, 0.0, 0.4, 0.0, 0.8, "cabinet_wood", collide=True)
    for k in range(4):
        p.box("box", 3.3 + 0.5 * (k % 2), 0.45, 0.45, 0.4, 0.36 * (k // 2), 0.36 * (k // 2 + 1))
    p.solid(3.55, 0.45, 0.95, 0.4, 0.0, 0.72)
    blinds(ctx, "back", drop=0.4)
    # 본관 지하 구 도서관이 침수됐을 때 건져 온 책: 창 아래 수납장 위에 펼쳐 말리는 중 (복원 대기)
    for k in range(5):
        u = 1.1 + 0.62 * k
        p.box("tray", u, D - 0.2, 0.5, 0.32, 0.8, 0.83)
        p.box("book_wet", u, D - 0.2, 0.36, 0.26, 0.83, 0.87 + 0.02 * (k % 2))
    p.box("paper", 0.66, D - 0.3, 0.36, 0.02, 0.82, 1.1)
    x, z = ctx.frame.pt(0.66, D - 0.315)
    label(ctx.sw, ctx.container, (x, ctx.y + 0.98, z), "침수 도서" + chr(10) + "복원 대기", 0.002, 32, (0.14, 0.14, 0.18),
          facing_rows(ctx.frame, "front"))


def stacks(ctx):
    """보존서고 (잠금): 이동식 밀집 서가 4련과 바닥 레일, 잠금 캐비닛, 시청각 자료장, 열람 책상(옛 졸업앨범), 제습기, 연감 상자"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(4):
        u = 0.45 + 0.47 * i
        p.box("mobile_shelf", u, 3.05, 0.45, 2.5, 0.0, 2.0)
        p.box("label_white", u, 1.79, 0.2, 0.012, 1.45, 1.6)
        p.box("mobile_wheel", u, 1.76, 0.22, 0.05, 0.95, 1.17)
    p.solid(1.155, 3.05, 1.9, 2.5, 0.0, 2.0)
    for k, v in enumerate((2.2, 3.05, 3.9)):
        p.box("drain_grate", 2.9, v, 1.5, 0.05, 0.0, 0.012)
    wall_item(p, W, D, "left", 0.85, 1.1, 0.0, 0.5, 0.0, 1.9, "cabinet_metal", collide=True)
    wall_item(p, W, D, "left", 0.85, 0.012, 0.5, 0.006, 0.05, 1.85, "metal_dark")
    wall_item(p, W, D, "left", 0.95, 0.08, 0.5, 0.02, 0.95, 1.05, "panel_red")
    wall_item(p, W, D, "right", 2.2, 1.2, 0.0, 0.5, 0.0, 1.3, "drawer_cabinet", collide=True)
    for k in range(4):
        wall_item(p, W, D, "right", 2.2, 1.1, 0.5, 0.006, 0.2 + 0.28 * k, 0.22 + 0.28 * k, "metal_dark")
    for k in range(3):
        wall_item(p, W, D, "right", 1.85 + 0.3 * k, 0.2, 0.1, 0.14, 1.3, 1.5, "case_black")
    office_desk(p, 4.4, 3.6, facing=1, w=1.3, items=("papers",), key="st")
    p.box("book_old", 4.2, 3.6, 0.42, 0.3, 0.74, 0.77)
    p.box("lamp", 4.9, 3.75, 0.12, 0.12, 0.74, 1.08)
    p.box("dehumidifier", W - 0.45, 0.5, 0.4, 0.3, 0.0, 0.6)
    for k in range(3):
        p.box("box", 2.75 + 0.02 * k, D - 0.35, 0.5, 0.4, 0.36 * k, 0.36 * (k + 1) - 0.02)
    p.solid(2.75, D - 0.35, 0.5, 0.4, 0.0, 1.06)


def copy_room(ctx):
    """복사·정보검색실: 검색용 컴퓨터 2대와 스캐너(왼쪽), 복사기·프린터·출력 대기 선반(오른쪽), 문서 세단기·용지 상자"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "left", 2.6, 2.2, 0.0, 0.6, 0.71, 0.74, "office_top")
    wall_item(p, W, D, "left", 2.6, 2.1, 0.03, 0.5, 0.0, 0.71, "office_panel", collide=True)
    for k in range(2):
        v = 2.05 + 1.0 * k
        wall_item(p, W, D, "left", v, 0.5, 0.08, 0.04, 0.8, 1.1, "monitor")
        wall_item(p, W, D, "left", v, 0.4, 0.32, 0.14, 0.74, 0.755, "keyboard")
        p.box("chair_office", 0.95, v, 0.44, 0.44, 0.44, 0.5)
        p.box("chair_office", 1.17, v, 0.06, 0.42, 0.5, 0.92)
        p.box("metal_dark", 0.95, v, 0.06, 0.06, 0.0, 0.44)
    wall_item(p, W, D, "left", 3.45, 0.4, 0.1, 0.3, 0.74, 0.84, "scanner")
    wall_item(p, W, D, "right", 1.9, 0.75, 0.0, 0.6, 0.0, 1.15, "copier", collide=True)
    wall_item(p, W, D, "right", 2.85, 0.7, 0.0, 0.55, 0.0, 0.7, "office_drawer", collide=True)
    wall_item(p, W, D, "right", 2.85, 0.5, 0.05, 0.45, 0.7, 1.0, "copier")
    wall_item(p, W, D, "right", 2.4, 1.4, 0.0, 0.3, 1.5, 1.9, "mailbox")
    p.box("shredder", W - 0.35, D - 0.4, 0.45, 0.4, 0.0, 0.75)
    for k in range(2):
        p.box("box", 0.4 + 0.5 * k, D - 0.35, 0.45, 0.4, 0.0, 0.36)
    blinds(ctx, "back", drop=0.4)


# ------------------------------------------------------------------ 복도 고정 소품 (rooms_corridor.corridor의 pre 콜백)

def _bridge_end(ctx, text):
    """구름다리 방화문이 있는 복도 끝: 문 위 방향 표지, 비상구 유도등, 출입통제 단말, 미끄럼 주의 매트. 2m x 2m는 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = [d for d in ctx.doors if d.kind == "fire2" and d.side in ("front", "back")]
    if not doors:
        return
    d = doors[0]
    side = d.side
    wall_item(p, W, D, side, d.mid, 1.7, 0.0, 0.03, 2.4, 2.72, "sign_blue")
    wall_label(ctx, side, d.mid, 2.56, text, 0.05, 0.0035, 40, (0.95, 0.96, 0.98))
    wall_item(p, W, D, side, d.mid, 0.5, 0.0, 0.06, 2.9, 3.1, "sign_green")
    wall_item(p, W, D, side, d.a1 + 0.2, 0.12, 0.0, 0.04, 1.1, 1.32, "terminal")
    v = 1.1 if side == "front" else D - 1.1
    p.box("mat_dark", d.mid, v, 1.7, 1.3, 0.0, 0.012)


def annex_corridor_pre(level_name):
    """별관 복도 층별 고정 소품. 좌표: v = 북 -> 남, 왼쪽 = 서쪽(지원실) 벽, 오른쪽 = 동쪽(급식실·특별교실) 벽"""
    def pre(ctx, walls):
        p, W, D = ctx.p, ctx.W, ctx.D
        if level_name == "1F":
            # 자판기 2대: 매점 창고 앞 벽면 (창고 문과 매점 문 사이)
            store = [d for d in ctx.doors if d.door.room == "매점 창고" and d.side == "left"]
            if store:
                c = walls["left"].find(store[0].a1 + 0.85, 1.5, span=1.5)
                if c is not None:
                    vending(p, W, D, "left", c - 0.37, "vending_red")
                    vending(p, W, D, "left", c + 0.37, "vending_blue")
                    walls["left"].block(c - 0.8, c + 0.8)
            caf = [d for d in ctx.doors if d.door.room == "급식실" and d.side == "right"]
            if caf:                                           # 급식실 문 옆 분리수거함
                c = walls["right"].find(caf[0].a0 - 1.0, 1.3, span=2.0)
                if c is not None:
                    for k, m in enumerate(("bin_blue", "bin_yellow", "bin_gray")):
                        wall_item(p, W, D, "right", c - 0.4 + 0.4 * k, 0.34, 0.02, 0.34, 0.0, 0.58, m)
                    walls["right"].block(c - 0.65, c + 0.65)
        else:
            # 가운데: 음수대와 분리수거함 (동쪽 벽)
            c = walls["right"].find(D * 0.38, 1.9, span=5.0)
            if c is not None:
                wall_item(p, W, D, "right", c - 0.65, 0.45, 0.0, 0.4, 0.0, 1.05, "purifier", collide=True)
                for k, m in enumerate(("bin_blue", "bin_yellow", "bin_gray")):
                    wall_item(p, W, D, "right", c - 0.1 + 0.4 * k, 0.34, 0.02, 0.34, 0.0, 0.58, m)
                walls["right"].block(c - 1.0, c + 1.0)
        # 벤치 2개 (동쪽 벽)
        for t in (0.3, 0.62):
            c = walls["right"].find(D * t, 1.9, span=4.0)
            if c is not None:
                bench(p, W - 0.3, c, 1.7, along_u=False)
                walls["right"].block(c - 1.0, c + 1.0)
        if level_name == "3F":
            _bridge_end(ctx, "구름다리 · 본관 2층")
    return pre


def main_corridor_pre(level_name):
    def pre(ctx, walls):
        if level_name == "2F":
            _bridge_end(ctx, "구름다리 · 별관 3층")
    return pre
