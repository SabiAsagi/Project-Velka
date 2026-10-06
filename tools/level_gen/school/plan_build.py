# -*- coding: utf-8 -*-
"""건물별 평면 계획 만들기: 블록아웃 + 레퍼런스 대조 보정 + 문 종류/방향 결정."""
from geometry import Rect, rect_of_box
from source import load_buildings, BUILDINGS, FLOOR_H, to_world
from classify import classify, level_index
from plan import GYM_Z0, GYM_Z1
from plan import (LevelPlan, Region, Door, Opening, normalize, Grid, FOOTPRINTS, boundary_type, style_of,
                  PART_T, FACADE_T, INNER_T, WALL_H)

KIND_OF = {"corridor": "corridor", "stair_zone": "stair", "elevator_zone": "elevator", "room": "room"}


def W(building, x0, z0, x1, z1):
    """건물 로컬 사각형 -> 월드 Rect"""
    a, _ = to_world(building, (x0, 0, z0), (0, 0, 0))
    b, _ = to_world(building, (x1, 0, z1), (0, 0, 0))
    return Rect(a[0], a[2], b[0], b[2])


def WP(building, x, z):
    p, _ = to_world(building, (x, 0, z), (0, 0, 0))
    return p[0], p[2]


def blockout_plans():
    plans = {}
    for b in load_buildings():
        key = (b.building, b.level)
        if key not in plans:
            plans[key] = LevelPlan(b.building, b.level, level_index(b))
        lv = plans[key]
        c = classify(b)
        if b.building == "gym" or (b.building == "main" and b.level == "Roof"):
            lv.markers.append(b)   # 강당·옥상은 직접 계획한다 (특수 박스 참고용)
            continue
        if c in KIND_OF:
            kind = KIND_OF[c]
            if kind == "room":
                st = style_of(b.name, "room")
                kind = "alcove" if st == "alcove" else ("lobby" if st == "lobby" else "room")
            lv.add(Region(b.name, kind, rect_of_box(b)))
        elif c in ("door", "entrance"):
            lv.markers.append(b)
    return plans


# ------------------------------------------------------------------ 문 표식 -> 문

def marker_axis(m):
    return "x" if m.size[0] >= m.size[2] else "z"


def merged_markers(markers):
    """같은 벽에서 겹치는 문 표식(급식실 양문 등)은 하나로 합친다."""
    out = []
    for m in sorted(markers, key=lambda m: (marker_axis(m), round(m.center[2] if marker_axis(m) == "x" else m.center[0], 2),
                                            m.center[0] if marker_axis(m) == "x" else m.center[2])):
        ax = marker_axis(m)
        a = m.center[0] if ax == "x" else m.center[2]
        f = m.center[2] if ax == "x" else m.center[0]
        w = max(m.size[0], m.size[2])
        if out:
            pax, pf, pa0, pa1, pm = out[-1]
            if pax == ax and abs(pf - f) < 0.2 and a - w / 2 < pa1 - 0.05:
                out[-1] = (ax, pf, min(pa0, a - w / 2), max(pa1, a + w / 2), pm + [m])
                continue
        out.append((ax, f, a - w / 2, a + w / 2, [m]))
    return out


def sides_of(plan, axis, fixed, a):
    """벽선 양쪽 구역 (음의 쪽, 양의 쪽)"""
    g = plan.grid
    if axis == "x":
        return g.region_at(a, fixed - 0.2), g.region_at(a, fixed + 0.2)
    return g.region_at(fixed - 0.2, a), g.region_at(fixed + 0.2, a)


def snap_boundary(plan, axis, fixed, a):
    """표식 위치 근처의 실제 구역 경계선 좌표"""
    g = plan.grid
    lines = g.zs if axis == "x" else g.xs
    best = min(lines, key=lambda v: abs(v - fixed))
    return best if abs(best - fixed) < 0.6 else fixed


