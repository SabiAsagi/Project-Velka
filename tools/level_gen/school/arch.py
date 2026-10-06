# -*- coding: utf-8 -*-
"""건축 요소 (생성기 v2): 격자 경계에서 벽 유도(양면 마감 두 겹), 문·창 구멍, 창문 3종, 슬래브, 난간.

모든 면은 서로 등지게만 맞닿도록 쌓는다 (같은 방향 면이 같은 평면에서 겹치지 않게 = 깜빡임 없음).
- 칸막이: 경계선 양쪽으로 0.075씩 (각 방의 마감 재질)
- 외벽: 외곽선 안쪽으로 0.15(외장) + 0.10(실내 마감). 외장은 슬래브 가장자리를 덮도록 바닥 아래 0.2까지
- 슬래브: 외장 안쪽 전체, 방마다 바닥 재질이 다른 조각
"""
from plan import boundary_type, FACADE_T, INNER_T, PART_T, WALL_H, SLAB
from geometry import Rect, subtract

EXT_T = FACADE_T + INNER_T
HALF = PART_T / 2

# 방 양식 -> 실내 벽 마감 / 바닥 재질
FINISH = {
    "classroom": "wall_class", "study": "wall_class", "club": "wall_class", "council": "wall_class", "art": "wall_class",
    "science": "wall_class", "computer": "wall_class", "group_study": "wall_class", "shop": "wall_class",
    "office": "wall_office", "admin": "wall_office", "principal": "wall_office", "guard": "wall_office", "staff": "wall_office",
    "prep_music": "wall_office", "prep_art": "wall_office", "prep_science": "wall_office", "prep_computer": "wall_office",
    "book_work": "wall_office", "stacks": "wall_office", "copy": "wall_office", "props_room": "wall_office",
    "nurse": "wall_nurse", "broadcast": "wall_acoustic", "music": "wall_acoustic", "sound_room": "wall_acoustic",
    "toilet": "wall_tile", "changing": "wall_tile_light", "kitchen": "wall_tile", "wash": "wall_tile", "food_storage": "wall_tile",
    "closet": "wall_concrete", "storage": "wall_concrete", "elevator": "wall_concrete",
    "corridor": "wall_corridor", "stair": "wall_corridor", "stair_hall": "wall_corridor", "passage": "wall_corridor",
    "alcove": "wall_corridor", "bridge": "wall_corridor", "lobby": "wall_lobby", "hall": "wall_lobby",
    "cafeteria": "wall_cafeteria", "library": "wall_library", "old_library": "wall_b1",
    "court": "wall_gym", "seating": "wall_gym", "void": "wall_gym", "void_room": "wall_gym", "stage": "wall_stage",
    "stage_stair": "wall_stage", "stage_upper": "wall_stage", "roof": "parapet_in", "roof_room": "wall_concrete",
}
FLOOR = {
    "classroom": "floor_class", "study": "floor_class", "club": "floor_class", "council": "floor_class", "art": "floor_class",
    "science": "floor_lab", "computer": "floor_office", "group_study": "floor_class", "shop": "floor_lobby",
    "office": "floor_office", "admin": "floor_office", "principal": "floor_wood", "guard": "floor_office", "staff": "floor_office",
    "prep_music": "floor_office", "prep_art": "floor_office", "prep_science": "floor_lab", "prep_computer": "floor_office",
    "book_work": "floor_office", "stacks": "floor_office", "copy": "floor_office", "props_room": "floor_office",
    "nurse": "floor_nurse", "broadcast": "floor_carpet", "music": "floor_wood", "sound_room": "floor_office",
    "toilet": "floor_toilet", "changing": "floor_toilet", "kitchen": "floor_kitchen", "wash": "floor_kitchen",
    "food_storage": "floor_kitchen", "closet": "floor_concrete", "storage": "floor_concrete", "elevator": "floor_concrete",
    "corridor": "floor_corridor", "stair": "floor_corridor", "stair_hall": "floor_corridor", "passage": "floor_lobby",
    "alcove": "floor_corridor", "bridge": "floor_bridge", "lobby": "floor_lobby", "hall": "floor_lobby",
    "cafeteria": "floor_cafeteria", "library": "floor_carpet", "old_library": "floor_b1_old",
    "court": "floor_gym", "seating": "floor_concrete", "stage": "floor_stage", "stage_stair": "floor_stage",
    "roof": "floor_roof", "roof_room": "floor_concrete",
}
B1_FINISH = {"old_library": "wall_b1_flood"}      # 구 도서관: 무릎 높이 물 자국선이 남은 벽
FACADE = {"main": "facade_main", "annex": "facade_annex", "gym": "facade_gym"}

# 창문 종류: A 큰 외부창 / C 높은 좁은 반투명창 / S 계단참 큰 창 / E 복도 끝 창 / G 강당 고창 / N 없음
WINDOW_OF = {
    "classroom": "A", "study": "A", "club": "A", "council": "A", "art": "A", "science": "A", "computer": "A",
    "group_study": "A", "office": "A", "admin": "A", "principal": "A", "guard": "A", "staff": "A", "nurse": "A",
    "broadcast": "A", "music": "A", "library": "A", "cafeteria": "A", "kitchen": "A", "lobby": "A", "hall": "A",
    "book_work": "A", "copy": "A", "shop": "C", "prep_music": "C", "prep_art": "C", "prep_science": "C",
    "prep_computer": "C", "stacks": "C", "toilet": "C", "changing": "C", "closet": "C", "storage": "C", "wash": "C",
    "food_storage": "C", "props_room": "C", "sound_room": "C", "stair": "S", "corridor": "E", "passage": "E",
    "stair_hall": "S", "alcove": "C", "court": "N", "seating": "G", "elevator": "N", "stage": "N", "stage_stair": "N",
    "stage_upper": "N", "void_room": "N", "void": "N", "roof_room": "C",
}


