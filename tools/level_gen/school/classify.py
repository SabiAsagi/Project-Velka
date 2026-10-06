# -*- coding: utf-8 -*-
"""블록아웃 박스 분류: 벽 / 바닥 / 방 구역 / 문 / 출입구 / 계단 / 특수 구조물"""
import re

HANGUL = re.compile(r"[가-힣]")
EXTERIOR_WALL_NAMES = ("NorthWall", "SouthWall", "WestWall", "EastWall", "NorthImageWall", "SouthImageWall",
                       "LeftImageWall", "RightImageWall", "WestWallSouth", "WestWallNorth", "EastWallSouth",
                       "EastWallNorth", "NorthWallWest", "NorthWallEast")
# 블록아웃 좌표가 복도와 어긋나 있어 생성기가 직접 처리하는 표식
MANUAL = ("SkybridgeDoorWest", "SkybridgeDoor", "LockedRoofDoor", "EastSealedWall")


def classify(box):
    n, path = box.name, box.path
    sx, sy, sz = box.size
    if "Debug" in path or n in ("Ceiling",) or box.kind == "hidden_box":
        return "skip"
    if n in MANUAL:
        return "manual"
    if box.kind == "door_marker" or n.startswith("Door_"):
        return "door"
    if ("Entrance" in n or "EmergencyExit" in n) and sy < 0.5:
        return "entrance"
    if n == "Floor" or "UShapeFloor/" in path:
        return "slab"
    if n == "CentralCorridor3m":
        return "corridor"
    if n == "옥상 출입실":
        return "roof_room"
    if n == "무대":
        return "stage"
    if n in ("StageWestStair", "StageEastStair"):
        return "stage_step"
    if "InternalStairs/" in path:
        return "gym_upper_stair"
    if "ExternalEmergencyStairs/" in path:
        return "emergency_landing" if "Landing" in n else "emergency_stair"
    if "Seating/" in path or "NorthControlBand/" in path:
        return "seating"
    if n in ("CentralPath", "HorizontalPath"):
        return "path"
    if sy >= 1.0 and min(sx, sz) <= 0.45:
        return "wall_out" if (n in EXTERIOR_WALL_NAMES or "OuterWalls/" in path or "Perimeter/" in path
                              or n == "EntrancePassageSouthWall") else "wall"
    if HANGUL.search(n) and sy <= 0.5:
        if "계단" in n:
            return "stair_zone"
        if "엘리베이터" in n:
            return "elevator_zone"
        return "room"
    return "other"


def level_index(box):
    from source import BUILDINGS
    names = [lv for lv, _ in BUILDINGS[box.building]["levels"]]
    return names.index(box.level)


def base_y(box):
    return level_index(box) * 3.8


KO_BUILDING = {"main": "본관", "annex": "별관", "gym": "강당"}


def display_name(box):
    return "%s %s %s" % (KO_BUILDING[box.building], box.level, box.name)
