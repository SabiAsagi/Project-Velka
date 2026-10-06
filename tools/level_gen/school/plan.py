# -*- coding: utf-8 -*-
"""층별 평면 계획 (생성기 v2).

블록아웃(레퍼런스 정렬)에서 방·복도·계단 사각형과 문 표식을 읽고,
- 가까운 모서리를 맞붙여 방들이 틈·겹침 없이 건물 평면을 채우게 정리하고 (normalize)
- 좌표 압축 격자에 방 번호를 칠해 (Grid) 경계에서 벽을 유도할 수 있게 한다.
문 종류, 열린 경계(복도-계단 등), 창문 종류, 특수 구조(강당·옥상·이계 교실)는 plan_build.py에서 정한다.
"""
from geometry import Rect
from source import FLOOR_H

SLAB = 0.2          # 층 슬래브 두께 (벽은 바닥 위 3.6m, 다음 층 슬래브 아래면까지)
WALL_H = FLOOR_H - SLAB
FACADE_T = 0.15     # 외벽 바깥 마감 두께 (슬래브 가장자리를 덮는다)
INNER_T = 0.10      # 외벽 안쪽 마감 두께
PART_T = 0.15       # 칸막이 벽 두께 (양면 0.075씩)
SNAP = 0.36         # 이 거리 안의 모서리는 한 선으로 맞춘다

# 강당 위치: 운동장 남쪽 끝(z = 22.5)에서 약 8m 떨어뜨린다 (학교_맵_상세.md "강당은 운동장 남측에서 약 8m").
# 외부 블록아웃의 강당 측면 출입구 매트(z 중심 43.26)·북측 출입구 매트(z 31.2)와도 이 위치에서 맞는다.
GYM_Z0, GYM_Z1 = 31.25, 57.25
FOOTPRINTS = {"main": Rect(-30.0, -63.25, 30.0, -44.75), "annex": Rect(-68.75, -27.5, -51.25, 24.5),
              "gym": Rect(-20.0, GYM_Z0, 20.0, GYM_Z1)}


class Region:
    """방·복도 등 바닥을 가진 평면 구역 (월드 좌표 사각형)"""

    def __init__(self, name, kind, rect, **kw):
        self.name, self.kind, self.rect = name, kind, rect
        self.style = kw.get("style") or style_of(name, kind)
        self.floor_dy = kw.get("floor_dy", 0.0)       # 층 바닥 기준 높이 차 (무대 등)
        self.no_floor = kw.get("no_floor", False)     # 바닥 없음 (강당 2층 가운데 빈 공간)
        self.groups = tuple(kw.get("groups", ()))     # real_only / otherworld_only
        self.tags = set(kw.get("tags", ()))
        self.display = kw.get("display", "")          # 구역 표시 이름 (비우면 자동)
        self.id = -1

    def __repr__(self):
        return "Region(%s %s %s)" % (self.kind, self.name, self.rect)


class Door:
    """벽 경계의 문. axis='x'면 벽이 x방향으로 뻗고(z=fixed), 'z'면 z방향(x=fixed)."""

    def __init__(self, kind, axis, fixed, center, width, **kw):
        self.kind, self.axis, self.fixed, self.center, self.width = kind, axis, fixed, center, width
        self.height = kw.get("height", 2.1)
        self.name = kw.get("name", "Door")
        self.room = kw.get("room", "")
        self.plate = kw.get("plate", "")
        self.notice = kw.get("notice", "")
        self.locked = kw.get("locked", False)
        self.locked_line = kw.get("locked_line", "")
        self.start_open = kw.get("start_open", False)
        self.side_glass = kw.get("side_glass", 0.0)     # 현관: 양옆 고정 유리 폭
        self.swing_toward = kw.get("swing_toward", 0)   # 여닫이가 열리는 쪽 (+1: +축 쪽, -1: -축 쪽)
        self.slide_dir = kw.get("slide_dir", 0)         # 미닫이 이동 방향 (0이면 자동)
        self.floor_dy = kw.get("floor_dy", 0.0)
        self.groups = tuple(kw.get("groups", ()))
        self.canopy = kw.get("canopy", False)
        self.wall_t = PART_T

    @property
    def hole(self):
        """벽 구멍 (a0, a1): 통과 폭 + 문틀 + 옆 유리"""
        half = self.width / 2 + 0.04 + self.side_glass
        return self.center - half, self.center + half


class Opening:
    """문 없이 뚫린 벽 구간. y0~y1은 층 바닥 기준 (None이면 벽 전체 높이)"""

    def __init__(self, axis, fixed, a0, a1, y0=None, y1=None, filler_groups=(), glass=""):
        self.axis, self.fixed, self.a0, self.a1, self.y0, self.y1 = axis, fixed, a0, a1, y0, y1
        self.filler_groups = tuple(filler_groups)   # 구멍을 이 그룹 전용 벽으로 채운다 (현실에만 있는 막힌 벽)
        self.glass = glass                          # 구멍을 고정 유리로 채운다 (유리 칸막이): "glass" / "glass_frosted"


