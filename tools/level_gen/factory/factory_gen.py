# -*- coding: utf-8 -*-
"""프로젝트 벨카 - 프롤로그 폐쇄 공장 맵 생성기 (P-04 현실 잠입)

실행: python tools/level_gen/factory/factory_gen.py
설계: 기획서/04. 맵 및 환경/폐쇄공장_맵_상세.md
출력: scenes/prologue/FactoryWorld.tscn, scenes/chapters/Prologue_Factory.tscn

좌표: 건물 안쪽 x 0~34 (서->동), z 0~22 (남->북). 1층 y=0, 지하 y=-3.8.
카메라는 북쪽 위에서 남쪽을 내려다본다: 보여야 하는 벽 장식은 남·서쪽 벽에 둔다.
  서쪽 마당(x -10~0)  : 시작 지점, 외부 보안 단말, 잠긴 옆문(x=0)
  생산동(x 0~22)      : 컨베이어·프레스·상자 더미 사이로 경비원 2명이 순찰
  사무동(x 22~34)     : 복도, 보안실(경비원 1명 - 샤무가 제압), 휴게실, 계단실(봉쇄문 - 샤무가 부숨)
  지하(x 22~34)       : 복도, 경보실(사비 해킹), 자료 폐기실(샤무가 파쇄기 파괴), 서버실(최하층)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "school"))
sys.path.insert(0, os.path.join(HERE, "..", "hideout"))
from emit import SceneWriter, tf, q, rot_y
from geometry import Rect
from batch import Batch
from structure import emit_zone, emit_light
from stairs2 import flight, flat_rail, stair_path
from source import ROOT
from hideout_gen import Builder
import palette

W, D = 34.0, 22.0
HALL_X = 22.0              # 생산동 / 사무동 경계
LEVEL_H = 3.8
B1 = -LEVEL_H              # 지하 바닥
WALL_H = 4.6               # 1층 벽 높이 (공장 천장이 높다)
ROOF_Y = WALL_H
SLAB = 0.2
WT = 0.2
BUILDING = "factory"
FOOTPRINT = Rect(-WT, -WT, W + WT, D + WT)
LEVELS = [("B1", B1), ("1F", 0.0), ("Roof", ROOF_Y)]
# 계단실: 1층 z 14.5 에서 북쪽으로 내려가 지하 z 20.5 에 닿는다
STAIR_X = (31.2, 32.4)
STAIR_Z = (14.5, 20.5)
START = (-7.0, 0.05, 14.0)
# 전이(P-05) 뒤에만 있는 지하 통로: 생산동 아래로 서쪽으로 뻗는다 (P-06 첫 개체 조우 장소)
OW_DOOR = (17.0, 18.6)
OW_CORRIDOR = Rect(4.0, 16.4, HALL_X - WT, 19.2)

EXTRA_MATS = {
    "fac_wall_out": ((0.36, 0.37, 0.36), {}),
    "fac_wall_in": ((0.55, 0.56, 0.52), {}),
    "fac_floor": ((0.33, 0.33, 0.32), {}),
    "fac_machine": ((0.32, 0.38, 0.36), {"metallic": 0.4}),
    "fac_yellow": ((0.75, 0.6, 0.1), {}),
    "fac_belt": ((0.08, 0.08, 0.09), {}),
    "fac_crate": ((0.45, 0.33, 0.2), {}),
    "fac_server": ((0.07, 0.08, 0.1), {"metallic": 0.3}),
    "fac_office_floor": ((0.4, 0.4, 0.42), {}),
}


def lv(name, child="Arch"):
    return "Buildings/%s/%s/%s" % (BUILDING, name, child)


# ---------------------------------------------------------------- 구조

def structure(B, sw, res):
    a1, ab, ar = lv("1F"), lv("B1"), lv("Roof")
    # 1층 바닥: 생산동은 땅 위 슬래브, 사무동은 지하 위 슬래브 (계단 구멍)
    B.box(a1, "fac_floor", 0, HALL_X, -SLAB, 0, 0, D, True, tag="floor")
    sx0, sx1 = STAIR_X
    for x0, x1, z0, z1 in ((HALL_X, sx0, 0, D), (sx1, W, 0, D), (sx0, sx1, 0, STAIR_Z[0]), (sx0, sx1, STAIR_Z[1], D)):
        B.box(a1, "fac_office_floor", x0, x1, -SLAB, 0, z0, z1, True, tag="floor")
    B.box(ab, "fac_floor", HALL_X, W, B1 - SLAB, B1, 0, D, True, tag="floor")
    B.box(ar, "roof_metal", -WT - 0.3, W + WT + 0.3, ROOF_Y, ROOF_Y + 0.2, -WT - 0.3, D + WT + 0.3, True, tag="roof")

    wo, wi = "fac_wall_out", "fac_wall_in"
    # 1층 바깥 벽: 서쪽 옆문(z 10~11.4), 남·북 높은 창
    B.wall(a1, wo, "z", -WT / 2, -WT, D + WT, 0, WALL_H, [(10.0, 11.4, 0.0, 2.4)])
    B.wall(a1, wo, "z", W + WT / 2, -WT, D + WT, 0, WALL_H)
    B.wall(a1, wo, "x", -WT / 2, 0, W, 0, WALL_H, [(4, 7, 3.0, 4.0), (11, 14, 3.0, 4.0), (25, 28, 2.6, 3.6)])
    B.wall(a1, wo, "x", D + WT / 2, 0, W, 0, WALL_H, [(4, 7, 3.0, 4.0), (11, 14, 3.0, 4.0)])
    # 생산동 / 사무동 벽 (복도로 이어지는 문 z 10~11.4)
    B.wall(a1, wi, "z", HALL_X, 0, D, 0, WALL_H, [(10.0, 11.4, 0.0, 2.4)])
    # 사무동: 복도 z 9.5~12.5, 남쪽 보안실, 북쪽 휴게실·계단실
    B.wall(a1, wi, "x", 9.5, HALL_X, W, 0, WALL_H, [(27.0, 28.4, 0.0, 2.3)], t=0.14)
    B.wall(a1, wi, "x", 12.5, HALL_X, W, 0, WALL_H, [(25.0, 26.4, 0.0, 2.3), (31.1, 32.5, 0.0, 2.3)], t=0.14)
    B.wall(a1, wi, "z", 30.0, 12.5, D, 0, WALL_H, t=0.14)
    # 계단실 안 계단 구멍 둘레 난간
    flat_rail(B.b, a1, "z", STAIR_Z[0], STAIR_Z[1], STAIR_X[0] - 0.04, 0.0)
    flat_rail(B.b, a1, "z", STAIR_Z[0], STAIR_Z[1], STAIR_X[1] + 0.04, 0.0)

    # 지하 벽
    wb = "wall_b1"
    # 서쪽 벽 z 17~18.6: 현실에서는 막혀 있고(real_only 채움벽), 전이 뒤에는 없던 통로가 열린다
    B.wall(ab, wb, "z", HALL_X - WT / 2, -WT, D + WT, B1, -SLAB, [(OW_DOOR[0], OW_DOOR[1], B1, B1 + 2.4)])
    B.box(ab, wb, HALL_X - WT, HALL_X, B1, B1 + 2.4, OW_DOOR[0], OW_DOOR[1], True, ("real_only",), "wall")
    B.wall(ab, wb, "z", W + WT / 2, -WT, D + WT, B1, -SLAB)
    B.wall(ab, wb, "x", -WT / 2, HALL_X - WT, W + WT, B1, -SLAB)
    B.wall(ab, wb, "x", D + WT / 2, HALL_X - WT, W + WT, B1, -SLAB)
    # 계단 밑(지하 쪽은 낮다): 막는다
    B.wall(ab, wb, "z", 30.7, 14.0, 20.5, B1, -SLAB, t=0.14)
    B.box(ab, wb, sx1 + 0.1, W, B1, -SLAB, 14.0, 20.5, True, tag="wall")
    # 복도(z 14~22) / 경보실·폐기실(z 7.5~14) / 서버실(z 0~7.5)
    B.wall(ab, wb, "x", 14.0, HALL_X, 30.7, B1, -SLAB, [(24.0, 25.4, B1, B1 + 2.3), (27.2, 28.8, B1, B1 + 2.3)], t=0.14)
    B.wall(ab, wb, "x", 14.0, 30.7, W, B1, -SLAB, t=0.14)
    B.wall(ab, wb, "z", 27.2, 7.5, 14.0, B1, -SLAB, t=0.14)
    B.wall(ab, wb, "z", 28.8, 7.5, 14.0, B1, -SLAB, [(10.0, 11.4, B1, B1 + 2.3)], t=0.14)
    B.wall(ab, wb, "x", 7.5, HALL_X, W, B1, -SLAB, [(27.2, 28.8, B1, B1 + 2.4)], t=0.14)

    # 계단 (지하 z 20.5 -> 1층 z 14.5, 남쪽으로 오른다)
    s = lv("1F", "Stairs")
    flight(B.b, s, "z", STAIR_Z[1], STAIR_Z[0], B1, 0.0, STAIR_X[0], STAIR_X[1], "metal_grate", (), ("w0",),
           rail_trim=(0.8, 0.0))
    stair_path(sw, s, [(31.8, 0.0, 13.4), (31.8, 0.0, STAIR_Z[0] - 0.4), (31.8, B1, STAIR_Z[1] + 0.6)], name="FactoryStairPath")

    # 문: 서쪽 옆문(사비가 외부 단말 해킹 -> 열림), 서버실 문(경보 해제 + 파쇄기 파괴 -> 열림)
    door(sw, res, "Doors", "SideDoor", (0.0, 0.0, 10.0), -90, 1.4, "p04_gate_hacked",
         "전자식 잠금이야. 밖에 있는 보안 단말부터 열어야 해.")
    door(sw, res, "Doors", "ServerDoor", (27.2, B1, 7.5), 0, 1.6, "p04_server_open",
         "서버실은 경보랑 자료 폐기가 돌아가는 동안 잠겨 있어.")


def door(sw, res, parent, name, pos, yaw, width, unlock_flag, locked_line):
    sw.node(name, None, parent, {"transform": tf(pos, rot_y(yaw) if yaw else None), "is_locked": "true",
                                 "unlock_flag": q(unlock_flag), "locked_prompt": q("잠긴 문"),
                                 "locked_line": q(locked_line), "door_width": "%.2f" % width},
            instance=res["door"])


# ---------------------------------------------------------------- 마당 (시작)

def yard(B):
    p = "Site"
    # 땅: 건물 바닥 자리는 비운다 (지하가 땅에 가려지지 않게)
    gx0, gx1, gz0, gz1 = -16.0, W + 8.0, -8.0, D + 8.0
    for x0, x1, z0, z1 in ((gx0, gx1, gz0, -WT), (gx0, gx1, D + WT, gz1), (gx0, -WT, -WT, D + WT), (W + WT, gx1, -WT, D + WT)):
        B.box(p, "ground", x0, x1, -0.25, -0.02, z0, z1, True, tag="ground")
    B.box(p, "silt", -10.0, -0.2, -0.02, 0.0, -2.0, D + 2.0, tag="yard")
    # 철망 담장 (마당을 막는다)
    for x0, x1, z0, z1 in ((-10.2, -10.0, -2.0, D + 2.0), (-10.0, -0.2, -2.1, -1.9), (-10.0, -0.2, D + 1.9, D + 2.1)):
        B.box(p, "fence", x0, x1, 0.0, 2.2, z0, z1, True, tag="fence")
    # 외부 보안 단말 (기둥 위 상자)
    B.box(p, "metal_dark", -3.15, -2.85, 0.0, 1.0, 5.85, 6.15, True, tag="terminal_post")
    B.box(p, "panel_gray", -3.3, -2.7, 1.0, 1.6, 5.8, 6.2, tag="terminal")
    B.box(p, "led_red", -2.69, -2.68, 1.4, 1.45, 5.95, 6.05, tag="led")
    # 버려진 팔레트·드럼통 (엄폐)
    for x0, z0 in ((-6.0, 3.0), (-4.5, 18.5)):
        B.box(p, "pallet", x0, x0 + 1.2, 0.0, 0.15, z0, z0 + 1.0, True, tag="pallet")
    for x, z in ((-8.5, 8.0), (-8.0, 8.6), (-2.0, 19.5)):
        B.cyl(p, "pipe_red", x, z, 0.58, 0.0, 0.88)
        B.solid(p, x - 0.29, x + 0.29, 0.0, 0.88, z - 0.29, z + 0.29)
    B.cyl(p, "lamp_post", -9.4, 11.0, 0.12, 0.0, 4.0)


# ---------------------------------------------------------------- 생산동

def hall(B):
    p = lv("1F", "Props")
    # 컨베이어 2줄 (시선을 가리는 높이 1.2m)
    for x0, x1, z0, z1 in ((3.0, 17.0, 5.0, 6.2), (5.0, 19.0, 15.8, 17.0)):
        B.box(p, "fac_machine", x0, x1, 0.0, 0.9, z0, z1, True, tag="conveyor")
        B.box(p, "fac_belt", x0, x1, 0.9, 1.2, z0 + 0.1, z1 - 0.1, True, tag="belt")
        for x in range(int(x0) + 1, int(x1), 3):
            B.box(p, "fac_yellow", x, x + 0.1, 0.9, 1.25, z0 - 0.02, z0, tag="belt_mark")
    # 프레스·대형 기계 (시선 차단)
    for x0, z0, w, d, h in ((4.0, 8.0, 2.2, 2.0, 2.8), (12.0, 12.0, 2.4, 2.2, 3.2), (16.5, 7.5, 2.0, 2.4, 2.6)):
        B.box(p, "fac_machine", x0, x0 + w, 0.2, h, z0, z0 + d, True, tag="machine")
        B.box(p, "fac_yellow", x0 - 0.02, x0 + w + 0.02, 0.0, 0.2, z0 - 0.02, z0 + d + 0.02, True, tag="machine_base")
        B.box(p, "panel_gray", x0 + 0.3, x0 + 0.9, 1.1, 1.6, z0 + d, z0 + d + 0.04, tag="machine_panel")
    # 상자 더미 (엄폐)
    for x0, z0, h in ((8.0, 12.0, 1.6), (15.0, 2.0, 1.4), (2.0, 13.0, 1.8), (9.5, 19.5, 1.2), (19.0, 13.5, 1.6)):
        B.box(p, "fac_crate", x0, x0 + 1.4, 0.0, h, z0, z0 + 1.4, True, tag="crate")
        B.box(p, "fac_crate", x0 + 0.2, x0 + 1.2, h, h + 0.6, z0 + 0.2, z0 + 1.2, True, tag="crate")
    # 바닥 안전선
    for z in (3.4, 18.6):
        B.box(p, "fac_yellow", 1.0, 21.0, 0.0, 0.006, z, z + 0.1, tag="floor_line")
    # 남쪽 벽 철제 사물함 (숨을 곳은 따로 LockerHidingSpot)
    B.box(p, "locker_gray", 6.0, 9.0, 0.0, 2.0, 0.0, 0.5, True, tag="locker_row")
    # 천장 크레인 레일
    for z in (4.0, 18.0):
        B.box(p, "steel_frame", 0.0, HALL_X, 4.0, 4.2, z, z + 0.2, tag="crane_rail")


# ---------------------------------------------------------------- 사무동 (1층)

def offices(B):
    p = lv("1F", "Props")
    # 보안실: 남쪽 벽 모니터 벽 + 단말 책상
    B.box(p, "desk_top", 24.5, 31.5, 0.72, 0.76, 0.2, 1.1, True, tag="desk")
    for x in (24.6, 31.35):
        B.box(p, "desk_frame", x, x + 0.05, 0.0, 0.72, 0.25, 1.05, tag="desk_leg")
    for i in range(6):
        x = 24.8 + i * 1.1
        for h in (0.95, 1.65):
            B.box(p, "monitor", x, x + 1.0, h, h + 0.6, 0.05, 0.12, tag="monitor")
            B.box(p, "screen_on", x + 0.05, x + 0.95, h + 0.05, h + 0.55, 0.12, 0.125, tag="screen")
    B.box(p, "chair_office", 27.5, 28.1, 0.0, 1.1, 1.5, 2.1, True, tag="chair")
    B.box(p, "file_box", 32.4, 33.6, 0.0, 1.8, 1.0, 3.0, True, tag="cabinet")
    # 휴게실: 테이블, 자판기, 사물함
    B.box(p, "table_top", 23.5, 25.5, 0.72, 0.76, 16.0, 17.2, True, tag="table")
    B.box(p, "vending_red", 28.8, 29.8, 0.0, 1.9, 20.9, 21.8, True, tag="vending")
    B.box(p, "sofa", 22.3, 23.1, 0.0, 0.8, 18.5, 21.0, True, tag="sofa")
    # 계단실 입구 봉쇄문은 BreakableObstacle 노드 (아래 main 에서)


# ---------------------------------------------------------------- 지하

def basement(B):
    p = lv("B1", "Props")
    y = B1
    # 경보실 (x 22~27.2, z 7.5~14): 경보 패널은 남쪽 벽
    B.box(p, "control_panel", 22.6, 24.6, y, y + 1.4, 7.6, 8.3, True, tag="alarm_panel")
    B.box(p, "panel_red", 23.1, 23.6, y + 1.5, y + 1.8, 7.6, 7.66, tag="alarm_lamp")
    B.box(p, "cable_tray", 22.1, 27.0, y + 3.0, y + 3.1, 7.6, 7.9, tag="cables")
    # 자료 폐기실 (x 28.8~34, z 7.5~14): 파쇄기는 BreakableObstacle, 서류 상자
    for x0 in (30.0, 31.4):
        B.box(p, "file_box", x0, x0 + 1.1, y, y + 0.8, 12.6, 13.6, True, tag="boxes")
    B.box(p, "paper", 29.2, 33.6, y, y + 0.01, 8.0, 12.0, tag="paper_scraps")
    # 서버실 (z 0~7.5): 랙 줄
    for x0 in (23.0, 25.6, 30.0, 32.6):
        B.box(p, "fac_server", x0, x0 + 1.0, y, y + 2.2, 1.5, 5.5, True, tag="rack")
        for k in range(8):
            B.box(p, "led_green" if k % 3 else "led_red", x0 + 1.0, x0 + 1.01, y + 0.3 + k * 0.22, y + 0.33 + k * 0.22, 2.0, 5.0, tag="led")
    B.box(p, "desk_top", 26.8, 29.2, y + 0.72, y + 0.76, 0.2, 1.0, True, tag="desk")
    B.box(p, "monitor", 27.4, 28.6, y + 0.8, y + 1.5, 0.25, 0.32, tag="monitor")
    B.box(p, "screen_on", 27.45, 28.55, y + 0.85, y + 1.45, 0.32, 0.325, tag="screen")
    # 복도 배관
    B.box(p, "pipe", 22.1, 30.6, y + 3.2, y + 3.4, 21.4, 21.6, tag="pipe")


# ---------------------------------------------------------------- 전이 뒤 (otherworld_only)

def otherworld(B):
    """P-05 전이 뒤의 변화: 계단 위 봉쇄문 자리가 벽으로 막히고, 지하 서쪽에 없던 통로가 생긴다."""
    g = ("otherworld_only",)
    a1, ab = lv("1F", "Arch"), lv("B1", "Arch")
    B.box(a1, "wall_b1_flood", 31.1, 32.5, 0.0, 2.3, 12.45, 12.55, True, g, "wall")
    r = OW_CORRIDOR
    B.box(ab, "floor_b1_old", r.x0, r.x1, B1 - SLAB, B1, r.z0, r.z1, True, g, "floor")
    for z0, z1 in ((r.z0 - WT, r.z0), (r.z1, r.z1 + WT)):
        B.box(ab, "wall_b1_flood", r.x0 - WT, r.x1, B1, -SLAB, z0, z1, True, g, "wall")
    B.box(ab, "wall_b1_flood", r.x0 - WT, r.x0, B1, -SLAB, r.z0, r.z1, True, g, "wall")
    # 바닥에 고인 물, 벽을 따라 늘어진 배관
    B.box(ab, "water", 7.0, 12.0, B1, B1 + 0.01, r.z0 + 0.4, r.z1 - 0.6, False, g, "puddle")
    B.box(ab, "pipe", r.x0, r.x1, B1 + 2.9, B1 + 3.1, r.z1 - 0.3, r.z1 - 0.1, False, g, "pipe")


# ---------------------------------------------------------------- 씬

def main():
    sw = SceneWriter()
    batch = Batch()
    B = Builder(batch)
    res = {
        "controller": sw.ext_res("Script", "res://scripts/world/WorldPhaseController.gd"),
        "zone": sw.ext_res("Script", "res://scripts/world/ZoneArea.gd"),
        "ambient": sw.ext_res("Script", "res://scripts/world/AmbientSynth.gd"),
        "inspect": sw.ext_res("Script", "res://scripts/interactables/InspectInteractable.gd"),
        "hack": sw.ext_res("Script", "res://scripts/interactables/HackTerminal.gd"),
        "breakable": sw.ext_res("Script", "res://scripts/interactables/BreakableObstacle.gd"),
        "checkpoint": sw.ext_res("Script", "res://scripts/world/Checkpoint.gd"),
        "defeat": sw.ext_res("Script", "res://scripts/encounters/DefeatTutorial.gd"),
        "door": sw.ext_res("PackedScene", "res://scenes/interactables/DoorInteractable.tscn"),
        "locker": sw.ext_res("PackedScene", "res://scenes/interactables/LockerHidingSpot.tscn"),
        "guard": sw.ext_res("PackedScene", "res://scenes/entities/Guard.tscn"),
    }
    mats = palette.make(sw, EXTRA_MATS)
    env = sw.sub_res("env_factory", "Environment", {
        "background_mode": "1", "background_color": "Color(0.02, 0.02, 0.04, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.45, 0.5, 0.62, 1)", "ambient_light_energy": "0.5",
        "ssao_enabled": "true", "ssao_radius": "1.2", "ssao_intensity": "2.2", "ssao_power": "1.6", "ssao_light_affect": "0.2",
        "adjustment_enabled": "true", "adjustment_saturation": "0.85", "adjustment_contrast": "1.08"})
    env_other = sw.sub_res("env_factory_other", "Environment", {
        "background_mode": "1", "background_color": "Color(0, 0, 0, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.42, 0.3, 0.36, 1)", "ambient_light_energy": "0.65", "fog_enabled": "true",
        "fog_light_color": "Color(0.08, 0.03, 0.04, 1)", "fog_density": "0.03",
        "ssao_enabled": "true", "ssao_radius": "1.4", "ssao_intensity": "3.0", "ssao_power": "1.8", "ssao_light_affect": "0.3",
        "adjustment_enabled": "true", "adjustment_saturation": "0.7", "adjustment_contrast": "1.1"})
    sw.node("FactoryWorld", "Node3D", None, {"script": res["controller"], "real_environment": env, "otherworld_environment": env_other,
                                             "world_environment": 'NodePath("WorldEnvironment")', "ambient": 'NodePath("Ambient")'},
            node_paths=["world_environment", "ambient"])
    sw.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env}, unique=False)
    moon_tf = "Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 30, 0)"
    sw.node("Moon", "DirectionalLight3D", ".", {"transform": moon_tf, "light_energy": "0.18", "light_color": "Color(0.6, 0.7, 1, 1)",
                                                "shadow_enabled": "true"}, groups=["real_light"], unique=False)
    sw.node("Ambient", "AudioStreamPlayer", ".", {"script": res["ambient"]}, unique=False)
    sw.node("Zones", "Node3D", ".", {}, unique=False)
    sw.node("Site", "Node3D", ".", {}, unique=False)
    sw.node("Doors", "Node3D", ".", {}, unique=False)

    sw.node("Buildings", "Node3D", ".", {}, unique=False)
    fp = FOOTPRINT
    sw.node(BUILDING, "Node3D", "Buildings", {
        "metadata/building": q(BUILDING), "metadata/footprint": "Rect2(%.3f, %.3f, %.3f, %.3f)" % (fp.x0, fp.z0, fp.w, fp.d),
        "metadata/base_y": "%.2f" % B1, "metadata/top_y": "%.2f" % (ROOF_Y + 0.2)}, groups=["school_building"], unique=False)
    for idx, (name, _y) in enumerate(LEVELS):
        sw.node(name, "Node3D", "Buildings/" + BUILDING, {
            "metadata/building": q(BUILDING), "metadata/level_index": str(idx), "metadata/cull_layer": str(2 + idx)},
                groups=["school_level"], unique=False)
        for child in ("Arch", "Stairs", "Props", "Lights"):
            sw.node(child, "Node3D", "Buildings/%s/%s" % (BUILDING, name), {}, unique=False)

    structure(B, sw, res)
    yard(B)
    hall(B)
    offices(B)
    basement(B)
    otherworld(B)

    # 조명: 마당 가로등, 생산동 나트륨등(드문드문), 사무동 형광등, 지하 비상등
    emit_light(sw, "Site", (-9.0, 3.8, 11.0), 9.0, "real_light", (1.0, 0.75, 0.45), 1.2)
    for pos in ((6.0, 4.0, 4.0), (16.0, 4.0, 11.0), (6.0, 4.0, 18.0)):
        emit_light(sw, lv("1F", "Lights"), pos, 8.5, "real_light", (1.0, 0.72, 0.42), 1.2)
    for pos, rng in (((28.0, 3.2, 11.0), 6.0), ((28.0, 3.0, 4.5), 6.0), ((25.0, 3.0, 17.5), 5.0), ((32.2, 3.0, 13.6), 3.5)):
        emit_light(sw, lv("1F", "Lights"), pos, rng, "real_light", (0.85, 0.92, 1.0), 0.8)
    for pos, rng, col in (((26.0, B1 + 3.0, 18.0), 7.0, (1.0, 0.85, 0.7)), ((24.5, B1 + 3.0, 10.7), 5.0, (1.0, 0.4, 0.35)),
                          ((31.4, B1 + 3.0, 10.7), 5.0, (1.0, 0.85, 0.7)), ((28.0, B1 + 3.0, 3.8), 7.0, (0.5, 0.8, 1.0))):
        emit_light(sw, lv("B1", "Lights"), pos, rng, "real_light", col, 0.8)
    emit_light(sw, lv("1F", "Lights"), (28.0, 1.6, 0.6), 3.0, "real_light", (0.45, 0.85, 0.95), 0.6)

    # 구역 이름
    for zid, name, r, y0, idx in (
            ("fac_yard", "공장 서쪽 마당", Rect(-10, -2, 0, D + 2), 0.0, 1),
            ("fac_hall", "생산동 작업장", Rect(0, 0, HALL_X, D), 0.0, 1),
            ("fac_corridor", "사무동 복도", Rect(HALL_X, 9.5, W, 12.5), 0.0, 1),
            ("fac_security", "보안실", Rect(HALL_X, 0, W, 9.5), 0.0, 1),
            ("fac_lounge", "휴게실", Rect(HALL_X, 12.5, 30.0, D), 0.0, 1),
            ("fac_stairs", "계단실", Rect(30.0, 12.5, W, D), 0.0, 1),
            ("fac_b1_corridor", "지하 복도", Rect(HALL_X, 14.0, W, D), B1, 0),
            ("fac_b1_alarm", "경보실", Rect(HALL_X, 7.5, 27.2, 14.0), B1, 0),
            ("fac_b1_shred", "자료 폐기실", Rect(28.8, 7.5, W, 14.0), B1, 0),
            ("fac_b1_server", "서버실", Rect(HALL_X, 0, W, 7.5), B1, 0),
            ("fac_ow_corridor", "변질된 복도", OW_CORRIDOR, B1, 0)):
        emit_zone(sw, "Zones", res["zone"], r, y0, 3.0, zid, name, BUILDING, idx)

    # 해킹 단말 (사비)
    sw.node("Interactables", "Node3D", ".", {}, unique=False)
    for name, pos, point, tid, done, req, prompt, marker in (
            ("GateTerminal", (-3.0, 0.0, 6.0), (0.9, 1.1, 0.0), "gate", "p04_gate_hacked", "", "외부 보안 단말 해킹", 1.9),
            ("SecurityTerminal", (28.0, 0.0, 0.7), (0.0, 1.1, 1.2), "security", "p04_security_hacked", "", "보안망 접속·삭제 자료 복구", 1.8),
            ("AlarmPanel", (23.6, B1, 8.0), (0.0, 1.1, 1.1), "alarm", "p04_alarm_off", "", "경보 장치 해제", 1.8),
            ("MainServer", (28.0, B1, 0.6), (0.0, 1.1, 1.3), "server", "p04_footage_restored", "p04_server_open", "서버에서 영상 복원", 1.8)):
        sw.node(name, "Node3D", "Interactables", {"transform": tf(pos), "script": res["hack"], "terminal_id": q(tid),
                                                  "done_flag": q(done), "requires_flag": q(req), "hack_prompt": q(prompt),
                                                  "marker_height": "%.2f" % marker})
        sw.node("InteractionPoint", "Marker3D", "Interactables/" + name, {"transform": tf(point)}, unique=False)

    # 부술 수 있는 것 (샤무): 계단실 봉쇄문, 자료 파쇄기
    blast = sw.sub_res("blast_mat", "StandardMaterial3D", {"albedo_color": "Color(0.42, 0.4, 0.3, 1)", "metallic": "0.5"})
    shred = sw.sub_res("shred_mat", "StandardMaterial3D", {"albedo_color": "Color(0.25, 0.28, 0.3, 1)", "metallic": "0.4"})
    for name, pos, size, mat, oid, prompt, line, point in (
            ("BlastDoor", (31.8, 0.0, 12.5), (1.4, 2.3, 0.2), blast, "basement_door", "봉쇄문 강제로 열기",
             "봉쇄문이 기계식으로 잠겨 있어… 샤무 힘이면 열 수 있을 거야.", (0.0, 1.1, -0.8)),
            ("Shredder", (31.0, B1, 9.0), (1.8, 1.3, 1.0), shred, "data_shredder", "파쇄기 부수기",
             "자료가 계속 갈려 나가고 있어. 내 힘으로는 못 멈춰… 샤무!", (0.0, 1.1, 1.0))):
        sw.node(name, "Node3D", "Interactables", {"transform": tf(pos), "script": res["breakable"], "obstacle_id": q(oid),
                                                  "break_prompt": q(prompt), "sabi_blocked_line": q(line), "marker_height": "1.6"})
        sw.node("Piece", "CSGBox3D", "Interactables/" + name, {"transform": tf((0.0, size[1] / 2, 0.0)), "use_collision": "true",
                                                               "size": "Vector3(%.2f, %.2f, %.2f)" % size, "material": mat}, unique=False)
        sw.node("InteractionPoint", "Marker3D", "Interactables/" + name, {"transform": tf(point)}, unique=False)

    # 숨을 곳 (철제 사물함, 앞이 북쪽)
    for name, pos in (("LockerA", (1.2, 0.0, 0.3)), ("LockerB", (20.6, 0.0, 0.3)), ("LockerC", (11.0, 0.0, 21.0))):
        rows = rot_y(180) if pos[2] > 10 else None
        sw.node(name, None, "Interactables", {"transform": tf((pos[0], pos[1], pos[2] + 0.4) if rows is None else pos, rows)},
                instance=res["locker"])

    # 경비원: 생산동 2명(순찰), 보안실 1명(모니터를 보고 서 있음 - 샤무가 뒤에서 제압)
    sw.node("Guards", "Node3D", ".", {}, groups=["real_only"], unique=False)
    for name, pos, span, gid in (("GuardHall", (5.0, 0.05, 11.0), (14.0, 0.0, 0.0), "hall"),
                                 ("GuardEast", (20.4, 0.05, 19.5), (0.0, 0.0, -16.0), "east"),
                                 ("GuardSecurity", (28.0, 0.05, 3.2), (0.0, 0.0, -0.01), "security")):
        sw.node(name, None, "Guards", {"transform": tf(pos), "guard_id": q(gid),
                                       "patrol_span": "Vector3(%.2f, %.2f, %.2f)" % span}, instance=res["guard"])

    # 체크포인트
    sw.node("Checkpoints", "Node3D", ".", {}, unique=False)
    for cid, name, center, size in (("yard", "공장 서쪽 마당", (-6.0, 1.0, 14.0), (6.0, 3.0, 6.0)),
                                    ("corridor", "사무동 복도", (23.4, 1.0, 11.0), (2.0, 3.0, 2.6)),
                                    ("basement", "지하 복도", (27.0, B1 + 1.0, 18.0), (5.0, 3.0, 5.0))):
        n = sw.node("Checkpoint_" + cid, "Area3D", "Checkpoints", {"transform": tf(center), "script": res["checkpoint"],
                                                                   "checkpoint_id": q(cid), "display_name": q(name)}, unique=False)
        sw.node("Shape", "CollisionShape3D", "Checkpoints/" + n, {"shape": sw.box_shape(size)}, unique=False)

    # 전이 뒤 조명: 붉고 희미한 비상등만 (otherworld_light)
    for pos, rng in (((27.0, B1 + 2.8, 18.5), 6.0), ((31.8, 2.6, 13.4), 4.0), ((19.0, B1 + 2.6, 17.8), 5.0),
                     ((12.0, B1 + 2.6, 17.8), 5.0), ((6.0, B1 + 2.6, 17.8), 5.0), ((28.0, B1 + 2.6, 4.0), 5.0)):
        emit_light(sw, lv("B1" if pos[1] < 0 else "1F", "Lights"), pos, rng, "otherworld_light", (0.75, 0.16, 0.14), 1.0)

    # P-06 첫 개체 조우 (DefeatTutorial 재사용): 통로 가운데를 지나면 시작
    r = OW_CORRIDOR
    sw.node("FirstEncounter", "Node3D", ".", {"script": res["defeat"], "done_flag": q("prologue_p06_done"),
                                              "encounter_dialogue": q("prologue_p06_encounter"),
                                              "sabi_hurt_dialogue": q("prologue_p06_sabi_hurt"),
                                              "overwhelm_dialogue": q("prologue_p06_overwhelm"),
                                              "aftermath_dialogue": q(""),
                                              "defeat_title": q("패배"), "defeat_body": q("이길 수 없는 상대였다."),
                                              "defeat_hint": q("공격은 먹히지 않았다. 칠수록 더 빨라졌다.\n의식이 멀어지기 직전, 어디선가 금속 소리가 들렸다.")})
    n = sw.node("Trigger", "Area3D", "FirstEncounter", {"transform": tf((15.0, B1 + 1.0, r.cz))}, unique=False)
    sw.node("Shape", "CollisionShape3D", "FirstEncounter/" + n, {"shape": sw.box_shape((1.0, 2.5, r.d))}, unique=False)
    for name, pos in (("EntitySpawn", (6.0, B1 + 0.05, r.cz)), ("ExtraSpawnA", (5.0, B1 + 0.05, r.z0 + 0.7)),
                      ("ExtraSpawnB", (20.5, B1 + 0.05, r.cz))):
        sw.node(name, "Marker3D", "FirstEncounter", {"transform": tf(pos)}, unique=False)

    sw.node("Spawn", "Marker3D", ".", {"transform": tf(START)}, unique=False)
    batch.emit(sw, mats)
    os.makedirs(os.path.join(ROOT, "scenes", "prologue"), exist_ok=True)
    path = os.path.join(ROOT, "scenes", "prologue", "FactoryWorld.tscn")
    text = sw.text()
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", path, "nodes=%d boxes=%d" % (len(sw.nodes), len(batch.records)))
    write_chapter()
    return batch


def write_chapter():
    x, y, z = START
    lines = [
        "[gd_scene load_steps=11 format=3]", "",
        '[ext_resource type="Script" path="res://scripts/chapters/PrologueFactory.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="res://scenes/prologue/FactoryWorld.tscn" id="2_world"]',
        '[ext_resource type="PackedScene" path="res://scenes/characters/PlayerParty.tscn" id="3_party"]',
        '[ext_resource type="PackedScene" path="res://scenes/cameras/FollowCamera.tscn" id="4_camera"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/PrototypeHUD.tscn" id="5_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/DialogueBox.tscn" id="6_dialogue"]',
        '[ext_resource type="Script" path="res://scripts/ui/VitalsOverlay.gd" id="7_overlay"]',
        '[ext_resource type="Script" path="res://scripts/ui/FailureScreen.gd" id="8_failure"]',
        '[ext_resource type="Script" path="res://scripts/ui/CaptionSequence.gd" id="9_caption"]',
        "",
        '[node name="PrologueFactory" type="Node3D"]', 'script = ExtResource("1_script")', "",
        '[node name="FactoryWorld" parent="." node_paths=PackedStringArray("party", "camera") instance=ExtResource("2_world")]',
        'party = NodePath("../PlayerParty")', 'camera = NodePath("../FollowCamera")', "",
        '[node name="PlayerParty" parent="." node_paths=PackedStringArray("camera") instance=ExtResource("3_party")]',
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (x, y, z), 'camera = NodePath("../FollowCamera")', "",
        '[node name="FollowCamera" parent="." node_paths=PackedStringArray("target") instance=ExtResource("4_camera")]',
        'target = NodePath("../PlayerParty/Sabi")', "",
        '[node name="PrototypeHUD" parent="." node_paths=PackedStringArray("party", "school_map") instance=ExtResource("5_hud")]',
        'party = NodePath("../PlayerParty")', 'school_map = NodePath("../FactoryWorld")', "",
        '[node name="DialogueBox" parent="." instance=ExtResource("6_dialogue")]', "",
        '[node name="VitalsOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("party")]',
        'script = ExtResource("7_overlay")', 'party = NodePath("../PlayerParty")', "",
        '[node name="FailureScreen" type="CanvasLayer" parent="."]', 'script = ExtResource("8_failure")', "",
        '[node name="CaptionSequence" type="CanvasLayer" parent="."]', 'script = ExtResource("9_caption")', "",
    ]
    path = os.path.join(ROOT, "scenes", "chapters", "Prologue_Factory.tscn")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    main()
