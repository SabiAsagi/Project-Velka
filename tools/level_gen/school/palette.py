# -*- coding: utf-8 -*-
"""재질 팔레트: 학교 표면 셰이더(school_surface) 파라미터. 가이드라인 색 기준.
외벽 회백·베이지 + 하단 짙은 회색 / 복도 아래 회녹색·위 아이보리 / 교실 장판 / 복도 테라조 등."""

import json as _json
import os as _os

SHADER = "res://assets/shaders/school_surface.gdshader"

# 키: (albedo, 추가 파라미터)
S = {}


def mat(key, rgb, **kw):
    S[key] = (rgb, kw)


# 외벽 (하단 0.9m 짙은 회색 마감: 본관은 고지대 3.8m 기준)
mat("facade_main", (0.86, 0.83, 0.76), band=(0.33, 0.33, 0.34), band_height=0.9, band_absolute=1, band_base=3.8, grime=0.07)
mat("facade_annex", (0.85, 0.82, 0.75), band=(0.33, 0.33, 0.34), band_height=0.9, band_absolute=1, band_base=0.0, grime=0.07)
mat("facade_gym", (0.83, 0.82, 0.78), band=(0.33, 0.33, 0.34), band_height=0.9, band_absolute=1, band_base=0.0, grime=0.07)
# 실내 벽
mat("wall_corridor", (0.9, 0.88, 0.8), band=(0.6, 0.66, 0.6), band_height=1.1)
mat("wall_class", (0.9, 0.88, 0.82), band=(0.4, 0.34, 0.28), band_height=0.1)
mat("wall_office", (0.87, 0.85, 0.79), band=(0.42, 0.4, 0.36), band_height=0.1)
mat("wall_nurse", (0.86, 0.9, 0.87), band=(0.5, 0.56, 0.54), band_height=0.1)
mat("wall_acoustic", (0.78, 0.7, 0.58), band=(0.52, 0.4, 0.29), band_height=1.0, grime=0.08)
mat("wall_tile", (0.88, 0.9, 0.9), band=(0.7, 0.77, 0.8), band_height=1.3, wall_tile_size=0.25, grime=0.03)
mat("wall_tile_light", (0.9, 0.9, 0.87), band=(0.78, 0.8, 0.8), band_height=1.2, wall_tile_size=0.3, grime=0.03)
mat("wall_concrete", (0.66, 0.66, 0.64), grime=0.12)
mat("wall_lobby", (0.88, 0.86, 0.8), band=(0.52, 0.5, 0.46), band_height=1.0)
mat("wall_cafeteria", (0.9, 0.88, 0.82), band=(0.7, 0.75, 0.73), band_height=1.2, wall_tile_size=0.3)
mat("wall_library", (0.88, 0.85, 0.78), band=(0.5, 0.38, 0.26), band_height=0.9)
mat("wall_b1", (0.62, 0.63, 0.6), band=(0.42, 0.44, 0.42), band_height=0.3, grime=0.18)
mat("wall_b1_flood", (0.6, 0.61, 0.57), band=(0.37, 0.4, 0.35), band_height=0.75, grime=0.34)   # 침수 물 자국선 (0.75m)
mat("wall_gym", (0.86, 0.84, 0.78), band=(0.6, 0.52, 0.4), band_height=0.15)
mat("wall_stage", (0.2, 0.18, 0.2), grime=0.04)
mat("parapet_in", (0.7, 0.7, 0.68), grime=0.12)
# 바닥
mat("floor_class", (0.66, 0.55, 0.42), tile_size=0.6, tile_line=(0.5, 0.42, 0.32), cut=0)
mat("floor_corridor", (0.7, 0.69, 0.66), tile_size=0.9, tile_line=(0.46, 0.46, 0.44), grime=0.08, cut=0)
mat("floor_office", (0.6, 0.6, 0.58), tile_size=0.5, tile_line=(0.47, 0.47, 0.46), cut=0)
mat("floor_wood", (0.58, 0.42, 0.28), grime=0.1, cut=0)
mat("floor_nurse", (0.72, 0.76, 0.74), tile_size=0.45, tile_line=(0.58, 0.62, 0.6), cut=0)
mat("floor_carpet", (0.4, 0.44, 0.52), tile_size=0.5, tile_line=(0.35, 0.38, 0.45), grime=0.08, cut=0)
mat("floor_toilet", (0.64, 0.68, 0.7), tile_size=0.2, tile_line=(0.45, 0.48, 0.5), cut=0)
mat("floor_kitchen", (0.56, 0.38, 0.32), tile_size=0.3, tile_line=(0.38, 0.28, 0.24), cut=0)
mat("floor_concrete", (0.55, 0.55, 0.53), grime=0.15, cut=0)
mat("floor_lobby", (0.6, 0.58, 0.54), tile_size=0.6, tile_line=(0.42, 0.4, 0.38), cut=0)
mat("floor_bridge", (0.52, 0.55, 0.6), tile_size=0.5, tile_line=(0.4, 0.42, 0.46), cut=0)
mat("floor_cafeteria", (0.7, 0.68, 0.62), tile_size=0.4, tile_line=(0.55, 0.53, 0.48), cut=0)
mat("floor_lab", (0.62, 0.64, 0.66), tile_size=0.45, tile_line=(0.5, 0.52, 0.54), cut=0)
mat("floor_b1", (0.5, 0.5, 0.48), tile_size=1.5, tile_line=(0.4, 0.4, 0.39), grime=0.2, cut=0)
mat("floor_b1_old", (0.46, 0.36, 0.26), grime=0.2, cut=0)
mat("floor_gym", (0.76, 0.56, 0.34), grime=0.06, cut=0)
mat("floor_stage", (0.32, 0.22, 0.16), grime=0.05)
mat("floor_roof", (0.38, 0.5, 0.4), grime=0.15, cut=0)
mat("roof_metal", (0.5, 0.54, 0.58), grime=0.1)
# 창·금속·마감
mat("win_frame", (0.58, 0.6, 0.62), roughness=0.45, metallic=0.4, grime=0.05)
mat("win_frame_new", (0.7, 0.72, 0.74), roughness=0.4, metallic=0.45, grime=0.02)
mat("sill", (0.8, 0.79, 0.75))
mat("sill_out", (0.55, 0.55, 0.55))
mat("coping", (0.55, 0.55, 0.55), grime=0.12)
mat("rail_metal", (0.5, 0.52, 0.55), roughness=0.4, metallic=0.6)
mat("kick_plate", (0.4, 0.42, 0.45), metallic=0.4)
mat("canopy", (0.52, 0.54, 0.56), metallic=0.3)
mat("pillar_dark", (0.42, 0.39, 0.36))
mat("steel", (0.72, 0.74, 0.76), roughness=0.3, metallic=0.8, grime=0.02)
mat("steel_frame", (0.6, 0.62, 0.64), roughness=0.35, metallic=0.7)

