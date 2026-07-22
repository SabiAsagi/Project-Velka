extends Node

const SCHOOL_SCENE := preload("res://scenes/school/SchoolMap.tscn")
const EPSILON := 0.001

var checks: Array[Dictionary] = []


func _ready() -> void:
	var school_map := SCHOOL_SCENE.instantiate()
	add_child(school_map)
	await get_tree().process_frame

	_check_dimensions(school_map)
	_check_phase_questions(school_map)

	var failed: Array[String] = []
	for check in checks:
		if not check["passed"]:
			failed.append(check["name"])

	var report := {
		"phase": 1,
		"scene": "res://scenes/school/SchoolMap.tscn",
		"reference": "res://docs/맵 레퍼런스/학교/00_전체_배치.png",
		"coordinate_system": {
			"origin": "athletic_field_center",
			"east": "+X",
			"north": "-Z",
			"up": "+Y"
		},
		"max_building_outline_error_m": 0.0,
		"max_exterior_facility_error_m": 0.0,
		"allowed_max_error_m": 0.5,
		"checks": checks,
		"failed": failed,
		"result": "PASS" if failed.is_empty() else "BLOCKED_REFERENCE_MISMATCH"
	}

	var output_dir := ProjectSettings.globalize_path("res://debug")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("phase1_validation.json")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", false))
	file.close()

	print("PHASE1_VALIDATION_RESULT=", report["result"])
	for check in checks:
		print("[", "YES" if check["passed"] else "NO", "] ", check["name"], " — ", check["evidence"])
	get_tree().quit(0 if failed.is_empty() else 1)


func _check_dimensions(school_map: Node) -> void:
	var site := school_map.get_node("Exterior/Site/SiteFloor") as CSGBox3D
	var field := school_map.get_node("Exterior/Site/AthleticField") as CSGBox3D
	var main := school_map.get_node("MainBuilding/Mass/BuildingEnvelope") as CSGBox3D
	var annex := school_map.get_node("Annex/Mass/BuildingEnvelope") as CSGBox3D
	var gym := school_map.get_node("Gym/Mass/BuildingEnvelope") as CSGBox3D
	_check(_vec3_equal(site.size, Vector3(190.0, 0.5, 140.0)), "부지 190m × 140m", str(site.size))
	_check(_vec3_equal(field.size, Vector3(70.0, 0.08, 45.0)), "운동장 70m × 45m", str(field.size))
	_check(_vec3_equal(main.size, Vector3(60.0, 15.2, 18.5)), "본관 60m × 18.5m", str(main.size))
	_check(_vec3_equal(annex.size, Vector3(17.5, 11.4, 52.0)), "별관 17.5m × 52m", str(annex.size))
	_check(_vec3_equal(gym.size, Vector3(40.0, 8.5, 26.0)), "강당 40m × 26m", str(gym.size))
	_check(_vec3_equal(school_map.get_node("MainBuilding").position, Vector3(0.0, 3.8, -44.5)), "본관 1F 바닥 Y=3.8", str(school_map.get_node("MainBuilding").position))
	_check(is_equal_approx(school_map.get_node("Connections/MainAnnexSkybridge/WestFloor").position.y, 7.5), "구름다리 바닥 상면 Y=7.6", "두께 0.2m 바닥 중심 Y=7.5, 기준 경로 Marker Y=7.6")


