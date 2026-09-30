# -*- coding: utf-8 -*-
"""외부 부지: 지면, 본관 고지대(3.8m), 스탠드와 양 끝 계단/동측 경사로, 도로·보행로, 정문·후문, 경계"""
from geometry import Rect, subtract
from stairs import ramp
from source import load_exterior

MAIN_FOOTPRINT = Rect(-30.0, -63.25, 30.0, -44.75)
SITE = Rect(-107.0, -79.0, 83.0, 61.0)
PLATEAU_TOP = 3.8

PAD_COLORS = {
    "AthleticField": (0.42, 0.3, 0.22), "Road": (0.33, 0.33, 0.34), "Path": (0.4, 0.4, 0.42), "Garden": (0.27, 0.38, 0.24),
    "Court": (0.3, 0.45, 0.62), "Fitness": (0.36, 0.3, 0.3), "Forest": (0.16, 0.24, 0.15), "Parking": (0.28, 0.28, 0.3),
    "Plaza": (0.45, 0.44, 0.42), "Plot": (0.34, 0.26, 0.18), "Trail": (0.44, 0.38, 0.3),
}


def pad_color(name):
    for key in ("Court", "Fitness", "Forest", "Parking", "Plaza", "Plot", "Trail", "Garden", "Road", "Path", "AthleticField"):
        if key in name:
            return key
    return "Path"