DOOR_KIND = {
    "classroom": "sliding", "study": "sliding", "club": "sliding", "office": "sliding", "admin": "sliding",
    "principal": "sliding", "nurse": "sliding_wide", "broadcast": "thick", "guard": "sliding", "council": "sliding",
    "toilet": "opaque", "changing": "opaque", "closet": "opaque", "old_library": "sliding", "archive": "metal",
    "storage": "metal", "boiler": "metal", "electric": "metal", "facility": "metal", "pump": "metal", "waste": "metal",
    "shop": "sliding", "cafeteria": "glass2", "food_storage": "metal", "kitchen": "metal", "wash": "metal", "staff": "opaque",
    "prep_music": "sliding", "prep_art": "sliding", "prep_science": "sliding", "prep_computer": "sliding", "music": "thick",
    "art": "sliding", "science": "sliding", "computer": "sliding", "book_work": "sliding", "stacks": "metal",
    "copy": "sliding", "group_study": "sliding", "library": "sliding", "props_room": "metal", "sound_room": "metal",
    "elevator": "elevator", "room": "sliding",
}
DOOR_WIDTH = {"sliding": 1.1, "sliding_wide": 1.5, "opaque": 0.9, "metal": 1.0, "thick": 1.0, "glass2": 1.8,
              "glass_entry": 1.8, "fire2": 1.8, "elevator": 1.1}
LOCKED = ("보일러실", "전기실", "소방펌프", "교장실", "경비실", "매점 창고", "관리실", "음향·조명", "기록 보관실",
          "공동 과학 준비실", "보존서고")


def plate_of(room):
    n = room.name
    if n.endswith(" 교실"):
        return n.replace(" 교실", "")
    return n


def doors_from_markers(plan):
    for ax, fixed, a0, a1, ms in merged_markers(plan.markers):
        center = (a0 + a1) / 2
        fixed = snap_boundary(plan, ax, fixed, center)
        neg, pos = sides_of(plan, ax, fixed, center)
        if neg is None and pos is None:
            continue
        if neg is None or pos is None:
            inner = neg or pos
            plan.doors.append(Door("glass_entry", ax, fixed, center, 1.8, name="Entrance", room=inner.name,
                                   side_glass=max(0.0, ((a1 - a0) - 1.9) / 2), height=2.4, canopy=True,
                                   swing_toward=1 if pos is None else -1))
            continue
        if boundary_type(neg, pos) == "open":
            continue
        # 문이 속한 방: 복도·홀이 아닌 쪽. 둘 다 방이면 작은 방 (조리실 안쪽 세척실 등)
        public = ("corridor", "hall", "passage", "lobby", "stair", "court", "bridge", "stair_hall")
        if neg.kind in public and pos.kind not in public:
            room = pos
        elif pos.kind in public and neg.kind not in public:
            room = neg
        else:
            room = min((neg, pos), key=lambda r: r.rect.w * r.rect.d)
        kind = DOOR_KIND.get(room.style, "sliding")
        width = DOOR_WIDTH[kind]
        if a1 - a0 > 1.6 and kind in ("sliding", "glass2"):
            kind, width = "glass2", 1.8
        toward_room = 1 if room is pos else -1
        plan.doors.append(Door(kind, ax, fixed, center, width, name="Door", room=room.name, plate=plate_of(room),
                               locked=any(k in room.name for k in LOCKED), swing_toward=toward_room))


# ------------------------------------------------------------------ 본관

MAIN_CORR = (-4.005, -1.24)       # 본관 복도 (로컬 z)


def drop_markers(plan, *names):
    plan.markers = [m for m in plan.markers if not any(n in m.path for n in names)]


def main_overrides(plans):
    f1 = plans[("main", "1F")]
    f1.add(Region("서측 현관 통로", "passage", W("main", -30.0, MAIN_CORR[1], -26.087, 9.25)))
    f1.add(Region("동측 현관 통로", "passage", W("main", 26.087, MAIN_CORR[1], 30.0, 9.25)))
    drop_markers(f1, "InternalSouthDoors/중앙 로비", "NorthRearEntrance")
    f1.special.add("lobby_opening")
    f1.special.add("rear_door")
    f2 = plans[("main", "2F")]
    f2.special.add("skybridge_west")
    f3 = plans[("main", "3F")]
    f3.special.add("anomaly_east")


