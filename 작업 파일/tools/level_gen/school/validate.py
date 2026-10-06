# -*- coding: utf-8 -*-
"""생성 결과 검증기
1) 깜빡임: 같은 방향을 보는 면이 같은 평면에서 겹치는 박스 쌍 (현실/이계 전용끼리는 제외)
2) 통로: 층마다 0.1m 격자에 충돌 박스를 칠하고 캡슐 반경만큼 여유를 둔 뒤, 복도에서 모든 방에 닿는지 BFS
"""
import math
from collections import defaultdict, deque
from batch import IDENT
from geometry import Rect

EXCLUSIVE = {("real_only", "otherworld_only")}


def _exclusive(ga, gb):
    a, b = set(ga), set(gb)
    return ("real_only" in a and "otherworld_only" in b) or ("otherworld_only" in a and "real_only" in b)


def faces(rec):
    (x0, y0, z0), (x1, y1, z1) = rec.aabb()
    return [(0, -1, x0, (y0, z0, y1, z1)), (0, 1, x1, (y0, z0, y1, z1)),
            (1, -1, y0, (x0, z0, x1, z1)), (1, 1, y1, (x0, z0, x1, z1)),
            (2, -1, z0, (x0, y0, x1, y1)), (2, 1, z1, (x0, y0, x1, y1))]


def zfight(records, tol=0.0003, min_area=0.0004):
    buckets = defaultdict(list)
    for i, r in enumerate(records):
        if not r.visual or r.rows != IDENT or r.mat in ("glass", "glass_frosted"):
            continue
        for axis, d, c, rect in faces(r):
            buckets[(axis, d, round(c / tol))].append((i, rect))
    issues = []
    for key, items in buckets.items():
        if len(items) < 2:
            continue
        items.sort(key=lambda t: t[1][0])
        for a in range(len(items)):
            ia, ra = items[a]
            for b in range(a + 1, len(items)):
                ib, rb = items[b]
                if rb[0] >= ra[2]:
                    break
                w = min(ra[2], rb[2]) - max(ra[0], rb[0])
                h = min(ra[3], rb[3]) - max(ra[1], rb[1])
                if w > 1e-3 and h > 1e-3 and w * h > min_area:
                    A, B = records[ia], records[ib]
                    if _exclusive(A.groups, B.groups):
                        continue
                    if key[0] == 1 and key[1] < 0 and A.container.startswith("Site") and B.container.startswith("Site"):
                        continue
                    if A.mat == B.mat:
                        continue        # 같은 재질끼리는 같은 평면에 겹쳐도 색이 같아 깜빡임이 보이지 않는다
                    issues.append((key, A, B, w * h))
    return issues


def summarize_zfight(issues, limit=12):
    by = defaultdict(list)
    for key, A, B, area in issues:
        by[tuple(sorted((A.tag, B.tag)))].append((key, A, B, area))
    out = []
    for pair, lst in sorted(by.items(), key=lambda kv: -len(kv[1])):
        out.append("  %-30s %4d  e.g. %s" % (" / ".join(pair), len(lst), _desc(lst[0])))
    return "\n".join(out[:limit])


def _desc(item):
    key, A, B, area = item
    ax = "xyz"[key[0]]
    return "%s%s=%.3f area=%.3f %s@%s | %s@%s" % (("+" if key[1] > 0 else "-"), ax, key[2] * 0.0003, area, A.mat,
                                                  tuple(round(v, 2) for v in A.center), B.mat, tuple(round(v, 2) for v in B.center))


# ------------------------------------------------------------------ 통로

RES = 0.1
RADIUS = 0.4


def walk_grid(plan, records, container_prefix):
    """plan 층의 걷기 격자: blocked[i][j]"""
    fp = plan.footprint
    x0, z0 = fp.x0 - 2.0, fp.z0 - 2.0
    nx, nz = int((fp.w + 4.0) / RES) + 1, int((fp.d + 4.0) / RES) + 1
    blocked = [bytearray(nz) for _ in range(nx)]
    band0, band1 = plan.y + 0.3, plan.y + 1.7
    for r in records:
        if not r.collide or not r.container.startswith(container_prefix) or "otherworld_only" in r.groups:
            continue
        (ax0, ay0, az0), (ax1, ay1, az1) = r.aabb()
        if r.rows != IDENT:
            continue
        if ay1 <= band0 or ay0 >= band1:
            continue
        # 칸 중심이 박스 안에 든 칸만 막는다 (0.9m 문 구멍이 격자 정렬에 따라 막힌 것으로 나오지 않게)
        i0, i1 = max(0, math.ceil((ax0 - x0) / RES - 0.5)), min(nx - 1, math.floor((ax1 - x0) / RES - 0.5))
        j0, j1 = max(0, math.ceil((az0 - z0) / RES - 0.5)), min(nz - 1, math.floor((az1 - z0) / RES - 0.5))
        for i in range(i0, i1 + 1):
            row = blocked[i]
            for j in range(j0, j1 + 1):
                row[j] = 1
    return blocked, (x0, z0, nx, nz)


