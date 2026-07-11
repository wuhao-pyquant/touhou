extends RefCounted
class_name EnemyPatternExecutor

var _database = load("res://scripts/data/game_database.gd").new()
var _scoring_rules: Dictionary = _database.scoring_rules()

func family_id_for_pattern(pattern: String, strong: bool = false) -> String:
	if strong:
		return "elite_yokai"
	match pattern:
		"downward":
			return "fast_attacker"
		"wind", "wind_aimed":
			return "fast_attacker"
		"spread", "ring":
			return "formation_shooter"
		"mist_delay":
			return "formation_shooter"
		"double_spread":
			return "elite_yokai"
		"wave":
			return "mechanism"
		"rhythm":
			return "mechanism"
		"large_orb", "final_dense":
			return "elite_yokai"
		"spiral":
			return "elite_yokai"
		_:
			return "low_yokai"

func spawn_config(pattern: String, base_hp: float, stage_hp_mult: float, strong: bool = false) -> Dictionary:
	var family_id := family_id_for_pattern(pattern, strong)
	var family: Dictionary = _database.enemy_family_by_id(family_id)
	if family.is_empty():
		family = _database.enemy_family_by_id("low_yokai")
	var hp := base_hp * 1.5 * maxf(0.1, stage_hp_mult)
	var shoot_interval := maxf(24.0, float(family.get("shoot_interval", 60.0)) * (0.8 if strong else 1.0))
	return {
		"family_id": family_id,
		"hp": hp,
		"radius": float(family.get("radius", 14.0)),
		"drop_tier": String(family.get("drop_tier", "standard")),
		"shoot_interval": shoot_interval,
	}

