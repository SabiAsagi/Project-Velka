# -*- coding: utf-8 -*-
"""조사 대상·체크포인트·규칙 구역·조명·챕터 씬 (생성기 v2)"""
import os
from emit import tf, q
from geometry import Rect
from plan_build import inner_rect
from source import ROOT

INSPECT_DATA = "res://data/inspectables/school.json"
SPAWN = (70.0, 0.05, -10.0)


def place_inspect(sw, parent, res, name, pos, inspect_id, point, marker=1.0, groups=None):
    n = sw.node(name, "Node3D", parent, {"transform": tf(pos), "script": res["inspect"], "marker_height": "%.2f" % marker,
                                         "inspect_id": q(inspect_id), "data_path": q(INSPECT_DATA)}, groups=groups)
    sw.node("InteractionPoint", "Marker3D", parent + "/" + n, {"transform": tf(point)}, unique=False)


def room(plans, building, level, name):
    lv = plans[(building, level)]
    r = lv.by_name(name)[0]
    ir, _ = inner_rect(lv, r)
    return lv, ir


def build_inspectables(sw, plans, res):
    """조사 대상: 방 배치 함수가 남긴 기준점(room_ctx.ANCHORS)에 놓는다. 가구 위치가 바뀌면 조사 지점도 따라간다."""
    from room_ctx import ANCHORS
    P = "Inspectables"
    sw.node(P, "Node3D", ".", {}, unique=False)

    def put(name, anchor, inspect_id, marker, groups=None, height=1.1):
        (x, y, z), (dx, dz) = ANCHORS[anchor]
        place_inspect(sw, P, res, name, (x, y, z), inspect_id, (dx, height, dz), marker, groups=groups)

    c11 = "main/2F/1-1 교실/"
    put("Blackboard", c11 + "blackboard", "classroom_blackboard", 1.5)
    put("AttendanceBook", c11 + "attendance", "classroom_attendance", 0.6)
    put("Window", c11 + "window", "classroom_window", 1.4)
    put("Locker", c11 + "locker", "classroom_locker", 1.3)
    put("RedChalkName", c11 + "chalk_name", "red_chalk_name", 1.6, ["otherworld_only"])
    put("DroppedPencilCase", "main/3F/2-1 교실/pencilcase", "dropped_pencilcase", 0.6, ["otherworld_only"], 0.3)
    put("NurseCabinet", "main/1F/보건실/cabinet", "nurse_cabinet", 1.2)
    put("NurseBed", "main/1F/보건실/bed", "nurse_bed", 0.8, None, 0.6)
    put("Closet", "main/2F/청소도구함/closet", "closet", 1.2, None, 1.0)
    put("OldLibraryFlood", "main/B1/구 도서관/flood", "old_library_flood", 1.3)
    for level in ("2F", "1F"):
        put("Notice" + level, "main/%s/corridor/notice" % level, "corridor_notice_" + level.lower(), 1.3)
    from plan import GYM_Z1
    place_inspect(sw, P, res, "Stage", (0.0, 0.0, GYM_Z1 - 6.14 + 0.05), "gym_stage", (0.0, 1.0, -0.9), 1.6)



def area(sw, parent, name, script, center, size, props, groups=None):
    p = {"transform": tf(center), "script": script}
    p.update(props)
    n = sw.node(name, "Area3D", parent, p, groups=groups)
    sw.node("Shape", "CollisionShape3D", parent + "/" + n, {"shape": sw.box_shape(size)}, unique=False)
    return n


def build_survival(sw, plans, res):
    sw.node("Checkpoints", "Node3D", ".", {}, unique=False)
    cps = [("gate", "정문 진입광장", (SPAWN[0] - 2.0, 1.0, SPAWN[2]), (6.0, 3.0, 8.0), (0.0, -0.95, 0.0))]
    lv, lobby = room(plans, "main", "1F", "중앙 로비·정문 현관")
    cps.append(("main_lobby", "본관 중앙 로비", (lobby.cx, lv.y + 1.2, lobby.cz), (lobby.w - 1.0, 2.5, lobby.d - 2.0), (0.0, -1.15, 0.0)))
    lv, nurse = room(plans, "main", "1F", "보건실")
    cps.append(("nurse_office", "본관 1층 보건실", (nurse.cx, lv.y + 1.2, nurse.cz), (nurse.w - 1.0, 2.5, nurse.d - 1.0), (0.0, -1.15, -2.2)))
    for level in ("2F", "3F", "4F"):
        lv = plans[("main", level)]
        c = lv.corridor()
        cps.append(("main_%s_center" % level, "본관 %s 중앙 계단 앞" % level, (2.0, lv.y + 1.2, c.cz), (6.0, 2.5, c.d), (0.0, -1.15, 0.0)))
    c = plans[("annex", "1F")].corridor()
    cps.append(("annex_1f", "별관 1층 복도", (c.cx, 1.2, c.z1 - 6.0), (c.w, 2.5, 6.0), (0.0, -1.15, 0.0)))
    from plan import GYM_Z0
    cps.append(("gym_lobby", "강당 북측 주출입홀", (0.0, 1.2, GYM_Z0 + 2.5), (8.0, 2.5, 3.0), (0.0, -1.15, 0.0)))
    for cid, name, center, size, off in cps:
        area(sw, "Checkpoints", "Checkpoint_" + cid, res["checkpoint"], center, size,
             {"checkpoint_id": q(cid), "display_name": q(name), "respawn_offset": "Vector3(%.2f, %.2f, %.2f)" % off})
    sw.node("RuleZones", "Node3D", ".", {}, unique=False)
    for level in ("2F", "3F", "4F"):
        lv = plans[("main", level)]
        c = lv.corridor()
        for cond in ("no_running", "no_noise"):
            area(sw, "RuleZones", "Corridor%s_%s" % (level, cond), res["rulezone"], (c.cx, lv.y + 1.3, c.cz), (c.w - 12.0, 2.6, c.d),
                 {"rule_id": q("RULE_COMMON_01"), "condition": q(cond), "active_phase": q("otherworld")})


