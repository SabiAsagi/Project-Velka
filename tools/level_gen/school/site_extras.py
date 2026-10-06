# -*- coding: utf-8 -*-
"""부지·건물 외부의 세부 요소 (2차 디테일).
운동장 수돗가·선수 벤치·체육 용품, 주차장 노면 표시, 분리수거장, 건물 정면 표지와 본관 시계 박공."""
from school_info import SCHOOL_NAME
from props_base import Props, bench, label
from stairs2 import slope_rows
from site_props import WorldFrame, TOP, PAD, PAVE, fline, wlabel

FLAT = slope_rows("z", 90.0)          # 바닥에 눕힌 글자 (남쪽에서 읽는 방향)


def wash_station(p, sw, parent, x, z):
    """운동장 수돗가: 콘크리트 수조 양쪽으로 수전 다섯 개씩"""
    p.box("stone", x, z, 4.6, 1.3, PAVE, 0.12)
    p.box("stone", x, z, 4.2, 0.9, 0.12, 0.62, collide=True)
    p.box("stone_dark", x, z, 3.96, 0.66, 0.62, 0.64)
    for dz in (-0.41, 0.41):
        p.box("stone", x, z + dz, 4.2, 0.08, 0.62, 0.78)
    for dx in (-2.06, 2.06):
        p.box("stone", x + dx, z, 0.08, 0.74, 0.62, 0.78)
    p.box("stone", x, z, 3.9, 0.14, 0.64, 1.05)
    for k in range(5):
        for dz in (-0.14, 0.14):
            p.box("steel", x - 1.6 + 0.8 * k, z + dz, 0.05, 0.15, 0.92, 0.97)
    p.box("soap", x - 1.2, z + 0.41, 0.1, 0.06, 0.78, 0.82)
    p.box("bucket_blue", x + 2.6, z + 0.3, 0.3, 0.3, 0.0, 0.32)
    p.box("sign_blue", x, z, 1.0, 0.04, 1.05, 1.35)
    wlabel(sw, parent, x, 1.2, z + 0.03, "수돗가", 0.0034, 44)


