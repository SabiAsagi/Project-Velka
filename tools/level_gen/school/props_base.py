# -*- coding: utf-8 -*-
"""소품·가구 기본 (생성기 v2)

방마다 '앞' 벽을 정해 좌표계를 만든다: v = 앞 벽에서 안쪽으로의 거리, u = 앞을 바라볼 때 왼쪽 -> 오른쪽.
(본관 교실: 앞 = 서쪽 칠판 벽, 왼쪽 = 남쪽 창가, 오른쪽 = 북쪽 복도, 뒤 = 동쪽 사물함 벽)
가구는 박스 조합으로 MultiMesh에 담기고, 큰 가구만 충돌을 가진다.
"""
from geometry import Rect
from batch import rows_y

SIDES = ("x0", "x1", "z0", "z1")
SIDE_TABLE = {
    "x0": {"x0": "front", "x1": "back", "z1": "left", "z0": "right"},
    "x1": {"x1": "front", "x0": "back", "z0": "left", "z1": "right"},
    "z0": {"z0": "front", "z1": "back", "x0": "left", "x1": "right"},
    "z1": {"z1": "front", "z0": "back", "x1": "left", "x0": "right"},
}


class Frame:
    def __init__(self, inner, front, y):
        self.r, self.front, self.y = inner, front, y
        if front in ("x0", "x1"):
            self.W, self.D = inner.d, inner.w
        else:
            self.W, self.D = inner.w, inner.d

    def pt(self, u, v):
        r, f = self.r, self.front
        if f == "x0":
            return r.x0 + v, r.z1 - u
        if f == "x1":
            return r.x1 - v, r.z0 + u
        if f == "z0":
            return r.x0 + u, r.z0 + v
        return r.x1 - u, r.z1 - v

    def uv(self, x, z):
        r, f = self.r, self.front
        if f == "x0":
            return r.z1 - z, x - r.x0
        if f == "x1":
            return z - r.z0, r.x1 - x
        if f == "z0":
            return x - r.x0, z - r.z0
        return r.x1 - x, r.z1 - z

    def size(self, su, sv, sh):
        return (sv, sh, su) if self.front in ("x0", "x1") else (su, sh, sv)

    def side_of(self, world_side):
        return SIDE_TABLE[self.front][world_side]

    def world_side(self, local):
        for w, l in SIDE_TABLE[self.front].items():
            if l == local:
                return w


