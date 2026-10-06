# -*- coding: utf-8 -*-
"""본관 2층 서쪽 끝 <-> 별관 3층 북쪽 끝 구름다리 (바닥 7.6m).
본관 복도에서 서쪽으로 나가 별관 복도 폭 위치에서 남쪽으로 꺾인다. 양옆 창, 지붕, 아래 기둥."""
from geometry import Rect
from arch import emit_layer, emit_collision, emit_window
from emit import tf, q

H = 2.9          # 벽 높이
T_OUT, T_IN = 0.12, 0.08
PLATEAU = Rect(-56.5, -74.0, 53.5, -33.0)


def build_skybridge(sw, batch, plans, zone_cb, light_cb=None):
    m2, a3 = plans[("main", "2F")], plans[("annex", "3F")]
    mc, ac = m2.corridor(), a3.corridor()
    y = m2.y
    zc0, zc1 = mc.z0, mc.z1            # 본관 복도 z 범위
    xa0, xa1 = ac.x0, ac.x1            # 별관 복도 x 범위
    east = m2.footprint.x0             # 본관 서쪽 외벽 바깥면 (-30)
    south = a3.footprint.z0            # 별관 북쪽 외벽 바깥면 (-27.5)
    P = m2.path + "/Skybridge"
    sw.node("Skybridge", "Node3D", m2.path, {}, unique=False)
    T = T_OUT + T_IN
    # 바닥 (벽 아래까지) + 두 건물 외벽 개구부의 문턱
    floors = [Rect(xa0, zc0, xa1, south), Rect(xa1, zc0, east, zc1)]
    for r in floors:
        batch.box(P, "floor_bridge", (r.cx, y - 0.15, r.cz), (r.w, 0.3, r.d), True, (), "bridge_floor")
    hm = next((d.hole for d in m2.doors if d.name == "BridgeFireDoor"), (zc0, zc1))
    ha = next((d.hole for d in a3.doors if d.name == "BridgeFireDoor"), (xa0, xa1))
    # 방화문 아래는 외장이 바닥 높이까지 올라와 있으므로 충돌만 채운다
    batch.solid(P, (east + 0.075, y - 0.1, (hm[0] + hm[1]) / 2), (0.15, 0.2, hm[1] - hm[0]), (), "threshold")
    batch.solid(P, ((ha[0] + ha[1]) / 2, y - 0.1, south + 0.075), (ha[1] - ha[0], 0.2, 0.15), (), "threshold")
    # 벽 (바깥 외장 + 안쪽 복도 마감), 양옆 연속 창
    walls = [("x", zc0, -1, xa0 - T, east), ("x", zc1, +1, xa1 + T, east),
             ("z", xa0, -1, zc0, south), ("z", xa1, +1, zc1, south)]
    for axis, line, out, a0, a1 in walls:
        outer = (line + out * T_IN, line + out * T)
        inner = (line, line + out * T_IN)
        o_lo, o_hi = sorted(outer)
        i_lo, i_hi = sorted(inner)
        wins = []
        L = a1 - a0
        n = max(1, int((L - 0.6) // 2.3))
        for i in range(n):
            c = a0 + L * (i + 0.5) / n
            wins.append((c - 0.95, c + 0.95, y + 0.9, y + 2.3))
        cut = [w for w in wins]
        emit_layer(batch, P, "facade_main", axis, o_lo, o_hi, a0, a1, y - 0.3, y + H, cut, (), "bridge_wall")
        emit_layer(batch, P, "wall_corridor", axis, i_lo, i_hi, a0, a1, y - 0.3, y + H, cut, (), "bridge_wall")
        emit_collision(batch, P, axis, min(o_lo, i_lo), max(o_hi, i_hi), a0, a1, y, y + H, [])
        for w0, w1, wy0, wy1 in wins:
            emit_window(batch, P, axis, min(o_lo, i_lo), max(o_hi, i_hi), w0, w1, wy0, wy1, "glass", 0)
    # 지붕
    roofs = [Rect(xa0 - T - 0.1, zc0 - T - 0.1, xa1 + T + 0.1, south), Rect(xa1 + T + 0.1, zc0 - T - 0.1, east, zc1 + T + 0.1)]
    for r in roofs:
        batch.box(P, "coping", (r.cx, y + H + 0.1, r.cz), (r.w, 0.2, r.d), False, (), "bridge_roof")
    # 기둥 (고지대 위는 3.8에서, 그 밖은 지면에서)
    for px in range(int(east) - 6, int(xa1) - 1, -8):
        base = (3.8 if PLATEAU.contains_point(px, (zc0 + zc1) / 2) else 0.0) - 0.05      # 바닥 구획과 밑면이 겹치지 않게 살짝 묻는다
        batch.box(P, "pillar_dark", (px, (base + y - 0.3) / 2, (zc0 + zc1) / 2), (0.5, y - 0.3 - base, 0.5), True, (), "pillar")
    for pz in range(int(zc1) + 6, int(south) - 2, 7):
        base = (3.8 if PLATEAU.contains_point((xa0 + xa1) / 2, pz) else 0.0) - 0.05
        batch.box(P, "pillar_dark", ((xa0 + xa1) / 2, (base + y - 0.3) / 2, pz), (0.5, y - 0.3 - base, 0.5), True, (), "pillar")
    # 양 끝 안내판
    for pos, rot, text in (((east - 0.3, y + 2.35, zc0 + 0.02), None, "본관 2층 ▶"), (((xa0 + xa1) / 2, y + 2.35, south - 0.3), None, "별관 3층 ▼")):
        sw.node("Sign", "Label3D", P, {"transform": tf(pos), "text": q(text), "font_size": "44", "pixel_size": "0.004",
                                       "modulate": "Color(0.15, 0.2, 0.25, 1)", "billboard": "0"})
    zone_cb("skybridge", "본관-별관 구름다리", Rect(xa1, zc0, east, zc1), y, 3.0, "", -1, "끝이 없는 구름다리")
    zone_cb("skybridge_s", "본관-별관 구름다리", Rect(xa0, zc0, xa1, south), y, 3.0, "", -1, "끝이 없는 구름다리")
    for r in (Rect(xa0, zc0, xa1, south), Rect(xa1, zc0, east, zc1)):
        L = max(r.w, r.d)
        n = max(2, int(L // 8))
        for i in range(n):
            t = (i + 0.5) / n
            p = (r.x0 + r.w * t, y + 2.6, r.cz) if r.w >= r.d else (r.cx, y + 2.6, r.z0 + r.d * t)
            sw.node("Light", "OmniLight3D", P, {"transform": tf(p), "light_color": "Color(1, 0.96, 0.9, 1)", "light_energy": "0.6",
                                                "omni_range": "6.0"}, ["real_light"])
