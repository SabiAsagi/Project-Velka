# -*- coding: utf-8 -*-
"""프로젝트 벨카 - 챕터 1 학교 전체 맵 생성기

실행: python tools/level_gen/school/school_world_gen.py
입력: scenes/school/ 의 레퍼런스 정렬 블록아웃(층별 씬, 외부 씬)
출력: scenes/school/SchoolWorld.tscn (플레이 가능한 학교 전체), scenes/chapters/Chapter1_School.tscn (챕터 1 씬)
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from emit import SceneWriter, tf, q
from geometry import Rect, rect_of_box
from structure import emit_zone
from site_builder import build_site, PAD_COLORS
from buildings import build_buildings, room_frame
from furniture import MATERIALS
from source import ROOT

INSPECT_DATA = "res://data/inspectables/school.json"
SPAWN = (70.0, 0.05, -10.0)


def make_materials(sw):
    m = {}
    base = {
        "ground": (0.24, 0.26, 0.22), "plateau": (0.46, 0.46, 0.44), "stair": (0.55, 0.55, 0.57), "rail": (0.42, 0.44, 0.47),
        "stand": (0.52, 0.5, 0.47), "metal": (0.35, 0.37, 0.4), "fence": (0.3, 0.33, 0.3),
        "wall": (0.72, 0.73, 0.72), "wall_out": (0.6, 0.6, 0.58),
        "floor_main": (0.5, 0.48, 0.44), "floor_annex": (0.48, 0.47, 0.45), "floor_gym": (0.55, 0.42, 0.28),
        "pad_tile": (0.62, 0.68, 0.72), "pad_class": (0.6, 0.47, 0.33), "pad_gym": (0.66, 0.5, 0.3), "pad_garden": (0.3, 0.45, 0.28),
        "pad_lobby": (0.56, 0.55, 0.52), "pad_room": (0.54, 0.52, 0.48), "pad_corridor": (0.42, 0.44, 0.47),
    }
    for k, c in base.items():
        m[k] = sw.material(k, c)
    for k, c in PAD_COLORS.items():
        m["pad_" + k] = sw.material("pad_" + k, c)
    for k, c in MATERIALS.items():
        m["f_" + k] = sw.material("f_" + k, c)
    m["window"] = sw.material("window", (0.62, 0.8, 0.95), emission=(0.62, 0.8, 0.95), energy=0.7)
    return m


def place_inspect(sw, parent, res, name, pos, inspect_id, point, marker=1.0):
    n = sw.node(name, "Node3D", parent, {"transform": tf(pos), "script": res["inspect"], "marker_height": "%.2f" % marker,
                                         "inspect_id": q(inspect_id), "data_path": q(INSPECT_DATA)})
    sw.node("InteractionPoint", "Marker3D", parent + "/" + n, {"transform": tf(point)}, unique=False)


def room_rect(levels, building, level, name):
    lv = levels[(building, level)]
    r = [b for b in lv.by("room") if b.name == name][0]
    return lv, rect_of_box(r)


def rel(a, b):
    return (b[0] - a[0], b[1] - a[1], b[2] - a[2])


def build_inspectables(sw, levels, res):
    P = "Inspectables"
    sw.node(P, "Node3D", ".", {}, unique=False)
    lv, r = room_rect(levels, "main", "2F", "1-1 교실")
    f = room_frame(r, lv, lv.y)
    D, W = f.D, f.W
    specs = [("Blackboard", "classroom_blackboard", (0.15, D / 2, 0.0), (1.25, D / 2, 1.1), 1.5),
             ("AttendanceBook", "classroom_attendance", (1.3, D / 2, 0.95), (2.05, D / 2, 0.95), 0.6),
             ("Window", "classroom_window", (W / 2, 0.2, 0.0), (W / 2, 1.1, 1.1), 1.4),
             ("Locker", "classroom_locker", (W - 0.3, D / 2 - 1.0, 0.0), (W - 1.1, D / 2 - 1.0, 1.0), 1.3)]
    for name, iid, at, point, mk in specs:
        c, _ = f.world(at[0], at[1], at[2], 0.1, 0.1, 0.1)
        pc, _ = f.world(point[0], point[1], point[2], 0.1, 0.1, 0.1)
        place_inspect(sw, P, res, name, c, iid, rel(c, pc), mk)
    lv, r = room_rect(levels, "main", "1F", "보건실")
    f = room_frame(r, lv, lv.y)
    specs = [("NurseCabinet", "nurse_cabinet", (0.35, f.D * 0.4, 0.0), (1.25, f.D * 0.4, 1.1), 1.2),
             ("NurseBed", "nurse_bed", (f.W * 0.35, 1.3, 0.0), (f.W * 0.35, 2.6, 0.6), 0.8)]
    for name, iid, at, point, mk in specs:
        c, _ = f.world(at[0], at[1], at[2], 0.1, 0.1, 0.1)
        pc, _ = f.world(point[0], point[1], point[2], 0.1, 0.1, 0.1)
        place_inspect(sw, P, res, name, c, iid, rel(c, pc), mk)
    lv, r = room_rect(levels, "main", "2F", "청소도구함")
    place_inspect(sw, P, res, "Closet", (r.cx, lv.y, r.cz), "closet", (0.0, 1.0, r.d / 2 - 0.8), 1.2)
    for level, x in (("2F", 10.0), ("1F", -10.0)):
        lv = levels[("main", level)]
        cor = lv.corridor()
        place_inspect(sw, P, res, "Notice" + level, (x, lv.y, cor.z0 + 0.1), "corridor_notice_" + level.lower(), (0.0, 1.1, 0.8), 1.3)
    gym = levels[("gym", "1F")]
    sr = rect_of_box(gym.by("stage")[0])
    place_inspect(sw, P, res, "Stage", (sr.cx, 0.0, sr.z0 - 0.2), "gym_stage", (0.0, 1.0, -0.8), 1.6)


def main():
    sw = SceneWriter()
    res = {
        "controller": sw.ext_res("Script", "res://scripts/world/WorldPhaseController.gd"),
        "zone": sw.ext_res("Script", "res://scripts/world/ZoneArea.gd"),
        "ambient": sw.ext_res("Script", "res://scripts/world/AmbientSynth.gd"),
        "door": sw.ext_res("PackedScene", "res://scenes/interactables/DoorInteractable.tscn"),
        "inspect": sw.ext_res("Script", "res://scripts/interactables/InspectInteractable.gd"),
        "elevator": sw.ext_res("Script", "res://scripts/interactables/ElevatorInteractable.gd"),
    }
    mats = make_materials(sw)
    env_real = sw.sub_res("env_real", "Environment", {
        "background_mode": "1", "background_color": "Color(0.56, 0.68, 0.8, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.8, 0.82, 0.86, 1)", "ambient_light_energy": "0.6"})
    env_other = sw.sub_res("env_other", "Environment", {
        "background_mode": "1", "background_color": "Color(0, 0, 0, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.55, 0.36, 0.42, 1)", "ambient_light_energy": "0.7", "fog_enabled": "true",
        "fog_light_color": "Color(0.1, 0.03, 0.05, 1)", "fog_density": "0.018"})
    sw.node("SchoolWorld", "Node3D", None, {"script": res["controller"], "real_environment": env_real,
                                            "otherworld_environment": env_other, "world_environment": 'NodePath("WorldEnvironment")',
                                            "ambient": 'NodePath("Ambient")'}, node_paths=["world_environment", "ambient"])
    sw.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env_real}, unique=False)
    sun_tf = "Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 30, 0)"
    sw.node("Sun", "DirectionalLight3D", ".", {"transform": sun_tf, "light_energy": "0.95", "shadow_enabled": "true"},
            groups=["real_light"], unique=False)
    sw.node("Ambient", "AudioStreamPlayer", ".", {"script": res["ambient"]}, unique=False)
    sw.node("Zones", "Node3D", ".", {}, unique=False)

    def zone_cb(zone_id, name, rect, y0, height, building="", level=-1, other=""):
        emit_zone(sw, "Zones", res["zone"], rect, y0, height, zone_id, name, building, level, other)

    sw.node("Site", "Node3D", ".", {}, unique=False)
    build_site(sw, "Site", mats, zone_cb)
    levels = build_buildings(sw, ".", mats, res, zone_cb)
    build_inspectables(sw, levels, res)
    sw.node("Spawn", "Marker3D", ".", {"transform": tf(SPAWN)}, unique=False)
    path = os.path.join(ROOT, "scenes", "school", "SchoolWorld.tscn")
    text = sw.text()
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", path, "nodes=%d subs=%d bytes=%d" % (len(sw.nodes), len(sw.subs), len(text)))
    write_chapter()


def write_chapter():
    x, y, z = SPAWN
    lines = [
        "[gd_scene load_steps=7 format=3]", "",
        '[ext_resource type="Script" path="res://scripts/chapters/Chapter1School.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="res://scenes/school/SchoolWorld.tscn" id="2_school"]',
        '[ext_resource type="PackedScene" path="res://scenes/characters/PlayerParty.tscn" id="3_party"]',
        '[ext_resource type="PackedScene" path="res://scenes/cameras/FollowCamera.tscn" id="4_camera"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/PrototypeHUD.tscn" id="5_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/DialogueBox.tscn" id="6_dialogue"]', "",
        '[node name="Chapter1School" type="Node3D"]', 'script = ExtResource("1_script")', "",
        '[node name="SchoolWorld" parent="." node_paths=PackedStringArray("party", "camera") instance=ExtResource("2_school")]',
        'party = NodePath("../PlayerParty")', 'camera = NodePath("../FollowCamera")', "",
        '[node name="PlayerParty" parent="." node_paths=PackedStringArray("camera") instance=ExtResource("3_party")]',
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % (x, y, z), 'camera = NodePath("../FollowCamera")', "",
        '[node name="FollowCamera" parent="." node_paths=PackedStringArray("target") instance=ExtResource("4_camera")]',
        'target = NodePath("../PlayerParty/Sabi")', "",
        '[node name="PrototypeHUD" parent="." node_paths=PackedStringArray("party", "school_map") instance=ExtResource("5_hud")]',
        'party = NodePath("../PlayerParty")', 'school_map = NodePath("../SchoolWorld")', "",
        '[node name="DialogueBox" parent="." instance=ExtResource("6_dialogue")]', "",
    ]
    path = os.path.join(ROOT, "scenes", "chapters", "Chapter1_School.tscn")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", path)


if __name__ == "__main__":
    main()