def facade_of(plan):
    """외벽 바깥 마감. 본관 지하는 땅에 묻힌 콘크리트 기초 (고지대가 숨겨질 때만 보인다)"""
    if plan.building == "main" and plan.name == "B1":
        return "facade_b1"
    return FACADE[plan.building]


def finish_of(plan, region):
    if region is None:
        return facade_of(plan)
    if plan.building == "main" and plan.name == "B1":
        return B1_FINISH.get(region.style, "wall_b1")
    return FINISH.get(region.style, "wall_office")


def floor_of(plan, region):
    if plan.building == "main" and plan.name == "B1":
        return "floor_b1_old" if region.style == "old_library" else "floor_b1"
    return FLOOR.get(region.style, "floor_office")


# ------------------------------------------------------------------ 구멍 난 벽 조각내기

def split_layer(a0, a1, y0, y1, holes):
    """[a0,a1]x[y0,y1] 면에서 구멍 [(h0,h1,hy0,hy1)]을 뺀 사각형들 (열 단위로 자른 뒤 같은 열끼리 병합)"""
    cuts = {a0, a1}
    hs = []
    for h0, h1, hy0, hy1 in holes:
        h0, h1 = max(h0, a0), min(h1, a1)
        hy0, hy1 = max(hy0, y0), min(hy1, y1)
        if h1 - h0 > 1e-4 and hy1 - hy0 > 1e-4:
            hs.append((h0, h1, hy0, hy1))
            cuts |= {h0, h1}
    xs = sorted(cuts)
    cols = []
    for i in range(len(xs) - 1):
        c0, c1 = xs[i], xs[i + 1]
        if c1 - c0 < 1e-4:
            continue
        mid = (c0 + c1) / 2
        spans = [(y0, y1)]
        for h0, h1, hy0, hy1 in hs:
            if h0 < mid < h1:
                nxt = []
                for s0, s1 in spans:
                    if hy1 <= s0 or hy0 >= s1:
                        nxt.append((s0, s1))
                        continue
                    if hy0 - s0 > 1e-4:
                        nxt.append((s0, hy0))
                    if s1 - hy1 > 1e-4:
                        nxt.append((hy1, s1))
                spans = nxt
        spans = tuple((round(s0, 5), round(s1, 5)) for s0, s1 in spans)
        if cols and cols[-1][2] == spans and abs(cols[-1][1] - c0) < 1e-6:
            cols[-1] = (cols[-1][0], c1, spans)
        else:
            cols.append((c0, c1, spans))
    out = []
    for c0, c1, spans in cols:
        for s0, s1 in spans:
            out.append((c0, c1, s0, s1))
    return out


def emit_layer(batch, container, mat, axis, t0, t1, a0, a1, y0, y1, holes, groups=(), tag="wall"):
    """두께 [t0,t1] (벽 법선 방향 절대 좌표) 한 겹을 구멍을 피해 박스로 낸다 (충돌 없음)."""
    for c0, c1, s0, s1 in split_layer(a0, a1, y0, y1, holes):
        if axis == "x":
            center = ((c0 + c1) / 2, (s0 + s1) / 2, (t0 + t1) / 2)
            size = (c1 - c0, s1 - s0, t1 - t0)
        else:
            center = ((t0 + t1) / 2, (s0 + s1) / 2, (c0 + c1) / 2)
            size = (t1 - t0, s1 - s0, c1 - c0)
        batch.box(container, mat, center, size, collide=False, groups=groups, tag=tag)


def emit_collision(batch, container, axis, t0, t1, a0, a1, y0, y1, holes, groups=()):
    for c0, c1, s0, s1 in split_layer(a0, a1, y0, y1, holes):
        if axis == "x":
            batch.solid(container, ((c0 + c1) / 2, (s0 + s1) / 2, (t0 + t1) / 2), (c1 - c0, s1 - s0, t1 - t0), groups, "wall")
        else:
            batch.solid(container, ((t0 + t1) / 2, (s0 + s1) / 2, (c0 + c1) / 2), (t1 - t0, s1 - s0, c1 - c0), groups, "wall")


# ------------------------------------------------------------------ 창문

def _free_spans(s0, s1, blocked, margin_end=0.35, margin_hole=0.3):
    """[s0,s1]에서 막힌 구간을 뺀 창 배치 가능 구간"""
    spans = [(s0 + margin_end, s1 - margin_end)]
    for b0, b1 in blocked:
        b0, b1 = b0 - margin_hole, b1 + margin_hole
        nxt = []
        for a0, a1 in spans:
            if b1 <= a0 or b0 >= a1:
                nxt.append((a0, a1))
                continue
            if b0 - a0 > 0.05:
                nxt.append((a0, b0))
            if a1 - b1 > 0.05:
                nxt.append((b1, a1))
        spans = nxt
    return [(a0, a1) for a0, a1 in spans if a1 - a0 > 0.5]


