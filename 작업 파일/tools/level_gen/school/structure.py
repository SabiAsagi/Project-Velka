# -*- coding: utf-8 -*-
"""건물 구조: 문 구멍이 난 벽, 문/출입구, 창문, 조명, 구역"""
from geometry import Rect, rect_of_box, split_span
from classify import classify, base_y, level_index, display_name
from emit import tf, vec3, q

DOOR_H = 2.4
ROT_DOOR_Z = (0, 0, 1, 0, 1, 0, -1, 0, 0)   # 로컬 +x -> 월드 -z
# 기본으로 잠겨 있는 방 (관계자 외 출입금지)
LOCKED_ROOMS = ("보일러실", "전기실", "소방펌프실", "교장실", "경비실", "매점 창고", "강당 관리실", "음향·조명·무대장치실")


def wall_axis(box):
    """벽이 뻗은 축: 'x'(z 고정) 또는 'z'(x 고정)"""
    return "x" if box.size[0] >= box.size[2] else "z"


def opening_for(marker):
    """문 표식 -> (중심 x, 중심 z, 폭, 방향 축)"""
    sx, sz = marker.size[0], marker.size[2]
    width = 1.2 if classify(marker) == "door" else max(sx, sz)
    return marker.center[0], marker.center[2], width


def match_openings(walls, markers):
    """표식마다 가장 가까운 벽을 찾아 {wall_id: [(a0, a1, marker)]}"""
    result = {}
    for m in markers:
        mx, mz, width = opening_for(m)
        best, best_d = None, 0.7
        for w in walls:
            if w.building != m.building or abs(base_y(w) - base_y(m)) > 0.1:
                continue
            mn, mxv = w.min, w.max
            if wall_axis(w) == "x":
                if not (mn[0] - 0.2 <= mx <= mxv[0] + 0.2):
                    continue
                d = abs(mz - w.center[2])
            else:
                if not (mn[2] - 0.2 <= mz <= mxv[2] + 0.2):
                    continue
                d = abs(mx - w.center[0])
            if d < best_d:
                best, best_d = w, d
        a = mx if best is None or wall_axis(best) == "x" else mz
        if best is None:
            result.setdefault(None, []).append((a - width / 2, a + width / 2, m))
        else:
            result.setdefault(id(best), []).append((a - width / 2, a + width / 2, m))
    return result


def emit_wall(sw, parent, w, gaps, mat, groups=None):
    """벽을 문 구멍 기준으로 나눠 출력. 구멍 위는 상인방."""
    mn, mx = w.min, w.max
    y0, y1 = mn[1], mx[1]
    along = wall_axis(w)
    a0, a1 = (mn[0], mx[0]) if along == "x" else (mn[2], mx[2])
    thick = w.size[2] if along == "x" else w.size[0]
    fixed = w.center[2] if along == "x" else w.center[0]

    def piece(b0, b1, lo, hi):
        mid = (b0 + b1) / 2
        if along == "x":
            sw.solid(parent, "Wall", (mid, (lo + hi) / 2, fixed), (b1 - b0, hi - lo, thick), mat, groups=groups)
        else:
            sw.solid(parent, "Wall", (fixed, (lo + hi) / 2, mid), (thick, hi - lo, b1 - b0), mat, groups=groups)

    for b0, b1 in split_span(a0, a1, [(g0, g1) for g0, g1, _ in gaps]):
        piece(b0, b1, y0, y1)
    for g0, g1, _ in gaps:
        g0, g1 = max(g0, a0), min(g1, a1)
        if g1 > g0 and y1 - (y0 + DOOR_H) > 0.05:
            piece(g0, g1, y0 + DOOR_H, y1)


def emit_door(sw, parent, door_scene, m, g0, g1, along, fixed, floor_y, room_name=""):
    width = g1 - g0
    props = {"door_width": "%.3f" % width}
    if along == "x":
        props["transform"] = tf((g0, floor_y, fixed))
    else:
        props["transform"] = tf((fixed, floor_y, g1), ROT_DOOR_Z)
    if any(k in room_name for k in LOCKED_ROOMS):
        props["is_locked"] = "true"
        props["locked_prompt"] = q("잠긴 문 (%s)" % room_name)
        props["locked_line"] = q("'관계자 외 출입금지' 표지가 붙어 있다. 잠겨 있다.")
    sw.node("Door", None, parent, props, instance=door_scene)


def window_items(w, gaps, inward_sign):
    """외벽 안팎으로 보이는 창 패널 목록 (멀티메시용)"""
    mn, mx = w.min, w.max
    along = wall_axis(w)
    a0, a1 = (mn[0], mx[0]) if along == "x" else (mn[2], mx[2])
    fixed = w.center[2] if along == "x" else w.center[0]
    thick = (w.size[2] if along == "x" else w.size[0]) + 0.06
    y = mn[1] + 1.75
    items = []
    for s0, s1 in split_span(a0 + 0.8, a1 - 0.8, [(g0 - 0.6, g1 + 0.6) for g0, g1, _ in gaps]):
        n = int((s1 - s0) // 3.0)
        for i in range(n):
            c = s0 + (s1 - s0) * (i + 0.5) / n
            if along == "x":
                items.append(((c, y, fixed), (2.0, 1.25, thick), 0))
            else:
                items.append(((fixed, y, c), (thick, 1.25, 2.0), 0))
    return items


def emit_zone(sw, parent, zone_script, box_rect, y0, height, zone_id, name, building, level_idx, other_name="", groups=()):
    props = {"transform": tf((box_rect.cx, y0 + height / 2, box_rect.cz)), "script": zone_script,
             "zone_id": q(zone_id), "zone_name": q(name), "building": q(building), "level_index": str(level_idx)}
    if other_name:
        props["otherworld_zone_name"] = q(other_name)
    n = sw.node("Zone", "Area3D", parent, props, groups=list(groups) or None)
    sw.node("Shape", "CollisionShape3D", parent + "/" + n,
            {"shape": sw.box_shape((max(box_rect.w - 0.2, 0.3), height, max(box_rect.d - 0.2, 0.3)))}, unique=False)


def emit_light(sw, parent, center, rng, group="real_light", color=(1.0, 0.96, 0.9), energy=0.9):
    sw.node("Light", "OmniLight3D", parent, {
        "transform": tf(center), "light_color": "Color(%.2f, %.2f, %.2f, 1)" % color,
        "light_energy": "%.2f" % energy, "omni_range": "%.2f" % rng}, [group])


def room_lights(sw, parent, rect, y0, group="real_light"):
    """큰 방은 여러 개, 작은 방은 하나"""
    nx = max(1, int(rect.w // 9) + (1 if rect.w % 9 > 4 else 0))
    nz = max(1, int(rect.d // 9) + (1 if rect.d % 9 > 4 else 0))
    rng = max(4.0, min(10.0, max(rect.w / nx, rect.d / nz) * 0.9))
    for i in range(nx):
        for j in range(nz):
            emit_light(sw, parent, (rect.x0 + rect.w * (i + 0.5) / nx, y0 + 3.0, rect.z0 + rect.d * (j + 0.5) / nz), rng, group)
