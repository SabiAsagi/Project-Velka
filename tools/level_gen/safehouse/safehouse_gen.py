# -*- coding: utf-8 -*-
"""프로젝트 벨카 - 협회 세이프 하우스(본부) 맵 생성기 (프롤로그 P-08 ~ P-12)

실행: python tools/level_gen/safehouse/safehouse_gen.py
설계: 기획서/04. 맵 및 환경/세이프하우스_맵_상세.md
출력: scenes/prologue/SafehouseWorld.tscn, scenes/chapters/Prologue_Safehouse.tscn

좌표: 건물 안쪽 x 0~32 (서->동), z 0~22 (남->북), 1층만. 가운데 복도 z 9.5~12.
카메라는 북쪽 위에서 남쪽을 내려다본다: 보여야 하는 벽 장식은 각 방의 남쪽 벽에 둔다.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "school"))
sys.path.insert(0, os.path.join(HERE, "..", "hideout"))
from emit import SceneWriter, tf, q, rot_y
from geometry import Rect
from batch import Batch
from structure import emit_zone, emit_light
from source import ROOT
from hideout_gen import Builder, window
import palette

W, D = 32.0, 22.0
WALL_H = 3.4
ROOF_Y = 3.8
SLAB = 0.2
WT = 0.2
CORR = (9.5, 12.0)          # 복도 z 범위
BUILDING = "safehouse"
FOOTPRINT = Rect(-WT, -WT, W + WT, D + WT)
START = (2.4, 0.05, 3.6)    # 치료실 침대 옆

EXTRA_MATS = {
    "sh_wall": ((0.62, 0.6, 0.52), {}),             # 누렇게 바랜 관공서 벽
    "sh_wall_low": ((0.32, 0.38, 0.34), {}),        # 허리 높이 아래 짙은 녹색 페인트
    "sh_floor": ((0.42, 0.4, 0.36), {}),            # 낡은 장판
    "sh_board": ((0.36, 0.27, 0.17), {}),           # 창을 막은 판자
    "sh_screen": ((0.12, 0.35, 0.4), {}),
}

# NPC: (노드 이름, 이름표, inspect_id, 처음 위치, 몸 색)
NPCS = [
    ("NpcSeo", "서유림", "npc_seo", (3.6, 0.0, 4.2), (0.86, 0.88, 0.9)),
    ("NpcKwon", "권지혁", "npc_kwon", (5.6, 0.0, 6.2), (0.26, 0.32, 0.2)),
    ("NpcHan", "한재윤", "npc_han", (11.6, 0.0, 3.6), (0.58, 0.36, 0.14)),
    ("NpcYu", "유가온", "npc_yu", (28.0, 0.0, 6.0), (0.16, 0.22, 0.38)),
    ("NpcBaek", "백윤서", "npc_baek", (21.0, 0.0, 18.4), (0.13, 0.11, 0.13)),
]


def lv(name, child="Arch"):
    return "Buildings/%s/%s/%s" % (BUILDING, name, child)


def structure(B, sw, res):
    a1, ar = lv("1F"), lv("Roof")
    B.box(a1, "sh_floor", 0, W, -SLAB, 0, 0, D, True, tag="floor")
    B.box(ar, "roof_metal", -WT - 0.3, W + WT + 0.3, ROOF_Y, ROOF_Y + 0.2, -WT - 0.3, D + WT + 0.3, True, tag="roof")
    wo = "facade_annex"
    south_win = [(1.5, 3.5), (25.5, 28.0), (29.5, 31.0)]   # 작업실 남쪽 벽은 공구벽
    B.wall(a1, wo, "x", -WT / 2, -WT, W + WT, 0, WALL_H, [(a, b, 1.0, 2.4) for a, b in south_win] + [(18.0, 21.0, 0.0, 2.6)])
    B.wall(a1, wo, "x", D + WT / 2, -WT, W + WT, 0, WALL_H, [(3.0, 5.0, 1.0, 2.4), (12.0, 14.0, 1.0, 2.4)])
    B.wall(a1, wo, "z", -WT / 2, 0, D, 0, WALL_H, [(4.0, 6.0, 1.0, 2.4), (15.5, 17.5, 1.0, 2.4)])
    B.wall(a1, wo, "z", W + WT / 2, 0, D, 0, WALL_H, [(4.0, 6.0, 1.0, 2.4)])
    # 판자로 막은 창 (안쪽에 판자 3장)
    for a, b in south_win:
        window(B, a1, "x", 0.0, a, b, 1.0, 2.4, inside=+1)
        for k in range(3):
            y = 1.15 + k * 0.42
            B.box(a1, "sh_board", a - 0.05, b + 0.05, y, y + 0.3, 0.16, 0.2, tag="board")
    # 봉쇄된 정문 (안쪽에 철판과 바리케이드)
    B.box(a1, "metal_dark", 18.0, 21.0, 0.0, 2.6, -0.12, -0.04, True, tag="front_door")
    B.box(a1, "steel_frame", 17.8, 21.2, 0.9, 1.1, 0.04, 0.16, True, tag="barricade")
    B.box(a1, "steel_frame", 17.8, 21.2, 1.8, 2.0, 0.04, 0.16, True, tag="barricade")
    B.box(a1, "sandbag", 18.1, 20.9, 0.0, 0.6, 0.2, 0.75, True, tag="sandbags")

    wi = "sh_wall"
    # 복도 남쪽 벽 (z 9.5): 치료실·작업실·기록실 문, 중앙 홀은 넓게 열림
    B.wall(a1, wi, "x", CORR[0], 0, W, 0, WALL_H, [(5.0, 6.4, 0.0, 2.3), (10.5, 11.9, 0.0, 2.3), (16.0, 23.0, 0.0, 2.8),
                                                    (27.0, 28.4, 0.0, 2.3)], t=0.14)
    # 복도 북쪽 벽 (z 12): 숙소·브리핑룸·협회장실(잠김)·보호관리부 사무실
    B.wall(a1, wi, "x", CORR[1], 0, W, 0, WALL_H, [(5.0, 6.4, 0.0, 2.3), (11.5, 12.9, 0.0, 2.3), (20.4, 21.8, 0.0, 2.3),
                                                    (28.0, 29.4, 0.0, 2.3)], t=0.14)
    for x in (8.0, 15.0, 24.0):
        B.wall(a1, wi, "z", x, 0.0, CORR[0] - 0.07, 0, WALL_H, t=0.14)
    for x in (8.0, 17.0, 25.0):
        B.wall(a1, wi, "z", x, CORR[1] + 0.07, D, 0, WALL_H, t=0.14)
    # 허리 아래 짙은 페인트 띠 (복도 양쪽 벽, 복도 쪽 면)
    for z0, z1 in ((CORR[0] + 0.07, CORR[0] + 0.09), (CORR[1] - 0.09, CORR[1] - 0.07)):
        for x0, x1 in ((0.0, 5.0), (6.4, 10.5), (11.9, 16.0), (23.0, 27.0), (28.4, W)) if z0 < 10 else \
                ((0.0, 5.0), (6.4, 11.5), (12.9, 20.4), (21.8, 28.0), (29.4, W)):
            B.box(a1, "sh_wall_low", x0, x1, 0.0, 1.0, z0, z1, tag="wainscot")

    # 잠긴 문 (이야기 진행에 따라 열린다)
    for name, x, flag, line in (("QuartersDoor", 5.0, "sh_quarters_open", "임시 숙소야. 아직 쉴 때가 아니야."),
                                ("BriefingDoor", 11.5, "sh_briefing_open", "브리핑룸. 지금은 아무도 없어."),
                                ("PresidentDoor", 20.4, "sh_president_open", "협회장실이야. 부르기 전에는 들어갈 수 없대.")):
        sw.node(name, None, "Doors", {"transform": tf((x, 0.0, CORR[1])), "is_locked": "true", "unlock_flag": q(flag),
                                      "locked_prompt": q("잠긴 문"), "locked_line": q(line), "door_width": "1.40"},
                instance=res["door"])


def rooms(B):
    p = lv("1F", "Props")
    # 치료실 (0~8, 0~9.5)
    for x0 in (0.6, 4.4):
        B.box(p, "bed_frame", x0, x0 + 1.0, 0.0, 0.5, 0.25, 2.3, True, tag="bed")
        B.box(p, "bed", x0 + 0.05, x0 + 0.95, 0.5, 0.65, 0.3, 2.25, tag="mattress")
        B.box(p, "pillow", x0 + 0.15, x0 + 0.85, 0.65, 0.75, 0.35, 0.75, tag="pillow")
    B.box(p, "curtain_light", 2.6, 2.64, 0.2, 2.4, 0.2, 2.8, tag="curtain")
    B.cyl(p, "steel", 1.9, 1.2, 0.05, 0.0, 1.8)
    B.box(p, "medicine_cabinet", 6.4, 7.8, 0.0, 1.9, 0.1, 0.6, True, tag="cabinet")
    B.box(p, "first_aid", 6.6, 7.0, 1.0, 1.25, 0.6, 0.66, tag="first_aid")
    B.box(p, "desk_top", 5.2, 7.6, 0.72, 0.76, 7.6, 8.6, True, tag="desk")
    # 기술지원 작업실 (8~15)
    B.box(p, "workbench", 8.6, 14.4, 0.0, 0.92, 0.2, 1.0, True, tag="workbench")
    B.box(p, "pegboard", 8.8, 14.2, 1.1, 2.4, 0.0, 0.04, tag="pegboard")
    for i in range(8):
        x = 9.1 + i * 0.62
        B.box(p, "steel" if i % 2 else "metal_dark", x, x + 0.08, 1.3, 1.6 + 0.12 * (i % 3), 0.04, 0.12, tag="tool")
    B.box(p, "locker_gray", 13.6, 14.8, 0.0, 2.0, 4.0, 6.0, True, tag="locker")
    B.box(p, "terminal", 10.0, 10.6, 0.92, 0.95, 0.4, 0.8, tag="hack_pad")         # 사비의 해킹 패드
    B.box(p, "case_black", 12.0, 13.0, 0.92, 1.1, 0.3, 0.8, tag="weapon_case")      # 샤무의 무기
    # 중앙 홀 (15~24): 접수대, 게시판, 대기 의자, 화분
    B.box(p, "counter_wood", 15.4, 17.2, 0.0, 1.05, 3.0, 6.5, True, tag="reception")
    B.box(p, "cork", 21.6, 23.6, 1.0, 2.2, 0.0, 0.04, tag="notice_board")
    for i, (px, py) in enumerate(((21.8, 1.8), (22.4, 1.5), (23.0, 1.85), (22.0, 1.15))):
        B.box(p, "paper" if i % 2 else "paper_yellow", px, px + 0.4, py, py + 0.3, 0.04, 0.05, tag="notice")
    for z0 in (6.5, 7.6):
        B.box(p, "bench_wood", 20.5, 23.5, 0.0, 0.45, z0, z0 + 0.45, True, tag="bench")
    B.cyl(p, "planter", 23.4, 1.0, 0.5, 0.0, 0.5)
    B.solid(p, 23.15, 23.65, 0.0, 0.5, 0.75, 1.25)
    # 기록실 (24~32): 서류 선반 3줄, 조사 테이블
    for z0 in (0.2, 2.2, 4.2):
        B.box(p, "shelf_metal", 24.6, 31.4 if z0 > 1 else 31.6, 0.0, 2.1, z0, z0 + 0.5, True, tag="shelf")
        for k in range(10):
            x = 24.8 + k * 0.65
            B.box(p, ("file_box", "book_a", "paper_old")[k % 3], x, x + 0.5, 0.95, 1.3, z0 + 0.05, z0 + 0.45, tag="files")
    B.box(p, "table_top", 25.0, 27.4, 0.72, 0.76, 7.0, 8.2, True, tag="table")
    B.box(p, "paper_old", 25.4, 26.6, 0.76, 0.77, 7.2, 8.0, tag="papers")
    # 임시 숙소 (0~8, 12~22)
    for z0 in (13.0, 17.0):
        B.box(p, "bed_frame", 0.3, 2.3, 0.0, 0.45, z0, z0 + 1.0, True, tag="bed")
        B.box(p, "bed", 0.35, 2.25, 0.45, 0.6, z0 + 0.05, z0 + 0.95, tag="mattress")
    B.box(p, "rack", 6.0, 7.8, 0.0, 1.6, 20.8, 21.8, True, tag="gear_rack")
    B.box(p, "bag", 4.0, 4.9, 0.0, 0.45, 14.0, 14.7, True, tag="gear_bag")
    B.box(p, "table_top", 4.2, 5.6, 0.7, 0.74, 18.0, 19.0, True, tag="table")
    # 브리핑룸 (8~17): 긴 탁자, 벽 화면(남쪽 벽 = 복도 벽의 북쪽 면)
    B.box(p, "table_top", 9.6, 15.4, 0.74, 0.78, 15.4, 17.6, True, tag="briefing_table")
    for x in (9.8, 15.1):
        B.box(p, "desk_frame", x, x + 0.1, 0.0, 0.74, 15.6, 17.4, tag="table_leg")
    B.box(p, "sh_screen", 9.2, 13.0, 1.0, 2.6, CORR[1] + 0.07, CORR[1] + 0.12, tag="screen")
    B.box(p, "floor_map", 13.6, 16.6, 1.0, 2.6, CORR[1] + 0.07, CORR[1] + 0.12, tag="map")
    for i in range(5):
        x = 10.0 + i * 1.2
        B.box(p, "paper", x, x + 0.5, 0.78, 0.79, 16.0, 16.6, tag="documents")
    # 협회장실 (17~25): 책상, 책장(남쪽 벽), 소파
    B.box(p, "desk_top", 19.6, 22.4, 0.74, 0.78, 19.4, 20.4, True, tag="desk")
    B.box(p, "office_panel", 19.7, 22.3, 0.0, 0.74, 19.5, 20.3, True, tag="desk_panel")
    B.box(p, "chair_office", 20.7, 21.3, 0.0, 1.1, 20.6, 21.2, True, tag="chair")
    B.box(p, "shelf_wood", 17.4, 20.0, 0.0, 2.2, CORR[1] + 0.07, CORR[1] + 0.5, True, tag="bookshelf")
    B.box(p, "shelf_wood", 22.2, 24.8, 0.0, 2.2, CORR[1] + 0.07, CORR[1] + 0.5, True, tag="bookshelf")
    B.box(p, "sofa", 17.4, 18.2, 0.0, 0.8, 15.0, 17.4, True, tag="sofa")
    B.box(p, "flag_school", 24.0, 24.6, 1.4, 2.4, 21.6, 21.8, tag="emblem")
    # 보호관리부 사무실 (25~32)
    for x0 in (26.0, 29.0):
        B.box(p, "office_top", x0, x0 + 1.6, 0.72, 0.76, 15.0, 15.8, True, tag="desk")
    B.box(p, "drawer_cabinet", 30.8, 31.8, 0.0, 1.3, 19.0, 21.6, True, tag="cabinet")


def npc(sw, res, mats_sub, name, label, inspect_id, pos, color):
    mat = sw.sub_res("npc_mat_" + name, "StandardMaterial3D", {"albedo_color": "Color(%.2f, %.2f, %.2f, 1)" % color,
                                                              "roughness": "0.8"})
    body = sw.sub_res("npc_body_" + name, "CapsuleMesh", {"radius": "0.25", "height": "1.45", "material": mat})
    head = sw.sub_res("npc_head_" + name, "SphereMesh", {"radius": "0.15", "height": "0.3", "material": mat})
    n = sw.node(name, "Node3D", "Npcs", {"transform": tf(pos), "script": res["inspect"], "inspect_id": q(inspect_id),
                                         "data_path": q("res://data/inspectables/safehouse.json"), "marker_height": "2.3"},
                groups=["npc"])
    base = "Npcs/" + n
    sw.node("Body", "MeshInstance3D", base, {"transform": tf((0.0, 0.78, 0.0)), "mesh": body}, unique=False)
    sw.node("Head", "MeshInstance3D", base, {"transform": tf((0.0, 1.66, 0.0)), "mesh": head}, unique=False)
    sw.node("NameTag", "Label3D", base, {"transform": tf((0.0, 2.05, 0.0)), "text": q(label), "billboard": "1",
                                         "font_size": "40", "outline_size": "10", "pixel_size": "0.006",
                                         "modulate": "Color(0.95, 0.95, 0.9, 1)", "no_depth_test": "true"}, unique=False)
    body_id = sw.node("Collider", "StaticBody3D", base, {}, unique=False)
    sw.node("Shape", "CollisionShape3D", base + "/" + body_id, {"transform": tf((0.0, 0.9, 0.0)),
                                                                "shape": sw.sub_res("npc_shape", "CapsuleShape3D",
                                                                                    {"radius": "0.32", "height": "1.8"})},
            unique=False)
    sw.node("InteractionPoint", "Marker3D", base, {"transform": tf((0.0, 1.0, 0.0))}, unique=False)


def main():
    sw = SceneWriter()
    batch = Batch()
    B = Builder(batch)
    res = {
        "controller": sw.ext_res("Script", "res://scripts/world/WorldPhaseController.gd"),
        "zone": sw.ext_res("Script", "res://scripts/world/ZoneArea.gd"),
        "ambient": sw.ext_res("Script", "res://scripts/world/AmbientSynth.gd"),
        "inspect": sw.ext_res("Script", "res://scripts/interactables/InspectInteractable.gd"),
        "door": sw.ext_res("PackedScene", "res://scenes/interactables/DoorInteractable.tscn"),
    }
    mats = palette.make(sw, EXTRA_MATS)
    env = sw.sub_res("env_safehouse", "Environment", {
        "background_mode": "1", "background_color": "Color(0.03, 0.03, 0.04, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.8, 0.82, 0.78, 1)", "ambient_light_energy": "0.5",
        "ssao_enabled": "true", "ssao_radius": "1.0", "ssao_intensity": "2.0", "ssao_power": "1.5", "ssao_light_affect": "0.2",
        "adjustment_enabled": "true", "adjustment_saturation": "0.85", "adjustment_contrast": "1.05"})
    sw.node("SafehouseWorld", "Node3D", None, {"script": res["controller"], "real_environment": env, "otherworld_environment": env,
                                               "world_environment": 'NodePath("WorldEnvironment")', "ambient": 'NodePath("Ambient")'},
            node_paths=["world_environment", "ambient"])
    sw.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env}, unique=False)
    sw.node("Ambient", "AudioStreamPlayer", ".", {"script": res["ambient"]}, unique=False)
    for name in ("Zones", "Site", "Doors", "Npcs"):
        sw.node(name, "Node3D", ".", {}, unique=False)
    sw.node("Buildings", "Node3D", ".", {}, unique=False)
    fp = FOOTPRINT
    sw.node(BUILDING, "Node3D", "Buildings", {
        "metadata/building": q(BUILDING), "metadata/footprint": "Rect2(%.3f, %.3f, %.3f, %.3f)" % (fp.x0, fp.z0, fp.w, fp.d),
        "metadata/base_y": "0.0", "metadata/top_y": "%.2f" % (ROOF_Y + 0.2)}, groups=["school_building"], unique=False)
    for idx, name in enumerate(("1F", "Roof")):
        sw.node(name, "Node3D", "Buildings/" + BUILDING, {
            "metadata/building": q(BUILDING), "metadata/level_index": str(idx), "metadata/cull_layer": str(2 + idx)},
                groups=["school_level"], unique=False)
        for child in ("Arch", "Props", "Lights"):
            sw.node(child, "Node3D", "Buildings/%s/%s" % (BUILDING, name), {}, unique=False)

    structure(B, sw, res)
    rooms(B)
    # 바깥 땅 (건물 둘레만)
    for x0, x1, z0, z1 in ((-12, W + 12, -10, -WT), (-12, W + 12, D + WT, D + 10), (-12, -WT, -WT, D + WT), (W + WT, W + 12, -WT, D + WT)):
        B.box("Site", "stone_dark", x0, x1, -0.25, -0.02, z0, z1, True, tag="ground")

    # 형광등 (방마다 하나, 복도 셋)
    cold = (0.92, 0.96, 1.0)
    for pos, rng in (((4.0, 3.0, 4.8), 6.0), ((11.5, 3.0, 4.8), 6.0), ((19.5, 3.0, 4.8), 7.0), ((28.0, 3.0, 4.8), 6.0),
                     ((4.0, 3.0, 17.0), 6.0), ((12.5, 3.0, 17.0), 6.5), ((21.0, 3.0, 17.0), 6.0), ((28.5, 3.0, 17.0), 6.0),
                     ((6.0, 3.0, 10.75), 6.0), ((16.0, 3.0, 10.75), 6.0), ((26.0, 3.0, 10.75), 6.0)):
        emit_light(sw, lv("1F", "Lights"), pos, rng, "real_light", cold, 0.85)
    emit_light(sw, lv("1F", "Lights"), (21.0, 1.6, 20.0), 3.0, "real_light", (1.0, 0.82, 0.6), 0.7)    # 협회장실 스탠드

    for zid, name, r in (("sh_infirmary", "치료실", Rect(0, 0, 8, CORR[0])), ("sh_workshop", "기술지원 작업실", Rect(8, 0, 15, CORR[0])),
                         ("sh_hall", "중앙 홀", Rect(15, 0, 24, CORR[0])), ("sh_records", "정보조사부 기록실", Rect(24, 0, W, CORR[0])),
                         ("sh_corridor", "본부 복도", Rect(0, CORR[0], W, CORR[1])), ("sh_quarters", "임시 숙소", Rect(0, CORR[1], 8, D)),
                         ("sh_briefing", "브리핑룸", Rect(8, CORR[1], 17, D)), ("sh_president", "협회장실", Rect(17, CORR[1], 25, D)),
                         ("sh_care_office", "보호관리부 사무실", Rect(25, CORR[1], W, D))):
        emit_zone(sw, "Zones", res["zone"], r, 0.0, 3.0, zid, name, BUILDING, 0)

    for name, label, iid, pos, color in NPCS:
        npc(sw, res, None, name, label, iid, pos, color)

    # 조사 대상: 중앙 홀 게시판
    sw.node("Inspectables", "Node3D", ".", {}, unique=False)
    sw.node("NoticeBoard", "Node3D", "Inspectables", {"transform": tf((22.6, 0.0, 0.2)), "script": res["inspect"],
                                                      "inspect_id": q("sh_notice_board"), "marker_height": "2.4",
                                                      "data_path": q("res://data/inspectables/safehouse.json")})
    sw.node("InteractionPoint", "Marker3D", "Inspectables/NoticeBoard", {"transform": tf((0.0, 1.1, 1.2))}, unique=False)

    sw.node("Spawn", "Marker3D", ".", {"transform": tf(START)}, unique=False)
    batch.emit(sw, mats)
    os.makedirs(os.path.join(ROOT, "scenes", "prologue"), exist_ok=True)
    path = os.path.join(ROOT, "scenes", "prologue", "SafehouseWorld.tscn")
    text = sw.text()
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", path, "nodes=%d boxes=%d" % (len(sw.nodes), len(batch.records)))
    write_chapter()
    return batch


def write_chapter():
    x, y, z = START
    lines = [
        "[gd_scene load_steps=10 format=3]", "",
        '[ext_resource type="Script" path="res://scripts/chapters/PrologueSafehouse.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="res://scenes/prologue/SafehouseWorld.tscn" id="2_world"]',
        '[ext_resource type="PackedScene" path="res://scenes/characters/PlayerParty.tscn" id="3_party"]',
        '[ext_resource type="PackedScene" path="res://scenes/cameras/FollowCamera.tscn" id="4_camera"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/PrototypeHUD.tscn" id="5_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/DialogueBox.tscn" id="6_dialogue"]',
        '[ext_resource type="Script" path="res://scripts/ui/VitalsOverlay.gd" id="7_overlay"]',
        '[ext_resource type="Script" path="res://scripts/ui/CaptionSequence.gd" id="8_caption"]',
        "",
        '[node name="PrologueSafehouse" type="Node3D"]', 'script = ExtResource("1_script")', "",
        '[node name="SafehouseWorld" parent="." node_paths=PackedStringArray("party", "camera") instance=ExtResource("2_world")]',
        'party = NodePath("../PlayerParty")', 'camera = NodePath("../FollowCamera")', "",
        '[node name="PlayerParty" parent="." node_paths=PackedStringArray("camera") instance=ExtResource("3_party")]',
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (x, y, z), 'camera = NodePath("../FollowCamera")', "",
        '[node name="FollowCamera" parent="." node_paths=PackedStringArray("target") instance=ExtResource("4_camera")]',
        'target = NodePath("../PlayerParty/Sabi")', "",
        '[node name="PrototypeHUD" parent="." node_paths=PackedStringArray("party", "school_map") instance=ExtResource("5_hud")]',
        'party = NodePath("../PlayerParty")', 'school_map = NodePath("../SafehouseWorld")', "",
        '[node name="DialogueBox" parent="." instance=ExtResource("6_dialogue")]', "",
        '[node name="VitalsOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("party")]',
        'script = ExtResource("7_overlay")', 'party = NodePath("../PlayerParty")', "",
        '[node name="CaptionSequence" type="CanvasLayer" parent="."]', 'script = ExtResource("8_caption")', "",
    ]
    path = os.path.join(ROOT, "scenes", "chapters", "Prologue_Safehouse.tscn")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    main()
