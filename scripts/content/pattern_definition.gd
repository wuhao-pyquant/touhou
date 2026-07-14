extends RefCounted

const VERSION := 1

var id: String = ""
var duration_ticks: int = 0
var emitters: Array[Dictionary] = []
var tags: Array[String] = []

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	id = String(values.get("id", id))
	duration_ticks = int(values.get("duration_ticks", duration_ticks))
	emitters.clear()
	for emitter in values.get("emitters", []):
		if emitter is Dictionary:
			emitters.append(emitter.duplicate(true))
	tags.clear()
	for tag in values.get("tags", []):
		tags.append(String(tag))

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id is required")
	if duration_ticks <= 0:
		errors.append("duration_ticks must be positive")
	if emitters.is_empty():
		errors.append("at least one emitter is required")
	for index in range(emitters.size()):
		if String(emitters[index].get("id", "")).is_empty():
			errors.append("emitters[%d].id is required" % index)
		if String(emitters[index].get("topology", "")).is_empty():
			errors.append("emitters[%d].topology is required" % index)
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"id": id,
		"duration_ticks": duration_ticks,
		"emitters": emitters.duplicate(true),
		"tags": tags.duplicate(),
	}