# 계단·부지
mat("stair", (0.66, 0.66, 0.63), grime=0.08)
mat("seat_tier", (0.56, 0.57, 0.58), grime=0.1, cut=0)
mat("metal_grate", (0.4, 0.42, 0.44), metallic=0.5, grime=0.1)
mat("ground", (0.25, 0.31, 0.21), grime=0.18, cut=0)
mat("plateau", (0.46, 0.46, 0.44), grime=0.12, cut=0)
mat("stone_wall", (0.5, 0.49, 0.46), grime=0.2, wall_tile_size=0.6, cut=0)   # 석축·계단 난간벽 (줄눈이 보이는 돌쌓기)
mat("sand", (0.78, 0.7, 0.52), grime=0.12, cut=0)
mat("earth_cut", (0.2, 0.17, 0.14), grime=0.3, cut=0)          # 본관 지하에 있을 때 드러나는 흙 단면 바닥
mat("facade_b1", (0.5, 0.5, 0.48), grime=0.22)                 # 본관 지하 외벽 (땅에 묻힌 콘크리트 기초)
# 구 도서관 침수 흔적
mat("silt", (0.3, 0.26, 0.2), grime=0.3, cut=0)
mat("mold", (0.3, 0.34, 0.28), grime=0.4)
mat("shelf_wet", (0.27, 0.21, 0.16), grime=0.3, cut_scale=0.85, cut_min=0.95)
mat("book_wet", (0.42, 0.38, 0.3), grime=0.3, cut_scale=0.85, cut_min=0.95)
mat("tarp_blue", (0.2, 0.36, 0.62), roughness=0.5, grime=0.1, cut_scale=0.85, cut_min=0.95)
mat("sandbag", (0.66, 0.6, 0.47), grime=0.22, cut_scale=0.85, cut_min=0.95)
mat("hose_blue", (0.16, 0.32, 0.55), roughness=0.5, cut=0)
mat("rubber_green", (0.3, 0.47, 0.36), grime=0.14, cut=0)       # 체력단련장 탄성 고무 매트
mat("rubber_blue", (0.3, 0.4, 0.56), grime=0.14, cut=0)
mat("stand", (0.52, 0.5, 0.47), grime=0.1, cut=0)             # 옹벽형 스탠드·관람 스탠드 (속이 찬 덩어리라 걷어내지 않는다)
mat("site_stair", (0.66, 0.66, 0.63), grime=0.08, cut=0)      # 부지 계단·경사로
mat("metal", (0.35, 0.37, 0.4), metallic=0.5)
mat("fence", (0.3, 0.33, 0.3), metallic=0.3)
mat("rail", (0.42, 0.44, 0.47), metallic=0.5)
for _k, _c in {"AthleticField": (0.5, 0.4, 0.3), "Road": (0.3, 0.3, 0.32), "Path": (0.44, 0.43, 0.42),
               "Garden": (0.27, 0.38, 0.24), "Court": (0.3, 0.45, 0.62), "Fitness": (0.36, 0.3, 0.3),
               "Forest": (0.16, 0.24, 0.15), "Parking": (0.28, 0.28, 0.3), "Plaza": (0.44, 0.43, 0.42),
               "Plot": (0.34, 0.26, 0.18), "Trail": (0.52, 0.45, 0.34)}.items():
    mat("pad_" + _k, _c, grime=0.15, cut=0)