def main_after_grid(plans):
    """격자가 생긴 뒤 좌표가 확정된 경계에 문·구멍을 붙인다."""
    f1 = plans[("main", "1F")]
    lobby = [r for r in f1.regions if r.kind == "lobby"][0]
    x0, _ = WP("main", -0.5, 0)
    x1, _ = WP("main", 4.5, 0)
    f1.openings.append(Opening("x", lobby.rect.z0, x0, x1))
    stair = f1.by_name("중앙 계단")[0]
    f1.doors.append(Door("glass_entry", "x", f1.footprint.z0, stair.rect.cx, 1.8, name="RearEntrance", room=stair.name,
                         side_glass=0.0, height=2.3, canopy=True, swing_toward=-1))
    for d in plans[("main", "B1")].doors:
        if d.room == "구 도서관":
            d.notice = "침수 피해로 폐쇄 · 도서관은 별관 3층으로 이전"
    f2 = plans[("main", "2F")]
    c = f2.corridor()
    f2.doors.append(Door("fire2", "z", f2.footprint.x0, c.cz, 1.8, name="BridgeFireDoor", room=f2.first("corridor").name,
                         height=2.2, start_open=True, swing_toward=1))
    f3 = plans[("main", "3F")]
    c = f3.corridor()
    f3.openings.append(Opening("z", f3.footprint.x1, c.z0, c.z1, filler_groups=("real_only",)))
    f3.no_outer_sill = {("z", round(f3.footprint.x1, 3))}
    f3.extension = anomaly_extension(f3)


def anomaly_extension(f3):
    """이계에서만 나타나는 3층 동쪽 연장: 복도가 늘어나고 2-6 옆에 2-7 교실이 붙는다 (2-6과는 벽으로 막힘)."""
    c = f3.corridor()
    east = f3.footprint.x1
    ext = LevelPlan("main", "3F", f3.index)
    ext.footprint = Rect(east, c.z0 - 0.175, east + 8.15, f3.footprint.z1)
    g = ("otherworld_only",)
    ext.add(Region("복도", "corridor", Rect(east, c.z0 - 0.175, east + 8.15, c.z1), groups=g, tags={"fixed"}))
    room = ext.add(Region("2-7 교실", "room", Rect(east, c.z1, east + 8.15, f3.footprint.z1), groups=g, tags={"fixed"},
                          display="2-7 교실"))
    ext.openings.append(Opening("z", east, c.z0, c.z1))
    y_face = east + FACADE_T + INNER_T
    for cx in (y_face + 0.91, east + 8.15 - FACADE_T - INNER_T - 0.75):
        ext.doors.append(Door("sliding", "x", c.z1, cx, 1.1, name="Door", room=room.name, plate="2-7", swing_toward=1, groups=g))
    ext.groups = g
    ext.no_window_lines = {("z", round(east, 3))}
    return ext


# ------------------------------------------------------------------ 별관 (로컬 x: 도면 좌->우 = 월드 북->남 반대, 로컬 z: 도면 위->아래 = 월드 서->동)

def annex_overrides(plans):
    f1 = plans[("annex", "1F")]
    f1.add(Region("서측 학생 출입 통로", "passage", W("annex", -26.0, -1.173, -23.739, 8.75)))
    f1.add(Region("동측 반입 통로", "passage", W("annex", 23.739, -1.173, 26.0, 8.75)))
    f1.markers = [m for m in f1.markers if not (m.path.endswith("급식실-조리실 연결문") or m.path.endswith("SupportDoors/매점")
                                                or m.path.endswith("SupportDoors/매점 창고"))]
    for lname in ("1F", "2F", "3F"):
        plans[("annex", lname)].special.add("annex")
    plans[("annex", "3F")].special.add("skybridge_north")


def annex_door(plan, kind, local_x, local_z, width, room, axis_local, **kw):
    """별관 로컬 좌표로 문 추가. axis_local: 로컬에서 벽이 뻗는 축 ('x' 또는 'z')."""
    wx, wz = WP("annex", local_x, local_z)
    # 로컬 x축 벽 -> 월드 z축 벽 (90도 회전)
    if axis_local == "x":
        plan.doors.append(Door(kind, "z", wx, wz, width, room=room, **kw))
    else:
        plan.doors.append(Door(kind, "x", wz, wx, width, room=room, **kw))


