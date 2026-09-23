extends Node

const FLOOR_DATA_PATH := "res://data/school/phase2_floor_layouts.json"
const EPSILON := 0.001

const FLOOR_SPECS := [
	{"id":"main_b1","scene":"res://scenes/school/floors/main/Main_B1.tscn","reference":"01_본관_B1.png","y":0.0,"orders":{"north_order_csv":"좌측 계단|전기실|시설관리 창고|중앙 계단|엘리베이터|소방펌프실·배관실|폐기물 임시보관실|우측 계단","south_order_csv":"구 도서관|기록 보관실|창고|보일러실"},"stairs":3,"elevators":1},
	{"id":"main_f1","scene":"res://scenes/school/floors/main/Main_1F.tscn","reference":"02_본관_1F.png","y":3.8,"orders":{"north_order_csv":"좌측 계단|여자 탈의실|여자 화장실|청소도구함|남자 화장실|남자 탈의실|중앙 계단|엘리베이터|경비실|학생회실|우측 계단","south_order_csv":"행정실|교무실|교장실|중앙 로비·정문 현관|보건실|방송실"},"stairs":3,"elevators":1,"entrances":4},
	{"id":"main_f2","scene":"res://scenes/school/floors/main/Main_2F.tscn","reference":"03_본관_2F.png","y":7.6,"orders":{"north_order_csv":"좌측 계단|여자 탈의실|여자 화장실|청소도구함|남자 화장실|남자 탈의실|중앙 계단|엘리베이터|일반 동아리실 1|일반 동아리실 2|우측 계단","south_order_csv":"1-1 교실|1-2 교실|1-3 교실|자습실|1-4 교실|1-5 교실|1-6 교실"},"stairs":3,"elevators":1},
	{"id":"main_f3","scene":"res://scenes/school/floors/main/Main_3F.tscn","reference":"04_본관_3F.png","y":11.4,"orders":{"north_order_csv":"좌측 계단|여자 탈의실|여자 화장실|청소도구함|남자 화장실|남자 탈의실|중앙 계단|엘리베이터|일반 동아리실 1|일반 동아리실 2|우측 계단","south_order_csv":"2-1 교실|2-2 교실|2-3 교실|자습실|2-4 교실|2-5 교실|2-6 교실"},"stairs":3,"elevators":1},
	{"id":"main_f4","scene":"res://scenes/school/floors/main/Main_4F.tscn","reference":"05_본관_4F.png","y":15.2,"orders":{"north_order_csv":"좌측 계단|여자 탈의실|여자 화장실|청소도구함|남자 화장실|남자 탈의실|중앙 계단|엘리베이터|일반 동아리실 1|일반 동아리실 2|우측 계단","south_order_csv":"3-1 교실|3-2 교실|3-3 교실|자습실|3-4 교실|3-5 교실|3-6 교실"},"stairs":3,"elevators":1},
	{"id":"main_roof","scene":"res://scenes/school/floors/main/Main_Roof.tscn","reference":"06_본관_옥상.png","y":19.0,"orders":{"north_order_csv":"실외기·환기 설비구역|옥상 출입실|저상 물탱크·배관·안테나 설비구역","south_order_csv":"좌측 옥상정원|중앙 옥상정원|우측 옥상정원"},"stairs":1,"elevators":0},
	{"id":"annex_f1","scene":"res://scenes/school/floors/annex/Annex_1F.tscn","reference":"07_별관_1F.png","y":0.0,"orders":{"support_order_csv":"좌측 계단|영양교사실|급식행정실|열린 급식 안내 공간|여자 화장실|청소도구함|남자 화장실|엘리베이터|매점|매점 창고|우측 계단","large_order_csv":"급식실|조리실|세척실|직원 휴게실|조리 식품 창고"},"stairs":2,"elevators":1,"entrances":2},
	{"id":"annex_f2","scene":"res://scenes/school/floors/annex/Annex_2F.tscn","reference":"08_별관_2F.png","y":3.8,"orders":{"support_order_csv":"좌측 계단|음악 준비실|미술 준비실|작품 전시 공간|여자 화장실|청소도구함|남자 화장실|엘리베이터|공동 과학 준비실|컴퓨터 기자재실|우측 계단","large_order_csv":"음악실|미술실|제1과학실|제2과학실|컴퓨터실"},"stairs":2,"elevators":1},
	{"id":"annex_f3","scene":"res://scenes/school/floors/annex/Annex_3F.tscn","reference":"09_별관_3F.png","y":7.6,"orders":{"support_order_csv":"좌측 계단|사서실|도서 정리실|사물함·반납 공간|여자 화장실|청소도구함|남자 화장실|엘리베이터|보존서고|복사·정보검색실|우측 계단","large_order_csv":"도서관|그룹학습실"},"stairs":2,"elevators":1},
	{"id":"gym_f1","scene":"res://scenes/school/floors/gym/Gym_1F.tscn","reference":"10_강당_1F.png","y":0.0,"orders":{"south_order_csv":"소품·의상 준비실|무대|음향·조명·무대장치실","center_order_csv":"마룻바닥","north_order_csv":"체육기구 창고|서측 화장실|북측 주출입홀|동측 화장실|행사물품 창고|강당 관리실|휠체어 관람 구역"},"stairs":2,"elevators":0,"entrances":3},
	{"id":"gym_f2","scene":"res://scenes/school/floors/gym/Gym_2F.tscn","reference":"11_강당_2F.png","y":3.8,"orders":{"south_order_csv":"소품실 상부|무대 상부|장치실 상부","north_order_csv":"촬영·관리대|카메라대 서|방송부스|카메라대 동","other_order_csv":"서측 관람석|북측 관람석|동측 관람석|중앙 개방부"},"stairs":2,"elevators":0}
]