# ---------------- 가구·소품 (컷어웨이는 벽보다 조금 작은 반경)
for _k, _c, _kw in [
    ("desk_top", (0.74, 0.62, 0.46), {}), ("desk_shelf", (0.5, 0.51, 0.53), {"metallic": 0.3}),
    ("desk_frame", (0.35, 0.37, 0.4), {"metallic": 0.4}), ("chair_seat", (0.64, 0.5, 0.35), {}),
    ("chair_frame", (0.33, 0.35, 0.38), {"metallic": 0.4}), ("bag", (0.24, 0.29, 0.45), {}), ("book_a", (0.7, 0.25, 0.2), {}),
    ("book_b", (0.2, 0.35, 0.6), {}), ("book_c", (0.86, 0.8, 0.6), {}), ("pencil_case", (0.3, 0.55, 0.4), {}),
    ("pencil_case2", (0.86, 0.42, 0.6), {}), ("bottle", (0.5, 0.75, 0.86), {"roughness": 0.3}), ("cushion", (0.92, 0.6, 0.3), {}),
    ("paper", (0.95, 0.95, 0.92), {"grime": 0.0}), ("paper_yellow", (0.96, 0.9, 0.55), {"grime": 0.0}),
    ("paper_blue", (0.62, 0.78, 0.92), {"grime": 0.0}), ("paper_pink", (0.95, 0.72, 0.78), {"grime": 0.0}),
    ("bench_wood", (0.55, 0.4, 0.26), {}), ("metal_dark", (0.25, 0.26, 0.28), {"metallic": 0.4}),
    ("cabinet_metal", (0.62, 0.65, 0.66), {"metallic": 0.3}), ("cleaning_cabinet", (0.55, 0.62, 0.66), {"metallic": 0.3}),
    ("shelf_wood", (0.6, 0.46, 0.3), {}), ("frame_alu", (0.72, 0.73, 0.75), {"metallic": 0.5}), ("cork", (0.7, 0.55, 0.35), {}),
    ("pot", (0.6, 0.35, 0.25), {}), ("leaf", (0.25, 0.5, 0.22), {}), ("bin_gray", (0.45, 0.47, 0.5), {}),
    ("bin_blue", (0.2, 0.45, 0.75), {}), ("bin_yellow", (0.9, 0.75, 0.2), {}), ("bin_green", (0.3, 0.6, 0.35), {}),
    ("curtain", (0.9, 0.85, 0.66), {}), ("chalkboard", (0.13, 0.29, 0.21), {"grime": 0.08}),
    ("chalkboard_erased", (0.33, 0.45, 0.39), {"grime": 0.25}), ("eraser", (0.3, 0.3, 0.35), {}), ("chalk", (0.96, 0.96, 0.95), {}),
    ("clock_rim", (0.2, 0.2, 0.22), {}), ("clock_face", (0.95, 0.95, 0.93), {"grime": 0.0}), ("speaker", (0.86, 0.86, 0.83), {}),
    ("whiteboard", (0.96, 0.97, 0.97), {"grime": 0.02}), ("tv", (0.08, 0.08, 0.1), {"roughness": 0.3}),
    ("lectern", (0.55, 0.42, 0.3), {}), ("lectern_top", (0.62, 0.48, 0.34), {}), ("attendance", (0.25, 0.3, 0.55), {}),
    ("chalk_box", (0.9, 0.9, 0.85), {}), ("pen_cup", (0.3, 0.3, 0.32), {}), ("monitor", (0.1, 0.1, 0.12), {"roughness": 0.3}),
    ("locker", (0.56, 0.63, 0.69), {"metallic": 0.3}), ("locker_line", (0.3, 0.33, 0.36), {}), ("box", (0.72, 0.58, 0.4), {}),
    ("aircon", (0.92, 0.92, 0.9), {}), ("sensor", (0.95, 0.95, 0.95), {}), ("watering_can", (0.3, 0.6, 0.35), {}),
    ("art_red", (0.86, 0.3, 0.25), {"grime": 0.0}), ("art_blue", (0.3, 0.5, 0.86), {"grime": 0.0}),
    ("art_yellow", (0.95, 0.8, 0.25), {"grime": 0.0}), ("art_green", (0.35, 0.7, 0.4), {"grime": 0.0}),
    ("ball", (0.9, 0.5, 0.15), {}), ("banner_roll", (0.9, 0.9, 0.85), {}), ("sign_board", (0.75, 0.6, 0.4), {}),
    ("cheer_stick", (0.95, 0.4, 0.6), {}), ("photo", (0.42, 0.46, 0.5), {}), ("file_box", (0.35, 0.45, 0.6), {}),
    ("hydrant_box", (0.75, 0.15, 0.12), {}), ("hydrant_door", (0.86, 0.22, 0.16), {}), ("extinguisher", (0.8, 0.1, 0.08), {"roughness": 0.4}),
    ("purifier", (0.94, 0.94, 0.95), {"roughness": 0.4}), ("floor_map", (0.85, 0.9, 0.95), {"grime": 0.0}),
    ("wet_sign", (0.95, 0.8, 0.1), {}), ("umbrella", (0.2, 0.25, 0.45), {}), ("cctv", (0.9, 0.9, 0.88), {}),
    ("toilet_partition", (0.78, 0.8, 0.82), {}), ("counter_white", (0.9, 0.9, 0.88), {}), ("porcelain", (0.95, 0.96, 0.97), {"roughness": 0.3}),
    ("mirror", (0.75, 0.82, 0.88), {"roughness": 0.05, "metallic": 0.6}), ("soap", (0.85, 0.9, 0.95), {}),
    ("stall_panel", (0.62, 0.7, 0.78), {}), ("stall_door", (0.66, 0.74, 0.82), {}), ("drain", (0.3, 0.3, 0.32), {"metallic": 0.4}),
    ("hose_reel", (0.2, 0.45, 0.3), {}), ("shelf_metal", (0.6, 0.62, 0.64), {"metallic": 0.4}), ("mop_stick", (0.75, 0.75, 0.72), {}),
    ("mop_head", (0.85, 0.83, 0.75), {}), ("bucket_blue", (0.25, 0.45, 0.75), {}), ("bucket_red", (0.8, 0.25, 0.2), {}),
    ("office_top", (0.78, 0.74, 0.66), {}), ("office_drawer", (0.62, 0.64, 0.66), {"metallic": 0.3}), ("office_panel", (0.58, 0.6, 0.62), {}),
    ("chair_office", (0.2, 0.22, 0.26), {}), ("keyboard", (0.15, 0.15, 0.17), {}), ("mug_red", (0.8, 0.25, 0.2), {}),
    ("mug_blue", (0.25, 0.4, 0.75), {}), ("mug_white", (0.95, 0.95, 0.93), {}), ("mug_green", (0.3, 0.6, 0.4), {}),
    ("wood_dark", (0.32, 0.22, 0.14), {}), ("table_top", (0.8, 0.72, 0.58), {}), ("carrel_panel", (0.66, 0.6, 0.5), {}),
    ("lamp", (0.95, 0.93, 0.85), {"emission": 0.3}), ("sofa", (0.36, 0.24, 0.2), {}), ("bed_frame", (0.8, 0.82, 0.84), {"metallic": 0.3}),
    ("bed", (0.95, 0.96, 0.97), {}), ("pillow", (0.98, 0.98, 0.98), {}), ("blind", (0.88, 0.87, 0.82), {}),
    ("curtain_heavy", (0.35, 0.18, 0.2), {}), ("curtain_light", (0.96, 0.95, 0.88), {}), ("cloth", (0.62, 0.76, 0.72), {}),
    ("mat_dark", (0.22, 0.24, 0.26), {"cut": 0}), ("frame_wood", (0.45, 0.32, 0.2), {}), ("glass_case", (0.7, 0.78, 0.82), {"roughness": 0.1, "metallic": 0.3}),
    ("trophy", (0.85, 0.7, 0.25), {"metallic": 0.7, "roughness": 0.3}),
    ("trophy_silver", (0.78, 0.8, 0.82), {"metallic": 0.75, "roughness": 0.3}), ("trophy_bronze", (0.62, 0.38, 0.2), {"metallic": 0.6, "roughness": 0.35}),
    ("uniform_navy", (0.11, 0.14, 0.26), {}), ("uniform_shirt", (0.93, 0.94, 0.95), {"grime": 0.02}),
    ("uniform_check", (0.24, 0.24, 0.32), {}), ("uniform_tie", (0.55, 0.1, 0.14), {}), ("mannequin", (0.86, 0.8, 0.72), {}),
    ("velvet", (0.3, 0.06, 0.08), {}), ("ribbon_blue", (0.15, 0.3, 0.7), {}), ("aed", (0.2, 0.6, 0.3), {}), ("lost_box", (0.5, 0.55, 0.65), {}),
    ("counter_wood", (0.6, 0.47, 0.33), {}), ("counter_top", (0.85, 0.83, 0.78), {}), ("seal_box", (0.5, 0.15, 0.12), {}),
    ("safe", (0.3, 0.32, 0.34), {"metallic": 0.5}), ("copier", (0.88, 0.88, 0.86), {}), ("mailbox", (0.6, 0.5, 0.35), {}),
    ("terminal", (0.2, 0.22, 0.25), {}), ("cabinet_wood", (0.55, 0.42, 0.3), {}), ("key_board", (0.5, 0.38, 0.25), {}),
    ("coffee", (0.15, 0.15, 0.16), {}), ("flag_kr", (0.95, 0.95, 0.95), {}), ("flag_school", (0.2, 0.3, 0.6), {}),
    ("table_low", (0.4, 0.28, 0.18), {}), ("cup_white", (0.95, 0.95, 0.93), {}), ("medicine_cabinet", (0.9, 0.92, 0.93), {}),
    ("fridge_small", (0.9, 0.9, 0.9), {}), ("stretcher", (0.35, 0.5, 0.7), {}), ("console", (0.18, 0.18, 0.2), {}),
    ("booth_wall", (0.7, 0.62, 0.52), {}), ("glass_dark", (0.3, 0.38, 0.45), {"roughness": 0.1}), ("rack", (0.12, 0.12, 0.14), {}),
    ("panel_red", (0.75, 0.15, 0.12), {}), ("cable_reel", (0.25, 0.25, 0.28), {}), ("flashlight", (0.9, 0.8, 0.2), {}),
    ("picket", (0.95, 0.9, 0.3), {}), ("vest", (0.95, 0.55, 0.15), {}), ("megaphone", (0.9, 0.9, 0.88), {}),
    ("shoe_rack", (0.62, 0.52, 0.4), {}), ("charge_box", (0.4, 0.45, 0.5), {}), ("phone_box", (0.3, 0.35, 0.45), {}),
    ("workbench", (0.62, 0.5, 0.36), {}), ("cutting_mat", (0.2, 0.45, 0.35), {}), ("drying_rack", (0.5, 0.52, 0.55), {"metallic": 0.4}),
    ("easel", (0.55, 0.42, 0.28), {}), ("canvas", (0.95, 0.94, 0.9), {}), ("camera", (0.1, 0.1, 0.12), {}),
    ("backdrop", (0.85, 0.85, 0.82), {}), ("studio_light", (0.2, 0.2, 0.22), {}), ("lab_bench", (0.25, 0.27, 0.3), {}),
    ("microscope", (0.85, 0.85, 0.85), {"metallic": 0.4}), ("globe", (0.3, 0.5, 0.75), {}), ("jar", (0.7, 0.8, 0.7), {"roughness": 0.2}),
    ("first_aid", (0.95, 0.95, 0.95), {}),
    ("pipe", (0.55, 0.57, 0.6), {"metallic": 0.5, "grime": 0.12}), ("pipe_red", (0.6, 0.2, 0.17), {"metallic": 0.3, "grime": 0.12}),
    ("shelf_old", (0.45, 0.35, 0.26), {"grime": 0.2}), ("card_catalog", (0.5, 0.36, 0.22), {}), ("monitor_old", (0.75, 0.73, 0.66), {}),
    ("cart", (0.5, 0.52, 0.55), {"metallic": 0.3}), ("book_old", (0.45, 0.38, 0.3), {"grime": 0.2}), ("vinyl", (0.85, 0.88, 0.9), {"roughness": 0.2}),
    ("map_cabinet", (0.4, 0.42, 0.38), {}), ("dehumidifier", (0.9, 0.9, 0.88), {}), ("tape", (0.75, 0.6, 0.4), {}),
    ("mobile_shelf", (0.62, 0.66, 0.62), {"metallic": 0.3}), ("mobile_wheel", (0.3, 0.3, 0.32), {}), ("label_white", (0.96, 0.96, 0.94), {}),
    ("scanner", (0.3, 0.3, 0.32), {}), ("shredder", (0.25, 0.25, 0.27), {}), ("drawer_cabinet", (0.55, 0.58, 0.55), {"metallic": 0.3}),
    ("pallet", (0.6, 0.48, 0.32), {}), ("ladder", (0.75, 0.72, 0.4), {"metallic": 0.3}), ("boiler", (0.7, 0.72, 0.74), {"metallic": 0.4, "grime": 0.15}),
    ("boiler_band", (0.75, 0.2, 0.15), {}), ("gauge", (0.95, 0.95, 0.9), {}), ("pump", (0.25, 0.4, 0.55), {"metallic": 0.4}),
    ("control_panel", (0.62, 0.64, 0.6), {}), ("fan", (0.4, 0.42, 0.44), {}), ("panel_gray", (0.66, 0.68, 0.66), {"metallic": 0.3}),
    ("cable_tray", (0.5, 0.52, 0.5), {}), ("rubber_mat", (0.15, 0.15, 0.16), {"cut": 0}), ("pegboard", (0.7, 0.6, 0.45), {}),
    ("paint_can", (0.75, 0.75, 0.72), {}), ("pump_red", (0.72, 0.15, 0.12), {"metallic": 0.3}), ("paper_old", (0.85, 0.8, 0.65), {}),
]:
    _kw = dict(_kw)
    _kw.setdefault("cut_scale", 0.85)
    _kw.setdefault("cut_min", 0.95)
    _kw.setdefault("ivar", 0.03)
    mat(_k, _c, **_kw)

