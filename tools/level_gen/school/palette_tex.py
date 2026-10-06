# -*- coding: utf-8 -*-
"""재질별 텍스처·사용감 설정 (palette.S에 덧붙인다).

텍스처: assets/third_party/ambientcg (CC0 사진 텍스처, 색 + 노멀), screaming_brain_studios (CC0 128px 공포 텍스처).
셰이더가 텍스처를 평균색으로 나눠 무늬만 얹으므로, 팔레트 색은 그대로 표면의 평균색이다.

키:
  tex=(이름, 한 장이 덮는 길이 m)  chroma 색 차이 반영(0~1)  tmix 무늬 세기  nrm 노멀 세기
  obj 박스 자기 좌표(가구)  anti 넓은 지면 반복 흐리기  band_tex=(이름, m)  over=(이름, m, 세기)
  사용감: stain stain_col base_dirt hand streaks leak edge(+벗겨짐/-손때) wear(벗겨진 색) edge_dirt rust wet ivar tvar
"""

WALL_PAINT = dict(tex=("PaintedPlaster017", 2.2), chroma=0.3, tmix=0.85, nrm=0.45, over=("Horror_Wall_02", 0.8, 0.22),
                  edge=0.35, wear=(0.8, 0.79, 0.75))
CONCRETE_WALL = dict(tex=("Concrete030", 3.0), chroma=0.2, tmix=0.55, nrm=0.4, over=("Horror_Wall_09", 1.2, 0.15),
                     edge=0.3, wear=(0.56, 0.56, 0.54))
B1_WALL = dict(tex=("Concrete032", 3.0), chroma=0.3, tmix=0.85, nrm=0.4, over=("Horror_Wall_09", 1.2, 0.2),
               band_tex=("Concrete035", 2.0), edge=0.3, wear=(0.56, 0.56, 0.54))
TERRAZZO = dict(tex=("Terrazzo005", 0.8), chroma=0.2, tmix=0.45, nrm=0.3, roughness=0.6)
VINYL = dict(tex=("Terrazzo019S", 1.2), chroma=0.2, tmix=0.55, nrm=0.2, tvar=0.04, edge_dirt=0.5, roughness=0.7)
GRASS = dict(tex=("Grass004", 2.5), chroma=0.7, tmix=1.0, nrm=0.4, anti=1)
SOIL = dict(tex=("Ground104", 2.0), chroma=0.5, tmix=1.0, nrm=0.6)
LEAVES = dict(tex=("Moss002", 1.4), chroma=0.6, tmix=1.0, nrm=0.8)
WOOD = dict(tex=("Wood049", 0.9), chroma=0.5, tmix=0.9, nrm=0.3, obj=1, edge=-0.4, ivar=0.05)
WOOD_OLD = dict(tex=("PaintedWood008C", 0.9), chroma=0.4, tmix=0.9, nrm=0.3, obj=1, edge=-0.3, ivar=0.05)
METAL_IN = dict(tex=("Plastic018B", 0.8), chroma=0.0, tmix=0.35, nrm=0.2, obj=1, edge=0.5, wear=(0.6, 0.6, 0.62), rust=0.05,
                ivar=0.04)
METAL_OUT = dict(tex=("PaintedMetal012", 0.8), chroma=0.1, tmix=0.35, nrm=0.2, obj=1, edge=0.5, wear=(0.55, 0.55, 0.56),
                 rust=0.3, ivar=0.04)
STEEL = dict(tex=("Metal016", 0.8), chroma=0.1, tmix=0.35, nrm=0.2, obj=1, ivar=0.03)
PLASTIC = dict(tex=("Plastic018B", 0.6), chroma=0.1, tmix=0.22, nrm=0.2, obj=1, edge=-0.25, ivar=0.04)
FABRIC = dict(tex=("Fabric036", 0.5), chroma=0.05, tmix=0.6, nrm=0.4, obj=1, ivar=0.04)
CARDBOARD = dict(tex=("Cardboard004", 0.6), chroma=0.2, tmix=0.7, nrm=0.3, obj=1, ivar=0.06)
SITE_CONCRETE = dict(tex=("Concrete030", 2.0), chroma=0.3, tmix=1.0, nrm=0.45)

