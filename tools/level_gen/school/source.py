# -*- coding: utf-8 -*-
"""기존 학교 블록아웃 씬(scenes/school/...)을 읽어 월드 좌표의 박스 목록으로 변환한다.

레퍼런스 PNG에 맞춰 검증된 방 경계·칸막이·문 마커·출입구 위치를 그대로 재사용하기 위한 모듈.
씬 인스턴스(Shell, NorthRow, DoorCenterMarker)와 부모 위치 오프셋을 재귀로 따라가고,
SchoolMap.tscn의 건물 배치(본관 이동, 별관 90도 회전, 강당 z 반전)를 적용한다.
"""
import os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FLOOR_H = 3.8


def res_path(res):
    return os.path.join(ROOT, res.replace("res://", "").replace("/", os.sep))


def _vec(text):
    return [float(v) for v in text.split(",")]


class Box:
    """월드 좌표 축정렬 박스"""

    def __init__(self, name, path, center, size, kind, building, level, scene):
        self.name, self.path, self.center, self.size = name, path, center, size
        self.kind, self.building, self.level, self.scene = kind, building, level, scene

    @property
    def min(self):
        return [self.center[i] - self.size[i] / 2 for i in range(3)]

    @property
    def max(self):
        return [self.center[i] + self.size[i] / 2 for i in range(3)]

    def __repr__(self):
        return "Box(%s %s c=%s s=%s)" % (self.kind, self.path, [round(v, 3) for v in self.center], [round(v, 3) for v in self.size])


def parse_scene(path):
    text = open(res_path(path), encoding="utf-8").read()
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', text)}
    nodes = []
    for block in re.split(r"\n(?=\[node )", text):
        if not block.startswith("[node "):
            continue
        head = block.split("\n", 1)[0]
        name = re.search(r'name="([^"]+)"', head).group(1)
        parent = re.search(r'parent="([^"]*)"', head)
        typ = re.search(r'type="(\w+)"', head)
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', head)
        size = re.search(r"\nsize = Vector3\(([^)]*)\)", block)
        pos = re.search(r"\nposition = Vector3\(([^)]*)\)", block)
        tr = re.search(r"\ntransform = Transform3D\(([^)]*)\)", block)
        visible = re.search(r"\nvisible = false", block) is None
        p = [0.0, 0.0, 0.0]
        if pos:
            p = _vec(pos.group(1))
        elif tr:
            p = _vec(tr.group(1))[-3:]
        nodes.append({
            "name": name, "parent": parent.group(1) if parent else None,
            "type": typ.group(1) if typ else None,
            "instance": ext.get(inst.group(1)) if inst else None,
            "size": _vec(size.group(1)) if size else None, "pos": p, "visible": visible,
        })
    return nodes


def collect(scene, offset=(0, 0, 0), prefix=""):
    """씬 안의 모든 CSGBox3D와 문 마커를 (로컬 합산 위치, 경로)로 모은다."""
    nodes = parse_scene(scene)
    world = {".": list(offset)}
    out = []
    for n in nodes:
        if n["parent"] is None:
            key = "."
            world[key] = list(offset)
            continue
        base = world.get(n["parent"], list(offset))
        p = [base[i] + n["pos"][i] for i in range(3)]
        key = n["name"] if n["parent"] == "." else n["parent"] + "/" + n["name"]
        world[key] = p
        full = (prefix + "/" if prefix else "") + key
        if n["instance"]:
            if n["instance"].endswith("DoorCenterMarker.tscn"):
                out.append(("door_marker", full, p, [1.2, 0.08, 0.45]))
            elif n["instance"].endswith(".tscn"):
                out.extend(collect(n["instance"], p, full))
        elif n["type"] in ("CSGBox3D",) and n["size"]:
            out.append(("box" if n["visible"] else "hidden_box", full, p, n["size"]))
    return out