class Props:
    """방 좌표로 박스를 내보내는 도우미. h0~h1은 방 바닥 기준 높이."""

    def __init__(self, batch, container, frame, groups=(), seed=0):
        self.b, self.c, self.f, self.groups = batch, container, frame, tuple(groups)
        self.seed = seed
        self.blocked = []      # 가구를 두면 안 되는 방 좌표 사각형 (문 앞 여유, 미닫이 이동 구간)

    def box(self, mat, u, v, su, sv, h0, h1, collide=False, tag="prop", yaw=0.0, groups=None, pivot=None):
        if su <= 0 or sv <= 0 or h1 <= h0:
            return
        # 우연히 같은 평면에 놓인 소품 면끼리 깜빡이지 않도록 박스마다 1mm 안팎으로 크기를 다르게 한다
        self.count = getattr(self, "count", 0) + 1
        e = 0.0007 * ((self.count * 5) % 7 + 1)
        # 얇은 표시물(4mm 벽 붙임, 2~6mm 바닥 표시)은 줄이는 양을 치수에 비례해 낮춘다 (아예 사라지지 않게)
        e_max = 0.0049
        su, sv = su - e * min(1.0, su * 0.25 / e_max), sv - e * 0.8 * min(1.0, sv * 0.25 / (0.8 * e_max))
        f = min(1.0, (h1 - h0) * 0.5 / (0.8 * e_max))
        h0, h1 = h0 + e * 0.3 * f, h1 - e * 0.5 * f
        x, z = self.f.pt(u, v)
        sx, sy, sz = self.f.size(su, sv, h1 - h0)
        g = self.groups + tuple(groups or ())
        rows = rows_y(yaw) if yaw else (1, 0, 0, 0, 1, 0, 0, 0, 1)
        if yaw and pivot is not None:
            # 가구 전체를 한 점(pivot) 기준으로 돌린다: 부품 위치도 같은 회전으로 옮긴다
            px, pz = self.f.pt(*pivot)
            dx, dz = x - px, z - pz
            x, z = px + rows[0] * dx + rows[2] * dz, pz + rows[6] * dx + rows[8] * dz
        self.b.box(self.c, mat, (x, self.f.y + (h0 + h1) / 2, z), (sx, sy, sz), collide, g, tag, rows)

    def cyl(self, mat, u, v, d, h0, h1, collide=False, groups=None):
        """세로 원통 (지름 d). collide면 안쪽에 들어가는 사각 충돌을 넣는다."""
        if d <= 0 or h1 <= h0:
            return
        self.count = getattr(self, "count", 0) + 1
        e = 0.0007 * ((self.count * 5) % 7 + 1)
        h1 = h1 - e
        x, z = self.f.pt(u, v)
        g = self.groups + tuple(groups or ())
        self.b.cyl(self.c, mat, (x, self.f.y + (h0 + h1) / 2, z), d, h1 - h0, g)
        if collide:
            self.solid(u, v, d * 0.8, d * 0.8, h0, h1)

    def cone(self, mat, u, v, d, h0, h1, groups=None):
        """세로 원뿔 (밑면 지름 d, 꼭짓점이 위)"""
        if d <= 0 or h1 <= h0:
            return
        x, z = self.f.pt(u, v)
        self.b.cone(self.c, mat, (x, self.f.y + (h0 + h1) / 2, z), d, h1 - h0, self.groups + tuple(groups or ()))

    def solid(self, u, v, su, sv, h0, h1, tag="prop_col", groups=None):
        x, z = self.f.pt(u, v)
        sx, sy, sz = self.f.size(su, sv, h1 - h0)
        self.b.solid(self.c, (x, self.f.y + (h0 + h1) / 2, z), (sx, sy, sz), self.groups + tuple(groups or ()), tag)

    def free(self, u0, v0, u1, v1):
        """방 좌표 사각형이 막힌 구역(문 앞 등)과 겹치지 않으면 True"""
        for bu0, bv0, bu1, bv1 in self.blocked:
            if u0 < bu1 and bu0 < u1 and v0 < bv1 and bv0 < v1:
                return False
        return True

    def rand(self, *keys):
        """결정적 난수 0~1 (같은 방·같은 키면 같은 값)"""
        h = (self.seed * 2654435761 + 12345) % 4294967296
        for k in keys:
            if isinstance(k, (int, float)):
                h = (h * 31 + int(k * 1000)) % 4294967296
            else:
                h = (h * 31 + sum(ord(c) * (i + 1) for i, c in enumerate(str(k)))) % 4294967296
        h ^= h >> 13
        h = (h * 1274126177) % 4294967296
        h ^= h >> 16
        return (h % 10000) / 10000.0


# ------------------------------------------------------------------ 기본 가구 (방 좌표, 가구 앞면 = -v 쪽)

def student_desk(p, u, v, items=(), yaw=0.0, collide=True):
    """학생 책상: 상판 0.6x0.45 (높이 0.72), 서랍 칸, 철제 다리 두 판"""
    p.box("desk_top", u, v, 0.6, 0.45, 0.69, 0.72, yaw=yaw, pivot=(u, v))
    p.box("desk_shelf", u, v + 0.02, 0.54, 0.34, 0.56, 0.6, yaw=yaw, pivot=(u, v))
    for du in (-0.27, 0.27):
        for dv in (-0.19, 0.19):
            p.box("desk_frame", u + du, v + dv, 0.028, 0.028, 0.0, 0.69, yaw=yaw, pivot=(u, v))
        p.box("desk_frame", u + du, v, 0.022, 0.36, 0.12, 0.15, yaw=yaw, pivot=(u, v))
    if collide:
        p.solid(u, v, 0.6, 0.45, 0.0, 0.75)
    for kind in items:
        desk_item(p, u, v, kind)


