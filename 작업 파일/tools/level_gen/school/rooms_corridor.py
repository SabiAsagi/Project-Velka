# -*- coding: utf-8 -*-
"""복도 소품 (학교_맵_상세.md 2-3 공용 복도 + 가이드라인 4장).
- 계단 입구마다 소화전함·소화기·층별 안내도 (개방부에서 1.5m 이상 떨어뜨림), 계단·엘리베이터 앞 2m 비움
- 엘리베이터: 층 표시기, 점검 안내문, 옆벽 짧은 대기 벤치
- 화장실 구역: 음수대(화장실과 청소도구함 사이 벽), 분리수거함, 청소 점검표, 미끄럼 주의 표지, 벽시계
- 교실 두 개마다 게시판, 자습실 앞 긴 벤치 2개, 복도 양끝 분리수거함, CCTV, 중앙 계단 부근 행사 게시판, 교실 앞 우산꽂이
모든 물건은 벽에 붙여 통행 폭을 지킨다."""
from props_base import wall_item, bench, label, facing_rows

CLASS_STYLES = ("classroom", "study", "club")


class WallPlan:
    """복도 한쪽 벽(side)의 쓸 수 있는 구간 관리"""

    def __init__(self, ctx, side):
        self.ctx, self.side = ctx, side
        self.blocked = []

    def block(self, a0, a1):
        self.blocked.append((a0, a1))

    def free(self, a0, a1):
        if a0 < 0.2 or a1 > self.ctx.D - 0.2:
            return False
        return all(a1 <= b0 or a0 >= b1 for b0, b1 in self.blocked)

    def find(self, center, width, span=4.0, step=0.1):
        """center에서 가까운 빈 자리 (없으면 None)"""
        k = 0
        while k * step <= span:
            for d in ((k * step,) if k == 0 else (k * step, -k * step)):
                c = center + d
                if self.free(c - width / 2, c + width / 2):
                    return c
            k += 1
        return None


def plan_walls(ctx):
    walls = {"left": WallPlan(ctx, "left"), "right": WallPlan(ctx, "right")}
    # 벽이 없는 구간(계단·로비 개방부)과 문·창은 쓸 수 없다
    openings = open_spans(ctx)
    for side, a0, a1, kind in openings:
        for s in ("left", "right"):
            margin = 2.0 if kind == "stair" else 0.6
            if s == side:
                walls[s].block(a0 - (1.5 if kind == "stair" else 0.3), a1 + (1.5 if kind == "stair" else 0.3))
            elif kind == "stair":
                walls[s].block(a0 - 0.3, a1 + 0.3)
    for d in ctx.doors:
        if d.side in walls:
            pad = 1.0 if d.kind == "elevator" else 0.12
            walls[d.side].block(d.a0 - pad, d.a1 + pad)
            if d.leaf_inside and hasattr(d, "slide"):
                walls[d.side].block(d.slide[0] - 0.05, d.slide[1] + 0.05)
            if d.kind == "elevator":
                other = "left" if d.side == "right" else "right"
                walls[other].block(d.a0 - 0.6, d.a1 + 0.6)
    for w in ctx.windows:
        if w.side in walls:
            walls[w.side].block(w.a0 - 0.05, w.a1 + 0.05)
    for o in ctx.plan.openings:
        ws = ctx._world_side_of_line(o.axis, o.fixed)
        side = ctx.local_side(ws) if ws else None
        if side in walls:
            a0, a1 = ctx._range(side, o.a0, o.a1, o.axis)
            walls[side].block(a0 - 0.15, a1 + 0.15)
    return walls, openings