def field_gear(p, sw, parent):
    """운동장 가장자리: 선수 벤치, 조회대 창고 앞 고깔·공 수레·라인기"""
    for x in (-36.3, 36.3):
        for z in (-8.0, 8.0):
            bench(p, x, z, 2.4, along_u=False)
    for k in range(5):                                           # 줄지어 세운 고깔
        p.cone("cone", -2.8 - 0.5 * k, -26.5, 0.3, 0.03, 0.5)
        p.box("cone", -2.8 - 0.5 * k, -26.5, 0.36, 0.36, 0.0, 0.03)
    bx, bz = 3.0, -26.4                                          # 공 수레
    for dx in (-0.42, 0.42):
        for dz in (-0.3, 0.3):
            p.box("metal_dark", bx + dx, bz + dz, 0.03, 0.03, 0.0, 0.9)
    for h in (0.12, 0.9):
        for dz in (-0.3, 0.3):
            p.box("metal_dark", bx, bz + dz, 0.87, 0.03, h, h + 0.03)
        for dx in (-0.42, 0.42):
            p.box("metal_dark", bx + dx, bz, 0.03, 0.63, h, h + 0.03)
    for i in range(7):
        p.box("ball", bx - 0.26 + 0.26 * (i % 3), bz - 0.13 + 0.26 * ((i // 3) % 2), 0.22, 0.22, 0.16 + 0.22 * (i // 6),
              0.38 + 0.22 * (i // 6))
    p.solid(bx, bz, 0.9, 0.66, 0.0, 0.9)
    p.box("art_red", 4.4, -26.4, 0.5, 0.3, 0.12, 0.45)           # 라인기
    p.cyl("tire", 4.4, -26.4, 0.24, 0.0, 0.12)
    p.box("metal_dark", 4.72, -26.4, 0.03, 0.3, 0.45, 0.95)


def parking_marks(p, sw, parent, tops):
    """후문 주차장 노면 표시: 진입·진출 화살표, 정지선, 과속방지턱, 장애인 주차 구획, 주차 안내 표지"""
    road = tops.get("RearGateRoad", TOP + 0.014) - TOP
    lot = tops.get("RearParking", TOP + PAD) - TOP
    for x, tip, tail in ((-3.6, -75.0, -76.6), (3.6, -76.6, -75.0)):      # 들어오는 차는 서쪽 차로, 나가는 차는 동쪽 차로
        fline(p, x, tail, x, tip, road, 0.18)
        back = 0.75 if tip > tail else -0.75
        for dx in (-0.55, 0.55):
            fline(p, x, tip, x + dx, tip - back, road, 0.18)
    fline(p, 0.3, -77.4, 7.0, -77.4, road, 0.3)                           # 정지선
    for k in range(12):                                                   # 과속방지턱
        p.box("safety_yellow" if k % 2 else "tire", -6.6 + 1.2 * k, -73.95, 1.2, 0.42, road, road + 0.06)
    p.box("floor_mark_blue", 9.87, -71.25, 2.3, 4.4, lot - 0.008, lot + 0.004)   # 장애인 주차 구획
    label(sw, parent, (9.87, TOP + lot + 0.02, -71.0), "장애인", 0.0062, 64, (0.95, 0.95, 0.95), FLAT)
    p.cyl("lamp_post", 7.7, -74.6, 0.09, 0.0, 2.5)                        # 주차 안내 표지
    p.box("sign_blue", 7.7, -74.6, 0.7, 0.05, 1.75, 2.45)
    wlabel(sw, parent, 7.7, TOP + 2.1, -74.56, "P", 0.012, 64)
    p.box("label_white", 7.7, -74.6, 0.7, 0.04, 1.42, 1.7)
    wlabel(sw, parent, 7.7, TOP + 1.56, -74.565, "방문객 주차", 0.0026, 36, (0.12, 0.13, 0.16))
    p.solid(7.7, -74.6, 0.2, 0.2, 0.0, 2.0)


def recycling(p, sw, parent):
    """분리수거장 (별관 북서쪽): 낮은 콘크리트 담 세 면, 큰 수거함 4개, 접은 종이 상자와 포대"""
    x0, x1, z0, z1 = -75.0, -68.6, -36.4, -32.4
    p.box("wall_concrete", (x0 + x1) / 2, z0 + 0.075, x1 - x0, 0.15, 0.0, 1.6, collide=True)
    p.box("wall_concrete", x0 + 0.075, (z0 + z1) / 2 + 0.075, 0.15, z1 - z0 - 0.15, 0.0, 1.6, collide=True)
    p.box("wall_concrete", x1 - 0.075, z0 + 1.3, 0.15, 2.3, 0.0, 1.6, collide=True)
    for k, m in enumerate(("bin_green", "bin_blue", "bin_yellow", "bin_gray")):
        bx = x0 + 0.95 + 1.3 * k
        p.box(m, bx, z0 + 0.7, 1.1, 0.75, 0.12, 1.05)
        p.box("metal_dark", bx, z0 + 0.7, 1.14, 0.79, 1.05, 1.1)
        for dx in (-0.4, 0.4):
            p.cyl("tire", bx + dx, z0 + 1.0, 0.14, 0.0, 0.12)
        p.solid(bx, z0 + 0.7, 1.1, 0.75, 0.0, 1.1)
    for k in range(4):                                                    # 납작하게 접어 세운 종이 상자, 포대
        p.box("box", x1 - 0.5, z0 + 1.6 + 0.09 * k, 0.9, 0.07, 0.0, 0.9 - 0.08 * k)
    for k in range(3):
        p.box("sack", x1 - 1.6 + 0.2 * k, z0 + 2.9, 0.6, 0.42, 0.18 * k, 0.18 * k + 0.17)
    p.solid(x1 - 1.0, z0 + 2.4, 1.9, 1.6, 0.0, 0.6)
    p.box("sign_blue", (x0 + x1) / 2 - 1.0, z0 + 0.16, 1.5, 0.03, 1.15, 1.5)
    wlabel(sw, parent, (x0 + x1) / 2 - 1.0, 1.32, z0 + 0.19, "분리수거장", 0.0036, 44)


def site_details(p0, p38, sw, parent, up, tops):
    wash_station(p0, sw, parent, -40.6, 12.0)
    field_gear(p0, sw, parent)
    recycling(p0, sw, parent)
    parking_marks(p38, sw, up, tops)


def _plate(batch, sw, container, y, center, along, width, text, mat="sign_blue", height=0.46, size=0.0042, font=48,
           color=(0.96, 0.96, 0.93)):
    """외벽 표지판: center = (x, z) 벽면 위치, along = 'x'면 남쪽을 보는 벽(z+), 'z'면 동쪽을 보는 벽(x+)"""
    x, z = center
    if along == "x":
        batch.box(container, mat, (x, y, z + 0.035), (width, height, 0.07), False, (), "prop")
        wlabel(sw, container, x, y, z + 0.075, text, size, font, color)
    else:
        batch.box(container, mat, (x + 0.035, y, z), (0.07, height, width), False, (), "prop")
        wlabel(sw, container, x + 0.075, y, z, text, size, font, color, face="east")


def facade_details(sw, batch, plans):
    """건물 바깥 얼굴: 본관 중앙 현관 교명판, 옥상 시계 박공, 본관 출입구 표지, 별관·강당 출입구 표지.
    고정 카메라에서 보이는 남쪽·동쪽 외벽에만 붙인다. 층 묶음에 넣어 그 층이 숨겨질 때 함께 사라진다."""
    m1, mr = plans[("main", "1F")], plans[("main", "Roof")]
    fp = m1.footprint
    c1 = m1.path + "/Props"
    # 본관 중앙 현관: 차양 위 교명판, 서·동 출입구 표지
    _plate(batch, sw, c1, m1.y + 3.45, (2.02, fp.z1), "x", 4.4, SCHOOL_NAME, height=0.5, size=0.0052, font=56)
    _plate(batch, sw, c1, m1.y + 3.43, (-28.04, fp.z1), "x", 2.4, "서측 출입구", size=0.0034, font=44)
    _plate(batch, sw, c1, m1.y + 3.43, (28.04, fp.z1), "x", 2.4, "동측 출입구", size=0.0034, font=44)
    # 옥상 난간 가운데의 시계 박공 (운동장·스탠드에서 올려다보인다)
    cr = mr.path + "/Props"
    gx, gy, gz = 2.02, mr.y, fp.z1
    batch.box(cr, "facade_main", (gx, gy + 1.76, gz - 0.14), (4.6, 3.48, 0.4), True, (), "gable")
    batch.box(cr, "coping", (gx, gy + 3.56, gz - 0.14), (4.9, 0.14, 0.52), False, (), "gable")
    cy = gy + 2.35
    batch.box(cr, "clock_rim", (gx, cy, gz + 0.085), (1.62, 1.62, 0.05), False, (), "prop")
    batch.box(cr, "clock_face", (gx, cy, gz + 0.12), (1.42, 1.42, 0.03), False, (), "prop")
    for k in range(12):                                                   # 시각 눈금
        import math
        a = math.radians(30.0 * k)
        batch.box(cr, "clock_rim", (gx + 0.6 * math.sin(a), cy + 0.6 * math.cos(a), gz + 0.14), (0.07, 0.07, 0.012), False, (), "prop")
    for theta, length, thick in ((132.5, 0.36, 0.07), (150.0, 0.56, 0.045)):   # 4시 25분에 멈춘 시계
        import math
        a = math.radians(theta)
        cxh, cyh = gx + math.sin(a) * length / 2, cy + math.cos(a) * length / 2
        batch.box(cr, "metal_dark", (cxh, cyh, gz + 0.15), (thick, length, 0.014), False, (), "prop", slope_rows("x", -theta))
    wlabel(sw, cr, gx, gy + 1.0, gz + 0.075, SCHOOL_NAME, 0.0085, 64, (0.24, 0.26, 0.32))
    # 별관: 동쪽 외벽의 두 출입문 위
    a1 = plans[("annex", "1F")]
    ca = a1.path + "/Props"
    _plate(batch, sw, ca, a1.y + 3.42, (a1.footprint.x1, 23.31), "z", 3.0, "별관 · 급식실", size=0.0038, font=48)
    _plate(batch, sw, ca, a1.y + 3.42, (a1.footprint.x1, -26.31), "z", 2.6, "급식 반입구", mat="sign_board", size=0.0036, font=44,
           color=(0.2, 0.14, 0.08))
    # 강당: 동쪽 측면 출입문 위
    g1 = plans[("gym", "1F")]
    cg = g1.path + "/Props"
    _plate(batch, sw, cg, g1.y + 3.42, (g1.footprint.x1, g1.footprint.z0 + 12.0), "z", 2.6, "강당 · 동측 출입구", size=0.0034, font=44)
