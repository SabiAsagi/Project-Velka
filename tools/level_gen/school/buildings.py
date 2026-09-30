# -*- coding: utf-8 -*-
"""건물 조립: 층별 벽·문·바닥·방·계단·엘리베이터·창문·조명·구역"""
from collections import defaultdict
from geometry import Rect, rect_of_box, subtract
from classify import classify, level_index, base_y, display_name, KO_BUILDING
from source import BUILDINGS, load_buildings, FLOOR_H
from structure import (wall_axis, match_openings, emit_wall, emit_door, window_items, emit_zone, room_lights)
from stairs import StairWell, corridor_side, ramp, slab, wall_seg, stair_path
from furniture import Frame, furnish
from emit import tf, q

FOOTPRINTS = {"main": Rect(-30.0, -63.25, 30.0, -44.75), "annex": Rect(-68.75, -27.5, -51.25, 24.5), "gym": Rect(-20.0, 29.0, 20.0, 55.0)}
LAYER_START = {"main": 2, "annex": 8, "gym": 11}
FLOOR_MAT = {"main": "floor_main", "annex": "floor_annex", "gym": "floor_gym"}


class Level:
    def __init__(self, building, name, index):
        self.building, self.name, self.index = building, name, index
        self.y = index * FLOOR_H
        self.boxes = []
        self.extra_gaps = []      # (wall_name, a0, a1, kind) 수동 구멍
        self.holes = []           # 슬래브 구멍 Rect
        self.path = ""

    def by(self, cat):
        return [b for b in self.boxes if classify(b) == cat]

    def corridor(self):
        c = self.by("corridor")
        return rect_of_box(c[0]) if c else None


def collect_levels():
    levels = {}
    for b in load_buildings():
        key = (b.building, b.level)
        if key not in levels:
            levels[key] = Level(b.building, b.level, level_index(b))
        levels[key].boxes.append(b)
    return levels


def room_frame(rect, level, y0):
    cor = level.corridor()
    if cor is None:
        return Frame(rect, "z", 1, y0)
    axis, sign = corridor_side(rect, cor)
    return Frame(rect, axis, sign, y0)


def emit_furniture(sw, parent, name, frame, mats):
    items = furnish(name, frame)
    if not items:
        return
    solids = [(c, s) for (layer, _), lst in items.items() if layer == "solid" for c, s, _ in lst]
    if solids:
        body = sw.node("FurnitureBody", "StaticBody3D", parent, {})
        for c, s in solids:
            sw.node("Shape", "CollisionShape3D", parent + "/" + body, {"transform": tf(c), "shape": sw.box_shape(s)})
    for (layer, mat), lst in items.items():
        groups = {"real": ["real_only"], "other": ["otherworld_only"]}.get(layer)
        sw.multimesh(parent, "Furniture_" + mat, mats["f_" + mat], lst, groups=groups)


def build_stairs(sw, levels, mats):
    """계단실 이름별로 층을 이어 붙이고, 위층 슬래브 구멍을 기록한다."""
    for bname in ("main", "annex"):
        chain = sorted([lv for (b, _), lv in levels.items() if b == bname], key=lambda l: l.index)
        names = {z.name for lv in chain for z in lv.by("stair_zone")}
        for sname in names:
            present = [lv for lv in chain if any(z.name == sname for z in lv.by("stair_zone"))]
            for i, lv in enumerate(present):
                nxt = [l for l in chain if l.index == lv.index + 1]
                if not nxt:
                    continue
                nxt = nxt[0]
                goes_up = any(z.name == sname for z in nxt.by("stair_zone")) or (sname == "중앙 계단" and nxt.by("roof_room"))
                if not goes_up:
                    continue
                zone = [z for z in lv.by("stair_zone") if z.name == sname][0]
                rect = rect_of_box(zone)
                axis, sign = corridor_side(rect, lv.corridor())
                well = StairWell(rect, axis, sign)
                is_bottom = lv.index == present[0].index
                well.build_segment(sw, lv.path + "/Stairs", lv.y, mats["stair"], mats["wall"], bottom=is_bottom, top=False)
                nxt.holes.append(well.hole())
                nxt_up = [l for l in chain if l.index == nxt.index + 1]
                continues = bool(nxt_up) and (any(z.name == sname for z in nxt_up[0].by("stair_zone")) or (sname == "중앙 계단" and nxt_up[0].by("roof_room")))
                if not continues:
                    # 계단이 끝나는 층: 올라가는 쪽 절반에 난간
                    a_mid0 = well.mid - 0.075
                    wall_seg(sw, nxt.path + "/Stairs", well.a_axis, well.a0, a_mid0, well.strip_edge, nxt.y, nxt.y + 1.1, mats["wall"], name="TopRail")


