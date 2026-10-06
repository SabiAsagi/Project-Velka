# -*- coding: utf-8 -*-
"""강당 특수 구조 (레퍼런스 10·11): 무대 좌우 계단, 준비실 안쪽 계단참, 1층->2층 되돌이 계단,
2층 U자 관람석(앞쪽 통로 3.8m / 좌석 단 / 뒤쪽 통로 5.0m / 계단 통로), 양 끝 비상구와 외부 비상계단.
좌표: u = 서->동 0~40, s = 남쪽 무대 0 -> 북쪽 주출입구 26 (월드 x = u-20, z = 55-s)."""
from geometry import Rect, subtract
from stairs2 import flight, flat_rail, stair_path
from plan import SLAB, GYM_Z0, GYM_Z1

FLOOR2 = 3.8
REAR = 5.0
STAGE_H = 1.1
WING_ROWS = [(1.2, 2.4, 4.7), (2.4, 3.6, 4.4), (3.6, 4.8, 4.1)]      # 날개 관람석 단 (u0, u1, 윗면): 서측 기준, 동측은 거울상
WING_AISLE = (15.2, 16.4)                                           # 날개 중간 횡단 계단 통로 (s)
NORTH_ROWS = [(19.4, 20.2, 4.2), (20.2, 21.0, 4.6)]                  # 북측 관람석 단 (s0, s1, 윗면): 난간에서 1.2m 뒤부터


def X(u):
    return u - 20.0


def Z(s):
    return GYM_Z1 - s


def UR(u0, s0, u1, s1):
    """(u,s) 사각형 -> 월드 Rect"""
    return Rect(X(u0), Z(s1), X(u1), Z(s0))


EXT_T = 0.25
INSIDE2 = Rect(-20.0 + EXT_T, GYM_Z0 + EXT_T, 20.0 - EXT_T, GYM_Z1 - 6.14 - 0.075)


def block(batch, path, rect, top, mat, bottom=FLOOR2 - SLAB, holes=(), groups=(), tag="gym_floor"):
    rect = rect.clip(INSIDE2)
    if rect.w <= 1e-3 or rect.d <= 1e-3:
        return
    for p in subtract(rect, list(holes)):
        batch.box(path, mat, (p.cx, (bottom + top) / 2, p.cz), (p.w, top - bottom, p.d), True, groups, tag)


def mirror(u0, u1):
    return 40.0 - u1, 40.0 - u0


