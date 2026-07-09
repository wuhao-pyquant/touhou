extends SceneTree

var failed := false

func _init() -> void:
	var bible := FileAccess.get_file_as_string("res://docs/art/style_bible.md")
	if not _assert_contains(bible, "## Gameplay Readability Contract", "style bible"):
		return
	if not _assert_contains(bible, "Art serves gameplay", "style bible"):
		return
	if not _assert_contains(bible, "Dense-play readability is mandatory", "style bible"):
		return
	if not _assert_contains(bible, "no copyrighted Touhou character", "style bible"):
		return
	if not _assert_contains(bible, "no bullet-like background dots", "style bible"):
		return

	var prompts := FileAccess.get_file_as_string("res://docs/art/phase6_asset_prompts.md")
	if not _assert_contains(prompts, "## stage_01_background_far", "prompt matrix"):
		return
	if not _assert_contains(prompts, "## protagonist_mika_gameplay_sprite", "prompt matrix"):
		return
	if not _assert_contains(prompts, "## boss_06b_spell_aura", "prompt matrix"):
		return
	if not _assert_contains(prompts, "Readability constraints", "prompt matrix"):
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
