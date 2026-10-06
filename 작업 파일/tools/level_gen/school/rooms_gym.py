# -*- coding: utf-8 -*-
"""강당 내부 (학교_맵_상세.md 강당 내부 구성 + 레퍼런스 10·11).
코트·무대·2층은 강당 좌표를 쓴다: u = 서 -> 동 0~40, s = 남쪽 무대 0 -> 북쪽 주출입구 26 (월드 x = u-20, z = 55-s).
벽으로 둘러싸인 방(준비실·창고·관리실·출입홀·화장실)은 다른 건물과 같은 방 좌표(RoomCtx)를 쓴다."""
import math
from props_base import Props, label, wall_item, bench, plant, bins, shelf_along
from props_more import office_desk, table, whiteboard_wall
from props_annex import wall_label, rack, glass_cabinet, book_cart, stool
from batch import rows_y
from plan import GYM_Z1
from gym import WING_ROWS, WING_AISLE, NORTH_ROWS, FLOOR2, REAR, STAGE_H

COURT = (2.7, 7.0, 37.3, 20.4)      # 농구 코트 (u0, s0, u1, s1): 서·동 출입구에서 2m 이상 띄운다
CS = 13.7                           # 코트 중심 s
N_WALL = 21.125                     # 코트 북쪽 벽 안쪽 면


class GymFrame:
    """강당 좌표 -> 월드"""

    def __init__(self, y=0.0):
        self.y = y
        self.front = "gym"

    def pt(self, u, s):
        return u - 20.0, GYM_Z1 - s

    def size(self, su, ss, sh):
        return (su, sh, ss)


def gp(batch, path, y=0.0, seed=7):
    return Props(batch, path, GymFrame(y), seed=seed)


def line(p, u0, s0, u1, s1, w=0.06, top=0.012, mat="floor_mark_white"):
    """바닥 테이프 선"""
    L = math.hypot(u1 - u0, s1 - s0)
    if L < 1e-3:
        return
    yaw = math.degrees(math.atan2(s1 - s0, u1 - u0))
    p.box(mat, (u0 + u1) / 2, (s0 + s1) / 2, L, w, 0.0, top, yaw=yaw)


