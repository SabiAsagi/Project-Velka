extends Node

const SCHOOL_SCENE := preload("res://scenes/school/SchoolMap.tscn")
const EPSILON := 0.001

var checks: Array[Dictionary] = []


func _ready() -> void:
	var school_map := SCHOOL_SCENE.instantiate()
	add_child(school_map)
	await get_tree().process_frame
	_check_dimensions_and_registration(school_map)
	_check_required_site_structures(school_map)
	var failed: Array[String] = []
	for check in checks:
		if not check["passed"]:
			failed.append(check["name"])
	var report := {
		"phase": 1,
		"scene": "res://scenes/school/SchoolMap.tscn",
		"reference": "res://docs/맵 레퍼런스/학교/00_전체_배치.png",
		"reference_sha256": "39a33a062579ff9978de0dcbf7ab0a42a207daf0bfbaaf9d48620606f2a49523",
		"coordinate_system": {"origin":"athletic_field_center", "east":"+X", "north":"-Z", "up":"+Y"},
		"registration": "Option 1 Hybrid Conformance: confirmed metric dimensions take strict priority; PNG provides spatial arrangement and topology reference",
		"checks": checks,
		"failed": failed,
		"result": "PASS" if failed.is_empty() else "FAIL"
	}
	var output_dir := ProjectSettings.globalize_path("res://debug")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("phase1_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", false))
	file.close()
	print("PHASE1_VALIDATION_RESULT=", report["result"])
	get_tree().quit(0 if failed.is_empty() else 1)


func _check_dimensions_and_registration(school_map: Node) -> void:
	var site := school_map.get_node("Exterior/Site/SiteFloor") as CSGBox3D
	var field := school_map.get_node("Exterior/Site/AthleticField") as CSGBox3D
	var main_node: Node3D = school_map.get_node("Buildings/MainBuilding") if school_map.has_node("Buildings/MainBuilding") else school_map.get_node("MainBuilding")
	var annex_node: Node3D = school_map.get_node("Buildings/Annex") if school_map.has_node("Buildings/Annex") else school_map.get_node("Annex")
	var gym_node: Node3D = school_map.get_node("Buildings/Gym") if school_map.has_node("Buildings/Gym") else school_map.get_node("Gym")
	var main := main_node.get_node("Mass/BuildingEnvelope") as CSGBox3D
	var annex := annex_node.get_node("Mass/BuildingEnvelope") as CSGBox3D
	var gym := gym_node.get_node("Mass/BuildingEnvelope") as CSGBox3D
	_check_vec3(site.size, Vector3(190.0, 0.5, 140.0), "site_size_190x140")
	_check_vec3(site.position, Vector3(-12.0123, -0.25, -8.9777), "site_registration_from_final_png")
	_check_vec3(field.size, Vector3(70.0, 0.08, 45.0), "field_confirmed_size_70x45")
	_check_vec3(field.position, Vector3(0.0, 0.04, 0.0), "field_confirmed_origin")
	_check_vec3(main.size, Vector3(60.0, 15.2, 18.5), "main_confirmed_extent_60x18.5")
	_check_vec3(annex.size, Vector3(20.0, 11.4, 50.0), "annex_confirmed_extent_20x50")
	_check_vec3(gym.size, Vector3(40.0, 8.5, 26.0), "gym_confirmed_extent_40x26")
	_check_vec3(main_node.position, Vector3(0.0, 3.8, -54.0), "main_hybrid_position_and_f1_y")
	_check_vec3(annex_node.position, Vector3(-60.0, 0.0, -1.5), "annex_hybrid_position")
	_check_vec3(gym_node.position, Vector3(0.0, 0.0, 42.0), "gym_hybrid_position")


