# -*- coding: utf-8 -*-
"""부지 조경·시설 (학교_맵_상세.md 2-1~2-2, 2-6, 2-8 외부 보행로 + 가이드라인 12장 + 레퍼런스 00).
좌표는 월드 (x = 동, z = 남). 본관 앞뒤는 고지대(y = 3.8), 그 밖은 지면(y = 0).
화단·수목은 배경 조경, 벤치·운동기구·국기게양대·농구장·관람 스탠드는 접근할 수 있는 생활 시설이다."""
import math
from props_base import Props, bench, label
from batch import rows_y
from plan import MAIN_FRONT_Z

TOP = 3.8
PAD = 0.010         # 면 구획(잔디·코트 등) 윗면 높이 (그 바닥 기준)
PAVE = 0.022        # 포장 보행로·광장 윗면 높이


class WorldFrame:
    def __init__(self, y=0.0):
        self.y = y
        self.front = "world"

    def pt(self, u, v):
        return u, v

    def size(self, su, sv, sh):
        return (su, sh, sv)


def wp(batch, parent, y=0.0, seed=97):
    return Props(batch, parent, WorldFrame(y), seed=seed)


def tree(p, x, z, kind="mid", key=0, base=0.0, solid=True):
    """나무: 줄기 + 층층이 겹친 수관.
    kind: slim(건물 옆 좁은 상록수) / small / mid / old(수령 오래된 교목) / pine(원뿔꼴 침엽수)"""
    r = p.rand("tree", x, z, key)
    if kind == "slim":
        th, td, cd = 0.9 + 0.3 * r, 0.16, 1.15 + 0.2 * r
        p.cyl("bark", x, z, td, base, base + th + 0.3)
        p.cyl("slim_dark", x, z, cd, base + th, base + th + 1.0)
        p.cyl("slim_mid", x, z, cd * 0.74, base + th + 1.0, base + th + 1.9)
        p.cyl("slim_light", x, z, cd * 0.42, base + th + 1.9, base + th + 2.6)
        p.solid(x, z, 0.3, 0.3, base, base + 2.0)
        return
    if kind == "pine":
        th, d = 1.3 + 0.5 * r, 2.8 + 0.8 * r
        p.cyl("bark", x, z, 0.28, base, base + th + 0.8)
        p.cone("leaf_dark", x, z, d, base + th, base + th + 2.6)
        p.cone("leaf_dark", x, z, d * 0.8, base + th + 1.5, base + th + 3.9)
        p.cone("leaf_mid", x, z, d * 0.58, base + th + 2.9, base + th + 5.2)
        if solid:
            p.solid(x, z, 0.45, 0.45, base, base + 2.0)
        return
    if kind == "old":
        th, td, cd = 3.2 + 0.8 * r, 0.5, 4.4 + 0.8 * r
    elif kind == "small":
        th, td, cd = 1.4 + 0.4 * r, 0.2, 2.0 + 0.6 * r
    else:
        th, td, cd = 2.2 + 0.6 * r, 0.34, 3.4 + r
    p.cyl("bark", x, z, td, base, base + th + 0.4)
    p.cyl("leaf_dark", x, z, cd, base + th, base + th + cd * 0.34)
    p.cyl("leaf_mid", x + 0.2 * (r - 0.5), z + 0.2 * (0.5 - r), cd * 0.78, base + th + cd * 0.34, base + th + cd * 0.62)
    p.cyl("leaf_light", x, z, cd * 0.48, base + th + cd * 0.62, base + th + cd * 0.82)
    if solid:
        p.solid(x, z, td + 0.2, td + 0.2, base, base + 2.0)


def wild(p, key, k):
    """산자락 수목 종류: 소나무가 섞인 잡목림"""
    v = p.rand(key, k)
    return "pine" if v < 0.38 else ("old" if v > 0.74 else "mid")


def picket(p, x0, z0, x1, z1, h=0.75, mat="bench_wood", gap=None):
    """낮은 목책 (가로대 2줄 + 기둥). gap = (a0, a1): 길이 방향으로 그 구간은 비운다 (출입구)"""
    along_x = abs(x1 - x0) >= abs(z1 - z0)
    a0, a1 = (x0, x1) if along_x else (z0, z1)
    f = z0 if along_x else x0
    spans = [(a0, a1)] if gap is None else [(a0, gap[0]), (gap[1], a1)]
    for s0, s1 in spans:
        if s1 - s0 < 0.3:
            continue
        m, length = (s0 + s1) / 2, s1 - s0
        for hh in (h * 0.45, h * 0.88):
            if along_x:
                p.box(mat, m, f, length, 0.05, hh, hh + 0.07)
            else:
                p.box(mat, f, m, 0.05, length, hh, hh + 0.07)
        n = max(1, int(length / 1.5))
        for i in range(n + 1):
            t = s0 + length * i / n
            if along_x:
                p.box(mat, t, f, 0.09, 0.09, 0.0, h)
            else:
                p.box(mat, f, t, 0.09, 0.09, 0.0, h)
        if along_x:
            p.solid(m, f, length, 0.1, 0.0, h)
        else:
            p.solid(f, m, 0.1, length, 0.0, h)


def signpost(p, sw, parent, x, z, lines, face="south", h=2.3):
    """갈림길 방향 안내판: 기둥 + 방향판 여러 장 (글자는 카메라에서 읽히는 남·동쪽 면)"""
    p.cyl("lamp_post", x, z, 0.09, 0.0, h)
    p.solid(x, z, 0.2, 0.2, 0.0, 2.0)
    for i, text in enumerate(lines):
        y = h - 0.22 - 0.3 * i
        if face == "south":
            p.box("sign_blue", x + 0.55, z, 1.1, 0.04, y - 0.12, y + 0.12)
            wlabel(sw, parent, x + 0.55, p.f.y + y, z + 0.03, text, 0.003, 44)
        else:
            p.box("sign_blue", x, z - 0.55, 0.04, 1.1, y - 0.12, y + 0.12)
            wlabel(sw, parent, x + 0.03, p.f.y + y, z - 0.55, text, 0.003, 44, face="east")


def bins3(p, x, z, along_x=True):
    """분리수거함 3개"""
    for k, m in enumerate(("bin_blue", "bin_yellow", "bin_gray")):
        dx, dz = ((k - 1) * 0.42, 0.0) if along_x else (0.0, (k - 1) * 0.42)
        p.box(m, x + dx, z + dz, 0.36, 0.36, 0.0, 0.62)
    p.solid(x, z, 1.25 if along_x else 0.4, 0.4 if along_x else 1.25, 0.0, 0.62)



def planter(p, x0, z0, x1, z1, key, trees=(), kind="mid", shrubs=True, h=0.35, hedge=False):
    """낮은 경계석 화단: 흙 + 관목(hedge면 이어진 생울타리) + 나무 (충돌 한 덩어리)"""
    cx, cz, sx, sz = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    p.box("soil_bed", cx, cz, sx - 0.24, sz - 0.24, 0.0, h - 0.06)
    for dx, dz, a, b in ((0, -(sz / 2 - 0.06), sx, 0.12), (0, sz / 2 - 0.06, sx, 0.12),
                         (-(sx / 2 - 0.06), 0, 0.12, sz - 0.24), (sx / 2 - 0.06, 0, 0.12, sz - 0.24)):
        p.box("stone", cx + dx, cz + dz, a, b, 0.0, h)
    for tx, tz in trees:
        tree(p, tx, tz, kind, key)
    if hedge:
        p.box("shrub", cx, cz, sx - 0.4, sz - 0.4, h - 0.06, h + 0.42)
    elif shrubs:
        long_x = sx >= sz
        n = max(1, int((sx if long_x else sz) / 1.4))
        for i in range(n):
            t = (i + 0.5) / n
            sxp, szp = (x0 + sx * t, cz) if long_x else (cx, z0 + sz * t)
            if any(abs(sxp - tx) < 0.9 and abs(szp - tz) < 0.9 for tx, tz in trees):
                continue
            d = min(0.7 + 0.4 * p.rand(key, i), min(sx, sz) - 0.3)
            p.cyl("leaf_light" if p.rand(key, i, 2) > 0.6 else "leaf_mid", sxp, szp, d, h - 0.06, h + d * 0.6)
    p.solid(cx, cz, sx, sz, 0.0, 0.6)


def strip(p, x0, z0, x1, z1, key, step=6.5):
    """건물 벽에 붙는 좁은 화단: 생울타리 + 일정 간격의 좁은 상록수"""
    long_x = (x1 - x0) >= (z1 - z0)
    L = (x1 - x0) if long_x else (z1 - z0)
    n = max(1, int(round(L / step)))
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    trees = [((x0 + L * (i + 0.5) / n, cz) if long_x else (cx, z0 + L * (i + 0.5) / n)) for i in range(n)] if L > 3.0 else []
    planter(p, x0, z0, x1, z1, key, trees, "slim", hedge=True)


