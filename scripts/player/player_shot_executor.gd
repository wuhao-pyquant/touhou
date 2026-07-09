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

func _shot_spec(shot_profile: Dictionary, position: Vector2, velocity: Vector2, radius: float, damage_multiplier: float, homing: bool, btype: int, lifetime: float) -> Dictionary:
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
	}

func _miko_tracking_ofuda(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-30.0, 0.0, 30.0] if level < 3 else [-48.0, -24.0, 0.0, 24.0, 48.0]
	if focused:
		offsets = [-28.0, -14.0, 0.0, 14.0, 28.0] if level >= 3 else [-16.0, 0.0, 16.0]
	var speed := float(shot_profile.get("bullet_speed", 5.4))
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -20.0), Vector2(offset * 0.025, -speed), 3.2, 1.0, true, 2, 150.0))
	if level >= 5:
		specs.append(_shot_spec(shot_profile, origin + Vector2(-64.0, -14.0), Vector2(-0.9, -speed * 0.92), 3.0, 0.9, true, 2, 160.0))
		specs.append(_shot_spec(shot_profile, origin + Vector2(64.0, -14.0), Vector2(0.9, -speed * 0.92), 3.0, 0.9, true, 2, 160.0))
	return specs

func _miko_yinyang_focus(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var speed := float(shot_profile.get("bullet_speed", 9.2))
	var offsets := [0.0]
	if level >= 3:
		offsets = [-7.0, 7.0] if focused else [-10.0, 0.0, 10.0]
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -19.0), Vector2(0.0, -speed), 5.3, 1.15, false, 1, 110.0))
	return specs

func _magician_stardust_spread(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-28.0, -14.0, 0.0, 14.0, 28.0] if level >= 3 else [-12.0, 0.0, 12.0]
	if level >= 5:
		offsets = [-40.0, -28.0, -14.0, 0.0, 14.0, 28.0, 40.0]
	if focused:
		offsets = [-22.0, -11.0, 0.0, 11.0, 22.0]
	var speed := float(shot_profile.get("bullet_speed", 7.4))
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -18.0), Vector2(offset * 0.08, -speed), 4.0, 1.0, false, 0, 95.0))
	return specs

func _magician_magic_laser(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var speed := float(shot_profile.get("bullet_speed", 11.0))
	var offsets := [0.0]
	if level >= 5 and not focused:
		offsets = [-5.0, 5.0]
	elif level >= 4 and focused:
		offsets = [-3.0, 0.0, 3.0]
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -22.0), Vector2(0.0, -speed), 6.5, 1.28, false, 1, 125.0))
	return specs

func _swordswoman_wave_fan(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	var specs: Array = []
	var offsets := [-24.0, -12.0, 0.0, 12.0, 24.0]
	if level >= 5:
		offsets = [-40.0, -30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0, 40.0]
	elif level >= 4:
		offsets = [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]
	if focused:
		offsets = [-26.0, -13.0, 0.0, 13.0, 26.0]
	var speed := float(shot_profile.get("bullet_speed", 8.0))
	for offset in offsets:
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -17.0), Vector2(offset * 0.055, -speed), 4.5, 1.0, false, 0, 100.0))
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
		specs.append(_shot_spec(shot_profile, origin + Vector2(offset, -20.0), Vector2(offset * 0.03, -speed), 4.2, 1.0, true, 2, 190.0))
	return specs