# 건물별 층 씬과 월드 배치 (SchoolMap.tscn / *FloorStack.tscn 기준)
MAIN_LEVELS = [("B1", "Main_B1"), ("1F", "Main_1F"), ("2F", "Main_2F"), ("3F", "Main_3F"), ("4F", "Main_4F"), ("Roof", "Main_Roof")]
ANNEX_LEVELS = [("1F", "Annex_1F"), ("2F", "Annex_2F"), ("3F", "Annex_3F")]
GYM_LEVELS = [("1F", "Gym_1F"), ("2F", "Gym_2F")]
BUILDINGS = {
    "main": {"origin": (0.0, 0.0, -54.0), "rot90": False, "flip_z": False, "levels": MAIN_LEVELS, "dir": "main", "base_level": -1},
    "annex": {"origin": (-60.0, 0.0, -1.5), "rot90": True, "flip_z": False, "levels": ANNEX_LEVELS, "dir": "annex", "base_level": 0},
    "gym": {"origin": (0.0, 0.0, 44.25), "rot90": False, "flip_z": True, "levels": GYM_LEVELS, "dir": "gym", "base_level": 0},
}


def to_world(building, local_center, local_size):
    b = BUILDINGS[building]
    x, y, z = local_center
    sx, sy, sz = local_size
    if b["rot90"]:
        # rotation_y +90: 로컬 +x -> 월드 -z, 로컬 +z -> 월드 +x
        x, z = z, -x
        sx, sz = sz, sx
    if b["flip_z"]:
        z = -z
    o = b["origin"]
    return [o[0] + x, o[1] + y, o[2] + z], [sx, sy, sz]


def to_local(building, world_point):
    b = BUILDINGS[building]
    o = b["origin"]
    x, y, z = world_point[0] - o[0], world_point[1] - o[1], world_point[2] - o[2]
    if b["flip_z"]:
        z = -z
    if b["rot90"]:
        x, z = -z, x
    return [x, y, z]


# 별관 블록아웃은 SupportZones/LargeZones 부모 오프셋 때문에 방 열이 외벽 밖이나 복도로 밀려 있다.
# 방·칸막이·계단 박스를 북측 열(외벽~북측 복도벽), 남측 열(남측 복도벽~외벽) 띠에 맞춘다. (로컬 z 기준)
ANNEX_BANDS = {"north": (-8.625 + 0.125, -3.789 - 0.075), "south": (-1.173 + 0.075, 8.625 - 0.125)}
ANNEX_ROWS = ("SupportZones/", "SupportPartitions/", "LargeZones/", "LargePartitions/")


def fix_annex(path, p, size):
    if not path.startswith(ANNEX_ROWS) or "WestWall" in path or "EastWall" in path or "PassageSouthWall" in path:
        return p, size
    lo, hi = ANNEX_BANDS["north"] if path.startswith("Support") else ANNEX_BANDS["south"]
    z0, z1 = p[2] - size[2] / 2, p[2] + size[2] / 2
    if size[2] < 0.5:
        # z방향으로 얇은 칸막이(세척실-휴게실 사이 등)는 띠 안으로만 끌어온다
        return [p[0], p[1], min(max(p[2], lo), hi)], size
    if z0 >= lo - 0.3 and z1 <= hi + 0.3:
        # 이미 띠 안에 있는 방(1층 급식·조리 구역 등)은 그대로 둔다
        return p, size
    z0, z1 = lo, hi
    return [p[0], p[1], (z0 + z1) / 2], [size[0], size[1], z1 - z0]


def load_buildings():
    boxes = []
    for bname, b in BUILDINGS.items():
        for index, (level, scene_name) in enumerate(b["levels"]):
            y = index * FLOOR_H
            scene = "res://scenes/school/floors/%s/%s.tscn" % (b["dir"], scene_name)
            for kind, path, p, size in collect(scene, (0.0, y, 0.0)):
                if bname == "annex":
                    p, size = fix_annex(path, p, size)
                c, s = to_world(bname, p, size)
                boxes.append(Box(path.split("/")[-1], path, c, s, kind, bname, level, scene_name))
    return boxes


def load_exterior():
    boxes = []
    for kind, path, p, size in collect("res://scenes/school/exterior/Exterior.tscn"):
        boxes.append(Box(path.split("/")[-1], path, p, size, kind, "site", "ground", "Exterior"))
    return boxes


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    bs = load_buildings()
    print(len(bs), "building boxes")
    for b in bs[:5]:
        print(b)