def build_site(sw, parent, mats, zone_cb):
    ext = {b.name: b for b in load_exterior()}
    ground = mats["ground"]
    # 지면 (부지 전체, 윗면 y=0)
    sw.solid(parent, "Ground", (SITE.cx, -0.25, SITE.cz), (SITE.w + 20, 0.5, SITE.d + 20), ground, groups=["camera_solid"])
    # 본관 고지대: 건물 자리(지하 1층)와 양 끝 계단·경사로 자리를 뺀다
    pl = ext["MainPlateau"]
    plateau = Rect(pl.min[0], pl.min[2], pl.max[0], pl.max[2])
    west_stair = ext["WestEndStair"]
    east_stair, east_ramp = ext["EastEndStair"], ext["EastRamp"]
    west_notch = Rect(west_stair.min[0], west_stair.min[2], west_stair.max[0], plateau.z1)
    east_x0, east_x1 = min(east_stair.min[0], east_ramp.min[0]), max(east_stair.max[0], east_ramp.max[0])
    east_notch = Rect(east_x0, east_stair.min[2], east_x1, plateau.z1)
    for r in subtract(plateau, [MAIN_FOOTPRINT, west_notch, east_notch]):
        sw.solid(parent, "Plateau", (r.cx, PLATEAU_TOP / 2, r.cz), (r.w, PLATEAU_TOP, r.d), mats["plateau"], groups=["camera_solid"])
    # 운동장 -> 고지대 계단/경사로 (남쪽 끝 y=0, 북쪽 끝 y=3.8)
    z_low, z_high = west_stair.max[2], west_stair.min[2]
    ramp(sw, parent, "z", west_notch.x0, west_notch.x1, z_high, PLATEAU_TOP, z_low, 0.0, mats["stair"], name="WestEndStair")
    ramp(sw, parent, "z", east_x0, east_x1, z_high, PLATEAU_TOP, z_low, 0.0, mats["stair"], name="EastEndStairAndRamp")
    from stairs import stair_path
    for x0, x1, nm in ((west_notch.x0, west_notch.x1, "WestEndStairPath"), (east_x0, east_x1, "EastRampPath")):
        stair_path(sw, parent, [((x0 + x1) / 2, 0.0, z_low + 1.0), ((x0 + x1) / 2, PLATEAU_TOP, z_high - 1.0)], name=nm)
    # 고지대 남쪽 가장자리 난간 (스탠드로 뛰어내리지 못하게)
    rail_z = plateau.z1 - 0.1
    for x0, x1 in ((west_notch.x1, east_x0),):
        sw.solid(parent, "PlateauRail", ((x0 + x1) / 2, PLATEAU_TOP + 0.55, rail_z), (x1 - x0, 1.1, 0.15), mats["rail"])
    for r, lo, hi in ((plateau, plateau.x0, west_notch.x0), (plateau, east_x1, plateau.x1)):
        if hi - lo > 0.2:
            sw.solid(parent, "PlateauRail", ((lo + hi) / 2, PLATEAU_TOP + 0.55, rail_z), (hi - lo, 1.1, 0.15), mats["rail"])
    # 스탠드, 조회대, 창고
    for name in ("TierNorth", "TierUpperMiddle", "TierLowerMiddle", "TierSouth", "AssemblyPodium", "UnderStandStorage"):
        b = ext[name]
        sw.solid(parent, name, b.center, b.size, mats["stand"])
    # 평면 요소 (도로, 보행로, 운동장, 코트 등)
    flat_names = [n for n, b in ext.items() if b.size[1] <= 0.2 and n not in ("SiteFloor",)]
    for n in flat_names:
        b = ext[n]
        top = b.max[1]
        sw.pad(parent, n, (b.center[0], top - 0.01, b.center[2]), (b.size[0], 0.02, b.size[2]), mats["pad_" + pad_color(n)])
    # 세워진 구조물 (정문 기둥, 경비실, 관람 스탠드, 자전거 거치대 등)
    for n in ("RearGateWestPost", "RearGateEastPost", "BicycleRacks", "MainGateNorthPost", "MainGateSouthPost", "Guardhouse",
              "WestCourtStand", "EastCourtStand"):
        b = ext[n]
        sw.solid(parent, n, b.center, b.size, mats["stand"] if "Stand" in n else mats["plateau"])
    # 닫힌 정문/후문 (챕터 진행 중에는 나갈 수 없다)
    ng, sg = ext["MainGateNorthPost"], ext["MainGateSouthPost"]
    sw.solid(parent, "MainGateBars", (ng.center[0], 1.1, (ng.center[2] + sg.center[2]) / 2), (0.15, 2.2, abs(sg.center[2] - ng.center[2]) - 0.8), mats["metal"])
    wp, ep = ext["RearGateWestPost"], ext["RearGateEastPost"]
    sw.solid(parent, "RearGateBars", ((wp.center[0] + ep.center[0]) / 2, PLATEAU_TOP + 1.1, wp.center[2]), (abs(ep.center[0] - wp.center[0]) - 0.6, 2.2, 0.15), mats["metal"])
    # 투광등
    for x, z in ((-36.5, -24), (36.5, -24), (-36.5, 24), (36.5, 24)):
        sw.solid(parent, "FloodlightPole", (x, 6.0, z), (0.45, 12.0, 0.45), mats["metal"])
        sw.solid(parent, "FloodlightHead", (x, 12.2, z), (2.2, 1.0, 0.5), mats["metal"], collision=False)
    # 부지 경계 울타리 (정문 x=76 안쪽은 닫힌 문으로 막힘)
    for c, s in (((SITE.cx, 1.1, SITE.z0), (SITE.w, 2.2, 0.2)), ((SITE.cx, 1.1, SITE.z1), (SITE.w, 2.2, 0.2)),
                 ((SITE.x0, 1.1, SITE.cz), (0.2, 2.2, SITE.d)), ((SITE.x1, 1.1, SITE.cz), (0.2, 2.2, SITE.d))):
        sw.solid(parent, "Fence", c, s, mats["fence"])
    # 정문 양옆 울타리: 정문 기둥 선(x=76)에서 부지 경계까지 막는다
    gate_x = ng.center[0]
    for z0, z1 in ((SITE.z0, ng.min[2]), (sg.max[2], SITE.z1)):
        sw.solid(parent, "GateFence", (gate_x, 1.1, (z0 + z1) / 2), (0.2, 2.2, z1 - z0), mats["fence"])
    # 외부 구역
    zone_cb("site_field", "운동장", Rect(-35, -22.5, 35, 22.5), 0.0, 4.0)
    zone_cb("site_gate", "정문 진입광장", Rect(56, -20, 83, 0), 0.0, 4.0)
    zone_cb("site_front_path", "본관 앞 보행로", Rect(-40, -43.2, 40, -39.2), PLATEAU_TOP, 4.0)
    zone_cb("site_rear", "후문 주차장", Rect(-38, -74, 44, -65), PLATEAU_TOP, 4.0)
    zone_cb("site_east_path", "동측 보행로", Rect(47.9, -28, 53.5, 27), 0.0, 4.0)
    zone_cb("site_gym_path", "강당 앞 보행로", Rect(-22, 28.5, 22, 33), 0.0, 4.0)
    zone_cb("site_annex_road", "별관 동측 도로", Rect(-56.5, -28, -51.5, 27), 0.0, 4.0)
    zone_cb("site_courts_w", "서측 농구장", Rect(-58.7, 33, -28.6, 46), 0.0, 4.0)
    zone_cb("site_courts_e", "동측 농구장", Rect(28.6, 33, 58.7, 46), 0.0, 4.0)
    zone_cb("site_trail", "서측 휴게 정원", Rect(-93, -30, -81, 28), 0.0, 4.0)