def desk_item(p, u, v, kind):
    if kind == "bag":
        p.box("bag", u + 0.2, v + 0.32, 0.3, 0.14, 0.35, 0.72)
    elif kind == "book":
        p.box("book_a", u - 0.08, v - 0.03, 0.26, 0.19, 0.72, 0.745)
    elif kind == "books":
        p.box("book_a", u - 0.1, v, 0.26, 0.19, 0.72, 0.745)
        p.box("book_b", u - 0.09, v + 0.01, 0.25, 0.18, 0.745, 0.77)
        p.box("book_c", u - 0.1, v, 0.24, 0.18, 0.77, 0.79)
    elif kind == "pencil":
        p.box("pencil_case", u + 0.12, v - 0.1, 0.2, 0.06, 0.72, 0.76)
    elif kind == "pencil2":
        p.box("pencil_case2", u + 0.1, v - 0.08, 0.22, 0.07, 0.72, 0.77)
    elif kind == "bottle":
        p.box("bottle", u + 0.22, v - 0.12, 0.07, 0.07, 0.72, 0.94)
    elif kind == "cushion":
        p.box("cushion", u, v + 0.45, 0.38, 0.36, 0.452, 0.5)     # 의자 판 위 (등받이 틀 아래끝 0.45와 면이 겹치지 않게)
    elif kind == "papers":
        p.box("paper", u, v, 0.3, 0.21, 0.72, 0.73)
    elif kind == "workbooks":
        for i in range(5):
            p.box("book_a" if i % 2 else "book_c", u - 0.1, v, 0.26, 0.19, 0.72 + i * 0.025, 0.745 + i * 0.025)
    elif kind == "brochure":
        p.box("paper_blue", u + 0.05, v, 0.21, 0.15, 0.72, 0.73)
        p.box("paper_yellow", u - 0.12, v + 0.03, 0.15, 0.21, 0.73, 0.735)


def chair(p, u, v, yaw=0.0, back_side=1):
    """학생 의자: 앉는 판 + 등받이 + 다리 판. 충돌 없음 (통로를 막지 않게)"""
    p.box("chair_seat", u, v, 0.4, 0.38, 0.42, 0.45, yaw=yaw, pivot=(u, v))
    p.box("chair_seat", u, v + back_side * 0.18, 0.38, 0.025, 0.6, 0.84, yaw=yaw, pivot=(u, v))
    for du in (-0.17, 0.17):
        for dv in (-0.16, 0.16):
            p.box("chair_frame", u + du, v + dv, 0.024, 0.024, 0.0, 0.42, yaw=yaw, pivot=(u, v))
        p.box("chair_frame", u + du, v + back_side * 0.18, 0.024, 0.02, 0.45, 0.6, yaw=yaw, pivot=(u, v))


def bench(p, u, v, length, along_u=True, collide=True, mat="bench_wood"):
    su, sv = (length, 0.38) if along_u else (0.38, length)
    p.box(mat, u, v, su, sv, 0.42, 0.46)
    for t in (-0.4, 0.4):
        if along_u:
            p.box("metal_dark", u + t * length, v, 0.05, 0.34, 0.0, 0.42)
        else:
            p.box("metal_dark", u, v + t * length, 0.34, 0.05, 0.0, 0.42)
    if collide:
        p.solid(u, v, su, sv, 0.0, 0.46)


def cabinet(p, u, v, su, sv, h, mat="cabinet_metal", doors=2, collide=True, front=-1):
    """캐비닛: 몸체 + 앞면 문 틈 선 (front = 앞면이 -v(-1) 또는 +v(+1))"""
    p.box(mat, u, v, su, sv, 0.0, h)
    for i in range(1, doors):
        p.box("metal_dark", u - su / 2 + su * i / doors, v + front * (sv / 2 + 0.004), 0.012, 0.008, 0.05, h - 0.05)
    p.box("metal_dark", u + 0.05, v + front * (sv / 2 + 0.006), 0.02, 0.012, h * 0.45, h * 0.55)
    if collide:
        p.solid(u, v, su, sv, 0.0, h)


