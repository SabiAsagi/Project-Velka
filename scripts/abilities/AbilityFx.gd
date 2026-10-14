class_name AbilityFx
extends RefCounted

# 프로젝트 벨카 - 능력 연출 헬퍼
# 바닥으로 퍼지는 파동 링과 머리 위로 떠오르는 짧은 텍스트를 만든다. 생성된 노드는 연출이 끝나면 스스로 사라진다.


## center에서 radius까지 퍼지며 사라지는 바닥 링
static func spawn_ring(parent: Node, center: Vector3, color: Color, radius: float, seconds: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.93
	mesh.outer_radius = 1.0
	mesh.rings = 64
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, 0.85)
	var ring := MeshInstance3D.new()
	ring.name = "AbilityRing"
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = center + Vector3.UP * 0.06
	ring.scale = Vector3(0.2, 0.05, 0.2)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(radius, 0.05, radius), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
	return ring


## position 위로 떠오르며 사라지는 짧은 문구 (고함, 효과음 텍스트 등)
static func spawn_text(parent: Node, position: Vector3, text: String, color: Color, seconds: float = 1.4) -> Label3D:
	var label := Label3D.new()
	label.name = "AbilityText"
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 10
	label.font_size = 36
	label.pixel_size = 0.0012
	label.fixed_size = true
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.global_position = position
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", position + Vector3.UP * 0.8, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN).set_delay(seconds * 0.4)
	tween.chain().tween_callback(label.queue_free)
	return label


## 파동이 닿은 자리에 잠깐 떠올랐다 사라지는 위치 표시 (스파이 비전). 그 순간의 위치만 보여 준다.
## delay 뒤에 나타나 hold 초 동안 머물고 서서히 사라진다. 벽 너머에서도 보인다.
## ground 가 true 면 발밑에 작은 링을 함께 그리고, 글자는 label_height 위에 뜬다.
static func spawn_ping(parent: Node, position: Vector3, color: Color, text: String, delay: float, hold: float, ground: bool = true, label_height: float = 1.9) -> Node3D:
	var root := Node3D.new()
	root.name = "AbilityPing"
	parent.add_child(root)
	root.global_position = position
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Color(color, 0.0)
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3.UP * 0.06
	ring.scale = Vector3(0.15, 0.05, 0.15)
	ring.visible = ground
	root.add_child(ring)
	var label := Label3D.new()
	label.text = text
	label.modulate = Color(color, 0.0)
	label.outline_modulate = Color(0, 0, 0, 0.0)
	label.outline_size = 8
	label.font_size = 26
	label.pixel_size = 0.0009
	label.fixed_size = true
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3.UP * label_height
	root.add_child(label)
	var tween := root.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel()
	tween.tween_property(ring, "scale", Vector3(0.55, 0.05, 0.55), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.85, 0.2)
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.tween_property(label, "outline_modulate:a", 0.75, 0.25)
	tween.set_parallel(false)
	tween.tween_interval(hold)
	tween.set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
	return root
