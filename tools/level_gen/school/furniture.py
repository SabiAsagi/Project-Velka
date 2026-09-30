# -*- coding: utf-8 -*-
"""방 이름 규칙에 따른 가구 배치.

방마다 로컬 좌표계를 쓴다: u = 복도와 나란한 축(0~W), v = 먼 벽(0) -> 복도쪽 벽(D).
결과는 재질별 목록: solid(충돌 있음), visual(충돌 없음), real/other(세계 상태별 배치).
"""


class Frame:
    def __init__(self, rect, n_axis, sign, y0):
        self.rect, self.n_axis, self.sign, self.y0 = rect, n_axis, sign, y0
        if n_axis == "z":
            self.W, self.D = rect.w, rect.d
        else:
            self.W, self.D = rect.d, rect.w

    def world(self, u, v, y, su, sv, sy):
        r = self.rect
        if self.n_axis == "z":
            wz = (r.z0 + v) if self.sign > 0 else (r.z1 - v)
            return (r.x0 + u, self.y0 + y, wz), (su, sy, sv)
        wx = (r.x0 + v) if self.sign > 0 else (r.x1 - v)
        return (wx, self.y0 + y, r.z0 + u), (sv, sy, su)


class Out:
    def __init__(self, frame):
        self.f = frame
        self.items = {}   # (layer, mat) -> [(center, size, 0)]

    def add(self, layer, mat, u, v, y, su, sv, sy):
        c, s = self.f.world(u, v, y + sy / 2, su, sv, sy)
        self.items.setdefault((layer, mat), []).append((c, s, 0))

    def solid(self, mat, u, v, su, sv, sy, y=0.0):
        self.add("solid", mat, u, v, y, su, sv, sy)

    def visual(self, mat, u, v, su, sv, sy, y=0.0):
        self.add("visual", mat, u, v, y, su, sv, sy)


def grid(n, lo, hi):
    if n <= 1:
        return [(lo + hi) / 2]
    return [lo + (hi - lo) * i / (n - 1) for i in range(n)]