class LevelPlan:
    def __init__(self, building, name, index):
        self.building, self.name, self.index = building, name, index
        self.y = index * FLOOR_H
        self.footprint = FOOTPRINTS[building]
        self.regions = []
        self.doors = []
        self.openings = []
        self.markers = []        # 블록아웃 문 표식 (월드 Box)
        self.wall_top = self.y + WALL_H
        self.exterior = "wall"   # wall / parapet
        self.windows = True
        self.holes = []          # 슬래브 구멍 Rect
        self.path = ""
        self.special = set()
        self.grid = None
        self.window_log = []     # 건축 단계에서 기록: (axis, line, inward, w0, w1, y0, y1, kind)

    def add(self, region):
        region.id = len(self.regions)
        self.regions.append(region)
        return region

    def by_name(self, name):
        return [r for r in self.regions if r.name == name]

    def first(self, kind):
        return next((r for r in self.regions if r.kind == kind), None)

    def corridor(self):
        c = self.first("corridor")
        return c.rect if c else None


# ------------------------------------------------------------------ 이름 -> 양식, 경계 종류

STYLE_KEYS = [
    ("교실", "classroom"), ("자습실", "study"), ("동아리실", "club"), ("화장실", "toilet"),
    ("탈의실", "changing"), ("청소", "closet"), ("교무실", "office"), ("행정실", "admin"), ("교장실", "principal"),
    ("보건실", "nurse"), ("방송실", "broadcast"), ("경비실", "guard"), ("학생회실", "council"), ("로비", "lobby"),
    ("구 도서관", "old_library"), ("기록 보관실", "archive"), ("보일러실", "boiler"), ("전기실", "electric"),
    ("시설관리", "facility"), ("소방펌프", "pump"), ("폐기물", "waste"), ("영양교사실", "office"), ("급식행정실", "office"),
    ("열린 급식", "alcove"), ("매점 창고", "storage"), ("매점", "shop"), ("급식실", "cafeteria"),
    ("조리 식품 창고", "food_storage"), ("조리실", "kitchen"), ("세척실", "wash"), ("직원 휴게실", "staff"),
    ("음악 준비실", "prep_music"), ("미술 준비실", "prep_art"), ("작품 전시", "alcove"), ("공동 과학 준비실", "prep_science"),
    ("컴퓨터 기자재실", "prep_computer"), ("음악실", "music"), ("미술실", "art"), ("과학실", "science"),
    ("컴퓨터실", "computer"), ("사서실", "office"), ("도서 정리실", "book_work"), ("사물함·반납", "alcove"),
    ("보존서고", "stacks"), ("복사·정보검색실", "copy"), ("그룹학습실", "group_study"), ("도서관", "library"),
    ("창고", "storage"), ("체육기구", "storage"), ("행사물품", "storage"), ("관리실", "guard"), ("소품", "props_room"),
    ("음향", "sound_room"),
]


def style_of(name, kind):
    if kind in ("corridor", "stair", "elevator", "passage", "hall", "court", "stage", "stage_stair", "void",
                "seating", "roof", "bridge", "stair_hall"):
        return kind
    for key, style in STYLE_KEYS:
        if key in name:
            return style
    return "room"


# 문 없이 이어지는 경계 (종류 쌍)
OPEN_PAIRS = {frozenset(p) for p in [
    ("corridor", "stair"), ("corridor", "passage"), ("corridor", "alcove"), ("hall", "stair"), ("hall", "passage"),
    ("court", "stage"), ("stage", "stage_stair"), ("court", "stage_stair"), ("corridor", "bridge"), ("seating", "seating"),
    ("corridor", "stair_hall"), ("stair_hall", "stair")]}
RAIL_PAIRS = {frozenset(p) for p in [("seating", "void")]}
# 이름으로 지정한 열린 경계: 세척실은 조리실에 벽 없이 붙는다 (학교_맵_상세.md 별관 1층)
OPEN_NAMES = {frozenset(p) for p in [("조리실", "세척실")]}


def boundary_type(a, b):
    """두 구역 사이 경계: 'exterior' / 'open' / 'rail' / 'wall'. 한쪽이 None이면 바깥."""
    if a is None or b is None:
        return "exterior"
    if a.name == b.name or frozenset((a.name, b.name)) in OPEN_NAMES:
        return "open"
    pair = frozenset((a.kind, b.kind))
    if pair in OPEN_PAIRS or (a.kind == b.kind and a.kind in ("corridor", "roof", "hall", "court")):
        return "open"
    if pair in RAIL_PAIRS:
        return "rail"
    return "wall"


# ------------------------------------------------------------------ 정리: 가까운 모서리 맞추기

