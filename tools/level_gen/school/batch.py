# -*- coding: utf-8 -*-
"""지오메트리 수집기: 박스를 모아 재질별 MultiMesh와 컨테이너별 충돌 몸체로 출력한다.

- 보이는 박스는 (컨테이너, 재질, 그룹)마다 MultiMeshInstance3D 하나로 묶는다 (그리기 호출 최소화).
- 충돌 박스는 (컨테이너, 그룹)마다 StaticBody3D 하나에 CollisionShape3D를 여러 개 단다.
- 모든 박스를 records에 남겨 검증기(겹친 면·통로 검사)가 쓴다.
"""
import math
from collections import OrderedDict

IDENT = (1, 0, 0, 0, 1, 0, 0, 0, 1)


def rows_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (c, 0, s, 0, 1, 0, -s, 0, c)


class Record:
    __slots__ = ("center", "size", "rows", "mat", "container", "groups", "visual", "collide", "tag")

    def __init__(self, center, size, rows, mat, container, groups, visual, collide, tag):
        self.center, self.size, self.rows = tuple(center), tuple(size), rows
        self.mat, self.container, self.groups = mat, container, tuple(groups)
        self.visual, self.collide, self.tag = visual, collide, tag

    @property
    def axis_aligned(self):
        return self.rows == IDENT

    def aabb(self):
        c, s = self.center, self.size
        return (c[0] - s[0] / 2, c[1] - s[1] / 2, c[2] - s[2] / 2), (c[0] + s[0] / 2, c[1] + s[1] / 2, c[2] + s[2] / 2)


class Batch:
    def __init__(self):
        self.visual = OrderedDict()     # (container, mat, groups) -> [(center, size, rows)]
        self.colliders = OrderedDict()  # (container, groups) -> [(center, size, rows)]
        self.cyls = OrderedDict()       # (container, mat, groups) -> [(center, (지름, 높이, 지름))]
        self.cones = OrderedDict()      # 같은 형식, 위가 뾰족한 원뿔
        self.records = []

    def box(self, container, mat, center, size, collide=True, groups=(), tag="", rows=IDENT, visual=True):
        """보이는 박스(선택적으로 충돌 포함). size가 0 이하인 축이 있으면 무시."""
        if min(size) <= 1e-4:
            return
        groups = tuple(groups)
        if visual:
            self.visual.setdefault((container, mat, groups), []).append((tuple(center), tuple(size), rows))
        if collide:
            self.colliders.setdefault((container, groups), []).append((tuple(center), tuple(size), rows))
        self.records.append(Record(center, size, rows, mat, container, groups, visual, collide, tag))

    def cyl(self, container, mat, center, diameter, height, groups=(), tag="cyl"):
        """보이는 원통 (세로축). 충돌은 따로 solid로 넣는다. 검증용 기록은 바깥 박스가 아니라 안쪽에 들어가는 박스로 남긴다."""
        if diameter <= 1e-4 or height <= 1e-4:
            return
        groups = tuple(groups)
        self.cyls.setdefault((container, mat, groups), []).append((tuple(center), (diameter, height, diameter)))

    def cone(self, container, mat, center, diameter, height, groups=(), tag="cone"):
        """보이는 원뿔 (세로축, 밑면 지름 diameter). center는 높이의 가운데."""
        if diameter <= 1e-4 or height <= 1e-4:
            return
        self.cones.setdefault((container, mat, tuple(groups)), []).append((tuple(center), (diameter, height, diameter)))

    def solid(self, container, center, size, groups=(), tag="", rows=IDENT):
        """보이지 않는 충돌 박스 (경사로·투명 벽)"""
        self.box(container, None, center, size, True, groups, tag, rows, visual=False)

    def emit(self, sw, mats):
        """SceneWriter에 노드를 쓴다. mats: 재질 키 -> SubResource 참조."""
        for (container, mat, groups), items in self.visual.items():
            name = "MM_" + mat
            sw.multimesh_rows(container, name, mats[mat], items, groups=list(groups) or None)
        for (container, mat, groups), items in self.cyls.items():
            sw.multimesh_cyl(container, "MC_" + mat, mats[mat + "@round"], items, groups=list(groups) or None)
        for (container, mat, groups), items in self.cones.items():
            sw.multimesh_cyl(container, "MK_" + mat, mats[mat + "@round"], items, groups=list(groups) or None, top_radius=0.0)
        for (container, groups), items in self.colliders.items():
            body = sw.node("Collision", "StaticBody3D", container, {}, groups=list(groups) or None)
            path = container + "/" + body
            for center, size, rows in items:
                sw.node("S", "CollisionShape3D", path, {"transform": _tf(center, rows), "shape": sw.box_shape(size)})


def _tf(center, rows):
    from emit import tf
    return tf(center, rows)
