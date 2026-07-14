extends RefCounted

const VERSION := 1

var stage_id: String = ""
var events: Array[Dictionary] = []
var cursor: int = 0

func _init(initial_stage_id: String = "", initial_events: Array = []) -> void:
	configure(initial_stage_id, initial_events)

func configure(next_stage_id: String, source_events: Array) -> void:
	stage_id = next_stage_id
	events.clear()
	for source in source_events:
		if source is Dictionary:
			events.append(source.duplicate(true))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tick := int(a.get("tick", -1))
		var b_tick := int(b.get("tick", -1))
		return a_tick < b_tick if a_tick != b_tick else String(a.get("id", "")) < String(b.get("id", ""))
	)
	cursor = 0

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if stage_id.is_empty():
		errors.append("stage_id is required")
	var seen_ids := {}
	for index in range(events.size()):
		var event := events[index]
		var event_id := String(event.get("id", ""))
		if event_id.is_empty():
			errors.append("events[%d].id is required" % index)
		elif seen_ids.has(event_id):
			errors.append("events[%d].id must be unique" % index)
		seen_ids[event_id] = true
		if int(event.get("tick", -1)) < 0:
			errors.append("events[%d].tick must be non-negative" % index)
		if String(event.get("kind", "")).is_empty():
			errors.append("events[%d].kind is required" % index)
		if event.has("payload") and not (event.payload is Dictionary):
			errors.append("events[%d].payload must be a Dictionary" % index)
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func reset() -> void:
	cursor = 0

func events_at_tick(tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if int(event.get("tick", -1)) == tick:
			result.append(event.duplicate(true))
	return result

func pop_events_through(tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while cursor < events.size() and int(events[cursor].get("tick", -1)) <= tick:
		result.append(events[cursor].duplicate(true))
		cursor += 1
	return result

func to_dict() -> Dictionary:
	return {"version": VERSION, "stage_id": stage_id, "events": events.duplicate(true)}