var checks: Array[Dictionary] = []


func _ready() -> void:
	_validate_floor_data()
	for spec in FLOOR_SPECS:
		_validate_floor(spec)
	_validate_school_stack()

	var failed: Array[String] = []
	for check in checks:
		if not check["passed"]:
			failed.append(check["name"])
	var report := {
		"phase": 2,
		"floor_scene_count": FLOOR_SPECS.size(),
		"required_review_image_count": FLOOR_SPECS.size() * 2,
		"checks": checks,
		"failed": failed,
		"todo_confirm": [],
		"result": "PASS" if failed.is_empty() else "BLOCKED_REFERENCE_MISMATCH"
	}
	var output_dir := ProjectSettings.globalize_path("res://debug")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("phase2_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", false))
	file.close()
	print("PHASE2_VALIDATION_RESULT=", report["result"])
	for check in checks:
		print("[", "YES" if check["passed"] else "NO", "] ", check["name"], " — ", check["evidence"])
	get_tree().quit(0 if failed.is_empty() else 1)


func _validate_floor_data() -> void:
	var file := FileAccess.open(FLOOR_DATA_PATH, FileAccess.READ)
	_check(file != null, "Phase 2 레이아웃 데이터 로드", FLOOR_DATA_PATH)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Dictionary, "Phase 2 레이아웃 JSON 문법", "Dictionary")
	if data is Dictionary:
		_check(data["floor_scenes"].size() == 11, "층 씬 11개 선언", str(data["floor_scenes"].size()))
		_check(int(data["required_counts"]["review_images"]) == 22, "검토 이미지 22장 선언", str(data["required_counts"]["review_images"]))


func _validate_floor(spec: Dictionary) -> void:
	var resource := load(String(spec["scene"])) as PackedScene
	_check(resource != null, "%s 씬 로드" % spec["id"], String(spec["scene"]))
	if resource == null:
		return
	var floor := resource.instantiate()
	add_child(floor)
	_check(String(floor.get_meta("floor_id", "")) == spec["id"], "%s floor_id" % spec["id"], String(floor.get_meta("floor_id", "")))
	_check(String(floor.get_meta("reference", "")) == spec["reference"], "%s 레퍼런스 파일" % spec["id"], String(floor.get_meta("reference", "")))
	_check(is_equal_approx(float(floor.get_meta("floor_y_m", -999.0)), float(spec["y"])), "%s 바닥 Y" % spec["id"], str(floor.get_meta("floor_y_m", -999.0)))
	for key in spec["orders"]:
		var actual := String(floor.get_meta(key, ""))
		_check(actual == spec["orders"][key], "%s %s 방 순서" % [spec["id"], key], actual)
	var stair_key := "internal_stair_count" if String(spec["id"]).begins_with("gym_") else "stair_count"
	_check(int(floor.get_meta(stair_key, -1)) == int(spec["stairs"]), "%s 계단 수" % spec["id"], str(floor.get_meta(stair_key, -1)))
	_check(int(floor.get_meta("elevator_count", -1)) == int(spec["elevators"]), "%s 엘리베이터 수" % spec["id"], str(floor.get_meta("elevator_count", -1)))
	if spec.has("entrances"):
		_check(int(floor.get_meta("external_entrance_count", -1)) == int(spec["entrances"]), "%s 외부 출입구 수" % spec["id"], str(floor.get_meta("external_entrance_count", -1)))
	_check(floor.has_node("Debug/ReferenceOverlay") and floor.has_node("Debug/DebugTopCamera"), "%s 상부/오버레이 검토 도구" % spec["id"], "DebugTopCamera + ReferenceOverlay")
	if String(spec["id"]).begins_with("main_") and spec["id"] != "main_roof":
		_check(_box_size(floor, "Shell/Floor") == Vector3(60, 0.15, 18.5), "%s 본관 외곽 60×18.5m" % spec["id"], str(_box_size(floor, "Shell/Floor")))
		_check(is_equal_approx(_corridor_width(floor), 3.0), "%s 중앙 복도 3m" % spec["id"], str(_corridor_width(floor)))
	elif String(spec["id"]).begins_with("annex_"):
		_check(_box_size(floor, "Shell/Floor") == Vector3(52, 0.15, 17.5), "%s 별관 외곽 52×17.5m" % spec["id"], str(_box_size(floor, "Shell/Floor")))
		_check(int(floor.get_meta("center_stair_count", -1)) == 0, "%s 중앙 계단 없음" % spec["id"], str(floor.get_meta("center_stair_count", -1)))
		_check(is_equal_approx(_corridor_width(floor), 3.0), "%s 중앙 복도 3m" % spec["id"], str(_corridor_width(floor)))
	elif spec["id"] == "gym_f1":
		_check(_box_size(floor, "Shell/Floor") == Vector3(40, 0.2, 26), "gym_f1 강당 외곽 40×26m", str(_box_size(floor, "Shell/Floor")))
		_check(int(floor.get_meta("stage_stair_count")) == 2, "gym_f1 무대 계단 2개", str(floor.get_meta("stage_stair_count")))
	elif spec["id"] == "gym_f2":
		_check(String(floor.get_meta("seating_shape")) == "U", "gym_f2 ㄷ자 관람석", String(floor.get_meta("seating_shape")))
		_check(int(floor.get_meta("central_void_count")) == 1 and floor.has_node("CentralVoid/중앙 개방부"), "gym_f2 중앙 개방부 1개", "CentralVoid/중앙 개방부")
		_check(int(floor.get_meta("external_emergency_stair_count")) == 2 and int(floor.get_meta("external_exit_count")) == 2, "gym_f2 외부 비상계단·출구 각 2개", "2 / 2")
	_validate_review_corrections(String(spec["id"]), floor)
	floor.queue_free()