func bullet_specs(enemy: Dictionary, player_position: Vector2, stage_bullet_speed: float) -> Array:
	var pattern := String(enemy.get("pattern", "aimed"))
	var position := Vector2(float(enemy.get("x", 0.0)), float(enemy.get("y", 0.0)))
	var shoot_phase := int(enemy.get("shoot_phase", 0))
	match pattern:
		"aimed":
			var aimed_angle := (player_position - position).angle()
			return [_make_spec(position, _velocity_for("circle", aimed_angle, 2.5, stage_bullet_speed), "circle")]
		"spread":
			var spread_specs: Array = []
			var spread_angle := (player_position - position).angle()
			for off in [-0.3, 0.0, 0.3]:
				spread_specs.append(_make_spec(position, _velocity_for("circle", spread_angle + off, 2.5, stage_bullet_speed), "circle"))
			return spread_specs
		"ring":
			var ring_specs: Array = []
			for i in range(12):
				var ring_angle := TAU / 12.0 * i + shoot_phase * 0.3
				ring_specs.append(_make_spec(position, _velocity_for("star", ring_angle, 2.0, stage_bullet_speed), "star"))
			return ring_specs
		"double_spread":
			var double_specs: Array = []
			var double_angle := (player_position - position).angle()
			for off in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				double_specs.append(_make_spec(position, _velocity_for("talisman", double_angle + off, 2.2, stage_bullet_speed), "talisman"))
			return double_specs
		"downward":
			var downward_velocity := Vector2(0.0, 3.5 * stage_bullet_speed * _speed_multiplier_for("needle"))
			return [_make_spec(position, downward_velocity, "needle")]
		"wave":
			var wave_specs: Array = []
			for i in range(5):
				var wave_angle := PI / 2.0 + sin(shoot_phase * 0.15 + i * 0.6) * 0.8
				var wave_position := position + Vector2(i * 10.0 - 20.0, 0.0)
				wave_specs.append(_make_spec(wave_position, _velocity_for("rice", wave_angle, 2.0, stage_bullet_speed), "rice"))
			return wave_specs
		"mist_delay":
			var mist_specs: Array = []
			for i in range(6):
				var mist_angle := PI / 2.0 + sin(shoot_phase * 0.1 + i * 0.9) * 0.65
				var mist_velocity := _velocity_for("spiral_seed", mist_angle, 1.65, stage_bullet_speed)
				mist_specs.append(_make_spec(position + Vector2((i - 2.5) * 9.0, 0.0), mist_velocity, "spiral_seed", {
					"kind": "delayed_aim", "trigger_age": 30.0 + i * 5.0, "target_speed": mist_velocity.length(), "aim_on_trigger": true,
				}))
			return mist_specs
		"wind":
			var wind_specs: Array = []
			for i in range(4):
				var wind_angle := PI / 2.0 + sin(shoot_phase * 0.22 + i) * 0.45
				wind_specs.append(_make_spec(position + Vector2((i - 1.5) * 12.0, 0.0), _velocity_for("storm_arc", wind_angle, 2.55, stage_bullet_speed), "storm_arc", {
					"kind": "curve", "turn_rate": (-0.006 if i < 2 else 0.006),
				}))
			return wind_specs
		"wind_aimed":
			var wind_aim := (player_position - position).angle()
			var wind_aimed_specs: Array = []
			for off in [-0.24, -0.08, 0.08, 0.24]:
				wind_aimed_specs.append(_make_spec(position, _velocity_for("needle", wind_aim + off, 3.0, stage_bullet_speed), "needle"))
			return wind_aimed_specs
		"rhythm":
			var rhythm_specs: Array = []
			var rhythm_count := 8 if shoot_phase % 2 == 0 else 12
			for i in range(rhythm_count):
				var rhythm_angle := TAU / float(rhythm_count) * i + shoot_phase * 0.18
				var rhythm_family := "star" if shoot_phase % 2 == 0 else "rice"
				var rhythm_velocity := _velocity_for(rhythm_family, rhythm_angle, 2.05, stage_bullet_speed)
				rhythm_specs.append(_make_spec(position, rhythm_velocity, rhythm_family, {
					"kind": "brake_restart", "brake": 0.045, "trigger_age": 32.0, "target_speed": rhythm_velocity.length() * 0.9,
				}))
			return rhythm_specs
		"large_orb":
			var orb_specs: Array = []
			var orb_angle := (player_position - position).angle()
			for off in [-0.38, 0.0, 0.38]:
				var orb_velocity := _velocity_for("large_orb", orb_angle + off, 1.9, stage_bullet_speed)
				orb_specs.append(_make_spec(position, orb_velocity, "large_orb", {
					"kind": "brake_restart", "brake": 0.025, "trigger_age": 52.0, "target_speed": orb_velocity.length() * 1.15, "aim_on_trigger": off == 0.0,
				}))
			return orb_specs
		"final_dense":
			var final_specs: Array = []
			for i in range(10):
				var final_angle := TAU / 10.0 * i + shoot_phase * 0.17
				var final_family := "talisman" if i % 2 == 0 else "star"
				var final_velocity := _velocity_for(final_family, final_angle, 2.2, stage_bullet_speed)
				final_specs.append(_make_spec(position, final_velocity, final_family, {
					"kind": "curve" if i % 2 == 0 else "accelerate",
					"turn_rate": 0.004 if i % 4 < 2 else -0.004,
					"accel": 0.008, "max_speed": final_velocity.length() * 1.45,
				}))
			if shoot_phase % 3 == 0:
				var aimed_angle := (player_position - position).angle()
				for off in [-0.18, 0.0, 0.18]:
					final_specs.append(_make_spec(position, _velocity_for("needle", aimed_angle + off, 3.0, stage_bullet_speed), "needle"))
			return final_specs
		"spiral":
			var spiral_specs: Array = []
			for i in range(8):
				var spiral_angle := shoot_phase * 0.12 + TAU / 8.0 * i
				spiral_specs.append(_make_spec(position, _velocity_for("clock_gear", spiral_angle, 2.2, stage_bullet_speed), "clock_gear", {
					"kind": "curve", "turn_rate": 0.009 if i % 2 == 0 else -0.009,
				}))
			return spiral_specs
		_:
			var fallback_angle := (player_position - position).angle()
			return [_make_spec(position, _velocity_for("circle", fallback_angle, 2.5, stage_bullet_speed), "circle")]

func _make_spec(position: Vector2, velocity: Vector2, family_id: String, motion: Dictionary = {}) -> Dictionary:
	var family: Dictionary = _database.bullet_family_by_id(family_id)
	return {
		"position": position,
		"velocity": velocity,
		"radius": float(family.get("radius", 5.0)),
		"color": family.get("color", Color.RED),
		"family_id": family_id,
		"lifetime": 350.0,
		"motion": motion.duplicate(true),
	}

func _velocity_for(family_id: String, angle: float, base_speed: float, stage_bullet_speed: float) -> Vector2:
	var speed := base_speed * stage_bullet_speed * _speed_multiplier_for(family_id)
	return Vector2(cos(angle), sin(angle)) * speed

func _speed_multiplier_for(family_id: String) -> float:
	var family: Dictionary = _database.bullet_family_by_id(family_id)
	return float(family.get("speed_multiplier", 1.0))