GROUPS = []


def group(keys, cfg):
    GROUPS.append((keys, cfg))


def apply(S):
    """S: palette 재질 표 {키: (rgb, kw)}. 없는 키는 오류로 알린다 (오타 방지)."""
    missing = []
    for keys, cfg in GROUPS:
        for k in keys.split():
            if k not in S:
                missing.append(k)
                continue
            S[k][1].update(cfg)
    if missing:
        raise KeyError("palette_tex: 없는 재질 키 " + ", ".join(missing))


# ---- 실내 벽
group("wall_corridor", dict(WALL_PAINT, band_tex=("PaintedPlaster003", 1.6), base_dirt=0.45, hand=0.55, leak=0.2, stain=0.12))
group("wall_class", dict(WALL_PAINT, band_tex=("Wood049", 0.8), base_dirt=0.3, hand=0.35, leak=0.12, stain=0.08))
group("wall_office wall_nurse wall_lobby wall_library wall_gym wall_patch",
      dict(WALL_PAINT, base_dirt=0.25, hand=0.25, leak=0.1, stain=0.06))
group("wall_acoustic", dict(tex=("Horror_Wall_06", 0.9), chroma=0.2, tmix=0.6, base_dirt=0.2))
group("wall_tile wall_tile_light", dict(tex=("Tiles107", 1.0), chroma=0.1, tmix=0.8, nrm=0.5, wall_tile_size=0.0,
                                        band_tex=("Tiles107", 1.0), base_dirt=0.35, stain=0.12, roughness=0.35))
group("wall_cafeteria", dict(tex=("Tiles107", 1.2), chroma=0.1, tmix=0.8, nrm=0.5, wall_tile_size=0.0,
                             band_tex=("Tiles107", 1.2), base_dirt=0.3, roughness=0.4))
group("wall_concrete parapet_in", dict(CONCRETE_WALL, stain=0.3, base_dirt=0.4, streaks=0.2))
group("wall_b1", dict(B1_WALL, stain=0.45, leak=0.55, base_dirt=0.5, hand=0.2, damp=0.45))
group("wall_b1_flood", dict(B1_WALL, stain=0.6, leak=0.8, base_dirt=0.6, damp=1.0))
group("wall_stage", dict(tex=("Fabric036", 0.8), chroma=0.0, tmix=0.5))
# ---- 외벽
group("facade_main facade_annex facade_gym",
      dict(tex=("Concrete034", 3.0), chroma=0.25, tmix=0.9, nrm=0.4, band_tex=("Concrete030", 2.0),
           over=("Horror_Wall_06", 1.0, 0.12), streaks=0.55, stain=0.12, leak=0.35, base_dirt=0.35, edge=0.35,
           wear=(0.62, 0.6, 0.56)))
group("facade_b1", dict(tex=("Concrete032", 2.5), chroma=0.3, tmix=1.0, nrm=0.5, streaks=0.4, stain=0.3, base_dirt=0.4))
# ---- 바닥
group("floor_corridor", dict(TERRAZZO, tvar=0.025, edge_dirt=0.6, stain=0.1))
group("floor_lobby", dict(TERRAZZO, tvar=0.03, edge_dirt=0.5, stain=0.08))
group("stair", dict(TERRAZZO, edge=0.5, wear=(0.84, 0.82, 0.78), base_dirt=0.3))
group("floor_class", dict(tex=("WoodFloor065B", 1.8), chroma=0.6, tmix=1.0, nrm=0.5, tile_size=0.0, edge_dirt=0.55,
                          stain=0.08, roughness=0.7))