def pergola(p, x, z, w=3.2, d=2.4):
    """휴게정원 퍼걸러: 기둥 4개 + 도리 + 살 지붕 + 벤치"""
    for dx in (-w / 2, w / 2):
        for dz in (-d / 2, d / 2):
            p.box("bench_wood", x + dx, z + dz, 0.14, 0.14, 0.0, 2.4)
            p.solid(x + dx, z + dz, 0.2, 0.2, 0.0, 2.4)
    for dz in (-d / 2, d / 2):
        p.box("bench_wood", x, z + dz, w + 0.5, 0.1, 2.4, 2.52)
    for i in range(7):
        p.box("bench_wood", x - w / 2 + w * i / 6, z, 0.07, d + 0.6, 2.52, 2.6)
    bench(p, x, z, 1.8, along_u=True)



def lamp(p, x, z, arm=(0, 1)):
    """가로등: 기둥 + 팔 + 등"""
    p.cyl("lamp_post", x, z, 0.14, 0.0, 4.2)
    ax, az = arm
    p.box("lamp_post", x + ax * 0.4, z + az * 0.4, 0.1 + abs(ax) * 0.8, 0.1 + abs(az) * 0.8, 4.1, 4.2)
    p.box("lamp_head", x + ax * 0.75, z + az * 0.75, 0.3 + abs(az) * 0.1, 0.3 + abs(ax) * 0.1, 4.0, 4.1)
    p.solid(x, z, 0.3, 0.3, 0.0, 2.0)


def fline(p, x0, z0, x1, z1, base, w=0.08, mat="line_white"):
    """바닥 선 (base = 그 바닥 구획의 윗면 높이)"""
    L = math.hypot(x1 - x0, z1 - z0)
    if L < 1e-3:
        return
    yaw = -math.degrees(math.atan2(z1 - z0, x1 - x0))
    p.box(mat, (x0 + x1) / 2, (z0 + z1) / 2, L, w, base - 0.008, base + 0.006, yaw=yaw)


def farc(p, cx, cz, r, a0, a1, base, n=20, w=0.08, mat="line_white"):
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
           for i in range(n + 1)]
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        fline(p, xa, za, xb, zb, base, w, mat)


def wlabel(sw, parent, x, y, z, text, size=0.006, font=56, color=(0.95, 0.95, 0.92), face="south"):
    """글자판 (남쪽 = +z 를 보는 면, 동쪽 = +x 를 보는 면: 카메라에서 읽히는 방향)"""
    label(sw, parent, (x, y, z), text, size, font, color, rows_y(0.0 if face == "south" else 90.0))


def _car(p, x, z, mat, along_z=True):
    """주차된 차 (충돌 한 덩어리)"""
    sx, sz = (1.8, 4.4) if along_z else (4.4, 1.8)
    p.box(mat, x, z, sx, sz, 0.3, 0.95)
    cx, cz = (1.62, 2.3) if along_z else (2.3, 1.62)
    p.box("car_glass", x, z + (0.2 if along_z else 0.0), cx, cz, 0.95, 1.45)
    p.box(mat, x, z + (0.2 if along_z else 0.0), cx - 0.12, cz - 0.3, 1.45, 1.5)
    for dx in (-1, 1):
        for dz in (-1, 1):
            wx, wz = (x + dx * 0.86, z + dz * 1.35) if along_z else (x + dz * 1.35, z + dx * 0.86)
            ws = (0.2, 0.62) if along_z else (0.62, 0.2)
            p.box("tire", wx, wz, ws[0], ws[1], 0.0, 0.62)
    p.solid(x, z, sx, sz, 0.0, 1.5)


def front_plateau(p, sw, parent):
    """본관 둘레: 출입구만 비운 연속 화단, 3.5m 보행로 옆 벤치 4개와 국기게양대 2기, 스탠드 쪽 화단·고목 띠(가운데 보행축과
    스탠드 상단 통로는 비운다), 가로등, 동측 화단, 서·동 잔디 마당, 문 앞 매트.
    (건물 벽 옆 나무는 수관이 벽 안으로 들어가지 않게 좁은 상록수만 쓴다)"""
    # 남쪽(정면): 세 출입구(x = -28.04, 2.02, 28.04) 앞 포장은 비운다
    for i, (x0, x1) in enumerate(((-26.2, -3.6), (5.6, 26.2))):
        strip(p, x0, MAIN_FRONT_Z + 0.2, x1, MAIN_FRONT_Z + 1.45, "fa%d" % i, 5.6)
    # 서·동 벽, 북쪽(후문 x = 2.02 앞은 비운다)
    strip(p, -31.5, -62.4, -30.25, -45.6, "mw", 5.6)
    strip(p, 30.25, -62.4, 31.5, -45.6, "me", 5.6)
    strip(p, -29.6, -64.8, 0.1, -63.5, "mn0", 5.9)
    strip(p, 3.9, -64.8, 29.6, -63.5, "mn1", 6.4)
    for x, z in ((-28.04, MAIN_FRONT_Z + 0.55), (2.02, MAIN_FRONT_Z + 0.55), (28.04, MAIN_FRONT_Z + 0.55), (2.02, -63.85)):
        p.box("mat_dark", x, z, 2.2, 0.9, PAVE, PAVE + 0.012)
    # 스탠드 쪽 화단과 수령 오래된 교목 (좌우 대칭). 가운데 4m 보행축과 양끝 계단 앞은 비운다
    for i, (x0, x1) in enumerate(((-40.5, -3.2), (3.2, 40.5))):
        s = -1 if x0 < 0 else 1
        trees = [(s * (8.0 + 7.0 * k), -37.8) for k in range(5)]
        planter(p, x0, -38.9, x1, -36.75, "fb%d" % i, trees, "old")
    for x in (-18.5, -8.5, 8.5, 18.5):
        bench(p, x, -39.2, 1.8, along_u=True)
    for x in (-25.5, -11.5, 11.5, 25.5):
        lamp(p, x, -37.8, (0, -1))
    for x in (-25.9, -3.9, 5.9, 25.9):
        lamp(p, x, -43.9, (0, 1))
    # 국기게양대 2기: 올라와서 보이는 왼쪽 화단 앞 (왼쪽 태극기, 오른쪽 학교 문양기)
    for x, m in ((-14.6, "flag_kr"), (-12.4, "flag_school")):
        p.cyl("steel", x, -39.2, 0.12, 0.0, 8.0)
        p.cyl("stone", x, -39.2, 0.5, 0.0, 0.45)
        p.box(m, x + 0.72, -39.2, 1.35, 0.03, 6.9, 7.8)
        p.cyl("brass", x, -39.2, 0.2, 8.0, 8.14)
        p.solid(x, -39.2, 0.4, 0.4, 0.0, 2.0)
    p.box("art_red", -14.6 + 0.72, -39.18, 0.36, 0.035, 7.33, 7.52)
    p.box("art_blue", -14.6 + 0.72, -39.18, 0.36, 0.035, 7.18, 7.33)
    p.box("emblem_gold", -12.4 + 0.72, -39.18, 0.4, 0.035, 7.15, 7.55)
    # 동측 화단 (건물 동쪽 끝 옆, 나무 3그루). 이계에서 이 위 3층 높이에 2-7 교실이 생기므로
    # 수관이 3층 바닥(고지대 위 7.6m)까지 닿지 않는 중간 크기 나무를 쓴다.
    planter(p, 33.0, -62.5, 39.0, -46.5, "fe", [(36.0, -59.0), (36.0, -54.5), (36.0, -50.0)], "mid")
    # 서·동 잔디 마당의 나무 (구름다리 아래와 기둥 자리는 비운다)
    for i, (x, z) in enumerate(((-40.5, -47.5), (-47.0, -46.5), (-53.0, -49.5), (-41.0, -62.0), (-48.0, -63.0), (-53.5, -61.6))):
        tree(p, x, z, "pine" if i in (1, 4) else "mid", "wl%d" % i)
    for i, z in enumerate((-47.0, -53.0, -59.0)):
        tree(p, 48.0, z, "pine" if i == 1 else "mid", "el%d" % i)
    for z in (-50.0, -60.5):
        bench(p, -35.4, z, 1.8, along_u=False)
        bench(p, 43.4, z, 1.8, along_u=False)
    # 건물 뒤 가로등 (북쪽 화단 안)
    for x in (-26.9, -9.5, 9.5, 26.8):
        lamp(p, x, -64.15, (0, -1))



