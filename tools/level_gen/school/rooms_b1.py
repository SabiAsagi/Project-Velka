# -*- coding: utf-8 -*-
"""본관 지하 1층 (학교_맵_상세.md 지하 1층 + 가이드라인 7장). 회색 콘크리트 바닥, 노출 배관, 도장 금속문.
좌표: 문(복도) 쪽 벽 = 앞(v=0)."""
from props_base import wall_item, shelf_unit, shelf_along, cabinet, bins, label, facing_rows
from props_more import office_desk, table
from props_annex import wall_label


def pipes(ctx, sides=("front", "back"), h=3.25):
    """천장 가까이 벽을 따라가는 노출 배관 두세 줄"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for side in sides:
        L = W if side in ("front", "back") else D
        for k, (off, dh, mat) in enumerate(((0.12, 0.0, "pipe"), (0.3, -0.18, "pipe_red"), (0.18, -0.36, "pipe"))):
            wall_item(p, W, D, side, L / 2, L - 0.1, off, 0.12, h + dh - 0.12, h + dh, mat)


def _flood_shelf(p, u, v, length, key, state="wet"):
    """침수된 양면 서가 (v 방향으로 길게). 물이 찼던 아래 두 칸은 비었고 판이 검게 젖어 있다.
    state: wet(윗칸에만 책이 남음) / tarp(방수포를 덮음) / empty(책을 모두 뺀 빈 서가)"""
    p.box("shelf_wet", u, v, 0.05, length, 0.0, 0.79)
    p.box("shelf_old", u, v, 0.05, length, 0.79, 2.0)
    for dv in (-(length / 2 - 0.02), length / 2 - 0.02):
        p.box("shelf_wet", u, v + dv, 0.6, 0.04, 0.0, 0.79)
        p.box("shelf_old", u, v + dv, 0.6, 0.04, 0.79, 2.0)
    for k in range(6):
        h = 0.08 + 0.37 * k
        p.box("shelf_wet" if k < 3 else "shelf_old", u, v, 0.6, length - 0.06, h, h + 0.02)
    if state != "empty":
        for side in (-1, 1):
            for k in range(2, 5):
                h = 0.1 + 0.37 * k
                n = int((length - 0.2) / 0.3)
                for j in range(n):
                    if p.rand(key, side, k, j) > (0.5 if k == 2 else 0.74):
                        continue
                    vv = v - length / 2 + 0.2 + j * 0.3
                    p.box(("book_a", "book_old", "book_c", "book_old")[j % 4], u + side * 0.16, vv, 0.22, 0.26, h,
                          h + 0.22 + 0.08 * p.rand(key, j))
            for j in range(3):                 # 아래 칸에 남은 불어 터진 책 몇 권
                vv = v - length / 2 + 0.5 + (length - 1.0) * p.rand(key, side, "low", j)
                p.box("book_wet", u + side * 0.16, vv, 0.24, 0.5, 0.47, 0.6 + 0.05 * j)
    if state == "tarp":
        p.box("tarp_blue", u, v, 0.74, length + 0.14, 1.05, 2.06)
        p.box("tarp_blue", u, v, 0.8, length + 0.2, 2.06, 2.09)
    p.solid(u, v, 0.62, length, 0.0, 2.0)


def _sandbags(p, u, v, n, rows=2, along_u=True):
    """모래주머니 줄 (n개 × rows단, 윗단은 반 칸 어긋나게)"""
    for r in range(rows):
        for i in range(n - r):
            a = (i + 0.5 * r - (n - 1) / 2) * 0.52
            x, z = (u + a, v) if along_u else (u, v + a)
            su, sv = (0.48, 0.3) if along_u else (0.3, 0.48)
            p.box("sandbag", x, z, su, sv, 0.15 * r, 0.15 * r + 0.14)
    length = n * 0.52
    p.solid(u, v, length if along_u else 0.3, 0.3 if along_u else length, 0.0, 0.15 * rows)


def old_library(ctx):
    """구 도서관 (폐쇄). 몇 해 전 집중호우 때 무릎 높이까지 침수되어 장서를 별관 3층으로 옮겼다는 설정.
    벽 아래쪽 물 자국선, 아래 칸이 빈 젖은 서가와 방수포, 문 옆 모래주머니, 배수 펌프와 호스, 바닥의 물웅덩이·토사,
    젖은 책을 말리던 건조대·송풍기·제습기, 별관으로 보낼 이전 상자와 안내문이 남아 있다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    d0 = doors[0].mid if doors else 1.5
    d1 = doors[-1].mid if doors else W - 1.5
    # 입구 안내 데스크와 카드함 (서랍이 빠져 있다), 반납 수레
    p.box("counter_wood", d0 + 1.8, 1.9, 2.2, 0.6, 0.0, 1.0, collide=True)
    p.box("shelf_wet", d0 + 1.8, 1.585, 2.2, 0.012, 0.0, 0.8)
    p.box("card_catalog", d0 + 3.5, 1.4, 0.6, 0.45, 0.0, 1.3, collide=True)
    for k in range(3):
        p.box("card_catalog", d0 + 4.15 + 0.02 * k, 1.5 + 0.03 * k, 0.5, 0.36, 0.14 * k, 0.14 * k + 0.13)
    p.box("monitor_old", d0 + 1.2, 1.85, 0.4, 0.4, 1.0, 1.35)
    p.box("paper_old", d0 + 2.2, 1.9, 0.3, 0.22, 1.0, 1.05)
    p.box("cart", d0 + 0.6, 2.9, 0.9, 0.45, 0.0, 0.9, collide=True)
    for i in range(4):
        p.box("book_old" if i % 2 else "book_c", d0 + 0.35 + 0.18 * i, 2.9, 0.08, 0.3, 0.9, 1.15)
    # 중앙 양면 서가: 아래 두 칸은 침수로 비었다. 두 줄은 방수포를 덮었고 한 줄은 이미 비웠다
    states = {1: "tarp", 3: "empty", 5: "tarp"}
    for i in range(7):
        u = W * 0.28 + i * 1.75
        if u > W - 3.5:
            break
        length = D - 4.4 if i != 3 else D - 6.2
        _flood_shelf(p, u, 3.0 + length / 2, length, "ol%d" % i, states.get(i, "wet"))
    return _old_library_flood(ctx, d0, d1)