def classroom(o, W, D):
    o.visual("board", 0.05, D / 2, 0.06, min(4.0, D - 2), 1.2, y=0.9)
    o.solid("desk", 1.3, D / 2, 0.6, 1.3, 0.95)
    cols = max(3, int((W - 3.2) // 0.95) + 1)
    rows = max(3, int((D - 2.4) // 1.25) + 1)
    for u in grid(cols, 2.7, W - 1.2):
        for v in grid(rows, 1.1, D - 1.6):
            o.solid("desk", u, v, 0.5, 0.62, 0.72)
            o.add("real", "chair", u + 0.42, v, 0, 0.38, 0.4, 0.45)
            o.add("real", "chair", u + 0.6, v, 0.45, 0.06, 0.4, 0.45)
            o.add("other", "chair", u - 0.1, v + 0.3, 0, 0.38, 0.4, 0.45)
    o.solid("locker", W - 0.3, D / 2 - 0.3, 0.45, D - 3.0, 1.8)


def study_room(o, W, D):
    for v in grid(2, 2.2, D / 2 - 0.2):
        for u in grid(2, W * 0.3, W * 0.7):
            o.solid("desk", u, v, 3.0, 0.9, 0.74)
    for u in grid(3, 1.5, W - 1.5):
        for v in grid(2, D / 2 + 1.3, D - 1.8):
            o.solid("desk", u, v, 0.9, 0.6, 0.74)
    o.solid("shelf", 0.3, D / 2, 0.4, D - 2.5, 1.9)


def toilet(o, W, D):
    stalls = max(2, int((W - 0.4) // 1.3))
    width = (W - 0.4) / stalls
    for i in range(stalls + 1):
        o.solid("partition", 0.2 + i * width, 0.8, 0.06, 1.6, 2.0)
    for i in range(stalls):
        o.visual("porcelain", 0.2 + (i + 0.5) * width, 0.35, 0.45, 0.6, 0.45)
    o.solid("counter", W / 2, D - 1.6, W * 0.55, 0.55, 0.85)


def changing_room(o, W, D):
    o.solid("locker", 0.3, D / 2 - 0.2, 0.45, D - 2.0, 1.9)
    o.solid("locker", W - 0.3, D / 2 - 0.2, 0.45, D - 2.0, 1.9)
    o.solid("bench", W / 2, D / 2, 0.4, D * 0.45, 0.45)


def closet(o, W, D):
    o.solid("shelf", W / 2, 0.35, W - 0.4, 0.5, 1.8)
    o.visual("metal", W * 0.3, D * 0.5, 0.45, 0.45, 0.5)
    o.visual("chair", W * 0.7, D * 0.45, 0.08, 0.08, 1.4)


def office(o, W, D, cluster=True):
    cols = max(1, int((W - 1.5) // 3.2))
    rows = max(1, int((D - 2.5) // 2.6))
    for u in grid(cols, 1.8, W - 1.8):
        for v in grid(rows, 1.6, D - 2.2):
            o.solid("desk", u, v, 2.4 if cluster else 1.4, 1.4, 0.74)
            o.visual("metal", u - 0.5, v, 0.5, 0.08, 0.4, y=0.74)
    o.solid("shelf", W / 2, 0.3, W * 0.6, 0.45, 1.9)


def principal(o, W, D):
    o.solid("desk", W / 2, 1.8, 1.8, 0.8, 0.76)
    o.solid("sofa", W / 2, D - 3.0, 0.8, 2.2, 0.8)
    o.solid("desk", W / 2 - 1.1, D - 3.0, 0.7, 1.2, 0.45)


def lobby(o, W, D):
    o.solid("locker", 0.4, D / 2, 0.6, D - 3.0, 1.2)
    o.solid("locker", W - 0.4, D / 2, 0.6, D - 3.0, 1.2)
    o.visual("board", W / 2, 0.2, 2.2, 0.08, 1.2, y=1.0)


def nurse(o, W, D):
    for u in grid(3, W * 0.35, W - 1.2):
        o.solid("bed", u, 1.3, 1.0, 2.0, 0.6)
        o.add("real", "cloth", u - 0.65, 1.3, 0, 0.05, 2.0, 2.0)
        o.add("other", "cloth", u, 2.45, 0, 1.3, 0.05, 2.0)
    o.solid("cabinet", 0.35, D * 0.4, 0.5, 1.8, 1.8)
    o.solid("desk", 1.6, D - 2.0, 1.4, 0.8, 0.76)


def broadcast(o, W, D):
    o.solid("machine", W / 2, 0.5, W * 0.6, 0.7, 1.0)
    o.solid("partition", W * 0.3, D * 0.55, 2.4, 0.08, 2.2)
    o.solid("desk", W * 0.7, D * 0.5, 1.6, 0.8, 0.76)


def meeting(o, W, D):
    o.solid("desk", W / 2, D / 2 - 0.3, min(W - 2.0, 4.0), 1.3, 0.74)
    o.solid("shelf", W / 2, 0.3, W * 0.6, 0.45, 1.9)


def shelves(o, W, D, rows_axis_u=True, spacing=1.8, h=2.0):
    n = max(1, int((W - 1.5) // spacing))
    for u in grid(n, 1.0, W - 1.0):
        o.solid("shelf", u, D / 2 - 0.4, 0.45, D - 2.6, h)


def boxes(o, W, D):
    for i, (u, v) in enumerate(((0.8, 0.8), (1.9, 0.8), (0.8, 1.9), (W - 1.0, 1.0), (W - 1.0, 2.2))):
        if u < W - 0.4 and v < D - 1.2:
            o.solid("box", u, v, 0.9, 0.9, 0.7 + 0.25 * (i % 3))


def machines(o, W, D, tall=2.2):
    n = max(1, int((W - 1.0) // 2.6))
    for u in grid(n, 1.4, W - 1.4):
        o.solid("machine", u, 1.2, 1.6, 1.6, tall)


def cafeteria(o, W, D):
    cols = max(1, int((W - 2.0) // 3.4))
    rows = max(1, int((D - 2.0) // 2.2))
    for u in grid(cols, 2.0, W - 2.0):
        for v in grid(rows, 1.5, D - 2.0):
            o.solid("desk", u, v, 2.6, 0.8, 0.74)
            o.visual("bench", u, v - 0.6, 2.4, 0.3, 0.45)
            o.visual("bench", u, v + 0.6, 2.4, 0.3, 0.45)


def kitchen(o, W, D):
    o.solid("counter", W / 2, 0.45, W - 1.0, 0.8, 0.9)
    o.solid("counter", W / 2, D / 2, W * 0.5, 1.2, 0.9)


def shop(o, W, D):
    o.solid("counter", W / 2, D - 1.8, W - 1.5, 0.6, 1.0)
    o.solid("shelf", W / 2, 0.35, W - 1.0, 0.5, 1.8)


def music(o, W, D):
    o.solid("piano", 1.4, 1.2, 1.5, 0.7, 1.1)
    for u in grid(4, 3.0, W - 1.2):
        for v in grid(3, 1.3, D - 1.8):
            o.add("real", "chair", u, v, 0, 0.42, 0.42, 0.45)
            o.add("other", "chair", u + 0.3, v - 0.4, 0, 0.42, 0.42, 0.45)


def art(o, W, D):
    for u in grid(3, 2.0, W - 2.0):
        for v in grid(2, 1.8, D - 2.2):
            o.solid("desk", u, v, 1.8, 1.2, 0.76)
            o.visual("wood_dark", u + 1.1, v, 0.06, 0.6, 1.5)


def science(o, W, D):
    for u in grid(3, 2.0, W - 2.0):
        for v in grid(2, 1.8, D - 2.2):
            o.solid("counter", u, v, 2.2, 1.1, 0.9)
    o.solid("cabinet", 0.3, D / 2, 0.45, D - 2.5, 1.9)


def computer(o, W, D):
    rows = max(2, int((D - 2.0) // 1.5))
    for v in grid(rows, 1.2, D - 1.8):
        o.solid("desk", W / 2 + 0.5, v, W - 3.0, 0.7, 0.74)
        for u in grid(max(2, int((W - 3.0) // 1.1)), 2.3, W - 1.3):
            o.visual("machine", u, v - 0.15, 0.5, 0.06, 0.38, y=0.74)


def library(o, W, D):
    n = max(1, int((W * 0.55) // 1.9))
    for u in grid(n, 1.2, W * 0.55):
        o.solid("shelf", u, D / 2 - 0.4, 0.5, D - 2.6, 2.0)
    for u in grid(max(1, int((W * 0.4) // 3.2)), W * 0.62, W - 1.6):
        for v in grid(2, 1.6, D - 2.2):
            o.solid("desk", u, v, 2.4, 1.0, 0.74)


def gym_floor(o, W, D):
    o.visual("court_line", W / 2, D / 2, W - 2.0, 0.08, 0.02)
    for u in (1.0, W - 1.0):
        o.solid("metal", u, D / 2, 0.3, 0.3, 3.05)
        o.visual("board", u + (0.3 if u < W / 2 else -0.3), D / 2, 0.05, 1.8, 1.05, y=2.9)


def roof_garden(o, W, D):
    for u in grid(max(1, int(W // 4.0)), 1.6, W - 1.6):
        o.solid("planter", u, D / 2, 2.4, 1.2, 0.6)


def roof_equipment(o, W, D, tanks=False):
    for u in grid(max(1, int(W // 3.2)), 1.6, W - 1.6):
        o.solid("tank" if tanks else "machine", u, D / 2 - 0.4, 2.0 if tanks else 1.4, 2.0 if tanks else 1.0, 2.6 if tanks else 1.3)


RULES = [
    ("존재하지 않는", classroom), ("교실", classroom), ("자습실", study_room), ("화장실", toilet), ("탈의실", changing_room),
    ("청소도구함", closet), ("동아리실", meeting), ("교무실", office), ("행정실", office), ("급식행정실", office),
    ("영양교사실", office), ("사서실", office), ("교장실", principal), ("로비", lobby), ("보건실", nurse),
    ("방송실", broadcast), ("경비실", principal), ("학생회실", meeting), ("그룹학습실", meeting), ("직원 휴게실", principal),
    ("구 도서관", library), ("도서관", library), ("기록 보관실", shelves), ("보존서고", shelves), ("도서 정리실", shelves),
    ("준비실", shelves), ("기자재실", shelves), ("시설관리 창고", shelves), ("창고", boxes), ("폐기물", boxes),
    ("보일러실", machines), ("전기실", machines), ("소방펌프실", machines), ("급식실", cafeteria), ("조리실", kitchen),
    ("세척실", kitchen), ("매점", shop), ("음악실", music), ("미술실", art), ("과학실", science), ("컴퓨터실", computer),
    ("복사·정보검색실", computer), ("사물함", changing_room), ("작품 전시", lobby), ("마룻바닥", gym_floor),
    ("체육기구 창고", boxes), ("행사물품 창고", boxes), ("소품", boxes), ("음향", machines), ("강당 관리실", principal),
    ("옥상정원", roof_garden), ("실외기", roof_equipment),
]


def furnish(name, frame):
    o = Out(frame)
    if "물탱크" in name:
        roof_equipment(o, frame.W, frame.D, tanks=True)
        return o.items
    for key, fn in RULES:
        if key in name:
            fn(o, frame.W, frame.D)
            break
    return o.items


MATERIALS = {
    "desk": (0.58, 0.44, 0.3), "chair": (0.3, 0.34, 0.4), "locker": (0.38, 0.45, 0.52), "board": (0.1, 0.24, 0.17),
    "shelf": (0.46, 0.36, 0.26), "partition": (0.72, 0.76, 0.8), "porcelain": (0.9, 0.92, 0.94), "counter": (0.78, 0.8, 0.82),
    "bench": (0.5, 0.38, 0.26), "metal": (0.42, 0.44, 0.47), "sofa": (0.35, 0.22, 0.2), "bed": (0.9, 0.91, 0.93),
    "cloth": (0.62, 0.76, 0.72), "cabinet": (0.82, 0.84, 0.86), "machine": (0.3, 0.33, 0.36), "box": (0.62, 0.5, 0.34),
    "piano": (0.08, 0.08, 0.1), "wood_dark": (0.32, 0.22, 0.14), "court_line": (0.95, 0.95, 0.95), "planter": (0.35, 0.42, 0.28),
    "tank": (0.7, 0.72, 0.74),
}
