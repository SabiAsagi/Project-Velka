class_name VelkaCinematicArt
extends RefCounted
## Shared illustrated plates and isolated people, used by intro and CCTV evidence.
const PEOPLE := "res://assets/characters/cctv/people_atlas.png"
const PLATES := "res://assets/cinematics/intro_plates.png"
const CORRIDOR := "res://assets/cinematics/cctv_corridor.png"
static var _textures: Dictionary = {}

static func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture:
		_textures[path] = texture
	return texture

## Cover the destination without stretching the illustrated plate.
static func draw_plate(canvas: CanvasItem, rect: Rect2, index: int, tint: Color = Color.WHITE) -> bool:
	var texture := _texture(PLATES)
	if texture == null or index < 0 or index > 3:
		return false
	var cell := texture.get_size() / 2.0
	var source := Rect2(Vector2(index % 2, index / 2) * cell, cell)
	_draw_cover(canvas, texture, rect, source, tint)
	return true

## Draw the fixed corridor view; door and evidence remain separate overlays.
static func draw_corridor(canvas: CanvasItem, rect: Rect2) -> bool:
	var texture := _texture(CORRIDOR)
	if texture == null:
		return false
	canvas.draw_texture_rect(texture, rect, false)
	return true

## Atlas cells are kept whole; no generated image is resampled or cropped on disk.
static func draw_person(canvas: CanvasItem, foot: Vector2, height: float, index: int, tint: Color = Color.WHITE, clip_rect: Rect2 = Rect2()) -> bool:
	var texture := _texture(PEOPLE)
	if texture == null or index < 0 or index > 8:
		return false
	var cell := texture.get_size() / 3.0
	var source := Rect2(Vector2(index % 3, index / 3) * cell, cell)
	var h := height / 0.92
	var target := Rect2(foot - Vector2(h * cell.x / cell.y * 0.5, h * 0.97), Vector2(h * cell.x / cell.y, h))
	var mirror := index == 8
	if clip_rect.has_area():
		var clipped := target.intersection(clip_rect)
		if not clipped.has_area():
			return true
		var ratio := (clipped.position - target.position) / target.size
		var fraction := clipped.size / target.size
		source.position += source.size * Vector2(1.0 - ratio.x - fraction.x if mirror else ratio.x, ratio.y)
		source.size *= fraction
		target = clipped
	if mirror:
		var pivot := target.get_center()
		canvas.draw_set_transform(pivot, 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(texture, Rect2(-target.size * 0.5, target.size), source, tint)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect_region(texture, target, source, tint)
	return true

## Ordinary civilians from the atlas, rather than association members, appear in the montage photos.
static func draw_portrait(canvas: CanvasItem, rect: Rect2, index: int, tint: Color = Color.WHITE) -> bool:
	var texture := _texture(PEOPLE)
	if texture == null or index < 0 or index > 8:
		return false
	var cell := texture.get_size() / 3.0
	var source := Rect2(Vector2(index % 3, index / 3) * cell + cell * Vector2(0.2, 0.015), cell * Vector2(0.6, 0.5))
	_draw_cover(canvas, texture, rect, source, tint)
	return true

static func _draw_cover(canvas: CanvasItem, texture: Texture2D, rect: Rect2, source: Rect2, tint: Color) -> void:
	var aspect := rect.size.x / maxf(1.0, rect.size.y)
	if source.size.x / source.size.y > aspect:
		var width := source.size.y * aspect
		source.position.x += (source.size.x - width) * 0.5
		source.size.x = width
	else:
		var height := source.size.x / aspect
		source.position.y += (source.size.y - height) * 0.5
		source.size.y = height
	canvas.draw_texture_rect_region(texture, rect, source, tint)