def _double_shelf(p, u, v, length, key):
    """양면 서가 (v 방향으로 길게): 가운데 판 + 양쪽 칸"""
    p.box("shelf_old", u, v, 0.05, length, 0.0, 2.0)
    p.box("shelf_old", u, v - length / 2 + 0.02, 0.6, 0.04, 0.0, 2.0)
    p.box("shelf_old", u, v + length / 2 - 0.02, 0.6, 0.04, 0.0, 2.0)
    for k in range(6):
        h = 0.08 + 0.37 * k
        p.box("shelf_old", u, v, 0.6, length - 0.06, h, h + 0.02)
    for side in (-1, 1):
        for k in range(5):
            h = 0.1 + 0.37 * k
            n = int((length - 0.2) / 0.3)
            for j in range(n):
                if p.rand(key, side, k, j) > 0.72:
                    continue
                vv = v - length / 2 + 0.2 + j * 0.3
                p.box(("book_a", "book_b", "book_c", "book_old")[j % 4], u + side * 0.16, vv, 0.22, 0.26, h, h + 0.22 + 0.08 * p.rand(key, j))
    p.solid(u, v, 0.62, length, 0.0, 2.0)


def archive(ctx):
    """기록 보관실: 이동식 문서 선반 4줄(연도별 라벨), 도면 서랍, 저장매체, 작업대·스캐너·파쇄기·잠금 철제함"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(4):
        u = W * 0.22 + i * 1.35
        p.box("mobile_shelf", u, D * 0.58, 0.7, D - 3.8, 0.0, 2.1, collide=True)
        p.box("mobile_wheel", u, D * 0.58 - (D - 3.8) / 2 - 0.08, 0.6, 0.16, 0.9, 1.1)
        for k in range(5):
            p.box("file_box" if k % 2 else "paper", u, D * 0.58, 0.72, D - 4.0, 0.25 + 0.4 * k, 0.28 + 0.4 * k)
        p.box("label_white", u - 0.36, D * 0.58 - (D - 3.8) / 2 + 0.3, 0.02, 0.2, 1.5, 1.62)
    p.box("workbench", W - 1.2, 2.2, 1.8, 0.8, 0.0, 0.85, collide=True)
    p.box("scanner", W - 1.5, 2.2, 0.5, 0.4, 0.85, 0.98)
    p.box("shredder", W - 0.4, 3.3, 0.45, 0.4, 0.0, 0.75)
    p.box("drawer_cabinet", 0.7, D - 0.5, 1.2, 0.8, 0.0, 1.0, collide=True)
    cabinet(p, W - 0.6, D - 0.5, 0.9, 0.5, 1.8, "cabinet_metal", 2)
    for i in range(3):
        p.box("box", 1.6 + 0.55 * i, D - 0.5, 0.5, 0.4, 0.0, 0.35)
    pipes(ctx)


def storage(ctx):
    """창고: 벽면 철제 선반, 중앙 팔레트(두 문을 잇는 1.5m 통로는 비움), 여분 책걸상, 체육·행사 장비, 고장 난 컴퓨터·방송장비,
    손수레·접이식 사다리"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for side, a in (("left", D * 0.55), ("right", D * 0.55)):
        wall_item(p, W, D, side, a, D - 3.2, 0.0, 0.5, 0.0, 2.0, "shelf_metal", collide=True)
        for k in range(4):
            for j in range(int((D - 3.4) / 0.55)):
                if p.rand(side, k, j) > 0.6:
                    continue
                wall_item(p, W, D, side, 1.8 + j * 0.55, 0.45, 0.04, 0.42, 0.1 + 0.48 * k, 0.4 + 0.48 * k,
                          ("box", "monitor_old", "box", "ball")[j % 4])
    for i in range(2):
        u = W * 0.35 + i * (W * 0.3)
        v = D - 2.0
        p.box("pallet", u, v, 1.2, 1.0, 0.0, 0.14)
        p.box("box", u, v, 1.1, 0.9, 0.14, 0.9, collide=True)
    for i in range(3):
        p.box("desk_top", W * 0.5, D - 0.5, 0.6, 0.45, 0.69 + 0.72 * 0 + i * 0.05, 0.72 + i * 0.05)
    p.box("desk_frame", W * 0.5, D - 0.5, 0.6, 0.4, 0.0, 0.69, collide=True)
    p.box("cart", W - 1.2, 2.0, 0.6, 1.0, 0.0, 0.25)
    p.box("ladder", W * 0.8, D - 0.2, 0.5, 0.1, 0.0, 1.9)
    pipes(ctx)