def shelf_unit(p, u, v, su, sv, h, levels=4, fill=0.7, mat="shelf_wood", book_mats=("book_a", "book_b", "book_c"), key="s",
               front=-1, collide=True):
    """선반: 옆판 두 개 + 뒤판 + 칸 판 + 책/상자 (front = 열린 쪽 -v(-1)/+v(+1))"""
    p.box(mat, u - su / 2 + 0.02, v, 0.04, sv, 0.0, h)
    p.box(mat, u + su / 2 - 0.02, v, 0.04, sv, 0.0, h)
    p.box(mat, u, v - front * (sv / 2 - 0.01), su - 0.08, 0.02, 0.0, h)
    for i in range(levels + 1):
        hh = 0.04 + (h - 0.07) * i / levels
        p.box(mat, u, v, su - 0.08, sv - 0.03, hh, hh + 0.025)
    gap = (h - 0.07) / levels - 0.05
    for i in range(levels):
        hh = 0.065 + (h - 0.07) * i / levels
        x = u - su / 2 + 0.07
        j = 0
        while x < u + su / 2 - 0.1:
            j += 1
            w = 0.03 + 0.05 * p.rand(key, i, j, 1)
            if p.rand(key, i, j) > fill:
                x += w + 0.02
                continue
            bh = gap * (0.55 + 0.4 * p.rand(key, j, i))
            p.box(book_mats[j % len(book_mats)], x + w / 2, v + front * 0.01, w, sv - 0.09, hh, hh + bh)
            x += w + 0.008
    if collide:
        p.solid(u, v, su, sv, 0.0, h)


def wall_board(p, u, v_wall, width, h0, h1, side=1, mat="cork", papers=4, key="b",
               paper_mats=("paper", "paper_yellow", "paper_blue", "paper_pink")):
    """벽 게시판: v_wall = 벽면 v좌표, side = 방 안쪽 방향(+1: +v 쪽이 방)"""
    p.box("frame_alu", u, v_wall + side * 0.012, width + 0.05, 0.024, h0 - 0.025, h1 + 0.025)
    p.box(mat, u, v_wall + side * 0.029, width, 0.01, h0, h1)
    for i in range(papers):
        pu = u - width / 2 + 0.16 + (width - 0.32) * p.rand(key, i)
        ph = h0 + 0.08 + (h1 - h0 - 0.42) * p.rand(key, i, 7)
        # 종이끼리 겹칠 수 있으므로 한 장마다 2mm씩 앞으로 내어 붙인다 (같은 평면에서 깜빡이지 않게)
        p.box(paper_mats[i % len(paper_mats)], pu, v_wall + side * (0.036 + 0.002 * i), 0.21, 0.004, ph, ph + 0.297)


def plant(p, u, v, h, size=0.16, leaf="leaf"):
    p.box("pot", u, v, size, size, h, h + size * 0.85)
    p.box(leaf, u, v, size * 1.25, size * 1.25, h + size * 0.85, h + size * 1.9)
    p.box(leaf, u, v, size * 0.8, size * 0.8, h + size * 1.9, h + size * 2.4)


def bins(p, u, v, n=3, along_u=True):
    mats = ("bin_gray", "bin_blue", "bin_yellow", "bin_green")
    for i in range(n):
        d = (i - (n - 1) / 2) * 0.4
        if along_u:
            p.box(mats[i % 4], u + d, v, 0.34, 0.34, 0.0, 0.58)
        else:
            p.box(mats[i % 4], u, v + d, 0.34, 0.34, 0.0, 0.58)


def curtain(p, u, v_wall, width, side=1, h0=0.7, h1=2.55, mat="curtain"):
    """창 옆에 모아 둔 커튼 (v_wall = 벽면, side = 방 안쪽 방향)"""
    p.box("frame_alu", u, v_wall + side * 0.1, width + 0.25, 0.03, h1 + 0.02, h1 + 0.06)
    for i in range(3):
        du = (i - 1) * width / 3
        p.box(mat, u + du, v_wall + side * (0.07 + 0.03 * (i % 2)), width / 3 + 0.03, 0.05, h0, h1)


