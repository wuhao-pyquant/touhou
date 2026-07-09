extends SceneTree

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest/phase6_asset_manifest.json"))
	assert(typeof(parsed) == TYPE_DICTIONARY)
	for asset in parsed["assets"]:
		if asset["status"] != "accepted":
			continue
		var final_path := str(asset["final_path"])
		assert(FileAccess.file_exists(final_path))
		var image := Image.new()
		var err := image.load(final_path)
		assert(err == OK)
		assert(image.get_width() == int(asset["width"]))
		assert(image.get_height() == int(asset["height"]))
		if bool(asset["transparent"]):
			assert(image.detect_alpha() != Image.ALPHA_NONE)
	quit(0)
