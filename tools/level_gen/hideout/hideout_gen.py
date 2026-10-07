# -*- coding: utf-8 -*-
"""프로젝트 벨카 - 프롤로그 사비·샤무 아지트 맵 생성기

실행: python tools/level_gen/hideout/hideout_gen.py
설계: 기획서/04. 맵 및 환경/아지트_맵_상세.md
출력: scenes/prologue/HideoutWorld.tscn, scenes/chapters/Prologue_Hideout.tscn

학교 맵 생성기 부품(SceneWriter, Batch, 재질·셰이더, 계단)을 그대로 쓴다.
좌표: 건물 안쪽 바닥 x 0~14 (서->동), z 0~10 (남->북). 남쪽이 골목(정면). 1층 y=0, 2층 y=3.8.
카메라는 북쪽 위에서 남쪽을 내려다본다: 보여야 하는 벽 장식(조사 보드·장비 벽·작업대)은 남·서쪽 벽에 둔다.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "school"))
from emit import SceneWriter, tf, q
from geometry import Rect
from batch import Batch, rows_y
from structure import emit_zone, emit_light
from stairs2 import flight, flat_rail, stair_path
from source import ROOT
import palette

W, D = 14.0, 10.0          # 건물 안쪽 크기
LEVEL_H = 3.8              # 층 높이 (WorldPhaseController.LEVEL_HEIGHT)
SLAB = 0.2
WALL_T = 0.2
F2 = LEVEL_H               # 2층 바닥 높이
ROOF_Y = 2 * LEVEL_H
# 철계단: 1층 북쪽에서 남쪽으로 올라 2층 남동쪽 참에 도착
STAIR_X = (12.6, 13.8)
STAIR_Z = (8.6, 2.6)       # (아래 끝, 위 끝)
SPAWN = (10.0, 0.05, 2.2)
BUILDING = "hideout"
FOOTPRINT = Rect(-WALL_T, -WALL_T, W + WALL_T, D + WALL_T)

# 아지트 전용 재질 (학교 팔레트에 없는 것만): (선형 RGB, 옵션)
EXTRA_MATS = {
    "hide_wall_out": ((0.42, 0.4, 0.37), {}),            # 바깥 벽 (낡은 회색 페인트)
    "hide_wall_2f": ((0.78, 0.74, 0.66), {}),            # 2층 안쪽 벽 (누런 벽지)
    "hide_floor_2f": ((0.42, 0.3, 0.2), {}),             # 2층 마루
    "shutter": ((0.5, 0.52, 0.54), {"metallic": 0.4}),
    "van_body": ((0.68, 0.7, 0.72), {"metallic": 0.2}),
    "rug": ((0.35, 0.16, 0.14), {}),
    "red_string": ((0.75, 0.05, 0.05), {}),
}

LEVELS = ["1F", "2F", "Roof"]


def lv(name, child="Arch"):
    return "Buildings/%s/%s/%s" % (BUILDING, name, child)


class Builder:
    """월드 좌표 박스 도우미 (x0~x1, y0~y1, z0~z1)."""

    def __init__(self, batch):
        self.b = batch

    def box(self, c, mat, x0, x1, y0, y1, z0, z1, collide=False, groups=(), tag="prop", yaw=0.0):
        rows = rows_y(yaw) if yaw else (1, 0, 0, 0, 1, 0, 0, 0, 1)
        self.b.box(c, mat, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), collide, groups, tag, rows)

    def solid(self, c, x0, x1, y0, y1, z0, z1, tag="prop_col"):
        self.b.solid(c, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), (), tag)

    def cyl(self, c, mat, x, z, d, y0, y1):
        self.b.cyl(c, mat, (x, (y0 + y1) / 2, z), d, y1 - y0)

    def wall(self, c, mat, axis, fixed, a0, a1, y0, y1, gaps=(), t=WALL_T, groups=()):
        """axis 'x'면 z=fixed 선을 따라 x a0~a1, 'z'면 x=fixed 선을 따라 z a0~a1.
        gaps: [(b0, b1, sill, head)] 구간은 sill 아래·head 위만 채운다 (문은 sill=y0)."""
        cuts = sorted(gaps)
        pos = a0
        pieces = []
        for b0, b1, sill, head in cuts:
            pieces.append((pos, b0, y0, y1))
            if sill > y0:
                pieces.append((b0, b1, y0, sill))
            if head < y1:
                pieces.append((b0, b1, head, y1))
            pos = b1
        pieces.append((pos, a1, y0, y1))
        for p0, p1, h0, h1 in pieces:
            if p1 - p0 < 1e-3 or h1 - h0 < 1e-3:
                continue
            if axis == "x":
                self.box(c, mat, p0, p1, h0, h1, fixed - t / 2, fixed + t / 2, True, groups, "wall")
            else:
                self.box(c, mat, fixed - t / 2, fixed + t / 2, h0, h1, p0, p1, True, groups, "wall")


# ---------------------------------------------------------------- 구조

def structure(B):
    a1, a2, ar = lv("1F"), lv("2F"), lv("Roof")
    # 바닥·천장 슬래브 (2층 바닥에는 계단 구멍)
    B.box(a1, "floor_concrete", 0, W, -SLAB, 0, 0, D, True, tag="floor")
    sx0, sx1 = STAIR_X
    sz_top, sz_low = STAIR_Z[1], STAIR_Z[0]
    for x0, x1, z0, z1, mat in ((0, sx0, 0, D, "hide_floor_2f"), (sx1, W, 0, D, "hide_floor_2f"),
                                (sx0, sx1, 0, sz_top, "hide_floor_2f"), (sx0, sx1, sz_low, D, "hide_floor_2f")):
        B.box(a2, mat, x0, x1, F2 - SLAB, F2, z0, z1, True, tag="floor")
    B.box(ar, "roof_metal", -WALL_T - 0.3, W + WALL_T + 0.3, ROOF_Y, ROOF_Y + 0.2, -WALL_T - 0.3, D + WALL_T + 0.3, True, tag="roof")

    # 1층 바깥 벽: 남쪽 셔터·철문, 서쪽 높은 창
    wo = "hide_wall_out"
    B.wall(a1, wo, "x", -WALL_T / 2, -WALL_T, W + WALL_T, 0, LEVEL_H,
           [(0.8, 6.2, 0.0, 3.0), (10.6, 11.6, 0.0, 2.1)])
    B.wall(a1, wo, "x", D + WALL_T / 2, -WALL_T, W + WALL_T, 0, LEVEL_H)
    B.wall(a1, wo, "z", -WALL_T / 2, 0, D, 0, LEVEL_H, [(2.0, 3.6, 2.2, 3.0), (6.4, 8.0, 2.2, 3.0)])
    B.wall(a1, wo, "z", W + WALL_T / 2, 0, D, 0, LEVEL_H)
    # 셔터 (가로 골이 있는 철판, 닫힘)
    B.box(a1, "shutter", 0.8, 6.2, 0.0, 3.0, -0.16, -0.08, True, tag="shutter")
    for k in range(15):
        y = 0.1 + k * 0.2
        B.box(a1, "metal_dark", 0.8, 6.2, y, y + 0.025, -0.06, -0.045, tag="shutter_rib")
    B.box(a1, "metal_dark", 0.6, 6.4, 2.97, 3.33, -0.27, -0.21, tag="shutter_box")
    # 철문 (잠김)
    B.box(a1, "metal_dark", 10.6, 11.6, 0.0, 2.1, -0.14, -0.06, True, tag="door")
    B.box(a1, "steel", 11.42, 11.5, 0.95, 1.05, -0.05, -0.02, tag="door_handle")
    for z0 in (2.0, 6.4):                                # 1층 높은 창
        window(B, a1, "z", 0.0, z0, z0 + 1.6, 2.2, 3.0, inside=+1)

    # 2층 바깥 벽: 남쪽·서쪽 창 (블라인드)
    w2 = "hide_wall_2f"
    south_win = [(5.9, 7.4, 1.0, 2.4), (8.2, 10.2, 1.2, 2.4)]
    west_win = [(7.4, 9.0, 1.0, 2.4)]
    B.wall(a2, wo, "x", -WALL_T / 2, -WALL_T, W + WALL_T, F2, ROOF_Y, [(a, b, F2 + s, F2 + h) for a, b, s, h in south_win])
    B.wall(a2, wo, "x", D + WALL_T / 2, -WALL_T, W + WALL_T, F2, ROOF_Y)
    B.wall(a2, wo, "z", -WALL_T / 2, 0, D, F2, ROOF_Y, [(a, b, F2 + s, F2 + h) for a, b, s, h in west_win])
    B.wall(a2, wo, "z", W + WALL_T / 2, 0, D, F2, ROOF_Y)
    for a, b, s, h in south_win:
        window(B, a2, "x", 0.0, a, b, F2 + s, F2 + h, inside=+1)
    for a, b, s, h in west_win:
        window(B, a2, "z", 0.0, a, b, F2 + s, F2 + h, inside=+1)
    # 2층 칸막이: 욕실(남서), 침실 2개(북쪽)
    B.wall(a2, "wall_tile_light", "z", 2.6, 0.0, 2.6, F2, ROOF_Y, [(1.5, 2.4, F2, F2 + 2.1)], t=0.12)
    B.wall(a2, "wall_tile_light", "x", 2.6, 0.0, 2.66, F2, ROOF_Y, t=0.12)
    B.wall(a2, w2, "x", 6.6, 5.6, 12.4, F2, ROOF_Y, [(6.4, 7.4, F2, F2 + 2.2), (10.2, 11.2, F2, F2 + 2.2)], t=0.12)
    for x in (5.6, 8.9, 12.4):
        B.wall(a2, w2, "z", x, 6.66, D, F2, ROOF_Y, t=0.12)
    # 침실 입구 커튼 (위쪽만 걸린 짧은 커튼: 지나갈 수 있다)
    for x0, x1, mat in ((6.4, 7.4, "curtain"), (10.2, 11.2, "curtain_light")):
        B.box(a2, mat, x0 + 0.03, x1 - 0.03, F2 + 1.3, F2 + 2.15, 6.62, 6.66, tag="curtain")
        B.box(a2, "metal_dark", x0 + 0.02, x1 - 0.02, F2 + 2.15, F2 + 2.18, 6.6, 6.68, tag="curtain_rod")

    # 계단 (서쪽 난간) + 2층 계단 구멍 둘레 난간
    s = lv("1F", "Stairs")
    # 난간 충돌판은 아래쪽 0.8m를 잘라 둔다: 계단 발치에 옆(서쪽)에서 들어와도 판 끝에 걸리지 않게
    flight(B.b, s, "z", STAIR_Z[0], STAIR_Z[1], 0.0, F2, STAIR_X[0], STAIR_X[1], "metal_grate", (), ("w0",),
           rail_trim=(0.8, 0.0))
    stair_path(sw_ref[0], s, [(13.2, 0.0, STAIR_Z[0] + 0.8), (13.2, F2, STAIR_Z[1] - 0.6)], name="HideoutStairPath")
    flat_rail(B.b, a2, "z", STAIR_Z[1] + 0.6, STAIR_Z[0], STAIR_X[0] - 0.04, F2)
    flat_rail(B.b, a2, "x", STAIR_X[0], STAIR_X[1], STAIR_Z[0] + 0.04, F2)


def window(B, c, axis, fixed, a0, a1, y0, y1, inside=+1):
    """벽 구멍에 창틀·유리·내린 블라인드. inside: 안쪽 방향(+1 = 좌표가 커지는 쪽)."""
    g = ("window_pane",)
    if axis == "x":
        B.box(c, "glass", a0, a1, y0, y1, fixed - 0.02, fixed + 0.02, groups=g, tag="glass")
        for x in (a0, a1 - 0.05):
            B.box(c, "win_frame", x, x + 0.05, y0, y1, fixed - 0.06, fixed + 0.06, tag="win_frame")
        B.box(c, "sill", a0 - 0.05, a1 + 0.05, y0 - 0.04, y0, fixed, fixed + inside * 0.16, tag="sill")
        y = y1 - 0.06
        while y > y0 + 0.08:
            z0, z1 = sorted((fixed + inside * 0.12, fixed + inside * 0.13))
            B.box(c, "blind", a0 + 0.04, a1 - 0.04, y - 0.035, y, z0, z1, tag="blind")
            y -= 0.06
    else:
        B.box(c, "glass", fixed - 0.02, fixed + 0.02, y0, y1, a0, a1, groups=g, tag="glass")
        for z in (a0, a1 - 0.05):
            B.box(c, "win_frame", fixed - 0.06, fixed + 0.06, y0, y1, z, z + 0.05, tag="win_frame")
        B.box(c, "sill", fixed, fixed + inside * 0.16, y0 - 0.04, y0, a0 - 0.05, a1 + 0.05, tag="sill")
        y = y1 - 0.06
        while y > y0 + 0.08:
            x0, x1 = sorted((fixed + inside * 0.12, fixed + inside * 0.13))
            B.box(c, "blind", x0, x1, y - 0.035, y, a0 + 0.04, a1 - 0.04, tag="blind")
            y -= 0.06


# ---------------------------------------------------------------- 1층: 차고·장비실

def garage(B):
    p = lv("1F", "Props")
    # 승합차 (셔터를 향해 주차, 앞이 남쪽)
    x0, x1, z0, z1 = 2.0, 4.0, 1.0, 5.8
    B.box(p, "van_body", x0, x1, 0.38, 1.25, z0, z1, True, tag="van")
    B.box(p, "van_body", x0 + 0.03, x1 - 0.03, 1.25, 2.05, z0 + 0.9, z1, True, tag="van")
    B.box(p, "car_glass", x0 + 0.08, x1 - 0.08, 1.3, 1.95, z0 + 0.86, z0 + 0.9, tag="van_glass")
    for zz in (z0 + 1.6, z0 + 3.1):
        for xx in (x0 - 0.005, x1 + 0.005):
            B.box(p, "car_glass", xx - 0.01, xx + 0.01, 1.35, 1.85, zz, zz + 1.1, tag="van_glass")
    for zz in (z0 + 0.8, z1 - 0.8):
        for xx in (x0 + 0.1, x1 - 0.32):
            B.box(p, "tire", xx, xx + 0.22, 0.0, 0.66, zz - 0.33, zz + 0.33, tag="tire")
    B.box(p, "lamp_head", x0 + 0.15, x0 + 0.5, 0.85, 1.0, z0 - 0.02, z0, tag="van_light")
    B.box(p, "lamp_head", x1 - 0.5, x1 - 0.15, 0.85, 1.0, z0 - 0.02, z0, tag="van_light")
    B.box(p, "mat_dark", x0 + 0.3, x1 - 0.3, 0.002, 0.006, z0 + 1.0, z1 - 1.0, tag="stain")

    # 장비 벽 (서쪽 벽, 카메라 쪽을 향함): 타공판 + 장비 + 철제 사물함 + 장비 가방
    B.box(p, "pegboard", 0.0, 0.04, 0.8, 2.1, 6.6, 9.0, tag="pegboard")
    for z, w, h0, h1, mat in ((6.8, 0.9, 1.6, 1.75, "case_black"), (7.9, 0.9, 1.85, 1.95, "metal_dark"),
                              (6.9, 0.12, 0.9, 1.5, "steel"), (7.3, 0.12, 0.9, 1.5, "steel"), (8.1, 0.7, 1.0, 1.6, "vest")):
        B.box(p, mat, 0.04, 0.14, h0, h1, z, z + w, tag="gear")
    B.box(p, "locker_gray", 0.0, 0.5, 0.0, 2.0, 9.1, D, True, tag="locker")
    B.box(p, "metal_dark", 0.5, 0.505, 0.1, 1.9, 9.53, 9.55, tag="locker_line")
    B.box(p, "bag", 0.4, 1.3, 0.0, 0.45, 7.0, 7.8, True, tag="gear_bag")      # 샤무 장비 가방
    B.box(p, "case_black", 0.3, 0.8, 0.0, 0.35, 8.1, 8.9, True, tag="gear_case")
    # 북쪽 벽: 타이어와 철제 선반 (낮은 물건)
    B.box(p, "shelf_metal", 1.2, 4.2, 0.0, 1.2, D - 0.45, D, True, tag="shelf")
    for k in range(3):
        B.box(p, "tire", 4.5, 5.2, k * 0.22, k * 0.22 + 0.2, D - 0.75, D - 0.05, tag="tire_stack")
    B.solid(p, 4.5, 5.2, 0.0, 0.66, D - 0.75, D - 0.05)

    # 운동 공간: 매트, 샌드백, 벤치, 덤벨 받침
    B.box(p, "rubber_mat", 6.8, 11.0, 0.0, 0.02, 3.4, 7.4, tag="mat")
    B.cyl(p, "sandbag", 8.0, 5.6, 0.42, 0.7, 1.9)
    B.solid(p, 7.8, 8.2, 0.7, 1.9, 5.4, 5.8)
    B.box(p, "metal_dark", 7.99, 8.01, 1.9, F2 - SLAB - 0.02, 5.59, 5.61, tag="chain")
    B.box(p, "bench_wood", 9.4, 10.6, 0.02, 0.45, 4.2, 4.6, True, tag="bench")
    B.box(p, "rack", 10.2, 10.9, 0.02, 0.7, 6.4, 7.0, True, tag="dumbbell_rack")
    for k in range(3):
        B.box(p, "metal_dark", 10.25 + k * 0.22, 10.4 + k * 0.22, 0.7, 0.82, 6.5, 6.9, tag="dumbbell")

    # 작업대 (남쪽 벽, 셔터와 철문 사이)
    B.box(p, "workbench", 6.6, 10.2, 0.0, 0.92, 0.0, 0.75, True, tag="workbench")
    B.box(p, "pegboard", 6.8, 10.0, 1.1, 2.3, 0.0, 0.04, tag="pegboard")
    for i in range(6):
        x = 7.1 + i * 0.5
        B.box(p, "steel" if i % 2 else "metal_dark", x, x + 0.06, 1.3, 1.6 + 0.1 * (i % 3), 0.04, 0.1, tag="tool")
    B.box(p, "metal_dark", 7.0, 7.3, 0.92, 1.12, 0.3, 0.55, tag="vise")
    B.box(p, "box", 8.8, 9.4, 0.92, 1.2, 0.15, 0.6, tag="parts_box")
    B.box(p, "paint_can", 9.6, 9.85, 0.92, 1.18, 0.25, 0.5, tag="can")
    # 계단 밑 박스
    for i, (z0, h) in enumerate(((3.0, 0.6), (3.7, 0.45), (4.4, 0.3))):
        B.box(p, "box", 12.7, 13.7, 0.0, h, z0, z0 + 0.6, True, tag="under_stair_box")
    # 문 옆 신발장과 매트
    B.box(p, "shoe_rack", 11.75, 12.5, 0.0, 0.9, 0.0, 0.35, True, tag="shoe_rack")
    B.box(p, "mat_dark", 10.5, 11.7, 0.0, 0.015, 0.1, 0.9, tag="door_mat")


# ---------------------------------------------------------------- 2층: 사무실 겸 집

def upstairs(B):
    p = lv("2F", "Props")
    y = F2
    # 욕실 (남서): 세면대, 변기, 샤워 칸
    B.box(p, "floor_toilet", 0.0, 2.54, y, y + 0.01, 0.0, 2.54, tag="bath_floor")
    B.box(p, "porcelain", 0.0, 0.5, y + 0.01, y + 0.85, 1.6, 2.3, True, tag="sink")
    B.box(p, "mirror", 0.0, 0.02, y + 1.2, y + 1.9, 1.65, 2.25, tag="mirror")
    B.box(p, "porcelain", 1.7, 2.2, y + 0.01, y + 0.45, 0.0, 0.7, True, tag="toilet")
    B.box(p, "porcelain", 1.75, 2.15, y + 0.45, y + 0.85, 0.0, 0.2, tag="toilet_tank")
    B.box(p, "glass_frosted", 0.0, 1.2, y, y + 2.0, 1.18, 1.22, True, tag="shower_glass")
    B.box(p, "drain_grate", 0.4, 0.6, y + 0.01, y + 0.02, 0.4, 0.6, tag="drain")

    # 사비 작업 공간 (서쪽 벽): ㄱ자 책상, 모니터 6대, 서버 랙, 의자
    B.box(p, "desk_top", 0.0, 0.9, y + 0.72, y + 0.76, 3.0, 6.6, True, tag="desk")
    B.box(p, "desk_top", 0.9, 2.2, y + 0.72, y + 0.76, 6.0, 6.6, True, tag="desk")
    for z in (3.05, 6.5):
        B.box(p, "desk_frame", 0.05, 0.85, y, y + 0.72, z, z + 0.05, tag="desk_leg")
    B.box(p, "desk_frame", 2.1, 2.15, y, y + 0.72, 6.05, 6.55, tag="desk_leg")
    for i, (z0, h0) in enumerate(((3.2, 0.82), (4.25, 0.82), (5.3, 0.82), (3.2, 1.42), (4.25, 1.42), (5.3, 1.42))):
        B.box(p, "monitor", 0.12, 0.18, y + h0, y + h0 + 0.55, z0, z0 + 0.98, tag="monitor")
        B.box(p, "screen_on", 0.18, 0.185, y + h0 + 0.04, y + h0 + 0.51, z0 + 0.04, z0 + 0.94, tag="screen")
    B.box(p, "metal_dark", 0.08, 0.12, y + 0.76, y + 1.97, 4.2, 4.3, tag="monitor_arm")
    B.box(p, "keyboard", 0.4, 0.6, y + 0.76, y + 0.79, 4.0, 4.6, tag="keyboard")
    B.box(p, "terminal", 0.3, 0.7, y + 0.76, y + 0.78, 5.0, 5.4, tag="hack_pad")         # 해킹 패드
    B.box(p, "pc_tower", 0.1, 0.6, y, y + 0.5, 5.8, 6.0, tag="pc")
    B.box(p, "chair_office", 0.95, 1.5, y, y + 1.1, 4.0, 4.55, True, tag="chair")
    B.box(p, "rack", 0.0, 0.7, y, y + 1.9, 6.75, 7.3, True, tag="server_rack")
    for k in range(6):
        B.box(p, "led_green" if k % 2 else "led_red", 0.7, 0.71, y + 0.3 + k * 0.25, y + 0.33 + k * 0.25, 6.9, 6.95, tag="led")
    B.box(p, "cable_tray", 0.01, 0.1, y + 0.05, y + 0.12, 3.0, 6.7, tag="cables")

    # 조사 보드 (남쪽 벽, 욕실 옆): 코르크 + 사진 + 붉은 실. 카메라 쪽(북쪽)을 향한다
    zb = 0.04
    B.box(p, "cork", 2.8, 5.7, y + 0.9, y + 2.3, 0.0, zb, tag="board")
    photos = [(2.95, 1.9), (3.4, 1.6), (3.85, 2.0), (4.3, 1.7), (4.75, 2.0), (5.2, 1.5), (3.05, 1.15), (3.9, 1.2), (4.8, 1.1)]
    for i, (px, py) in enumerate(photos):
        B.box(p, "photo" if i % 3 else "paper", px, px + 0.24, y + py, y + py + 0.3, zb, zb + 0.01, tag="photo")
    for (ax, ay), (bx, by) in ((photos[0], photos[2]), (photos[2], photos[4]), (photos[1], photos[7]), (photos[7], photos[8])):
        # 붉은 실: 사진 사이를 잇는 짧은 수평 띠 (기울기는 표현하지 않는다)
        B.box(p, "red_string", min(ax, bx) + 0.12, max(ax, bx) + 0.12, y + (ay + by) / 2 + 0.14, y + (ay + by) / 2 + 0.155, zb + 0.01, zb + 0.015, tag="string")
    B.box(p, "table_top", 3.2, 5.2, y + 0.7, y + 0.74, 0.1, 0.7, True, tag="board_table")
    B.box(p, "file_box", 3.4, 3.9, y + 0.74, y + 1.0, 0.2, 0.6, tag="files")
    B.box(p, "paper_old", 4.3, 4.9, y + 0.74, y + 0.76, 0.2, 0.6, tag="papers")

    # 응접 공간: 러그, 소파 2개, 낮은 테이블, 스탠드 조명
    B.box(p, "rug", 3.2, 7.2, y, y + 0.012, 3.0, 5.8, tag="rug")
    B.box(p, "sofa", 3.4, 4.2, y + 0.012, y + 0.85, 3.2, 5.6, True, tag="sofa")
    B.box(p, "sofa_blue", 6.2, 7.0, y + 0.012, y + 0.85, 3.2, 5.6, True, tag="sofa")
    B.box(p, "table_low", 4.8, 5.6, y + 0.012, y + 0.42, 3.6, 5.2, True, tag="table")
    for i, (px, pz) in enumerate(((4.9, 3.8), (5.1, 4.3), (5.25, 4.75))):
        B.box(p, "photo", px, px + 0.22, y + 0.42, y + 0.425, pz, pz + 0.28, tag="client_photo")
    B.cyl(p, "lamp_post", 7.5, 5.9, 0.05, y, y + 1.6)
    B.cyl(p, "lamp_head", 7.5, 5.9, 0.4, y + 1.55, y + 1.85)

    # 주방·식탁 (남쪽 벽 동쪽)
    B.box(p, "counter_white", 7.6, 11.0, y, y + 0.88, 0.0, 0.65, True, tag="counter")
    B.box(p, "counter_top", 7.58, 11.02, y + 0.88, y + 0.92, 0.0, 0.67, tag="counter_top")
    B.box(p, "stainless", 9.0, 9.6, y + 0.9, y + 0.93, 0.1, 0.55, tag="sink")
    B.box(p, "metal_dark", 7.8, 8.4, y + 0.92, y + 0.95, 0.1, 0.55, tag="stove")
    B.box(p, "fridge_small", 11.1, 11.8, y, y + 1.8, 0.0, 0.7, True, tag="fridge")
    B.box(p, "table_top", 8.6, 10.2, y + 0.72, y + 0.76, 2.0, 3.0, True, tag="dining")
    for x in (8.65, 10.1):
        for z in (2.05, 2.9):
            B.box(p, "wood_dark", x, x + 0.05, y, y + 0.72, z, z + 0.05, tag="table_leg")
    for z0 in (1.4, 3.15):
        B.box(p, "stool_seat", 9.1, 9.7, y, y + 0.45, z0, z0 + 0.45, True, tag="chair")
    B.box(p, "mug_red", 9.0, 9.1, y + 0.76, y + 0.86, 2.3, 2.4, tag="mug")
    B.box(p, "mug_blue", 9.6, 9.7, y + 0.76, y + 0.86, 2.5, 2.6, tag="mug")

    # 샤무 침실 (5.6~8.9): 침대, 옷걸이, 아령
    B.box(p, "bed_frame", 5.75, 7.0, y, y + 0.35, 7.9, 9.94, True, tag="bed")
    B.box(p, "bed", 5.8, 6.95, y + 0.35, y + 0.55, 7.95, 9.9, tag="mattress")
    B.box(p, "pillow", 5.9, 6.85, y + 0.55, y + 0.65, 9.4, 9.8, tag="pillow")
    B.box(p, "rack", 7.8, 8.8, y, y + 1.6, 9.4, 9.9, True, tag="clothes_rack")
    B.box(p, "uniform_navy", 7.9, 8.7, y + 0.7, y + 1.5, 9.6, 9.7, tag="jacket")
    # 사비 침실 (8.9~12.4): 침대, 책 더미, 인형
    B.box(p, "bed_frame", 11.1, 12.3, y, y + 0.35, 7.9, 9.94, True, tag="bed")
    B.box(p, "bed", 11.15, 12.25, y + 0.35, y + 0.55, 7.95, 9.9, tag="mattress")
    B.box(p, "pillow", 11.25, 12.15, y + 0.55, y + 0.65, 9.4, 9.8, tag="pillow")
    for k in range(4):
        B.box(p, ("book_a", "book_b", "book_c", "book_old")[k], 9.1, 9.5, y + k * 0.08, y + (k + 1) * 0.08, 9.3, 9.6, tag="books")
    B.box(p, "cushion", 10.3, 10.7, y, y + 0.35, 9.5, 9.85, tag="plush")


# ---------------------------------------------------------------- 씬

sw_ref = [None]


def main():
    sw = SceneWriter()
    sw_ref[0] = sw
    batch = Batch()
    B = Builder(batch)
    res = {
        "controller": sw.ext_res("Script", "res://scripts/world/WorldPhaseController.gd"),
        "zone": sw.ext_res("Script", "res://scripts/world/ZoneArea.gd"),
        "ambient": sw.ext_res("Script", "res://scripts/world/AmbientSynth.gd"),
        "inspect": sw.ext_res("Script", "res://scripts/interactables/InspectInteractable.gd"),
    }
    mats = palette.make(sw, EXTRA_MATS)
    env = sw.sub_res("env_hideout", "Environment", {
        "background_mode": "1", "background_color": "Color(0.05, 0.05, 0.07, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.85, 0.78, 0.68, 1)", "ambient_light_energy": "0.45",
        "ssao_enabled": "true", "ssao_radius": "1.0", "ssao_intensity": "2.0", "ssao_power": "1.5", "ssao_light_affect": "0.2",
        "adjustment_enabled": "true", "adjustment_saturation": "0.92", "adjustment_contrast": "1.05"})
    sw.node("HideoutWorld", "Node3D", None, {"script": res["controller"], "real_environment": env, "otherworld_environment": env,
                                             "world_environment": 'NodePath("WorldEnvironment")', "ambient": 'NodePath("Ambient")'},
            node_paths=["world_environment", "ambient"])
    sw.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env}, unique=False)
    sun_tf = "Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 30, 0)"
    sw.node("Sun", "DirectionalLight3D", ".", {"transform": sun_tf, "light_energy": "0.25", "light_color": "Color(0.75, 0.8, 1, 1)",
                                               "shadow_enabled": "true"}, unique=False)
    sw.node("Ambient", "AudioStreamPlayer", ".", {"script": res["ambient"]}, unique=False)
    sw.node("Zones", "Node3D", ".", {}, unique=False)

    sw.node("Buildings", "Node3D", ".", {}, unique=False)
    fp = FOOTPRINT
    sw.node(BUILDING, "Node3D", "Buildings", {
        "metadata/building": q(BUILDING), "metadata/footprint": "Rect2(%.3f, %.3f, %.3f, %.3f)" % (fp.x0, fp.z0, fp.w, fp.d),
        "metadata/base_y": "0.0", "metadata/top_y": "%.2f" % (ROOF_Y + 0.2)}, groups=["school_building"], unique=False)
    for idx, name in enumerate(LEVELS):
        sw.node(name, "Node3D", "Buildings/" + BUILDING, {
            "metadata/building": q(BUILDING), "metadata/level_index": str(idx), "metadata/cull_layer": str(2 + idx)},
                groups=["school_level"], unique=False)
        for child in ("Arch", "Stairs", "Props", "Lights"):
            sw.node(child, "Node3D", "Buildings/%s/%s" % (BUILDING, name), {}, unique=False)

    structure(B)
    garage(B)
    upstairs(B)

    # 바깥 바닥 (골목) — 건물 밖으로 나갈 수는 없지만 셔터 앞이 보이게
    sw.node("Site", "Node3D", ".", {}, unique=False)
    B.box("Site", "ground", -6.0, W + 6.0, -0.25, -0.02, -8.0, D + 4.0, True, tag="ground")

    # 조명 (따뜻한 실내등)
    warm = (1.0, 0.86, 0.68)
    for pos, rng, e in (((3.0, 3.2, 3.5), 6.5, 0.9), ((9.0, 3.2, 5.0), 6.5, 0.9), ((8.4, 2.6, 1.0), 4.0, 0.8),
                        ((1.5, 2.8, 8.0), 4.0, 0.7)):
        emit_light(sw, lv("1F", "Lights"), pos, rng, "real_light", warm, e)
    for pos, rng, e in (((1.3, F2 + 3.0, 1.3), 3.0, 0.7), ((2.0, F2 + 2.9, 5.5), 5.0, 0.9), ((5.2, F2 + 2.9, 4.4), 5.5, 0.9),
                        ((9.6, F2 + 2.9, 2.6), 5.0, 0.9), ((7.2, F2 + 2.8, 8.3), 3.5, 0.6), ((10.6, F2 + 2.8, 8.3), 3.5, 0.6),
                        ((13.2, F2 + 3.0, 1.3), 3.0, 0.6)):
        emit_light(sw, lv("2F", "Lights"), pos, rng, "real_light", warm, e)
    # 모니터 불빛 (청록)
    emit_light(sw, lv("2F", "Lights"), (0.9, F2 + 1.3, 4.8), 3.0, "real_light", (0.45, 0.85, 0.95), 0.7)

    # 구역 이름 (HUD)
    zones = [("hide_garage", "아지트 1층 차고", Rect(0, 0, W, D), 0.0, 0),
             ("hide_bath", "아지트 욕실", Rect(0, 0, 2.6, 2.6), F2, 1),
             ("hide_room_shamu", "샤무의 방", Rect(5.6, 6.6, 8.9, D), F2, 1),
             ("hide_room_sabi", "사비의 방", Rect(8.9, 6.6, 12.4, D), F2, 1),
             ("hide_office", "아지트 2층 사무실", Rect(0, 0, W, D), F2, 1)]
    for zid, name, r, y0, idx in zones:
        emit_zone(sw, "Zones", res["zone"], r, y0, 3.0, zid, name, BUILDING, idx)

    # 조사 대상
    sw.node("Inspectables", "Node3D", ".", {}, unique=False)
    for name, pos, iid, point, marker in (
            ("InvestigationBoard", (4.25, F2, 0.2), "hideout_board", (0.0, 1.1, 1.3), 2.4),
            ("SabiMonitors", (0.5, F2, 4.8), "hideout_monitors", (1.3, 1.1, 0.0), 2.1),
            ("ClientPhotos", (5.2, F2, 4.4), "hideout_client_photos", (0.0, 1.1, -1.2), 0.8),
            ("GearBag", (0.85, 0.0, 7.4), "hideout_gear_bag", (1.2, 1.1, 0.0), 0.8)):
        sw.node(name, "Node3D", "Inspectables", {"transform": tf(pos), "script": res["inspect"], "marker_height": "%.2f" % marker,
                                                 "inspect_id": q(iid), "data_path": q("res://data/inspectables/hideout.json")})
        sw.node("InteractionPoint", "Marker3D", "Inspectables/" + name, {"transform": tf(point)}, unique=False)

    sw.node("Spawn", "Marker3D", ".", {"transform": tf(SPAWN)}, unique=False)
    batch.emit(sw, mats)
    os.makedirs(os.path.join(ROOT, "scenes", "prologue"), exist_ok=True)
    path = os.path.join(ROOT, "scenes", "prologue", "HideoutWorld.tscn")
    text = sw.text()
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", path, "nodes=%d boxes=%d" % (len(sw.nodes), len(batch.records)))
    write_chapter()
    return batch


def write_chapter():
    x, y, z = SPAWN
    lines = [
        "[gd_scene load_steps=8 format=3]", "",
        '[ext_resource type="Script" path="res://scripts/chapters/PrologueHideout.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="res://scenes/prologue/HideoutWorld.tscn" id="2_world"]',
        '[ext_resource type="PackedScene" path="res://scenes/characters/PlayerParty.tscn" id="3_party"]',
        '[ext_resource type="PackedScene" path="res://scenes/cameras/FollowCamera.tscn" id="4_camera"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/PrototypeHUD.tscn" id="5_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/DialogueBox.tscn" id="6_dialogue"]',
        '[ext_resource type="Script" path="res://scripts/ui/VitalsOverlay.gd" id="7_overlay"]',
        "",
        '[node name="PrologueHideout" type="Node3D"]', 'script = ExtResource("1_script")', "",
        '[node name="HideoutWorld" parent="." node_paths=PackedStringArray("party", "camera") instance=ExtResource("2_world")]',
        'party = NodePath("../PlayerParty")', 'camera = NodePath("../FollowCamera")', "",
        '[node name="PlayerParty" parent="." node_paths=PackedStringArray("camera") instance=ExtResource("3_party")]',
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (x, y, z), 'camera = NodePath("../FollowCamera")', "",
        '[node name="FollowCamera" parent="." node_paths=PackedStringArray("target") instance=ExtResource("4_camera")]',
        'target = NodePath("../PlayerParty/Sabi")', "",
        '[node name="PrototypeHUD" parent="." node_paths=PackedStringArray("party", "school_map") instance=ExtResource("5_hud")]',
        'party = NodePath("../PlayerParty")', 'school_map = NodePath("../HideoutWorld")', "",
        '[node name="DialogueBox" parent="." instance=ExtResource("6_dialogue")]', "",
        '[node name="VitalsOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("party")]',
        'script = ExtResource("7_overlay")', 'party = NodePath("../PlayerParty")', "",
    ]
    path = os.path.join(ROOT, "scenes", "chapters", "Prologue_Hideout.tscn")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    main()