def clearance(blocked, dims, radius=RADIUS):
    x0, z0, nx, nz = dims
    k = int(math.ceil(radius / RES))
    free = [bytearray(nz) for _ in range(nx)]
    # 막힌 칸 주변 반경 안은 걸을 수 없다
    near = [bytearray(nz) for _ in range(nx)]
    offs = [(di, dj) for di in range(-k, k + 1) for dj in range(-k, k + 1) if (di * di + dj * dj) * RES * RES <= radius * radius]
    for i in range(nx):
        row = blocked[i]
        for j in range(nz):
            if row[j]:
                for di, dj in offs:
                    ii, jj = i + di, j + dj
                    if 0 <= ii < nx and 0 <= jj < nz:
                        near[ii][jj] = 1
    for i in range(nx):
        for j in range(nz):
            free[i][j] = 0 if near[i][j] else 1
    return free


def reach(plan, free, dims, start):
    x0, z0, nx, nz = dims
    si, sj = int((start[0] - x0) / RES), int((start[1] - z0) / RES)
    seen = [bytearray(nz) for _ in range(nx)]
    if not (0 <= si < nx and 0 <= sj < nz) or not free[si][sj]:
        return seen, False
    q = deque([(si, sj)])
    seen[si][sj] = 1
    while q:
        i, j = q.popleft()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ii, jj = i + di, j + dj
            if 0 <= ii < nx and 0 <= jj < nz and free[ii][jj] and not seen[ii][jj]:
                seen[ii][jj] = 1
                q.append((ii, jj))
    return seen, True


def unreachable_regions(plan, records, container_prefix, start=None, skip_kinds=("void", "void_room", "stage_upper", "elevator")):
    blocked, dims = walk_grid(plan, records, container_prefix)
    free = clearance(blocked, dims)
    c = plan.corridor()
    if start is None:
        if c is None:
            return None
        start = (c.cx, c.cz)
    seen, ok = reach(plan, free, dims, start)
    if not ok:
        return ["START BLOCKED at %.1f,%.1f" % start]
    x0, z0, nx, nz = dims
    bad = []
    for r in plan.regions:
        if r.kind in skip_kinds or r.no_floor or r.floor_dy > 0.5:
            continue
        rr = r.rect
        hit = 0
        tot = 0
        for i in range(max(0, int((rr.x0 - x0) / RES)), min(nx, int((rr.x1 - x0) / RES))):
            for j in range(max(0, int((rr.z0 - z0) / RES)), min(nz, int((rr.z1 - z0) / RES))):
                tot += 1
                if seen[i][j]:
                    hit += 1
        if hit == 0:
            bad.append(r.name)
    return bad


def blocked_stair_ends(plans, records, paths, starts=None, radius=0.25):
    """계단 경로의 양 끝(올라타는 곳·내려서는 곳)이 그 층의 복도에서 걸어서 닿는지 확인한다.
    가구가 계단 입구를 막으면 방 도달 검사로는 드러나지 않으므로 따로 본다. 막힌 끝 목록을 돌려준다."""
    cache = {}
    bad = []
    for parent, points in paths:
        parts = parent.split("/")
        if len(parts) < 3 or parts[0] != "Buildings":
            continue
        b = parts[1]
        for x, y, z in (points[0], points[-1]):
            lv = next((p for k, p in plans.items() if isinstance(k, tuple) and k[0] == b and abs(p.y - y) < 0.3), None)
            if lv is None:
                continue
            key = (b, lv.name)
            if key not in cache:
                blocked, dims = walk_grid(lv, records, lv.path + "/")
                free = clearance(blocked, dims)
                c = lv.corridor()
                start = (starts or {}).get(key) or ((c.cx, c.cz) if c is not None else None)
                seen = reach(lv, free, dims, start)[0] if start else None
                cache[key] = (seen, dims)
            seen, (x0, z0, nx, nz) = cache[key]
            if seen is None:
                continue
            k = int(radius / RES)
            ci, cj = int((x - x0) / RES), int((z - z0) / RES)
            ok = any(seen[i][j] for i in range(max(0, ci - k), min(nx, ci + k + 1)) for j in range(max(0, cj - k), min(nz, cj + k + 1)))
            if not ok:
                bad.append("%s %s (%.1f, %.1f, %.1f)" % (b, lv.name, x, y, z))
    return bad