def open_spans(ctx):
    """복도 벽선에서 벽 없이 열린 구간 [(side, a0, a1, kind)]: 계단·로비·통로"""
    plan, reg = ctx.plan, ctx.region
    out = []
    for ax, f, a0, a1, lo, hi in plan.grid.boundaries():
        if lo != reg.id and hi != reg.id:
            continue
        other_id = hi if lo == reg.id else lo
        if other_id < 0:
            continue
        other = plan.regions[other_id]
        from plan import boundary_type
        if boundary_type(reg, other) != "open":
            continue
        ws = ctx._world_side_of_line(ax, f)
        if ws is None:
            continue
        side = ctx.local_side(ws)
        if side not in ("left", "right"):
            continue
        b0, b1 = ctx._range(side, a0, a1, ax)
        kind = "stair" if other.kind == "stair" else other.kind
        if out and out[-1][0] == side and out[-1][3] == kind and abs(out[-1][2] - b0) < 0.05:
            out[-1] = (side, out[-1][1], b1, kind)
        else:
            out.append((side, b0, b1, kind))
    return out


def _hydrant(p, W, D, side, a, toward):
    wall_item(p, W, D, side, a, 0.7, 0.0, 0.2, 0.9, 1.95, "hydrant_box", collide=True)
    wall_item(p, W, D, side, a, 0.52, 0.2, 0.004, 1.05, 1.8, "hydrant_door")
    wall_item(p, W, D, side, a + toward * 0.6, 0.17, 0.04, 0.17, 0.0, 0.56, "extinguisher")
    wall_item(p, W, D, side, a + toward * 0.6, 0.09, 0.08, 0.09, 0.56, 0.66, "metal_dark")


def corridor(ctx, level_name, room_of_door, pre=None):
    """pre(ctx, walls): 층별 고정 소품(자판기 등)을 먼저 놓고 벽 구간을 막는 콜백"""
    p, W, D = ctx.p, ctx.W, ctx.D
    walls, openings = plan_walls(ctx)
    groups = list(ctx.groups) or None
    stairs = [(side, a0, a1) for side, a0, a1, kind in openings if kind == "stair"]
    if pre is not None:
        pre(ctx, walls)
    # 1. 계단 입구: 소화전함·소화기 + 층별 안내도 (개방부에서 1.5m 이상). 계단 쪽 벽에 자리가 없으면 맞은편 벽
    for side, a0, a1 in stairs:
        toward = 1 if (a0 + a1) / 2 < D / 2 else -1
        edge = a1 if toward > 0 else a0
        c = walls[side].find(edge + toward * 1.95, 1.4, span=3.0)
        if c is None:
            side = "left" if side == "right" else "right"
            c = walls[side].find(edge + toward * 0.6, 1.4, span=3.0)
        if c is not None:
            _hydrant(p, W, D, side, c, toward)
            walls[side].block(min(c - 0.45 * toward, c + 0.9 * toward), max(c - 0.45 * toward, c + 0.9 * toward))
            m = walls[side].find(c + toward * 1.25, 0.7, span=1.5)
            if m is not None:
                wall_item(p, W, D, side, m, 0.62, 0.0, 0.02, 1.2, 1.85, "frame_alu")
                wall_item(p, W, D, side, m, 0.56, 0.02, 0.004, 1.24, 1.81, "floor_map")
                walls[side].block(m - 0.35, m + 0.35)
    _elevator(ctx, walls, level_name, groups)
    _toilet_zone(ctx, walls, room_of_door)
    _class_fronts(ctx, walls, room_of_door)
    _ends_and_extras(ctx, walls, stairs, level_name, groups)


