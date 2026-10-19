class_name FlavorSpots
extends RefCounted

# 프로젝트 벨카 - 자잘한 사물·표지판 조사 지점
# 생성기로 만든 맵의 소품은 한 덩어리(MultiMesh)라 따로 조사할 수 없어서, 데이터의 위치에 조사 지점을 세운다.
#   data/inspectables/<장소>_flavor.json : { "<inspect_id>": { "pos": [x, y, z], "prompt": ..., "lines": [...], ... } }
#     pos 는 상호작용 지점(사물 앞, 눈높이쯤). 선택: "sign": {"text": "...", "yaw": 도, "at": [x, y, z], "size": [가로, 세로]}
#     를 주면 그 자리에 글자가 적힌 표지판 판을 세운다 (판에는 충돌이 없다).
#   대사는 InspectInteractable 형식 그대로 (speaker "inspector" + text_sabi / text_shamu 로 각자의 생각).
# 학교 게시판 포스터(Sprite3D "Poster", poster_<key>.png)는 posters() 로 그림마다 조사 지점을 붙인다.
# 조사 지점은 주변에서는 반짝이지 않고, 가까이 가서 대상이 됐을 때만 강조한다 (화면이 반짝임으로 어지럽지 않게).



## parent 아래에 data_path 의 조사 지점들을 세운다. 세운 개수를 돌려준다.
static func spawn(parent: Node, data_path: String) -> int:
	if parent == null or not FileAccess.file_exists(data_path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary:
		return 0
	var root := Node3D.new()
	root.name = "FlavorSpots"
	parent.add_child(root)
	var count := 0
	for id in data:
		var entry = data[id]
		if not (entry is Dictionary and entry.has("pos")):
			continue
		var pos := _vec(entry["pos"])
		if entry.has("sign"):
			_make_sign(root, entry["sign"], pos)
		_make_spot(root, String(id), data_path, pos)
		count += 1
	return count


## 학교 게시판 포스터마다 조사 지점을 붙인다 (inspect_id = poster_<key>)
static func posters(world: Node, data_path: String) -> int:
	if world == null:
		return 0
	var count := 0
	for node in world.find_children("Poster*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		if sprite.texture == null:
			continue
		var key := sprite.texture.resource_path.get_file().get_basename().trim_prefix("poster_")
		var front := sprite.global_basis.z.normalized()
		var spot := _make_spot(sprite.get_parent(), "poster_" + key, data_path, sprite.global_position + front * 0.35)
		spot.marker_height = 0.4
		count += 1
	return count


static func _make_spot(parent: Node, id: String, data_path: String, pos: Vector3) -> InspectInteractable:
	var spot := InspectInteractable.new()
	spot.name = "Flavor_" + id
	spot.inspect_id = id
	spot.data_path = data_path
	spot.show_nearby_marker = false
	spot.marker_height = 0.5
	parent.add_child(spot)
	spot.global_position = pos
	return spot


## 글자가 적힌 판 (어두운 판 + 흰 글자). 판의 앞면(+Z)이 yaw 방향을 본다.
static func _make_sign(parent: Node, sign: Dictionary, spot_pos: Vector3) -> void:
	var at := _vec(sign.get("at", [spot_pos.x, spot_pos.y + 0.5, spot_pos.z]))
	var size := _vec2(sign.get("size", [1.0, 0.6]))
	var holder := Node3D.new()
	holder.name = "Sign"
	parent.add_child(holder)
	holder.global_position = at
	holder.rotation.y = deg_to_rad(float(sign.get("yaw", 45.0)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(sign.get("color", "#141618"))
	mat.roughness = 0.7
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.03)
	box.material = mat
	plate.mesh = box
	holder.add_child(plate)
	var text := Label3D.new()
	text.text = String(sign.get("text", ""))
	text.font_size = 48
	text.outline_size = 0
	text.modulate = Color(sign.get("text_color", "#e8e4d8"))
	# 가장 긴 줄과 줄 수가 판 안에 들어가게 글자 크기를 맞춘다 (한글 한 글자 ≈ 글꼴 크기만큼 넓다)
	var longest := 1
	var lines := text.text.split("\n")
	for line in lines:
		longest = maxi(longest, line.length())
	var by_width := size.x * 0.88 / (longest * text.font_size)
	var by_height := size.y * 0.8 / (lines.size() * text.font_size * 1.25)
	text.pixel_size = minf(by_width, by_height)
	text.position = Vector3(0, 0, 0.02)
	holder.add_child(text)
	if bool(sign.get("post", false)):
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		# 바닥 높이: 따로 주지 않으면 조사 지점(눈높이)에서 1m 아래
		var floor_y := float(sign.get("floor_y", spot_pos.y - 1.0))
		cyl.height = maxf(0.1, at.y - size.y * 0.5 - floor_y)
		cyl.material = mat
		post.mesh = cyl
		holder.add_child(post)
		post.position = Vector3(0, -size.y * 0.5 - cyl.height * 0.5, -0.03)


static func _vec(v) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2])) if v is Array and v.size() >= 3 else Vector3.ZERO


static func _vec2(v) -> Vector2:
	return Vector2(float(v[0]), float(v[1])) if v is Array and v.size() >= 2 else Vector2.ONE