func _check_required_site_structures(school_map: Node) -> void:
	var main_node: Node3D = school_map.get_node("Buildings/MainBuilding") if school_map.has_node("Buildings/MainBuilding") else school_map.get_node("MainBuilding")
	var annex_node: Node3D = school_map.get_node("Buildings/Annex") if school_map.has_node("Buildings/Annex") else school_map.get_node("Annex")
	_check(school_map.has_node("Exterior/RearFacilities/RearParking"), "rear_parking_present", "RearParking")
	_check(main_node.has_node("WestFrontEntrance") and main_node.has_node("CenterFrontEntrance") and main_node.has_node("EastFrontEntrance"), "three_main_front_entrances", "west_center_east")
	_check(not _contains_node_name(school_map.get_node("Exterior"), "MainSidePath"), "no_invented_main_side_path", "no MainSidePath node")
	_check(school_map.has_node("Exterior/Grandstand/AssemblyPodium") and not _contains_node_name(school_map, "CentralGrandstandStair"), "assembly_podium_not_center_stair", "AssemblyPodium")
	var storage := school_map.get_node("Exterior/Grandstand/UnderStandStorage") as Node3D
	var storage_door := school_map.get_node("Exterior/Grandstand/UnderStandStorageFieldDoor") as Node3D
	_check(storage_door.position.z > storage.position.z, "storage_door_faces_field", "%s > %s" % [storage_door.position.z, storage.position.z])
	var annex_envelope := annex_node.get_node("Mass/BuildingEnvelope") as CSGBox3D
	_check(annex_envelope.size.z > annex_envelope.size.x, "annex_long_axis_north_south", str(annex_envelope.size))
	var west_court := school_map.get_node("Exterior/SouthFacilities/WestBasketballCourt") as CSGBox3D
	var east_court := school_map.get_node("Exterior/SouthFacilities/EastBasketballCourt") as CSGBox3D
	_check(west_court.position.x < 0.0 and east_court.position.x > 0.0, "two_side_basketball_courts", "%s / %s" % [west_court.position, east_court.position])
	var south_facilities := school_map.get_node("Exterior/SouthFacilities")
	_check(south_facilities.has_node("WestCourtStand") and south_facilities.has_node("EastCourtStand") and south_facilities.has_node("WestCourtFlowerTreeMass") and south_facilities.has_node("EastCourtFlowerTreeMass"), "court_stands_and_south_gardens", "west/east")
	var floodlights := school_map.get_node("Exterior/FieldFloodlights")
	_check(floodlights.get_child_count() == 4 and int(floodlights.get_meta("count")) == 4, "four_field_corner_floodlights", str(floodlights.get_child_count()))
	var road_network := school_map.get_node("Exterior/RoadNetwork")
	_check(road_network.get_child_count() == 6, "final_png_road_network", "본관 전면·별관 동측/연결·운동장 남/동측 6개 구간")
	var exterior_door_markers := school_map.get_node("Exterior/ExteriorDoorMarkers")
	_check(exterior_door_markers.get_child_count() == 9, "final_png_exterior_door_markers", "본관 4 + 별관 2 + 강당 3")
	var bridge := school_map.get_node("Connections/MainAnnexSkybridge")
	var turn := bridge.get_node("TurnAnchor") as Marker3D
	var annex_anchor := bridge.get_node("AnnexNorthEndAnchor") as Marker3D
	_check(turn.position.x < -30.0 and annex_anchor.position.z > turn.position.z and is_equal_approx(annex_anchor.position.x, turn.position.x), "bridge_main_f2_to_annex_f3_route", "%s -> %s" % [turn.position, annex_anchor.position])
	_check(school_map.rotation.is_zero_approx() and school_map.scale.is_equal_approx(Vector3.ONE) and not bool(school_map.get_meta("mirrored")), "site_not_rotated_or_mirrored", "rotation=0 scale=1 mirrored=false")
	_check(str(school_map.get_meta("reference_policy")) == "hybrid_scale_conformance", "hybrid_reference_policy", str(school_map.get_meta("reference_policy")))


func _check_vec3(actual: Vector3, expected: Vector3, name: String) -> void:
	_check(actual.distance_to(expected) <= EPSILON, name, "%s expected %s" % [actual, expected])


func _check(passed: bool, name: String, evidence: String) -> void:
	checks.append({"name":name, "passed":passed, "evidence":evidence})


func _contains_node_name(root: Node, target_name: String) -> bool:
	if root.name == target_name:
		return true
	for child in root.get_children():
		if _contains_node_name(child, target_name):
			return true
	return false