# ---------------- 별관·강당·옥상·부지 소품
for _k, _c, _kw in [
    ("stainless", (0.76, 0.78, 0.8), {"roughness": 0.35, "metallic": 0.65, "grime": 0.03}),
    ("stainless_dark", (0.5, 0.52, 0.55), {"roughness": 0.4, "metallic": 0.6}),
    ("tray", (0.84, 0.82, 0.76), {"roughness": 0.5}), ("food_rice", (0.95, 0.94, 0.9), {"grime": 0.0}),
    ("food_soup", (0.68, 0.36, 0.2), {"grime": 0.0}), ("food_green", (0.36, 0.56, 0.3), {"grime": 0.0}),
    ("food_red", (0.74, 0.24, 0.18), {"grime": 0.0}), ("food_yellow", (0.92, 0.76, 0.3), {"grime": 0.0}),
    ("caf_table", (0.84, 0.85, 0.84), {"roughness": 0.6}), ("caf_stool", (0.27, 0.42, 0.62), {}),
    ("vending_red", (0.72, 0.14, 0.13), {}), ("vending_blue", (0.16, 0.3, 0.58), {}),
    ("vending_panel", (0.92, 0.94, 0.96), {"emission": 0.45, "grime": 0.0}), ("sack", (0.88, 0.84, 0.72), {}),
    ("apron", (0.94, 0.94, 0.92), {}), ("uv_lamp", (0.5, 0.42, 0.95), {"emission": 0.7, "grime": 0.0}),
    ("sign_green", (0.14, 0.56, 0.3), {"emission": 0.35, "grime": 0.0}), ("sign_blue", (0.2, 0.34, 0.6), {"grime": 0.0}),
    ("piano", (0.05, 0.05, 0.06), {"roughness": 0.2}), ("piano_key", (0.95, 0.95, 0.93), {"grime": 0.0}),
    ("case_black", (0.14, 0.14, 0.16), {}), ("instrument_wood", (0.66, 0.45, 0.24), {"roughness": 0.4}),
    ("drum_shell", (0.68, 0.14, 0.14), {"roughness": 0.4}), ("drum_head", (0.93, 0.92, 0.88), {}),
    ("brass", (0.78, 0.62, 0.25), {"roughness": 0.3, "metallic": 0.7}),
    ("acoustic_a", (0.56, 0.45, 0.34), {}), ("acoustic_b", (0.4, 0.44, 0.5), {}), ("riser", (0.46, 0.33, 0.22), {}),
    ("plaster", (0.92, 0.92, 0.9), {}), ("clay", (0.6, 0.45, 0.35), {}), ("stool_seat", (0.5, 0.36, 0.25), {}),
    ("safety_yellow", (0.95, 0.8, 0.1), {"grime": 0.0}), ("safety_green", (0.14, 0.6, 0.35), {"grime": 0.0}),
    ("fume_hood", (0.86, 0.87, 0.85), {}), ("bone", (0.9, 0.88, 0.8), {}), ("anatomy_skin", (0.86, 0.66, 0.56), {}),
    ("anatomy_red", (0.7, 0.24, 0.24), {}), ("pc_tower", (0.12, 0.12, 0.14), {}),
    ("led_green", (0.2, 0.9, 0.4), {"emission": 1.0, "grime": 0.0}), ("screen_on", (0.5, 0.7, 0.9), {"emission": 0.5, "grime": 0.0}),
    ("sofa_blue", (0.3, 0.38, 0.5), {}), ("sofa_green", (0.32, 0.44, 0.38), {}),
    ("gate_panel", (0.86, 0.87, 0.89), {}), ("gate_stripe", (0.2, 0.3, 0.5), {}), ("book_return", (0.25, 0.36, 0.5), {}),
    ("magazine_a", (0.85, 0.3, 0.35), {"grime": 0.0}), ("magazine_b", (0.25, 0.55, 0.7), {"grime": 0.0}),
    ("magazine_c", (0.95, 0.85, 0.4), {"grime": 0.0}), ("periodic", (0.8, 0.88, 0.8), {"grime": 0.0}),
    ("poster_night", (0.1, 0.12, 0.3), {"grime": 0.0}), ("screen_white", (0.96, 0.96, 0.94), {"grime": 0.0}),
    ("locker_blue", (0.42, 0.52, 0.66), {"metallic": 0.3}), ("locker_gray", (0.66, 0.68, 0.68), {"metallic": 0.3}),
    ("pad_blue", (0.2, 0.36, 0.62), {}), ("gym_mat", (0.24, 0.42, 0.7), {}), ("gym_mat_green", (0.25, 0.55, 0.4), {}),
    ("led_red", (0.95, 0.16, 0.1), {"emission": 1.0, "grime": 0.0}), ("seat_plastic", (0.24, 0.42, 0.66), {}),
    ("curtain_stage", (0.46, 0.1, 0.13), {}), ("hoop_rim", (0.92, 0.42, 0.12), {"metallic": 0.3}),
    ("net_white", (0.95, 0.95, 0.93), {}), ("vault_top", (0.86, 0.82, 0.72), {}), ("cone", (0.95, 0.45, 0.1), {}),
    ("emblem", (0.16, 0.26, 0.5), {"grime": 0.0}), ("emblem_gold", (0.85, 0.7, 0.3), {"grime": 0.0}),
    ("wall_patch", (0.82, 0.8, 0.7), {"grime": 0.12}),
]:
    _kw = dict(_kw)
    _kw.setdefault("cut_scale", 0.85)
    _kw.setdefault("cut_min", 0.95)
    _kw.setdefault("ivar", 0.03)
    mat(_k, _c, **_kw)