def annex_after_grid(plans):
    f1 = plans[("annex", "1F")]
    kitchen = f1.by_name("조리실")[0]
    caf = f1.by_name("급식실")[0]
    # 급식실-조리실 벽: 배식구·반납구(허리 높이 창)와 직원 출입문
    wall_x = caf.rect.z0 if abs(caf.rect.z0 - kitchen.rect.z1) < 0.05 else caf.rect.z1
    for z0, z1 in ((-0.45, 3.4), (5.6, 7.6)):
        a0, _ = WP("annex", 10.174, z0)
        a1, _ = WP("annex", 10.174, z1)
        f1.openings.append(Opening("x", wall_x, min(a0, a1), max(a0, a1), 0.95, 2.05))
    annex_door(f1, "metal", 10.174, 4.3, 1.0, "조리실", "z", plate="조리실", swing_toward=0)
    # 식품 창고: 조리실 쪽 문, 반입 통로 쪽 문
    annex_door(f1, "metal", 20.348, 2.2, 1.0, "조리 식품 창고", "z", plate="식품 창고")
    annex_door(f1, "metal", 23.739, 6.2, 1.2, "조리 식품 창고", "z", plate="식품 반입")
    # 매점: 복도 쪽 판매창과 출입문
    shop = f1.by_name("매점")[0]
    fixed = shop.rect.x1 if abs(shop.rect.x1 - f1.corridor().x0) < 0.3 else shop.rect.x0
    zz0, zz1 = sorted((WP("annex", 11.9, -3.9)[1], WP("annex", 14.6, -3.9)[1]))
    f1.openings.append(Opening("z", fixed, zz0, zz1, 0.9, 2.0))
    annex_door(f1, "metal", 15.55, -3.9, 0.9, "매점", "x", plate="매점 (직원)")
    # 매점 창고 문은 계단 쪽으로 붙여 창고 앞 벽면에 자판기 2대 자리를 만든다
    annex_door(f1, "metal", 20.0, -3.9, 1.0, "매점 창고", "x", plate="매점 창고", locked=True)
    annex_door(f1, "glass2", -23.739, 3.8, 1.8, "급식실", "z", plate="급식실")
    # 영양교사실-급식행정실 내부 연결문, 매점-매점 창고 직원용 내부문 (학교_맵_상세.md 별관 1층)
    annex_door(f1, "sliding", -16.2, -6.9, 0.9, "영양교사실", "z")
    annex_door(f1, "metal", 16.35, -7.2, 0.9, "매점 창고", "z")
    f2 = plans[("annex", "2F")]
    annex_door(f2, "sliding", 14.5, -1.1, 1.1, "제2과학실", "x", plate="제2과학실")
    f3 = plans[("annex", "3F")]
    for lx in (-18.6, -13.7):
        annex_door(f3, "sliding", lx, -1.1, 1.1, "도서관", "x", plate="도서관")
    annex_door(f3, "sliding", 16.0, 5.0, 1.1, "그룹학습실", "z", plate="")
    # 그룹학습실의 도서관 쪽 벽은 유리 (문과 미닫이 이동 구간은 피해서 고정 유리 4장)
    lib = f3.by_name("도서관")[0]
    grp = f3.by_name("그룹학습실")[0]
    wall_z = lib.rect.z0 if abs(lib.rect.z0 - grp.rect.z1) < 0.05 else lib.rect.z1
    x_in = lib.rect.x0 + PART_T / 2
    for v0, v1 in ((0.45, 2.1), (2.3, 3.95), (6.9, 8.0), (8.2, 9.2)):
        f3.openings.append(Opening("x", wall_z, x_in + v0, x_in + v1, 0.45, 2.45, glass="glass"))
    c = f3.corridor()
    # 구름다리 도착부: 평소 열려 있는 양개 방화문 (종이 울리면 닫혀 고립 구간이 된다)
    f3.doors.append(Door("fire2", "x", f3.footprint.z0, c.cx, 1.8, name="BridgeFireDoor", room=f3.first("corridor").name,
                         height=2.2, start_open=True, swing_toward=1))


def fix_door_axes(plan):
    """annex_door로 넣은 문의 고정 좌표를 실제 경계선에 맞춘다."""
    for d in plan.doors:
        d.fixed = snap_boundary(plan, d.axis, d.fixed, d.center)


# ------------------------------------------------------------------ 강당 (u: 서->동 0~40, s: 남쪽 무대 0 -> 북쪽 주출입구 26)

STAGE_H = 1.1          # 무대 높이
GYM_REAR = 1.2         # 2층 뒤쪽 통로 높이 (층 바닥 3.8 기준 +1.2 = 5.0)
GYM_WALL_TOP = 10.8    # 강당 2층 벽 윗면 (지붕 슬래브 아래면)
GYM_N = 21.2           # 코트 북쪽 끝 (북측 서비스 띠 시작)


def G(u0, s0, u1, s1):
    return Rect(u0 - 20.0, GYM_Z1 - s1, u1 - 20.0, GYM_Z1 - s0)


def GP(u, s):
    return u - 20.0, GYM_Z1 - s


