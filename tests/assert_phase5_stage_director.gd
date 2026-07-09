extends SceneTree

var failed := false

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _assert_equal(actual, expected, message: String) -> bool:
	if actual != expected:
		_fail("%s Expected %s, got %s" % [message, expected, actual])
		return false
	return true

func _assert_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _assert_spawn_event(event: Dictionary, context: String) -> void:
	_assert_keys(event, ["time", "x", "y", "hp", "pattern", "move", "vx", "vy", "stage_index"], context)
	_assert(float(event.hp) > 0.0, "%s hp should be positive." % context)
	_assert(String(event.pattern) != "", "%s pattern should not be empty." % context)

func _init() -> void:
	var director_script = load("res://scripts/runtime/stage_director.gd")
	if not _assert(director_script != null, "Could not load stage_director.gd"):
		return
	var director = director_script.new()
	for method in ["stage_controller", "due_wave_events", "boss_cards", "boss_definition", "midboss_definition", "pattern_aliases"]:
		if not _assert(director.has_method(method), "StageDirector missing method %s" % method):
			return

	_assert_equal(director.stage_controller(0), {}, "Invalid stage 0 should return empty controller.")
	_assert_equal(director.due_wave_events(0, 0, {}), [], "Invalid stage should not emit wave events.")

	for stage_index in range(1, 7):
		var controller: Dictionary = director.stage_controller(stage_index)
		_assert_keys(controller, ["stage_index", "stage_id", "display_name", "curve_tag", "theme", "boss_time", "waves", "midboss", "boss"], "stage %d controller" % stage_index)
		_assert_equal(int(controller.stage_index), stage_index, "Controller stage_index mismatch.")
		_assert(not controller.has("fallback_from"), "Stage %d controller should not expose fallback_from." % stage_index)
		var waves: Array = controller.waves
		_assert(waves.size() >= 10, "Stage %d should expose authored waves." % stage_index)
		var first_time := int(waves[0].time)
		var triggered := {}
		var first_events: Array = director.due_wave_events(stage_index, first_time, triggered)
		_assert(first_events.size() > 0, "Stage %d first wave time should emit events." % stage_index)
		for event in first_events:
			_assert_spawn_event(event, "stage %d emitted event" % stage_index)
			_assert_equal(int(event.stage_index), stage_index, "Emitted stage index mismatch.")
		var duplicate_events: Array = director.due_wave_events(stage_index, first_time, triggered)
		_assert_equal(duplicate_events.size(), 0, "Stage %d wave events should emit only once per triggered table." % stage_index)
		var fresh_events: Array = director.due_wave_events(stage_index, first_time, {})
		_assert_equal(fresh_events.size(), first_events.size(), "Stage %d fresh triggered table should emit the same event count." % stage_index)

		controller.waves[0].pattern = "mutated"
		var fresh_controller: Dictionary = director.stage_controller(stage_index)
		_assert(String(fresh_controller.waves[0].pattern) != "mutated", "Stage %d controller data should be duplicated." % stage_index)

		var cards: Array = director.boss_cards(stage_index)
		var expected_count := 4 if stage_index <= 4 else 6
		_assert_equal(cards.size(), expected_count, "Stage %d boss card count mismatch." % stage_index)

	var expanded_stage: Dictionary = director.stage_controller(1)
	var expanded_events: Array = director.due_wave_events(1, int(expanded_stage.waves[0].time), {})
	_assert(expanded_events.size() >= 2, "Stage 1 first compact wave should expand to multiple spawn events.")

	quit(0)