group("floor_wood", dict(tex=("WoodFloor064", 1.3), chroma=0.6, tmix=1.0, nrm=0.5, edge_dirt=0.5, roughness=0.6))
group("floor_gym", dict(tex=("WoodFloor061", 1.5), chroma=0.5, tmix=1.0, nrm=0.4, edge_dirt=0.4, roughness=0.45))
group("floor_stage", dict(tex=("WoodFloor064", 1.3), chroma=0.5, tmix=1.0, nrm=0.5, edge_dirt=0.3))
group("floor_b1_old", dict(tex=("WoodFloor065B", 1.8), chroma=0.5, tmix=1.0, nrm=0.6, stain=0.6, wet=0.45, edge_dirt=0.8))
group("floor_office floor_lab floor_nurse floor_cafeteria floor_bridge", dict(VINYL, stain=0.06))
group("floor_carpet", dict(tex=("Carpet001", 1.0), chroma=0.1, tmix=0.6, nrm=0.3, edge_dirt=0.4, tvar=0.03))
group("floor_toilet", dict(tex=("Tiles141", 1.2), chroma=0.2, tmix=0.9, nrm=0.5, tile_size=0.0, edge_dirt=0.6,
                           stain=0.3, wet=0.3))
group("floor_kitchen", dict(tex=("Tiles141", 1.8), chroma=0.2, tmix=0.9, nrm=0.5, tile_size=0.0, edge_dirt=0.6,
                            stain=0.3, wet=0.35, roughness=0.6))
group("floor_concrete", dict(tex=("Concrete032", 2.5), chroma=0.3, tmix=1.0, nrm=0.4, stain=0.3, edge_dirt=0.6))
group("floor_b1", dict(tex=("Concrete032", 2.5), chroma=0.3, tmix=1.0, nrm=0.5, stain=0.5, wet=0.25, edge_dirt=0.8))
group("floor_roof", dict(tex=("Horror_Floor_01", 1.0), chroma=0.4, tmix=0.8, stain=0.35, wet=0.2, edge_dirt=0.5))
group("roof_metal", dict(tex=("CorrugatedSteel003", 1.2), chroma=0.2, tmix=0.8, nrm=0.8, rust=0.3))
group("roof_path", dict(SITE_CONCRETE, stain=0.15))
# ---- 부지
group("site_stair", dict(SITE_CONCRETE, edge=0.4, wear=(0.72, 0.72, 0.7), stain=0.2))
group("seat_tier stand", dict(SITE_CONCRETE, tex=("Concrete030", 2.5), over=("Horror_Wall_09", 1.2, 0.2), stain=0.3,
                              streaks=0.35, edge=0.3, wear=(0.68, 0.68, 0.66)))
group("plateau", dict(SITE_CONCRETE, tex=("Concrete030", 3.0), stain=0.2))
group("coping sill_out planter", dict(SITE_CONCRETE, tex=("Concrete030", 1.5), streaks=0.2, stain=0.15))
group("stone_wall", dict(tex=("Bricks089", 2.0), chroma=0.25, tmix=1.0, nrm=0.9, wall_tile_size=0.0, stain=0.15,
                         streaks=0.3, base_dirt=0.3))
group("ground pad_Garden bank_grass", GRASS)
group("pad_Forest", dict(tex=("ScatteredLeaves009", 3.0), chroma=0.7, tmix=1.0, nrm=0.5, anti=1))
group("pad_AthleticField", dict(tex=("Ground102", 3.0), chroma=0.5, tmix=1.0, nrm=0.5, anti=1))
group("pad_Trail sand", dict(tex=("Ground091", 2.5), chroma=0.5, tmix=1.0, nrm=0.5, anti=1))
group("pad_Road pad_Parking", dict(tex=("Road015A", 3.5), chroma=0.25, tmix=1.0, nrm=0.5, anti=1, stain=0.15))
group("pad_Path pad_Plaza", dict(tex=("PavingStones099", 1.8), chroma=0.3, tmix=1.0, nrm=0.7, stain=0.1))
group("pad_Court", dict(SITE_CONCRETE, tex=("Concrete030", 3.0), chroma=0.1, tmix=0.7, nrm=0.3, stain=0.1))
group("pad_Fitness rubber_green rubber_blue rubber_mat mat_dark",
      dict(tex=("Rubber004", 1.0), chroma=0.15, tmix=0.9, nrm=0.4))