def gym_plans(plans):
    f1 = LevelPlan("gym", "1F", 0)
    f2 = LevelPlan("gym", "2F", 1)
    fixed = {"fixed"}
    for name, kind, (u0, s0, u1, s1), kw in [
        ("소품·의상 준비실", "room", (0, 0, 4.67, 6.14), {}),
        ("무대", "stage", (4.67, 0, 35.33, 3.2), {"floor_dy": STAGE_H}),
        ("무대", "stage", (7.67, 3.2, 32.33, 6.14), {"floor_dy": STAGE_H}),
        ("무대 서측 계단", "stage_stair", (4.67, 3.2, 7.67, 6.14), {"no_floor": True}),
        ("무대 동측 계단", "stage_stair", (32.33, 3.2, 35.33, 6.14), {"no_floor": True}),
        ("음향·조명·무대장치실", "room", (35.33, 0, 40, 6.14), {}),
        ("마룻바닥", "court", (0, 6.14, 40, GYM_N), {}),
        ("체육기구 창고", "room", (0, GYM_N, 9.33, 26), {}),
        ("서측 내부 계단", "stair", (9.33, GYM_N, 14.0, 23.7), {"no_floor": True}),
        ("서측 화장실", "room", (9.33, 23.7, 14.67, 26), {}),
        ("북측 주출입홀", "hall", (14.67, GYM_N, 25.33, 26), {}),
        ("북측 주출입홀", "hall", (14.0, GYM_N, 14.67, 23.7), {}),
        ("북측 주출입홀", "hall", (25.33, GYM_N, 26.0, 23.7), {}),
        ("동측 내부 계단", "stair", (26.0, GYM_N, 30.67, 23.7), {"no_floor": True}),
        ("동측 화장실", "room", (25.33, 23.7, 30.67, 26), {}),
        ("행사물품 창고", "room", (30.67, GYM_N, 36.67, 26), {}),
        ("강당 관리실", "room", (36.67, GYM_N, 40, 26), {}),
    ]:
        f1.add(Region(name, kind, G(u0, s0, u1, s1), tags=fixed, **kw))
    for name, kind, (u0, s0, u1, s1), kw in [
        ("서측 관람석", "seating", (0, 6.14, 8, 26), {"no_floor": True}),
        ("북측 관람석", "seating", (8, 18.2, 32, 26), {"no_floor": True}),
        ("동측 관람석", "seating", (32, 6.14, 40, 26), {"no_floor": True}),
        ("코트 상부", "void", (8, 6.14, 32, 18.2), {"no_floor": True}),
        ("무대 상부", "stage_upper", (4.67, 0, 35.33, 6.14), {"no_floor": True}),
        ("소품실 상부", "void_room", (0, 0, 4.67, 6.14), {"no_floor": True}),
        ("장치실 상부", "void_room", (35.33, 0, 40, 6.14), {"no_floor": True}),
    ]:
        f2.add(Region(name, kind, G(u0, s0, u1, s1), tags=fixed, **kw))
    f2.wall_top = GYM_WALL_TOP
    f2.special.add("gym_upper")
    f1.special.add("gym")
    plans[("gym", "1F")] = f1
    plans[("gym", "2F")] = f2


