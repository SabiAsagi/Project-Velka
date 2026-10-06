# -*- coding: utf-8 -*-
"""방 양식별 가구 배치 연결 (생성기 v2)"""
from room_ctx import RoomCtx
from rooms_class import classroom
from rooms_corridor import corridor
from rooms_service import toilet, changing, closet
from rooms_main import lobby, admin, staff_office, principal, nurse, broadcast, guard, council, entrance_passage
from rooms_study import study_2f, study_3f, study_4f, club, CLUBS
from rooms_b1 import old_library, archive, storage, boiler, electric, facility, pump, waste, b1_corridor
from props_base import SIDE_TABLE
import rooms_annex as RA
import rooms_gym as RG

# 강당 방 -> (배치 함수, 앞 벽 = 마룻바닥 쪽 벽)
GYM_ROOMS = {
    "소품·의상 준비실": (RG.prop_room, "z0"), "음향·조명·무대장치실": (RG.sound_room, "z0"),
    "체육기구 창고": (RG.equipment_storage, "z1"), "행사물품 창고": (RG.event_storage, "z1"), "강당 관리실": (RG.gym_office, "z1"),
}

# 별관 방 -> (배치 함수, 앞 벽). 동쪽 큰 방은 복도 벽이 x0, 서쪽 지원실은 x1
ANNEX_ROOMS = {
    "급식실": (RA.cafeteria, "x0"), "조리실": (RA.kitchen, "x0"), "세척실": (RA.wash, "x0"), "직원 휴게실": (RA.staff_lounge, "x0"),
    "조리 식품 창고": (RA.food_storage, "x0"), "매점": (RA.shop, "x1"), "매점 창고": (RA.shop_storage, "x1"),
    "영양교사실": (RA.nutrition_office, "x1"), "급식행정실": (RA.meal_admin, "x1"), "열린 급식 안내 공간": (RA.alcove_meal, "x1"),
    "서측 학생 출입 통로": (RA.annex_passage, "x1"), "동측 반입 통로": (RA.annex_passage, "x1"),
    "음악실": (RA.music_room, "x0"), "미술실": (RA.art_room, "x0"), "제1과학실": (RA.science1, "x0"),
    "제2과학실": (RA.science2, "x0"), "컴퓨터실": (RA.computer_room, "x0"), "음악 준비실": (RA.music_prep, "x1"),
    "미술 준비실": (RA.art_prep, "x1"), "작품 전시 공간": (RA.alcove_gallery, "x1"), "공동 과학 준비실": (RA.science_prep, "x1"),
    "컴퓨터 기자재실": (RA.computer_prep, "x1"), "도서관": (RA.library, "x0"), "그룹학습실": (RA.group_study, "x0"),
    "사서실": (RA.librarian_office, "x1"), "도서 정리실": (RA.book_work, "x1"), "사물함·반납 공간": (RA.alcove_lockers, "x1"),
    "보존서고": (RA.stacks, "x1"), "복사·정보검색실": (RA.copy_room, "x1"),
}


def _seed(text):
    h = 7
    for ch in text:
        h = (h * 131 + ord(ch)) % 1000003
    return h


def door_world_side(plan, region):
    """방의 주 출입문이 붙은 월드 변 (복도·홀 쪽 문 우선)"""
    r = region.rect
    found = []
    for d in plan.doors:
        if d.room != region.name:
            continue
        if d.axis == "x":
            ws = "z0" if abs(d.fixed - r.z0) < 0.05 else ("z1" if abs(d.fixed - r.z1) < 0.05 else None)
        else:
            ws = "x0" if abs(d.fixed - r.x0) < 0.05 else ("x1" if abs(d.fixed - r.x1) < 0.05 else None)
        if ws is None:
            continue
        px, pz = {"z0": (r.cx, r.z0 - 0.3), "z1": (r.cx, r.z1 + 0.3), "x0": (r.x0 - 0.3, r.cz), "x1": (r.x1 + 0.3, r.cz)}[ws]
        other = plan.grid.region_at(px, pz)
        rank = 0 if (other is not None and other.kind in ("corridor", "hall", "passage")) else 1
        found.append((rank, ws))
    if not found:
        c = plan.corridor()
        if c is None:
            return "z1"
        return "z0" if c.cz < r.cz else ("z1" if c.cz > r.cz else "x0")
    return min(found)[1]


def front_for(plan, region, door_local="front"):
    """문이 방 좌표의 door_local 쪽에 오도록 앞 벽을 고른다"""
    ws = door_world_side(plan, region)
    for f, table in SIDE_TABLE.items():
        if table[ws] == door_local:
            return f
    return "x0"


def _ctx(plan, region, batch, sw, container, door_local="front", groups=()):
    return RoomCtx(plan, region, batch, sw, container, front_for(plan, region, door_local), groups=groups,
                   seed=_seed(plan.building + plan.name + region.name))


