extends RefCounted

const VERSION := 1
const SUPPORTED_IDS := ["normal", "hard"]
const DEFAULTS := {
	"normal": {
		"bullet_speed_scale": 1.0,
		"emission_count_scale": 1.0,
		"topology_variant": "baseline",
		"topology_overrides": {
			"routing": "authored",
			"additional_emitter_lanes": [],
		},
	},
	"hard": {
		"bullet_speed_scale": 1.12,
		"emission_count_scale": 1.15,
		"topology_variant": "crossfire",
		"topology_overrides": {
			"routing": "crossfire",
			"additional_emitter_lanes": ["mirrored_flank"],
		},
	},
}

var id: String = "normal"
var bullet_speed_scale: float = 1.0
var emission_count_scale: float = 1.0
var topology_variant: String = "baseline"
var topology_overrides: Dictionary = {}
var normal_structure: Dictionary = {}
var authored_hard_transformation: Dictionary = {}

func _init(profile_id: String = "normal", overrides: Dictionary = {}) -> void:
	configure(profile_id, overrides)

func configure(profile_id: String, overrides: Dictionary = {}) -> void:
	id = profile_id.to_lower()
	var defaults: Dictionary = DEFAULTS.get(id, {}).duplicate(true)
	bullet_speed_scale = float(overrides.get("bullet_speed_scale", defaults.get("bullet_speed_scale", 1.0)))
	emission_count_scale = float(overrides.get("emission_count_scale", defaults.get("emission_count_scale", 1.0)))
	topology_variant = String(overrides.get("topology_variant", defaults.get("topology_variant", "")))
	topology_overrides = defaults.get("topology_overrides", {}).duplicate(true)
	var authored_topology = overrides.get("topology_overrides", {})
	if authored_topology is Dictionary:
		for key in authored_topology:
			topology_overrides[key] = authored_topology[key]
	normal_structure = _dictionary_copy(overrides.get("normal_structure", {}))
	authored_hard_transformation = _dictionary_copy(overrides.get("hard_topology_change", {}))

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id not in SUPPORTED_IDS:
		errors.append("difficulty must be normal or hard")
	if bullet_speed_scale <= 0.0:
		errors.append("bullet_speed_scale must be positive")
	if emission_count_scale <= 0.0:
		errors.append("emission_count_scale must be positive")
	if topology_variant.is_empty():
		errors.append("topology_variant is required")
	if id == "hard" and not has_topology_change():
		errors.append("hard must define a topology change")
	return errors

func is_valid() -> bool:
	return validation_errors().is_empty()

func has_topology_change() -> bool:
	if id != "hard":
		return false
	if not authored_hard_transformation.is_empty():
		return (
			not String(authored_hard_transformation.get("type", "")).is_empty()
			and not String(authored_hard_transformation.get("graph_change", "")).is_empty()
		)
	var normal: Dictionary = DEFAULTS.normal
	return topology_variant != String(normal.topology_variant) or topology_overrides != normal.topology_overrides

func configure_for_phase(profile_id: String, source_normal: Dictionary, source_hard: Dictionary) -> void:
	configure(profile_id, {
		"normal_structure": source_normal,
		"hard_topology_change": source_hard,
		"topology_variant": String(source_hard.get("type", "authored")) if profile_id.to_lower() == "hard" else "baseline",
		"topology_overrides": {
			"graph_change": String(source_hard.get("graph_change", "")) if profile_id.to_lower() == "hard" else "authored",
		},
	})

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"id": id,
		"bullet_speed_scale": bullet_speed_scale,
		"emission_count_scale": emission_count_scale,
		"topology_variant": topology_variant,
		"topology_overrides": topology_overrides.duplicate(true),
		"normal_structure": normal_structure.duplicate(true),
		"authored_hard_transformation": authored_hard_transformation.duplicate(true),
	}

func _dictionary_copy(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
