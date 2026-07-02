extends Control
class_name RuleBookSystem

const RULES_PATH := "res://data/anomaly_rules.json"
const STATUS_LABELS := {
	"confirmed": "[확정]",
	"assumed": "[추정]",
	"unknown": "[미확인]",
	"false": "[오류]",
	"variant": "[변칙]",
}

@export var list_container_path: NodePath

func _ready() -> void:
	load_rules()

func load_rules() -> void:
	var container := get_node_or_null(list_container_path)
	if container == null:
		container = self
	_clear_container(container)
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if file == null:
		_add_label(container, "규칙 파일을 찾을 수 없습니다.")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_add_label(container, "규칙 파일 형식이 올바르지 않습니다.")
		return
	for anomaly in parsed.get("anomalies", []):
		_add_label(container, anomaly.get("name", "이름 없는 괴이"))
		var rules: Dictionary = anomaly.get("rules", {})
		for status in STATUS_LABELS.keys():
			for rule_text in rules.get(status, []):
				_add_label(container, "%s %s" % [STATUS_LABELS[status], rule_text])

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_label(container: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	container.add_child(label)
