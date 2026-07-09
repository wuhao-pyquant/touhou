extends SceneTree

func _init() -> void:
	var manifest_text := FileAccess.get_file_as_string("res://assets/manifest/phase6_asset_manifest.json")
	assert(manifest_text.length() > 0)
	var parsed: Variant = JSON.parse_string(manifest_text)
	assert(typeof(parsed) == TYPE_DICTIONARY)
	assert(parsed.has("version"))
	assert(parsed.has("assets"))
	assert(parsed["assets"].size() >= 98)

	var accepted_statuses := {"pending_generation": true, "generated_needs_review": true, "accepted": true, "rejected": true}
	var ids := {}
	for asset in parsed["assets"]:
		assert(asset.has("id"))
		assert(not ids.has(asset["id"]))
		ids[asset["id"]] = true
		assert(asset.has("final_path"))
		assert(asset["final_path"].begins_with("res://assets/"))
		assert(asset.has("width") and asset["width"] > 0)
		assert(asset.has("height") and asset["height"] > 0)
		assert(asset.has("status") and accepted_statuses.has(asset["status"]))
		assert(asset.has("readability_role") and str(asset["readability_role"]).length() >= 24)
		assert(asset.has("prompt_id") and str(asset["prompt_id"]).length() > 0)

	assert(ids.has("stage_01_background_far"))
	assert(ids.has("stage_06_background_spell"))
	assert(ids.has("protagonist_mika_gameplay_sprite"))
	assert(ids.has("boss_06b_spell_aura"))
	assert(ids.has("enemy_bullet_lotus_core"))
	assert(ids.has("item_power_large"))
	quit(0)
