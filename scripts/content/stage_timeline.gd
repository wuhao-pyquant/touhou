extends RefCounted

const VERSION := 1

var stage_id: String = ""
var events: Array[Dictionary] = []
var cursor: int = 0

# M1 choreography metadata. These fields are optional so the version-1
# constructor remains a valid, minimal timeline contract.
var stage_index: int = 0
var display_name: String = ""
var location: String = ""
var midboss_id: String = ""
var boss_id: String = ""
var approved_identity: String = ""
var segments: Array[Dictionary] = []
var midboss: Dictionary = {}
var preboss_climax: Dictionary = {}
var normal_route: String = ""
var hard_route: String = ""
var score_route: Dictionary = {}

func _init(initial_stage_id: String = "", initial_events: Array = []) -> void:
	configure(initial_stage_id, initial_events)

func configure(next_stage_id: String, source_events: Array) -> void:
	stage_id = next_stage_id
	_clear_m1_metadata()
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

func configure_m1(values: Dictionary) -> void:
	var authored_events: Array[Dictionary] = []
	var source_beats = values.get("beats", [])
	if source_beats is Array:
		for source in source_beats:
			if not (source is Dictionary):
				continue
			var payload: Dictionary = source.duplicate(true)
			payload.erase("id")
			payload.erase("frame")
			payload.erase("kind")
			authored_events.append({
				"id": String(source.get("id", "")),
				"tick": int(source.get("frame", -1)),
				"frame": int(source.get("frame", -1)),
				"kind": String(source.get("kind", "")),
				"payload": payload,
			})
	configure(String(values.get("stage_id", "")), authored_events)
	stage_index = int(values.get("stage_index", 0))
	display_name = String(values.get("display_name", ""))
	location = String(values.get("location", ""))
	midboss_id = String(values.get("midboss_id", ""))
	boss_id = String(values.get("boss_id", ""))
	approved_identity = String(values.get("approved_identity", ""))
	var source_segments = values.get("segments", [])
	if source_segments is Array:
		for source in source_segments:
			if source is Dictionary:
				segments.append(source.duplicate(true))
	var source_midboss = values.get("midboss", {})
	if source_midboss is Dictionary:
		midboss = source_midboss.duplicate(true)
	var source_climax = values.get("preboss_climax", {})
	if source_climax is Dictionary:
		preboss_climax = source_climax.duplicate(true)
	normal_route = String(values.get("normal_route", ""))
	hard_route = String(values.get("hard_route", ""))
	var source_score_route = values.get("score_route", {})
	if source_score_route is Dictionary:
		score_route = source_score_route.duplicate(true)

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
	if is_m1_contract():
		if stage_index <= 0:
			errors.append("stage_index must be positive for an M1 timeline")
		if segments.size() != 3:
			errors.append("M1 timeline must contain exactly three segments")
		var seen_segments := {}
		for index in range(segments.size()):
			var segment_id := String(segments[index].get("id", ""))
			if segment_id.is_empty():
				errors.append("segments[%d].id is required" % index)
			elif seen_segments.has(segment_id):
				errors.append("segments[%d].id must be unique" % index)
			seen_segments[segment_id] = true
			var beat_range = segments[index].get("beat_range", [])
			if not (beat_range is Array) or beat_range.size() != 2:
				errors.append("segments[%d].beat_range must contain two authored bounds" % index)
			if String(segments[index].get("normal_route", "")).is_empty():
				errors.append("segments[%d].normal_route is required" % index)
			if String(segments[index].get("hard_route", "")).is_empty():
				errors.append("segments[%d].hard_route is required" % index)
		for index in range(events.size()):
			var payload: Dictionary = events[index].get("payload", {})
			var event_segment_id := String(payload.get("segment", ""))
			if not seen_segments.has(event_segment_id):
				errors.append("events[%d] references unknown segment %s" % [index, event_segment_id])
			if int(payload.get("max_gap_after_frames", -1)) < 0:
				errors.append("events[%d].max_gap_after_frames must be non-negative" % index)
			if String(payload.get("action", "")).is_empty() or String(payload.get("warning", "")).is_empty():
				errors.append("events[%d] requires authored action and warning text" % index)
		if normal_route.is_empty() or hard_route.is_empty():
			errors.append("M1 stage requires Normal and Hard route contracts")
		if not bool(midboss.get("fought", false)):
			errors.append("M1 stage requires a fought midboss contract")
		if not bool(preboss_climax.get("boss_front", false)):
			errors.append("M1 stage requires a boss-front climax contract")
		for key in ["decision", "reward", "risk", "evidence"]:
			if String(score_route.get(key, "")).is_empty():
				errors.append("score_route.%s is required for an M1 stage" % key)
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func reset() -> void:
	cursor = 0

func is_m1_contract() -> bool:
	return stage_index > 0 or not segments.is_empty()

func beat_count() -> int:
	return events.size()

func segment_count() -> int:
	return segments.size()

func beats_for_segment(segment_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if String(event.get("payload", {}).get("segment", "")) == segment_id:
			result.append(event.duplicate(true))
	return result

func max_non_transition_gap() -> int:
	var maximum := 0
	for event in events:
		if String(event.get("kind", "")) == "transition":
			continue
		maximum = maxi(maximum, int(event.get("payload", {}).get("max_gap_after_frames", 0)))
	return maximum

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
	return {
		"version": VERSION,
		"stage_id": stage_id,
		"events": events.duplicate(true),
		"stage_index": stage_index,
		"display_name": display_name,
		"location": location,
		"midboss_id": midboss_id,
		"boss_id": boss_id,
		"approved_identity": approved_identity,
		"segments": segments.duplicate(true),
		"midboss": midboss.duplicate(true),
		"preboss_climax": preboss_climax.duplicate(true),
		"normal_route": normal_route,
		"hard_route": hard_route,
		"score_route": score_route.duplicate(true),
	}

func _clear_m1_metadata() -> void:
	stage_index = 0
	display_name = ""
	location = ""
	midboss_id = ""
	boss_id = ""
	approved_identity = ""
	segments.clear()
	midboss.clear()
	preboss_climax.clear()
	normal_route = ""
	hard_route = ""
	score_route.clear()
