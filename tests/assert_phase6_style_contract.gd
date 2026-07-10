extends SceneTree

var failed := false
var required_style_sections := [
	"## Project Identity",
	"## Style Pillars",
	"## Original-IP Rules",
	"## Gameplay Readability Contract",
	"## Shape Language",
	"## Color Language",
	"## Bullet And Bomb Readability",
	"## Character Rendering Standard",
	"## Enemy And Boss Rendering Standard",
	"## Background Rendering Standard",
	"## UI Rendering Standard",
	"## Stage Palettes",
	"## Prompt Negative Constraints",
	"## Acceptance Checklist",
]
var required_prompt_fields := [
	"Target:",
	"Gameplay role:",
	"Positive prompt:",
	"Negative prompt:",
	"Readability constraints:",
	"Review composite:",
]
var sentinel_prompt_blocks := [
	"## stage_01_background_far",
	"## protagonist_mika_gameplay_sprite",
	"## boss_06b_spell_aura",
]

func _init() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/art/style_bible.md")
	var prompts := FileAccess.get_file_as_string("res://docs/art/phase6_asset_prompts.md")

	if not _assert_forbidden_absent(bible, "Festival Master Spark", "style bible"):
		return
	if not _assert_forbidden_absent(bible, "festival_master_spark", "style bible"):
		return
	if not _assert_forbidden_absent(prompts, "Festival Master Spark", "prompt matrix"):
		return
	if not _assert_forbidden_absent(prompts, "festival_master_spark", "prompt matrix"):
		return

	if not _assert_exact_style_sections(bible):
		return
	if not _assert_contains(bible, "Dense-play readability is mandatory", "style bible"):
		return
	if not _assert_contains(bible, "no copyrighted Touhou character", "style bible"):
		return
	if not _assert_contains(bible, "no bullet-like background dots", "style bible"):
		return

	for heading in sentinel_prompt_blocks:
		if not _assert_prompt_block_schema(prompts, heading):
			return
	quit(0)

func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

func _assert_contains(content: String, expected: String, label: String) -> bool:
	if not content.contains(expected):
		_fail("%s missing required text: %s" % [label, expected])
		return false
	return true

func _assert_forbidden_absent(content: String, forbidden: String, label: String) -> bool:
	if content.contains(forbidden):
		_fail("%s contains forbidden text: %s" % [label, forbidden])
		return false
	return true

func _assert_exact_style_sections(content: String) -> bool:
	var actual_sections := []
	for line in content.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("## "):
			actual_sections.append(stripped)

	if actual_sections.size() != required_style_sections.size():
		_fail("style bible section count mismatch: expected %d, got %d" % [required_style_sections.size(), actual_sections.size()])
		return false

	for i in range(required_style_sections.size()):
		if actual_sections[i] != required_style_sections[i]:
			_fail("style bible section mismatch at index %d: expected %s, got %s" % [i, required_style_sections[i], actual_sections[i]])
			return false
	return true

func _assert_prompt_block_schema(content: String, heading: String) -> bool:
	var block := _extract_prompt_block(content, heading)
	if block.is_empty():
		_fail("prompt matrix missing sentinel block: %s" % heading)
		return false

	var field_positions := []
	for field in required_prompt_fields:
		var index := block.find(field)
		if index == -1:
			_fail("%s missing prompt field: %s" % [heading, field])
			return false
		field_positions.append(index)

	for i in range(1, field_positions.size()):
		if field_positions[i] <= field_positions[i - 1]:
			_fail("%s prompt fields are out of schema order" % heading)
			return false
	return true

func _extract_prompt_block(content: String, heading: String) -> String:
	var start := content.find(heading)
	if start == -1:
		return ""
	var next := content.find("\n## ", start + heading.length())
	if next == -1:
		return content.substr(start)
	return content.substr(start, next - start)
