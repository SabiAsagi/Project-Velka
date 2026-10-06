# -*- coding: utf-8 -*-
"""외부 부지 (생성기 v2): 지면(건물 자리 제외), 본관 고지대(3.8m), 옹벽형 스탠드와 조회대, 양끝 계단·동측 경사로,
석축·흙 경사면, 바닥 구획과 보행로, 문·울타리·난간.

바닥은 네 층으로 깐다: 면 구획(잔디·운동장·코트 등, 서로 겹치지 않게 자른다) < 차도 < 산책로 < 포장 보행로·광장.
보행로는 중심선과 폭으로 정의하고 꺾이는 곳과 끝을 둥글게 이어, 길과 길이 끊기거나 어긋나지 않게 한다."""
import math
from geometry import Rect, subtract
from source import load_exterior
from stairs2 import slope_rows, stair_path, flat_rail, sloped_rail, flight
from batch import rows_y
from plan import FOOTPRINTS as _FP, GYM_Z0, GYM_Z1
from emit import q

MAIN_FOOTPRINT = _FP["main"]
FOOTPRINTS = [_FP["main"], _FP["annex"], _FP["gym"]]
SITE = Rect(-107.0, -79.0, 83.0, 61.0)
PLATEAU_TOP = 3.8
L_PAD, L_ROAD, L_TRAIL, L_PAVE = 0.010, 0.014, 0.018, 0.022   # 바닥 층 윗면 높이 (그 바닥 기준)
LAYER = {"Road": L_ROAD, "Trail": L_TRAIL, "Path": L_PAVE, "Plaza": L_PAVE - 0.002}
PAD_T = 0.02
STAND_Z0, STAND_Z1, N_TIER = -35.4, -28.6, 8       # 옹벽형 스탠드: 고지대 끝에서 운동장 쪽으로 8단
STAND_X = 43.3                                     # 스탠드 양끝 (그 바깥이 계단)
PODIUM = Rect(-4.0, STAND_Z0 + 5 * (STAND_Z1 - STAND_Z0) / N_TIER, 4.0, -27.0)   # 조회대 (하부 창고)
PODIUM_TOP = 2.2
PODIUM_STAIR_X = 8.4                               # 조회대 양옆 계단이 운동장에 닿는 x (±)
CENTER_STAIR = (-2.0, 2.0)                         # 조회대 뒤 중앙 계단 (조회대 -> 본관 앞)
AISLES = (-29.0, -14.5, 14.5, 29.0)                # 스탠드 통로 계단 위치
STAIR_TOP, STAIR_FOOT, STAIR_LAND = -38.0, -28.6, 1.5   # 양끝 계단: 위 끝, 아래 끝, 가운데 참 깊이
STAIR_W, CHEEK = 3.0, 0.35                         # 계단 폭, 양옆 석조 난간벽 두께
RAMP_X = (47.6, 51.2)                              # 동측 경사로 (양옆 벽 포함)
RAMP_FOOT = -22.0
TERRACE_D = 1.6                                    # 고지대 남쪽 석축 화단 깊이
BANK = 3.4                                         # 고지대 서·동 흙 경사면 폭 (걸어 오를 수 없는 급경사)
GATE_Z = -78.4                                     # 후문·고지대 북쪽 울타리 선
OUT_FAR, OUT_NEAR = 70.0, 45.0                     # 부지 밖 지면: 북·서(산자락) / 동·남
UPPER_CULL_LAYER = 15                              # 고지대 위 묶음의 렌더 레이어 (본관 2~7, 별관 8~11, 강당 12~14 다음)
HILL = ((3.0, 1.5), (12.0, 3.0), (21.0, 4.5))      # 북·서 울타리 밖 거리 -> 산자락 단 높이
SX = STAND_X + CHEEK + STAIR_W / 2                 # 양끝 계단 중심 x (±)
RX = (RAMP_X[0] + RAMP_X[1]) / 2                   # 경사로·동측 통로 중심 x
Z_S, Z_N, Z_F = 29.4, -30.9, -41.25                # 운동장 남측 통로 / 별관 북측 보행로 / 본관 앞 보행로 중심 z
X_AE = -48.5                                       # 별관 동측 보행로 중심 x


