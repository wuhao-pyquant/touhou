extends RefCounted
class_name PlayerShotExecutor

func bullet_type_for_shot(shot_profile: Dictionary, game_manager_ref: Object) -> int:
	var bullet_type_name := String(shot_profile.get("bullet_type", "spread"))
	match bullet_type_name:
		"linear":
			return game_manager_ref.BulletType.LINEAR
		"homing":
			return game_manager_ref.BulletType.HOMING
		_:
			return game_manager_ref.BulletType.SPREAD

func fire_pattern(shot_profile: Dictionary, power_level: int, focused: bool, origin: Vector2) -> Array:
	var pattern_id := String(shot_profile.get("pattern_id", ""))
	var level := clampi(power_level, 0, 5)
	match pattern_id:
		"miko_tracking_ofuda":
			return _miko_tracking_ofuda(shot_profile, level, focused, origin)
		"miko_yinyang_focus":
			return _miko_yinyang_focus(shot_profile, level, focused, origin)
		"magician_stardust_spread":
			return _magician_stardust_spread(shot_profile, level, focused, origin)
		"magician_magic_laser":
			return _magician_magic_laser(shot_profile, level, focused, origin)
		"swordswoman_wave_fan":
			return _swordswoman_wave_fan(shot_profile, level, focused, origin)
		"swordswoman_returning_blades":
			return _swordswoman_returning_blades(shot_profile, level, focused, origin)
		_:
			return _magician_stardust_spread(shot_profile, level, focused, origin)

func fire_pattern_legacy(shot_profile: Dictionary, power_level: int, focused: bool, origin: Vector2) -> Array:
	var pattern_id := String(shot_profile.get("pattern_id", ""))
	var level := clampi(power_level, 0, 5)
	var legacy_profile := shot_profile.duplicate(true)
	var legacy_damage := {"yin_yang_focus":4.3, "stardust_spread":1.93, "magic_laser":3.2, "sword_wave_fan":1.81}
	if legacy_damage.has(String(legacy_profile.get("id", ""))):
		legacy_profile["base_damage"] = legacy_damage[String(legacy_profile.id)]
	var specs: Array = []
	match pattern_id:
		"miko_tracking_ofuda":
			var offsets := [-30.0, 0.0, 30.0] if level < 3 else [-48.0, -24.0, 0.0, 24.0, 48.0]
			if focused:
				offsets = [-28.0, -14.0, 0.0, 14.0, 28.0] if level >= 3 else [-16.0, 0.0, 16.0]
			var speed := float(legacy_profile.get("bullet_speed", 5.4))
			for offset in offsets:
				specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -20.0), Vector2(offset * 0.025, -speed), 3.2, 1.0, true, 2, 150.0))
			if level >= 5:
				specs.append(_shot_spec(legacy_profile, origin + Vector2(-64.0, -14.0), Vector2(-0.9, -speed * 0.92), 3.0, 0.9, true, 2, 160.0))
				specs.append(_shot_spec(legacy_profile, origin + Vector2(64.0, -14.0), Vector2(0.9, -speed * 0.92), 3.0, 0.9, true, 2, 160.0))
		"miko_yinyang_focus":
			var speed := float(legacy_profile.get("bullet_speed", 9.2))
			var offsets := [0.0]
			if level >= 3: offsets = [-7.0, 7.0] if focused else [-10.0, 0.0, 10.0]
			for offset in offsets: specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -19.0), Vector2(0.0, -speed), 5.3, 1.15, false, 1, 110.0))
		"magician_stardust_spread":
			var offsets := [-28.0, -14.0, 0.0, 14.0, 28.0] if level >= 3 else [-12.0, 0.0, 12.0]
			if level >= 5: offsets = [-40.0, -28.0, -14.0, 0.0, 14.0, 28.0, 40.0]
			if focused: offsets = [-22.0, -11.0, 0.0, 11.0, 22.0]
			var speed := float(legacy_profile.get("bullet_speed", 7.4))
			for offset in offsets: specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -18.0), Vector2(offset * 0.08, -speed), 4.0, 1.0, false, 0, 95.0))
		"magician_magic_laser":
			var speed := float(legacy_profile.get("bullet_speed", 11.0))
			var offsets := [0.0]
			if level >= 5 and not focused: offsets = [-5.0, 5.0]
			elif level >= 4 and focused: offsets = [-3.0, 0.0, 3.0]
			for offset in offsets: specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -22.0), Vector2(0.0, -speed), 6.5, 1.28, false, 1, 125.0))
		"swordswoman_wave_fan":
			var offsets := [-24.0, -12.0, 0.0, 12.0, 24.0]
			if level >= 5: offsets = [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]
			elif level >= 4: offsets = [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]
			if focused: offsets = [-26.0, -13.0, 0.0, 13.0, 26.0]
			var speed := float(legacy_profile.get("bullet_speed", 8.0))
			for offset in offsets: specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -17.0), Vector2(offset * 0.055, -speed), 4.5, 1.0, false, 0, 100.0))
		"swordswoman_returning_blades":
			var offsets := [-24.0, 0.0, 24.0]
			if level >= 5: offsets = [-40.0, -20.0, 0.0, 20.0, 40.0]
			elif level >= 4: offsets = [-32.0, -10.0, 10.0, 32.0]
			if focused: offsets = [-24.0, -8.0, 8.0, 24.0] if level >= 4 else [-16.0, 0.0, 16.0]
			var speed := float(legacy_profile.get("bullet_speed", 6.4))
			for offset in offsets: specs.append(_shot_spec(legacy_profile, origin + Vector2(offset, -20.0), Vector2(offset * 0.03, -speed), 4.2, 1.0, true, 2, 190.0))
		_:
			specs = fire_pattern(legacy_profile, level, focused, origin)
	for spec in specs:
		spec.erase("behavior")
	return specs