def boiler(ctx):
    """보일러실: 대형 보일러 2기, 순환 펌프, 제어반, 천장 배관·밸브·압력계, 배수구, 환풍기, 공구 선반, 중앙 점검 통로"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i, u in enumerate((W * 0.3, W * 0.7)):
        p.box("boiler", u, D * 0.55, 2.0, 2.6, 0.0, 2.3, collide=True)
        p.box("boiler_band", u, D * 0.55, 2.04, 2.64, 1.9, 2.0)
        p.box("pipe_red", u, D * 0.55 - 1.3, 0.2, 0.2, 2.3, 3.2)
        p.box("gauge", u - 0.6, D * 0.55 - 1.32, 0.2, 0.05, 1.5, 1.7)
    for i in range(2):
        p.box("pump", W * 0.5 + (i - 0.5) * 1.0, D - 0.8, 0.6, 0.5, 0.0, 0.7, collide=True)
    wall_item(p, W, D, "left", D * 0.35, 1.2, 0.0, 0.35, 0.3, 2.0, "control_panel", collide=True)
    wall_item(p, W, D, "right", D * 0.3, 1.2, 0.0, 0.45, 0.0, 1.8, "shelf_metal", collide=True)
    wall_item(p, W, D, "front", W * 0.5, 0.4, 0.0, 0.05, 1.4, 1.8, "paper")
    wall_item(p, W, D, "back", W * 0.8, 0.6, 0.0, 0.2, 2.6, 3.2, "fan")
    p.box("drain", W * 0.5, D * 0.55, 0.3, 0.3, 0.0, 0.006)
    pipes(ctx, ("front", "back", "left"))


def electric(ctx):
    """전기실: 배전반 3면, 케이블 트레이, 회로 표기, 점검용 절연 매트"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(3):
        wall_item(p, W, D, "back", W * 0.25 + i * (W * 0.25), 1.0, 0.0, 0.6, 0.0, 2.1, "panel_gray", collide=True)
        wall_item(p, W, D, "back", W * 0.25 + i * (W * 0.25), 0.6, 0.6, 0.01, 1.3, 1.6, "label_white")
    wall_item(p, W, D, "back", W / 2, W - 0.4, 0.3, 0.3, 2.6, 2.7, "cable_tray")
    p.box("rubber_mat", W / 2, D - 1.2, W - 1.0, 0.8, 0.0, 0.01)
    pipes(ctx, ("front",))