def _light(sw, parent, pos, rng, group="real_light", color=(1.0, 0.96, 0.9), energy=0.8, groups=()):
    sw.node("Light", "OmniLight3D", parent, {
        "transform": tf(pos), "light_color": "Color(%.2f, %.2f, %.2f, 1)" % color,
        "light_energy": "%.2f" % energy, "omni_range": "%.2f" % rng}, [group] + list(groups))


def emit_region_lights(sw, plan, region, container, groups=()):
    k = region.kind
    if k in ("void", "void_room", "stage_upper", "elevator", "seating", "stage_stair", "roof"):
        return
    r = region.rect
    y = plan.y + region.floor_dy
    if k == "corridor":
        long_x = r.w >= r.d
        L = r.w if long_x else r.d
        n = max(2, int(L // 7.5))
        for i in range(n):
            t = (i + 0.5) / n
            p = (r.x0 + r.w * t, y + 3.2, r.cz) if long_x else (r.cx, y + 3.2, r.z0 + r.d * t)
            _light(sw, container, p, 6.5, energy=0.75, groups=groups)
        ends = [(r.x0 + 1.5, r.cz), (r.x1 - 1.5, r.cz)] if long_x else [(r.cx, r.z0 + 1.5), (r.cx, r.z1 - 1.5)]
        for x, z in ends:
            _light(sw, container, (x, y + 2.6, z), 7.0, "otherworld_light", (0.85, 0.12, 0.1), 1.6, groups)
        return
    if k == "court":
        for i in range(3):
            for j in range(2):
                _light(sw, container, (r.x0 + r.w * (i + 0.5) / 3, y + 8.5, r.z0 + r.d * (j + 0.5) / 2), 13.0, energy=1.1, groups=groups)
        return
    nx = max(1, min(3, int(round(r.w / 5.5))))
    nz = max(1, min(3, int(round(r.d / 5.5))))
    rng = max(4.0, min(8.0, max(r.w / nx, r.d / nz) * 1.1))
    for i in range(nx):
        for j in range(nz):
            _light(sw, container, (r.x0 + r.w * (i + 0.5) / nx, y + 3.1, r.z0 + r.d * (j + 0.5) / nz), rng, groups=groups)


def write_chapter():
    x, y, z = SPAWN
    lines = [
        "[gd_scene load_steps=10 format=3]", "",
        '[ext_resource type="Script" path="res://scripts/chapters/Chapter1School.gd" id="1_script"]',
        '[ext_resource type="PackedScene" path="res://scenes/school/SchoolWorld.tscn" id="2_school"]',
        '[ext_resource type="PackedScene" path="res://scenes/characters/PlayerParty.tscn" id="3_party"]',
        '[ext_resource type="PackedScene" path="res://scenes/cameras/FollowCamera.tscn" id="4_camera"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/PrototypeHUD.tscn" id="5_hud"]',
        '[ext_resource type="PackedScene" path="res://scenes/ui/DialogueBox.tscn" id="6_dialogue"]',
        '[ext_resource type="Script" path="res://scripts/ui/RuleNotebook.gd" id="7_notebook"]',
        '[ext_resource type="Script" path="res://scripts/ui/FailureScreen.gd" id="8_failure"]',
        '[ext_resource type="Script" path="res://scripts/ui/VitalsOverlay.gd" id="9_overlay"]',
        "",
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
        '[node name="VitalsOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("party")]',
        'script = ExtResource("9_overlay")', 'party = NodePath("../PlayerParty")', "",
        '[node name="RuleNotebook" type="CanvasLayer" parent="."]', 'script = ExtResource("7_notebook")', "",
        '[node name="FailureScreen" type="CanvasLayer" parent="."]', 'script = ExtResource("8_failure")', "",
    ]
    path = os.path.join(ROOT, "scenes", "chapters", "Chapter1_School.tscn")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", path)