# 바닥에 붙는 표시·배수로 (컷어웨이 대상 아님)
mat("drain_grate", (0.28, 0.29, 0.3), metallic=0.4, cut=0)
mat("floor_mark_yellow", (0.9, 0.76, 0.12), grime=0.02, cut=0)
mat("floor_mark_white", (0.92, 0.92, 0.9), grime=0.02, cut=0)
mat("cable_duct", (0.44, 0.45, 0.47), cut=0)
mat("floor_mark_blue", (0.22, 0.4, 0.7), grime=0.02, cut=0)
mat("roof_path", (0.62, 0.62, 0.6), tile_size=0.6, tile_line=(0.5, 0.5, 0.48), grime=0.1, cut=0)
mat("soil", (0.3, 0.22, 0.15), grime=0.2, cut=0)
mat("planter", (0.5, 0.48, 0.45), grime=0.12)
mat("shrub", (0.22, 0.42, 0.2), grime=0.15)
mat("shrub_light", (0.36, 0.52, 0.24), grime=0.12)
mat("trunk", (0.36, 0.26, 0.17), grime=0.15)
mat("tank", (0.74, 0.77, 0.8), roughness=0.5, metallic=0.4, grime=0.1)
mat("leaf_dark", (0.16, 0.32, 0.17), grime=0.18, cut_scale=2.6, cut_min=1.6, cut_fade=1.6)
mat("leaf_mid", (0.24, 0.42, 0.2), grime=0.15, cut_scale=2.6, cut_min=1.6, cut_fade=1.6)
mat("leaf_light", (0.38, 0.54, 0.26), grime=0.12, cut_scale=2.6, cut_min=1.6, cut_fade=1.6)
mat("bark", (0.33, 0.25, 0.18), grime=0.2, cut_scale=1.2, cut_min=1.6)
# 건물 옆 좁은 상록수: 작아서 넓게 걷어내면 조각만 남는다. 가구와 같은 반경으로만 걷어낸다.
mat("slim_dark", (0.16, 0.32, 0.17), grime=0.18, cut_scale=1.0, cut_min=1.2)
mat("slim_mid", (0.24, 0.42, 0.2), grime=0.15, cut_scale=1.0, cut_min=1.2)
mat("slim_light", (0.38, 0.54, 0.26), grime=0.12, cut_scale=1.0, cut_min=1.2)
mat("stone", (0.55, 0.54, 0.52), grime=0.15)
mat("stone_dark", (0.36, 0.36, 0.37), grime=0.15)
mat("lamp_post", (0.2, 0.22, 0.24), roughness=0.5, metallic=0.5)
mat("lamp_head", (0.95, 0.93, 0.82), emission=0.35, grime=0.0)
mat("car_white", (0.86, 0.87, 0.88), roughness=0.35, metallic=0.3)
mat("car_gray", (0.36, 0.38, 0.42), roughness=0.35, metallic=0.4)
mat("car_blue", (0.2, 0.3, 0.5), roughness=0.35, metallic=0.4)
mat("car_glass", (0.16, 0.2, 0.25), roughness=0.1, metallic=0.5)
mat("tire", (0.08, 0.08, 0.09))
mat("line_white", (0.92, 0.92, 0.9), grime=0.04, cut=0)
mat("line_yellow", (0.88, 0.74, 0.14), grime=0.04, cut=0)
mat("court_line", (0.95, 0.95, 0.96), grime=0.02, cut=0)
mat("soil_bed", (0.3, 0.22, 0.15), grime=0.2)
mat("bank_grass", (0.22, 0.3, 0.18), grime=0.2, cut=0)
mat("crop", (0.3, 0.55, 0.24), grime=0.1)
mat("fit_steel", (0.2, 0.42, 0.62), roughness=0.4, metallic=0.5)
mat("fit_yellow", (0.9, 0.72, 0.12), roughness=0.5)
mat("goal_white", (0.94, 0.94, 0.94), roughness=0.5)
mat("roof_guard", (0.34, 0.36, 0.4), grime=0.1)
# 부지 소품은 실내 가구와 같은 기준으로 걷어낸다 (허리 높이 아래는 남긴다)
for _k in ("planter", "shrub", "shrub_light", "trunk", "tank", "stone", "stone_dark", "lamp_post", "lamp_head", "car_white",
           "car_gray", "car_blue", "car_glass", "tire", "soil_bed", "crop", "fit_steel", "fit_yellow", "goal_white"):
    S[_k][1].setdefault("cut_scale", 0.85)
    S[_k][1].setdefault("cut_min", 0.95)