func _validate_review_corrections(floor_id: String, floor: Node) -> void:
	if floor_id.begins_with("main_") and floor_id != "main_roof":
		var stair_front := floor.get_node_or_null("Shell/NorthCorridorWall")
		var stair_front_open := stair_front != null and stair_front.get_child_count() == 2
		if floor_id in ["main_b1", "main_f1"]:
			var boundary_walls := floor.get_node_or_null("CorridorBoundaryWalls")
			stair_front_open = boundary_walls != null and boundary_walls.has_node("NorthWestToCenter") and boundary_walls.has_node("NorthCenterToEast")
		_check(stair_front_open, "%s 계단 앞 벽·문 제거" % floor_id, "북측 복도벽 2개 구간으로 분리")

	if floor_id in ["main_f2", "main_f3", "main_f4"]:
		var room_doors := floor.get_node("Doors/SouthRoomDoors")
		var expected_x := PackedFloat32Array([-29.0, -22.832, -20.848, -14.664, -12.663, -6.511, -4.526, 4.526, 6.511, 12.663, 14.664, 20.848, 22.832, 29.0])
		var actual_x := PackedFloat32Array()
		for marker in room_doors.get_children():
			actual_x.append((marker as Node3D).position.x)
		var symmetric := actual_x.size() == expected_x.size()
		if symmetric:
			for i in expected_x.size():
				if not is_equal_approx(actual_x[i], expected_x[i]):
					symmetric = false
					break
		_check(symmetric and int(room_doors.get_meta("marker_count", -1)) == 14, "%s 메인 방 문 좌우 대칭·각 2개" % floor_id, str(actual_x))

	if floor_id == "annex_f1":
		_check(floor.has_node("LargePartitions/CafeteriaWestWall") and floor.has_node("LargePartitions/FoodStorageEastWall"), "annex_f1 급식실 좌측·식품창고 우측 벽", "양쪽 외곽 칸막이 존재")
		_check(floor.has_node("LargePartitions/EntrancePassageSouthWall") and not (floor.get_node("Shell/SouthImageWall") as Node3D).visible, "annex_f1 출입구 통로 앞 벽 제거", "양 끝 통로 개방")
		var kitchen_door := floor.get_node_or_null("Doors/LargeRoomDoors/급식실-조리실 연결문")
		_check(kitchen_door != null and String(kitchen_door.get_meta("connects", "")) == "급식실|조리실", "annex_f1 급식실–조리실 문", "내부 연결문 존재")

	if floor_id == "annex_f3":
		var library_doors := floor.get_node("Doors/LargeRoomDoors")
		_check(not library_doors.has_node("도서관 출입문 2") and not library_doors.has_node("도서관 출입문 3") and int(library_doors.get_meta("marker_count", -1)) == 3, "annex_f3 도서관 중간 문 2개 제거", "도서관 끝문 2개 + 그룹학습실문")

	if floor_id == "gym_f1":
		var stage := floor.get_node("SouthStageBand/무대") as CSGBox3D
		var west_stair := floor.get_node("SouthStageBand/StageWestStair") as CSGBox3D
		var east_stair := floor.get_node("SouthStageBand/StageEastStair") as CSGBox3D
		_check(stage.size.is_equal_approx(Vector3(24.233, 0.45, 6.145)), "gym_f1 무대 복구", str(stage.size))
		_check(west_stair.position.z > stage.position.z and east_stair.position.z > stage.position.z, "gym_f1 무대 계단 실내 배치", "무대 전면 내부")
		_check(floor.has_node("SouthStageBand/StageFrontWalls/PropsFront") and floor.has_node("SouthStageBand/StageFrontWalls/StageFront") and floor.has_node("SouthStageBand/StageFrontWalls/EquipmentFront"), "gym_f1 무대 구역 위쪽 벽", "준비실·무대·장치실 전면벽")
		_check(not floor.has_node("NorthPartitions/P2") and not floor.has_node("NorthPartitions/P3") and not floor.has_node("NorthPartitions/ManagerWheelchair"), "gym_f1 계단–출입홀 벽·관리실 중앙벽 제거", "불필요 칸막이 없음")
		_check(floor.has_node("Doors/InternalDoors/서측 화장실 출입구") and floor.has_node("Doors/InternalDoors/동측 화장실 출입구"), "gym_f1 화장실 출입구 2개", "서측 + 동측")

	if floor_id == "gym_f2":
		var west_exit := floor.get_node("Doors/WestEmergencyExit") as CSGBox3D
		var east_exit := floor.get_node("Doors/EastEmergencyExit") as CSGBox3D
		var west_emergency_stair := floor.get_node("ExternalEmergencyStairs/WestEmergencyStair") as CSGBox3D
		var east_emergency_stair := floor.get_node("ExternalEmergencyStairs/EastEmergencyStair") as CSGBox3D
		_check(is_equal_approx(absf(west_exit.position.x), 19.75) and is_equal_approx(absf(east_exit.position.x), 19.75), "gym_f2 비상출입구 외벽 정렬", "x=±19.75m")
		_check(is_equal_approx(absf(west_emergency_stair.position.x), 21.17) and is_equal_approx(absf(east_emergency_stair.position.x), 21.17) and floor.has_node("ExternalEmergencyStairs/WestEmergencyLanding") and floor.has_node("ExternalEmergencyStairs/EastEmergencyLanding"), "gym_f2 외부 비상계단·참 정렬", "외벽 출구와 연결")


