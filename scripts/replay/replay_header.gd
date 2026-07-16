extends RefCounted

const FORMAT_VERSION := 2
const SUPPORTED_DIFFICULTIES := ["normal", "hard"]
const MODE_STORY := "story"
const MODE_STAGE_PRACTICE := "stage_practice"
const MODE_SPELL_PRACTICE := "spell_practice"
const SUPPORTED_MODES := [MODE_STORY, MODE_STAGE_PRACTICE, MODE_SPELL_PRACTICE]
const STAGE2_PHASE_IDS := [
	"stage_2_midboss_nonspell_1", "stage_2_midboss_spell_1",
	"stage_2_boss_nonspell_1", "stage_2_boss_spell_1", "stage_2_boss_spell_2", "stage_2_boss_spell_3",
]

var build_version: String = ""
var content_hash: String = ""
var seed: int = 1
var difficulty: String = "normal"
var protagonist: String = ""
var shot_type: String = ""
var mode: String = MODE_STORY
var starting_stage: int = 1
var phase_id: String = ""

func _init(values: Dictionary = {}) -> void:
	configure(values)

func configure(values: Dictionary) -> void:
	build_version = String(values.get("build_version", build_version))
	content_hash = String(values.get("content_hash", content_hash))
	seed = int(values.get("seed", seed))
	difficulty = String(values.get("difficulty", difficulty)).to_lower()
	protagonist = String(values.get("protagonist", protagonist))
	shot_type = String(values.get("shot_type", shot_type))
	mode = String(values.get("mode", mode)).to_lower()
	starting_stage = int(values.get("starting_stage", starting_stage))
	phase_id = String(values.get("phase_id", values.get("spell_id", phase_id)))

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
	if mode not in SUPPORTED_MODES:
		errors.append("mode must be story, stage_practice, or spell_practice")
	if starting_stage < 1 or starting_stage > 6:
		errors.append("starting_stage must be between 1 and 6")
	if mode == MODE_STORY and starting_stage != 1:
		errors.append("story replays must start at stage 1")
	if mode == MODE_SPELL_PRACTICE and phase_id.is_empty():
		errors.append("spell_practice requires phase_id")
	if mode == MODE_SPELL_PRACTICE and starting_stage == 2 and phase_id not in STAGE2_PHASE_IDS:
		errors.append("Stage 2 spell_practice requires an approved phase_id")
	if mode != MODE_SPELL_PRACTICE and not phase_id.is_empty():
		errors.append("phase_id is only valid for spell_practice")
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
		"mode": mode,
		"starting_stage": starting_stage,
		"phase_id": phase_id,
	}

static func from_dict(data: Dictionary) -> RefCounted:
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		return null
	return new(data)