def _elevator(ctx, walls, level_name, groups):
    """층 표시기·점검 안내문, 옆 벽 짧은 대기 벤치"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for d in ctx.doors:
        if d.kind != "elevator":
            continue
        wall_item(p, W, D, d.side, d.mid, 0.36, 0.0, 0.04, 2.3, 2.46, "tv")
        x, z = ctx.frame.pt(W - 0.05 if d.side == "right" else 0.05, d.mid)
        label(ctx.sw, ctx.container, (x, ctx.y + 2.38, z), level_name, 0.003, 36, (0.95, 0.5, 0.2),
              facing_rows(ctx.frame, "left" if d.side == "right" else "right"), groups)
        wall_item(p, W, D, d.side, d.a1 + 0.55, 0.21, 0.0, 0.004, 1.35, 1.65, "paper_yellow")
        b = walls[d.side].find(d.a1 + 2.3, 1.1, span=1.5)
        if b is None:
            b = walls[d.side].find(d.a0 - 2.3, 1.1, span=1.5)
        if b is not None:
            u = 0.3 if d.side == "left" else W - 0.3
            bench(p, u, b, 1.0, along_u=False)
            walls[d.side].block(b - 0.6, b + 0.6)


def _toilet_zone(ctx, walls, room_of_door):
    """음수대(화장실과 청소도구함 사이 벽), 청소 점검표, 미끄럼 주의 표지, 벽시계"""
    p, W, D = ctx.p, ctx.W, ctx.D
    toilets = [d for d in ctx.doors if room_of_door(d) == "toilet"]
    closets = [d for d in ctx.doors if room_of_door(d) == "closet"]
    if not toilets:
        return
    for d in toilets:
        a = d.a1 + 0.35 if walls[d.side].free(d.a1 + 0.2, d.a1 + 0.5) else d.a0 - 0.35
        wall_item(p, W, D, d.side, a, 0.21, 0.0, 0.004, 1.35, 1.65, "paper")
    d0 = toilets[0]
    a = d0.mid + (1.3 if d0.mid < D / 2 else -1.3)
    u = 0.45 if d0.side == "left" else W - 0.45
    p.box("wet_sign", u, a, 0.3, 0.05, 0.0, 0.6, yaw=20.0)
    if closets:
        c = closets[0]
        near = min(toilets, key=lambda t: abs(t.mid - c.mid))
        f = walls[c.side].find((c.mid + near.mid) / 2, 0.5, span=1.2)
        if f is not None:
            wall_item(p, W, D, c.side, f, 0.45, 0.0, 0.4, 0.0, 1.05, "purifier", collide=True)
            wall_item(p, W, D, c.side, f, 0.3, 0.1, 0.28, 0.85, 0.92, "metal_dark")
            walls[c.side].block(f - 0.3, f + 0.3)
    t = toilets[0]
    wall_item(p, W, D, t.side, t.mid, 0.3, 0.0, 0.05, 2.5, 2.8, "clock_rim")
    wall_item(p, W, D, t.side, t.mid, 0.24, 0.05, 0.01, 2.53, 2.77, "clock_face")


def _class_fronts(ctx, walls, room_of_door):
    """두 반마다 게시판, 교실 앞문 옆 우산꽂이, 자습실 앞 긴 벤치 2개"""
    p, W, D = ctx.p, ctx.W, ctx.D
    rooms = {}
    for d in ctx.doors:
        if room_of_door(d) in CLASS_STYLES:
            rooms.setdefault((d.door.room, d.side), []).append(d)
    ordered = sorted(rooms.items(), key=lambda kv: min(x.a0 for x in kv[1]))
    for i, ((name, side), ds) in enumerate(ordered):
        ds.sort(key=lambda x: x.a0)
        st = room_of_door(ds[0])
        u_wall = 0.3 if side == "left" else W - 0.3
        if st == "study" and len(ds) >= 2:
            g0, g1 = ds[0].a1, ds[-1].a0
            for k in (1, 2):
                c = walls[side].find(g0 + (g1 - g0) * k / 3, 1.9, span=1.0)
                if c is not None:
                    bench(p, u_wall, c, 1.8, along_u=False)
                    walls[side].block(c - 1.0, c + 1.0)
            continue
        if st == "classroom" and i % 2 == 0 and len(ds) >= 2:
            bs = side if ctx.visible_side(side) else ("right" if side == "left" else "left")
            c = walls[bs].find((ds[0].a1 + ds[-1].a0) / 2, 1.3, span=3.0)
            if c is not None:
                wall_item(p, W, D, bs, c, 1.2, 0.0, 0.02, 1.1, 1.95, "cork")
                for k, m in enumerate(("paper", "paper_blue", "paper_yellow")):
                    wall_item(p, W, D, bs, c - 0.4 + 0.4 * k, 0.21, 0.02, 0.004, 1.25 + 0.08 * (k % 2), 1.55 + 0.08 * (k % 2), m)
                walls[bs].block(c - 0.7, c + 0.7)
        if st == "classroom":
            front = ds[0]
            ua = walls[side].find(front.a1 + 0.4, 0.36, span=0.8)
            if ua is not None:
                u = 0.2 if side == "left" else W - 0.2
                p.box("bin_gray", u, ua, 0.3, 0.3, 0.0, 0.6)
                for k in range(3):
                    p.box("umbrella", u - 0.06 + 0.06 * k, ua, 0.04, 0.04, 0.3, 0.95 + 0.05 * k)
                walls[side].block(ua - 0.2, ua + 0.2)


def _ends_and_extras(ctx, walls, stairs, level_name, groups):
    """복도 양끝 분리수거함, CCTV, 중앙 계단 맞은편 행사 게시판·층 표시, 복도 끝 창가 화분"""
    p, W, D = ctx.p, ctx.W, ctx.D
    for a in (1.2, D - 1.2):
        for side in ("left", "right"):
            c = walls[side].find(a, 1.2, span=2.0)
            if c is not None:
                for k, m in enumerate(("bin_blue", "bin_yellow", "bin_gray")):
                    wall_item(p, W, D, side, c - 0.4 + 0.4 * k, 0.34, 0.02, 0.34, 0.0, 0.58, m)
                walls[side].block(c - 0.62, c + 0.62)
                break
    for k in (1, 2, 3):
        side = "right" if k % 2 else "left"
        wall_item(p, W, D, side, D * k / 4, 0.12, 0.0, 0.18, 3.05, 3.2, "cctv")
    center = [s for s in stairs if abs((s[1] + s[2]) / 2 - D / 2) < D * 0.2]
    if center:
        side0, a0, a1 = center[0]
        other = "left" if side0 == "right" else "right"
        bw = 1.9
        c = walls[other].find((a0 + a1) / 2, bw + 0.1, span=3.0)
        if not ctx.visible_side(other):
            # 맞은편 벽이 카메라에서 안 보이면 계단과 같은 쪽 벽에서 가장 가까운 빈 자리에 건다 (좁으면 작은 판)
            other, c = side0, None
            for bw in (1.9, 1.4, 1.0):
                c = walls[other].find((a0 + a1) / 2, bw + 0.1, span=D / 2)
                if c is not None:
                    break
        if c is not None:
            ctx.anchor("notice", W - 0.03 if other == "right" else 0.03, c, W - 0.85 if other == "right" else 0.85, c)
            wall_item(p, W, D, other, c, bw, 0.0, 0.02, 1.05, 2.05, "cork")
            n = max(2, int(bw / 0.38))
            for k in range(n):
                m = ("art_red", "paper", "art_blue", "paper_yellow", "art_green")[k % 5]
                wall_item(p, W, D, other, c - bw / 2 + bw * (k + 0.5) / n, 0.28, 0.02, 0.004, 1.2 + 0.1 * (k % 3), 1.6 + 0.1 * (k % 3), m)
            walls[other].block(c - bw / 2 - 0.1, c + bw / 2 + 0.1)
            x, z = ctx.frame.pt(W - 0.03 if other == "right" else 0.03, c)
            label(ctx.sw, ctx.container, (x, ctx.y + 2.45, z), level_name, 0.009, 64, (0.18, 0.32, 0.36),
                  facing_rows(ctx.frame, "left" if other == "right" else "right"), groups)
    from props_base import plant
    placed = 0
    for w in ctx.windows:
        if w.side in ("front", "back") and placed < 4:
            v = 0.3 if w.side == "front" else D - 0.3
            for k in range(2):
                plant(p, w.a0 + 0.3 + (w.a1 - w.a0 - 0.6) * k, v, 0.0, 0.3)
                placed += 1