func _shot_spec(shot_profile: Dictionary, position: Vector2, velocity: Vector2, radius: float, damage_multiplier: float, homing: bool, btype: int, lifetime: float, behavior: Dictionary = {}) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"radius": radius,
		"color": shot_profile.get("color", Color.WHITE),
		"damage": float(shot_profile.get("base_damage", 1.0)) * damage_multiplier,
		"homing": homing,
		"btype": btype,
		"persist": false,
		"lifetime": lifetime,
		"behavior": behavior.duplicate(true),
	}

func _miko_tracking_ofuda(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-30.0, 0.0, 30.0] if level < 3 else [-52.0, -26.0, 0.0, 26.0, 52.0]
	var behavior := {"kind":"tracking_ofuda", "tracking_range":460.0, "acquisition_half_angle":1.05, "turn_rate":0.038, "max_deflect":1.05}
	if focused:
		offsets = [-20.0, -10.0, 0.0, 10.0, 20.0] if level >= 3 else [-10.0, 0.0, 10.0]
		behavior = {"kind":"tracking_ofuda", "tracking_range":260.0, "acquisition_half_angle":0.36, "turn_rate":0.09, "max_deflect":0.42}
	var speed := float(shot_profile.get("bullet_speed", 5.4))
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -20.0), Vector2(offset * 0.018, -speed), 3.2, 1.0, true, 2, 150.0, behavior))
	if level >= 5:
		var wing := 34.0 if focused else 72.0
		specs.append(_shot_spec(shot_profile, origin + Vector2(-wing, -14.0), Vector2(-0.65, -speed * 0.92), 3.0, 0.9, true, 2, 160.0, behavior))
		specs.append(_shot_spec(shot_profile, origin + Vector2(wing, -14.0), Vector2(0.65, -speed * 0.92), 3.0, 0.9, true, 2, 160.0, behavior))
	return specs

func _miko_yinyang_focus(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var speed := float(shot_profile.get("bullet_speed", 9.2))
	var offsets := [-38.0, 38.0] if not focused else [-8.0, 8.0]
	if level >= 3:
		offsets = [-56.0, 0.0, 56.0] if not focused else [-11.0, 0.0, 11.0]
	for offset in offsets:
		var inward: float = -signf(offset) * 0.12 if focused else signf(offset) * 0.08
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -19.0), Vector2(inward, -speed), 5.0, 1.0, false, 1, 110.0, {"kind":"yinyang_satellite", "satellite_offset":offset, "focused":focused}))
	return specs

func _magician_stardust_spread(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-28.0, -14.0, 0.0, 14.0, 28.0] if level >= 3 else [-12.0, 0.0, 12.0]
	if level >= 5:
		offsets = [-40.0, -28.0, -14.0, 0.0, 14.0, 28.0, 40.0]
	if focused:
		offsets = [-16.0, -8.0, 0.0, 8.0, 16.0]
	var speed := float(shot_profile.get("bullet_speed", 7.4))
	for offset in offsets:
		var behavior := {"kind":"distance_damage", "origin":origin, "near_range":250.0, "near_multiplier":1.35, "far_multiplier":0.72}
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -18.0), Vector2(offset * (0.045 if focused else 0.09), -speed), 4.0, 1.0, false, 0, 95.0, behavior))
	return specs

func _magician_magic_laser(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var speed := float(shot_profile.get("bullet_speed", 11.0))
	var offsets := [-5.0, 5.0] if not focused else [0.0]
	if level >= 4:
		offsets = [-9.0, 0.0, 9.0] if not focused else [-2.5, 0.0, 2.5]
	for offset in offsets:
		var damage_scale: float = 0.72 if not focused else 1.35
		var radius: float = 10.0 if not focused else 4.0
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -22.0), Vector2(0.0, -speed), radius, damage_scale, false, 1, 90.0, {"kind":"sustained_laser", "piercing":true, "max_hits":12, "repeat_interval":6.0, "focused":focused}))
	return specs

func _swordswoman_wave_fan(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-24.0, -12.0, 0.0, 12.0, 24.0]
	if level >= 5:
		offsets = [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]
	elif level >= 4:
		offsets = [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]
	if focused:
		offsets = [-16.0, -8.0, 0.0, 8.0, 16.0]
	var speed := float(shot_profile.get("bullet_speed", 8.0))
	for offset in offsets:
		var cross_velocity: float = -signf(offset) * 0.24 if focused else float(offset) * 0.06
		var behavior := {"kind":"distance_damage", "origin":origin, "near_range":330.0, "near_multiplier":1.28, "far_multiplier":0.52, "cross_slash":focused}
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -17.0), Vector2(cross_velocity, -speed), 4.5, 1.0, false, 0, 100.0, behavior))
	return specs

func _swordswoman_returning_blades(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-24.0, 0.0, 24.0]
	if level >= 5:
		offsets = [-40.0, -20.0, 0.0, 20.0, 40.0]
	elif level >= 4:
		offsets = [-32.0, -10.0, 10.0, 32.0]
	if focused:
		offsets = [-24.0, -8.0, 8.0, 24.0] if level >= 4 else [-16.0, 0.0, 16.0]
	var speed := float(shot_profile.get("bullet_speed", 6.4))
	for offset in offsets:
		var lateral: float = float(offset) * (0.045 if not focused else 0.025)
		var behavior := {"kind":"returning_blade", "piercing":true, "max_hits":16, "turn_age":70.0 if not focused else 62.0, "return_speed":speed * 0.92, "lateral_response":82.0, "returned":false}
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -20.0), Vector2(lateral, -speed), 4.2, 1.0, false, 2, 190.0, behavior))
	return specs