def build_gym(sw, batch, plans):
    f1, f2 = plans[("gym", "1F")], plans[("gym", "2F")]
    p1 = f1.path + "/Stairs"
    p2 = f2.path + "/Stairs"
    # 무대 좌우 계단 (코트 0 -> 무대 1.1, 북->남으로 오른다)
    for (u0, u1) in ((4.745, 7.67), (32.33, 35.255)):
        flight(batch, p1, "z", Z(6.14), Z(3.2), 0.0, STAGE_H, X(u0), X(u1), "floor_stage")
        cx = (X(u0) + X(u1)) / 2
        stair_path(sw, p1, [(cx, 0.0, Z(6.14) + 0.6), (cx, STAGE_H, Z(3.2) - 0.4)], name="StageStairPath")
    # 준비실·음향실 안쪽: 무대 옆문(1.1m)으로 오르는 계단과 참
    for side in (-1, 1):
        lu0, lu1 = (3.5, 4.595) if side < 0 else mirror(3.5, 4.595)
        land = UR(lu0, 0.25, lu1, 2.0)
        batch.box(p1, "stair", (land.cx, STAGE_H / 2, land.cz), (land.w, STAGE_H, land.d), True, (), "stage_landing")
        flight(batch, p1, "z", Z(4.6), Z(2.0), 0.0, STAGE_H, X(lu0) + 0.1, X(lu1), "stair")
        flat_rail(batch, p1, "z", Z(2.0), Z(0.25), X(lu0 if side < 0 else lu1), STAGE_H)
    # 1층 -> 2층 뒤쪽 통로(5.0) 되돌이 계단: 출입홀 쪽에서 오른다
    holes2 = []
    for side in (-1, 1):
        ua, ub = (9.405, 14.0) if side < 0 else (40.0 - 9.405, 40.0 - 14.0)   # ua 먼 쪽 벽, ub 홀 쪽
        s_court, s_toilet = 21.275, 23.625
        s_mid = (s_court + s_toilet) / 2
        land_u = ua + (1.2 if side < 0 else -1.2)
        flight(batch, p1, "x", X(ub), X(land_u), 0.0, REAR / 2, Z(s_mid) + 0.06, Z(s_court), "stair", (), ("w0",),
               rail_trim=(0.0, 1.0))
        lr = Rect(min(X(ua), X(land_u)), Z(s_toilet), max(X(ua), X(land_u)), Z(s_court))
        batch.box(p1, "stair", (lr.cx, REAR / 2 - 0.1, lr.cz), (lr.w, 0.2, lr.d), True, (), "landing")
        flight(batch, p1, "x", X(land_u), X(ub), REAR / 2, REAR, Z(s_toilet), Z(s_mid) - 0.06, "stair", (), ("w1",),
               rail_trim=(1.0, 0.0))
        u_lo, u_hi = sorted((X(land_u), X(ub)))
        u_lo, u_hi = u_lo + 0.01, u_hi - 0.01
        batch.box(p1, "wall_concrete", ((u_lo + u_hi) / 2, 1.2, (Z(s_toilet) + Z(s_mid) - 0.06) / 2),
                  (u_hi - u_lo, 2.4, Z(s_mid) - 0.06 - Z(s_toilet)), True, (), "under_stair")
        hole = Rect(min(X(ua), X(ub)), Z(s_toilet), max(X(ua), X(ub)), Z(s_court))
        holes2.append(hole)
        a_c = (Z(s_mid) + Z(s_court)) / 2
        a_t = (Z(s_toilet) + Z(s_mid)) / 2
        d = 1 if side < 0 else -1
        stair_path(sw, p1, [(X(ub) + 0.6 * d, 0.0, a_c), ((X(land_u) + X(ua)) / 2, REAR / 2, a_c),
                            ((X(land_u) + X(ua)) / 2, REAR / 2, a_t), (X(ub) + 0.9 * d, REAR, a_t)], name="GymInnerStairPath")
        # 2층 구멍 둘레 난간 (2단이 도착하는 홀 쪽 절반은 열어 둔다)
        flat_rail(batch, p2, "x", hole.x0, hole.x1, hole.z1 + 0.04, REAR)
        flat_rail(batch, p2, "x", hole.x0, hole.x1, hole.z0 - 0.04, REAR)
        far_x = hole.x0 - 0.04 if side < 0 else hole.x1 + 0.04
        flat_rail(batch, p2, "z", hole.z0, hole.z1, far_x, REAR)
        near_x = X(ub) + 0.04 * d
        flat_rail(batch, p2, "z", Z(s_mid), hole.z1, near_x, REAR)
    build_balcony(sw, batch, f2, holes2)
    build_emergency_stairs(sw, batch, f2)