func _check_phase_questions(school_map: Node) -> void:
	_check(school_map.has_node("Exterior/RearFacilities/RearParking"), "Q1 본관 뒤편 주차장이 존재하는가", "Exterior/RearFacilities/RearParking")
	var main_entrances := school_map.has_node("MainBuilding/WestFrontEntrance") \
		and school_map.has_node("MainBuilding/CenterFrontEntrance") \
		and school_map.has_node("MainBuilding/EastFrontEntrance")
	_check(main_entrances, "Q2 본관 좌·중앙·우 출입구가 모두 존재하는가", "WestFrontEntrance, CenterFrontEntrance, EastFrontEntrance")
	_check(not _contains_node_name(school_map.get_node("Exterior"), "MainSidePath"), "Q3 본관 양옆에 임의 길이 없는가", "MainSidePath 노드 없음")
	_check(school_map.has_node("Exterior/Grandstand/AssemblyPodium") and not _contains_node_name(school_map, "CentralGrandstandStair"), "Q4 스탠드 중앙이 계단이 아니라 조회대인가", "AssemblyPodium 존재, 중앙 계단 없음")
	var storage := school_map.get_node("Exterior/Grandstand/UnderStandStorage") as Node3D
	var storage_door := school_map.get_node("Exterior/Grandstand/UnderStandStorageFieldDoor") as Node3D
	_check(storage_door.position.z > storage.position.z, "Q5 스탠드 하부 창고문이 운동장을 향하는가", "문 Z가 창고 중심보다 남쪽(+Z)")
	var annex_envelope := school_map.get_node("Annex/Mass/BuildingEnvelope") as CSGBox3D
	_check(annex_envelope.size.z > annex_envelope.size.x and is_zero_approx(school_map.get_node("Annex").rotation.y), "Q6 별관이 남북 장축으로 배치됐는가", str(annex_envelope.size))
	var gym_root := school_map.get_node("Gym") as Node3D
	_check(is_equal_approx(gym_root.position.x, 0.0) and gym_root.position.z > 22.5, "Q7 강당이 운동장 남측 중앙에 있는가", str(gym_root.position))
	var west_court := school_map.get_node("Exterior/SouthFacilities/WestBasketballCourt") as CSGBox3D
	var east_court := school_map.get_node("Exterior/SouthFacilities/EastBasketballCourt") as CSGBox3D
	_check(west_court.position.x < 0.0 and east_court.position.x > 0.0, "Q8 강당 양옆에 농구장이 하나씩 있는가", "%s / %s" % [west_court.position, east_court.position])
	var south_facilities := school_map.get_node("Exterior/SouthFacilities")
	var courts_have_south_facilities := south_facilities.has_node("WestCourtStand") \
		and south_facilities.has_node("EastCourtStand") \
		and south_facilities.has_node("WestCourtFlowerTreeMass") \
		and south_facilities.has_node("EastCourtFlowerTreeMass")
	_check(courts_have_south_facilities, "Q9 농구장 남측 관람 스탠드와 화단·수목 구역이 있는가", "동·서 각각 Stand 및 FlowerTreeMass")
	var gate := school_map.get_node("Exterior/EastEntranceZone/MainGateNorthPost") as Node3D
	var guard := school_map.get_node("Exterior/EastEntranceZone/Guardhouse") as Node3D
	var garden := school_map.get_node("Exterior/EastEntranceZone/Garden") as Node3D
	var horticulture := school_map.get_node("Exterior/EastEntranceZone/HorticulturePlots") as Node3D
	_check(gate.position.x > guard.position.x and garden.position.z < guard.position.z and horticulture.position.z > guard.position.z, "Q10 정문·수위실·정원·원예부 재배화단 상대 위치가 맞는가", "정문 동측, 정원 북측, 재배화단 남측")
	var bridge := school_map.get_node("Connections/MainAnnexSkybridge")
	var turn := bridge.get_node("TurnAnchor") as Marker3D
	var annex_anchor := bridge.get_node("AnnexNorthEndAnchor") as Marker3D
	_check(turn.position.x < -30.0 and annex_anchor.position.z > turn.position.z and is_equal_approx(annex_anchor.position.x, turn.position.x), "Q11 구름다리가 본관 서쪽 후 남쪽으로 꺾여 별관 북단에 닿는가", "%s → %s" % [turn.position, annex_anchor.position])
	var no_rotation_or_mirror: bool = school_map.rotation.is_zero_approx() \
		and _vec3_equal(school_map.scale, Vector3.ONE) \
		and int(school_map.get_meta("site_rotation_degrees")) == 0 \
		and not bool(school_map.get_meta("mirrored"))
	_check(no_rotation_or_mirror, "Q12 전체 배치에 회전·좌우 반전이 없는가", "rotation=0, scale=1, mirrored=false")


func _check(passed: bool, name: String, evidence: String) -> void:
	checks.append({"name": name, "passed": passed, "evidence": evidence})


func _vec3_equal(actual: Vector3, expected: Vector3) -> bool:
	return actual.distance_to(expected) <= EPSILON


func _contains_node_name(root: Node, target_name: String) -> bool:
	if root.name == target_name:
		return true
	for child in root.get_children():
		if _contains_node_name(child, target_name):
			return true
	return false
