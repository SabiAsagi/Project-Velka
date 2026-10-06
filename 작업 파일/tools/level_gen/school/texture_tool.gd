extends SceneTree

# 프로젝트 벨카 - 학교 표면 텍스처 도구
# 실행: godot --headless --path . -s res://tools/level_gen/school/texture_tool.gd
# 1) 공용 노이즈 텍스처(assets/textures/school/surface_noise.png, 이음매 없는 512px RGBA)를 만든다.
#    R = 큰 얼룩(저주파), G = 중간 얼룩(도메인 왜곡), B = 잔결(고주파), A = 금·긁힘(셀 경계, 0에 가까울수록 선)
# 2) 문짝용 파생 텍스처(StandardMaterial3D 삼면 투영용: 세로 나뭇결, 대비를 낮춘 회색 도장면)를 만든다.
# 3) 학교 셰이더가 쓰는 텍스처들의 선형 평균색을 texture_stats.json에 기록한다 (palette.py가 읽는다).
#    셰이더는 텍스처를 평균색으로 나눠 무늬만 얹으므로, 팔레트 색이 그대로 표면의 평균색이 된다.

const NOISE_PATH := "res://assets/textures/school/surface_noise.png"
const STATS_PATH := "res://tools/level_gen/school/texture_stats.json"
const TEXTURE_DIRS := ["res://assets/third_party/ambientcg", "res://assets/third_party/screaming_brain_studios/horror_textures_128",
	"res://assets/textures/school"]
const AMBIENTCG := "res://assets/third_party/ambientcg"
const SIZE := 512


func _init() -> void:
	_make_noise()
	_make_door_textures()
	_write_stats()
	quit()


func _noise(type: int, freq: float, octaves: int, seed: int, fractal: int = FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	n.seed = seed
	return n


func _make_noise() -> void:
	var big := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006, 4, 11)
	var mid := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 5, 23)
	mid.domain_warp_enabled = true
	mid.domain_warp_amplitude = 18.0
	mid.domain_warp_frequency = 0.01
	var fine := _noise(FastNoiseLite.TYPE_VALUE_CUBIC, 0.16, 3, 37)
	var cell := _noise(FastNoiseLite.TYPE_CELLULAR, 0.022, 1, 41, FastNoiseLite.FRACTAL_NONE)
	cell.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cell.domain_warp_enabled = true
	cell.domain_warp_amplitude = 9.0
	cell.domain_warp_frequency = 0.03
	var layers := []
	for n in [big, mid, fine, cell]:
		layers.append(n.get_seamless_image(SIZE, SIZE, false, false, 0.12, true))
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			out.set_pixel(x, y, Color(layers[0].get_pixel(x, y).r, layers[1].get_pixel(x, y).r,
				layers[2].get_pixel(x, y).r, layers[3].get_pixel(x, y).r))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NOISE_PATH.get_base_dir()))
	out.save_png(ProjectSettings.globalize_path(NOISE_PATH))
	print("noise -> ", NOISE_PATH)


# 픽셀을 이미지 평균 쪽으로 당겨 대비를 낮춘다 (keep = 남길 대비 비율). gray면 밝기만 남긴다
func _flatten(img: Image, keep: float, gray: bool) -> void:
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	var mean := Color(0, 0, 0)
	for y in h:
		for x in w:
			mean += img.get_pixel(x, y)
	mean = mean / float(w * h)
	var mean_l := mean.get_luminance()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if gray:
				var l := lerpf(mean_l, c.get_luminance(), keep)
				img.set_pixel(x, y, Color(l, l, l))
			else:
				img.set_pixel(x, y, mean.lerp(c, keep))


func _make_door_textures() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/textures/school")
	var wood := Image.load_from_file(ProjectSettings.globalize_path(AMBIENTCG + "/Wood049/Wood049_Color.jpg"))
	wood.rotate_90(CLOCKWISE)
	_flatten(wood, 0.85, false)
	wood.save_jpg(dir.path_join("DoorWood_Color.jpg"), 0.9)
	var paint := Image.load_from_file(ProjectSettings.globalize_path(AMBIENTCG + "/PaintedMetal002/PaintedMetal002_Color.jpg"))
	_flatten(paint, 0.45, true)
	paint.save_jpg(dir.path_join("DoorPaint_Color.jpg"), 0.9)
	print("door textures -> ", dir)


func _avg_linear(path: String) -> Color:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var acc := Vector3.ZERO
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y).srgb_to_linear()
			acc += Vector3(c.r, c.g, c.b)
	acc /= 4096.0
	return Color(acc.x, acc.y, acc.z)


func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with("_Color.jpg") or (f.ends_with(".png") and f.begins_with("Horror_")):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


func _write_stats() -> void:
	var files := []
	for d in TEXTURE_DIRS:
		_collect(d, files)
	files.sort()
	var stats := {}
	for path in files:
		var key: String = path.get_file().get_basename().trim_suffix("_Color").trim_suffix("-128x128")
		var c := _avg_linear(path)
		stats[key] = {"path": path, "avg": [snappedf(c.r, 0.0001), snappedf(c.g, 0.0001), snappedf(c.b, 0.0001)]}
	var f := FileAccess.open(ProjectSettings.globalize_path(STATS_PATH), FileAccess.WRITE)
	f.store_string(JSON.stringify(stats, "  ", true) + "\n")
	f.close()
	print("stats -> ", STATS_PATH, " (", stats.size(), ")")
