# -*- coding: utf-8 -*-
"""계단 (생성기 v2): 되돌이 계단을 층마다 쌓는다.

계단실 = 복도쪽 참(도착 참) + 두 줄 계단(올라가는 1단 / 되돌아 오르는 2단) + 먼 쪽 중간참.
보이는 디딤판은 단마다 박스, 걷는 면은 보이지 않는 경사 충돌면. 안쪽은 금속 난간.
위층 슬래브는 복도쪽 참을 뺀 계단실 전체가 뚫린다 (plan.holes).
"""
import math
from geometry import Rect
from plan import FACADE_T, INNER_T, PART_T, SLAB, boundary_type
from source import FLOOR_H

EXT_T = FACADE_T + INNER_T
HALF = PART_T / 2
RISER = 0.17
STRIP = 1.2      # 복도쪽 도착 참 깊이
LANDING = 1.25   # 중간참 깊이
GAP = 0.12       # 두 계단 사이 틈 (난간 자리)


def slope_rows(axis, angle_deg):
    """경사로 회전 행렬 (행 우선). axis: 경사가 오르는 방향 축 'x' 또는 'z', angle>0이면 +축으로 올라간다."""
    c, s = math.cos(math.radians(angle_deg)), math.sin(math.radians(angle_deg))
    if axis == "z":
        # x축 회전: +z 로 갈수록 높아지려면 -angle 회전
        return (1, 0, 0, 0, c, s, 0, -s, c)
    return (c, -s, 0, s, c, 0, 0, 0, 1)


def flight(batch, container, axis, n0, n1, y0, y1, w0, w1, mat, groups=(), rail_sides=(), thickness=0.25, rail_trim=(0.0, 1.0),
           solid_to=None):
    """한 줄 계단: 길이축 axis 위 n0(높이 y0) -> n1(높이 y1), 폭 [w0,w1].
    디딤판 박스 + 경사 충돌면 + rail_sides에 적힌 쪽('w0','w1') 금속 난간(충돌 포함)."""
    run = n1 - n0
    rise = y1 - y0
    steps = max(2, int(round(abs(rise) / RISER)))
    tread = run / steps
    step_h = abs(rise) / steps
    for i in range(steps):
        a, b = n0 + tread * i, n0 + tread * (i + 1)
        top = y0 + rise * (i + 1) / steps if rise > 0 else y0 + rise * i / steps
        lo, hi = sorted((a, b))
        bottom = max(top - step_h - 0.18, min(y0, y1) + 0.002)
        if solid_to is not None and abs((a + b) / 2 - n0) <= abs(solid_to - n0):
            bottom = min(y0, y1) + 0.002
        _box(batch, container, mat, axis, lo, hi, bottom, top, w0, w1, groups, "stair_step")
    # 걷는 면: 디딤판 앞끝을 잇는 경사면 (위로 두께만큼 내린 회전 박스)
    # 아래쪽 끝은 바닥 속으로 0.3m 더 늘려 턱이 생기지 않게 한다
    sign = 1 if run > 0 else -1
    grade = rise / abs(run)
    e0 = n0 - sign * 0.3
    ey0 = y0 - grade * 0.3
    length = math.hypot(n1 - e0, y1 - ey0)
    ang = math.degrees(math.atan2(y1 - ey0, abs(n1 - e0)))
    mid_n, mid_y = (e0 + n1) / 2, (ey0 + y1) / 2
    ny, nn = math.cos(math.radians(ang)), -math.sin(math.radians(ang)) * sign
    cy = mid_y - ny * thickness / 2 + step_h * 0.5
    cn = mid_n - nn * thickness / 2
    rows = slope_rows(axis, ang * sign)
    if axis == "z":
        batch.solid(container, ((w0 + w1) / 2, cy, cn), (w1 - w0, thickness, length), groups, "ramp", rows)
    else:
        batch.solid(container, (cn, cy, (w0 + w1) / 2), (length, thickness, w1 - w0), groups, "ramp", rows)
    for side in rail_sides:
        w = w0 + 0.03 if side == "w0" else w1 - 0.03
        sloped_rail(batch, container, axis, n0, n1, y0 + step_h * 0.5, y1 + step_h * 0.5, w, groups, rail_trim)