def arc(p, cu, cs, r, a0, a1, n=16, w=0.06, top=0.012, mat="floor_mark_white"):
    pts = [(cu + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cs + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
           for i in range(n + 1)]
    for (ua, sa), (ub, sb) in zip(pts, pts[1:]):
        line(p, ua, sa, ub, sb, w, top, mat)


def court_lines(p):
    """흰 테이프: 농구 코트(중앙 원·자유투 구역·3점 라인)와 배구 코트를 겹쳐 표시, 배구 지주 소켓 덮개"""
    u0, s0, u1, s1 = COURT
    for a, b, c, d in ((u0, s0, u1, s0), (u0, s1, u1, s1), (u0, s0, u0, s1), (u1, s0, u1, s1), (20.0, s0, 20.0, s1)):
        line(p, a, b, c, d)
    arc(p, 20.0, CS, 1.8, 0, 360, 24)
    reach = math.sqrt(6.75 ** 2 - 5.8 ** 2)
    ang = math.degrees(math.asin(5.8 / 6.75))
    for side, ub in ((1, u0), (-1, u1)):
        ft = ub + side * 5.8
        line(p, ub, CS - 2.45, ft, CS - 2.45)
        line(p, ub, CS + 2.45, ft, CS + 2.45)
        line(p, ft, CS - 2.45, ft, CS + 2.45)
        arc(p, ft, CS, 1.8, 0, 360, 20)
        hu = ub + side * 1.575
        line(p, ub, CS - 5.8, hu + side * reach, CS - 5.8)
        line(p, ub, CS + 5.8, hu + side * reach, CS + 5.8)
        if side > 0:
            arc(p, hu, CS, 6.75, -ang, ang, 18)
        else:
            arc(p, hu, CS, 6.75, 180 - ang, 180 + ang, 18)
    for a, b, c, d in ((11, 9.2, 29, 9.2), (11, 18.2, 29, 18.2), (11, 9.2, 11, 18.2), (29, 9.2, 29, 18.2),
                       (17, 9.2, 17, 18.2), (23, 9.2, 23, 18.2)):
        line(p, a, b, c, d, 0.045, 0.0105)
    for s in (8.7, 18.7):
        p.cyl("steel", 20.0, s, 0.2, 0.0, 0.006)


def hoop(p, side):
    """벽 부착 접이식 농구 골대 (side = +1 서쪽 벽, -1 동쪽 벽): 백보드, 림과 그물, 벽에서 뻗은 철제 틀"""
    wall = 0.25 if side > 0 else 39.75
    bu = (COURT[0] + 1.2) if side > 0 else (COURT[2] - 1.2)
    p.box("whiteboard", bu - side * 0.025, CS, 0.05, 1.8, 2.9, 3.95)
    p.box("hoop_rim", bu + side * 0.004, CS, 0.008, 0.59, 3.02, 3.06)
    p.box("hoop_rim", bu + side * 0.004, CS, 0.008, 0.59, 3.43, 3.47)
    for d in (-1, 1):
        p.box("hoop_rim", bu + side * 0.004, CS + d * 0.275, 0.008, 0.04, 3.06, 3.43)
    ru = bu + side * 0.38
    for i in range(8):
        a0, a1 = math.radians(i * 45), math.radians((i + 1) * 45)
        ua, sa = ru + 0.23 * math.cos(a0), CS + 0.23 * math.sin(a0)
        ub, sb = ru + 0.23 * math.cos(a1), CS + 0.23 * math.sin(a1)
        yaw = math.degrees(math.atan2(sb - sa, ub - ua))
        p.box("hoop_rim", (ua + ub) / 2, (sa + sb) / 2, math.hypot(ub - ua, sb - sa) + 0.02, 0.03, 3.03, 3.06, yaw=yaw)
    p.box("hoop_rim", bu + side * 0.09, CS, 0.18, 0.1, 3.02, 3.06)
    p.cyl("net_white", ru, CS, 0.38, 2.62, 3.03)
    back = bu - side * 0.05
    for h in (3.18, 3.8):
        for d in (-1, 1):
            ua, sa, ub, sb = wall, CS + d * 1.0, back, CS + d * 0.45
            yaw = math.degrees(math.atan2(sb - sa, ub - ua))
            p.box("steel_frame", (ua + ub) / 2, (sa + sb) / 2, math.hypot(ub - ua, sb - sa), 0.06, h, h + 0.06, yaw=yaw)
        p.box("steel_frame", wall + side * 0.03, CS, 0.06, 2.3, h - 0.1, h + 0.16)
    p.box("steel_frame", back - side * 0.03, CS, 0.06, 1.0, 3.1, 3.9)


def ball_cart(p, u, s, mat="ball"):
    """철망 공 카트 (충돌 한 덩어리)"""
    for du in (-0.4, 0.4):
        for ds in (-0.28, 0.28):
            p.box("metal_dark", u + du, s + ds, 0.03, 0.03, 0.05, 0.85)
    p.box("metal_dark", u, s, 0.86, 0.62, 0.22, 0.25)
    for ds in (-0.3, 0.3):
        p.box("metal_dark", u, s + ds, 0.86, 0.025, 0.8, 0.83)
    for du in (-0.42, 0.42):
        p.box("metal_dark", u + du, s, 0.025, 0.62, 0.8, 0.83)
    k = 0
    for du in (-0.25, 0.0, 0.25):
        for ds in (-0.15, 0.15):
            p.cyl(mat if k % 3 else "net_white", u + du, s + ds, 0.24, 0.25 + 0.24 * (k % 2), 0.49 + 0.24 * (k % 2))
            k += 1
    p.solid(u, s, 0.86, 0.62, 0.0, 0.85)


def fold_chair(p, u, s, face=1):
    """접이식 의자 (face: 앉은 사람이 보는 s 방향)"""
    p.box("chair_office", u, s, 0.42, 0.4, 0.43, 0.46)
    p.box("chair_office", u, s - face * 0.19, 0.4, 0.03, 0.46, 0.85)
    for du in (-0.19, 0.19):
        p.box("metal_dark", u + du, s, 0.025, 0.36, 0.0, 0.43)


def _nboard(p, u, w, h0, h1, mat, papers=()):
    """코트 북쪽 벽(카메라를 보는 면)에 붙는 판"""
    p.box("frame_alu", u, N_WALL - 0.015, w + 0.08, 0.03, h0 - 0.04, h1 + 0.04)
    p.box(mat, u, N_WALL - 0.036, w, 0.012, h0, h1)
    for i, m in enumerate(papers):
        pu = u - w / 2 + 0.25 + (w - 0.5) * i / max(1, len(papers) - 1)
        p.box(m, pu, N_WALL - 0.045, 0.24, 0.005, h0 + 0.15 + 0.12 * (i % 2), h0 + 0.5 + 0.12 * (i % 2))


def _nlabel(sw, path, u, h, text, size=0.005, font=48, color=(0.14, 0.16, 0.2)):
    label(sw, path, (u - 20.0, h, GYM_Z1 - (N_WALL - 0.06)), text, size, font, color, rows_y(0.0))


def court(batch, sw, path):
    """1층 마룻바닥: 가운데는 고정 물건 없이 선만. 벽면에 골대·하단 안전 매트·선수 벤치·경기 기록석·이동식 득점판·
    공 카트·청소 장비·AED·들것·구급함·휠체어 관람 구역, 북측 벽에 시계·기록판·일정표·현수막·대피도"""
    p = gp(batch, path)
    court_lines(p)
    for side in (1, -1):
        hoop(p, side)
        wall = 0.25 if side > 0 else 39.75
        for s0, s1 in ((8.2, 12.4), (15.6, 19.8)):
            p.box("pad_blue", wall + side * 0.045, (s0 + s1) / 2, 0.09, s1 - s0, 0.05, 2.0)
            k = 1
            while s0 + 1.05 * k < s1 - 0.2:
                p.box("metal_dark", wall + side * 0.093, s0 + 1.05 * k, 0.006, 0.02, 0.05, 2.0)
                k += 1
        bench(p, wall + side * 0.38, 10.4, 2.6, along_u=False)
        p.box("mat_dark", wall + side * 1.0, 14.0, 1.5, 2.2, 0.0, 0.012)
    bench(p, 2.5, N_WALL - 0.24, 2.6, along_u=True)
    bench(p, 36.3, N_WALL - 0.24, 2.4, along_u=True)
    # 서측: 공 카트, 간이 구급함 / 북서 구석: 대형 밀대·왁스 작업기
    ball_cart(p, 1.0, 16.9)
    p.box("first_aid", 0.32, 17.9, 0.14, 0.35, 2.1, 2.4)
    p.box("safety_yellow", 0.62, 20.75, 0.5, 0.6, 0.0, 0.5, collide=True)
    p.box("metal_dark", 0.62, 20.48, 0.4, 0.04, 0.5, 1.05)
    for k in range(2):
        p.box("mop_stick", 0.33, 20.0 + 0.2 * k, 0.03, 0.03, 0.0, 1.5)
        p.box("mop_head", 0.75, 20.0 + 0.2 * k, 0.9, 0.1, 0.0, 0.06)
    # 동측: 경기 기록석, 점수 조작기, 이동식 득점판
    p.box("table_top", 38.3, 17.1, 0.7, 2.4, 0.72, 0.75)
    for ds in (-1.1, 1.1):
        p.box("desk_frame", 38.3, 17.1 + ds, 0.6, 0.05, 0.0, 0.72)
    p.solid(38.3, 17.1, 0.7, 2.4, 0.0, 0.76)
    for k in range(3):
        s = 16.3 + 0.8 * k
        p.box("chair_office", 39.05, s, 0.42, 0.42, 0.43, 0.47)
        p.box("chair_office", 39.26, s, 0.04, 0.4, 0.47, 0.88)
        p.box("metal_dark", 39.05, s, 0.05, 0.05, 0.0, 0.43)
    p.box("monitor", 38.3, 16.5, 0.3, 0.4, 0.75, 0.9)
    p.box("paper", 38.3, 17.4, 0.3, 0.21, 0.75, 0.756)
    p.box("metal_dark", 38.5, 18.9, 0.5, 0.9, 0.0, 0.05)
    for ds in (-0.4, 0.4):
        p.box("metal_dark", 38.5, 18.9 + ds, 0.04, 0.04, 0.05, 0.95)
    p.box("rack", 38.5, 18.9, 0.06, 1.0, 0.95, 1.55)
    p.box("net_white", 38.462, 18.65, 0.012, 0.36, 1.05, 1.45)
    p.box("art_red", 38.462, 19.15, 0.012, 0.36, 1.05, 1.45)
    # 북동: 휠체어 관람 구역, 동측 벽 AED·들것, 북측 벽 대형 구급함
    for a, b, c, d in ((33.6, 19.1, 37.2, 19.1), (33.6, 20.33, 37.2, 20.33), (33.6, 19.1, 33.6, 20.33), (37.2, 19.1, 37.2, 20.33)):
        line(p, a, b, c, d, 0.08, 0.014, "floor_mark_blue")
    p.box("floor_mark_blue", 35.9, 19.72, 0.6, 0.6, 0.0, 0.014)
    for u in (34.0, 34.7):
        fold_chair(p, u, 19.75, -1)
    p.box("metal_dark", 36.7, 19.72, 0.55, 0.6, 0.45, 0.5)
    p.box("metal_dark", 36.7, 20.0, 0.5, 0.05, 0.5, 0.95)
    for du in (-0.3, 0.3):
        p.box("metal_dark", 36.7 + du, 19.75, 0.04, 0.55, 0.05, 0.6)
    p.box("aed", 39.67, 20.4, 0.16, 0.4, 1.1, 1.55)
    p.box("sign_green", 39.745, 20.4, 0.01, 0.3, 1.65, 1.85)
    p.box("stretcher", 39.63, 20.88, 0.15, 0.4, 0.0, 1.9)
    p.box("first_aid", 39.3, N_WALL - 0.08, 0.5, 0.16, 1.1, 1.6)
    # 북측 벽 게시물
    p.box("clock_rim", 20.0, N_WALL - 0.03, 0.6, 0.06, 2.75, 3.35)
    p.box("clock_face", 20.0, N_WALL - 0.065, 0.5, 0.012, 2.8, 3.3)
    _nboard(p, 11.5, 3.2, 1.0, 2.3, "cork", ("paper", "paper_yellow", "paper", "paper_blue", "paper"))
    _nlabel(sw, path, 11.5, 2.52, "체육대회 종합 기록")
    _nboard(p, 26.4, 1.8, 1.0, 2.1, "whiteboard", ("paper", "paper_yellow"))
    _nlabel(sw, path, 26.4, 2.3, "경기 일정", 0.004, 40)
    _nboard(p, 29.6, 0.9, 1.2, 1.9, "floor_map")
    p.box("banner_roll", 28.0, N_WALL - 0.02, 6.0, 0.02, 2.65, 3.3)
    _nlabel(sw, path, 28.0, 2.98, "OO고등학교 한마음 체육대회", 0.0075, 64, (0.14, 0.24, 0.5))
    for u in (16.2, 23.8):
        p.box("extinguisher", u, N_WALL - 0.14, 0.17, 0.17, 0.0, 0.56)
    p.box("extinguisher", 4.2, 6.5, 0.17, 0.17, 0.0, 0.56)
    fold_chair(p, 8.3, 6.75, 1)


def stage(batch, sw, path):
    """무대 (바닥 +1.1m): 걷어 둔 전면 커튼, 옆막, 배경막, 말아 올린 스크린, 연설대와 마이크, 접어 세운 합창 단상,
    모니터 스피커, 무대 끝 테두리와 낮은 안전등"""
    p = gp(batch, path, STAGE_H, seed=11)
    for u0, u1 in ((7.75, 9.4), (30.6, 32.25)):
        for k in range(4):
            uu = u0 + (u1 - u0) * (k + 0.5) / 4
            p.box("curtain_stage", uu, 5.75 + 0.05 * (k % 2), (u1 - u0) / 4 + 0.03, 0.14, 0.0, 2.45)
    for u in (8.2, 31.8):
        p.box("curtain_heavy", u, 2.9, 0.1, 2.2, 0.0, 2.45)
    p.box("backdrop", 20.0, 0.42, 20.0, 0.06, 0.0, 2.45)
    p.box("emblem", 20.0, 0.46, 1.6, 0.012, 0.9, 2.1)
    p.box("frame_alu", 20.0, 0.75, 6.4, 0.16, 2.3, 2.45)
    p.box("lectern", 20.0, 4.6, 0.7, 0.5, 0.0, 1.1, collide=True)
    p.box("lectern_top", 20.0, 4.6, 0.76, 0.56, 1.1, 1.14)
    p.box("emblem_gold", 20.0, 4.86, 0.3, 0.012, 0.5, 0.8)
    p.box("metal_dark", 21.2, 4.7, 0.03, 0.03, 0.0, 1.4)
    p.box("metal_dark", 21.2, 4.7, 0.3, 0.3, 0.0, 0.03)
    for k in range(3):
        p.box("riser", 11.0 + 0.16 * k, 1.6, 0.12, 2.4, 0.0, 1.2 + 0.1 * k)
    p.solid(11.16, 1.6, 0.5, 2.4, 0.0, 1.4)
    for u in (9.9, 30.1):
        p.box("rack", u, 5.5, 0.5, 0.4, 0.0, 0.35)
        p.box("lamp", u + (0.7 if u < 20 else -0.7), 5.98, 0.12, 0.08, 0.0, 0.08)
    p.box("metal_dark", 20.0, 6.02, 24.5, 0.1, 0.0, 0.012)


def prop_room(ctx):
    """소품·의상 준비실 (앞 = 마룻바닥 쪽 벽, 무대 옆문으로 오르는 안쪽 계단은 오른쪽): 이동식 의상 행거 2개, 의상장,
    화장대 2개와 거울, 전신거울, 가면·모자함, 연극 배경판. 문에서 계단까지는 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    for i, v in enumerate((2.4, 3.6)):                    # 의상 행거 (바퀴 달린 봉 + 옷)
        p.box("metal_dark", 1.5, v, 1.6, 0.04, 1.6, 1.64)
        for du in (-0.78, 0.78):
            p.box("metal_dark", 1.5 + du, v, 0.04, 0.5, 0.0, 0.05)
            p.box("metal_dark", 1.5 + du, v, 0.04, 0.04, 0.05, 1.6)
        for k, m in enumerate(("art_red", "curtain_stage", "paper", "art_blue", "cloth", "art_yellow", "apron")):
            p.box(m, 0.84 + 0.22 * k, v, 0.16, 0.42, 0.55 + 0.1 * ((k + i) % 3), 1.58)
        p.solid(1.5, v, 1.6, 0.5, 0.0, 1.64)
    wall_item(p, W, D, "left", 4.45, 1.4, 0.0, 0.55, 0.0, 1.9, "cabinet_wood", collide=True)      # 의상장
    wall_item(p, W, D, "left", 4.45, 0.012, 0.55, 0.006, 0.05, 1.85, "wood_dark")
    for k in range(2):                                    # 화장대 (남쪽 벽), 거울과 전구
        cu = 1.2 + 1.15 * k
        wall_item(p, W, D, "back", cu, 1.0, 0.0, 0.45, 0.0, 0.75, "counter_white", collide=True)
        wall_item(p, W, D, "back", cu, 0.8, 0.0, 0.02, 0.95, 1.75, "mirror")
        wall_item(p, W, D, "back", cu, 0.9, 0.0, 0.05, 1.77, 1.84, "lamp")
        stool(p, cu, D - 0.85)
    wall_item(p, W, D, "left", 0.7, 0.6, 0.0, 0.03, 0.2, 1.9, "mirror")                          # 전신거울
    for k in range(3):                                    # 가면·모자함, 소품 상자
        p.box("box", 0.35, 1.7 + (0.5 * k if k < 2 else 0.25), 0.5, 0.42, 0.36 * (k // 2), 0.36 * (k // 2 + 1))
    p.box("backdrop", 1.0, 0.12, 1.7, 0.06, 0.0, 1.9)                                             # 연극 배경판
    p.box("art_green", 0.8, 0.17, 0.9, 0.02, 0.6, 1.5)


def sound_room(ctx):
    """음향·조명·무대장치실 (잠금, 안쪽 계단은 왼쪽): 잠금형 장비장, 공구 작업대와 보조 믹서, 이동식 스피커,
    조명 스탠드, 케이블 릴, 마이크 케이스, 사다리. 가운데 운반 통로는 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    wall_item(p, W, D, "right", 3.75, 2.9, 0.0, 0.55, 0.0, 1.9, "cabinet_metal", collide=True)
    for k in range(1, 3):
        wall_item(p, W, D, "right", 2.3 + 2.9 * k / 3, 0.012, 0.55, 0.006, 0.05, 1.85, "metal_dark")
    for k in range(3):
        wall_item(p, W, D, "right", 2.3 + 2.9 * (k + 0.5) / 3 + 0.2, 0.08, 0.55, 0.02, 0.95, 1.05, "panel_red")
    wall_item(p, W, D, "back", 2.4, 1.9, 0.0, 0.6, 0.0, 0.85, "workbench", collide=True)
    wall_item(p, W, D, "back", 2.1, 0.7, 0.08, 0.4, 0.85, 0.97, "console")
    wall_item(p, W, D, "back", 3.0, 0.4, 0.1, 0.3, 0.85, 1.05, "charge_box")
    for u in (3.25, 3.95):                                # 이동식 스피커 (삼각대 위)
        p.box("metal_dark", u, 1.5, 0.04, 0.04, 0.0, 1.2)
        p.box("metal_dark", u, 1.5, 0.5, 0.5, 0.0, 0.03)
        p.box("rack", u, 1.5, 0.36, 0.34, 1.2, 1.8)
    for k in range(2):                                    # 케이블 릴, 마이크 케이스 (앞 벽 오른쪽)
        p.cyl("cable_reel", 2.95 + 0.5 * k, 0.32, 0.4, 0.0, 0.3)
    p.box("case_black", 4.0, 0.3, 0.5, 0.35, 0.0, 0.3)
    p.box("ladder", W - 0.35, D - 0.3, 0.5, 0.1, 0.0, 2.2)
    for u in (3.55, 3.85):                                # 조명 스탠드
        p.box("metal_dark", u - 0.4, D - 0.75, 0.04, 0.04, 0.0, 1.9)
        p.box("studio_light", u - 0.4, D - 0.75, 0.3, 0.22, 1.9, 2.15)


def equipment_storage(ctx):
    """체육기구 창고 (앞 = 마룻바닥 쪽 양개문): 벽면 선반(공·라바콘·라켓·조끼), 공 카트 2대, 체조 매트 더미, 뜀틀과 구름판,
    허들, 배구 지주, 말아 둔 네트. 문 앞과 가운데는 장비를 끌고 나올 수 있게 비운다."""
    p, W, D = ctx.p, ctx.W, ctx.D
    rack(p, W, D, "back", 2.3, 3.6, 0.5, 1.8, 3, ("ball", "cone", "box", "net_white"), "es1", 0.9)
    rack(p, W, D, "right", 2.5, 2.8, 0.5, 1.8, 3, ("vest", "box", "art_blue", "ball"), "es2", 0.85)
    for k in range(5):                                    # 체조 매트 더미
        p.box("gym_mat" if k % 2 else "gym_mat_green", 6.6, D - 0.75, 2.4, 1.2, 0.08 * k, 0.08 * (k + 1))
    p.solid(6.6, D - 0.75, 2.4, 1.2, 0.0, 0.42)
    for k in range(4):                                    # 뜀틀 (층층이 좁아지는 틀 + 가죽 윗판)
        p.box("bench_wood", 0.75, 3.0, 0.9 - 0.08 * k, 1.3 - 0.06 * k, 0.26 * k, 0.26 * (k + 1))
    p.box("vault_top", 0.75, 3.0, 0.5, 1.2, 1.04, 1.14)
    p.solid(0.75, 3.0, 0.9, 1.3, 0.0, 1.14)
    p.box("bench_wood", 0.7, 1.75, 0.6, 0.9, 0.0, 0.12)   # 구름판
    for k in range(3):                                    # 허들
        p.box("net_white", 1.9 + 0.12 * k, 3.3, 0.04, 1.0, 0.7, 0.76)
        for dv in (-0.48, 0.48):
            p.box("metal_dark", 1.9 + 0.12 * k, 3.3 + dv, 0.04, 0.04, 0.0, 0.7)
    for k in range(2):                                    # 배구 지주, 말아 둔 네트
        p.cyl("steel", 0.3 + 0.25 * k, 0.35, 0.09, 0.0, 2.5)
    p.cyl("net_white", 0.9, 0.3, 0.22, 0.0, 1.1)
    ball_cart(p, 6.4, 1.9)
    ball_cart(p, 7.6, 1.9, "art_blue")
    for k in range(4):                                    # 라바콘 더미
        p.cyl("cone", 8.15, 2.85, 0.3 - 0.05 * k, 0.12 * k, 0.12 * (k + 1))


def _chair_cart(p, u, v):
    """접이식 의자 운반 카트 (세워 겹친 의자)"""
    p.box("metal_dark", u, v, 0.6, 1.3, 0.12, 0.17)
    for k in range(9):
        p.box("chair_office", u, v - 0.52 + 0.13 * k, 0.5, 0.05, 0.17, 1.1)
    p.box("metal_dark", u, v + 0.66, 0.5, 0.04, 0.17, 1.2)
    p.solid(u, v, 0.6, 1.36, 0.0, 1.2)


def event_storage(ctx):
    """행사물품 창고: 접이식 의자 카트 3대, 접이식 테이블 카트, 이동식 연단, 파티션, 기표소, 국기·교기, 현수막 봉,
    대형 선풍기 2대, 난방기"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for k in range(3):
        _chair_cart(p, 0.55 + 0.75 * k, D - 0.8)
    p.box("metal_dark", 3.1, D - 1.05, 0.7, 1.9, 0.12, 0.17)                     # 테이블 카트
    for k in range(5):
        p.box("table_top", 2.9 + 0.1 * k, D - 1.05, 0.05, 1.8, 0.17, 0.95)
    p.solid(3.1, D - 1.05, 0.7, 1.9, 0.0, 0.95)
    p.box("lectern", W - 1.1, 2.6, 0.7, 0.55, 0.0, 1.1, collide=True)            # 이동식 연단
    p.box("lectern_top", W - 1.1, 2.6, 0.76, 0.6, 1.1, 1.14)
    for k in range(3):                                                           # 파티션 (오른쪽 벽에 세움)
        p.box("carrel_panel", W - 0.08 - 0.07 * k, 2.2, 0.05, 1.5, 0.05, 1.75)
    p.solid(W - 0.16, 2.2, 0.3, 1.5, 0.0, 1.75)
    p.box("carrel_panel", W - 1.0, D - 0.5, 0.9, 0.9, 0.0, 1.9, collide=True)    # 기표소
    p.box("cloth", W - 1.0, D - 0.96, 0.8, 0.02, 0.9, 1.85)
    for k, m in enumerate(("flag_kr", "flag_school")):                           # 국기·교기 (깃대 꽂이)
        p.cyl("brass", 0.35 + 0.3 * k, 0.4, 0.05, 0.0, 2.4)
        p.box(m, 0.35 + 0.3 * k, 0.55, 0.02, 0.3, 1.5, 2.3)
    p.box("metal_dark", 0.5, 0.4, 0.7, 0.3, 0.0, 0.25)
    for k in range(3):                                                           # 현수막 봉
        p.cyl("steel", 0.2 + 0.08 * k, 1.1, 0.04, 0.0, 2.6)
    for k in range(2):                                                           # 대형 선풍기
        v = 1.75 + 0.8 * k
        p.box("metal_dark", 0.4, v, 0.5, 0.5, 0.0, 0.06)
        p.box("metal_dark", 0.4, v, 0.06, 0.06, 0.06, 0.9)
        p.box("fan", 0.4, v, 0.25, 0.75, 0.9, 1.65)
    p.box("boiler", W - 0.5, 0.5, 0.5, 0.5, 0.0, 1.0, collide=True)              # 난방기
    p.box("boiler_band", W - 0.5, 0.5, 0.52, 0.52, 0.8, 0.9)


def gym_office(ctx):
    """강당 관리실 (잠금): 담당 교사 책상·컴퓨터, 예약 일정표, 열쇠함, CCTV 모니터, 점수판 제어기, 무전기 충전대,
    서류장, 작은 냉장고, 구급함"""
    p, W, D = ctx.p, ctx.W, ctx.D
    office_desk(p, 2.2, 2.9, facing=-1, w=1.3, items=("monitor", "papers", "mug"), key="go")
    wall_item(p, W, D, "right", 0.7, 0.8, 0.0, 0.45, 0.0, 1.9, "cabinet_metal", collide=True)
    whiteboard_wall(p, W, D, "right", 3.75, 1.2, 1.1, 1.9)
    for k in range(4):
        wall_item(p, W, D, "right", 3.35 + 0.27 * k, 0.2, 0.04, 0.004, 1.3, 1.7, "paper_yellow" if k % 2 else "paper")
    wall_item(p, W, D, "front", 0.4, 0.5, 0.0, 0.1, 1.2, 1.7, "key_board")
    wall_item(p, W, D, "left", 2.6, 1.8, 0.0, 0.5, 0.0, 0.75, "office_panel", collide=True)   # 창 아래 장비대
    wall_item(p, W, D, "left", 2.6, 1.86, 0.0, 0.54, 0.75, 0.78, "office_top")
    wall_item(p, W, D, "left", 2.15, 0.5, 0.2, 0.05, 0.84, 1.16, "monitor")                   # CCTV 모니터
    wall_item(p, W, D, "left", 2.15, 0.44, 0.19, 0.004, 0.87, 1.13, "screen_on")
    wall_item(p, W, D, "left", 2.95, 0.5, 0.1, 0.3, 0.78, 0.9, "console")                     # 점수판 제어기
    wall_item(p, W, D, "left", 3.35, 0.2, 0.12, 0.2, 0.78, 0.92, "rack")                      # 무전기 충전대
    p.box("fridge_small", 0.35, D - 0.38, 0.55, 0.55, 0.0, 0.85, collide=True)
    wall_item(p, W, D, "back", 2.6, 0.35, 0.0, 0.14, 1.35, 1.65, "first_aid")


def gym_hall(ctx):
    """북측 출입홀: 가운데 3m 주동선은 비우고 바닥 매트, 대기 벤치 2개, 우산꽂이, 덧신함, 이용 안내판·행사 일정표·피난도,
    트로피 진열장, 행사 사진, 분실물함, AED, 휠체어, 방문객 확인대"""
    p, W, D = ctx.p, ctx.W, ctx.D
    p.box("mat_dark", W / 2, 0.95, 3.0, 1.5, 0.0, 0.012)
    for u in (1.95, 8.55):
        bench(p, u, 0.3, 1.0, along_u=True)
    for u in (2.62, 7.88):
        p.cyl("bin_gray", u, 0.3, 0.3, 0.0, 0.6)
        for k in range(3):
            p.box("umbrella", u - 0.06 + 0.06 * k, 0.3, 0.035, 0.035, 0.3, 0.9 + 0.05 * k)
    # 마룻바닥 쪽 벽 가운데: 덧신함, 그 위 안내판·일정표·피난도 / 서쪽: 트로피 진열장 / 동쪽: 분실물함·AED
    wall_item(p, W, D, "back", W / 2, 2.2, 0.0, 0.4, 0.0, 0.9, "shoe_rack", collide=True)
    for k in range(1, 5):
        wall_item(p, W, D, "back", W / 2 - 1.1 + 0.44 * k, 0.012, 0.4, 0.006, 0.05, 0.85, "locker_line")
    wall_item(p, W, D, "back", W / 2 - 0.85, 0.9, 0.0, 0.02, 1.2, 2.0, "sign_blue")
    wall_item(p, W, D, "back", W / 2 + 0.1, 0.8, 0.0, 0.02, 1.2, 2.0, "whiteboard")
    wall_item(p, W, D, "back", W / 2 + 0.95, 0.6, 0.0, 0.02, 1.3, 1.9, "floor_map")
    # 좌·우 계단 입구(마룻바닥 쪽 벽 양 끝)는 비워야 하므로 진열장·분실물함은 화장실 문과 계단 입구 사이 옆벽에 붙인다
    glass_cabinet(p, W, D, "left", 2.62, 1.1, 0.42, 1.9, ("trophy", "trophy", "photo", "trophy"), "gh", "cabinet_wood", 0.6, 3, 0.9)
    wall_item(p, W, D, "right", 2.62, 0.6, 0.02, 0.45, 0.0, 0.8, "lost_box", collide=True)
    wall_item(p, W, D, "right", 2.62, 0.4, 0.0, 0.16, 1.1, 1.55, "aed")
    wall_item(p, W, D, "right", 2.62, 0.3, 0.0, 0.01, 1.65, 1.85, "sign_green")
    p.box("metal_dark", W / 2 - 1.55, D - 0.5, 0.55, 0.6, 0.45, 0.5)                          # 휠체어
    p.box("metal_dark", W / 2 - 1.55, D - 0.22, 0.5, 0.05, 0.5, 0.95)
    # 방문객 확인대 (동쪽 계단 입구와 방화문 사이는 막지 않는다)
    p.box("office_panel", 8.2, 2.35, 1.0, 0.5, 0.0, 1.0, collide=True)
    p.box("office_top", 8.2, 2.35, 1.06, 0.56, 1.0, 1.04)
    p.box("attendance", 8.2, 2.35, 0.3, 0.22, 1.04, 1.06)
    for a in (0.95, W - 0.95):                                                                 # 행사 사진 (계단 입구 옆 벽)
        wall_item(p, W, D, "back", a, 0.9, 0.0, 0.03, 1.3, 1.9, "frame_wood")
        wall_item(p, W, D, "back", a, 0.8, 0.03, 0.004, 1.36, 1.84, "photo")
    wall_label(ctx, "front", 1.35, 2.75, "OO고등학교 강당", 0.05, 0.0045, 48)


def gym_toilet(ctx, men=False):
    """강당 화장실 (좁고 긴 방, 문은 끝 벽): 문 옆 세면대와 거울, 안쪽 대변기 칸 2개, 남자는 옆벽 소변기 2개"""
    p, W, D = ctx.p, ctx.W, ctx.D
    doors = ctx.doors_on("front")
    dm = doors[0].mid if doors else W / 2
    sink_side = "left" if dm > W / 2 else "right"
    other = "right" if sink_side == "left" else "left"
    for k in range(1 if men else 2):
        a = 1.85 + 0.75 * k
        wall_item(p, W, D, sink_side, a, 0.6, 0.0, 0.45, 0.78, 0.86, "counter_white", collide=True)
        wall_item(p, W, D, sink_side, a, 0.42, 0.06, 0.32, 0.86, 0.9, "porcelain")
        wall_item(p, W, D, sink_side, a, 0.04, 0.02, 0.1, 0.9, 1.08, "steel")
        wall_item(p, W, D, sink_side, a, 0.5, 0.0, 0.02, 1.2, 1.85, "mirror")
    if men:
        for k in range(2):
            a = 2.75 + 0.65 * k
            wall_item(p, W, D, other, a, 0.36, 0.0, 0.3, 0.45, 1.05, "porcelain")
            wall_item(p, W, D, other, a + 0.32, 0.03, 0.0, 0.42, 0.6, 1.5, "toilet_partition")
    v0 = D - 1.45
    p.box("stall_panel", W / 2, (v0 + D) / 2, 0.03, D - v0, 0.12, 2.0, collide=True)
    for k in range(2):
        cu = W * (0.25 + 0.5 * k)
        p.box("stall_door", cu, v0, W / 2 - 0.14, 0.03, 0.12, 2.0, collide=True)
        p.box("porcelain", cu, D - 0.45, 0.38, 0.55, 0.0, 0.42)
        p.box("porcelain", cu, D - 0.12, 0.42, 0.18, 0.42, 0.8)
    p.box("bin_gray", 0.2 if sink_side == "right" else W - 0.2, 1.5, 0.28, 0.28, 0.0, 0.5)
    p.box("drain", W / 2, 2.6, 0.2, 0.2, 0.0, 0.006)


def _bench_u(p, u0, u1, s, top, mat, collide=True):
    """u 방향 장의자 (북측 관람석): 앉는 판 + 받침"""
    p.box(mat, (u0 + u1) / 2, s, u1 - u0, 0.34, top + 0.39, top + 0.43)
    n = max(2, int((u1 - u0) / 1.5) + 1)
    for i in range(n):
        uu = u0 + 0.12 + (u1 - u0 - 0.24) * i / (n - 1)
        p.box("metal_dark", uu, s, 0.05, 0.28, top, top + 0.39)
    if collide:
        p.solid((u0 + u1) / 2, s, u1 - u0, 0.34, top, top + 0.45)


def _bench_s(p, u, s0, s1, top, mat, collide=True):
    """s 방향 장의자 (서·동 날개 관람석)"""
    p.box(mat, u, (s0 + s1) / 2, 0.34, s1 - s0, top + 0.39, top + 0.43)
    n = max(2, int((s1 - s0) / 1.5) + 1)
    for i in range(n):
        ss = s0 + 0.12 + (s1 - s0 - 0.24) * i / (n - 1)
        p.box("metal_dark", u, ss, 0.28, 0.05, top, top + 0.39)
    if collide:
        p.solid(u, (s0 + s1) / 2, 0.34, s1 - s0, top, top + 0.45)


def upper(batch, sw, path):
    """2층 관람석: 단마다 장의자형 고정석, 북측 최상단 중앙 방송·음향 부스(전면 유리)와 좌우 카메라 촬영대,
    무대 상부 전광 점수판, 비상구 표지, 북측 벽 공연 포스터"""
    p = gp(batch, path, 0.0, seed=23)
    mats = ("seat_plastic", "bench_wood")
    for side in (-1, 1):                                  # 서·동 날개: 단의 벽 쪽에 장의자, 앞은 통로
        for i, (u0, u1, top) in enumerate(WING_ROWS):
            bu = u0 + 0.22 if side < 0 else 40.0 - u0 - 0.22
            for s0, s1 in ((9.4, WING_AISLE[0] - 0.15), (WING_AISLE[1] + 0.15, 20.8)):
                _bench_s(p, bu, s0, s1, top, mats[i % 2])
    for i, (s0, s1, top) in enumerate(NORTH_ROWS):        # 북측: 단의 뒤쪽에 장의자 (가운데 계단 통로는 비움)
        for u0, u1 in ((8.4, 19.1), (20.9, 31.6)):
            _bench_u(p, u0, u1, s1 - 0.22, top, mats[i % 2])
    for u0, u1 in ((14.7, 17.4), (22.6, 25.3)):
        _bench_u(p, u0, u1, 21.25, REAR, "seat_plastic")
    # 방송·음향 부스 (뒤쪽 통로 5.0m 위, 무대 정면): 낮은 벽 + 전면·옆면 유리, 뒤쪽 출입구
    b0, b1, s0, s1 = 17.7, 22.3, 22.2, 24.3
    y = REAR
    p.box("booth_wall", (b0 + b1) / 2, s0, b1 - b0, 0.08, y, y + 0.95, collide=True)
    p.box("glass", (b0 + b1) / 2, s0, b1 - b0 - 0.1, 0.02, y + 0.95, y + 2.1)
    for u in (b0, b1):
        p.box("booth_wall", u, (s0 + s1) / 2, 0.08, s1 - s0, y, y + 0.95, collide=True)
        p.box("glass", u, (s0 + s1) / 2, 0.02, s1 - s0 - 0.1, y + 0.95, y + 2.1)
        p.box("frame_alu", u, s0, 0.08, 0.08, y + 0.95, y + 2.15)
        p.box("frame_alu", u, s1, 0.08, 0.08, y, y + 2.15)
    p.box("booth_wall", (b0 + 20.9) / 2, s1, 20.9 - b0, 0.08, y, y + 2.1, collide=True)       # 뒤벽 (동쪽 끝은 출입구)
    p.box("frame_alu", (b0 + b1) / 2, s0, b1 - b0 + 0.08, 0.08, y + 2.1, y + 2.18)
    p.box("console", 20.0, s0 + 0.5, 3.6, 0.7, y + 0.72, y + 0.76)                             # 음향·조명 콘솔 책상
    p.box("office_panel", 20.0, s0 + 0.5, 3.5, 0.6, y, y + 0.72, collide=True)
    for u in (19.0, 20.3):
        p.box("monitor", u, s0 + 0.3, 0.5, 0.04, y + 0.84, y + 1.16)
        p.box("keyboard", u, s0 + 0.62, 0.42, 0.14, y + 0.76, y + 0.775)
    p.box("rack", 21.3, s0 + 0.5, 0.6, 0.4, y + 0.76, y + 0.9)                                 # 믹서
    p.box("panel_red", 18.2, s0 + 0.5, 0.14, 0.14, y + 0.76, y + 0.84)                         # 비상방송 버튼
    for u in (19.2, 20.6):
        p.box("chair_office", u, s0 + 1.25, 0.46, 0.44, y + 0.44, y + 0.5)
        p.box("chair_office", u, s0 + 1.47, 0.44, 0.06, y + 0.5, y + 0.95)
        p.box("metal_dark", u, s0 + 1.25, 0.06, 0.06, y, y + 0.44)
    p.box("rack", b0 + 0.4, s1 - 0.45, 0.6, 0.6, y, y + 1.6, collide=True)                     # 앰프 랙
    for k in range(4):
        p.box("led_green", b0 + 0.71, s1 - 0.6 + 0.1 * k, 0.006, 0.03, y + 1.3, y + 1.33)
    for u0, u1 in ((15.6, 17.3), (22.7, 24.4)):                                                # 카메라 촬영대
        uc = (u0 + u1) / 2
        p.box("stair", uc, 23.1, u1 - u0, 1.6, y, y + 0.3, collide=True)
        for du in (-0.25, 0.25):
            p.box("metal_dark", uc + du, 23.0, 0.04, 0.04, y + 0.3, y + 1.5)
        p.box("metal_dark", uc, 23.35, 0.04, 0.04, y + 0.3, y + 1.5)
        p.box("camera", uc, 23.05, 0.3, 0.5, y + 1.5, y + 1.78)
    # 무대 상부 전광 점수판 (코트 쪽을 본다)
    p.box("rack", 20.0, 6.14 + 0.16, 3.2, 0.14, 7.3, 8.5)
    for k, du in enumerate((-1.1, -0.6, 0.6, 1.1)):
        p.box("led_red", 20.0 + du, 6.14 + 0.235, 0.34, 0.012, 7.6, 8.2)
    p.box("led_green", 20.0, 6.14 + 0.235, 0.5, 0.012, 8.25, 8.4)
    for u in (0.27, 39.73):                                                                    # 비상구 유도등
        p.box("sign_green", u, 7.8, 0.02, 0.6, REAR + 2.3, REAR + 2.55)
    for k, m in enumerate(("art_red", "poster_night", "art_yellow", "art_blue", "paper")):     # 북측 벽 공연 포스터
        p.box(m, 9.5 + 1.1 * k, 25.735, 0.8, 0.01, REAR + 1.2, REAR + 2.3)
    _nlabel2(sw, path, 11.7, REAR + 2.55, "공연·행사 포스터")


def _nlabel2(sw, path, u, h, text, size=0.004, font=44, color=(0.14, 0.16, 0.2)):
    label(sw, path, (u - 20.0, h, GYM_Z1 - 25.69), text, size, font, color, rows_y(0.0))