# 텍스처·사용감 (palette_tex.py)
import palette_tex as _palette_tex
_palette_tex.apply(S)

GLASS = {"glass": (0.58, 0.72, 0.8, 0.4), "glass_frosted": (0.82, 0.86, 0.88, 0.8),
         "water": (0.12, 0.17, 0.2, 0.5)}        # 고인 물 (바닥이 비쳐 보인다)


NOISE = "res://assets/textures/school/surface_noise.png"
LEAK = "res://assets/third_party/ambientcg/Leaking001/Leaking001_Opacity.jpg"
# 텍스처 이름 -> {path, avg(선형 평균색)}: texture_tool.gd가 만든다
_STATS = _json.load(open(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), "texture_stats.json"), encoding="utf-8"))


def _col(c, a=1.0):
    return "Color(%.3f, %.3f, %.3f, %.3f)" % (c[0], c[1], c[2], a)


def _vec3(c):
    return "Vector3(%.4f, %.4f, %.4f)" % tuple(c)


def _tex(sw, name):
    """텍스처 이름 -> (색 텍스처 참조, 노멀 텍스처 참조 또는 None, 선형 평균색)"""
    st = _STATS[name]
    path = st["path"]
    nrm = path.replace("_Color.jpg", "_NormalGL.jpg") if path.endswith("_Color.jpg") else None
    return sw.ext_res("Texture2D", path), (sw.ext_res("Texture2D", nrm) if nrm else None), st["avg"]