def rear_parking(p, sw, parent, tops):
    """본관 뒤편 주차장: 주차 구획선, 주차 블록, 차 4대, 양끝 녹지섬과 조명, 후문 진입로 중앙선, 자전거 거치대, 산림 경계 배수로"""
    base = tops.get("RearParking", 3.93) - TOP
    for x0, x1 in ((-34.6, -8.6), (8.6, 36.6)):
        n = int(round((x1 - x0) / 2.6))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            fline(p, x, -73.6, x, -68.9, base)
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            p.box("stone", x, -73.35, 1.7, 0.2, base, base + 0.14)
    for x, m in ((-30.7, "car_white"), (-17.7, "car_gray"), (12.42, "car_blue"), (27.69, "car_white")):
        _car(p, x, -71.3, m)
    road = tops.get("RearGateRoad", 3.95) - TOP
    for k in range(6):
        fline(p, 0.0, -77.6 + 2.0 * k, 0.0, -76.6 + 2.0 * k, road, 0.12, "line_yellow")
    planter(p, -37.8, -73.6, -35.3, -65.4, "pk0", [(-36.55, -71.2), (-36.55, -67.5)], "mid")
    planter(p, 36.9, -73.6, 39.3, -65.4, "pk1", [(38.1, -71.2), (38.1, -67.5)], "mid")
    lamp(p, -34.9, -65.6, (1, 0))
    lamp(p, 37.2, -64.7, (-1, 0))
    p.box("drain", -1.5, -73.92, 108.0, 0.22, 0.0, 0.04)
    # 자전거 거치대 (지붕 + 거치 틀 + 자전거 몇 대)
    bx0, bx1, bz0, bz1 = 44.2, 49.8, -72.8, -69.8
    for x in (bx0, bx1):
        for z in (bz0, bz1):
            p.cyl("lamp_post", x, z, 0.1, 0.0, 2.3)
    p.box("roof_guard", (bx0 + bx1) / 2, (bz0 + bz1) / 2, bx1 - bx0 + 0.6, bz1 - bz0 + 0.6, 2.3, 2.38)
    for k in range(9):
        x = bx0 + 0.45 + 0.6 * k
        p.box("steel", x, bz0 + 0.5, 0.04, 0.04, 0.0, 0.8)
        p.box("steel", x, bz0 + 1.1, 0.04, 0.04, 0.0, 0.8)
        p.box("steel", x, bz0 + 0.8, 0.04, 0.64, 0.76, 0.8)
        if k % 2 == 0 or k == 5:
            _bike(p, x + 0.22, bz0 + 1.35, ("art_red", "art_blue", "metal_dark", "art_green", "art_yellow")[(k // 2) % 5])
    p.solid((bx0 + bx1) / 2, bz0 + 0.9, bx1 - bx0, 1.9, 0.0, 1.0)


def stands_and_field(p, sw, parent, ext, tops, geo):
    """조회대(지붕·연설대·하부 창고 문·교명판), 운동장 선·중앙 원·골대·모래판, 투광 조명탑 등기구, 스탠드 번호·화단"""
    # 조회대: 운동장 중앙선·본관 중앙 보행축과 일직선. 하부 창고 문은 운동장 쪽
    pod, ph = geo["podium"], geo["podium_top"]
    px, pz1 = pod.cx, pod.z1
    p.box("kick_plate", px, pz1 + 0.02, 2.4, 0.04, 0.0, 2.0)
    p.box("steel_frame", px, pz1 + 0.03, 2.56, 0.05, 2.0, 2.08)
    for dx in (-1.24, 1.24):
        p.box("steel_frame", px + dx, pz1 + 0.03, 0.08, 0.05, 0.0, 2.0)
    p.box("metal_dark", px, pz1 + 0.045, 0.02, 0.012, 0.05, 1.95)
    p.box("sign_blue", px + 2.3, pz1 + 0.02, 0.9, 0.03, 1.5, 1.8)
    wlabel(sw, parent, px + 2.3, 1.65, pz1 + 0.05, "체육 창고", 0.004, 48)
    for dx, z in ((-3.7, pod.z0 + 0.3), (3.7, pod.z0 + 0.3), (-2.9, pz1 - 0.3), (2.9, pz1 - 0.3)):
        p.cyl("lamp_post", px + dx, z, 0.14, ph, ph + 2.9)
    p.box("roof_guard", px, pod.cz, pod.w + 0.8, pod.d + 0.8, ph + 2.9, ph + 3.05)
    p.box("emblem", px, pz1 + 0.42, 5.0, 0.04, ph + 2.4, ph + 2.9)
    wlabel(sw, parent, px, ph + 2.65, pz1 + 0.46, "OO고등학교", 0.008, 64)
    p.box("lectern", px, pz1 - 0.9, 0.7, 0.5, ph, ph + 1.1, collide=True)
    p.box("metal_dark", px + 0.7, pz1 - 0.8, 0.03, 0.03, ph, ph + 1.4)
    p.box("speaker", px - 3.2, pod.z0 + 0.9, 0.5, 0.45, ph, ph + 1.0)
    p.box("speaker", px + 3.2, pod.z0 + 0.9, 0.5, 0.45, ph, ph + 1.0)
    # 스탠드 구역 번호 (단 앞면), 양끝 계단 옆 화단
    for i, x in enumerate((-36.0, -21.8, -8.0, 8.0, 21.8, 36.0)):
        wlabel(sw, parent, x, 0.22, -28.57, "ABCDEF"[i], 0.006, 64, (0.92, 0.92, 0.9))
    # 운동장: 경계선, 중앙선, 중앙 원, 양쪽 벌칙 구역, 골대
    base = tops.get("AthleticField", PAD)
    for a, b, c, d in ((-33, -20.5, 33, -20.5), (-33, 20.5, 33, 20.5), (-33, -20.5, -33, 20.5), (33, -20.5, 33, 20.5),
                       (0, -20.5, 0, 20.5)):
        fline(p, a, b, c, d, base, 0.1)
    farc(p, 0.0, 0.0, 7.0, 0, 360, base, 36, 0.1)
    for s in (-1, 1):
        fline(p, s * 33, -11.0, s * 22, -11.0, base, 0.1)
        fline(p, s * 33, 11.0, s * 22, 11.0, base, 0.1)
        fline(p, s * 22, -11.0, s * 22, 11.0, base, 0.1)
        fline(p, s * 33, -5.0, s * 29, -5.0, base, 0.1)
        fline(p, s * 33, 5.0, s * 29, 5.0, base, 0.1)
        fline(p, s * 29, -5.0, s * 29, 5.0, base, 0.1)
        gx = s * 33.0
        for dz in (-3.0, 3.0):
            p.cyl("goal_white", gx, dz, 0.12, 0.0, 2.3)
            p.cyl("goal_white", gx + s * 1.6, dz, 0.07, 0.0, 1.7)
            p.box("goal_white", gx + s * 0.8, dz, 1.6, 0.05, 2.2, 2.26)
            p.solid(gx, dz, 0.2, 0.2, 0.0, 2.3)
        p.box("goal_white", gx, 0.0, 0.12, 6.0, 2.2, 2.32)
        p.box("goal_white", gx + s * 1.6, 0.0, 0.07, 6.0, 1.66, 1.72)
        for k in range(13):                                   # 뒤 그물: 가는 살을 엮어 속이 비쳐 보이게
            p.box("net_white", gx + s * 1.63, -3.0 + 0.5 * k, 0.02, 0.025, 0.0, 1.66)
        for k in range(1, 4):
            p.box("net_white", gx + s * 1.63, 0.0, 0.012, 6.0, 0.415 * k, 0.415 * k + 0.02)
    # 멀리뛰기 모래판과 도움닫기 주로 (운동장 남동쪽 가장자리), 철봉 옆 급수대
    p.box("sand", 30.0, 21.75, 6.0, 1.3, base - 0.008, base + 0.02)
    for dz in (-0.72, 0.72):
        p.box("bench_wood", 30.0, 21.75 + dz, 6.2, 0.12, 0.0, 0.1)
    for dx in (-3.06, 3.06):
        p.box("bench_wood", 30.0 + dx, 21.75, 0.12, 1.56, 0.0, 0.1)
    p.box("pad_Trail", 17.0, 21.75, 20.0, 1.22, base - 0.008, base + 0.004)
    p.box("line_white", 26.4, 21.75, 0.2, 1.22, base - 0.006, base + 0.008)
    # 네 모서리 투광 조명탑: 운동장 쪽 등기구
    for x in (-36.5, 36.5):
        for z in (-24.0, 24.0):
            dz = 0.27 if z < 0 else -0.27
            for k in range(4):
                p.box("lamp_head", x - 0.78 + 0.52 * k, z + dz, 0.42, 0.05, 11.85, 12.55)



def annex_side(p, sw, parent):
    """별관 둘레 화단(출입문 구간은 비움)과 문 앞 매트, 별관 서측 휴게정원.
    휴게정원은 완만하게 굽은 산책로를 따라 굽이 안쪽마다 나무·퍼걸러를 두고, 길가에 벤치와 낮은 정원등을 놓는다."""
    from site2 import TRAIL, Z_N, Z_S
    for z in (-26.31, 23.31):
        p.box("mat_dark", -50.55, z, 1.1, 1.8, PAVE, PAVE + 0.012)
    strip(p, -51.1, -24.2, -50.1, 21.6, "ae", 6.5)            # 동측 (두 출입문 사이)
    strip(p, -68.6, -29.1, -52.4, -27.75, "an", 5.4)          # 북측
    strip(p, -70.1, -27.3, -68.95, 24.3, "aw", 6.4)           # 서측
    strip(p, -68.6, 24.75, -51.4, 25.95, "as", 5.7)           # 남측

    def at(z_target, off):
        """산책로에서 z가 가장 가까운 점을 길 옆으로 off만큼 옮긴 자리 (off > 0 = 서쪽)"""
        i = min(range(len(TRAIL)), key=lambda k: abs(TRAIL[k][1] - z_target))
        (x0, z0), (x1, z1) = TRAIL[max(0, i - 1)], TRAIL[min(len(TRAIL) - 1, i + 1)]
        length = math.hypot(x1 - x0, z1 - z0) or 1.0
        return TRAIL[i][0] - (z1 - z0) / length * off, TRAIL[i][1] + (x1 - x0) / length * off
    pergola(p, -83.6, -24.6)
    pergola(p, -90.4, 20.0)
    for i, (x, z, kind) in enumerate(((-90.6, -16.5, "mid"), (-83.4, -7.5, "old"), (-90.4, 1.5, "pine"), (-83.5, 11.0, "mid"),
                                      (-91.4, -26.6, "pine"), (-82.6, 25.2, "mid"), (-91.7, 9.6, "small"), (-82.4, -15.5, "small"),
                                      (-91.5, -8.0, "small"), (-82.5, 2.5, "pine"))):
        tree(p, x, z, kind, "wg%d" % i)
    for i, zt in enumerate((-21.0, -12.0, -3.0, 6.0, 15.0, 24.0)):
        x, z = at(zt, 2.1 if i % 2 else -2.1)
        d = 1.0 + 0.3 * p.rand("wgs", i)
        p.cyl("leaf_light" if i % 2 else "leaf_mid", x, z, d, 0.0, d * 0.62)
        p.cyl("leaf_mid", x + 0.7, z + 0.5, d * 0.7, 0.0, d * 0.45)
        p.solid(x, z, d * 0.7, d * 0.7, 0.0, 0.6)
    for i, zt in enumerate((-12.5, 5.5, 14.5)):               # 길가 벤치 (굽이 바깥쪽)
        x, z = at(zt, -1.5 if i % 2 else 1.5)
        bench(p, x, z, 1.8, along_u=False)
    for i, zt in enumerate((-27.0, -19.0, -11.0, -3.0, 5.0, 13.0, 21.0, 26.5)):   # 낮은 정원등
        x, z = at(zt, 1.25 if i % 2 else -1.25)
        p.cyl("lamp_post", x, z, 0.11, 0.0, 0.8)
        p.cyl("lamp_head", x, z, 0.16, 0.8, 0.95)
        p.solid(x, z, 0.2, 0.2, 0.0, 0.9)
    for i in range(7):                                        # 산책로 가운데 디딤돌 무늬 (밝은 판석)
        x, z = at(-22.0 + 7.5 * i, 0.0)
        p.cyl("stone", x, z, 0.9, 0.012, 0.03)
    picket(p, -92.85, Z_N + 1.6, -92.85, Z_S - 1.6)           # 숲 쪽 목책
    lamp(p, -84.6, Z_N + 2.3, (-1, 0))
    lamp(p, -84.6, Z_S - 2.3, (-1, 0))
    signpost(p, sw, parent, -84.3, Z_N + 1.9, ("휴게정원 ▼", "별관 ▶"))



def forest(p, geo, p_up):
    """북·서 외곽 산자락 수목 (배경): 서쪽 띠, 북쪽 띠(고지대 구간은 3.8m 위), 북서·북동 모서리 숲, 산림 경계 배수로"""
    pl, bank = geo["plateau"], geo["bank"]
    k = 0
    for xi, x in enumerate((-104.3, -99.4, -95.2)):
        z = -70.0 + 1.5 * xi
        while z < 53.0:
            k += 1
            tree(p, x + (p.rand("fx", k) - 0.5) * 1.6, z + (p.rand("fz", k) - 0.5) * 1.8, wild(p, "fo", k), k)
            z += 5.6
    x = -90.0
    while x < 80.0:
        k += 1
        on_top = pl.x0 + 1.5 < x < pl.x1 - 1.5
        on_bank = (pl.x0 - bank - 1.5 < x <= pl.x0 + 1.5) or (pl.x1 - 1.5 <= x < pl.x1 + bank + 1.5)
        if abs(x) > 9.0 and not on_bank:
            tree(p_up if on_top else p, x + (p.rand("fx", k) - 0.5) * 1.4, -76.2 + (p.rand("fz", k) - 0.5) * 1.2,
                 wild(p, "fo", k), k)
        x += 5.2
    # 북서 모서리: 산자락이 부지 안쪽으로 비스듬히 내려온다 (구름다리 기둥 줄은 비운다)
    for i in range(6):
        for j in range(6):
            x, z = -90.0 + 5.4 * i, -71.0 + 5.4 * j
            if i + j > 5 or x > -62.5:
                continue
            k += 1
            tree(p, x + (p.rand("nx", k) - 0.5) * 2.0, z + (p.rand("nz", k) - 0.5) * 2.0, wild(p, "no", k), k)
    # 북동 모서리
    for i in range(4):
        for j in range(5):
            x, z = 61.5 + 5.6 * i, -71.0 + 6.2 * j
            if (i + j) % 2 == 1 and j > 1:
                continue
            k += 1
            tree(p, x + (p.rand("ex", k) - 0.5) * 2.0, z + (p.rand("ez", k) - 0.5) * 2.0, wild(p, "eo", k), k)
    p.box("drain", -93.2, -9.0, 0.22, 128.0, 0.0, 0.04)
    # 울타리 밖 산자락 수목 (배경, 충돌 없음): 단마다 한두 줄씩 북쪽과 서쪽을 감싼다
    from site2 import hill_height, SITE
    for row, d in enumerate((1.6, 6.0, 9.6, 15.0, 18.6, 24.0, 29.5)):
        x = SITE.x0 - 31.0 + 2.6 * (row % 2)
        while x < SITE.x1 + 16.0:
            k += 1
            tx, tz = x + (p.rand("ox", k) - 0.5) * 2.2, SITE.z0 - d + (p.rand("oz", k) - 0.5) * 1.6
            tree(p, tx, tz, wild(p, "oo", k), k, hill_height(d) + (TOP if pl.x0 < tx < pl.x1 else 0.0), solid=False)
            x += 5.4
        z = SITE.z0 + 1.5 + 2.6 * (row % 2)
        while z < SITE.z1 + 16.0:
            k += 1
            tree(p, SITE.x0 - d + (p.rand("wx", k) - 0.5) * 1.6, z + (p.rand("wz", k) - 0.5) * 2.2,
                 wild(p, "wo", k), k, hill_height(d), solid=False)
            z += 5.4



def _bed(p, x0, z0, x1, z1, crop, key):
    """재배화단 한 칸: 나무 틀 + 흙 + 작물 줄 (crop: lettuce / tomato / corn / flower / herb / sprout)"""
    cx, cz, sx, sz = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    p.box("soil_bed", cx, cz, sx - 0.16, sz - 0.16, 0.0, 0.2)
    for dx in (-(sx / 2 - 0.04), sx / 2 - 0.04):
        p.box("bench_wood", cx + dx, cz, 0.08, sz, 0.0, 0.26)
    for dz in (-(sz / 2 - 0.04), sz / 2 - 0.04):
        p.box("bench_wood", cx, cz + dz, sx - 0.16, 0.08, 0.0, 0.26)
    rows = max(2, int((sx - 0.5) / 0.8))
    for r in range(rows):
        rx = x0 + 0.45 + (sx - 0.9) * r / max(1, rows - 1)
        p.box("soil", rx, cz, 0.42, sz - 0.5, 0.2, 0.25)                     # 이랑
        n = max(2, int((sz - 0.7) / (0.55 if crop != "corn" else 0.45)))
        for k in range(n):
            pz = z0 + 0.45 + (sz - 0.9) * k / max(1, n - 1)
            v = p.rand(key, r, k)
            if crop == "lettuce":
                p.cyl("crop", rx, pz, 0.3 + 0.08 * v, 0.24, 0.36 + 0.05 * v)
            elif crop == "tomato":
                p.box("bench_wood", rx, pz, 0.03, 0.03, 0.2, 1.25)
                p.cyl("leaf_mid", rx, pz, 0.34, 0.3, 0.95 + 0.2 * v)
                if v > 0.35:
                    p.box("art_red", rx + 0.14, pz + 0.05, 0.09, 0.09, 0.6 + 0.2 * v, 0.69 + 0.2 * v)
            elif crop == "corn":
                p.cyl("crop", rx, pz, 0.2, 0.24, 1.3 + 0.35 * v)
                p.box("art_yellow", rx + 0.09, pz, 0.07, 0.07, 0.9, 1.1)
            elif crop == "flower":
                p.cyl("leaf_light", rx, pz, 0.28, 0.24, 0.42)
                p.cyl(("art_red", "art_yellow", "paper_pink", "paper")[int(v * 4) % 4], rx, pz, 0.2, 0.42, 0.5)
            elif crop == "herb":
                p.cyl("shrub_light", rx, pz, 0.36, 0.24, 0.4 + 0.1 * v)
            elif crop == "sprout":                                               # 막 올라온 새싹
                p.cyl("crop", rx, pz, 0.13, 0.24, 0.3 + 0.05 * v)
    p.box("paper", x0 + 0.35, z1 + 0.16, 0.34, 0.03, 0.42, 0.62)                # 이름표
    p.box("bench_wood", x0 + 0.35, z1 + 0.16, 0.04, 0.04, 0.0, 0.42)
    p.solid(cx, cz, sx, sz, 0.0, 0.6)


def plots(p, sw, parent):
    """원예부 재배화단: 3열 × 2줄 여섯 칸 (사용자 지시: 1×3 -> 2×3). 열 사이 남북 통로 2개와 가운데 동서 통로, 낮은 목책,
    북쪽 입구 아치(진입광장에서 오는 길), 서쪽 쪽문(동측 통로에서 오는 길), 남쪽 작업 마당의 도구 창고·수도·퇴비함"""
    cols = ((51.95, 56.25), (57.35, 61.65), (62.75, 67.05))
    rows = ((7.6, 14.3), (15.8, 22.5))
    crops = (("lettuce", "tomato", "corn"), ("flower", "herb", "sprout"))
    for r, (z0, z1) in enumerate(rows):
        for c, (x0, x1) in enumerate(cols):
            _bed(p, x0, z0, x1, z1, crops[r][c], "bed%d%d" % (r, c))
    picket(p, 51.4, 6.9, 67.5, 6.9, gap=(61.3, 63.1))
    picket(p, 51.4, 24.5, 67.5, 24.5)
    picket(p, 51.4, 7.05, 51.4, 24.35, gap=(14.2, 15.9))
    picket(p, 67.5, 7.05, 67.5, 24.35)
    for x in (61.3, 63.1):                                                    # 입구 아치와 이름판
        p.box("bench_wood", x, 6.9, 0.12, 0.12, 0.0, 2.3)
    p.box("bench_wood", 62.2, 6.9, 2.1, 0.12, 2.3, 2.42)
    p.box("sign_board", 62.2, 6.98, 1.7, 0.04, 1.85, 2.25)
    wlabel(sw, parent, 62.2, 2.05, 7.02, "원예부 재배화단", 0.0036, 44, (0.2, 0.14, 0.08))
    p.box("cabinet_wood", 66.2, 23.6, 1.5, 1.2, 0.0, 2.0, collide=True)         # 도구 창고
    p.box("roof_guard", 66.2, 23.6, 1.8, 1.5, 2.0, 2.1)
    p.cyl("steel", 64.3, 23.9, 0.07, 0.0, 0.9)                                # 수도와 물뿌리개
    p.box("steel", 64.3, 23.77, 0.05, 0.22, 0.82, 0.87)
    p.box("stone", 64.3, 23.9, 0.7, 0.6, 0.0, 0.12)
    p.box("watering_can", 63.6, 24.0, 0.3, 0.18, 0.0, 0.28)
    p.box("watering_can", 63.3, 23.8, 0.28, 0.18, 0.0, 0.26)
    p.box("bench_wood", 53.0, 23.75, 1.3, 1.0, 0.0, 0.8, collide=True)          # 퇴비함
    p.box("soil", 53.0, 23.75, 1.14, 0.84, 0.8, 0.86)
    p.box("metal_dark", 55.0, 23.8, 0.6, 0.9, 0.3, 0.6)                         # 외발 수레
    p.cyl("tire", 55.0, 23.2, 0.36, 0.0, 0.1)
    for dx in (-0.25, 0.25):
        p.box("bench_wood", 55.0 + dx, 24.3, 0.04, 0.5, 0.45, 0.5)
    for k in range(3):                                                        # 지지대 묶음, 비료 포대
        p.box("bench_wood", 58.6 + 0.06 * k, 24.1, 0.04, 0.04, 0.0, 1.5)
    p.box("sack", 59.6, 24.0, 0.6, 0.4, 0.0, 0.18)
    p.box("sack", 59.7, 24.0, 0.6, 0.4, 0.18, 0.34)
    # 허수아비 (꽃밭 한가운데)
    sx_, sz_ = 54.1, 19.2
    p.box("bench_wood", sx_, sz_, 0.07, 0.07, 0.2, 1.9)
    p.box("bench_wood", sx_, sz_, 1.3, 0.06, 1.35, 1.42)
    p.box("cloth", sx_, sz_, 0.6, 0.12, 0.85, 1.45)
    p.cyl("sack", sx_, sz_, 0.3, 1.5, 1.82)
    p.cone("bench_wood", sx_, sz_, 0.62, 1.8, 2.08)



def _court(p, x0, z0, x1, z1, base):
    """야외 농구장: 선, 양 끝 농구대"""
    m = 0.7
    a0, a1, b0, b1 = x0 + m, x1 - m, z0 + m, z1 - m
    cz = (b0 + b1) / 2
    cx = (a0 + a1) / 2
    for a, b, c, d in ((a0, b0, a1, b0), (a0, b1, a1, b1), (a0, b0, a0, b1), (a1, b0, a1, b1), (cx, b0, cx, b1)):
        fline(p, a, b, c, d, base, 0.07, "court_line")
    farc(p, cx, cz, 1.8, 0, 360, base, 20, 0.07, "court_line")
    half = (b1 - b0) / 2 - 0.9
    reach = math.sqrt(max(0.1, 6.75 ** 2 - half ** 2))
    ang = math.degrees(math.asin(min(1.0, half / 6.75)))
    for s, ex in ((1, a0), (-1, a1)):
        ft = ex + s * 5.8
        fline(p, ex, cz - 2.45, ft, cz - 2.45, base, 0.07, "court_line")
        fline(p, ex, cz + 2.45, ft, cz + 2.45, base, 0.07, "court_line")
        fline(p, ft, cz - 2.45, ft, cz + 2.45, base, 0.07, "court_line")
        farc(p, ft, cz, 1.8, 0, 360, base, 16, 0.07, "court_line")
        hx = ex + s * 1.575
        fline(p, ex, cz - half, hx + s * reach, cz - half, base, 0.07, "court_line")
        fline(p, ex, cz + half, hx + s * reach, cz + half, base, 0.07, "court_line")
        if s > 0:
            farc(p, hx, cz, 6.75, -ang, ang, base, 16, 0.07, "court_line")
        else:
            farc(p, hx, cz, 6.75, 180 - ang, 180 + ang, base, 16, 0.07, "court_line")
        # 농구대: 끝선 밖 기둥 + 팔 + 백보드 + 림
        px = ex - s * 0.55
        p.cyl("lamp_post", px, cz, 0.22, 0.0, 3.3)
        p.box("lamp_post", px + s * 0.85, cz, 1.7, 0.14, 3.2, 3.36)
        p.box("whiteboard", px + s * 1.72, cz, 0.05, 1.8, 2.9, 3.95)
        p.box("hoop_rim", px + s * 1.98, cz, 0.45, 0.45, 3.03, 3.07)
        p.cyl("net_white", px + s * 1.98, cz, 0.36, 2.68, 3.03)
        p.box("stone_dark", px, cz, 0.9, 0.9, 0.0, 0.25)
        p.solid(px, cz, 0.5, 0.5, 0.0, 2.2)


def _fitness(p, sw, parent, x0, z0, x1, z1, mirror):
    """야외 체력단련장. 북쪽 입구에서 남쪽으로: 철봉 3단·구름사다리 / 평행봉·허리돌리기·공중걷기·역기 올리기 /
    윗몸일으키기·평균대·통나무 디딤목 / 그늘막·음수대·벤치. 농구장 쪽 가장자리는 지압 보도, 바깥쪽은 낮은 울타리."""
    def X(t):                    # t = 0 농구장 쪽 가장자리, 1 바깥쪽 가장자리
        return x0 + (x1 - x0) * (1 - t if mirror else t)
    out = -1 if mirror else 1    # 바깥쪽 방향 (x)
    # 고무 매트 구역과 지압 보도
    p.box("rubber_green", X(0.52), z0 + 5.3, (x1 - x0) * 0.7, 5.6, PAD, PAD + 0.008)
    p.box("rubber_blue", X(0.56), z0 + 11.7, (x1 - x0) * 0.78, 6.6, PAD, PAD + 0.008)
    p.box("rubber_green", X(0.56), z0 + 17.9, (x1 - x0) * 0.78, 5.4, PAD, PAD + 0.008)
    p.box("stone", X(0.08), z0 + 11.8, 1.1, 18.4, PAD, PAD + 0.01)
    for i in range(23):
        for j in range(3):
            p.cyl("stone_dark", X(0.08) - 0.32 + 0.32 * j + (0.16 if i % 2 else 0.0) - 0.08, z0 + 3.0 + 0.8 * i, 0.16, PAD + 0.01, PAD + 0.05)
    # 철봉 3단 (높이 순), 구름사다리
    bx = X(0.3)
    for k, hh in enumerate((2.3, 2.0, 1.7)):
        zz = z0 + 3.5 + 1.6 * k
        for dz in (-0.75, 0.75):
            p.cyl("fit_steel", bx, zz + dz, 0.1, 0.0, hh)
        p.box("steel", bx, zz, 0.05, 1.5, hh - 0.08, hh - 0.03)
    p.solid(bx, z0 + 5.1, 0.3, 4.9, 0.0, 2.0)
    mx = X(0.72)
    for dz in (0.0, 4.2):
        for dx in (-0.45, 0.45):
            p.cyl("fit_steel", mx + dx, z0 + 3.2 + dz, 0.1, 0.0, 2.3)
            p.solid(mx + dx, z0 + 3.2 + dz, 0.2, 0.2, 0.0, 2.0)
    for dx in (-0.45, 0.45):
        p.box("fit_steel", mx + dx, z0 + 5.3, 0.07, 4.3, 2.23, 2.3)
    for k in range(10):
        p.box("fit_yellow", mx, z0 + 3.5 + 0.4 * k, 0.9, 0.045, 2.24, 2.285)
    # 평행봉
    px = X(0.3)
    for dx in (-0.28, 0.28):
        p.box("steel", px + dx, z0 + 11.4, 0.05, 2.6, 1.22, 1.27)
        for dz in (-1.1, 1.1):
            p.cyl("fit_steel", px + dx, z0 + 11.4 + dz, 0.08, 0.0, 1.22)
    p.solid(px, z0 + 11.4, 0.7, 2.6, 0.0, 1.3)
    # 허리돌리기 2, 공중걷기 2, 역기 올리기 2
    for k in range(2):
        tx, tz = X(0.56), z0 + 9.6 + 2.0 * k
        p.cyl("fit_steel", tx, tz, 0.1, 0.0, 1.25)
        p.cyl("fit_yellow", tx, tz, 0.5, 0.12, 0.18)
        p.box("fit_steel", tx, tz, 0.7, 0.05, 1.2, 1.25)
        p.solid(tx, tz, 0.5, 0.5, 0.0, 1.25)
        ax, az = X(0.8), z0 + 9.6 + 2.0 * k
        for dx in (-0.32, 0.32):
            p.cyl("fit_steel", ax + dx, az, 0.09, 0.0, 1.35)
            p.box("fit_yellow", ax + dx * 0.55, az, 0.05, 0.05, 0.3, 1.3)
            p.box("fit_yellow", ax + dx * 0.55, az, 0.16, 0.34, 0.24, 0.3)
        p.box("fit_steel", ax, az, 0.75, 0.07, 1.3, 1.37)
        p.solid(ax, az, 0.8, 0.5, 0.0, 1.3)
        wx, wz = X(0.56 + 0.24 * k), z0 + 14.0
        p.cyl("fit_steel", wx, wz + 0.35, 0.1, 0.0, 1.7)
        p.box("fit_yellow", wx, wz, 0.42, 0.42, 0.4, 0.48)
        p.box("fit_yellow", wx, wz + 0.24, 0.42, 0.07, 0.48, 1.0)
        for dx in (-0.3, 0.3):
            p.box("fit_steel", wx + dx, wz - 0.05, 0.05, 0.6, 1.05, 1.1)
        p.solid(wx, wz + 0.1, 0.7, 0.8, 0.0, 1.1)
    # 윗몸일으키기대 3
    sx_ = X(0.3)
    for k in range(3):
        zz = z0 + 16.0 + 1.7 * k
        p.box("fit_yellow", sx_, zz, 1.9, 0.5, 0.42, 0.5)
        for dx in (-0.8, 0.8):
            p.box("fit_steel", sx_ + dx, zz, 0.08, 0.5, 0.0, 0.42)
        p.box("fit_steel", sx_ + out * 0.9, zz, 0.06, 0.6, 0.5, 0.85)
        p.solid(sx_, zz, 1.9, 0.5, 0.0, 0.6)
    # 평균대 2 (길이 4m), 통나무 디딤목 5 (점점 높아진다)
    for k, t in enumerate((0.6, 0.72)):
        p.box("bench_wood", X(t), z0 + 17.8, 0.14, 4.0, 0.28 + 0.14 * k, 0.4 + 0.14 * k)
        for dz in (-1.7, 1.7):
            p.box("fit_steel", X(t), z0 + 17.8 + dz, 0.3, 0.08, 0.0, 0.28 + 0.14 * k)
        p.solid(X(t), z0 + 17.8, 0.2, 4.0, 0.0, 0.4 + 0.14 * k)
    for k in range(5):
        p.cyl("bark", X(0.9), z0 + 15.8 + 1.0 * k, 0.42, 0.0, 0.2 + 0.1 * k, collide=True)
    # 남쪽 끝: 그늘막과 벤치, 음수대, 분리수거함
    pergola(p, X(0.3), z1 - 1.7)
    p.box("stone", X(0.62), z1 - 1.2, 0.5, 0.5, 0.0, 0.85, collide=True)
    p.cyl("stainless", X(0.62), z1 - 1.2, 0.32, 0.85, 0.92)
    p.box("steel", X(0.62), z1 - 1.2, 0.04, 0.04, 0.92, 1.05)
    bench(p, X(0.84), z1 - 1.1, 1.8, along_u=True)
    bins3(p, X(0.18), z0 + 1.0)
    # 입구: 이용 안내판, 옷걸이, 가로등
    sgx = X(0.82)
    for dx in (-0.6, 0.6):
        p.cyl("lamp_post", sgx + dx, z0 + 0.7, 0.08, 0.0, 2.0)
    p.box("sign_blue", sgx, z0 + 0.7, 1.4, 0.05, 1.1, 2.05)
    wlabel(sw, parent, sgx, 1.78, z0 + 0.74, "야외 체력단련장", 0.004, 44)
    wlabel(sw, parent, sgx, 1.4, z0 + 0.74, "기구 이용 전 준비운동" + chr(10) + "젖은 날 철봉 사용 금지", 0.0024, 32)
    p.solid(sgx, z0 + 0.7, 1.4, 0.2, 0.0, 2.0)
    hx = X(0.5)
    p.box("fit_steel", hx, z0 + 22.6, 1.6, 0.05, 1.4, 1.45)
    for dx in (-0.8, 0.8):
        p.cyl("fit_steel", hx + dx, z0 + 22.6, 0.07, 0.0, 1.45)
    for dx in (-0.4, 0.0, 0.4):
        p.box("steel", hx + dx, z0 + 22.55, 0.03, 0.1, 1.3, 1.4)
    lamp(p, X(0.04), z0 + 1.0, (-out, 0))
    lamp(p, X(0.96), z0 + 12.0, (-out, 0))
    lamp(p, X(0.04), z1 - 1.0, (-out, 0))
    # 바깥쪽·남쪽 낮은 울타리
    picket(p, X(1.0) + out * 0.2, z0, X(1.0) + out * 0.2, z1 + 0.2, 0.9, "rail_metal")
    xa, xb = sorted((X(0.0), X(1.0) + out * 0.2))
    picket(p, xa, z1 + 0.2, xb, z1 + 0.2, 0.9, "rail_metal")



def south_area(p, sw, parent, ext, tops):
    """남측 체육 구역: 야외 농구장 2면(선·농구대), 걸어 오를 수 있는 낮은 관람 스탠드, 화단·고목 띠, 체력단련장 2곳,
    강당 둘레 화단(출입문·비상계단 구간은 비움), 강당 앞 광장 벤치·가로등, 남측 통로 가로등·벤치"""
    from site2 import site_ramp, Z_S
    from stairs2 import flat_rail
    from plan import GYM_Z0, GYM_Z1
    for i, name in enumerate(("WestBasketballCourt", "EastBasketballCourt")):
        b = ext[name]
        _court(p, b.min[0], b.min[2], b.max[0], b.max[2], tops.get(name, PAD))
    for i, name in enumerate(("WestCourtStand", "EastCourtStand")):
        b = ext[name]
        cx, sx = (b.min[0] + b.max[0]) / 2, b.max[0] - b.min[0]
        d = (b.max[2] - b.min[2]) / 3
        for k in range(3):                                   # 3단 관람 스탠드 (남쪽이 높다)
            p.box("stand", cx, b.min[2] + d * (k + 0.5), sx, d, 0.0, 0.45 * (k + 1), collide=(k == 2))
        # 걷는 면: 단 앞끝을 잇는 보이지 않는 경사면, 맨 윗단 뒤 난간
        site_ramp(p.b, p.c, "z", b.min[0], b.max[0], b.min[2] - d, 0.0, b.min[2] + 2 * d, 1.35, "stand", visible=False)
        flat_rail(p.b, p.c, "x", b.min[0], b.max[0], b.max[2] - 0.05, 1.35)
        for ax in (cx - 9.0, cx, cx + 9.0):                  # 통로 디딤판
            for k in range(3):
                p.box("site_stair", ax, b.min[2] + d * k - 0.2, 1.2, 0.4, 0.45 * k, 0.45 * k + 0.225)
    for i, name in enumerate(("WestCourtFlowerTreeMass", "EastCourtFlowerTreeMass")):
        b = ext[name]
        x0, x1, z0, z1 = b.min[0], b.max[0], b.min[2] + 0.3, b.max[2] - 0.3
        mid = (x0 + x1) / 2
        for j, (a0, a1) in enumerate(((x0 + 0.2, mid - 1.6), (mid + 1.6, x1 - 0.2))):   # 가운데는 출입 구간
            trees = [(a0 + (a1 - a0) * (k + 0.5) / 3, (z0 + z1) / 2) for k in range(3)]
            planter(p, a0, z0, a1, z1, "ct%d%d" % (i, j), trees, "old")
    for i, name in enumerate(("WestFitnessArea", "EastFitnessArea")):
        b = ext[name]
        _fitness(p, sw, parent, b.min[0] + 0.4, b.min[2] + 0.4, b.max[0] - 0.4, b.max[2] - 0.4, mirror=(i == 0))
    # 강당 둘레 화단: 북측 주출입문(x = 0), 서·동 측면 출입문, 외부 비상계단 자리는 비운다
    zn, zd = GYM_Z0, GYM_Z0 + 12.0
    strip(p, -19.6, zn - 1.2, -2.6, zn - 0.2, "gn0", 5.6)
    strip(p, 2.6, zn - 1.2, 19.6, zn - 0.2, "gn1", 5.6)
    for s, key in ((-1, "gw"), (1, "ge")):
        xa, xb = sorted((s * 20.15, s * 21.2))
        strip(p, xa, zn + 1.2, xb, zd - 1.7, key + "0", 4.5)
        planter(p, xa, zd + 1.7, xb, zd + 4.8, key + "1", (), "slim", hedge=True)
        p.box("mat_dark", s * 20.7, zd, 1.1, 2.0, PAVE, PAVE + 0.012)
    p.box("mat_dark", 0.0, zn - 0.7, 2.8, 1.2, PAVE, PAVE + 0.012)
    # 강당 앞 광장: 벤치(주출입문 앞은 비움), 가로등, 화분, 행사 게시판
    for x in (-15.5, -9.5, 9.5, 15.5):
        bench(p, x, 26.3, 1.8, along_u=True)
    for x in (-21.6, 21.6):
        lamp(p, x, 26.2, (0, 1))
        lamp(p, x * 1.22, GYM_Z1 - 1.0, (0, -1))
    bz = zn - 1.4                                            # 행사 게시판 (화단 앞에 붙여 세운다)
    for dx in (-0.9, 0.9):
        p.cyl("lamp_post", 11.0 + dx, bz, 0.08, 0.0, 2.1)
    p.box("frame_alu", 11.0, bz, 2.0, 0.07, 1.0, 2.15)
    p.box("cork", 11.0, bz - 0.04, 1.86, 0.02, 1.06, 2.09)
    for k, m in enumerate(("art_red", "paper", "art_blue", "paper_yellow")):
        p.box(m, 10.3 + 0.46 * k, bz - 0.06, 0.32, 0.01, 1.3 + 0.1 * (k % 2), 1.8 + 0.1 * (k % 2))
    p.solid(11.0, bz, 2.0, 0.2, 0.0, 2.1)
    bins3(p, -11.0, zn - 1.45)
    signpost(p, sw, parent, 26.6, Z_S - 2.2, ("강당 ▼", "농구장 ▶", "본관 ▲"))
    signpost(p, sw, parent, -46.3, Z_S - 2.2, ("별관 ▲", "강당 ▶", "휴게정원 ◀"))
    # 운동장 남측 통로: 농구장 쪽 가장자리 가로등과 벤치
    for x in (-62.0, -52.0, -34.0, 34.0, 52.0, 62.0):
        lamp(p, x, Z_S + 2.0, (0, -1))
    for x in (-57.0, -38.0, 38.0, 57.0):
        bench(p, x, Z_S + 2.1, 1.8, along_u=True)



def slopes(p, sw, parent, geo):
    """고지대 남쪽 석축 화단과 계단·경사로 사이 화단의 관목, 계단 아래 화단, 갈림길 안내판"""
    from site2 import STAIR_FOOT, RAMP_X, RAMP_FOOT, TERRACE_D
    pl, w_out, z_edge = geo["plateau"], geo["w_out"], geo["z_edge"]
    half = TOP / 2
    for i, (x0, x1) in enumerate(((pl.x0 + 0.3, -w_out - 0.3), (RAMP_X[1] + 0.3, pl.x1 - 0.3))):
        n = max(2, int((x1 - x0) / 1.5))
        for k in range(n):
            x = x0 + (x1 - x0) * (k + 0.5) / n
            d = 0.8 + 0.35 * p.rand("ter", i, k)
            p.cyl("leaf_light" if (k + i) % 3 == 0 else "leaf_mid", x, z_edge - TERRACE_D / 2, d, half, half + d * 0.7)
    for k, (x, z, top) in enumerate(geo["mid_planter"]):
        p.cyl("leaf_mid" if k % 2 else "leaf_light", x, z, 0.5, top, top + 0.45)
    # 동측 계단 아래 ~ 경사로 사이 화단, 서측 계단 옆 화단
    planter(p, w_out - 0.25, STAIR_FOOT + 0.7, RAMP_X[0] - 0.05, RAMP_FOOT - 0.6, "sr0", (), "slim", hedge=True)
    signpost(p, sw, parent, -43.1, STAIR_FOOT + 5.6, ("본관 ▲", "별관 ◀", "강당 ▼"))


def build_site_props(sw, batch, parent, ext, tops, geo):
    p0 = wp(batch, parent, 0.0, 97)
    up = geo["upper"]                    # 고지대 위 묶음 (본관 지하에 있을 때 숨겨진다)
    p38 = wp(batch, up, TOP, 131)
    front_plateau(p38, sw, up)
    rear_parking(p38, sw, up, tops)
    stands_and_field(p0, sw, parent, ext, tops, geo)
    annex_side(p0, sw, parent)
    forest(p0, geo, p38)
    gate_area(p0, sw, parent, ext)
    south_area(p0, sw, parent, ext, tops)
    slopes(p0, sw, parent, geo)
    from site_extras import site_details
    site_details(p0, p38, sw, parent, up, tops)



def _wall_run(p, mat, along, fixed, a0, a1, T, H, openings=()):
    """얇은 벽 한 줄. along = 'x'면 x 방향으로 뻗고 fixed = 벽 중심 z. openings = [(b0, b1, y0, y1, 종류)] 종류: win / door"""
    def seg(b0, b1, y0, y1, m=mat, t=T):
        if b1 - b0 < 0.01 or y1 - y0 < 0.01:
            return
        if along == "x":
            p.box(m, (b0 + b1) / 2, fixed, b1 - b0, t, y0, y1)
        else:
            p.box(m, fixed, (b0 + b1) / 2, t, b1 - b0, y0, y1)
    cur = a0
    for b0, b1, y0, y1, kind in sorted(openings):
        seg(cur, b0, 0.0, H)
        seg(b0, b1, 0.0, y0)
        seg(b0, b1, y1, H)
        if kind == "win":
            seg(b0 + 0.02, b1 - 0.02, y0, y1, "glass", 0.03)
            seg(b0 + 0.01, b1 - 0.01, y0 - 0.05, y0 + 0.02, "win_frame", T + 0.1)
            seg((b0 + b1) / 2 - 0.02, (b0 + b1) / 2 + 0.02, y0 + 0.02, y1, "win_frame", 0.06)
        else:
            seg(b0 + 0.03, b1 - 0.03, y0, y1 - 0.03, "kick_plate", 0.05)
            seg(b1 - 0.2, b1 - 0.12, 0.95, 1.1, "steel", 0.12)
        cur = b1
    seg(cur, a1, 0.0, H)


def gatehouse(p, sw, parent, x0, z0, x1, z1):
    """수위실(게이트하우스): 얇은 벽 4면(남·동 관찰창, 남쪽 문)과 지붕, 실내 책상·모니터·열쇠함·사물함·의자.
    들어가지는 않지만 뒤에 서면 컷어웨이로 속이 보이므로 속이 빈 상자가 아니라 방처럼 만든다."""
    cx, cz, sx, sz = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    T, H = 0.18, 2.7
    p.box("floor_office", cx, cz, sx - 0.1, sz - 0.1, 0.0, 0.05)
    _wall_run(p, "facade_annex", "x", z0 + T / 2, x0, x1, T, H)                                                   # 북
    _wall_run(p, "facade_annex", "x", z1 - T / 2, x0, x1, T, H,
              [(x0 + 0.5, x0 + 2.7, 1.0, 2.0, "win"), (x1 - 1.45, x1 - 0.5, 0.0, 2.05, "door")])                 # 남 (광장 쪽)
    _wall_run(p, "facade_annex", "z", x0 + T / 2, z0 + T, z1 - T, T, H)                                           # 서
    _wall_run(p, "facade_annex", "z", x1 - T / 2, z0 + T, z1 - T, T, H, [(cz - 1.0, cz + 1.0, 1.0, 2.0, "win")])  # 동 (정문 쪽)
    p.box("roof_guard", cx, cz, sx + 0.7, sz + 0.7, H, H + 0.16)
    p.box("sign_blue", x0 + 1.6, z1 + 0.02, 1.3, 0.03, 2.1, 2.42)
    wlabel(sw, parent, x0 + 1.6, 2.26, z1 + 0.05, "수위실", 0.0055, 56)
    # 실내: 남쪽 관찰창 아래 책상(모니터·출입 장부·손전등·무전기), 의자, 북벽 열쇠함·사물함, 구석 난로
    dz = z1 - T - 0.42
    p.box("office_top", x0 + 1.6, dz, 2.0, 0.7, 0.7, 0.74)
    p.box("office_drawer", x0 + 0.85, dz, 0.45, 0.6, 0.0, 0.7)
    p.box("office_panel", x0 + 2.55, dz, 0.04, 0.6, 0.0, 0.7)
    p.box("monitor", x0 + 1.2, dz + 0.12, 0.5, 0.04, 0.86, 1.18)
    p.box("metal_dark", x0 + 1.2, dz + 0.1, 0.16, 0.14, 0.74, 0.86)
    p.box("monitor", x0 + 1.85, dz + 0.12, 0.5, 0.04, 0.86, 1.18)
    p.box("metal_dark", x0 + 1.85, dz + 0.1, 0.16, 0.14, 0.74, 0.86)
    p.box("paper", x0 + 2.25, dz - 0.1, 0.3, 0.22, 0.74, 0.755)
    p.box("flashlight", x0 + 0.85, dz - 0.15, 0.2, 0.06, 0.74, 0.8)
    p.box("phone_box", x0 + 0.8, dz + 0.12, 0.18, 0.1, 0.74, 0.86)
    p.box("chair_office", x0 + 1.55, dz - 0.75, 0.48, 0.48, 0.42, 0.5)
    p.box("chair_office", x0 + 1.55, dz - 0.98, 0.46, 0.06, 0.5, 0.98)
    p.cyl("metal_dark", x0 + 1.55, dz - 0.75, 0.08, 0.05, 0.42)
    p.box("key_board", x0 + 1.2, z0 + T + 0.05, 0.7, 0.08, 1.25, 1.8)
    p.box("locker_gray", x1 - 0.6, z0 + T + 0.28, 0.5, 0.5, 0.0, 1.8)
    p.box("clock_rim", cx, z0 + T + 0.03, 0.32, 0.04, 1.95, 2.27)
    p.box("clock_face", cx, z0 + T + 0.055, 0.26, 0.02, 1.98, 2.24)
    p.box("sofa", x0 + 0.55, z0 + T + 0.9, 0.7, 1.3, 0.0, 0.42)
    p.box("sofa", x0 + 0.3, z0 + T + 0.9, 0.2, 1.3, 0.42, 0.8)
    p.solid(cx, cz, sx, sz, 0.0, H)


def _bike(p, x, z, mat):
    """거치대에 세운 자전거 (길이 방향 = z). 바퀴는 상자 두 개를 45도 엇갈려 둥글게 보이게 한다."""
    from stairs2 import slope_rows
    for dz in (-0.52, 0.52):
        c = (x, p.f.y + 0.33, z + dz)
        p.b.box(p.c, "tire", c, (0.045, 0.52, 0.52), False, (), "prop")
        p.b.box(p.c, "tire", c, (0.05, 0.52, 0.52), False, (), "prop", slope_rows("z", 45.0))
    p.box(mat, x, z, 0.034, 1.0, 0.52, 0.58)
    p.box(mat, x, z - 0.1, 0.03, 0.06, 0.58, 0.86)
    p.box("metal_dark", x, z - 0.14, 0.12, 0.24, 0.86, 0.9)
    p.box(mat, x, z + 0.45, 0.03, 0.06, 0.58, 0.95)
    p.box("metal_dark", x, z + 0.45, 0.46, 0.04, 0.95, 0.99)


def gate_area(p, sw, parent, ext):
    """정문·진입광장: 수위실, 교명석, 문기둥 등, 안내도·게시판, 벤치·가로등·화분, 갈림길 안내판,
    정문 정원(디딤길 끝 기념석 마당·고목·벤치)"""
    gatehouse(p, sw, parent, 55.4, -18.6, 60.0, -15.0)          # 진입광장 북쪽 가장자리에 붙인다
    # 교명석과 문기둥 등
    p.box("stone_dark", 72.6, -16.4, 2.6, 0.7, 0.0, 0.3)
    p.box("stone", 72.6, -16.4, 2.3, 0.5, 0.3, 1.5, collide=True)
    wlabel(sw, parent, 72.6, 0.95, -16.13, "OO고등학교", 0.0075, 64, (0.12, 0.12, 0.14))
    for name in ("MainGateNorthPost", "MainGateSouthPost"):
        b = ext[name]
        p.box("lamp_head", (b.min[0] + b.max[0]) / 2, (b.min[2] + b.max[2]) / 2, 0.5, 0.5, b.max[1], b.max[1] + 0.3)
    # 진입광장: 안내도, 게시판, 벤치 2개, 가로등, 모서리 화분 (시작 위치 반경 2m는 비운다)
    for dx in (-0.85, 0.85):
        p.cyl("lamp_post", 66.4 + dx, -15.6, 0.09, 0.0, 2.2)
    p.box("frame_alu", 66.4, -15.6, 2.0, 0.08, 1.0, 2.25)
    p.box("floor_map", 66.4, -15.55, 1.84, 0.02, 1.08, 2.0)
    wlabel(sw, parent, 66.4, 2.12, -15.5, "학교 안내도", 0.004, 44, (0.12, 0.12, 0.14))
    p.solid(66.4, -15.6, 2.0, 0.2, 0.0, 2.2)
    for x in (57.2, 64.2):
        bench(p, x, -5.45, 1.8, along_u=True)
    lamp(p, 55.2, -5.6, (0, -1))
    lamp(p, 69.6, -15.6, (0, 1))
    lamp(p, 69.6, -4.6, (0, -1))
    for x, z in ((55.2, -14.4), (74.4, -14.5), (74.4, -5.5)):
        p.box("planter", x, z, 0.9, 0.9, 0.0, 0.5, collide=True)
        p.cyl("shrub_light", x, z, 0.75, 0.5, 1.0)
    bins3(p, 64.1, -15.45)
    signpost(p, sw, parent, 52.0, -12.9, ("본관 ▲", "강당 ▼", "별관 ◀"))
    # 정문 정원: 디딤길 끝 둥근 마당에 기념석, 양옆 벤치, 뒤쪽 고목 화단
    planter(p, 54.2, -32.6, 67.6, -28.4, "gg0", [(57.0, -30.5), (62.2, -30.7), (66.0, -30.5)], "old")
    planter(p, 53.6, -27.0, 58.4, -22.6, "gg1", [(56.0, -24.8)], "mid")
    planter(p, 65.8, -27.0, 67.8, -21.0, "gg2", [(66.8, -24.4)], "pine")
    p.box("stone_dark", 62.2, -25.5, 2.2, 0.9, 0.0, 0.25)
    p.box("stone", 62.2, -25.5, 1.7, 0.6, 0.25, 1.45, collide=True)
    wlabel(sw, parent, 62.2, 0.9, -25.18, "개교 기념", 0.006, 56, (0.12, 0.12, 0.14))
    for x in (60.2, 64.2):
        bench(p, x, -23.4, 1.5, along_u=False)
    for x, z in ((60.6, -21.4), (63.8, -21.4)):
        p.cyl("lamp_post", x, z, 0.11, 0.0, 0.8)
        p.cyl("lamp_head", x, z, 0.16, 0.8, 0.95)
    plots(p, sw, parent)