def _clusters(values, fixed):
    """values를 SNAP 폭으로 묶어 {원래값: 대표값}. 묶음에 fixed 값이 있으면 그 값을 쓴다."""
    vals = sorted(set(round(v, 4) for v in values))
    out = {}
    group = []

    def flush():
        if not group:
            return
        fx = [f for f in fixed if min(group) - 1e-3 <= f <= max(group) + 1e-3]
        rep = fx[0] if fx else (min(group) + max(group)) / 2
        for v in group:
            out[v] = rep

    for v in vals:
        if group and v - group[0] > SNAP:
            flush()
            group = []
        group.append(v)
    flush()
    return out


def normalize(plan):
    """방 모서리를 맞붙인다: 벽 두께만큼 벌어진 틈과 복도-방 겹침을 한 선으로. 건물 외곽선은 고정."""
    fp = plan.footprint
    fixed_x = [fp.x0, fp.x1] + [v for r in plan.regions if "fixed" in r.tags for v in (r.rect.x0, r.rect.x1)]
    fixed_z = [fp.z0, fp.z1] + [v for r in plan.regions if "fixed" in r.tags for v in (r.rect.z0, r.rect.z1)]
    mx = _clusters([v for r in plan.regions for v in (r.rect.x0, r.rect.x1)] + fixed_x, fixed_x)
    mz = _clusters([v for r in plan.regions for v in (r.rect.z0, r.rect.z1)] + fixed_z, fixed_z)
    for r in plan.regions:
        if "fixed" in r.tags:
            continue
        q = r.rect
        r.rect = Rect(mx[round(q.x0, 4)], mz[round(q.z0, 4)], mx[round(q.x1, 4)], mz[round(q.z1, 4)])


# ------------------------------------------------------------------ 격자: 구역 번호 칠하기

class Grid:
    """좌표 압축 격자. cell[i][j] = 구역 id (-1 = 바깥). i: x 구간, j: z 구간.
    겹치는 구역은 넓이가 작은 쪽이 이긴다 (복도 띠에 걸친 방 등)."""

    def __init__(self, plan, regions=None):
        self.plan = plan
        regions = plan.regions if regions is None else regions
        fp = plan.footprint
        xs, zs = {fp.x0, fp.x1}, {fp.z0, fp.z1}
        for r in regions:
            xs |= {r.rect.x0, r.rect.x1}
            zs |= {r.rect.z0, r.rect.z1}
        self.xs, self.zs = sorted(xs), sorted(zs)
        nx, nz = len(self.xs) - 1, len(self.zs) - 1
        self.cell = [[-1] * nz for _ in range(nx)]
        for r in sorted(regions, key=lambda r: -(r.rect.w * r.rect.d)):
            for i in range(nx):
                cx = (self.xs[i] + self.xs[i + 1]) / 2
                if not (r.rect.x0 < cx < r.rect.x1):
                    continue
                for j in range(nz):
                    cz = (self.zs[j] + self.zs[j + 1]) / 2
                    if r.rect.z0 < cz < r.rect.z1:
                        self.cell[i][j] = r.id

    def region_at(self, x, z):
        from bisect import bisect_right
        i = bisect_right(self.xs, x) - 1
        j = bisect_right(self.zs, z) - 1
        if 0 <= i < len(self.xs) - 1 and 0 <= j < len(self.zs) - 1:
            rid = self.cell[i][j]
            return self.plan.regions[rid] if rid >= 0 else None
        return None

    def gaps(self):
        """건물 평면 안인데 어느 구역에도 속하지 않은 칸 (계획 누락 검사용)"""
        fp = self.plan.footprint
        out = []
        for i in range(len(self.xs) - 1):
            for j in range(len(self.zs) - 1):
                if self.cell[i][j] < 0:
                    r = Rect(self.xs[i], self.zs[j], self.xs[i + 1], self.zs[j + 1])
                    if fp.contains_point(r.cx, r.cz) and r.w > 0.05 and r.d > 0.05:
                        out.append(r)
        return out

    def boundaries(self):
        """경계 선분 [(axis, fixed, a0, a1, id_neg, id_pos)].
        axis 'x': z=fixed 위 x방향 선분 (neg = z가 작은 쪽), 'z': x=fixed 위 z방향 선분 (neg = x가 작은 쪽)."""
        segs = []
        nx, nz = len(self.xs) - 1, len(self.zs) - 1
        for i in range(nx):
            for j in range(nz + 1):
                lo = self.cell[i][j - 1] if j > 0 else -1
                hi = self.cell[i][j] if j < nz else -1
                if lo != hi:
                    segs.append(("x", self.zs[j], self.xs[i], self.xs[i + 1], lo, hi))
        for j in range(nz):
            for i in range(nx + 1):
                lo = self.cell[i - 1][j] if i > 0 else -1
                hi = self.cell[i][j] if i < nx else -1
                if lo != hi:
                    segs.append(("z", self.xs[i], self.zs[j], self.zs[j + 1], lo, hi))
        return segs
