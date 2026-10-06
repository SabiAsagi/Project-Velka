extends SceneTree

# 프로젝트 벨카 - 학교 맵 렌더링 시간 측정 (확인용)
# 실행: godot --path . -s res://tools/level_gen/school/perf.gd -- [비교할 셰이더 파일 경로 ...]
# 챕터 1 씬의 몇몇 위치에서 GPU·CPU 렌더링 시간을 평균 낸다. 셰이더 파일을 주면 school_surface 셰이더 코드를
# 차례로 그 파일들로 바꿔 같은 위치를 다시 잰다 (텍스처·사용감 레이어 비용 비교용).

const POINTS := [
	["main_2f_corridor_c", Vector3(1.0, 7.65, -56.6)],
	["main_2f_class_1_1", Vector3(-26.0, 7.65, -50.5)],
	["main_b1", Vector3(0.0, 0.05, -56.6)],
	["main_front", Vector3(2.0, 3.85, -41.5)],
	["gym_court", Vector3(0.0, 0.05, 42.25)],
	["n_trail_mid", Vector3(-86.6, 0.05, 0.0)],
	["site_parking", Vector3(3.0, 3.85, -70.5)],
]
const WARMUP := 60
const FRAMES := 180

var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/chapters/Chapter1_School.tscn")
	for i in 10:
		await process_frame
	var scene := current_scene
	var party = scene.get_node("PlayerParty")
	root.get_node("/root/GameManager").set_story_flag("tutorial_defeat_done", true)
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _measure(party, vp, "current")
	var shader: Shader = load("res://assets/shaders/school_surface.gdshader")
	for path in args:
		shader.code = FileAccess.get_file_as_string(path)
		await _measure(party, vp, path.get_file())
	quit()


func _measure(party, vp: RID, label: String) -> void:
	# 한 바퀴 먼저 돌아 셰이더 컴파일·텍스처 로드가 측정에 섞이지 않게 한다
	for p in POINTS:
		party.teleport_party(p[1])
		for i in 40:
			await process_frame
	var total_gpu := 0.0
	for p in POINTS:
		party.teleport_party(p[1])
		for i in WARMUP:
			await process_frame
		var gpu := 0.0
		var cpu := 0.0
		for i in FRAMES:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu /= FRAMES
		cpu /= FRAMES
		total_gpu += gpu
		print("PERF %s %-20s gpu %.2f ms  cpu %.2f ms" % [label, p[0], gpu, cpu])
	print("PERF %s average gpu %.2f ms (%s)" % [label, total_gpu / POINTS.size(), str(root.get_viewport().get_visible_rect().size)])