def build_walls_and_doors(sw, lv, mats, res):
    walls = lv.by("wall") + lv.by("wall_out")
    markers = lv.by("door") + lv.by("entrance")
    openings = match_openings(walls, markers)
    windows = []
    for w in walls:
        gaps = list(openings.get(id(w), []))
        for wname, a0, a1, kind in lv.extra_gaps:
            if w.name == wname:
                gaps.append((a0, a1, kind))
        open_gaps = [(g0, g1) for g0, g1, m in gaps if isinstance(m, str)]
        door_gaps = [(g0, g1, m) for g0, g1, m in gaps if not isinstance(m, str)
                     and not any(o0 <= (g0 + g1) / 2 <= o1 for o0, o1 in open_gaps)]
        gaps = [(g0, g1, m) for g0, g1, m in gaps if isinstance(m, str) or (g0, g1, m) in door_gaps]
        is_out = classify(w) == "wall_out"
        emit_wall(sw, lv.path + "/Walls", w, gaps, mats["wall_out" if is_out else "wall"])
        along = wall_axis(w)
        fixed = w.center[2] if along == "x" else w.center[0]
        for g0, g1, m in door_gaps:
            if "엘리베이터" in m.name:
                continue
            emit_door(sw, lv.path + "/Doors", res["door"], m, g0, g1, along, fixed, lv.y, _room_for_marker(lv, m))
        if is_out and w.size[1] >= 3.0 and not (lv.building == "main" and lv.index == 0):
            windows += window_items(w, gaps, 1)
    for g0, g1, m in openings.get(None, []):
        # 이미 벽 사이가 비어 있는 출입구 (강당 북측 주출입구 등). 벽 없는 실내 문 표식은 무시한다.
        if classify(m) != "entrance":
            continue
        along = "x" if m.size[0] >= m.size[2] else "z"
        fixed = m.center[2] if along == "x" else m.center[0]
        a = m.center[0] if along == "x" else m.center[2]
        w = max(m.size[0], m.size[2])
        emit_door(sw, lv.path + "/Doors", res["door"], m, a - w / 2, a + w / 2, along, fixed, lv.y)
    sw.multimesh(lv.path, "Windows", mats["window"], windows, groups=["window_pane"])


def _room_for_marker(lv, m):
    best, best_d = "", 99.0
    for r in lv.by("room"):
        rr = rect_of_box(r)
        d = abs(rr.cx - m.center[0]) + abs(rr.cz - m.center[2])
        if rr.contains_point(m.center[0], m.center[2], 1.0) and d < best_d:
            best, best_d = r.name, d
    return best


def build_floor(sw, lv, mats):
    for s in lv.by("slab"):
        r = rect_of_box(s)
        for piece in subtract(r, lv.holes):
            sw.solid(lv.path + "/Floor", "Slab", (piece.cx, s.center[1], piece.cz), (piece.w, s.size[1], piece.d), mats[FLOOR_MAT[lv.building]])


ROOM_PAD = [("화장실", "pad_tile"), ("교실", "pad_class"), ("도서관", "pad_class"), ("마룻바닥", "pad_gym"), ("옥상정원", "pad_garden"),
            ("로비", "pad_lobby"), ("급식실", "pad_tile"), ("조리실", "pad_tile"), ("세척실", "pad_tile")]


def emit_elevator_button(sw, lv, rect, script):
    """엘리베이터 구역의 복도쪽 벽 앞 중앙에 호출 버튼"""
    cor = lv.corridor()
    if cor is None:
        return
    from stairs import corridor_side
    axis, sign = corridor_side(rect, cor)
    if axis == "z":
        edge = rect.z1 if sign > 0 else rect.z0
        pos = (rect.cx, lv.y, edge + 0.45 * sign)
    else:
        edge = rect.x1 if sign > 0 else rect.x0
        pos = (edge + 0.45 * sign, lv.y, rect.cz)
    n = sw.node("Elevator", "Node3D", lv.path + "/Doors", {"transform": tf(pos), "script": script,
                                                          "elevator_id": q(lv.building), "floor_label": q(lv.name)})
    sw.node("InteractionPoint", "Marker3D", lv.path + "/Doors/" + n, {"transform": tf((0, 1.1, 0))}, unique=False)