def gym_doors(plans):
    f1, f2 = plans[("gym", "1F")], plans[("gym", "2F")]

    def door(plan, kind, axis, u_or_s_fixed, center, width, room, **kw):
        # axis 'x': 벽이 u방향 (s 고정) / 'z': 벽이 s방향 (u 고정)
        if axis == "x":
            _, fz = GP(0, u_or_s_fixed)
            cx, _ = GP(center, 0)
            plan.doors.append(Door(kind, "x", fz, cx, width, room=room, **kw))
        else:
            fx, _ = GP(u_or_s_fixed, 0)
            _, cz = GP(0, center)
            plan.doors.append(Door(kind, "z", fx, cz, width, room=room, **kw))

    door(f1, "glass_entry", "x", 26.0, 20.0, 2.4, "북측 주출입홀", side_glass=1.2, height=2.4, canopy=True, swing_toward=-1,
         name="NorthMainEntrance")
    for u in (17.5, 22.5):
        door(f1, "fire2", "x", GYM_N, u, 1.8, "북측 주출입홀", height=2.2, swing_toward=-1, name="FireDoor")
    door(f1, "opaque", "z", 14.67, 24.85, 0.9, "서측 화장실", plate="남자 화장실", swing_toward=-1)
    door(f1, "opaque", "z", 25.33, 24.85, 0.9, "동측 화장실", plate="여자 화장실", swing_toward=1)
    door(f1, "fire2", "x", GYM_N, 5.33, 2.4, "체육기구 창고", height=2.4, plate="체육기구 창고", swing_toward=-1)
    door(f1, "fire2", "x", GYM_N, 33.67, 2.0, "행사물품 창고", height=2.4, plate="행사물품 창고", swing_toward=-1)
    door(f1, "metal", "x", GYM_N, 38.4, 0.9, "강당 관리실", plate="관리실", locked=True, swing_toward=-1)
    door(f1, "glass_entry", "z", 0.0, 14.0, 1.8, "마룻바닥", side_glass=0.4, height=2.4, canopy=True, swing_toward=-1,
         name="WestEntrance")
    door(f1, "glass_entry", "z", 40.0, 14.0, 1.8, "마룻바닥", side_glass=0.4, height=2.4, canopy=True, swing_toward=1,
         name="EastEntrance")
    door(f1, "metal", "x", 6.14, 2.8, 0.9, "소품·의상 준비실", plate="소품·의상 준비실", swing_toward=1)
    door(f1, "metal", "x", 6.14, 37.2, 0.9, "음향·조명·무대장치실", plate="음향·조명실", locked=True, swing_toward=1)
    door(f1, "metal", "z", 4.67, 1.1, 0.9, "소품·의상 준비실", floor_dy=STAGE_H, swing_toward=-1, name="StageSideDoor")
    door(f1, "metal", "z", 35.33, 1.1, 0.9, "음향·조명·무대장치실", floor_dy=STAGE_H, swing_toward=1, name="StageSideDoor",
         locked=True)
    # 2층 비상구: 양 날개 뒤쪽 통로(+1.2) 남쪽 끝에서 외부 비상계단으로
    door(f2, "metal", "z", 0.0, 7.8, 1.0, "서측 관람석", floor_dy=GYM_REAR, plate="비상구", swing_toward=-1, name="EmergencyExit")
    door(f2, "metal", "z", 40.0, 7.8, 1.0, "동측 관람석", floor_dy=GYM_REAR, plate="비상구", swing_toward=1, name="EmergencyExit")
    # 무대 상부 경계: 코트에서 무대가 보이도록 아래쪽 크게 뚫린 무대 입구(프로시니엄)
    _, fz = GP(0, 6.14)
    x0, _ = GP(8.0, 0)
    x1, _ = GP(32.0, 0)
    f2.openings.append(Opening("x", fz, x0, x1, -0.2, 3.2))


# ------------------------------------------------------------------ 옥상 층

def roof_plans(plans):
    main_roof = LevelPlan("main", "Roof", 5)
    main_roof.add(Region("옥상", "roof", FOOTPRINTS["main"], tags={"fixed"}))
    main_roof.add(Region("옥상 출입실", "roof_room", W("main", -2.2, -9.25, 6.3, -2.9), tags={"fixed"}))
    main_roof.exterior = "parapet"
    main_roof.wall_top = main_roof.y + 3.0
    main_roof.windows = False
    main_roof.special.add("roof_main")
    plans[("main", "Roof")] = main_roof
    annex_roof = LevelPlan("annex", "Roof", 3)
    annex_roof.add(Region("옥상", "roof", FOOTPRINTS["annex"], tags={"fixed"}))
    annex_roof.exterior = "parapet"
    annex_roof.windows = False
    plans[("annex", "Roof")] = annex_roof
    gym_roof = LevelPlan("gym", "Roof", 2)
    gym_roof.y = GYM_WALL_TOP + 0.2
    gym_roof.add(Region("지붕", "roof", FOOTPRINTS["gym"], tags={"fixed"}))
    gym_roof.exterior = "parapet"
    gym_roof.parapet_h = 0.6
    gym_roof.windows = False
    plans[("gym", "Roof")] = gym_roof


def roof_doors(plans):
    roof = plans[("main", "Roof")]
    room = roof.by_name("옥상 출입실")[0]
    cx = room.rect.cx
    roof.doors.append(Door("metal", "x", room.rect.z1, cx, 1.0, name="RoofDoor", room=room.name, locked=True,
                           notice="시설 점검으로 임시 폐쇄", locked_line="'시설 점검으로 임시 폐쇄' 안내문이 붙어 있다. 잠겨 있다.",
                           swing_toward=1))


