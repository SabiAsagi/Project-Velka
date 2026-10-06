# -*- coding: utf-8 -*-
"""프로젝트 벨카 - 챕터 1 학교 전체 맵 생성기 (v2)

실행: python tools/level_gen/school/school_world_gen.py
입력: scenes/school/ 의 레퍼런스 정렬 블록아웃(층별 씬, 외부 씬) + plan_build.py의 보정
출력: scenes/school/SchoolWorld.tscn, scenes/chapters/Chapter1_School.tscn
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from emit import SceneWriter, tf, q
from geometry import Rect
from batch import Batch
from structure import emit_zone
import palette
from site2 import build_site
from buildings2 import build_buildings
from plan_build import inner_rect
from source import ROOT
from world_extras import build_inspectables, build_survival, emit_region_lights, SPAWN, write_chapter

def main():
    import stairs2
    stairs2.STAIR_PATHS.clear()
    import room_ctx
    room_ctx.ANCHORS.clear()
    sw = SceneWriter()
    batch = Batch()
    res = {
        "controller": sw.ext_res("Script", "res://scripts/world/WorldPhaseController.gd"),
        "zone": sw.ext_res("Script", "res://scripts/world/ZoneArea.gd"),
        "ambient": sw.ext_res("Script", "res://scripts/world/AmbientSynth.gd"),
        "school_door": sw.ext_res("Script", "res://scripts/interactables/SchoolDoor.gd"),
        "inspect": sw.ext_res("Script", "res://scripts/interactables/InspectInteractable.gd"),
        "elevator": sw.ext_res("Script", "res://scripts/interactables/ElevatorInteractable.gd"),
        "checkpoint": sw.ext_res("Script", "res://scripts/world/Checkpoint.gd"),
        "rulezone": sw.ext_res("Script", "res://scripts/world/RuleZone.gd"),
    }
    mats = palette.make(sw)
    env_real = sw.sub_res("env_real", "Environment", {
        "background_mode": "1", "background_color": "Color(0.56, 0.68, 0.8, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.8, 0.82, 0.86, 1)", "ambient_light_energy": "0.55",
        # 구석·가구 밑·벽과 바닥이 만나는 곳을 어둡게 (사용감), 채도를 살짝 낮춰 오래된 느낌
        "ssao_enabled": "true", "ssao_radius": "1.2", "ssao_intensity": "2.2", "ssao_power": "1.6", "ssao_light_affect": "0.2",
        "adjustment_enabled": "true", "adjustment_saturation": "0.9", "adjustment_contrast": "1.05"})
    env_other = sw.sub_res("env_other", "Environment", {
        "background_mode": "1", "background_color": "Color(0, 0, 0, 1)", "ambient_light_source": "2",
        "ambient_light_color": "Color(0.55, 0.36, 0.42, 1)", "ambient_light_energy": "0.7", "fog_enabled": "true",
        "fog_light_color": "Color(0.1, 0.03, 0.05, 1)", "fog_density": "0.018",
        "ssao_enabled": "true", "ssao_radius": "1.4", "ssao_intensity": "3.0", "ssao_power": "1.8", "ssao_light_affect": "0.3",
        "adjustment_enabled": "true", "adjustment_saturation": "0.8", "adjustment_contrast": "1.08"})
    sw.node("SchoolWorld", "Node3D", None, {"script": res["controller"], "real_environment": env_real,
                                            "otherworld_environment": env_other, "world_environment": 'NodePath("WorldEnvironment")',
                                            "ambient": 'NodePath("Ambient")'}, node_paths=["world_environment", "ambient"])
    sw.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env_real}, unique=False)
    sun_tf = "Transform3D(0.707107, -0.5, 0.5, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 30, 0)"
    sw.node("Sun", "DirectionalLight3D", ".", {"transform": sun_tf, "light_energy": "0.95", "shadow_enabled": "true"},
            groups=["real_light"], unique=False)
    sw.node("Ambient", "AudioStreamPlayer", ".", {"script": res["ambient"]}, unique=False)
    sw.node("Zones", "Node3D", ".", {}, unique=False)

    def zone_cb(zone_id, name, rect, y0, height, building="", level=-1, other="", groups=()):
        emit_zone(sw, "Zones", res["zone"], rect, y0, height, zone_id, name, building, level, other, groups)

    def light_cb(plan, region, container, groups=()):
        emit_region_lights(sw, plan, region, container, groups)

    sw.node("Site", "Node3D", ".", {}, unique=False)
    build_site(sw, batch, "Site", zone_cb)
    plans = build_buildings(sw, batch, res, zone_cb, light_cb)
    from site_extras import facade_details
    facade_details(sw, batch, plans)
    build_inspectables(sw, plans, res)
    build_survival(sw, plans, res)
    sw.node("Spawn", "Marker3D", ".", {"transform": tf(SPAWN)}, unique=False)
    batch.emit(sw, mats)
    path = os.path.join(ROOT, "scenes", "school", "SchoolWorld.tscn")
    text = sw.text()
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote", path, "nodes=%d subs=%d bytes=%d boxes=%d" % (len(sw.nodes), len(sw.subs), len(text), len(batch.records)))
    write_chapter()
    return plans, batch


if __name__ == "__main__":
    main()