def facility(ctx):
    """시설관리 창고: 공구 걸이, 사다리, 전구 상자, 페인트통, 작업대, 선반"""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "back", W * 0.35, 2.0, 0.0, 0.8, 0.0, 0.9, "workbench", collide=True)
    wall_item(p, W, D, "back", W * 0.35, 1.8, 0.0, 0.03, 1.2, 1.9, "pegboard")
    for i in range(6):
        wall_item(p, W, D, "back", W * 0.35 - 0.75 + 0.3 * i, 0.06, 0.03, 0.04, 1.35 + 0.2 * (i % 2), 1.6 + 0.2 * (i % 2), "metal_dark")
    for side in ("left", "right"):
        wall_item(p, W, D, side, D * 0.5, 1.6, 0.0, 0.5, 0.0, 1.9, "shelf_metal", collide=True)
        for k in range(3):
            wall_item(p, W, D, side, D * 0.5, 1.4, 0.05, 0.4, 0.4 + 0.55 * k, 0.65 + 0.55 * k, ("box", "paint_can", "box")[k])
    p.box("ladder", W * 0.75, D - 0.25, 0.5, 0.1, 0.0, 2.4)
    for i in range(3):
        p.box("paint_can", W * 0.6 + 0.3 * i, 1.8, 0.25, 0.25, 0.0, 0.3)
    pipes(ctx, ("front",))


def pump(ctx):
    """소방펌프·배관실: 펌프, 굵은 배관, 압력계, 설비 번호표"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i in range(3):
        u = W * 0.25 + i * (W * 0.25)
        p.box("pump_red", u, D * 0.55, 0.8, 1.2, 0.0, 0.9, collide=True)
        p.box("pipe_red", u, D * 0.55 + 0.9, 0.25, 0.6, 0.35, 0.6)
        p.box("pipe_red", u, D - 0.3, 0.3, 0.3, 0.0, 3.3)
        p.box("gauge", u + 0.3, D * 0.55 - 0.61, 0.15, 0.03, 0.9, 1.05)
        p.box("label_white", u, D * 0.55 - 0.61, 0.25, 0.01, 0.6, 0.72)
    wall_item(p, W, D, "back", W / 2, W - 0.4, 0.2, 0.3, 2.9, 3.2, "pipe_red")
    pipes(ctx, ("front",))


def waste(ctx):
    """폐기물 임시보관실: 분류 용기, 폐기 예정 물품, 운반 카트"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i, m in enumerate(("bin_gray", "bin_blue", "bin_yellow", "bin_green")):
        wall_item(p, W, D, "back", 0.45 + i * 0.6, 0.5, 0.0, 0.5, 0.0, 0.85, m, collide=True)
    p.box("cart", W * 0.5, D * 0.45, 0.6, 1.0, 0.0, 0.8)
    p.box("box", W * 0.5, D * 0.45, 0.5, 0.8, 0.8, 1.1)
    p.box("monitor_old", 0.5, D * 0.45, 0.45, 0.45, 0.0, 0.4)
    pipes(ctx, ("front",))