# ------------------------------------------------------------------ 문 세부 (문짝 쪽, 미닫이 방향, 경첩)

def wall_runs_on_line(plan, axis, fixed):
    """한 선 위에서 벽이 이어진 구간들 [(a0, a1)]"""
    runs = []
    for ax, f, a0, a1, lo, hi in plan.grid.boundaries():
        if ax != axis or abs(f - fixed) > 1e-3:
            continue
        ra = plan.regions[lo] if lo >= 0 else None
        rb = plan.regions[hi] if hi >= 0 else None
        if boundary_type(ra, rb) in ("wall", "exterior"):
            runs.append((a0, a1))
    runs.sort()
    merged = []
    for a0, a1 in runs:
        if merged and a0 <= merged[-1][1] + 1e-3:
            merged[-1] = (merged[-1][0], max(merged[-1][1], a1))
        else:
            merged.append((a0, a1))
    return merged


def fit_door(plan, d):
    """문 구멍이 방의 벽 구간 안에 들어오게 중심을 옮기고, 모자라면 옆 유리·문 폭을 줄인다."""
    rooms = plan.by_name(d.room)
    if not rooms:
        return
    fp = plan.footprint
    best = None
    for r in rooms:
        a0, a1 = (r.rect.x0, r.rect.x1) if d.axis == "x" else (r.rect.z0, r.rect.z1)
        if a0 - 0.05 <= d.center <= a1 + 0.05:
            best = (a0, a1)
    if best is None:
        return
    a0, a1 = best
    e0 = fp.x0 if d.axis == "x" else fp.z0
    e1 = fp.x1 if d.axis == "x" else fp.z1
    lo = a0 + (FACADE_T + INNER_T if abs(a0 - e0) < 1e-3 else PART_T / 2) + 0.1
    hi = a1 - (FACADE_T + INNER_T if abs(a1 - e1) < 1e-3 else PART_T / 2) - 0.1
    room_len = hi - lo
    need = d.width + 0.08 + 2 * d.side_glass
    if need > room_len:
        d.side_glass = max(0.0, (room_len - d.width - 0.08) / 2)
        if d.side_glass < 0.2:
            d.side_glass = 0.0
        need = d.width + 0.08 + 2 * d.side_glass
        if need > room_len:
            d.width = max(0.85, room_len - 0.08)
            need = d.width + 0.08
    half = need / 2
    d.center = min(max(d.center, lo + half), hi - half)


def door_details(plan):
    for d in plan.doors:
        fit_door(plan, d)
    by_line = {}
    for d in plan.doors:
        by_line.setdefault((d.axis, round(d.fixed, 3)), []).append(d)
    for d in plan.doors:
        runs = wall_runs_on_line(plan, d.axis, d.fixed)
        run = next(((a0, a1) for a0, a1 in runs if a0 - 0.05 <= d.center <= a1 + 0.05), (d.center - 3, d.center + 3))
        h0, h1 = d.hole
        others = [o.hole for o in by_line[(d.axis, round(d.fixed, 3))] if o is not d]
        lim_lo = max([run[0] + 0.12] + [b for a, b in others if b <= h0 + 1e-3])
        lim_hi = min([run[1] - 0.12] + [a for a, b in others if a >= h1 - 1e-3])
        free_lo, free_hi = h0 - lim_lo, lim_hi - h1
        world_dir = 1 if free_hi >= free_lo else -1
        # 로컬 x: 'x'벽은 월드 +x, 'z'벽은 월드 -z
        d.slide_local = world_dir if d.axis == "x" else -world_dir
        d.slide_room = max(free_lo, free_hi)
        hinge_world = -1 if (d.center - run[0]) < (run[1] - d.center) else 1
        d.hinge_local = hinge_world if d.axis == "x" else -hinge_world
        if d.swing_toward == 0:
            neg, pos = sides_of(plan, d.axis, d.fixed, d.center)
            d.swing_toward = 1 if (pos is not None and pos.name == d.room) else -1
        d.plate_side = -d.swing_toward


