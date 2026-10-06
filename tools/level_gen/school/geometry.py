# -*- coding: utf-8 -*-
"""평면 사각형 연산: 바닥 슬래브에서 계단 구멍 빼기, 벽에서 문 구멍 빼기."""

EPS = 1e-4


class Rect:
    """xz 평면 사각형 (x0 < x1, z0 < z1)"""

    def __init__(self, x0, z0, x1, z1):
        self.x0, self.z0, self.x1, self.z1 = min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1)

    @property
    def w(self):
        return self.x1 - self.x0

    @property
    def d(self):
        return self.z1 - self.z0

    @property
    def cx(self):
        return (self.x0 + self.x1) / 2

    @property
    def cz(self):
        return (self.z0 + self.z1) / 2

    def intersects(self, o):
        return self.x0 < o.x1 - EPS and o.x0 < self.x1 - EPS and self.z0 < o.z1 - EPS and o.z0 < self.z1 - EPS

    def contains_point(self, x, z, margin=0.0):
        return self.x0 - margin <= x <= self.x1 + margin and self.z0 - margin <= z <= self.z1 + margin

    def clip(self, o):
        return Rect(max(self.x0, o.x0), max(self.z0, o.z0), min(self.x1, o.x1), min(self.z1, o.z1))

    def __repr__(self):
        return "Rect(%.2f,%.2f,%.2f,%.2f)" % (self.x0, self.z0, self.x1, self.z1)


def rect_of_box(box):
    mn, mx = box.min, box.max
    return Rect(mn[0], mn[2], mx[0], mx[2])


def subtract(rect, holes):
    """rect에서 holes를 뺀 나머지를 겹치지 않는 사각형들로 반환 (행 단위 병합)."""
    holes = [h.clip(rect) for h in holes if h.intersects(rect)]
    if not holes:
        return [rect]
    xs = sorted({rect.x0, rect.x1, *[h.x0 for h in holes], *[h.x1 for h in holes]})
    zs = sorted({rect.z0, rect.z1, *[h.z0 for h in holes], *[h.z1 for h in holes]})
    rows = []
    for zi in range(len(zs) - 1):
        z0, z1 = zs[zi], zs[zi + 1]
        if z1 - z0 < EPS:
            continue
        cells = []
        for xi in range(len(xs) - 1):
            x0, x1 = xs[xi], xs[xi + 1]
            if x1 - x0 < EPS:
                continue
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if any(h.x0 < cx < h.x1 and h.z0 < cz < h.z1 for h in holes):
                continue
            if cells and abs(cells[-1][1] - x0) < EPS:
                cells[-1][1] = x1
            else:
                cells.append([x0, x1])
        rows.append((z0, z1, cells))
    # 같은 x 구간이 위아래로 이어지면 합친다
    out = []
    open_rects = {}
    for z0, z1, cells in rows:
        next_open = {}
        for x0, x1 in cells:
            key = (round(x0, 4), round(x1, 4))
            if key in open_rects:
                r = open_rects.pop(key)
                r.z1 = z1
                next_open[key] = r
            else:
                next_open[key] = Rect(x0, z0, x1, z1)
        out.extend(open_rects.values())
        open_rects = next_open
    out.extend(open_rects.values())
    return out


def split_span(a0, a1, gaps):
    """[a0,a1] 구간에서 gaps [(g0,g1)]를 뺀 구간들"""
    segs = []
    cur = a0
    for g0, g1 in sorted(gaps):
        g0, g1 = max(g0, a0), min(g1, a1)
        if g1 <= g0:
            continue
        if g0 - cur > 0.05:
            segs.append((cur, g0))
        cur = max(cur, g1)
    if a1 - cur > 0.05:
        segs.append((cur, a1))
    return segs


if __name__ == "__main__":
    r = Rect(0, 0, 10, 10)
    print(subtract(r, [Rect(2, 2, 4, 10), Rect(6, 0, 8, 3)]))
    print(split_span(0, 10, [(2, 3), (7, 8.5)]))