def b1_corridor(ctx):
    """지하 복도: 노출 배관, 계단 옆 소화전함, 오래된 게시물"""
    from rooms_corridor import plan_walls, _hydrant
    p, W, D = ctx.p, ctx.W, ctx.D
    walls, openings = plan_walls(ctx)
    for side, a0, a1, kind in openings:
        if kind != "stair":
            continue
        toward = 1 if (a0 + a1) / 2 < D / 2 else -1
        c = walls[side].find((a1 if toward > 0 else a0) + toward * 1.95, 1.4, span=3.0)
        if c is not None:
            _hydrant(p, W, D, side, c, toward)
            walls[side].block(c - 0.8, c + 0.8)
    for side in ("left", "right"):
        wall_item(p, W, D, side, D / 2, D - 0.2, 0.08, 0.14, 3.18, 3.32, "pipe")
        wall_item(p, W, D, side, D / 2, D - 0.2, 0.3, 0.1, 3.0, 3.1, "pipe_red")
    for k in range(3):
        c = walls["left"].find(D * (k + 1) / 4, 0.6, span=2.0)
        if c is not None:
            wall_item(p, W, D, "left", c, 0.5, 0.0, 0.004, 1.3, 1.7, "paper_old")
    # 구 도서관 문 옆: 침수 때 쌓았던 모래주머니, 문 앞 바닥 배수구, 미끄럼 주의 표지 (벽에 번진 습기는 벽 재질 wall_b1이 그린다)
    for i, d in enumerate([d for d in ctx.doors if d.door.room == "구 도서관"]):
        c = walls[d.side].find(d.a1 + 1.2, 1.7, span=2.5)
        if c is not None:
            _sandbags(p, 0.22 if d.side == "left" else W - 0.22, c, 3, 2, along_u=False)
            walls[d.side].block(c - 0.9, c + 0.9)
        p.box("drain_grate", W / 2, d.mid, 0.9, 0.3, 0.0, 0.012)
        if i == 0:
            p.box("wet_sign", W / 2 + (0.5 if d.side == "left" else -0.5), d.a0 - 0.7, 0.3, 0.05, 0.0, 0.6, yaw=20.0)


