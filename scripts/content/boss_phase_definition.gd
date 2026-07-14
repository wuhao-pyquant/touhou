extends RefCounted

const VERSION := 1
const KINDS := ["nonspell", "spell"]

var id: String = ""
var display_name: String = ""
var kind: String = "nonspell"
var hit_points: float = 0.0
var timeout_ticks: int = 0
var pattern_id: String = ""
var next_phase_id: String = ""

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	id = String(values.get("id", id))
	display_name = String(values.get("display_name", display_name))
	kind = String(values.get("kind", kind))
	hit_points = float(values.get("hit_points", hit_points))
	timeout_ticks = int(values.get("timeout_ticks", timeout_ticks))
	pattern_id = String(values.get("pattern_id", pattern_id))
	next_phase_id = String(values.get("next_phase_id", next_phase_id))

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id is required")
	if display_name.is_empty():
		errors.append("display_name is required")
	if kind not in KINDS:
		errors.append("kind must be nonspell or spell")
	if hit_points <= 0.0:
		errors.append("hit_points must be positive")
	if timeout_ticks <= 0:
		errors.append("timeout_ticks must be positive")
	if pattern_id.is_empty():
		errors.append("pattern_id is required")
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"id": id,
		"display_name": display_name,
		"kind": kind,
		"hit_points": hit_points,
		"timeout_ticks": timeout_ticks,
		"pattern_id": pattern_id,
		"next_phase_id": next_phase_id,
	}
