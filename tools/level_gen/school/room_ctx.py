# -*- coding: utf-8 -*-
"""방 하나의 배치 정보: 안쪽 사각형, 좌표계(앞 벽), 문·창 위치(방 좌표), 가구 금지 구역."""
from props_base import Frame, Props
from plan_build import inner_rect


ANCHORS = {}       # "건물/층/방/이름" -> ((x, y, z) 물체 위치, (dx, dz) 물체에서 플레이어가 서는 자리까지)


class Opening2:
    def __init__(self, side, a0, a1, kind, sliding=False, leaf_inside=False):
        self.side, self.a0, self.a1, self.kind = side, a0, a1, kind
        self.sliding, self.leaf_inside = sliding, leaf_inside

    @property
    def mid(self):
        return (self.a0 + self.a1) / 2


class RoomCtx:
    def __init__(self, plan, region, batch, sw, container, front, groups=(), seed=0):
        self.plan, self.region, self.sw, self.container = plan, region, sw, container
        self.inner, self.kinds = inner_rect(plan, region)
        self.y = plan.y + region.floor_dy
        self.frame = Frame(self.inner, front, self.y)
        self.p = Props(batch, container, self.frame, groups, seed)
        self.groups = tuple(groups)
        self.doors = []
        self.windows = []
        self._collect()

    @property
    def W(self):
        return self.frame.W

    @property
    def D(self):
        return self.frame.D

    def anchor(self, key, u, v, su, sv):
        """조사 대상 기준점: 실제 가구 위치 (u, v)와 그 앞에 서는 자리 (su, sv)를 월드 좌표로 남긴다.
        world_extras.build_inspectables가 이 값으로 조사 지점을 놓는다 (가구를 옮기면 조사 지점도 따라간다)."""
        x, z = self.frame.pt(u, v)
        px, pz = self.frame.pt(su, sv)
        room = "corridor" if self.region.kind == "corridor" else self.region.name
        ANCHORS["%s/%s/%s/%s" % (self.plan.building, self.plan.name, room, key)] = ((x, self.y, z), (px - x, pz - z))

    def visible_side(self, side):
        """그 변의 벽 안쪽 면이 고정 카메라(남동쪽 위)에서 보이는가 (북·서쪽 벽만 보인다)"""
        return self.frame.world_side(side) in ("x0", "z0")

    def local_side(self, world_side):
        return self.frame.side_of(world_side)

    def kind_of(self, local):
        """방 좌표 변('front' 등)의 경계 종류: exterior / wall / open"""
        return self.kinds[self.frame.world_side(local)]

    def _range(self, side, wa0, wa1, axis):
        """월드 벽선 구간 -> 그 변을 따라가는 방 좌표 구간"""
        f = self.frame
        r = self.region.rect
        if axis == "x":
            p0 = f.uv(wa0, r.cz)
            p1 = f.uv(wa1, r.cz)
        else:
            p0 = f.uv(r.cx, wa0)
            p1 = f.uv(r.cx, wa1)
        idx = 0 if side in ("front", "back") else 1
        a, b = sorted((p0[idx], p1[idx]))
        return a, b

    def _world_side_of_line(self, axis, fixed):
        r = self.region.rect
        if axis == "x":
            if abs(fixed - r.z0) < 0.05:
                return "z0"
            if abs(fixed - r.z1) < 0.05:
                return "z1"
        else:
            if abs(fixed - r.x0) < 0.05:
                return "x0"
            if abs(fixed - r.x1) < 0.05:
                return "x1"
        return None

    def _collect(self):
        r = self.region.rect
        for d in self.plan.doors:
            ws = self._world_side_of_line(d.axis, d.fixed)
            if ws is None:
                continue
            along0, along1 = (r.x0, r.x1) if d.axis == "x" else (r.z0, r.z1)
            h0, h1 = d.hole
            if h1 < along0 - 0.05 or h0 > along1 + 0.05:
                continue
            side = self.local_side(ws)
            a0, a1 = self._range(side, h0, h1, d.axis)
            sliding = d.kind in ("sliding", "sliding_wide")
            # 미닫이 문짝은 +z/+x(카메라 쪽) 벽면에 붙는다: 그 쪽이 이 방이면 방 안에서 벽을 따라 밀린다
            room_on_plus = (ws in ("z0", "x0"))
            op = Opening2(side, a0, a1, d.kind, sliding, sliding and room_on_plus)
            op.door = d
            if sliding:
                world_dir = d.slide_local if d.axis == "x" else -d.slide_local
                s0, s1 = (h1, h1 + d.width + 0.15) if world_dir > 0 else (h0 - d.width - 0.15, h0)
                op.slide = self._range(side, s0, s1, d.axis)
            self.doors.append(op)
        for axis, line, inward, w0, w1, y0, y1, kind in self.plan.window_log:
            ws = self._world_side_of_line(axis, line)
            if ws is None:
                continue
            along0, along1 = (r.x0, r.x1) if axis == "x" else (r.z0, r.z1)
            if w1 < along0 or w0 > along1:
                continue
            side = self.local_side(ws)
            a0, a1 = self._range(side, w0, w1, axis)
            op = Opening2(side, a0, a1, kind)
            op.y0, op.y1 = y0 - self.plan.y, y1 - self.plan.y
            self.windows.append(op)
        self._block_doors()

    def _block_doors(self):
        """문 앞 1.3m와 미닫이 이동 구간(벽을 따라 0.35m)은 가구 금지"""
        W, D = self.W, self.D
        for d in self.doors:
            pad = 0.25
            if d.side == "front":
                self.p.blocked.append((d.a0 - pad, 0.0, d.a1 + pad, 1.3))
            elif d.side == "back":
                self.p.blocked.append((d.a0 - pad, D - 1.3, d.a1 + pad, D))
            elif d.side == "left":
                self.p.blocked.append((0.0, d.a0 - pad, 1.3, d.a1 + pad))
            else:
                self.p.blocked.append((W - 1.3, d.a0 - pad, W, d.a1 + pad))
            if d.leaf_inside and hasattr(d, "slide"):
                s0, s1 = d.slide
                if d.side == "front":
                    self.p.blocked.append((s0, 0.0, s1, 0.35))
                elif d.side == "back":
                    self.p.blocked.append((s0, D - 0.35, s1, D))
                elif d.side == "left":
                    self.p.blocked.append((0.0, s0, 0.35, s1))
                else:
                    self.p.blocked.append((W - 0.35, s0, W, s1))

    def windows_on(self, side):
        return sorted([w for w in self.windows if w.side == side], key=lambda w: w.a0)

    def doors_on(self, side):
        return sorted([d for d in self.doors if d.side == side], key=lambda d: d.a0)
