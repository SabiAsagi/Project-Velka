class_name NoiseEvents
extends RefCounted

# 프로젝트 벨카 - 소음 이벤트
# 샤무의 주의 끌기, 장애물 파괴 등 큰 소리를 반경 안의 청취자(괴이 등)에게 전달한다.
# 청취자는 NOISE_GROUP 그룹에 들어가고 hear_noise(position: Vector3, source: Node) 메서드를 구현한다.

const NOISE_GROUP := "noise_listener"


## 반경 안에서 소리를 들은 청취자 수를 반환한다.
static func emit(tree: SceneTree, position: Vector3, radius: float, source: Node) -> int:
	var heard := 0
	for listener in tree.get_nodes_in_group(NOISE_GROUP):
		if not (listener is Node3D and listener.has_method("hear_noise")):
			continue
		if (listener as Node3D).global_position.distance_to(position) <= radius:
			listener.hear_noise(position, source)
			heard += 1
	return heard