def _spline(pts, step=1.0):
    """굽은 길: 조절점을 지나는 부드러운 곡선(Catmull-Rom)을 step 간격의 점으로 돌려준다."""
    out = []
    ext = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        n = max(2, int(math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[j] + (p2[j] - p0[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (3 * p1[j] - p0[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


TRAIL = _spline([(-87.0, Z_N), (-88.4, -25.0), (-85.5, -16.5), (-88.1, -7.5), (-85.4, 1.5), (-88.2, 11.0), (-85.7, 20.0),
                 (-87.0, Z_S)])
# 보행로: (종류, 폭, 중심선, (시작 끝 둥글게, 마지막 끝 둥글게)). 아래는 지면(y = 0)
PATHS_LOW = [
    ("Path", 3.0, [(RX, RAMP_FOOT), (RX, Z_S)], (False, False)),                         # 동측 통로 (북쪽은 경사로로 이어진다)
    ("Path", 3.0, [(SX, STAIR_FOOT), (SX, -20.5), (RX, -20.5)], (False, False)),         # 동측 계단 아래 ~ 동측 통로
    ("Path", 3.0, [(-87.0, Z_S), (70.0, Z_S)], (True, True)),                            # 운동장 남측 통로
    ("Path", 3.0, [(-87.0, Z_N), (X_AE, Z_N), (X_AE, Z_S)], (True, False)),              # 별관 북측 ~ 동측 보행로
    ("Path", 3.0, [(-SX, STAIR_FOOT), (-SX, -25.4), (X_AE, -25.4)], (False, False)),     # 서측 계단 아래 ~ 별관 동측 보행로
    ("Path", 2.2, [(-51.25, -26.31), (X_AE, -26.31)], (False, False)),                   # 별관 출입문 앞
    ("Path", 2.2, [(-51.25, 23.31), (X_AE, 23.31)], (False, False)),
    ("Path", 3.0, [(-24.3, Z_S), (-24.3, 59.9)], (False, False)),                        # 강당 서·동측 보행로
    ("Path", 3.0, [(24.3, Z_S), (24.3, 59.9)], (False, False)),
    ("Path", 1.6, [(-77.0, 59.9), (77.0, 59.9)], (True, True)),                          # 남측 시설 통로
    ("Path", 2.4, [(-20.0, GYM_Z0 + 12.0), (-24.3, GYM_Z0 + 12.0)], (False, False)),     # 강당 측면 출입문 앞
    ("Path", 2.4, [(20.0, GYM_Z0 + 12.0), (24.3, GYM_Z0 + 12.0)], (False, False)),
    ("Path", 2.4, [(-43.6, Z_S), (-43.6, 33.2)], (False, False)),                        # 농구장 진입
    ("Path", 2.4, [(43.6, Z_S), (43.6, 33.2)], (False, False)),
    ("Path", 2.0, [(X_AE, 12.0), (-37.9, 12.0)], (False, False)),                        # 운동장 수돗가
    ("Path", 2.0, [(-71.8, Z_N), (-71.8, -32.4)], (False, False)),                       # 분리수거장
    ("Path", 2.4, [(-69.9, Z_S), (-69.9, 32.3)], (False, False)),                        # 체력단련장 진입
    ("Path", 2.4, [(69.6, Z_S), (69.6, 32.3)], (False, False)),
    ("Path", 6.0, [(75.6, -10.0), (128.0, -10.0)], (False, False)),                      # 정문 앞 등굣길
    ("Path", 4.0, [(RX, -10.0), (54.5, -10.0)], (False, False)),                         # 진입광장 ~ 동측 통로
    ("Trail", 1.5, [(62.2, -15.0), (62.2, -21.6)], (False, False)),                      # 정문 정원 디딤길
    ("Trail", 5.0, [(62.2, -23.8)], (True, True)),                                       # 기념석 둘레 마당
    ("Trail", 1.6, [(62.2, -5.0), (62.2, 6.9)], (False, False)),                         # 진입광장 ~ 재배화단 입구
    ("Trail", 1.1, [(62.2, 6.9), (62.2, 24.2)], (False, False)),                         # 재배화단 남북 통로 2개
    ("Trail", 1.1, [(56.8, 7.3), (56.8, 24.2)], (False, False)),
    ("Trail", 1.5, [(51.5, 15.05), (67.3, 15.05)], (False, False)),                      # 재배화단 가운데 동서 통로
    ("Trail", 1.7, [(51.9, 23.45), (67.2, 23.45)], (False, False)),                      # 재배화단 남쪽 작업 마당
    ("Trail", 1.5, [(RX, 15.05), (51.5, 15.05)], (False, False)),                        # 동측 통로 ~ 재배화단 쪽문
    ("Trail", 2.0, TRAIL, (False, False)),                                               # 휴게정원 산책로
]
# 본관 앞뒤 고지대 (y = 3.8)
PATHS_UP = [
    ("Path", 3.5, [(-SX - 1.5, Z_F), (RX + 1.4, Z_F)], (False, False)),                  # 본관 앞 연속 보행로
    ("Path", 3.0, [(-SX, STAIR_TOP), (-SX, Z_F - 1.75)], (False, False)),                # 서측 계단 위
    ("Path", 3.0, [(SX, STAIR_TOP), (SX, Z_F)], (False, False)),                         # 동측 계단 위
    ("Path", 2.8, [(RX, STAIR_TOP), (RX, Z_F - 1.75)], (False, False)),                  # 경사로 위
    ("Path", 4.0, [(0.0, STAND_Z0), (0.0, Z_F)], (False, False)),                        # 조회대 계단 ~ 중앙 보행축
    ("Path", 1.2, [(-STAND_X, -36.0), (STAND_X, -36.0)], (False, False)),                # 스탠드 상단 통로
    ("Path", 3.0, [(-28.04, -44.74), (-28.04, Z_F)], (False, False)),                    # 서·동 출입구 앞
    ("Path", 3.0, [(28.04, -44.74), (28.04, Z_F)], (False, False)),
    ("Path", 3.0, [(-33.1, Z_F), (-33.1, -66.7)], (False, False)),                       # 본관 서측 외곽 보행로
    ("Path", 1.5, [(-34.6, -65.95), (41.1, -65.95)], (False, False)),                    # 주차장 남쪽 보도 (서·후문·동 보행로를 잇는다)
    ("Path", 3.0, [(41.1, Z_F), (41.1, -66.7), (46.9, -66.7)], (False, False)),          # 본관 동측 ~ 자전거 거치대
    ("Path", 3.0, [(2.02, -63.25), (2.02, -65.2)], (False, False)),                      # 후문 앞
]
# 포장 광장 (보행로와 같은 층). (범위, 고지대 위 여부)
PLAZAS = [
    (Rect(-24.0, 25.6, 24.0, GYM_Z0), False),                 # 강당 앞 광장
    (Rect(-28.57, Z_S, -20.0, 49.7), False),                  # 농구장과 강당 사이 체육광장
    (Rect(20.0, Z_S, 28.57, 49.7), False),
    (Rect(54.5, -15.0, 75.6, -5.0), False),                   # 정문 진입광장
    (Rect(-STAND_X - 2 * CHEEK - STAIR_W, STAIR_FOOT, -STAND_X, -26.6), False),          # 서측 계단 앞
    (Rect(-75.0, -36.4, -68.6, -32.4), False),                # 분리수거장 바닥
    (Rect(-3.2, -44.75, 5.2, -42.9), True),                   # 중앙 현관 앞
    (Rect(43.22, -73.78, 50.6, -65.19), True),                # 자전거 거치대
]
# 블록아웃에 없는 면 구획 (종류, 이름, 범위, 고지대 위 여부)
EXTRA_PADS = [
    ("Garden", "WestGardenLawn", Rect(-93.0, Z_N + 1.5, -81.0, Z_S - 1.5), False),       # 휴게정원 잔디
    ("Garden", "MainWestLawn", Rect(-56.0, -65.0, -35.2, -43.5), True),                  # 본관 서·동 잔디 마당
    ("Garden", "MainEastLawn", Rect(43.2, -65.0, 53.0, -43.5), True),
    ("Garden", "SouthEastTerrace", Rect(RAMP_X[1] + 0.1, -43.0, 53.3, -35.0), True),     # 경사로 옆 고지대 끝 잔디
    ("Forest", "NorthBankTop", Rect(-56.4, -78.28, 53.4, -74.0), True),                  # 고지대 북쪽 산림 띠
    ("Forest", "OuterNorth", Rect(-176.9, -82.0, -56.5, -79.12), False),                 # 부지 밖 산자락 첫 띠 (배경)
    ("Forest", "OuterNorthEast", Rect(53.5, -82.0, 128.0, -79.12), False),
    ("Forest", "OuterWest", Rect(-110.0, -79.12, -107.12, 106.0), False),
]
# 블록아웃의 면 구획 가운데 그대로 쓰는 것 (길·매트는 위 보행로 정의가 대신한다)
AREA_PADS = {"AthleticField": "AthleticField", "Garden": "Garden", "HorticulturePlots": "Plot", "RearParking": "Parking",
             "WestBasketballCourt": "Court", "EastBasketballCourt": "Court", "WestFitnessArea": "Fitness",
             "EastFitnessArea": "Fitness", "WestCourtFlowerTreeMass": "Garden", "EastCourtFlowerTreeMass": "Garden",
             "NorthForestSlopeMass": "Forest", "WestForestSlopeMass": "Forest", "NorthGardenBand": "Garden",
             "SouthGardenBand": "Garden"}
PAD_ORDER = ["AthleticField", "Forest", "Garden", "Plot", "Parking", "Fitness", "Court"]


def hill_height(d):
    """울타리 밖으로 d(m) 나간 곳의 산자락 단 높이"""
    h = 0.0
    for start, height in HILL:
        if d >= start:
            h = height
    return h


def site_ramp(batch, container, axis, a0, a1, n_low, y_low, n_high, y_high, mat, groups=(), visible=True, collide=True):
    """경사 슬래브 (보이는 면 + 충돌). visible=False면 충돌만 둔다."""
    run = n_high - n_low
    rise = y_high - y_low
    sign = 1 if run > 0 else -1
    length = math.hypot(run, rise)
    ang = math.degrees(math.atan2(rise, abs(run)))
    t = 0.3
    ny, nn = math.cos(math.radians(ang)), -math.sin(math.radians(ang)) * sign
    mid_n, mid_y = (n_low + n_high) / 2, (y_low + y_high) / 2
    rows = slope_rows(axis, ang * sign)
    if axis == "z":
        c = ((a0 + a1) / 2, mid_y - ny * t / 2, mid_n - nn * t / 2)
        size = (a1 - a0, t, length)
    else:
        c = (mid_n - nn * t / 2, mid_y - ny * t / 2, (a0 + a1) / 2)
        size = (length, t, a1 - a0)
    if visible:
        batch.box(container, mat, c, size, collide, groups, "site_ramp", rows)
    else:
        batch.solid(container, c, size, groups, "site_ramp", rows)


def emit_pads(batch, parent, pads, blockers, level):
    """면 구획. pads: [(종류, 범위)] 우선순위 낮은 것부터. 높은 우선순위가 덮는 부분은 잘라내 겹치지 않게 깐다."""
    placed = []
    top = level + L_PAD
    for kind, rect in reversed(pads):
        for piece in subtract(rect, blockers + placed):
            if piece.w > 0.04 and piece.d > 0.04:
                batch.box(parent, "pad_" + kind, (piece.cx, top - PAD_T / 2, piece.cz), (piece.w, PAD_T, piece.d), False, (), "pad")
        placed.append(rect)


def emit_rect(batch, parent, kind, rect, level):
    """포장 광장·차도처럼 사각형으로 까는 길 층 (건물 자리는 뺀다)"""
    top = level + LAYER[kind]
    for piece in subtract(rect, FOOTPRINTS):
        batch.box(parent, "pad_" + kind, (piece.cx, top - PAD_T / 2, piece.cz), (piece.w, PAD_T, piece.d), False, (), "path")


def emit_path(batch, parent, kind, width, pts, caps, level):
    """중심선을 따라 포장 띠를 깐다. 꺾이는 곳과 둥근 끝에는 원판을 놓아 매끄럽게 잇는다."""
    mat = "pad_" + kind
    cy = level + LAYER[kind] - PAD_T / 2
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, z1 - z0)
        if length < 1e-3:
            continue
        c = ((x0 + x1) / 2, cy, (z0 + z1) / 2)
        if abs(z1 - z0) < 1e-6:
            batch.box(parent, mat, c, (length, PAD_T, width), False, (), "path")
        elif abs(x1 - x0) < 1e-6:
            batch.box(parent, mat, c, (width, PAD_T, length), False, (), "path")
        else:
            yaw = -math.degrees(math.atan2(z1 - z0, x1 - x0))
            batch.box(parent, mat, c, (length, PAD_T, width), False, (), "path", rows_y(yaw))
    last = len(pts) - 1
    for i, (x, z) in enumerate(pts):
        if (i == 0 and not caps[0]) or (i == last and not caps[1]):
            continue
        batch.cyl(parent, mat, (x, cy, z), width, PAD_T, (), "path")


def bank(batch, parent, x_wall, out, z0, z1):
    """고지대 옆 흙 경사면 (out = -1 서쪽 / +1 동쪽): 보이는 잔디 경사면 + 그 아래 계단식 충돌 채움"""
    site_ramp(batch, parent, "x", z0, z1, x_wall + out * BANK, 0.0, x_wall, PLATEAU_TOP - 0.05, "bank_grass", collide=False)
    n = 8
    for j in range(n - 1):
        reach = BANK * (1.0 - (j + 1) / n) - 0.05
        y0, y1 = max(0.0, PLATEAU_TOP * j / n - 0.06), PLATEAU_TOP * (j + 1) / n - 0.06
        xa, xb = sorted((x_wall, x_wall + out * reach))
        batch.box(parent, "bank_grass", ((xa + xb) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (xb - xa, y1 - y0, z1 - z0), True, (), "bank")


def wing(batch, parent, x_wall, out, z_c, n=6, t=0.4):
    """흙 경사면의 남쪽 끝을 막는 얇은 석축 날개벽: 경사를 따라 계단식으로 낮아진다 (경사면의 잘린 단면이 보이지 않게)"""
    for i in range(n):
        xa, xb = sorted((x_wall + out * BANK * i / n, x_wall + out * BANK * (i + 1) / n))
        top = (PLATEAU_TOP - 0.05) * (1.0 - i / n) + 0.25
        batch.box(parent, "stone_wall", ((xa + xb) / 2, top / 2, z_c + t / 2), (xb - xa, top, t), True, (), "wing")



def terrace(batch, parent, x0, x1, z_face):
    """고지대 남쪽 가장자리의 2단 석축: 높이 절반의 아랫단(위는 화단) + 그 뒤 윗단 벽. 고지대는 이 깊이만큼 물러나 있다."""
    half = PLATEAU_TOP / 2
    z_back = z_face - TERRACE_D
    batch.box(parent, "stone_wall", ((x0 + x1) / 2, half / 2, (z_back + z_face) / 2), (x1 - x0, half, TERRACE_D), True, (), "terrace")
    batch.box(parent, "stone_wall", ((x0 + x1) / 2, PLATEAU_TOP / 2, z_back - 0.075), (x1 - x0, PLATEAU_TOP, 0.15), True, (), "terrace")
    batch.box(parent, "soil_bed", ((x0 + x1) / 2, half + 0.03, (z_back + z_face) / 2), (x1 - x0 - 0.3, 0.06, TERRACE_D - 0.3),
              False, (), "terrace")


def end_stair(batch, sw, parent, side, name):
    """운동장 -> 본관 앞 고지대 계단 (side = -1 서 / +1 동): 폭 3m 두 줄 계단 + 가운데 참, 양옆은 계단을 따라 오르는 석조 난간벽"""
    xa, xb = sorted((side * STAND_X, side * (STAND_X + 2 * CHEEK + STAIR_W)))
    c0, c1 = xa + CHEEK, xb - CHEEK
    half = PLATEAU_TOP / 2
    run = (STAIR_FOOT - STAIR_TOP - STAIR_LAND) / 2
    za = STAIR_FOOT - run                 # 아래 계단 윗끝 = 참 앞
    zb = za - STAIR_LAND                  # 참 뒤 = 위 계단 아랫끝
    cx = (c0 + c1) / 2
    flight(batch, parent, "z", STAIR_FOOT, za, 0.0, half, c0, c1, "site_stair", (), (), solid_to=za)
    batch.box(parent, "site_stair", (cx, half / 2, (za + zb) / 2), (c1 - c0, half, STAIR_LAND), True, (), "landing")
    flight(batch, parent, "z", zb, STAIR_TOP, half, PLATEAU_TOP, c0, c1, "site_stair", (), (), solid_to=STAIR_TOP)
    batch.box(parent, "site_stair", (cx, half / 2, (zb + STAIR_TOP) / 2), (c1 - c0, half, zb - STAIR_TOP), True, (), "stair_base")
    for w0, w1 in ((xa, c0), (c1, xb)):
        wx, ww = (w0 + w1) / 2, w1 - w0
        for z_lo, z_hi, y_lo, y_hi in ((STAIR_FOOT, za, 0.0, half), (zb, STAIR_TOP, half, PLATEAU_TOP)):
            n = 3
            for i in range(n):
                p0, p1 = z_lo + (z_hi - z_lo) * i / n, z_lo + (z_hi - z_lo) * (i + 1) / n
                top = y_lo + (y_hi - y_lo) * (i + 1) / n + 0.8
                batch.box(parent, "stone_wall", (wx, top / 2, (p0 + p1) / 2), (ww, top, abs(p1 - p0)), True, (), "cheek")
        batch.box(parent, "stone_wall", (wx, (half + 0.8) / 2, (za + zb) / 2), (ww, half + 0.8, STAIR_LAND), True, (), "cheek")
        batch.box(parent, "stone_dark", (wx, 0.5, STAIR_FOOT + 0.2), (ww + 0.14, 1.0, 0.5), True, (), "pier")      # 아래 끝 기둥
        batch.box(parent, "stone_dark", (wx, PLATEAU_TOP + 0.5, STAIR_TOP - 0.2), (ww + 0.14, 1.0, 0.5), True, (), "pier")
    stair_path(sw, parent, [(cx, 0.0, STAIR_FOOT + 1.0), (cx, half, (za + zb) / 2), (cx, PLATEAU_TOP, STAIR_TOP - 1.0)], name=name)
    return Rect(xa, STAIR_TOP, xb, STAIR_FOOT)


def east_ramp(batch, sw, parent):
    """동측 경사로: 본관 앞 고지대에서 동측 통로까지 길게 내려오는 완만한 보행 경사면. 양옆은 경사를 따라 낮아지는 석축."""
    x0, x1 = RAMP_X
    c0, c1 = x0 + 0.4, x1 - 0.4
    site_ramp(batch, parent, "z", c0, c1, RAMP_FOOT, 0.0, STAIR_TOP, PLATEAU_TOP, "site_stair")
    n = 16
    for i in range(n):
        za, zb = RAMP_FOOT + (STAIR_TOP - RAMP_FOOT) * i / n, RAMP_FOOT + (STAIR_TOP - RAMP_FOOT) * (i + 1) / n
        fill = PLATEAU_TOP * i / n - 0.06
        if fill > 0.05:
            batch.box(parent, "site_stair", ((c0 + c1) / 2, fill / 2, (za + zb) / 2), (c1 - c0, fill, abs(zb - za)), False, (), "ramp_fill")
        top = PLATEAU_TOP * (i + 1) / n + 0.3
        for w0, w1 in ((x0, c0), (c1, x1)):
            batch.box(parent, "stone_wall", ((w0 + w1) / 2, top / 2, (za + zb) / 2), (w1 - w0, top, abs(zb - za)), True, (), "ramp_wall")
    for w in (c0 + 0.06, c1 - 0.06):
        sloped_rail(batch, parent, "z", RAMP_FOOT, STAIR_TOP, 0.0, PLATEAU_TOP, w, (), (0.3, 0.3))
    cx = (c0 + c1) / 2
    stair_path(sw, parent, [(cx, 0.0, RAMP_FOOT + 1.0), (cx, PLATEAU_TOP, STAIR_TOP - 1.0)], name="EastRampPath")
    return Rect(x0, STAIR_TOP, x1, RAMP_FOOT)


def build_stand(batch, sw, parent):
    """옹벽형 스탠드 8단(어디서나 걸어 오르내릴 수 있다)과 중앙 조회대.
    조회대는 양옆 계단으로 운동장에서 오르고, 뒤쪽 중앙 계단으로 본관 앞 보행축에 이어진다."""
    stand = Rect(-STAND_X, STAND_Z0, STAND_X, STAND_Z1)
    pod = PODIUM
    d = (STAND_Z1 - STAND_Z0) / N_TIER
    h = PLATEAU_TOP / (N_TIER + 1)
    cs = Rect(CENTER_STAIR[0], STAND_Z0, CENTER_STAIR[1], pod.z0)
    for k in range(N_TIER):
        top = PLATEAU_TOP - h * (k + 1)
        r = Rect(stand.x0, STAND_Z0 + d * k, stand.x1, STAND_Z0 + d * (k + 1))
        for piece in subtract(r, [pod, cs]):
            batch.box(parent, "stand", (piece.cx, top / 2, piece.cz), (piece.w, top, piece.d), False, (), "stand")
        for ax in AISLES:
            batch.box(parent, "site_stair", (ax, top + h * 0.25, r.z0 + 0.2), (1.2, h * 0.5, 0.4), False, (), "stand_step")
            if k == N_TIER - 1:
                batch.box(parent, "site_stair", (ax, h * 0.25, r.z1 + 0.2), (1.2, h * 0.5, 0.4), False, (), "stand_step")
    # 걷는 면: 단 앞끝을 잇는 보이지 않는 경사면 (단 높이 0.42m는 그냥은 오를 수 없다)
    front = STAND_Z1 + d

    def slope(x0, x1, z_low):
        y_low = PLATEAU_TOP * (front - z_low) / (front - STAND_Z0)
        site_ramp(batch, parent, "z", x0, x1, z_low, y_low, STAND_Z0, PLATEAU_TOP, "stand", visible=False)
    px = PODIUM_STAIR_X + 0.2
    slope(stand.x0, -px, front)
    slope(px, stand.x1, front)
    slope(-px, pod.x0, STAND_Z1)
    slope(pod.x1, px, STAND_Z1)
    slope(pod.x0, cs.x0 - 0.3, pod.z0)
    slope(cs.x1 + 0.3, pod.x1, pod.z0)
    # 조회대 + 양옆 계단 (스탠드 앞을 따라 운동장에서 오른다)
    batch.box(parent, "stand", (pod.cx, PODIUM_TOP / 2, pod.cz), (pod.w, PODIUM_TOP, pod.d), True, (), "podium")
    for s in (-1, 1):
        flight(batch, parent, "x", s * PODIUM_STAIR_X, s * pod.x1, 0.0, PODIUM_TOP, STAND_Z1, pod.z1, "site_stair", (),
               ("w0", "w1"), solid_to=s * pod.x1)
        zc = (STAND_Z1 + pod.z1) / 2
        stair_path(sw, parent, [(s * (PODIUM_STAIR_X + 0.9), 0.0, zc), (s * (pod.x1 - 0.9), PODIUM_TOP, zc)], name="PodiumSideStairPath")
    # 조회대 뒤 중앙 계단: 조회대 -> 스탠드 최상단 (본관 중앙 보행축)
    batch.box(parent, "stand", (cs.cx, PODIUM_TOP / 2, cs.cz), (cs.w, PODIUM_TOP, cs.d), True, (), "podium")
    flight(batch, parent, "z", pod.z0, STAND_Z0, PODIUM_TOP, PLATEAU_TOP, cs.x0, cs.x1, "site_stair", (), ("w0", "w1"),
           solid_to=STAND_Z0)
    stair_path(sw, parent, [(cs.cx, PODIUM_TOP, pod.z0 + 0.9), (cs.cx, PLATEAU_TOP, STAND_Z0 - 0.9)], name="PodiumRearStairPath")
    # 조회대 난간: 앞, 양옆(옆 계단이 닿는 앞부분은 연다), 뒤(중앙 계단 자리는 연다)
    flat_rail(batch, parent, "x", pod.x0, pod.x1, pod.z1 - 0.05, PODIUM_TOP)
    for s in (-1, 1):
        flat_rail(batch, parent, "z", pod.z0 + 0.1, STAND_Z1, s * (pod.x1 - 0.05), PODIUM_TOP)
    flat_rail(batch, parent, "x", pod.x0, cs.x0, pod.z0 + 0.05, PODIUM_TOP)
    flat_rail(batch, parent, "x", cs.x1, pod.x1, pod.z0 + 0.05, PODIUM_TOP)
    return stand


def build_site(sw, batch, parent, zone_cb):
    ext = {b.name: b for b in load_exterior()}
    B = lambda name, mat, collide=True: batch.box(parent, mat, ext[name].center, ext[name].size, collide, (), "site")
    # 지면: 건물 자리는 비운다 (건물 바닥 슬래브와 겹치지 않게)
    big = Rect(SITE.x0 - OUT_FAR, SITE.z0 - OUT_FAR, SITE.x1 + OUT_NEAR, SITE.z1 + OUT_NEAR)
    for r in subtract(big, FOOTPRINTS):
        batch.box(parent, "ground", (r.cx, -0.25, r.cz), (r.w, 0.5, r.d), True, (), "ground")
    # 본관 고지대: 북쪽은 부지 경계(산자락)까지 같은 높이. 건물, 스탠드, 양끝 계단·경사로, 남쪽 석축 자리를 뺀다
    pl = ext["MainPlateau"]
    plateau = Rect(pl.min[0], SITE.z0, pl.max[0], pl.max[2])
    z_edge = plateau.z1
    z_ter = z_edge - TERRACE_D - 0.15                        # 석축 뒤 = 그 구간의 고지대 남쪽 끝
    w_out = STAND_X + 2 * CHEEK + STAIR_W                    # 양끝 계단 바깥 x (47.0)
    carve = [MAIN_FOOTPRINT, Rect(-STAND_X, STAND_Z0, STAND_X, z_edge), Rect(-w_out, STAIR_TOP, -STAND_X, z_edge),
             Rect(STAND_X, STAIR_TOP, RAMP_X[1], z_edge), Rect(plateau.x0, z_ter, -w_out, z_edge),
             Rect(RAMP_X[1], z_ter, plateau.x1, z_edge)]
    # 고지대 덩어리와 그 위의 것들은 Site/Upper에 넣는다. 본관 1층과 같은 층 번호를 주어, 조작 캐릭터가 본관 지하에 있을 때
    # (지하를 덮은 앞마당이 화면을 가리지 않게) 본관 위층과 함께 숨겨진다. 그때는 아래의 흙 단면 바닥이 드러난다.
    UP = parent + "/Upper"
    sw.node("Upper", "Node3D", parent, {"metadata/building": q("main"), "metadata/level_index": "1",
                                        "metadata/cull_layer": str(UPPER_CULL_LAYER)}, groups=["school_level"], unique=False)
    for r in subtract(plateau, carve):
        batch.box(UP, "plateau", (r.cx, PLATEAU_TOP / 2, r.cz), (r.w, PLATEAU_TOP, r.d), True, (), "plateau")
    inset = Rect(plateau.x0 + 0.05, plateau.z0 + 0.05, plateau.x1 - 0.05, plateau.z1 - 0.05)
    hole = Rect(MAIN_FOOTPRINT.x0 - 0.02, MAIN_FOOTPRINT.z0 - 0.02, MAIN_FOOTPRINT.x1 + 0.02, MAIN_FOOTPRINT.z1 + 0.02)
    for r in subtract(inset, [hole]):
        batch.box(parent, "earth_cut", (r.cx, 0.015, r.cz), (r.w, 0.03, r.d), False, (), "earth_cut")
    build_stand(batch, sw, parent)
    end_stair(batch, sw, parent, -1, "WestEndStairPath")
    end_stair(batch, sw, parent, +1, "EastEndStairPath")
    east_ramp(batch, sw, parent)
    # 동측 계단과 경사로 사이: 계단을 따라 오르는 석축 화단
    half = PLATEAU_TOP / 2
    run = (STAIR_FOOT - STAIR_TOP - STAIR_LAND) / 2
    seg = [(STAIR_FOOT - run * i / 3, STAIR_FOOT - run * (i + 1) / 3, half * (i + 1) / 3) for i in range(3)]
    seg.append((STAIR_FOOT - run, STAIR_FOOT - run - STAIR_LAND, half))
    seg += [(STAIR_TOP + run * (3 - i) / 3, STAIR_TOP + run * (2 - i) / 3, half + half * (i + 1) / 3) for i in range(3)]
    mid = []
    for za, zb, yy in seg:
        top = min(PLATEAU_TOP, yy + 0.3)
        batch.box(parent, "stone_wall", ((w_out + RAMP_X[0]) / 2, top / 2, (za + zb) / 2), (RAMP_X[0] - w_out, top, za - zb), True, (),
                  "mid_planter")
        mid.append(((w_out + RAMP_X[0]) / 2, (za + zb) / 2, top))
    # 남쪽 석축과 흙 경사면, 경사면 끝 날개벽
    terrace(batch, parent, plateau.x0, -w_out, z_edge)
    terrace(batch, parent, RAMP_X[1], plateau.x1, z_edge)
    bank(batch, parent, plateau.x0, -1, SITE.z0 + 0.15, z_ter)
    bank(batch, parent, plateau.x1, +1, SITE.z0 + 0.15, z_ter)
    wing(batch, parent, plateau.x0, -1, z_ter)
    wing(batch, parent, plateau.x1, +1, z_ter)

    def rail(axis, a0, a1, fixed):
        """고지대 가장자리 난간 (손잡이 + 중간대 + 기둥 + 충돌)"""
        if a1 - a0 < 0.3:
            return
        flat_rail(batch, UP, axis, a0, a1, fixed, PLATEAU_TOP)
        c = ((a0 + a1) / 2, PLATEAU_TOP + 0.55, fixed) if axis == "x" else (fixed, PLATEAU_TOP + 0.55, (a0 + a1) / 2)
        s = (a1 - a0, 0.03, 0.03) if axis == "x" else (0.03, 0.03, a1 - a0)
        batch.box(UP, "rail_metal", c, s, False, (), "rail_mid")
    e = 0.07
    rail("x", plateau.x0 + 0.15, -w_out - 0.1, z_ter - e)                # 남서 석축 위
    rail("z", STAIR_TOP + 0.1, z_ter - 0.15, -w_out - e)                 # 서측 계단 옆 (바깥쪽)
    rail("z", STAIR_TOP + 0.1, STAND_Z0 - 1.25, -STAND_X + e)            # 서측 계단 옆 (스탠드 쪽, 상단 통로는 연다)
    rail("z", GATE_Z + 0.15, z_ter, plateau.x0 + e)                      # 서쪽 끝
    rail("z", STAIR_TOP + 0.1, STAND_Z0 - 1.25, STAND_X - e)             # 동측 계단 옆 (스탠드 쪽)
    rail("z", STAIR_TOP + 0.1, z_ter - 0.15, RAMP_X[1] + e)              # 경사로 옆 (바깥쪽)
    rail("x", RAMP_X[1] + 0.1, plateau.x1 - 0.15, z_ter - e)             # 남동 석축 위
    rail("z", GATE_Z + 0.15, z_ter, plateau.x1 - e)                      # 동쪽 끝
    # 바닥: 면 구획(겹치지 않게) -> 차도 -> 산책로·보행로·광장
    lists = {False: [], True: []}
    for name, kind in AREA_PADS.items():
        b = ext[name]
        lists[b.min[1] > 1.0].append((kind, name, Rect(b.min[0], b.min[2], b.max[0], b.max[2])))
    for kind, name, rect, high in EXTRA_PADS:
        lists[high].append((kind, name, rect))
    tops = {}
    raised = [plateau, Rect(-w_out, z_edge, w_out, STAIR_FOOT), Rect(RAMP_X[0], z_edge, RAMP_X[1], RAMP_FOOT), PODIUM,
              Rect(plateau.x0 - BANK, SITE.z0, plateau.x0, z_edge), Rect(plateau.x1, SITE.z0, plateau.x1 + BANK, z_edge)]
    for high, items in lists.items():
        level = PLATEAU_TOP if high else 0.0
        items.sort(key=lambda it: (PAD_ORDER.index(it[0]), it[1]))
        for kind, name, rect in items:
            tops[name] = level + L_PAD
        emit_pads(batch, UP if high else parent, [(k, r) for k, _, r in items], FOOTPRINTS + ([] if high else raised), level)
    road = ext["RearGateRoad"]
    emit_rect(batch, UP, "Road", Rect(road.min[0], road.min[2], road.max[0], road.max[2]), PLATEAU_TOP)
    tops["RearGateRoad"] = PLATEAU_TOP + L_ROAD
    for rect, high in PLAZAS:
        emit_rect(batch, UP if high else parent, "Plaza", rect, PLATEAU_TOP if high else 0.0)
    for kind, width, pts, caps in PATHS_LOW:
        emit_path(batch, parent, kind, width, pts, caps, 0.0)
    for kind, width, pts, caps in PATHS_UP:
        emit_path(batch, UP, kind, width, pts, caps, PLATEAU_TOP)
    # 문기둥·문·투광 조명탑·울타리
    for n in ("RearGateWestPost", "RearGateEastPost", "MainGateNorthPost", "MainGateSouthPost"):
        batch.box(UP if n.startswith("Rear") else parent, "stone_dark", ext[n].center, ext[n].size, True, (), "site")
    ng, sg = ext["MainGateNorthPost"], ext["MainGateSouthPost"]
    batch.box(parent, "metal", (ng.center[0], 1.1, (ng.center[2] + sg.center[2]) / 2), (0.15, 2.2, abs(sg.center[2] - ng.center[2]) - 0.8), True, (), "gate")
    wp, ep = ext["RearGateWestPost"], ext["RearGateEastPost"]
    batch.box(UP, "metal", ((wp.center[0] + ep.center[0]) / 2, PLATEAU_TOP + 1.1, wp.center[2]), (abs(ep.center[0] - wp.center[0]) - 0.6, 2.2, 0.15), True, (), "gate")
    for x, z in ((-36.5, -24), (36.5, -24), (-36.5, 24), (36.5, 24)):
        batch.box(parent, "metal", (x, 6.0, z), (0.45, 12.0, 0.45), True, (), "pole")
        batch.box(parent, "metal", (x, 12.2, z), (2.2, 1.0, 0.5), False, (), "pole")
    for c, s in (((SITE.cx, 1.1, SITE.z1), (SITE.w, 2.2, 0.2)), ((SITE.x0, 1.1, SITE.cz), (0.2, 2.2, SITE.d - 0.2))):
        batch.box(parent, "fence", c, s, True, (), "fence")
    # 동쪽 바깥 울타리는 정문 앞 등굣길 자리만 비운다
    gate_road = ext["EastGateRoad"]
    for z0, z1 in ((SITE.z0 + 0.1, gate_road.min[2] - 0.4), (gate_road.max[2] + 0.4, SITE.z1 - 0.1)):
        batch.box(parent, "fence", (SITE.x1, 1.1, (z0 + z1) / 2), (0.2, 2.2, z1 - z0), True, (), "fence")
    # 부지 밖 산자락 (배경): 북·서 울타리 바깥으로 갈수록 높아지는 단. 고지대 뒤는 3.8m 위에서 시작한다
    starts = [d for d, _ in HILL] + [OUT_FAR]
    for (d0, h), d1 in zip(HILL, starts[1:]):
        for x0, x1, base in ((SITE.x0 - OUT_FAR, plateau.x0, 0.0), (plateau.x0, plateau.x1, PLATEAU_TOP),
                             (plateau.x1, SITE.x1 + OUT_NEAR, 0.0)):
            batch.box(parent, "bank_grass", ((x0 + x1) / 2, (base + h) / 2, SITE.z0 - (d0 + d1) / 2), (x1 - x0, base + h, d1 - d0),
                      False, (), "hill")
        batch.box(parent, "bank_grass", (SITE.x0 - (d0 + d1) / 2, h / 2, (SITE.z0 + SITE.z1 + OUT_NEAR) / 2),
                  (d1 - d0, h, SITE.d + OUT_NEAR), False, (), "hill")
    batch.box(parent, "bank_grass", (plateau.cx, PLATEAU_TOP / 2, SITE.z0 - HILL[0][0] / 2), (plateau.w, PLATEAU_TOP, HILL[0][0]),
              False, (), "hill")
    # 북쪽 울타리: 고지대 밖은 지면에서, 고지대 위는 후문 선에서 3.8m 위로
    for x0, x1 in ((SITE.x0 + 0.1, plateau.x0 - BANK + 0.06), (plateau.x1 + BANK - 0.06, SITE.x1 - 0.1)):
        batch.box(parent, "fence", ((x0 + x1) / 2, 1.1, SITE.z0), (x1 - x0, 2.2, 0.2), True, (), "fence")
    for x0, x1 in ((plateau.x0 + 0.02, wp.min[0]), (ep.max[0], plateau.x1 - 0.02)):
        batch.box(UP, "fence", ((x0 + x1) / 2, PLATEAU_TOP + 1.1, GATE_Z), (x1 - x0, 2.2, 0.2), True, (), "fence")
    gate_x = ng.center[0]
    for z0, z1 in ((SITE.z0 + 0.1, ng.min[2]), (sg.max[2], SITE.z1 - 0.1)):
        batch.box(parent, "fence", (gate_x, 1.1, (z0 + z1) / 2), (0.2, 2.2, z1 - z0), True, (), "fence")
    T = PLATEAU_TOP
    for zid, name, rect, y0, hh in (
            ("site_field", "운동장", Rect(-46.4, -27.3, 47.5, 27.8), 0.0, 4.0),
            ("site_stand", "운동장 스탠드", Rect(-STAND_X, STAND_Z0, STAND_X, -27.2), 0.0, 7.0),
            ("site_gate", "정문 진입광장", Rect(51.4, -20, 83, 0), 0.0, 4.0),
            ("site_front_path", "본관 앞 보행로", Rect(-50, -44.7, 53.4, -35.5), T, 4.0),
            ("site_rear", "후문 주차장", Rect(-38, -78, 51, -65), T, 4.0),
            ("site_main_w", "본관 서측 마당", Rect(-56.4, -65.0, -30.1, -44.8), T, 4.0),
            ("site_main_e", "본관 동측 마당", Rect(30.1, -65.0, 53.4, -44.8), T, 4.0),
            ("site_east_path", "동측 통로", Rect(47.6, -21.5, 51.3, 27.8), 0.0, 4.0),
            ("site_south_cross", "운동장 남측 통로", Rect(-80.0, 27.9, 62.0, 30.9), 0.0, 4.0),
            ("site_gym_path", "강당 앞 광장", Rect(-24, 25.6, 24, GYM_Z0 - 0.1), 0.0, 4.0),
            ("site_gym_w", "강당 서측 체육광장", Rect(-28.5, GYM_Z0, -20.1, GYM_Z1), 0.0, 4.0),
            ("site_gym_e", "강당 동측 체육광장", Rect(20.1, GYM_Z0, 28.5, GYM_Z1), 0.0, 4.0),
            ("site_annex_road", "별관 동측 보행로", Rect(-51.2, -24.4, -46.5, 27.8), 0.0, 4.0),
            ("site_annex_n", "별관 북측 보행로", Rect(-88.0, -32.5, -47.0, -29.3), 0.0, 4.0),
            ("site_courts_w", "서측 농구장", Rect(-58.7, 33, -28.6, 49.7), 0.0, 4.0),
            ("site_courts_e", "동측 농구장", Rect(28.6, 33, 58.7, 49.7), 0.0, 4.0),
            ("site_trail", "서측 휴게 정원", Rect(-93, -29.3, -81, 27.8), 0.0, 4.0),
            ("site_fit_w", "서측 체력단련장", Rect(-76.9, 31.7, -62.9, 56), 0.0, 4.0),
            ("site_fit_e", "동측 체력단련장", Rect(62.3, 31.7, 76.9, 56), 0.0, 4.0),
            ("site_south_path", "남측 시설 통로", Rect(-79.4, 59.1, 76.8, 60.8), 0.0, 4.0),
            ("site_garden_e", "정문 정원", Rect(51.4, -33, 68, -20.1), 0.0, 4.0),
            ("site_plots", "원예부 재배화단", Rect(51.4, 6, 68, 24), 0.0, 4.0)):
        zone_cb(zid, name, rect, y0, hh)
    from site_props import build_site_props
    geo = {"upper": UP, "plateau": plateau, "podium": PODIUM, "podium_top": PODIUM_TOP, "gate_z": GATE_Z, "bank": BANK, "z_ter": z_ter,
           "z_edge": z_edge, "w_out": w_out, "mid_planter": mid}
    build_site_props(sw, batch, parent, ext, tops, geo)