def _old_library_flood(ctx, d0, d1):
    """구 도서관의 침수 흔적과 복구·이전 작업의 흔적"""
    p, W, D = ctx.p, ctx.W, ctx.D
    NL = chr(10)
    # 문 옆 모래주머니, 남서쪽 구석에 남은 더미
    _sandbags(p, d0 + 2.3, 0.28, 4, 2)
    _sandbags(p, d1 - 2.0, 0.28, 4, 2)
    _sandbags(p, 1.2, D - 0.55, 3, 3)
    # 바닥: 물웅덩이, 벽을 따라 쌓인 토사, 불어 터져 흩어진 책
    for u, v, d in ((9.4, 9.3, 1.5), (13.0, 7.9, 1.3), (16.4, 9.4, 1.0), (4.2, 6.4, 2.0), (2.0, 8.6, 0.9), (19.3, 5.0, 0.8),
                    (14.9, 2.2, 0.7), (21.0, 1.7, 0.6)):
        p.cyl("water", u, v, d, 0.002, 0.013)
        p.cyl("water", u + d * 0.34, v + d * 0.2, d * 0.55, 0.002, 0.0125)
    p.box("silt", W / 2, D - 0.3, W - 3.0, 0.6, 0.002, 0.012)
    p.box("silt", 0.45, D * 0.62, 0.9, D * 0.5, 0.002, 0.011)
    p.box("silt", W - 0.4, D * 0.7, 0.8, D * 0.4, 0.002, 0.011)
    for i in range(16):
        u = 6.0 + 12.4 * p.rand("fb_u", i)
        v = 2.4 + 6.6 * p.rand("fb_v", i)
        if p.free(u - 0.3, v - 0.3, u + 0.3, v + 0.3) and abs((u - W * 0.28) % 1.75 - 0.875) < 0.5:
            p.box("book_wet", u, v, 0.26, 0.2, 0.008, 0.06, yaw=180.0 * p.rand("fb_y", i))
    # 서쪽 열람 구역: 큰 물웅덩이 둘레의 안전 고깔과 띠, 미끄럼 주의 표지
    for u, v in ((3.0, 5.2), (5.4, 5.2), (3.0, 7.6), (5.4, 7.6)):
        p.cone("cone", u, v, 0.34, 0.03, 0.62)
        p.box("cone", u, v, 0.4, 0.4, 0.0, 0.03)
    for (ua, va), (ub, vb) in (((3.0, 5.2), (5.4, 5.2)), ((5.4, 5.2), (5.4, 7.6)), ((5.4, 7.6), (3.0, 7.6)), ((3.0, 7.6), (3.0, 5.2))):
        p.box("safety_yellow", (ua + ub) / 2, (va + vb) / 2, abs(ub - ua) + 0.02, abs(vb - va) + 0.02, 0.5, 0.56)
    p.box("wet_sign", 6.0, 4.6, 0.3, 0.05, 0.0, 0.6, yaw=25.0)
    shelf_along(p, W, D, "left", D * 0.45, 2.4, 0.4, 1.4, 3, 0.25, key="news", mat="shelf_wet", book_mats=("paper_old", "book_wet", "paper_old"))
    p.box("map_cabinet", 0.9, D - 1.9, 1.2, 0.8, 0.0, 0.9, collide=True)
    p.box("map_cabinet", 1.65, D - 1.9, 0.5, 0.74, 0.5, 0.62)                # 빠져나온 서랍
    # 동쪽: 젖은 책을 말리던 자리 (책을 펼쳐 둔 탁자, 건조대, 송풍기, 제습기)
    for i in range(3):
        u, v = W - 2.2, 3.2 + i * 2.1
        table(p, u, v, 1.8, 0.9, 0, along="u", key="olt%d" % i)
        if i == 2:
            p.box("vinyl", u, v, 1.95, 1.05, 0.75, 0.78)
            continue
        for k in range(5):
            bu = u - 0.7 + 0.35 * k
            p.box("book_wet", bu, v, 0.3, 0.42, 0.75, 0.775)
            p.box("paper_old", bu, v, 0.26, 0.38, 0.775, 0.79)
    for v in (3.4, 6.4):                                                     # 건조대: 낱장을 널어 말린다
        u = W - 4.6
        for dv in (-0.9, 0.9):
            p.box("drying_rack", u, v + dv, 0.5, 0.04, 0.0, 1.3)
        for k in range(3):
            p.box("drying_rack", u - 0.2 + 0.2 * k, v, 0.03, 1.8, 1.26 - 0.2 * k, 1.29 - 0.2 * k)
            for j in range(5):
                p.box("paper_old", u - 0.2 + 0.2 * k, v - 0.7 + 0.35 * j, 0.012, 0.24, 0.96 - 0.2 * k, 1.27 - 0.2 * k)
        p.solid(u, v, 0.5, 1.8, 0.0, 1.3)
    for u, v, yaw in ((W - 5.6, 8.5, -30.0), (W - 3.6, 1.9, 150.0)):          # 송풍기
        p.cyl("metal_dark", u, v, 0.45, 0.0, 0.06)
        p.cyl("metal_dark", u, v, 0.07, 0.06, 0.9)
        p.box("fan", u, v, 0.62, 0.18, 0.6, 1.22, yaw=yaw)
        p.box("metal_dark", u, v, 0.16, 0.24, 0.84, 1.0, yaw=yaw)
    for u, v in ((W * 0.62, D - 0.5), (W - 1.0, D - 0.9)):                    # 제습기와 물받이 양동이
        p.box("dehumidifier", u, v, 0.4, 0.3, 0.0, 0.6)
        p.box("bucket_blue", u + 0.5, v, 0.3, 0.3, 0.0, 0.32)
    # 배수 펌프와 호스 (남쪽 벽을 따라 동쪽 문으로)
    p.box("safety_yellow", 10.4, D - 0.5, 0.5, 0.36, 0.0, 0.42, collide=True)
    p.box("metal_dark", 10.4, D - 0.5, 0.3, 0.05, 0.42, 0.5)
    p.box("hose_blue", (10.7 + W - 0.6) / 2, D - 0.2, W - 0.6 - 10.7, 0.09, 0.0, 0.08)
    p.box("hose_blue", W - 0.6, (D - 0.2 + 0.7) / 2, 0.09, D - 0.9, 0.0, 0.08)
    p.box("cable_reel", 11.2, D - 0.45, 0.4, 0.3, 0.0, 0.4)
    # 천장 누수 자리의 양동이
    for (u, v), m in (((14.9, 2.2), "bucket_blue"), ((21.0, 1.7), "bucket_red"), ((6.0, 9.5), "bucket_blue")):
        p.box(m, u, v, 0.32, 0.32, 0.0, 0.34)
    # 별관으로 보낼 이전 상자 (팔레트 위), 폐기할 책 상자
    for k, (u, v) in enumerate(((7.7, D - 0.75), (12.6, D - 0.75), (15.2, D - 0.75))):
        p.box("pallet", u, v, 1.2, 1.0, 0.0, 0.14)
        for i in range(3):
            for j in range(2 if k != 1 else 1):
                p.box("box", u - 0.38 + 0.38 * i, v - 0.1, 0.36, 0.6, 0.14 + 0.4 * j, 0.52 + 0.4 * j)
        p.solid(u, v, 1.2, 1.0, 0.0, 0.9)
        x, z = ctx.frame.pt(u, v + 0.21)
        label(ctx.sw, ctx.container, (x, ctx.y + 0.36, z), "별관 3층" + NL + "도서관" if k != 1 else "폐기", 0.0024, 36, (0.2, 0.14, 0.08),
              facing_rows(ctx.frame, "back"))
    p.box("tape", 8.3, D - 0.85, 0.12, 0.12, 0.94, 0.99)
    # 북쪽 벽(복도 쪽): 침수 수위 표시, 도서관 이전 안내문. 스며 오른 습기·곰팡이 얼룩은 벽 재질(wall_b1_flood)이 그린다
    wm = W * 0.5
    wall_item(p, W, D, "front", wm, 1.4, 0.0, 0.006, 0.735, 0.765, "safety_yellow")
    wall_label(ctx, "front", wm, 0.98, "▲ 침수 수위", 0.03, 0.004, 44, (0.25, 0.2, 0.1))
    na = d0 + 3.3
    wall_item(p, W, D, "front", na, 1.3, 0.0, 0.02, 1.15, 2.05, "cork")
    wall_item(p, W, D, "front", na, 1.1, 0.02, 0.004, 1.25, 1.95, "paper")
    wall_label(ctx, "front", na, 1.78, "도서관 이전 안내", 0.03, 0.0034, 40)
    wall_label(ctx, "front", na, 1.48, "침수 피해로 이곳을 닫습니다." + NL + "장서는 별관 3층 도서관으로" + NL + "옮겼습니다.", 0.03, 0.0022, 32)
    ctx.anchor("flood", wm, 0.05, wm, 0.95)
    pipes(ctx)