# palette_tex 키 -> 셰이더 파라미터 (값이 0이면 쓰지 않는다)
_WEAR = (("stain", "stain"), ("base_dirt", "base_dirt"), ("hand", "hand_dirt"), ("streaks", "streaks"), ("edge", "edge_wear"),
         ("edge_dirt", "edge_dirt"), ("rust", "rust"), ("wet", "wet"), ("ivar", "inst_var"), ("tvar", "tile_var"), ("damp", "damp"), ("paint_wear", "paint_wear"))


def _params(sw, rgb, kw, shape_round=False):
    p = {"albedo": _col(rgb), "roughness": "%.2f" % kw.get("roughness", 0.85),
         "metallic": "%.2f" % kw.get("metallic", 0.0), "grime": "%.3f" % kw.get("grime", 0.05)}
    if "band" in kw:
        p["band_color"] = _col(kw["band"])
        p["band_height"] = "%.2f" % kw["band_height"]
        p["band_absolute"] = "%.1f" % kw.get("band_absolute", 0)
        p["band_base"] = "%.2f" % kw.get("band_base", 0.0)
    if "tile_size" in kw:
        p["tile_size"] = "%.2f" % kw["tile_size"]
        p["tile_line_color"] = _col(kw.get("tile_line", (0.3, 0.3, 0.3)))
    if "wall_tile_size" in kw:
        p["wall_tile_size"] = "%.2f" % kw["wall_tile_size"]
    if kw.get("cut", 1) == 0:
        p["cutaway_affected"] = "0.0"
    if "cut_scale" in kw:
        p["cutaway_scale"] = "%.2f" % kw["cut_scale"]
    if "cut_min" in kw:
        p["cutaway_min_height"] = "%.2f" % kw["cut_min"]
    if "cut_fade" in kw:
        p["cutaway_wedge_fade"] = "%.2f" % kw["cut_fade"]
    if "emission" in kw:
        p["emission_energy"] = "%.2f" % kw["emission"]
    if "tex" in kw:
        name, scale = kw["tex"]
        t, n, avg = _tex(sw, name)
        p["surf_tex"] = t
        p["surf_avg"] = _vec3(avg)
        p["surf_scale"] = "%.3f" % scale
        p["surf_mix"] = "%.2f" % kw.get("tmix", 1.0)
        p["surf_chroma"] = "%.2f" % kw.get("chroma", 0.4)
        if n and kw.get("nrm", 0) > 0:
            p["surf_nrm"] = n
            p["surf_nrm_strength"] = "%.2f" % kw["nrm"]
        if kw.get("obj"):
            p["object_space"] = "1.0"
        if kw.get("anti"):
            p["anti_tile"] = "1.0"
    if "band_tex" in kw:
        name, scale = kw["band_tex"]
        t, _n, avg = _tex(sw, name)
        p["band_tex"], p["band_avg"], p["band_scale"] = t, _vec3(avg), "%.3f" % scale
    if "over" in kw:
        name, scale, amount = kw["over"]
        t, _n, avg = _tex(sw, name)
        p["over_tex"], p["over_avg"], p["over_scale"], p["over_mix"] = t, _vec3(avg), "%.3f" % scale, "%.2f" % amount
    p["noise_tex"] = sw.ext_res("Texture2D", NOISE)
    # 누수 자국 텍스처는 모든 재질에 준다 (이계 부식도가 올리면 어디서나 번진다)
    p["leak_tex"] = sw.ext_res("Texture2D", LEAK)
    if kw.get("leak", 0) > 0:
        p["leak"] = "%.2f" % kw["leak"]
    for src, dst in _WEAR:
        if kw.get(src):
            p[dst] = "%.3f" % kw[src]
    if "stain_col" in kw:
        p["stain_color"] = _col(kw["stain_col"])
    if "wear" in kw:
        p["wear_color"] = _col(kw["wear"])
    if shape_round:
        p["shape_round"] = "1.0"
    return p