def label(sw, parent, pos, text, size=0.004, font=40, color=(0.12, 0.13, 0.16), rot=None, groups=None, outline=0):
    """벽·게시물 글자 (Label3D). rot: 3x3 행 우선 회전 (앞면 방향)"""
    from emit import tf, q
    props = {"transform": tf(pos, rot), "text": q(text), "font_size": str(font), "pixel_size": "%.4f" % size,
             "modulate": "Color(%.2f, %.2f, %.2f, 1)" % color, "outline_size": str(outline)}
    sw.node("Label", "Label3D", parent, props, groups=groups)


def facing_rows(frame, toward):
    """방 좌표에서 toward('front','back','left','right') 쪽을 바라보는 글자 회전 (Label3D는 +z가 앞면)"""
    import math
    wside = frame.world_side(toward)
    # 바라보는 월드 방향 벡터 -> y축 회전각
    vec = {"x0": (-1, 0), "x1": (1, 0), "z0": (0, -1), "z1": (0, 1)}[wside]
    ang = math.degrees(math.atan2(vec[0], vec[1]))
    return rows_y(ang)


def wall_item(p, W, D, side, a, width, off, depth, h0, h1, mat, collide=False, tag="prop"):
    """방 좌표 변(side)에 붙는 박스: a = 벽을 따라 중심, off = 벽면에서 박스까지 거리, depth = 벽에서 튀어나온 두께"""
    if side == "front":
        p.box(mat, a, off + depth / 2, width, depth, h0, h1, collide, tag)
    elif side == "back":
        p.box(mat, a, D - off - depth / 2, width, depth, h0, h1, collide, tag)
    elif side == "left":
        p.box(mat, off + depth / 2, a, depth, width, h0, h1, collide, tag)
    else:
        p.box(mat, W - off - depth / 2, a, depth, width, h0, h1, collide, tag)


def shelf_along(p, W, D, side, a, length, depth, h, levels=3, fill=0.75, mat="shelf_wood", key="sa",
                book_mats=("book_a", "book_b", "book_c")):
    """벽(side)에 붙은 책장: 벽을 따라 length, 앞면은 방 안쪽"""
    if side in ("front", "back"):
        v = depth / 2 if side == "front" else D - depth / 2
        shelf_unit(p, a, v, length, depth, h, levels, fill, mat, book_mats, key, front=1 if side == "front" else -1)
    else:
        # 왼쪽/오른쪽 벽: 좌표를 돌려 그린다
        u = depth / 2 if side == "left" else W - depth / 2
        s = 1 if side == "left" else -1
        wall_item(p, W, D, side, a - length / 2 + 0.02, 0.04, 0.0, depth, 0.0, h, mat)
        wall_item(p, W, D, side, a + length / 2 - 0.02, 0.04, 0.0, depth, 0.0, h, mat)
        wall_item(p, W, D, side, a, length, 0.0, 0.02, 0.0, h, mat)
        for i in range(levels + 1):
            hh = 0.04 + (h - 0.07) * i / levels
            wall_item(p, W, D, side, a, length - 0.08, 0.0, depth - 0.02, hh, hh + 0.025, mat)
        gap = (h - 0.07) / levels - 0.05
        for i in range(levels):
            hh = 0.065 + (h - 0.07) * i / levels
            x = a - length / 2 + 0.07
            j = 0
            while x < a + length / 2 - 0.1:
                j += 1
                w = 0.03 + 0.05 * p.rand(key, i, j, 1)
                if p.rand(key, i, j) <= fill:
                    bh = gap * (0.55 + 0.4 * p.rand(key, j, i))
                    wall_item(p, W, D, side, x + w / 2, w, 0.03, depth - 0.09, hh, hh + bh, book_mats[j % len(book_mats)])
                x += w + 0.008
        if side == "left":
            p.solid(depth / 2, a, depth, length, 0.0, h)
        else:
            p.solid(W - depth / 2, a, depth, length, 0.0, h)