group("pad_Plot soil soil_bed earth_cut silt", SOIL)
# ---- 나무·풀
group("leaf_dark leaf_mid leaf_light slim_dark slim_mid slim_light shrub shrub_light crop", LEAVES)
group("trunk bark", dict(tex=("Bark014", 1.0), chroma=0.4, tmix=1.0, nrm=0.8))
# ---- 가구·소품
group("desk_top chair_seat shelf_wood lectern lectern_top table_top bench_wood cabinet_wood counter_wood frame_wood "
      "wood_dark table_low workbench easel instrument_wood riser stool_seat sign_board mailbox key_board carrel_panel "
      "booth_wall shoe_rack office_top", WOOD)
group("shelf_old card_catalog", WOOD_OLD)
group("shelf_wet", dict(WOOD_OLD, stain=0.4))
group("desk_frame chair_frame desk_shelf locker locker_blue locker_gray cabinet_metal cleaning_cabinet office_drawer "
      "drawer_cabinet shelf_metal mobile_shelf map_cabinet metal metal_dark safe panel_gray control_panel cart charge_box "
      "phone_box bed_frame drying_rack kick_plate hydrant_box hydrant_door boiler pump pump_red cable_tray office_panel "
      "medicine_cabinet ladder", METAL_IN)
group("fence rail fit_steel fit_yellow goal_white roof_guard lamp_post tank pipe pipe_red hoop_rim", METAL_OUT)
group("canopy", dict(tex=("Metal016", 1.5), chroma=0.1, tmix=0.3, nrm=0.2, streaks=0.3, stain=0.15, edge=0.3,
                     wear=(0.6, 0.6, 0.62)))
group("steel steel_frame stainless stainless_dark frame_alu win_frame win_frame_new rail_metal", STEEL)
group("bin_gray bin_blue bin_yellow bin_green bucket_blue bucket_red caf_stool seat_plastic tray purifier aircon cctv "
      "speaker monitor monitor_old tv pc_tower keyboard copier fridge_small dehumidifier fan console terminal scanner "
      "shredder watering_can vending_red vending_blue gate_panel lost_box chair_office cone hose_reel toilet_partition "
      "stall_panel stall_door counter_white tarp_blue", PLASTIC)
group("whiteboard", dict(PLASTIC, tmix=0.25))
group("curtain curtain_heavy curtain_light curtain_stage cloth sofa sofa_blue sofa_green cushion bag apron bed pillow sack "
      "net_white gym_mat gym_mat_green pad_blue vest flag_kr flag_school banner_roll backdrop umbrella mop_head "
      "uniform_navy uniform_shirt uniform_check velvet", FABRIC)
group("sandbag", dict(FABRIC, tex=("Fabric036", 0.4), stain=0.3))
group("box file_box pegboard", CARDBOARD)
group("pallet", dict(tex=("Planks023A", 1.0), chroma=0.4, tmix=0.9, nrm=0.4, obj=1, ivar=0.06))
group("chalkboard chalkboard_erased", dict(tex=("Concrete034", 1.0), chroma=0.0, tmix=0.5, obj=1))
group("stone stone_dark", dict(tex=("Concrete035", 1.0), chroma=0.2, tmix=1.0, nrm=0.4, obj=1, ivar=0.06))
# ---- 도색 선·표시: 군데군데 벗겨진 칠
group("line_white line_yellow", dict(paint_wear=0.55))
group("court_line floor_mark_yellow floor_mark_white floor_mark_blue", dict(paint_wear=0.3))
group("metal_grate", dict(tex=("Horror_Floor_10", 0.6), chroma=0.3, tmix=0.8, rust=0.2, edge=0.4, wear=(0.6, 0.6, 0.62)))
group("cork", dict(tex=("Ground091", 0.4), chroma=0.3, tmix=0.8, obj=1))