class _Mats(dict):
    """재질 표. 키 + "@round"를 처음 찾으면 원통·원뿔용 변형(박스 모서리 계산 없음, 월드 좌표 투영)을 만든다."""

    def __init__(self, sw, shader, table):
        super().__init__()
        self.sw, self.shader, self.table = sw, shader, table

    def __missing__(self, key):
        base, _sep, kind = key.partition("@")
        if kind != "round":
            raise KeyError(key)
        if base in GLASS:
            return self[base]
        rgb, kw = self.table[base]
        value = self.sw.shader_material(key, self.shader, _params(self.sw, rgb, kw, shape_round=True))
        self[key] = value
        return value


def make(sw, extra=None):
    """SceneWriter에 재질을 만들어 {키: SubResource 참조}를 돌려준다."""
    shader = sw.ext_res("Shader", SHADER)
    table = dict(S)
    if extra:
        table.update(extra)
    out = _Mats(sw, shader, table)
    for key, (rgb, kw) in table.items():
        out[key] = sw.shader_material(key, shader, _params(sw, rgb, kw))
    for key, c in GLASS.items():
        out[key] = sw.sub_res(("mat", key), "StandardMaterial3D", {
            "transparency": "1", "albedo_color": _col(c[:3], c[3]), "roughness": "0.08", "metallic": "0.3"})
    return out