def sloped_rail(batch, container, axis, n0, n1, y0, y1, w, groups=(), trim=(0.0, 1.0)):
    """경사 난간: 기둥 + 기울어진 손잡이 + 보이지 않는 충돌판.
    trim=(시작쪽, 끝쪽): 충돌판을 그 길이만큼 줄인다 (기울어진 판 모서리가 참 위로 튀어나오지 않게)."""
    run, rise = n1 - n0, y1 - y0
    n = max(2, int(abs(run) // 0.9) + 1)
    for i in range(n):
        t = i / (n - 1)
        pn = n0 + run * t
        py = y0 + rise * t
        pn = min(max(pn, min(n0, n1) + 0.03), max(n0, n1) - 0.03)
        _box(batch, container, "rail_metal", axis, pn - 0.02, pn + 0.02, py, py + 0.9, w - 0.02, w + 0.02, groups, "rail_post", collide=False)
    length = math.hypot(run, rise)
    ang = math.degrees(math.atan2(rise, abs(run)))
    sign = 1 if run > 0 else -1
    rows = slope_rows(axis, ang * sign)
    c = ((n0 + n1) / 2, (y0 + y1) / 2 + 0.92)
    # 충돌판: 경사선 아래 1.0m 두께, 양끝 trim만큼 줄인 구간
    t0, t1 = trim
    frac0, frac1 = t0 / abs(run), 1.0 - t1 / abs(run)
    if frac1 - frac0 > 0.1:
        cn = n0 + run * (frac0 + frac1) / 2
        cyy = y0 + rise * (frac0 + frac1) / 2 + 0.92 - 0.5
        clen = length * (frac1 - frac0)
    if axis == "z":
        batch.box(container, "rail_metal", (w, c[1], c[0]), (0.05, 0.05, length), False, groups, "handrail", rows)
        if frac1 - frac0 > 0.1:
            batch.solid(container, (w, cyy, cn), (0.06, 1.0, clen), groups, "rail", rows)
    else:
        batch.box(container, "rail_metal", (c[0], c[1], w), (length, 0.05, 0.05), False, groups, "handrail", rows)
        if frac1 - frac0 > 0.1:
            batch.solid(container, (cn, cyy, w), (clen, 1.0, 0.06), groups, "rail", rows)


def _box(batch, container, mat, axis, n0, n1, y0, y1, w0, w1, groups, tag, collide=False):
    if axis == "z":
        batch.box(container, mat, ((w0 + w1) / 2, (y0 + y1) / 2, (n0 + n1) / 2), (w1 - w0, y1 - y0, n1 - n0), collide, groups, tag)
    else:
        batch.box(container, mat, ((n0 + n1) / 2, (y0 + y1) / 2, (w0 + w1) / 2), (n1 - n0, y1 - y0, w1 - w0), collide, groups, tag)


def flat_rail(batch, container, axis, a0, a1, fixed, y, groups=()):
    """수평 난간: axis 방향으로 뻗음 (fixed = 다른 축 좌표)"""
    if axis == "x":
        batch.box(container, "rail_metal", ((a0 + a1) / 2, y + 1.05, fixed), (a1 - a0, 0.05, 0.05), False, groups, "handrail")
        batch.solid(container, ((a0 + a1) / 2, y + 0.55, fixed), (a1 - a0, 1.1, 0.06), groups, "rail")
        n = max(1, int((a1 - a0) // 1.0))
        for i in range(n + 1):
            x = min(max(a0 + (a1 - a0) * i / n, a0 + 0.045), a1 - 0.045)
            batch.box(container, "rail_metal", (x, y + 0.52, fixed), (0.04, 1.04, 0.04), False, groups, "rail_post")
    else:
        batch.box(container, "rail_metal", (fixed, y + 1.05, (a0 + a1) / 2), (0.05, 0.05, a1 - a0), False, groups, "handrail")
        batch.solid(container, (fixed, y + 0.55, (a0 + a1) / 2), (0.06, 1.1, a1 - a0), groups, "rail")
        n = max(1, int((a1 - a0) // 1.0))
        for i in range(n + 1):
            z = min(max(a0 + (a1 - a0) * i / n, a0 + 0.045), a1 - 0.045)
            batch.box(container, "rail_metal", (fixed, y + 0.52, z), (0.04, 1.04, 0.04), False, groups, "rail_post")


def fill_under(batch, container, axis, n0, n1, y0, y1, w0, w1, mat, floor_y, groups=()):
    """한 줄 계단(flight와 같은 인자)의 디딤판 밑을 바닥(floor_y)까지 벽 재질로 채운다 (가장 아래층의 계단 밑 막음).
    벽은 디딤판 바로 밑까지 올라가므로 계단 옆에서 보면 계단을 따라 오르는 벽으로 보인다."""
    rise = y1 - y0
    steps = max(2, int(round(abs(rise) / RISER)))
    tread = (n1 - n0) / steps
    step_h = abs(rise) / steps
    for i in range(steps):
        top = y0 + rise * (i + 1) / steps if rise > 0 else y0 + rise * i / steps
        under = top - step_h - 0.18
        if under - floor_y < 0.05:
            continue
        lo, hi = sorted((n0 + tread * i, n0 + tread * (i + 1)))
        _box(batch, container, mat, axis, lo, hi, floor_y, under, w0, w1, groups, "under_stair", collide=True)


def closet_door(batch, sw, container, axis, a, n, s, y, groups=(), text="창고"):
    """계단 밑 창고의 작은 철문 (장식): 문짝 + 문틀 + 손잡이 + 이름표.
    axis = 문이 바라보는 축, n = 벽면 좌표, s = 바라보는 방향(+1 / -1), a = 문 중심 (다른 축 좌표)"""
    def pt(aa, nn, yy):
        return (aa, yy, nn) if axis == "z" else (nn, yy, aa)

    def part(mat, da, w, t, y0, y1, dn=0.012):
        size = (w, y1 - y0, t) if axis == "z" else (t, y1 - y0, w)
        batch.box(container, mat, pt(a + da, n + s * dn, y + (y0 + y1) / 2), size, False, groups, "prop")
    part("kick_plate", 0.0, 0.8, 0.03, 0.01, 1.85)
    part("steel_frame", 0.0, 0.92, 0.02, 1.85, 1.91)
    for da in (-0.43, 0.43):
        part("steel_frame", da, 0.06, 0.02, 0.012, 1.85)
    part("steel", 0.3, 0.035, 0.035, 0.92, 1.04, 0.032)
    part("sign_board", 0.0, 0.5, 0.012, 1.5, 1.62, 0.032)
    from props_base import label
    from batch import rows_y
    rot = rows_y(0.0 if axis == "z" else 90.0) if s > 0 else rows_y(180.0 if axis == "z" else -90.0)
    label(sw, container, pt(a, n + s * 0.047, y + 1.56), text, 0.0022, 32, (0.15, 0.16, 0.18), rot, list(groups) or None)


STAIR_PATHS = []          # (부모 경로, [(x, y, z), ...]) : 검증기가 계단 양 끝이 막히지 않았는지 확인할 때 쓴다


def stair_path(sw, parent, points, name="StairPath"):
    STAIR_PATHS.append((parent, [tuple(pt) for pt in points]))
    arr = ", ".join("%.3f, %.3f, %.3f" % (x, y + 0.05, z) for x, y, z in points)
    sw.node(name, "Node3D", parent, {"metadata/points": "PackedVector3Array(%s)" % arr}, groups=["stair_path"])


# ------------------------------------------------------------------ 계단실 (학교_맵_상세.md 2-3, 2-8 + 사용자 지시: 입구가 복도를 본다)

def _inner_of(plan, region):
    from plan_build import inner_rect
    return inner_rect(plan, region)


def wall_rail(batch, container, axis, n0, y0, n1, y1, w, groups=()):
    """벽에 붙은 손잡이 봉 (기둥·충돌 없음)"""
    run, rise = n1 - n0, y1 - y0
    length = math.hypot(run, rise)
    ang = math.degrees(math.atan2(rise, abs(run))) * (1 if run > 0 else -1)
    rows = slope_rows(axis, ang)
    cy = (y0 + y1) / 2 + 0.9
    if axis == "z":
        batch.box(container, "rail_metal", (w, cy, (n0 + n1) / 2), (0.045, 0.045, length), False, groups, "handrail", rows)
    else:
        batch.box(container, "rail_metal", ((n0 + n1) / 2, cy, w), (length, 0.045, 0.045), False, groups, "handrail", rows)


class UWell:
    """좌·우 계단: 입구가 복도를 바라보는 되돌이 계단.
    복도에서 보면 한쪽 절반은 올라가는 계단(1단), 다른 절반은 아래층에서 올라와 닿는 계단(2단 = 내려가는 입구)이다.
    1단은 복도에서 먼 쪽 벽의 중간참까지 오르고, 2단이 되돌아 위층 복도 앞에 닿는다. 난간은 두 줄 사이에서 끊기지 않고 이어진다."""

    STRIP = 0.35     # 복도 쪽에 남는 바닥 띠 (계단은 여기서 시작·도착)
    LANDING = 1.35   # 중간참 깊이
    GAP = 0.2        # 두 줄 사이 (난간 자리)

    def __init__(self, plan, region):
        ir, kinds = _inner_of(plan, region)
        side = next((s for s in ("z1", "z0", "x1", "x0") if kinds[s] == "open"), "z1")
        self.n_axis = "z" if side[0] == "z" else "x"      # 계단이 달리는 축 (복도에 직각)
        self.sign = 1 if side[1] == "1" else -1           # 복도가 + 쪽이면 1
        if self.n_axis == "z":
            self.a0, self.a1 = ir.x0, ir.x1
            self.near, self.far = (ir.z1, ir.z0) if self.sign > 0 else (ir.z0, ir.z1)
        else:
            self.a0, self.a1 = ir.z0, ir.z1
            self.near, self.far = (ir.x1, ir.x0) if self.sign > 0 else (ir.x0, ir.x1)
        s = self.sign
        self.start = self.near - s * self.STRIP
        self.land = self.far + s * self.LANDING
        self.mid = (self.a0 + self.a1) / 2
        # 올라가는 1단은 카메라에 가까운 절반(좌표가 큰 쪽)에 두어 두 줄이 모두 보이게 한다
        self.h1 = (self.mid + self.GAP / 2, self.a1)
        self.h2 = (self.a0, self.mid - self.GAP / 2)

    def _rect(self, n0, n1, a0, a1):
        n0, n1 = sorted((n0, n1))
        return Rect(a0, n0, a1, n1) if self.n_axis == "z" else Rect(n0, a0, n1, a1)

    def _pt(self, a, n, y):
        return (a, y, n) if self.n_axis == "z" else (n, y, a)

    def hole(self):
        return self._rect(self.far, self.start, self.a0, self.a1)

    def _cap(self, batch, container, n, y, w0, w1, groups):
        """두 줄 난간 끝을 잇는 짧은 봉"""
        c = self._pt((w0 + w1) / 2, n, y)
        size = (w1 - w0 + 0.05, 0.05, 0.05) if self.n_axis == "z" else (0.05, 0.05, w1 - w0 + 0.05)
        batch.box(container, "rail_metal", c, size, False, groups, "handrail")

    def _closet_door(self, batch, sw, container, y, groups):
        """계단 밑 창고 문 (복도를 보는 면)"""
        closet_door(batch, sw, container, self.n_axis, (self.h2[0] + self.h2[1]) / 2, self.start, self.sign, y, groups)

    def build(self, batch, sw, container, upper, y, mat, bottom=False, top_after=False, groups=(), label_text="",
              wall_mat="wall_corridor"):
        """y층에서 y+3.8층까지 한 구간. upper = 위층 묶음 (위층 바닥 가장자리 난간은 위층과 함께 보이고 숨는다)"""
        h = FLOOR_H / 2
        ax = self.n_axis
        cross = "x" if ax == "z" else "z"
        s = self.sign
        steps = max(2, int(round(h / RISER)))
        off = h / steps * 0.5
        flight(batch, container, ax, self.start, self.land, y, y + h, self.h1[0], self.h1[1], mat, groups, ("w0",),
               rail_trim=(0.0, 0.5), solid_to=self.land if bottom else None)
        flight(batch, container, ax, self.land, self.start, y + h, y + FLOOR_H, self.h2[0], self.h2[1], mat, groups, ("w1",),
               rail_trim=(0.5, 0.0))
        land = self._rect(self.far, self.land, self.a0, self.a1)
        if bottom:
            batch.box(container, mat, (land.cx, y + h / 2, land.cz), (land.w, h, land.d), True, groups, "landing")
            # 가장 아래층: 2단 밑은 벽으로 막아 계단 밑 창고로 만든다. 벽은 디딤판 바로 밑까지 올라가 틈이 없다
            tread = (self.start - self.land) / steps
            for i in range(steps):
                under = max(y + h + h * (i + 1) / steps - h / steps - 0.18, y + h)
                r = self._rect(self.land + tread * i, self.land + tread * (i + 1), self.h2[0], self.h2[1])
                batch.box(container, wall_mat, (r.cx, (y + under) / 2, r.cz), (r.w, under - y, r.d), True, groups, "under_stair")
            self._closet_door(batch, sw, container, y, groups)
        else:
            batch.box(container, mat, (land.cx, y + h - 0.1, land.cz), (land.w, 0.2, land.d), True, groups, "landing")
        # 난간: 가운데 두 줄(계단마다 flight가 넣음)을 참과 위층에서 잇고, 바깥 벽에는 손잡이 봉
        w1, w2 = self.h1[0] + 0.03, self.h2[1] - 0.03
        self._cap(batch, container, self.land, y + h + off + 0.92, w2, w1, groups)
        self._cap(batch, container, self.start, y + FLOOR_H + off + 0.92, w2, w1, groups)
        wall_rail(batch, container, ax, self.start, y + off, self.land, y + h + off, self.h1[1] - 0.07, groups)
        wall_rail(batch, container, ax, self.land, y + h + off, self.start, y + FLOOR_H + off, self.h2[0] + 0.07, groups)
        if top_after:
            # 맨 위층: 1단이 더 이어지지 않으므로 그 자리의 뚫린 곳을 복도 쪽에서 난간으로 막는다
            flat_rail(batch, upper, cross, w1, self.h1[1] - 0.02, self.start, y + FLOOR_H, groups)
        # 중간참: 작은 쓰레기통, 층 표시
        bx = self._pt(self.a1 - 0.3, self.far + s * 0.3, y + h + 0.25)
        batch.box(container, "bin_gray", bx, (0.3, 0.5, 0.3), False, groups, "prop")
        if label_text:
            from props_base import label
            from batch import rows_y
            pos = self._pt(self.a0 + 0.55, self.far + s * 0.04, y + h + 1.3)
            rot = rows_y(0.0 if ax == "z" else 90.0) if s > 0 else rows_y(180.0 if ax == "z" else -90.0)
            plate = self._pt(self.a0 + 0.55, self.far + s * 0.015, y + h + 1.3)
            size = (0.7, 0.5, 0.02) if ax == "z" else (0.02, 0.5, 0.7)
            batch.box(container, "sign_blue", plate, size, False, groups, "prop")
            label(sw, container, pos, label_text, 0.0035, 48, (0.96, 0.97, 0.98), rot, list(groups) or None)
        a_1, a_2 = (self.h1[0] + self.h1[1]) / 2, (self.h2[0] + self.h2[1]) / 2
        n_out = self.near + s * 0.6
        n_land = (self.far + self.land) / 2
        pts = [(a_1, n_out, y), (a_1, n_land, y + h), (a_2, n_land, y + h), (a_2, n_out, y + FLOOR_H)]
        stair_path(sw, container, [self._pt(a, n, yy) for a, n, yy in pts])


class ImperialWell:
    """본관 중앙 계단 (사용자 지시 2026-10-01): 가운데로 반 층 오른 뒤 참에서 양옆으로 갈라져 되돌아 반 층을 오른다.
    가운데 = 올라가는 계단, 양옆 = 아래층에서 올라와 닿는 계단(= 내려가는 입구). 세 입구가 모두 복도를 본다.
    세 계단은 복도 쪽으로 LEAD만큼 나와 한 줄(계단 선)에서 시작·도착하고, 그만큼 계단 덩어리가 앞으로 당겨져
    뒤(북쪽)에 넓은 통로가 남는다 (1층은 후문 앞 공간). 양옆에도 층마다 걸을 수 있는 통로가 있다."""

    CENTER_W = 2.4    # 가운데 계단 폭
    SIDE_W = 1.3      # 양옆 계단 폭
    GAP = 0.12        # 가운데와 옆 계단 사이 (난간 자리)
    LANDING = 1.15    # 참 깊이
    RUN = 2.75        # 옆 계단 한 줄의 수평 길이 (반 층 1.9m, 약 35도)
    LEAD = 0.75       # 계단 선이 복도로 나오는 길이 (복도 2.88m 가운데 2.1m가 남는다)

    def __init__(self, plan, region):
        ir, _ = _inner_of(plan, region)
        c = plan.corridor()
        self.inner = ir
        corr_plus = True if c is None else c.cz > ir.cz
        self.s = 1 if corr_plus else -1                         # 복도가 있는 쪽 (+z면 1)
        self.near = ir.z1 if corr_plus else ir.z0               # 계단실과 복도의 경계
        self.far = ir.z0 if corr_plus else ir.z1
        self.cx = ir.cx
        self.start = self.near + self.s * self.LEAD             # 가운데 계단 첫 단 (계단 선)
        self.c0, self.c1 = self.cx - self.CENTER_W / 2, self.cx + self.CENTER_W / 2
        self.w0, self.w1 = self.c0 - self.GAP - self.SIDE_W, self.c0 - self.GAP
        self.e0, self.e1 = self.c1 + self.GAP, self.c1 + self.GAP + self.SIDE_W
        self.holes = []                                         # 마지막으로 지은 구간이 위층 바닥에 내는 구멍

    def build(self, batch, sw, container, upper, y, mat, bottom=False, top_after=False, groups=(), wall_mat="wall_corridor",
              top_lead=None):
        """y층에서 y+3.8층까지 한 구간. upper = 위층 묶음 (위층 바닥 가장자리 난간은 위층과 함께 보이고 숨는다).
        top_lead = 옆 계단이 위층에서 복도 쪽으로 나오는 길이 (기본 LEAD, 옥상 출입실처럼 앞이 좁으면 0)."""
        h = FLOOR_H / 2
        s = self.s
        yt = y + FLOOR_H
        top = self.near + s * (self.LEAD if top_lead is None else top_lead)     # 옆 계단이 위층에 닿는 선
        land_near = top - s * self.RUN                                          # 참의 복도 쪽 끝
        land_far = land_near - s * self.LANDING                                 # 참의 뒤쪽 끝 (그 뒤는 통로)
        sides = ((self.w0, self.w1), (self.e0, self.e1))
        # 난간 충돌판은 기울어진 판이라 끝 모서리가 계단 밖으로 0.28m 나온다. 복도에 닿는 끝은 0.3m 줄여 발에 걸리지 않게 한다
        flight(batch, container, "z", self.start, land_near, y, y + h, self.c0, self.c1, mat, groups, ("w0", "w1"),
               rail_trim=(0.3, 0.4))
        for a0, a1 in sides:
            flight(batch, container, "z", land_near, top, y + h, yt, a0, a1, mat, groups, ("w0", "w1"), rail_trim=(0.4, 0.3))
        z0, z1 = sorted((land_far, land_near))
        land = Rect(self.w0, z0, self.e1, z1)
        batch.box(container, mat, (land.cx, y + h - 0.1, land.cz), (land.w, 0.2, land.d), True, groups, "landing")
        if bottom:
            # 가장 아래층: 참과 계단 밑을 벽으로 막는다 (머리가 닿는 낮은 틈을 남기지 않는다). 옆 계단 밑은 문이 달린 창고.
            # 옆 계단 밑 벽은 가운데 계단과의 틈까지 채워, 가운데 계단이 두 벽 사이를 오르는 모양이 된다
            batch.box(container, wall_mat, (land.cx, y + (h - 0.2) / 2, land.cz), (land.w, h - 0.2, land.d), True, groups, "under_stair")
            fill_under(batch, container, "z", self.start, land_near, y, y + h, self.c0, self.c1, wall_mat, y, groups)
            for k, (a0, a1) in enumerate(((self.w0, self.c0), (self.c1, self.e1))):
                fill_under(batch, container, "z", land_near, top, y + h, yt, a0, a1, wall_mat, y, groups)
                closet_door(batch, sw, container, "z", (sides[k][0] + sides[k][1]) / 2, top, s, y, groups,
                            ("창고", "배관 점검구")[k])
        # 참 난간: 뒤쪽과 양옆 (계단이 닿는 복도 쪽은 열려 있다)
        flat_rail(batch, container, "x", self.w0, self.e1, land_far + s * 0.04, y + h, groups)
        zr0, zr1 = (z0 + 0.1, z1) if s > 0 else (z0, z1 - 0.1)      # 뒤 난간과 만나는 모서리 기둥은 한 번만 세운다
        flat_rail(batch, container, "z", zr0, zr1, self.w0 + 0.04, y + h, groups)
        flat_rail(batch, container, "z", zr0, zr1, self.e1 - 0.04, y + h, groups)
        # 위층 바닥 구멍: 계단실 쪽 큰 구멍 + 옆 계단이 복도로 나온 만큼의 두 조각 (가운데는 다음 계단의 첫 단이 놓이는 바닥)
        hz0, hz1 = sorted((land_far, self.near))
        self.holes = [Rect(self.w0, hz0, self.e1, hz1)]
        if abs(top - self.near) > 0.01:
            f0, f1 = sorted((self.near, top))
            self.holes += [Rect(a0, f0, a1, f1) for a0, a1 in sides]
        # 위층 바닥 구멍 둘레 난간: 뒤, 양옆. 가운데는 다음 계단이 시작하지 않는 맨 위층에서만 막는다
        rz0, rz1 = sorted((land_far, top))
        flat_rail(batch, upper, "x", self.w0 - 0.08, self.e1 + 0.08, land_far - s * 0.05, yt, groups)
        flat_rail(batch, upper, "z", rz0, rz1, self.w0 - 0.05, yt, groups)
        flat_rail(batch, upper, "z", rz0, rz1, self.e1 + 0.05, yt, groups)
        if top_after:
            flat_rail(batch, upper, "x", self.w1, self.e0, self.near - s * 0.04, yt, groups)
        ex = (self.e0 + self.e1) / 2
        lm = (land_far + land_near) / 2
        pts = [(self.cx, y, self.start + s * 0.45), (self.cx, y + h, lm), (ex, y + h, lm), (ex, yt, top + s * 0.55)]
        stair_path(sw, container, pts)


def build_stairs_v2(plans, batch, sw, container_of):
    """좌·우 계단(UWell: 입구가 복도를 보는 되돌이 계단)과 본관 중앙 양갈래 계단(ImperialWell)을 층마다 쌓는다."""
    for bname in ("main", "annex"):
        chain = sorted([lv for (b, _), lv in plans.items() if b == bname], key=lambda l: l.index)
        names = sorted({r.name for lv in chain for r in lv.regions if r.kind == "stair"})
        for name in names:
            levels = [lv for lv in chain if lv.by_name(name)]
            for lv in levels:
                nxt = next((l for l in chain if l.index == lv.index + 1), None)
                if nxt is None:
                    continue
                goes = bool(nxt.by_name(name)) or (name == "중앙 계단" and nxt.name == "Roof")
                if not goes:
                    continue
                after = next((l for l in chain if l.index == nxt.index + 1), None)
                continues = nxt.name != "Roof" and after is not None and (
                    bool(after.by_name(name)) or (name == "중앙 계단" and after.name == "Roof"))
                region = lv.by_name(name)[0]
                bottom = lv is levels[0]
                path, upper = container_of(lv, "Stairs"), container_of(nxt, "Stairs")
                wall_mat = "wall_b1" if (bname == "main" and lv.name == "B1") else "wall_corridor"
                if name == "중앙 계단" and bname == "main":
                    well = ImperialWell(lv, region)
                    # 옥상 출입실은 계단 앞이 좁으므로 그 구간의 옆 계단은 복도 쪽으로 내밀지 않는다
                    well.build(batch, sw, path, upper, lv.y, "stair", bottom=bottom, top_after=not continues, wall_mat=wall_mat,
                               top_lead=0.0 if nxt.name == "Roof" else None)
                    nxt.holes.extend(well.holes)
                else:
                    well = UWell(lv, region)
                    well.build(batch, sw, path, upper, lv.y, "stair", bottom=bottom, top_after=not continues,
                               label_text="%s ▲  %s ▼" % (nxt.name, lv.name), wall_mat=wall_mat)
                    nxt.holes.append(well.hole())
