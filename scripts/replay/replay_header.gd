extends RefCounted

const FORMAT_VERSION := 1
const SUPPORTED_DIFFICULTIES := ["normal", "hard"]

var build_version: String = ""
var content_hash: String = ""
var seed: int = 1
var difficulty: String = "normal"
var protagonist: String = ""
var shot_type: String = ""

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	build_version = String(values.get("build_version", build_version))
	content_hash = String(values.get("content_hash", content_hash))
	seed = int(values.get("seed", seed))
	difficulty = String(values.get("difficulty", difficulty)).to_lower()
	protagonist = String(values.get("protagonist", protagonist))
	shot_type = String(values.get("shot_type", shot_type))

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if build_version.is_empty():
		errors.append("build_version is required")
	if content_hash.is_empty():
		errors.append("content_hash is required")
	if difficulty not in SUPPORTED_DIFFICULTIES:
		errors.append("difficulty must be normal or hard")
	if protagonist.is_empty():
		errors.append("protagonist is required")
	if shot_type.is_empty():
		errors.append("shot_type is required")
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"build_version": build_version,
		"content_hash": content_hash,
		"seed": seed,
		"difficulty": difficulty,
		"protagonist": protagonist,
		"shot_type": shot_type,
	}

static func from_dict(data: Dictionary) -> RefCounted:
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		return null
	return new(data)