def build_balcony(sw, batch, f2, holes):
    """2층 U자 관람석: 앞쪽 통로(3.8) - 좌석 단 - 뒤쪽 통로(5.0), 계단 통로로 잇는다"""
    P = f2.path + "/Arch"
    S = f2.path + "/Stairs"
    wing_rows = WING_ROWS
    aisle = WING_AISLE
    for side in (-1, 1):
        def U(u0, u1):
            return (u0, u1) if side < 0 else mirror(u0, u1)
        for (u0, u1), (s0, s1), top in ((U(0.0, 1.2), (6.14, 26.0), REAR), (U(1.2, 3.0), (6.14, 9.2), REAR),
                                          (U(1.2, 8.0), (21.0, 26.0), REAR), (U(4.8, 8.0), (9.2, 21.0), FLOOR2),
                                          (U(3.0, 8.0), (6.14, 9.2), FLOOR2)):
            block(batch, P, UR(u0, s0, u1, s1), top, "floor_concrete", holes=holes)
        for u0, u1, top in wing_rows:
            a, b = U(u0, u1)
            for s0, s1 in ((9.2, aisle[0]), (aisle[1], 21.0)):
                block(batch, P, UR(a, s0, b, s1), top, "seat_tier", holes=holes, tag="seat_tier")
        lo_u, hi_u = (4.8, 1.2) if side < 0 else (40.0 - 4.8, 40.0 - 1.2)
        flight(batch, S, "x", X(lo_u), X(hi_u), FLOOR2, REAR, Z(aisle[1]), Z(aisle[0]), "stair")
        d = 1 if side < 0 else -1
        zc = (Z(aisle[0]) + Z(aisle[1])) / 2
        stair_path(sw, S, [(X(lo_u) + 0.8 * d, FLOOR2, zc), (X(hi_u) - 0.5 * d, REAR, zc)], name="BalconyAislePath")
    # 북측 관람석: 앞쪽 통로, 좌석 3단(가운데 계단 통로), 방송 부스 띠(5.0)
    block(batch, P, UR(8.0, 18.2, 32.0, NORTH_ROWS[0][0]), FLOOR2, "floor_concrete", holes=holes)
    for s0, s1, top in NORTH_ROWS:
        for u0, u1 in ((8.0, 19.3), (20.7, 32.0)):
            block(batch, P, UR(u0, s0, u1, s1), top, "seat_tier", holes=holes, tag="seat_tier")
    block(batch, P, UR(8.0, 21.0, 32.0, 26.0), REAR, "floor_concrete", holes=holes)
    flight(batch, S, "z", Z(NORTH_ROWS[0][0]), Z(21.0), FLOOR2, REAR, X(19.3), X(20.7), "stair")
    stair_path(sw, S, [(0.0, FLOOR2, Z(NORTH_ROWS[0][0]) + 0.4), (0.0, REAR, Z(21.0) - 0.5)], name="BalconyAislePath")


def build_emergency_stairs(sw, batch, f2):
    """비상구(뒤쪽 통로 5.0, 서·동 외벽) -> 바깥 참 -> 벽을 따라 남쪽(무대 쪽)으로 내려가는 외부 철제 비상계단.
    측면 출입문(z = 41) 앞을 가로막지 않도록 북쪽이 아니라 남쪽으로 내린다.
    건물 밖 계단이므로 층 노드가 아닌 Exterior에 둔다 (강당 뒤에 서서 2층이 숨겨져도 계단은 보여야 한다)."""
    P = "Buildings/gym/Exterior"
    sw.node("Exterior", "Node3D", "Buildings/gym", {}, unique=False)
    for side in (-1, 1):
        wall_x = X(0.0) if side < 0 else X(40.0)
        out = -1 if side < 0 else 1
        x_in, x_out = sorted((wall_x, wall_x + out * 1.6))
        plat = Rect(x_in, Z(9.0), x_out, Z(7.0))
        batch.box(P, "metal_grate", (plat.cx, REAR - 0.1, plat.cz), (plat.w, 0.2, plat.d), True, (), "ext_stair")
        sx0, sx1 = sorted((wall_x + out * 0.35, wall_x + out * 1.55))
        flight(batch, P, "z", Z(0.0), Z(7.0), 0.0, REAR, sx0, sx1, "metal_grate", (), ("w0",) if side < 0 else ("w1",))
        outer_x = x_out - 0.03 if side > 0 else x_in + 0.03
        flat_rail(batch, P, "x", plat.x0 + (0.08 if side < 0 else 0.0), plat.x1 - (0.08 if side > 0 else 0.0), plat.z0 + 0.03, REAR)
        flat_rail(batch, P, "z", plat.z0, plat.z1, outer_x, REAR)
        # 참과 계단을 받치는 철제 기둥 (바깥쪽)
        post_x = x_out - 0.08 if side > 0 else x_in + 0.08
        for z in (plat.z0 + 0.1, plat.z1 - 0.1):
            batch.box(P, "rail_metal", (post_x, (REAR - 0.2 + 0.03) / 2, z), (0.12, REAR - 0.23, 0.12), True, (), "ext_stair_post")
        for t in (0.33, 0.66):
            z = plat.z1 + (Z(0.0) - plat.z1) * t
            h = REAR * (1.0 - t) - 0.35
            batch.box(P, "rail_metal", (post_x, (h + 0.03) / 2, z), (0.1, h - 0.03, 0.1), True, (), "ext_stair_post")
        cx = (sx0 + sx1) / 2
        stair_path(sw, P, [(cx, 0.0, Z(0.0) + 0.8), (cx, REAR, Z(7.0) - 0.5), (wall_x + out * 0.8, REAR, Z(7.8))],
                   name="EmergencyStairPath")
