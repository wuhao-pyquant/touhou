extends SceneTree

var failed := false

const EXPECTED_STAGE_IDS := [
	"shrine_approach",
	"yokai_market",
	"mist_bamboo_grove",
	"tengu_mountain_path",
	"oni_banquet_hall",
	"night_festival_divine_realm",
]

const EXPECTED_CURVE_TAGS := [
	"basic_collection",
	"horizontal_objects",
	"mist_memory",
	"wind_aimed_pressure",
	"rhythm_orb_resource",
	"final_readable_density",
]

const DIRECT_BOSS_PATTERNS := [
	"moonlight",
	"starfall",
	"butterfly",
	"divine",
	"ripple",
	"bubble",
	"mist",
	"mirror",
	"scarlet",
	"midnight",
	"vortex",
	"darkness",
	"apocalypse",
	"wind_aimed",
	"wind_lattice",
	"rhythm_drum",
	"large_orb_gate",
	"final_lantern",
]

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

func _is_cjk_char(ch: String) -> bool:
	var codepoint := ord(ch)
	return (codepoint >= 0x3400 and codepoint <= 0x4DBF) or (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or (codepoint >= 0xF900 and codepoint <= 0xFAFF)

func _assert_chinese_first(value: String, context: String) -> void:
	_assert(value.length() > 0, "%s should not be empty." % context)
	if value.length() > 0:
		_assert(_is_cjk_char(value[0]), "%s should be Chinese-first, got %s" % [context, value])

func _assert_keys(value: Dictionary, keys: Array, context: String) -> void:
	for key in keys:
		_assert(value.has(key), "%s missing %s: %s" % [context, key, value])

func _recognized_pattern(pattern_id: String, aliases: Dictionary) -> bool:
	return aliases.has(pattern_id) or DIRECT_BOSS_PATTERNS.has(pattern_id)

func _count_kind(cards: Array, kind: String) -> int:
	var result := 0
	for card in cards:
		if String(card.get("kind", "")) == kind:
			result += 1
	return result

func _assert_card(card: Dictionary, aliases: Dictionary, context: String) -> void:
	_assert_keys(card, ["name", "hp", "time", "pattern", "kind"], context)
	_assert_chinese_first(String(card.get("name", "")), "%s card name" % context)
	_assert(float(card.get("hp", 0.0)) > 0.0, "%s hp should be positive." % context)
	_assert(float(card.get("time", 0.0)) > 0.0, "%s time should be positive." % context)
	_assert(["nonspell", "spell"].has(String(card.get("kind", ""))), "%s kind should be nonspell or spell." % context)
	_assert(_recognized_pattern(String(card.get("pattern", "")), aliases), "%s pattern is not recognized: %s" % [context, card])

func _assert_boss_counts(stage_index: int, cards: Array) -> void:
	var expected_nonspells := 1 if stage_index <= 4 else 2
	var expected_spells := 3 if stage_index <= 4 else 4
	_assert_equal(_count_kind(cards, "nonspell"), expected_nonspells, "Stage %d nonspell count mismatch." % stage_index)
	_assert_equal(_count_kind(cards, "spell"), expected_spells, "Stage %d spell count mismatch." % stage_index)
	_assert_equal(cards.size(), expected_nonspells + expected_spells, "Stage %d total boss card count mismatch." % stage_index)

func _assert_wave_event(event: Dictionary, context: String) -> void:
	_assert_keys(event, ["time", "x", "y", "hp", "pattern", "move", "vx", "vy"], context)
	_assert(int(event.get("time", -1)) >= 0, "%s time should be non-negative." % context)
	_assert(float(event.get("hp", 0.0)) > 0.0, "%s hp should be positive." % context)
	_assert(String(event.get("pattern", "")) != "", "%s pattern should not be empty." % context)
	if event.has("repeat"):
		_assert(int(event.repeat) > 0, "%s repeat should be positive." % context)

func _patterns_for(schedule: Array) -> Array:
	var result: Array = []
	for event in schedule:
		var pattern := String(event.get("pattern", ""))
		if pattern != "" and not result.has(pattern):
			result.append(pattern)
	return result

func _init() -> void:
	var db_script = load("res://scripts/data/stage_content_database.gd")
	if not _assert(db_script != null, "Could not load stage_content_database.gd"):
		return
	var db = db_script.new()
	for method in ["stage_count", "stage_config", "wave_schedule", "midboss_definition", "boss_definition", "boss_cards", "pattern_aliases"]:
		if not _assert(db.has_method(method), "StageContentDatabase missing method %s" % method):
			return

	_assert_equal(db.stage_count(), 6, "Stage content should define six stages.")
	var aliases: Dictionary = db.pattern_aliases()
	_assert(aliases.size() >= 6, "Boss pattern aliases should cover new Phase 5 pattern ids.")

	for stage_index in range(1, 7):
		var config: Dictionary = db.stage_config(stage_index)
		_assert_keys(config, ["index", "stage_id", "display_name", "curve_tag", "theme", "boss_time"], "stage %d config" % stage_index)
		_assert_equal(int(config.index), stage_index, "Stage index mismatch.")
		_assert_equal(String(config.stage_id), EXPECTED_STAGE_IDS[stage_index - 1], "Stage id mismatch.")
		_assert_equal(String(config.curve_tag), EXPECTED_CURVE_TAGS[stage_index - 1], "Stage curve tag mismatch.")
		_assert_chinese_first(String(config.display_name), "stage %d display name" % stage_index)
		_assert(int(config.boss_time) >= 4200, "Stage %d boss_time should leave room for a real stage route." % stage_index)

		var schedule: Array = db.wave_schedule(stage_index)
		_assert(schedule.size() >= 10, "Stage %d should have at least ten authored wave events." % stage_index)
		for i in range(schedule.size()):
			_assert_wave_event(schedule[i], "stage %d wave %d" % [stage_index, i])

		var midboss: Dictionary = db.midboss_definition(stage_index)
		_assert_keys(midboss, ["id", "display_name", "cards"], "stage %d midboss" % stage_index)
		_assert_chinese_first(String(midboss.display_name), "stage %d midboss display name" % stage_index)
		var mid_cards: Array = midboss.cards
		_assert_equal(mid_cards.size(), 2, "Stage %d midboss should have one nonspell and one short spell." % stage_index)
		_assert_equal(_count_kind(mid_cards, "nonspell"), 1, "Stage %d midboss nonspell count mismatch." % stage_index)
		_assert_equal(_count_kind(mid_cards, "spell"), 1, "Stage %d midboss spell count mismatch." % stage_index)
		for card in mid_cards:
			_assert_card(card, aliases, "stage %d midboss" % stage_index)

		var boss: Dictionary = db.boss_definition(stage_index)
		_assert_keys(boss, ["id", "display_name", "cards"], "stage %d boss" % stage_index)
		_assert_chinese_first(String(boss.display_name), "stage %d boss display name" % stage_index)
		var boss_cards: Array = db.boss_cards(stage_index)
		_assert_boss_counts(stage_index, boss_cards)
		for card in boss_cards:
			_assert_card(card, aliases, "stage %d boss" % stage_index)

		var patterns := _patterns_for(schedule)
		match stage_index:
			4:
				_assert(patterns.has("wind") or patterns.has("wind_aimed"), "Stage 4 should include wind pressure patterns.")
			5:
				_assert(patterns.has("rhythm"), "Stage 5 should include rhythm bullet pressure.")
				_assert(patterns.has("large_orb"), "Stage 5 should include large-orb control.")
			6:
				_assert(patterns.has("final_dense"), "Stage 6 should include final readable dense patterns.")

	_assert_equal(db.stage_config(0), {}, "Invalid stage 0 should return empty config.")
	_assert_equal(db.boss_cards(7), [], "Invalid stage 7 should return empty boss cards.")
	quit(0)
