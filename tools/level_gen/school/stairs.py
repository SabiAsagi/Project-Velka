# -*- coding: utf-8 -*-
"""계단: 계단실마다 층을 잇는 되돌이 계단(복도쪽 참 - 1단 - 중간참 - 2단)을 쌓는다.

복도쪽 참(strip) 폭 S, 반대편 중간참 폭 L, 나머지가 경사로. 한쪽 절반은 올라가는 1단, 다른 절반은 2단.
위층 슬래브는 계단실 중 복도쪽 참을 제외한 영역이 뚫린다(holes 반환).
"""
import math
from geometry import Rect
from emit import rot_x, rot_z

STRIP = 1.0
LANDING = 1.1
FLOOR_H = 3.8
THICK = 0.3


def ramp(sw, parent, axis, a0, a1, n_a, y_a, n_b, y_b, mat, width_pad=0.0, name="Ramp"):
    """윗면이 (n_a, y_a)~(n_b, y_b)를 잇는 경사로. axis는 경사 방향 축('x' 또는 'z'), a0~a1은 다른 축 범위."""
    if n_a > n_b:
        n_a, y_a, n_b, y_b = n_b, y_b, n_a, y_a
    run, rise = n_b - n_a, y_b - y_a
    length = math.hypot(run, rise)
    ang = math.degrees(math.atan2(rise, run))
    mid_n, mid_y = (n_a + n_b) / 2, (y_a + y_b) / 2
    w = (a1 - a0) + width_pad
    if axis == "z":
        rows = rot_x(-ang)
        ny, nn = math.cos(math.radians(ang)), -math.sin(math.radians(ang))
        center = ((a0 + a1) / 2, mid_y - ny * THICK / 2, mid_n - nn * THICK / 2)
        size = (w, THICK, length)
    else:
        rows = rot_z(ang)
        ny, nn = math.cos(math.radians(ang)), -math.sin(math.radians(ang))
        center = (mid_n - nn * THICK / 2, mid_y - ny * THICK / 2, (a0 + a1) / 2)
        size = (length, THICK, w)
    return sw.solid(parent, name, center, size, mat, rows=rows)


def slab(sw, parent, rect, top_y, mat, thick=0.2, name="Slab"):
    sw.solid(parent, name, (rect.cx, top_y - thick / 2, rect.cz), (rect.w, thick, rect.d), mat)


def wall_seg(sw, parent, axis, a0, a1, fixed, y0, y1, mat, name="Rail", thick=0.15):
    if axis == "x":
        sw.solid(parent, name, ((a0 + a1) / 2, (y0 + y1) / 2, fixed), (a1 - a0, y1 - y0, thick), mat)
    else:
        sw.solid(parent, name, (fixed, (y0 + y1) / 2, (a0 + a1) / 2), (thick, y1 - y0, a1 - a0), mat)


class StairWell:
    """계단실 하나의 기하 (월드 좌표)"""

    def __init__(self, rect, corridor_axis, corridor_sign):
        # corridor_axis: 복도 방향 법선 축 ('z'면 복도가 z쪽), corridor_sign: 복도가 +쪽이면 1
        self.rect, self.n_axis, self.sign = rect, corridor_axis, corridor_sign
        self.a_axis = "x" if corridor_axis == "z" else "z"
        if corridor_axis == "z":
            self.a0, self.a1, lo, hi = rect.x0, rect.x1, rect.z0, rect.z1
        else:
            self.a0, self.a1, lo, hi = rect.z0, rect.z1, rect.x0, rect.x1
        self.near, self.far = (hi, lo) if corridor_sign > 0 else (lo, hi)
        s = corridor_sign
        self.strip_edge = self.near - s * STRIP
        self.landing_edge = self.far + s * LANDING
        self.mid = (self.a0 + self.a1) / 2

    def _rect(self, n0, n1, a0=None, a1=None):
        a0 = self.a0 if a0 is None else a0
        a1 = self.a1 if a1 is None else a1
        if self.n_axis == "z":
            return Rect(a0, n0, a1, n1)
        return Rect(n0, a0, n1, a1)

    def hole(self):
        """위층 슬래브에서 뚫을 영역 (복도쪽 참 제외)"""
        return self._rect(self.far, self.strip_edge)

    def build_segment(self, sw, parent, y0, mat, wall_mat, bottom=False, top=False):
        a_mid0, a_mid1 = self.mid - 0.075, self.mid + 0.075
        ramp(sw, parent, self.n_axis, self.a0, a_mid0, self.strip_edge, y0, self.landing_edge, y0 + FLOOR_H / 2, mat, name="FlightUp")
        ramp(sw, parent, self.n_axis, a_mid1, self.a1, self.landing_edge, y0 + FLOOR_H / 2, self.strip_edge, y0 + FLOOR_H, mat, name="FlightDown")
        slab(sw, parent, self._rect(self.far, self.landing_edge), y0 + FLOOR_H / 2, mat, name="MidLanding")
        n0, n1 = sorted((self.strip_edge, self.landing_edge))
        wall_seg(sw, parent, self.n_axis, n0, n1, self.mid, y0, y0 + FLOOR_H + 1.0, wall_mat, name="Divider")
        if bottom:
            # 가장 아래층: 2단 아래 공간을 막는다
            wall_seg(sw, parent, self.a_axis, a_mid1, self.a1, self.strip_edge, y0, y0 + FLOOR_H / 2, wall_mat, name="UnderBlock")
        if top:
            # 가장 위층: 올라가는 계단이 없는 쪽 난간
            wall_seg(sw, parent, self.a_axis, self.a0, a_mid0, self.strip_edge, y0 + FLOOR_H, y0 + FLOOR_H + 1.1, wall_mat, name="TopRail")
        # 검증용 걷기 경로 (복도쪽 참 -> 1단 -> 중간참 -> 2단 -> 위층 참)
        a_a, a_b = (self.a0 + self.mid) / 2, (self.mid + self.a1) / 2
        strip_mid, land_mid = (self.near + self.strip_edge) / 2, (self.far + self.landing_edge) / 2
        pts = [(a_a, strip_mid, y0), (a_a, land_mid, y0 + FLOOR_H / 2), (a_b, land_mid, y0 + FLOOR_H / 2), (a_b, strip_mid, y0 + FLOOR_H)]
        stair_path(sw, parent, [self._world(a, n, y) for a, n, y in pts])

    def _world(self, a, n, y):
        return (a, y, n) if self.n_axis == "z" else (n, y, a)


def stair_path(sw, parent, points, name="StairPath"):
    """테스트가 따라 걸을 경로 (월드 좌표). 그룹 stair_path."""
    arr = ", ".join("%.3f, %.3f, %.3f" % (x, y + 0.05, z) for x, y, z in points)
    sw.node(name, "Node3D", parent, {"metadata/points": "PackedVector3Array(%s)" % arr}, groups=["stair_path"])


def corridor_side(zone_rect, corridor_rect):
    """계단실 기준 복도 방향 (축, 부호)"""
    if corridor_rect.w >= corridor_rect.d:
        return "z", (1 if corridor_rect.cz > zone_rect.cz else -1)
    return "x", (1 if corridor_rect.cx > zone_rect.cx else -1)