func _validate_school_stack() -> void:
	var packed := load("res://scenes/school/SchoolMap.tscn") as PackedScene
	var school := packed.instantiate()
	add_child(school)
	_check(int(school.get_meta("phase")) == 2, "SchoolMap Phase 2 등록", str(school.get_meta("phase")))
	var plans := school.get_node_or_null("FloorPlans") if school.has_node("FloorPlans") else school.get_node("Phase2FloorPlans")
	_check(not plans.visible, "Phase 2 층 스택 기본 숨김", "Phase 1 외관 검토 보존")
	_check((plans.get_node("Annex") as Node3D).rotation_degrees.is_equal_approx(Vector3(0, 90, 0)), "별관 방향 변환", "Y +90°")
	_check((plans.get_node("Gym") as Node3D).scale.is_equal_approx(Vector3(1, 1, -1)), "강당 방향 변환", "image bottom → site north, east/west unchanged")
	_check(is_equal_approx((plans.get_node("Main/F2") as Node3D).position.y, 7.6) and is_equal_approx((plans.get_node("Annex/F3") as Node3D).position.y, 7.6), "구름다리 양단 바닥 Y=7.6", "main_f2 ↔ annex_f3")
	_check(is_equal_approx((plans.get_node("Annex/F2") as Node3D).position.y, 3.8), "본관 2F–별관 2F 연결 없음", "별관 2F는 Y=3.8, 구름다리 표식 없음")
	var roof := plans.get_node("Main/Roof")
	_check(int(roof.get_meta("stair_count")) == 1 and int(roof.get_meta("elevator_count")) == 0, "옥상 중앙 계단만 연결", "stairs=1, elevators=0")
	school.queue_free()


func _box_size(root: Node, path: String) -> Vector3:
	var box := root.get_node(path) as CSGBox3D
	return box.size if box != null else Vector3.ZERO


func _corridor_width(root: Node) -> float:
	var corridor := root.get_node_or_null("Shell/CentralCorridor3m")
	if corridor == null:
		corridor = root.get_node_or_null("CentralCorridor3m")
	return float(corridor.get_meta("width_m", -1.0)) if corridor != null else -1.0


func _check(passed: bool, name: String, evidence: String) -> void:
	checks.append({"name": name, "passed": passed, "evidence": evidence})