res_ref = {}


def build_rooms(sw, lv, mats, zone_cb):
    for r in lv.by("room"):
        rect = rect_of_box(r)
        pad = next((m for key, m in ROOM_PAD if key in r.name), "pad_room")
        sw.pad(lv.path + "/Rooms", "Pad", (rect.cx, lv.y + 0.012, rect.cz), (rect.w - 0.1, 0.02, rect.d - 0.1), mats[pad])
        frame = room_frame(rect, lv, lv.y)
        emit_furniture(sw, lv.path + "/Rooms", r.name, frame, mats)
        room_lights(sw, lv.path + "/Lights", rect, lv.y)
        zone_cb("%s_%s_%s" % (lv.building, lv.name, r.name), display_name(r), rect, lv.y, 3.0, lv.building, lv.index)
    for z in lv.by("elevator_zone"):
        emit_elevator_button(sw, lv, rect_of_box(z), res_ref["elevator"])
    for z in lv.by("stair_zone") + lv.by("elevator_zone"):
        rect = rect_of_box(z)
        zone_cb("%s_%s_%s" % (lv.building, lv.name, z.name), display_name(z), rect, lv.y, 3.0, lv.building, lv.index)
    cor = lv.corridor()
    if cor:
        sw.pad(lv.path + "/Rooms", "CorridorPad", (cor.cx, lv.y + 0.012, cor.cz), (cor.w, 0.02, cor.d), mats["pad_corridor"])
        long_len = max(cor.w, cor.d)
        n = max(2, int(long_len // 8))
        for i in range(n):
            t = (i + 0.5) / n
            if cor.w >= cor.d:
                c = (cor.x0 + cor.w * t, lv.y + 3.0, cor.cz)
            else:
                c = (cor.cx, lv.y + 3.0, cor.z0 + cor.d * t)
            from structure import emit_light
            emit_light(sw, lv.path + "/Lights", c, 6.5)
        ends = [(cor.x0 + 1.5, cor.cz), (cor.x1 - 1.5, cor.cz)] if cor.w >= cor.d else [(cor.cx, cor.z0 + 1.5), (cor.cx, cor.z1 - 1.5)]
        from structure import emit_light
        for x, z in ends:
            emit_light(sw, lv.path + "/Lights", (x, lv.y + 2.6, z), 7.0, group="otherworld_light", color=(0.85, 0.12, 0.1), energy=1.6)
        zone_cb("%s_%s_corridor" % (lv.building, lv.name), "%s %s 복도" % (KO_BUILDING[lv.building], lv.name), cor, lv.y, 3.0, lv.building, lv.index,
                "뒤틀린 %s %s 복도" % (KO_BUILDING[lv.building], lv.name))


def build_gym_specials(sw, levels, mats):
    f1, f2 = levels[("gym", "1F")], levels[("gym", "2F")]
    stage = f1.by("stage")[0]
    sw.solid(f1.path + "/Rooms", "Stage", stage.center, stage.size, mats["f_wood_dark"])
    sr = rect_of_box(stage)
    for step in f1.by("stage_step"):
        r = rect_of_box(step)
        west = r.cx < sr.cx
        x_low, x_high = (r.x0, sr.x0) if west else (r.x1, sr.x1)
        ramp(sw, f1.path + "/Rooms", "x", r.z0, r.z1, x_low, 0.0, x_high, stage.size[1], mats["stair"], name="StageSteps")
    # 내부 계단: 로비쪽 끝(y=0)에서 올라가 바깥쪽 끝(y=3.8)에서 2층 날개 바닥에 도착한다.
    # (바깥쪽 끝은 칸막이 벽에 붙어 있어 거기서 오르기 시작할 수 없다)
    uppers = f2.by("gym_upper_stair")
    for z in f1.by("stair_zone"):
        zr = rect_of_box(z)
        up = min(uppers, key=lambda u: abs(u.center[0] - zr.cx))
        ur = rect_of_box(up)
        high = zr.x0 if zr.cx < 0 else zr.x1
        low = ur.x1 if zr.cx < 0 else ur.x0
        ramp(sw, f1.path + "/Stairs", "x", zr.z0, zr.z1, low, 0.0, high, FLOOR_H, mats["stair"], name="InnerStair")
        d = 1.0 if high > low else -1.0
        stair_path(sw, f1.path + "/Stairs", [(low - d * 1.0, 0.0, zr.cz), (high + d * 0.9, FLOOR_H, zr.cz)], name="GymInnerStairPath")
        lo, hi = sorted((low, high))
        f2.holes.append(Rect(lo, zr.z0, hi, zr.z1))
        # 높은 쪽 아래로 걸어 들어가지 못하게 막는다
        cut = low + (high - low) * 0.42
        b0, b1 = sorted((cut, high))
        sw.solid(f1.path + "/Stairs", "UnderStair", ((b0 + b1) / 2, 0.75, zr.cz), (b1 - b0, 1.5, zr.d - 0.1), mats["wall"])
        for zz in (zr.z0 - 0.08, zr.z1 + 0.08):
            wall_seg(sw, f2.path + "/Stairs", "x", lo, hi, zz, FLOOR_H, FLOOR_H + 1.1, mats["wall"], name="StairRail")
    # 외부 비상계단: 2층 비상구 바깥 참(y=3.8)에서 부지(y=0)까지
    for es in f2.by("emergency_stair"):
        r = rect_of_box(es)
        exit_z = [e.center[2] for e in f2.by("entrance") if "Emergency" in e.name and (e.center[0] < 0) == (r.cx < 0)][0]
        wall_x = 20.0 if r.cx > 0 else -20.0
        outer_x = r.x1 if r.cx > 0 else r.x0
        top_z = exit_z - 1.0
        plat = Rect(min(wall_x, outer_x), top_z - 0.2, max(wall_x, outer_x), exit_z + 1.0)
        slab(sw, f2.path + "/Stairs", plat, FLOOR_H, mats["stair"], name="EmergencyPlatform")
        ramp(sw, f2.path + "/Stairs", "z", r.x0, r.x1, top_z - 0.2, FLOOR_H, r.z0, 0.0, mats["stair"], name="EmergencyStair")
        stair_path(sw, f2.path + "/Stairs", [(r.cx, 0.0, r.z0 - 0.8), (r.cx, FLOOR_H, top_z + 0.3)], name="EmergencyStairPath")
        for xx in (r.x0 - 0.08, r.x1 + 0.08):
            if abs(xx - wall_x) > 0.3:
                sw.solid(f2.path + "/Stairs", "EmergencyRail", (xx, FLOOR_H / 2 + 0.55, (r.z0 + top_z) / 2), (0.1, FLOOR_H + 1.1, abs(top_z - r.z0)), mats["rail"], collision=True)
        sw.solid(f2.path + "/Stairs", "EmergencyRail", ((plat.x0 + plat.x1) / 2, FLOOR_H + 0.55, plat.z1), (plat.w, 1.1, 0.1), mats["rail"])
    for s in f2.by("seating"):
        sw.solid(f2.path + "/Rooms", "Seats", (s.center[0], FLOOR_H + s.size[1] / 2, s.center[2]), s.size, mats["f_bench"], collision=False)


def build_roof_room(sw, levels, mats, res):
    roof = levels[("main", "Roof")]
    room = roof.by("roof_room")[0]
    stair = [z for z in levels[("main", "4F")].by("stair_zone") if z.name == "중앙 계단"][0]
    rr, sr = rect_of_box(room), rect_of_box(stair)
    u = Rect(min(rr.x0, sr.x0), min(rr.z0, sr.z0), max(rr.x1, sr.x1), max(rr.z1, sr.z1))
    y0, h = roof.y, 3.0
    door_w, door_x = 2.35, 0.163
    for (a0, a1) in ((u.x0, door_x - door_w / 2), (door_x + door_w / 2, u.x1)):
        sw.solid(roof.path + "/Walls", "RoofRoomWall", ((a0 + a1) / 2, y0 + h / 2, u.z1), (a1 - a0, h, 0.2), mats["wall_out"])
    sw.solid(roof.path + "/Walls", "RoofRoomLintel", (door_x, y0 + (2.4 + h) / 2, u.z1), (door_w, h - 2.4, 0.2), mats["wall_out"])
    sw.solid(roof.path + "/Walls", "RoofRoomWall", (u.x0, y0 + h / 2, u.cz), (0.2, h, u.d), mats["wall_out"])
    sw.solid(roof.path + "/Walls", "RoofRoomWall", (u.x1, y0 + h / 2, u.cz), (0.2, h, u.d), mats["wall_out"])
    sw.solid(roof.path + "/Walls", "RoofRoomTop", (u.cx, y0 + h + 0.1, u.cz), (u.w, 0.2, u.d), mats["wall_out"], collision=False)
    sw.node("RoofDoor", None, roof.path + "/Doors", {
        "transform": tf((door_x - door_w / 2, y0, u.z1)), "door_width": "%.3f" % door_w, "is_locked": "true",
        "locked_prompt": q("잠긴 옥상 출입문"), "locked_line": q("옥상 출입문은 평소처럼 잠겨 있다.")}, instance=res["door"])
    for r in roof.by("path"):
        sw.pad(roof.path + "/Rooms", "RoofPath", (r.center[0], roof.y + 0.02, r.center[2]), (r.size[0], 0.03, r.size[2]), mats["pad_corridor"])


def build_skybridge(sw, levels, mats, zone_cb):
    m2, a3 = levels[("main", "2F")], levels[("annex", "3F")]
    mc, ac = m2.corridor(), a3.corridor()
    y = m2.y
    z0, z1 = mc.z0, mc.z1                  # 본관 2층 복도 폭
    x0, x1 = ac.x0, ac.x1                  # 별관 3층 복도 폭
    north_z = FOOTPRINTS["annex"].z0       # 별관 북쪽 외벽
    west_end = FOOTPRINTS["main"].x0
    m2.extra_gaps.append(("WestWall", z0, z1, "open"))
    a3.extra_gaps.append(("RightImageWall", x0, x1, "open"))
    P = m2.path + "/Skybridge"
    sw.node("Skybridge", "Node3D", m2.path, {}, unique=False)
    slab(sw, P, Rect(x0, z0, west_end, z1), y, mats["floor_main"], name="BridgeFloor")
    slab(sw, P, Rect(x0, z1, x1, north_z), y, mats["floor_main"], name="BridgeFloor")
    h = 2.8
    walls = [("x", x0 - 0.1, west_end, z0 - 0.1), ("x", x1, west_end, z1 + 0.1),
             ("z", z0 - 0.1, north_z, x0 - 0.1), ("z", z1, north_z, x1 + 0.1)]
    windows = []
    for axis, a0, a1, fixed in walls:
        wall_seg(sw, P, axis, a0, a1, fixed, y, y + h, mats["wall_out"], name="BridgeWall", thick=0.2)
        n = max(1, int((a1 - a0) // 3.0))
        for i in range(n):
            c = a0 + (a1 - a0) * (i + 0.5) / n
            windows.append((((c, y + 1.6, fixed) if axis == "x" else (fixed, y + 1.6, c)), ((2.0, 1.2, 0.26) if axis == "x" else (0.26, 1.2, 2.0)), 0))
    sw.multimesh(P, "BridgeWindows", mats["window"], windows, groups=["window_pane"])
    for px in range(int(west_end) - 4, int(x0), -8):
        base = 3.8 if px > -56.5 else 0.0
        sw.solid(P, "Pillar", (px, (base + y - 0.2) / 2, (z0 + z1) / 2), (0.6, y - 0.2 - base, 0.6), mats["stand"])
    for pz in range(int(z1) + 6, int(north_z), 8):
        sw.solid(P, "Pillar", ((x0 + x1) / 2, (y - 0.2) / 2, pz), (0.6, y - 0.2, 0.6), mats["stand"])
    zone_cb("skybridge", "본관-별관 구름다리", Rect(x0, z0, west_end, z1), y, 3.0, "", -1, "끝이 없는 구름다리")
    zone_cb("skybridge_s", "본관-별관 구름다리", Rect(x0, z1, x1, north_z), y, 3.0, "", -1, "끝이 없는 구름다리")


def build_anomaly_classroom(sw, levels, mats, zone_cb):
    """본관 3층 동쪽 끝: 현실은 막힌 벽, 이계에서는 4~6m 늘어난 뒤 남쪽으로 꺾여 존재하지 않는 교실로 이어진다."""
    m3 = levels[("main", "3F")]
    c = m3.corridor()
    y = m3.y
    east = FOOTPRINTS["main"].x1
    m3.extra_gaps.append(("EastWall", c.z0, c.z1, "anomaly"))
    sw.solid(m3.path + "/Walls", "SealedEastEnd", (east - 0.125, y + 1.9, c.cz), (0.25, 3.8, c.d), mats["wall_out"], groups=["real_only"])
    P = m3.path + "/NonexistentClassroom"
    sw.node("NonexistentClassroom", "Node3D", m3.path, {}, groups=["otherworld_only"], unique=False)
    ext_end = east + 5.0
    room = Rect(east + 0.5, c.z1 + 4.5, east + 8.6, c.z1 + 15.0)
    slab(sw, P, Rect(east, c.z0, ext_end, c.z1), y, mats["floor_main"], name="ExtensionFloor")
    slab(sw, P, Rect(ext_end - 3.0, c.z1, ext_end, room.z0), y, mats["floor_main"], name="ExtensionFloor")
    slab(sw, P, room, y, mats["floor_main"], name="RoomFloor")
    h = 3.4
    wall_seg(sw, P, "x", east, ext_end, c.z0 - 0.1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "x", east, ext_end - 3.0, c.z1 + 0.1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "z", c.z0, room.z0, ext_end + 0.1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "z", c.z1, room.z0, ext_end - 3.1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "x", room.x0, ext_end - 3.0, room.z0, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "x", ext_end, room.x1, room.z0, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "x", room.x0, room.x1, room.z1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "z", room.z0, room.z1, room.x0, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    wall_seg(sw, P, "z", room.z0, room.z1, room.x1, y, y + h, mats["wall_out"], name="Wall", thick=0.2)
    emit_furniture(sw, P, "존재하지 않는 교실", Frame(room, "z", -1, y), mats)
    sw.node("BoardNames", "Label3D", P, {"transform": tf((room.x0 + 0.15, y + 1.6, room.cz), (0, 0, 1, 0, 1, 0, -1, 0, 0)),
                                          "text": q("0-0 교실\n출석 확인 중"), "font_size": "56", "pixel_size": "0.004",
                                          "modulate": "Color(0.85, 0.1, 0.1, 1)"}, unique=False)
    from structure import emit_light
    emit_light(sw, P, (room.cx, y + 2.8, room.cz), 9.0, group="otherworld_light", color=(0.7, 0.1, 0.12), energy=1.4)
    zone_cb("main_3F_nonexistent", "존재하지 않는 교실", room, y, 3.0, "main", 3, "존재하지 않는 교실")


def build_buildings(sw, root, mats, res, zone_cb):
    levels = collect_levels()
    sw.node("Buildings", "Node3D", root, {}, unique=False)
    for bname, b in BUILDINGS.items():
        fp = FOOTPRINTS[bname]
        bpath = "Buildings/" + bname
        sw.node(bname, "Node3D", "Buildings", {
            "metadata/building": q(bname),
            "metadata/footprint": "Rect2(%.3f, %.3f, %.3f, %.3f)" % (fp.x0, fp.z0, fp.w, fp.d),
            "metadata/base_y": "0.0"}, groups=["school_building"], unique=False)
        for idx, (lname, _) in enumerate(b["levels"]):
            lv = levels[(bname, lname)]
            lv.path = bpath + "/" + lname
            sw.node(lname, "Node3D", bpath, {
                "metadata/building": q(bname), "metadata/level_index": str(idx),
                "metadata/cull_layer": str(LAYER_START[bname] + idx)}, groups=["school_level"], unique=False)
            for child in ("Walls", "Doors", "Floor", "Rooms", "Stairs", "Lights"):
                sw.node(child, "Node3D", lv.path, {}, unique=False)
    res_ref.update(res)
    lobby = [r for r in levels[("main", "1F")].by("room") if "로비" in r.name][0]
    lr = rect_of_box(lobby)
    levels[("main", "1F")].extra_gaps.append(("South", lr.x0 + 0.4, lr.x1 - 0.4, "open"))
    build_skybridge(sw, levels, mats, zone_cb)
    build_anomaly_classroom(sw, levels, mats, zone_cb)
    build_stairs(sw, levels, mats)
    build_gym_specials(sw, levels, mats)
    build_roof_room(sw, levels, mats, res)
    for key in sorted(levels, key=lambda k: (k[0], levels[k].index)):
        lv = levels[key]
        build_walls_and_doors(sw, lv, mats, res)
        build_floor(sw, lv, mats)
        build_rooms(sw, lv, mats, zone_cb)
    return levels
