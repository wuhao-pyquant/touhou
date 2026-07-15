extends RefCounted
class_name StageDirector

var _content: Object = null
var _m1_contract_catalog: Object = null

func _content_db() -> Object:
	if _content == null:
		var content_script = load("res://scripts/data/stage_content_database.gd")
		_content = content_script.new()
	return _content

func stage_controller(stage_index: int) -> Dictionary:
	var content := _content_db()
	var config: Dictionary = content.stage_config(stage_index)
	if config.is_empty():
		return {}
	return {
		"stage_index": int(config.index),
		"stage_id": String(config.stage_id),
		"display_name": String(config.display_name),
		"curve_tag": String(config.curve_tag),
		"theme": String(config.theme),
		"boss_time": int(config.boss_time),
		"waves": content.wave_schedule(stage_index),
		"midboss": content.midboss_definition(stage_index),
		"boss": content.boss_definition(stage_index),
	}

func due_wave_events(stage_index: int, timer: int, triggered: Dictionary) -> Array:
	var schedule: Array = _content_db().wave_schedule(stage_index)
	if schedule.is_empty():
		return []
	var result: Array = []
	for i in range(schedule.size()):
		var event: Dictionary = schedule[i]
		var event_time: int = int(event.get("time", -1))
		var event_key: String = _event_key(stage_index, i, event_time)
		if event_time <= timer and event_time >= 0 and not triggered.has(event_key):
			triggered[event_key] = true
			result.append_array(_expand_event(stage_index, event_key, event))
	return result

func boss_cards(stage_index: int) -> Array:
	return _content_db().boss_cards(stage_index)

func boss_definition(stage_index: int) -> Dictionary:
	return _content_db().boss_definition(stage_index)

func midboss_definition(stage_index: int) -> Dictionary:
	return _content_db().midboss_definition(stage_index)

func pattern_aliases() -> Dictionary:
	return _content_db().pattern_aliases()

# Additive M1 contract queries. Current stage_controller(), wave schedules,
# aliases, and playable boss definitions intentionally remain on the legacy
# content database until their later implementation milestones.
func m1_content_catalog() -> Object:
	if _m1_contract_catalog == null:
		var catalog_script = load("res://scripts/content/m1_content_catalog.gd")
		_m1_contract_catalog = catalog_script.new()
	return _m1_contract_catalog

func m1_stage_timeline(stage_index: int):
	return m1_content_catalog().stage_timeline(stage_index)

func m1_stage_segments(stage_index: int) -> Array:
	var timeline = m1_stage_timeline(stage_index)
	return [] if timeline == null else timeline.segments.duplicate(true)

func m1_stage_beats(stage_index: int) -> Array:
	var timeline = m1_stage_timeline(stage_index)
	return [] if timeline == null else timeline.events.duplicate(true)

func m1_phase_definitions(stage_index: int, encounter_role: String = "") -> Array:
	return m1_content_catalog().phase_definitions_for_stage(stage_index, encounter_role)

func m1_phase_definition(phase_id: String):
	return m1_content_catalog().phase_definition(phase_id)

func m1_phase_local_seed(run_seed: int, phase_id: String) -> int:
	return m1_content_catalog().phase_local_seed(run_seed, phase_id)

func _event_key(stage_index: int, event_index: int, event_time: int) -> String:
	return "%d:%d:%d" % [stage_index, event_index, event_time]

func _expand_event(stage_index: int, event_key: String, event: Dictionary) -> Array:
	var repeat: int = maxi(1, int(event.get("repeat", 1)))
	var spacing_x: float = float(event.get("spacing_x", 0.0))
	var spacing_y: float = float(event.get("spacing_y", 0.0))
	var variants: Array = event.get("variants", [])
	var result: Array = []
	for i in range(repeat):
		var spawn: Dictionary = event.duplicate(true)
		spawn.erase("repeat")
		spawn.erase("spacing_x")
		spawn.erase("spacing_y")
		spawn.erase("variants")
		spawn["stage_index"] = stage_index
		spawn["event_id"] = "%s:%d" % [event_key, i]
		spawn["x"] = float(event.get("x", 0.0)) + spacing_x * float(i)
		spawn["y"] = float(event.get("y", 0.0)) + spacing_y * float(i)
		if not spawn.has("move_data"):
			spawn["move_data"] = {}
		if not spawn.has("strong"):
			spawn["strong"] = false
		if i < variants.size():
			var variant: Dictionary = variants[i]
			for key in variant.keys():
				spawn[key] = variant[key]
		result.append(spawn)
	return result