def window_layout(kind, spans):
    """창 종류별 배치 [(w0, w1, sill, head, glass)] (sill/head는 층 바닥 기준)"""
    out = []
    for a0, a1 in spans:
        L = a1 - a0
        if kind == "A":
            n = int((L + 0.5) // 2.3)
            if n == 0 and L >= 1.2:
                out.append((a0 + 0.1, a1 - 0.1, 0.9, 2.4, "glass"))
            for i in range(n):
                slot = L / n
                w = min(1.8, slot - 0.5)
                c = a0 + slot * (i + 0.5)
                out.append((c - w / 2, c + w / 2, 0.9, 2.4, "glass"))
        elif kind == "C" and L >= 1.0:
            n = max(1, int(L // 2.8))
            for i in range(n):
                c = a0 + L * (i + 0.5) / n
                out.append((c - 0.4, c + 0.4, 1.75, 2.35, "glass_frosted"))
        elif kind == "S" and L >= 1.2:
            w = min(L - 0.4, 2.6)
            c = (a0 + a1) / 2
            out.append((c - w / 2, c + w / 2, 1.2, 3.3, "glass"))
        elif kind == "T" and L >= 1.2:
            # 되돌이 계단의 중간참(층 바닥 + 1.9m) 위로 난 창
            w = min(L - 0.4, 2.6)
            c = (a0 + a1) / 2
            out.append((c - w / 2, c + w / 2, 2.15, 3.35, "glass"))
        elif kind == "E" and L >= 1.0:
            w = min(L - 0.3, 1.8)
            c = (a0 + a1) / 2
            out.append((c - w / 2, c + w / 2, 0.9, 2.4, "glass"))
        elif kind == "B" and L >= 1.4:
            n = min(3, max(1, int(L // 1.9)))
            for i in range(n):
                c = a0 + L * (i + 0.5) / n
                out.append((c - 0.5, c + 0.5, 1.45, 2.05, "glass"))
        elif kind == "G" and L >= 2.0:
            n = max(1, int((L + 1.0) // 3.4))
            for i in range(n):
                slot = L / n
                c = a0 + slot * (i + 0.5)
                w = min(2.4, slot - 1.0)
                out.append((c - w / 2, c + w / 2, 3.4, 5.9, "glass"))
    return out


def emit_window(batch, container, axis, t_lo, t_hi, w0, w1, y0, y1, glass, inside_sign=0, groups=(), sills=True, outer_sill=True):
    """창 구멍 안의 틀·유리·창턱. inside_sign: 실내가 법선 +쪽이면 +1, -쪽이면 -1, 0이면 창턱 없음."""
    tc = (t_lo + t_hi) / 2
    frame = "win_frame_new" if int(abs(w0 * 7.3 + y0 * 3.1)) % 7 == 0 else "win_frame"
    fd = min(0.08, (t_hi - t_lo) - 0.04)
    p = 0.05
    w, h = w1 - w0, y1 - y0

    def box(mat, a0, a1, b0, b1, d0, d1, grp=groups, tag="window"):
        if axis == "x":
            batch.box(container, mat, ((a0 + a1) / 2, (b0 + b1) / 2, (d0 + d1) / 2), (a1 - a0, b1 - b0, d1 - d0), False, grp, tag)
        else:
            batch.box(container, mat, ((d0 + d1) / 2, (b0 + b1) / 2, (a0 + a1) / 2), (d1 - d0, b1 - b0, a1 - a0), False, grp, tag)

    box(frame, w0, w0 + p, y0, y1, tc - fd / 2, tc + fd / 2)
    box(frame, w1 - p, w1, y0, y1, tc - fd / 2, tc + fd / 2)
    box(frame, w0 + p, w1 - p, y0, y0 + p, tc - fd / 2, tc + fd / 2)
    box(frame, w0 + p, w1 - p, y1 - p, y1, tc - fd / 2, tc + fd / 2)
    if w > 1.2:
        m = (w0 + w1) / 2
        box(frame, m - 0.022, m + 0.022, y0 + p, y1 - p, tc - fd / 2 + 0.008, tc + fd / 2 - 0.008)
    if h > 1.6 and glass == "glass":
        ty = y1 - (h - 2 * p) * 0.28
        box(frame, w0 + p, w1 - p, ty - 0.02, ty + 0.02, tc - fd / 2 + 0.018, tc + fd / 2 - 0.018)
    box(glass, w0 + p, w1 - p, y0 + p, y1 - p, tc - 0.006, tc + 0.006, tuple(groups) + ("window_pane",), "glass")
    if inside_sign:
        face = t_hi if inside_sign > 0 else t_lo
        out_face = t_lo if inside_sign > 0 else t_hi
        d = inside_sign
        # 실내 창턱 (화분 올리는 자리)과 바깥 물끊기
        if sills:
            box("sill", w0 - 0.06, w1 + 0.06, y0 - 0.04, y0 + 0.015, min(face, face + d * 0.17), max(face, face + d * 0.17))
        if outer_sill:
            box("sill_out", w0 - 0.04, w1 + 0.04, y0 - 0.07, y0 - 0.02, min(out_face, out_face - d * 0.07), max(out_face, out_face - d * 0.07))


# ------------------------------------------------------------------ 벽 유도

DOOR_KIND_ENUM = {"sliding": 0, "sliding_wide": 0, "metal": 1, "opaque": 2, "thick": 3, "glass2": 4, "glass_entry": 4, "fire2": 5}
CORRIDOR_WINDOW = {"classroom", "study", "club", "council", "guard", "library",
                   "prep_music", "prep_art", "prep_science", "prep_computer"}


class Ctx:
    """한 층(또는 이계 연장 구역)을 지을 때 필요한 것들"""

    def __init__(self, plan, batch, sw, res, arch_path, door_path, groups=()):
        self.plan, self.batch, self.sw, self.res = plan, batch, sw, res
        self.arch, self.doors = arch_path, door_path
        self.groups = tuple(groups)
        self.segs = plan.grid.boundaries()

    def doors_on(self, axis, fixed):
        """선 위의 문 (좌표 반올림 차이 없이 거리로 비교)"""
        return [d for d in self.plan.doors if d.axis == axis and abs(d.fixed - fixed) < 1e-3]

    def region(self, rid):
        return self.plan.regions[rid] if rid >= 0 else None


def _door_hole(plan, d):
    h0, h1 = d.hole
    y0 = plan.y + d.floor_dy
    return (h0, h1, y0, y0 + d.height + 0.04, True)


def line_holes(ctx, axis, fixed, a0, a1):
    """선 위 [a0,a1] 구간의 문·개구부 구멍 [(h0,h1,y0,y1,passable)] (절대 높이)"""
    plan = ctx.plan
    out = []
    for d in ctx.doors_on(axis, fixed):
        h = _door_hole(plan, d)
        if h[1] > a0 and h[0] < a1:
            out.append(h)
    for o in plan.openings:
        if o.axis == axis and abs(o.fixed - fixed) < 1e-3 and o.a1 > a0 and o.a0 < a1:
            y0 = plan.y - SLAB if o.y0 is None else plan.y + o.y0
            y1 = plan.wall_top + 1.0 if o.y1 is None else plan.y + o.y1
            out.append((o.a0, o.a1, y0, y1, o.y0 is None or o.y0 < 0.3))
    return out


def _fill_openings(ctx, axis, fixed, a0, a1, layers):
    """filler_groups가 있는 개구부는 그 그룹 전용 벽으로 막는다 (현실에서만 막힌 벽)."""
    plan = ctx.plan
    for o in plan.openings:
        if not o.filler_groups or o.axis != axis or abs(o.fixed - fixed) > 1e-3:
            continue
        f0, f1 = max(o.a0, a0), min(o.a1, a1)
        if f1 - f0 < 1e-3:
            continue
        for t0, t1, mat, y0, y1 in layers:
            emit_layer(ctx.batch, ctx.arch, mat, axis, t0, t1, f0, f1, y0, y1, [], ctx.groups + o.filler_groups, "filler")
        t_lo, t_hi = min(l[0] for l in layers), max(l[1] for l in layers)
        emit_collision(ctx.batch, ctx.arch, axis, t_lo, t_hi, f0, f1, plan.y, plan.wall_top, [], ctx.groups + o.filler_groups)


def build_exterior(ctx):
    """외벽 네 변. 모서리: x방향 변의 외장이 모서리를 덮고, z방향 변은 외장 두께만큼 물러선다 (면 겹침 없음)."""
    plan = ctx.plan
    fp = plan.footprint
    y, top = plan.y, plan.wall_top
    if plan.exterior == "parapet":
        top = y + getattr(plan, "parapet_h", 1.1)
    sides = [("x", fp.z0, +1, (fp.x0, fp.x1), (fp.x0 + FACADE_T, fp.x1 - FACADE_T)),
             ("x", fp.z1, -1, (fp.x0, fp.x1), (fp.x0 + FACADE_T, fp.x1 - FACADE_T)),
             ("z", fp.x0, +1, (fp.z0 + FACADE_T, fp.z1 - FACADE_T), (fp.z0 + EXT_T, fp.z1 - EXT_T)),
             ("z", fp.x1, -1, (fp.z0 + FACADE_T, fp.z1 - FACADE_T), (fp.z0 + EXT_T, fp.z1 - EXT_T))]
    for axis, line, inward, (fa0, fa1), (ia0, ia1) in sides:
        pieces = []
        for ax, f, s0, s1, lo, hi in ctx.segs:
            if ax != axis or abs(f - line) > 1e-3:
                continue
            rid, other = (hi, lo) if inward > 0 else (lo, hi)
            if other >= 0 or rid < 0:
                continue
            pieces.append([s0, s1, ctx.region(rid)])
        if not pieces:
            continue
        pieces.sort(key=lambda p: p[0])
        pieces[0][0] = min(pieces[0][0], fa0)
        pieces[-1][1] = max(pieces[-1][1], fa1)
        facade = (line, line + inward * FACADE_T)
        inner = (line + inward * FACADE_T, line + inward * EXT_T)
        f_lo, f_hi = min(facade), max(facade)
        i_lo, i_hi = min(inner), max(inner)
        holes = line_holes(ctx, axis, line, fa0, fa1)
        wins = []
        if plan.windows and plan.exterior == "wall":
            blocked = [(h[0], h[1]) for h in holes]
            for s0, s1, reg in pieces:
                kind = WINDOW_OF.get(reg.style, "A")
                if plan.building == "main" and plan.name == "B1":
                    kind = "N"
                if plan.building == "gym" and plan.index == 1 and kind != "N":
                    kind = "G"
                if (axis, round(line, 3)) in getattr(plan, "no_window_lines", set()):
                    kind = "N"
                if kind == "S" and reg.kind == "stair" and "중앙" not in reg.name:
                    kind = "T"
                c = plan.corridor()
                if c is not None and reg.kind == "room" and kind in ("A", "C"):
                    long_x = c.w >= c.d
                    end_wall = (axis == "z") if long_x else (axis == "x")
                    if end_wall and reg.style in ("classroom", "study", "club", "music", "art", "science", "computer", "library"):
                        kind = "N"
                if kind == "N":
                    continue
                s0c, s1c = max(s0, ia0), min(s1, ia1)
                for w0, w1, sill, head, glass in window_layout(kind, _free_spans(s0c, s1c, blocked)):
                    wins.append((w0, w1, y + sill, y + head, glass, kind))
        cut = [(h[0], h[1], h[2], h[3]) for h in holes] + [(w[0], w[1], w[2], w[3]) for w in wins]
        emit_layer(ctx.batch, ctx.arch, facade_of(plan), axis, f_lo, f_hi, fa0, fa1, y - SLAB, top, cut, ctx.groups, "facade")
        for s0, s1, reg in pieces:
            s0c, s1c = max(s0, ia0), min(s1, ia1)
            if s1c - s0c > 1e-3:
                base = y - SLAB if reg.no_floor else y
                emit_layer(ctx.batch, ctx.arch, finish_of(plan, reg), axis, i_lo, i_hi, s0c, s1c, base, top, cut, ctx.groups, "inner")
        passable = [(h[0], h[1], h[2], h[3]) for h in holes if h[4]]
        emit_collision(ctx.batch, ctx.arch, axis, min(f_lo, i_lo), max(f_hi, i_hi), fa0, fa1, y, max(top, y + 1.2), passable, ctx.groups)
        _fill_openings(ctx, axis, line, fa0, fa1, [(f_lo, f_hi, facade_of(plan), y - SLAB, top),
                                                    (i_lo, i_hi, finish_of(plan, pieces[0][2]), y, top)])
        if plan.exterior == "parapet":
            for s0, s1, reg in pieces:
                if reg.kind != "roof_room" or plan.wall_top <= top + 1e-3:
                    continue
                # 난간 덮개(두께 0.08) 위에서부터 쌓는다
                emit_layer(ctx.batch, ctx.arch, FACADE[plan.building], axis, f_lo, f_hi, s0, s1, top + 0.08, plan.wall_top, [], ctx.groups, "facade")
                emit_layer(ctx.batch, ctx.arch, finish_of(plan, reg), axis, i_lo, i_hi, s0, s1, top + 0.08, plan.wall_top, [], ctx.groups, "inner")
                emit_collision(ctx.batch, ctx.arch, axis, min(f_lo, i_lo), max(f_hi, i_hi), s0, s1, top, plan.wall_top, [], ctx.groups)
            c_lo, c_hi = min(f_lo, i_lo) - 0.03, max(f_hi, i_hi) + 0.03
            if axis == "x":
                ctx.batch.box(ctx.arch, "coping", ((fa0 + fa1) / 2, top + 0.04, (c_lo + c_hi) / 2),
                              (fa1 - fa0 + 0.06, 0.08, c_hi - c_lo), False, ctx.groups, "coping")
            else:
                z0, z1 = fp.z0 + EXT_T + 0.03, fp.z1 - EXT_T - 0.03
                ctx.batch.box(ctx.arch, "coping", ((c_lo + c_hi) / 2, top + 0.04, (z0 + z1) / 2),
                              (c_hi - c_lo, 0.08, z1 - z0), False, ctx.groups, "coping")
        for w0, w1, wy0, wy1, glass, kind in wins:
            plan.window_log.append((axis, line, inward, w0, w1, wy0, wy1, kind))
        outer = (axis, round(line, 3)) not in getattr(plan, "no_outer_sill", set())
        for w0, w1, wy0, wy1, glass, kind in wins:
            emit_window(ctx.batch, ctx.arch, axis, min(f_lo, i_lo), max(f_hi, i_hi), w0, w1, wy0, wy1, glass, inward, ctx.groups,
                        sills=kind == "A", outer_sill=outer)


def _merge_runs(items):
    """[(a0, a1, payload)] -> 이어진 구간 [(a0, a1, [payload...])]"""
    items = sorted(items, key=lambda t: t[0])
    runs = []
    for a0, a1, p in items:
        if runs and a0 <= runs[-1][1] + 1e-3:
            runs[-1][1] = max(runs[-1][1], a1)
            runs[-1][2].append((a0, a1, p))
        else:
            runs.append([a0, a1, [(a0, a1, p)]])
    return runs


def build_interior(ctx):
    plan = ctx.plan
    fp = plan.footprint
    y, top = plan.y, plan.wall_top
    lines = {}
    rails = {}
    for ax, f, a0, a1, lo, hi in ctx.segs:
        if lo < 0 or hi < 0:
            continue
        ra, rb = ctx.region(lo), ctx.region(hi)
        t = boundary_type(ra, rb)
        if t == "wall":
            lines.setdefault((ax, round(f, 4)), []).append((a0, a1, (ra, rb)))
        elif t == "rail":
            rails.setdefault((ax, round(f, 4)), []).append((a0, a1, (ra, rb)))
    runs = {key: _merge_runs(items) for key, items in lines.items()}

    def cover(axis, f, a):
        """axis 방향 벽선 f 위에서 a 지점: 'through' / 'end' / None"""
        for r0, r1, _ in runs.get((axis, round(f, 4)), []):
            if r0 + 1e-3 < a < r1 - 1e-3:
                return "through"
            if abs(a - r0) < 1e-3 or abs(a - r1) < 1e-3:
                return "end"
        return None

    ext_x = (fp.x0, fp.x1)
    ext_z = (fp.z0, fp.z1)
    for (axis, fkey), rlist in runs.items():
        f = float(fkey)
        for r0, r1, segs in rlist:
            pieces = [(r0, r1)]
            if axis == "z":
                # x벽이 가로지르는 곳에서 자른다
                cuts = sorted(float(k[1]) for k, rl in runs.items() if k[0] == "x" and r0 + 1e-3 < float(k[1]) < r1 - 1e-3
                              and cover("x", float(k[1]), f) == "through")
                edges = [r0] + cuts + [r1]
                pieces = [(edges[i], edges[i + 1]) for i in range(len(edges) - 1)]
            for p0, p1 in pieces:
                s, e = p0, p1
                if axis == "x":
                    if any(abs(s - v) < 1e-3 for v in ext_x):
                        s = s + EXT_T
                    else:
                        c = cover("z", s, f)
                        s = s + HALF if c == "through" else (s - HALF if c == "end" else s)
                    if any(abs(e - v) < 1e-3 for v in ext_x):
                        e = e - EXT_T
                    else:
                        c = cover("z", e, f)
                        e = e - HALF if c == "through" else (e + HALF if c == "end" else e)
                else:
                    if any(abs(s - v) < 1e-3 for v in ext_z):
                        s = s + EXT_T
                    elif cover("x", s, f):
                        s = s + HALF
                    if any(abs(e - v) < 1e-3 for v in ext_z):
                        e = e - EXT_T
                    elif cover("x", e, f):
                        e = e - HALF
                sub = [(max(a0, p0), min(a1, p1), pr) for a0, a1, pr in segs if min(a1, p1) - max(a0, p0) > 1e-3]
                _emit_interior_piece(ctx, axis, f, s, e, p0, p1, sub)
    for (axis, fkey), items in rails.items():
        for r0, r1, _ in _merge_runs(items):
            _emit_rail(ctx, axis, float(fkey), r0 + HALF + 0.005, r1 - HALF - 0.005, y)


def _emit_interior_piece(ctx, axis, f, s, e, p0, p1, sub):
    plan = ctx.plan
    y, top = plan.y, plan.wall_top
    holes = line_holes(ctx, axis, f, s, e)
    wins = []
    for a0, a1, (ra, rb) in sub:
        styles = {ra.style, rb.style}
        kinds = {ra.kind, rb.kind}
        if "corridor" in kinds and styles & CORRIDOR_WINDOW:
            blocked = [(h[0], h[1]) for h in holes]
            for d in ctx.doors_on(axis, f):
                if d.kind in ("sliding", "sliding_wide"):
                    h0, h1 = d.hole
                    world_dir = d.slide_local if axis == "x" else -d.slide_local
                    blocked.append((h1, h1 + d.width + 0.15) if world_dir > 0 else (h0 - d.width - 0.15, h0))
            for w0, w1, sill, head, glass in window_layout("B", _free_spans(a0, a1, blocked, 0.45, 0.25)):
                wins.append((w0, w1, y + sill, y + head, glass))
    cut = [(h[0], h[1], h[2], h[3]) for h in holes] + [(w[0], w[1], w[2], w[3]) for w in wins]
    base = y - SLAB if all(ra.no_floor and rb.no_floor for _, _, (ra, rb) in sub) else y
    for side, (t0, t1) in ((0, (f - HALF, f)), (1, (f, f + HALF))):
        spans = []
        for a0, a1, pair in sub:
            mat = finish_of(plan, pair[side])
            if spans and spans[-1][2] == mat and abs(spans[-1][1] - a0) < 1e-3:
                spans[-1][1] = a1
            else:
                spans.append([a0, a1, mat])
        if not spans:
            continue
        spans[0][0] = s if abs(spans[0][0] - p0) < 1e-3 else spans[0][0]
        spans[-1][1] = e if abs(spans[-1][1] - p1) < 1e-3 else spans[-1][1]
        for a0, a1, mat in spans:
            emit_layer(ctx.batch, ctx.arch, mat, axis, t0, t1, a0, a1, base, top, cut, ctx.groups, "partition")
    passable = [(h[0], h[1], h[2], h[3]) for h in holes if h[4]]
    emit_collision(ctx.batch, ctx.arch, axis, f - HALF, f + HALF, s, e, y, top, passable, ctx.groups)
    for w0, w1, wy0, wy1, glass in wins:
        emit_window(ctx.batch, ctx.arch, axis, f - HALF, f + HALF, w0, w1, wy0, wy1, glass, 0, ctx.groups)
        ctx.plan.window_log.append((axis, f, 0, w0, w1, wy0, wy1, "B"))
    # 유리 칸막이: 개구부를 고정 유리로 채운다 (충돌은 벽 그대로)
    for o in plan.openings:
        if o.glass and o.axis == axis and abs(o.fixed - f) < 1e-3 and o.a0 >= s - 1e-3 and o.a1 <= e + 1e-3:
            emit_window(ctx.batch, ctx.arch, axis, f - HALF, f + HALF, o.a0, o.a1, y + o.y0, y + o.y1, o.glass, 0, ctx.groups)
            ctx.plan.window_log.append((axis, f, 0, o.a0, o.a1, y + o.y0, y + o.y1, "P"))


def _emit_rail(ctx, axis, f, a0, a1, y):
    b = ctx.batch

    def box(mat, c0, c1, y0, y1, t0, t1, collide=False):
        if axis == "x":
            b.box(ctx.arch, mat, ((c0 + c1) / 2, (y0 + y1) / 2, (t0 + t1) / 2), (c1 - c0, y1 - y0, t1 - t0), collide, ctx.groups, "rail")
        else:
            b.box(ctx.arch, mat, ((t0 + t1) / 2, (y0 + y1) / 2, (c0 + c1) / 2), (t1 - t0, y1 - y0, c1 - c0), collide, ctx.groups, "rail")

    dy = 0.0 if axis == "x" else 0.006
    box("rail_metal", a0, a1, y + 1.05 + dy, y + 1.1 + dy, f - 0.035, f + 0.035)
    box("rail_metal", a0, a1, y + 0.5 + dy, y + 0.53 + dy, f - 0.015, f + 0.015)
    box("kick_plate", a0, a1, y + dy, y + 0.12 + dy, f - 0.02, f + 0.02)
    n = max(1, int((a1 - a0) // 1.2))
    for i in range(n + 1):
        c = a0 + (a1 - a0) * i / n
        c = min(max(c, a0 + 0.045), a1 - 0.045)
        box("rail_metal", c - 0.02, c + 0.02, y + 0.12 + dy, y + 1.05 + dy, f - 0.02, f + 0.02)
    if axis == "x":
        b.solid(ctx.arch, ((a0 + a1) / 2, y + 0.6, f), (a1 - a0, 1.2, 0.08), ctx.groups, "rail")
    else:
        b.solid(ctx.arch, (f, y + 0.6, (a0 + a1) / 2), (0.08, 1.2, a1 - a0), ctx.groups, "rail")


# ------------------------------------------------------------------ 슬래브

def cell_rects(grid, rid):
    """격자에서 rid 칸들을 겹치지 않는 사각형으로 묶는다 (중첩된 구역도 자기 칸만)"""
    nx, nz = len(grid.xs) - 1, len(grid.zs) - 1
    out, open_runs = [], {}
    for i in range(nx):
        runs, j = [], 0
        col = grid.cell[i]
        while j < nz:
            if col[j] == rid:
                j0 = j
                while j < nz and col[j] == rid:
                    j += 1
                runs.append((j0, j))
            else:
                j += 1
        nxt = {}
        for key in runs:
            if key in open_runs:
                r = open_runs.pop(key)
                r.x1 = grid.xs[i + 1]
                nxt[key] = r
            else:
                nxt[key] = Rect(grid.xs[i], grid.zs[key[0]], grid.xs[i + 1], grid.zs[key[1]])
        out.extend(open_runs.values())
        open_runs = nxt
    out.extend(open_runs.values())
    return out


def build_slabs(ctx):
    plan = ctx.plan
    fp = plan.footprint
    inside = Rect(fp.x0 + FACADE_T, fp.z0 + FACADE_T, fp.x1 - FACADE_T, fp.z1 - FACADE_T)
    y = plan.y
    g = plan.grid
    for r in plan.regions:
        if r.no_floor:
            continue
        mat = floor_of(plan, r)
        if plan.building == "gym" and plan.name == "Roof":
            mat = "roof_metal"
        groups = ctx.groups + r.groups
        for cr in cell_rects(g, r.id):
            if r.floor_dy > 0:
                # 단(무대 등): 외벽 쪽은 외벽 두께, 벽 쪽은 벽 두께 절반만큼 들여서 벽과 겹치지 않게
                inset = {}
                for side, (px, pz), on_edge in (("x0", (cr.x0 - 0.2, cr.cz), abs(cr.x0 - fp.x0) < 1e-3),
                                                ("x1", (cr.x1 + 0.2, cr.cz), abs(cr.x1 - fp.x1) < 1e-3),
                                                ("z0", (cr.cx, cr.z0 - 0.2), abs(cr.z0 - fp.z0) < 1e-3),
                                                ("z1", (cr.cx, cr.z1 + 0.2), abs(cr.z1 - fp.z1) < 1e-3)):
                    other = g.region_at(px, pz)
                    if on_edge:
                        inset[side] = EXT_T
                    elif other is not None and boundary_type(r, other) == "wall":
                        inset[side] = HALF
                    else:
                        inset[side] = 0.0
                rect = Rect(cr.x0 + inset["x0"], cr.z0 + inset["z0"], cr.x1 - inset["x1"], cr.z1 - inset["z1"])
                top = y + r.floor_dy
                for piece in subtract(rect, plan.holes):
                    ctx.batch.box(ctx.arch, mat, (piece.cx, (y - SLAB + top) / 2, piece.cz), (piece.w, top - y + SLAB, piece.d),
                                  True, groups, "slab")
                continue
            rect = cr.clip(inside)
            if rect.w <= 1e-3 or rect.d <= 1e-3:
                continue
            for piece in subtract(rect, plan.holes):
                ctx.batch.box(ctx.arch, mat, (piece.cx, y - SLAB / 2, piece.cz), (piece.w, SLAB, piece.d), True, groups, "slab")


# ------------------------------------------------------------------ 문

def _on_exterior(plan, d):
    fp = plan.footprint
    if d.axis == "x":
        if abs(d.fixed - fp.z0) < 1e-3:
            return +1
        if abs(d.fixed - fp.z1) < 1e-3:
            return -1
    else:
        if abs(d.fixed - fp.x0) < 1e-3:
            return +1
        if abs(d.fixed - fp.x1) < 1e-3:
            return -1
    return 0


def _stable_hash(text):
    h = 0
    for ch in text:
        h = (h * 131 + ord(ch)) % 1000003
    return h


def build_doors(ctx):
    from emit import tf, q
    plan, sw = ctx.plan, ctx.sw
    for d in plan.doors:
        inward = _on_exterior(plan, d)
        t = EXT_T if inward else PART_T
        across = d.fixed + inward * EXT_T / 2 if inward else d.fixed
        y = plan.y + d.floor_dy
        pos = (d.center, y, across) if d.axis == "x" else (across, y, d.center)
        rows = None if d.axis == "x" else (0, 0, 1, 0, 1, 0, -1, 0, 0)
        groups = ctx.groups + d.groups
        if d.kind == "elevator":
            _elevator(ctx, d, t, groups)
            continue
        kind = DOOR_KIND_ENUM[d.kind]
        props = {"transform": tf(pos, rows), "script": ctx.res["school_door"], "kind": str(kind),
                 "door_width": "%.3f" % d.width, "door_height": "%.3f" % d.height, "wall_thickness": "%.3f" % t,
                 "leaf_side": "%.1f" % (1.0 if kind == 0 else float(d.swing_toward)),
                 "slide_dir": "%.1f" % float(d.slide_local), "hinge_side": "%.1f" % float(d.hinge_local),
                 "plate_side": "%.1f" % float(d.plate_side)}
        if d.plate:
            props["plate_text"] = q(d.plate)
        if d.notice:
            props["notice_text"] = q(d.notice)
        if d.locked:
            props["is_locked"] = "true"
            props["locked_prompt"] = q("잠긴 문 (%s)" % d.room if d.room else "잠긴 문")
            props["locked_line"] = q(d.locked_line or "'관계자 외 출입금지' 표지가 붙어 있다. 잠겨 있다.")
        if d.start_open or (kind == 0 and "교실" in d.room and _stable_hash(d.room + "%.1f" % d.center) % 3 == 0):
            props["start_open"] = "true"
        sw.node("Door", "Node3D", ctx.doors, props, groups=list(groups) or None)
        if d.side_glass > 0:
            _side_glass(ctx, d, y, t, across, groups)
        if d.canopy and inward:
            _canopy(ctx, d, y, inward, groups)


def _panel_box(ctx, d, mat, a0, a1, y0, y1, t0, t1, groups, collide=False, tag="door_extra"):
    if d.axis == "x":
        c, s = ((a0 + a1) / 2, (y0 + y1) / 2, (t0 + t1) / 2), (a1 - a0, y1 - y0, t1 - t0)
    else:
        c, s = ((t0 + t1) / 2, (y0 + y1) / 2, (a0 + a1) / 2), (t1 - t0, y1 - y0, a1 - a0)
    if mat is None:
        ctx.batch.solid(ctx.arch, c, s, groups, tag)
    else:
        ctx.batch.box(ctx.arch, mat, c, s, collide, groups, tag)


def _side_glass(ctx, d, y, t, across, groups):
    """현관 문 양옆 고정 유리 (문틀·유리·아래 걸레받이 + 막힘 충돌)"""
    h0, h1 = d.hole
    inner0, inner1 = d.center - d.width / 2 - 0.04, d.center + d.width / 2 + 0.04
    top = y + d.height + 0.04
    for a0, a1 in ((h0, inner0), (inner1, h1)):
        if a1 - a0 < 0.15:
            continue
        emit_window(ctx.batch, ctx.arch, d.axis, across - t / 2, across + t / 2, a0, a1, y, top, "glass", 0, groups)
        _panel_box(ctx, d, "win_frame", a0 + 0.05, a1 - 0.05, y + 0.05, y + 0.22, across - 0.035, across + 0.035, groups)
        _panel_box(ctx, d, None, a0, a1, y, top, across - t / 2, across + t / 2, groups, tag="side_glass")


def _canopy(ctx, d, y, inward, groups):
    """현관 바깥 차양과 외벽보다 짙은 기둥 두 개"""
    h0, h1 = d.hole
    out = -inward
    line = d.fixed
    depth = 1.7
    a0, a1 = h0 - 0.6, h1 + 0.6
    t0, t1 = sorted((line, line + out * depth))
    _panel_box(ctx, d, "canopy", a0, a1, y + d.height + 0.55, y + d.height + 0.72, t0, t1, groups, tag="canopy")
    tp = line + out * (depth - 0.2)
    for a in (a0 + 0.2, a1 - 0.2):
        _panel_box(ctx, d, "pillar_dark", a - 0.15, a + 0.15, y - 0.02, y + d.height + 0.55, tp - 0.15, tp + 0.15, groups,
                   collide=True, tag="pillar")


def _elevator(ctx, d, t, groups):
    """닫힌 스테인리스 양문 + 문틀 + 복도 쪽 호출 버튼(ElevatorInteractable)"""
    from emit import tf, q
    plan = ctx.plan
    h0, h1 = d.hole
    y = plan.y
    top = y + d.height + 0.04
    tc = d.fixed
    half = d.width / 2
    for a0, a1 in ((d.center - half, d.center - 0.005), (d.center + 0.005, d.center + half)):
        _panel_box(ctx, d, "steel", a0, a1, y, y + d.height, tc - 0.025, tc + 0.025, groups, collide=True, tag="elevator_door")
    for a0, a1 in ((h0, h0 + 0.04), (h1 - 0.04, h1)):
        _panel_box(ctx, d, "steel_frame", a0, a1, y, top, tc - t / 2 - 0.01, tc + t / 2 + 0.01, groups, tag="elevator_frame")
    _panel_box(ctx, d, "steel_frame", h0 + 0.04, h1 - 0.04, top - 0.04, top, tc - t / 2 - 0.01, tc + t / 2 + 0.01, groups,
               tag="elevator_frame")
    side = -d.swing_toward if d.swing_toward else 1
    along = h1 + 0.35
    bpos = (along, y, tc + side * (t / 2 + 0.45)) if d.axis == "x" else (tc + side * (t / 2 + 0.45), y, along)
    n = ctx.sw.node("Elevator", "Node3D", ctx.doors, {"transform": tf(bpos), "script": ctx.res["elevator"],
                                                      "elevator_id": q(plan.building), "floor_label": q(plan.name)},
                    groups=list(groups) or None)
    ctx.sw.node("InteractionPoint", "Marker3D", ctx.doors + "/" + n, {"transform": tf((0, 1.1, 0))}, unique=False)
    t0, t1 = sorted((tc + side * t / 2, tc + side * (t / 2 + 0.012)))
    _panel_box(ctx, d, "steel", h1 + 0.25, h1 + 0.4, y + 1.0, y + 1.3, t0, t1, groups, tag="elevator_button")


def build_level(ctx):
    build_exterior(ctx)
    build_interior(ctx)
    build_slabs(ctx)
    build_doors(ctx)
