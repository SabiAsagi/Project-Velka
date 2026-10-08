class_name NavGrid
extends RefCounted

# 프로젝트 벨카 - 격자 길찾기 (경비원 등 NPC 용)
# 한 층(y)의 사각 영역을 cell 간격으로 나눠, 사람이 설 수 있는 칸인지 물리 질의로 검사한 뒤 AStarGrid2D 로 길을 찾는다.
# 같은 층·영역은 한 번만 만들어 공유한다 (for_area). 문이 열리거나 장애물이 부서지면 invalidate() 로 다시 검사한다.

const CELL := 0.5
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.2

static var _cache: Dictionary = {}
static var _version: int = 0

var origin := Vector2.ZERO        # 영역 왼쪽 위 (x, z)
var cols := 0
var rows := 0
var y := 0.0
var astar := AStarGrid2D.new()
var _built_version := -1
var _world: World3D
var _exclude: Array[RID] = []


## 문·장애물 상태가 바뀌었다: 모든 격자를 다음 길찾기 때 다시 검사한다
static func invalidate() -> void:
	_version += 1


## 영역·층이 같은 격자를 공유한다
static func for_area(world: World3D, area: Rect2, floor_y: float) -> NavGrid:
	var key := "%d|%s|%.1f" % [world.get_instance_id(), str(area), floor_y]
	if not _cache.has(key) or not is_instance_valid(_cache[key]._world):
		var grid := NavGrid.new()
		grid._world = world
		grid.origin = area.position
		grid.cols = maxi(1, int(ceil(area.size.x / CELL)))
		grid.rows = maxi(1, int(ceil(area.size.y / CELL)))
		grid.y = floor_y
		grid.astar.region = Rect2i(0, 0, grid.cols, grid.rows)
		grid.astar.cell_size = Vector2(1, 1)
		grid.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.astar.update()
		_cache[key] = grid
	return _cache[key]


## 길 찾기에서 벽으로 치지 않을 몸들 (경비원·파티원 자신)
func add_exclusions(rids: Array[RID]) -> void:
	for rid in rids:
		if not _exclude.has(rid):
			_exclude.append(rid)
			_built_version = -1


func _ensure_built() -> void:
	if _built_version == _version:
		return
	_built_version = _version
	var space := _world.direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = _exclude
	for r in rows:
		for c in cols:
			var p := cell_center(Vector2i(c, r))
			query.transform = Transform3D(Basis(), Vector3(p.x, y + 0.25 + BODY_HEIGHT * 0.5, p.z))
			astar.set_point_solid(Vector2i(c, r), not space.intersect_shape(query, 1).is_empty())


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x - origin.x) / CELL)), 0, cols - 1), clampi(int(floor((p.z - origin.y) / CELL)), 0, rows - 1))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * CELL, y, origin.y + (c.y + 0.5) * CELL)


func is_walkable(p: Vector3) -> bool:
	_ensure_built()
	return not astar.is_point_solid(cell_of(p))


## 막힌 칸이면 가장 가까운 빈 칸
func _nearest_open(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for radius in range(1, 7):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var n := c + Vector2i(dx, dy)
				if astar.region.has_point(n) and not astar.is_point_solid(n):
					return n
	return c


## from -> to 길 (월드 좌표, 첫 칸은 빼고 마지막은 목적지 그대로). 못 가면 빈 배열.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	_ensure_built()
	var a := _nearest_open(cell_of(from))
	var b := _nearest_open(cell_of(to))
	var out := PackedVector3Array()
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return out
	var ids := astar.get_id_path(a, b)
	if ids.is_empty():
		return out
	for i in range(1, ids.size()):
		out.append(cell_center(ids[i]))
	var end := Vector3(to.x, y, to.z)
	if out.is_empty() or not astar.is_point_solid(cell_of(to)):
		out.append(end)
	return out
