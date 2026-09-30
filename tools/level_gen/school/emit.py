# -*- coding: utf-8 -*-
"""tscn 텍스트 생성기: 리소스 중복 제거, 메시+충돌 박스, 멀티메시, 인스턴스 노드."""
import math


def fmt(v):
    v = round(float(v), 4)
    if v == 0:
        return "0"
    return str(int(v)) if v == int(v) else repr(v)


def q(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def tf(center, rows=None):
    r = rows or (1, 0, 0, 0, 1, 0, 0, 0, 1)
    return "Transform3D(" + ", ".join(fmt(a) for a in list(r) + list(center)) + ")"


def rot_y(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (c, 0, s, 0, 1, 0, -s, 0, c)


def rot_x(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (1, 0, 0, 0, c, -s, 0, s, c)


def rot_z(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (c, -s, 0, s, c, 0, 0, 0, 1)


def vec3(v):
    return "Vector3(%s, %s, %s)" % tuple(fmt(a) for a in v)


class SceneWriter:
    def __init__(self):
        self.ext = []
        self._ext_ids = {}
        self.subs = []
        self._sub_keys = {}
        self.nodes = []
        self._names = {}

    # ---------------- resources ----------------
    def ext_res(self, kind, path):
        if path not in self._ext_ids:
            rid = "e%d" % (len(self._ext_ids) + 1)
            self._ext_ids[path] = rid
            self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        return 'ExtResource("%s")' % self._ext_ids[path]

    def sub_res(self, key, kind, props):
        if key not in self._sub_keys:
            rid = "s%d" % (len(self._sub_keys) + 1)
            self._sub_keys[key] = rid
            body = "".join("%s = %s\n" % (k, v) for k, v in props.items())
            self.subs.append('[sub_resource type="%s" id="%s"]\n%s' % (kind, rid, body))
        return 'SubResource("%s")' % self._sub_keys[key]

    def material(self, name, color, emission=None, energy=0.8, transparent=False, unshaded=False):
        props = {"albedo_color": "Color(%s, %s, %s, %s)" % tuple(fmt(c) for c in (list(color) + [1.0])[:4]), "roughness": "0.88"}
        if transparent:
            props["transparency"] = "1"
        if unshaded:
            props["shading_mode"] = "0"
        if emission:
            props["emission_enabled"] = "true"
            props["emission"] = "Color(%s, %s, %s, 1)" % tuple(fmt(c) for c in emission)
            props["emission_energy_multiplier"] = fmt(energy)
        return self.sub_res(("mat", name), "StandardMaterial3D", props)

    def box_mesh(self, size, mat):
        key = ("boxmesh", tuple(round(s, 3) for s in size), mat)
        return self.sub_res(key, "BoxMesh", {"material": mat, "size": vec3(size)})

    def box_shape(self, size):
        key = ("boxshape", tuple(round(s, 3) for s in size))
        return self.sub_res(key, "BoxShape3D", {"size": vec3(size)})

    # ---------------- nodes ----------------
    def uniq(self, parent, name):
        key = (parent, name)
        n = self._names.get(key, 0)
        self._names[key] = n + 1
        return name if n == 0 else "%s_%d" % (name, n + 1)

    def node(self, name, kind, parent, props=None, groups=None, instance=None, node_paths=None, unique=True):
        if unique and parent is not None:
            name = self.uniq(parent, name)
        head = '[node name="%s"' % name
        if kind:
            head += ' type="%s"' % kind
        if parent is not None:
            head += ' parent="%s"' % parent
        if node_paths:
            head += " node_paths=PackedStringArray(" + ", ".join(q(p) for p in node_paths) + ")"
        if instance:
            head += " instance=%s" % instance
        if groups:
            head += " groups=[" + ", ".join(q(g) for g in groups) + "]"
        head += "]"
        body = "".join("%s = %s\n" % (k, v) for k, v in (props or {}).items())
        self.nodes.append(head + "\n" + body)
        return name

    def solid(self, parent, name, center, size, mat, collision=True, groups=None, rows=None, shadow=True):
        """메시(시각) + StaticBody3D(충돌). 카메라 가림 처리를 위해 벽 하나당 지오메트리 하나."""
        props = {"transform": tf(center, rows), "mesh": self.box_mesh(size, mat)}
        if not shadow:
            props["cast_shadow"] = "0"
        n = self.node(name, "MeshInstance3D", parent, props, groups)
        if collision:
            body = self.node("Body", "StaticBody3D", parent + "/" + n, {}, unique=False)
            self.node("Shape", "CollisionShape3D", parent + "/" + n + "/" + body, {"shape": self.box_shape(size)}, unique=False)
        return n

    def pad(self, parent, name, center, size, mat, groups=None):
        return self.solid(parent, name, center, size, mat, collision=False, groups=groups, shadow=False)

    def collider(self, parent, name, center, size, groups=None, rows=None):
        n = self.node(name, "StaticBody3D", parent, {"transform": tf(center, rows)}, groups)
        self.node("Shape", "CollisionShape3D", parent + "/" + n, {"shape": self.box_shape(size)}, unique=False)
        return n

    def multimesh(self, parent, name, mat, items, groups=None):
        """items: [(center, size, rot_y_deg)] 단위 박스를 스케일해서 한 번에 그린다."""
        if not items:
            return None
        floats = []
        for center, size, ry in items:
            c, s = math.cos(math.radians(ry)), math.sin(math.radians(ry))
            sx, sy, sz = size
            # 3x4 행 우선: basis 행 + origin
            floats += [c * sx, 0, s * sz, center[0], 0, sy, 0, center[1], -s * sx, 0, c * sz, center[2]]
        unit = self.box_mesh((1, 1, 1), mat)
        mm = self.sub_res(("mm", parent, name, len(self._sub_keys)), "MultiMesh", {
            "transform_format": "1",
            "instance_count": str(len(items)),
            "mesh": unit,
            "buffer": "PackedFloat32Array(" + ", ".join(fmt(f) for f in floats) + ")",
        })
        return self.node(name, "MultiMeshInstance3D", parent, {"multimesh": mm}, groups)

    def text(self):
        return "[gd_scene load_steps=%d format=3]\n\n" % (len(self.ext) + len(self.subs) + 1) + \
            "\n".join(self.ext) + "\n\n" + "\n".join(self.subs) + "\n" + "\n".join(self.nodes)
