# -*- coding: utf-8 -*-
"""건물 조립 (생성기 v2): 평면 계획 -> 계단 -> 층별 건축(벽·창·문·슬래브) -> 구역·조명."""
from geometry import Rect
from plan_build import build_plans
from plan import FACADE_T
from arch import Ctx, build_level, cell_rects
from stairs2 import build_stairs_v2
from gym import build_gym
from skybridge import build_skybridge
from furnish import furnish_all
from source import BUILDINGS
from emit import q

LAYER_START = {"main": 2, "annex": 8, "gym": 12}
KO = {"main": "본관", "annex": "별관", "gym": "강당"}
from plan import FOOTPRINTS
LEVEL_ORDER = {"main": ["B1", "1F", "2F", "3F", "4F", "Roof"], "annex": ["1F", "2F", "3F", "Roof"], "gym": ["1F", "2F", "Roof"]}


def container_of(lv, child):
    return lv.path + "/" + child


def build_buildings(sw, batch, res, zone_cb, light_cb):
    plans = build_plans()
    sw.node("Buildings", "Node3D", ".", {}, unique=False)
    for bname, order in LEVEL_ORDER.items():
        fp = FOOTPRINTS[bname]
        sw.node(bname, "Node3D", "Buildings", {
            "metadata/building": q(bname),
            "metadata/footprint": "Rect2(%.3f, %.3f, %.3f, %.3f)" % (fp.x0, fp.z0, fp.w, fp.d),
            "metadata/base_y": "0.0", "metadata/top_y": "%.2f" % (plans[(bname, "Roof")].y + 1.2)},
                groups=["school_building"], unique=False)
        for idx, lname in enumerate(order):
            lv = plans[(bname, lname)]
            lv.path = "Buildings/%s/%s" % (bname, lname)
            sw.node(lname, "Node3D", "Buildings/" + bname, {
                "metadata/building": q(bname), "metadata/level_index": str(lv.index),
                "metadata/cull_layer": str(LAYER_START[bname] + idx)}, groups=["school_level"], unique=False)
            for child in ("Arch", "Stairs", "Doors", "Props", "Lights"):
                sw.node(child, "Node3D", lv.path, {}, unique=False)
    build_stairs_v2(plans, batch, sw, container_of)
    build_gym(sw, batch, plans)
    build_skybridge(sw, batch, plans, zone_cb)
    for key in sorted(plans, key=lambda k: (k[0], plans[k].index)):
        lv = plans[key]
        build_level(Ctx(lv, batch, sw, res, container_of(lv, "Arch"), container_of(lv, "Doors")))
    f3 = plans[("main", "3F")]
    ext = f3.extension
    ext.path = f3.path
    sw.node("Otherworld", "Node3D", f3.path, {}, groups=["otherworld_only"], unique=False)
    build_level(Ctx(ext, batch, sw, res, f3.path + "/Otherworld", f3.path + "/Otherworld", groups=("otherworld_only",)))
    furnish_all(plans, batch, sw)
    for key, lv in plans.items():
        for r in lv.regions:
            if r.kind in ("void", "void_room", "stage_upper") or (lv.name == "Roof" and r.kind == "roof" and lv.building != "main"):
                continue
            name = r.display or r.name
            if r.kind == "corridor":
                name = "복도"
            zid = "%s_%s_%s" % (lv.building, lv.name, r.name if r.kind != "corridor" else "corridor")
            other = "뒤틀린 %s %s 복도" % (KO[lv.building], lv.name) if r.kind == "corridor" else ""
            # 다른 구역을 품은 구역(옥상 안의 출입실)은 겹치지 않는 조각으로 나눠야 안쪽에서 나올 때 구역 이름이 바뀐다
            rects = cell_rects(lv.grid, r.id) if r.kind == "roof" else [r.rect]
            for zr in rects:
                zone_cb(zid, "%s %s %s" % (KO[lv.building], lv.name, name), zr, lv.y + r.floor_dy, 3.0, lv.building, lv.index, other)
            light_cb(lv, r, container_of(lv, "Lights"))
    for r in ext.regions:
        zid = "main_3F_%s" % ("ext_corridor" if r.kind == "corridor" else "2-7")
        name = "본관 3F 2-7 교실" if r.kind != "corridor" else "본관 3F 복도"
        zone_cb(zid, name, r.rect, ext.y, 3.0, "", -1, "뒤틀린 본관 3F 복도" if r.kind == "corridor" else "", groups=("otherworld_only",))
        light_cb(ext, r, f3.path + "/Otherworld", groups=("otherworld_only",))
    return plans