def add_missing_elevator_doors(plan):
    for r in plan.regions:
        if r.kind != "elevator" or any(d.room == r.name for d in plan.doors):
            continue
        c = plan.corridor()
        if c is None:
            continue
        if r.rect.w >= r.rect.d or abs(r.rect.z1 - c.z0) < 0.05 or abs(r.rect.z0 - c.z1) < 0.05:
            fixed = r.rect.z1 if abs(r.rect.z1 - c.z0) < 0.05 else r.rect.z0
            plan.doors.append(Door("elevator", "x", fixed, r.rect.cx, 1.1, room=r.name, plate="엘리베이터"))
        else:
            fixed = r.rect.x1 if abs(r.rect.x1 - c.x0) < 0.05 else r.rect.x0
            plan.doors.append(Door("elevator", "z", fixed, r.rect.cz, 1.1, room=r.name, plate="엘리베이터"))


def build_plans():
    plans = blockout_plans()
    main_overrides(plans)
    annex_overrides(plans)
    gym_plans(plans)
    roof_plans(plans)
    for lv in plans.values():
        normalize(lv)
        lv.grid = Grid(lv)
    main_after_grid(plans)
    annex_after_grid(plans)
    for lv in plans.values():
        if lv.building != "gym" and lv.name != "Roof":
            doors_from_markers(lv)
    for lv in plans.values():
        add_missing_elevator_doors(lv)
    for d in plans[("annex", "1F")].doors:
        # 별관 출입 통로는 폭이 좁다: 학생 출입구는 유리 양문만, 동측 반입구는 금속 양문
        if d.kind == "glass_entry" and d.room == "동측 반입 통로":
            d.kind, d.side_glass, d.width = "fire2", 0.0, 1.6
        elif d.kind == "glass_entry" and d.room == "서측 학생 출입 통로":
            d.side_glass, d.width = 0.0, 1.6
    gym_doors(plans)
    roof_doors(plans)
    from rooms_study import CLUBS, CLUB_NAMES
    for (lname, room), kind in CLUBS.items():
        for d in plans[("main", lname)].doors:
            if d.room == room:
                d.plate = "%s (%s)" % (room.replace("일반 ", ""), CLUB_NAMES[kind])
    for lv in plans.values():
        fix_door_axes(lv)
        door_details(lv)
    ext = plans[("main", "3F")].extension
    ext.grid = Grid(ext)
    door_details(ext)
    return plans


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    ps = build_plans()
    for key in sorted(ps, key=lambda k: (k[0], ps[k].index)):
        lv = ps[key]
        gaps = lv.grid.gaps()
        print("%-6s %-5s regions=%2d doors=%2d openings=%d gaps=%d" % (key[0], key[1], len(lv.regions), len(lv.doors), len(lv.openings), len(gaps)))
        for gp in gaps[:6]:
            print("    GAP", gp)


def inner_rect(plan, region):
    """벽 두께를 뺀 방 안쪽 사각형과 변별 경계 종류. 한 변에 벽이 조금이라도 있으면 벽 두께만큼 뺀다."""
    from plan import FACADE_T, INNER_T, PART_T
    g = plan.grid
    r = region.rect
    fp = plan.footprint
    edge = {"x0": abs(r.x0 - fp.x0) < 1e-3, "x1": abs(r.x1 - fp.x1) < 1e-3, "z0": abs(r.z0 - fp.z0) < 1e-3, "z1": abs(r.z1 - fp.z1) < 1e-3}
    kinds, inset = {}, {}
    seen = {"x0": set(), "x1": set(), "z0": set(), "z1": set()}
    for ax, f, a0, a1, lo, hi in g.boundaries():
        if lo != region.id and hi != region.id:
            continue
        other = plan.regions[hi] if lo == region.id and hi >= 0 else (plan.regions[lo] if hi == region.id and lo >= 0 else None)
        if ax == "x":
            side = "z0" if abs(f - r.z0) < 1e-3 else ("z1" if abs(f - r.z1) < 1e-3 else None)
        else:
            side = "x0" if abs(f - r.x0) < 1e-3 else ("x1" if abs(f - r.x1) < 1e-3 else None)
        if side is None:
            continue
        seen[side].add("exterior" if other is None else boundary_type(region, other))
    for side in ("x0", "x1", "z0", "z1"):
        types = seen[side]
        if edge[side] or "exterior" in types:
            kinds[side], inset[side] = "exterior", FACADE_T + INNER_T
        elif "wall" in types:
            kinds[side], inset[side] = "wall", PART_T / 2
        elif "rail" in types:
            kinds[side], inset[side] = "rail", 0.05
        else:
            kinds[side], inset[side] = "open", 0.0
    return Rect(r.x0 + inset["x0"], r.z0 + inset["z0"], r.x1 - inset["x1"], r.z1 - inset["z1"]), kinds