B1_ROOMS = {"old_library": old_library, "archive": archive, "storage": storage, "boiler": boiler, "electric": electric,
            "facility": facility, "pump": pump, "waste": waste}
MAIN_ROOMS = {"lobby": lobby, "admin": admin, "office": staff_office, "principal": principal, "nurse": nurse,
              "broadcast": broadcast, "guard": guard, "council": council}


def furnish_all(plans, batch, sw):
    """방마다 가구·소품을 배치한다. 조사 대상 기준점은 각 방 함수가 ctx.anchor()로 room_ctx.ANCHORS에 남긴다."""
    for key in sorted(plans, key=lambda k: (k[0], plans[k].index)):
        lv = plans[key]
        container = lv.path + "/Props"
        for r in lv.regions:
            if lv.building == "main" and r.style == "classroom":
                ctx = RoomCtx(lv, r, batch, sw, container, "x0", seed=_seed(lv.name + r.name))
                classroom(ctx, r.name.replace(" 교실", ""))
            elif lv.building == "main" and lv.name == "B1" and r.style in B1_ROOMS:
                B1_ROOMS[r.style](_ctx(lv, r, batch, sw, container))
            elif lv.building == "main" and lv.name == "B1" and r.kind == "corridor":
                b1_corridor(RoomCtx(lv, r, batch, sw, container, "x0", seed=_seed("b1corr")))
            elif lv.building == "main" and r.style in MAIN_ROOMS:
                MAIN_ROOMS[r.style](_ctx(lv, r, batch, sw, container))
            elif lv.building == "main" and r.style == "study":
                {"2F": study_2f, "3F": study_3f, "4F": study_4f}.get(lv.name, study_2f)(_ctx(lv, r, batch, sw, container))
            elif lv.building == "main" and (lv.name, r.name) in CLUBS:
                club(_ctx(lv, r, batch, sw, container), CLUBS[(lv.name, r.name)])
            elif lv.building == "main" and r.kind == "passage":
                entrance_passage(_ctx(lv, r, batch, sw, container))
            elif lv.building == "gym":
                if r.name in GYM_ROOMS:
                    fn, front = GYM_ROOMS[r.name]
                    fn(RoomCtx(lv, r, batch, sw, container, front, seed=_seed("gym" + r.name)))
                elif r.style == "toilet":
                    RG.gym_toilet(_ctx(lv, r, batch, sw, container), men="서측" in r.name)
                elif r.kind == "hall" and r.rect.w > 5.0:
                    RG.gym_hall(RoomCtx(lv, r, batch, sw, container, "z0", seed=_seed("gymhall")))
            elif lv.building == "annex" and r.name in ANNEX_ROOMS:
                fn, front = ANNEX_ROOMS[r.name]
                fn(RoomCtx(lv, r, batch, sw, container, front, seed=_seed("annex" + lv.name + r.name)))
            elif r.style == "toilet":
                toilet(_ctx(lv, r, batch, sw, container), men="남자" in r.name)
            elif r.style == "changing":
                changing(_ctx(lv, r, batch, sw, container))
            elif r.style == "closet":
                closet(_ctx(lv, r, batch, sw, container))
            elif r.kind == "corridor" and lv.building in ("main", "annex") and lv.name not in ("B1", "Roof"):
                front = "x0" if lv.building == "main" else "z0"
                ctx = RoomCtx(lv, r, batch, sw, container, front, seed=_seed(lv.building + lv.name + "corridor"))

                def room_of_door(d, lv=lv):
                    rooms = lv.by_name(d.door.room)
                    return rooms[0].style if rooms else ""
                pre = RA.annex_corridor_pre(lv.name) if lv.building == "annex" else RA.main_corridor_pre(lv.name)
                corridor(ctx, lv.name, room_of_door, pre)
    g1, g2 = plans[("gym", "1F")], plans[("gym", "2F")]
    RG.court(batch, sw, g1.path + "/Props")
    RG.stage(batch, sw, g1.path + "/Props")
    RG.upper(batch, sw, g2.path + "/Props")
    import rooms_roof as RR
    roof = plans[("main", "Roof")]
    RR.main_roof(batch, sw, roof.path + "/Props", roof.footprint, roof.y)
    RR.roof_room(RoomCtx(roof, roof.by_name("옥상 출입실")[0], batch, sw, roof.path + "/Props", "z1", seed=_seed("roofroom")))
    ar, gr = plans[("annex", "Roof")], plans[("gym", "Roof")]
    RR.annex_roof(batch, ar.path + "/Props", ar.footprint, ar.y)
    RR.gym_roof(batch, gr.path + "/Props", gr.footprint, gr.y)
    f3 = plans[("main", "3F")]
    ext = f3.extension
    for r in ext.regions:
        if r.style == "classroom":
            ctx = RoomCtx(ext, r, batch, sw, f3.path + "/Otherworld", "x0", groups=("otherworld_only",), seed=_seed("2-7"))
            classroom(ctx, "2-7")
