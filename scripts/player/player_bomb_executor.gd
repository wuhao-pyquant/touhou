extends RefCounted
class_name PlayerBombExecutor

func start_state(bomb_profile: Dictionary, origin: Vector2, direction: Vector2) -> Dictionary:
	var normalized_dir: Vector2 = direction.normalized()
	if normalized_dir == Vector2.ZERO:
		normalized_dir = Vector2(0, -1)
	var state: Dictionary = bomb_profile.duplicate(true)
	state["origin"] = origin
	state["direction"] = normalized_dir
	state["behavior_id"] = String(bomb_profile.get("behavior_id", "boundary_bloom"))
	state["duration"] = int(bomb_profile.get("duration_frames", 120))
	state["waves"] = int(bomb_profile.get("waves", 4))
	state["clear_radius"] = float(bomb_profile.get("clear_radius", 160.0))
	state["damage"] = float(bomb_profile.get("damage", 1.0))
	state["bullet_count"] = int(bomb_profile.get("bullet_count", 12))
	state["speed"] = float(bomb_profile.get("speed", 4.0))
	state["color"] = bomb_profile.get("color", Color.WHITE)
	return state

func wave_specs(state: Dictionary, phase: int) -> Array:
	match String(state.get("behavior_id", "boundary_bloom")):
		"master_spark":
			return _master_spark_specs(state, phase)
		"instant_slash":
			return _instant_slash_specs(state, phase)
		_:
			return _boundary_bloom_specs(state, phase)

func should_clear_enemy_bullet(state: Dictionary, bullet: Dictionary, player_position: Vector2) -> bool:
	var bullet_position: Vector2 = Vector2(float(bullet.get("x", 0.0)), float(bullet.get("y", 0.0)))
	var direction: Vector2 = _state_direction(state)
	match String(state.get("behavior_id", "boundary_bloom")):
		"master_spark":
			return _inside_directional_lane(player_position, bullet_position, direction, 520.0, 90.0)
		"instant_slash":
			return _inside_directional_lane(player_position, bullet_position, direction, 360.0, 82.0)
		_:
			return bullet_position.distance_to(player_position) <= float(state.get("clear_radius", 160.0))

func _boundary_bloom_specs(state: Dictionary, phase: int) -> Array:
	var specs: Array = []
	var origin: Vector2 = state.get("origin", Vector2.ZERO)
	var count: int = max(1, int(state.get("bullet_count", 12)))
	var speed: float = float(state.get("speed", 4.0))
	for i in range(count):
		var angle: float = TAU / float(count) * float(i) + float(phase) * 0.3
		specs.append(_bomb_spec(
			state,
			origin,
			Vector2(cos(angle), sin(angle)) * speed,
			7.0,
			float(state.get("damage", 1.0)),
			false,
			-1,
			90.0
		))
	return specs

func _master_spark_specs(state: Dictionary, phase: int) -> Array:
	var specs: Array = []
	var origin: Vector2 = state.get("origin", Vector2.ZERO)
	var direction: Vector2 = _state_direction(state)
	var side: Vector2 = direction.orthogonal()
	var count: int = max(1, int(state.get("bullet_count", 9)))
	var speed: float = float(state.get("speed", 11.0))
	var denom: float = max(1.0, float(count - 1))
	for i in range(count):
		var lane_offset: float = (float(i) / denom - 0.5) * 84.0
		var phase_push: float = float(phase) * 10.0
		specs.append(_bomb_spec(
			state,
			origin + side * lane_offset + direction * phase_push,
			direction * speed,
			14.0,
			float(state.get("damage", 1.0)),
			false,
			1,
			72.0
		))
	return specs

func _instant_slash_specs(state: Dictionary, phase: int) -> Array:
	var specs: Array = []
	var origin: Vector2 = state.get("origin", Vector2.ZERO)
	var direction: Vector2 = _state_direction(state)
	var side: Vector2 = direction.orthogonal()
	var count: int = max(1, int(state.get("bullet_count", 7)))
	var speed: float = float(state.get("speed", 9.0))
	var denom: float = max(1.0, float(count - 1))
	for i in range(count):
		var fan: float = (float(i) / denom - 0.5)
		var slash_dir: Vector2 = (direction + side * fan * 0.55).normalized()
		var start: Vector2 = origin + side * fan * 42.0 + direction * float(phase) * 7.0
		specs.append(_bomb_spec(
			state,
			start,
			slash_dir * speed,
			10.0,
			float(state.get("damage", 1.0)),
			false,
			0,
			58.0
		))
	return specs

func _bomb_spec(state: Dictionary, position: Vector2, velocity: Vector2, radius: float, damage: float, homing: bool, btype: int, lifetime: float) -> Dictionary:
	return {
		"position": position,
		"velocity": velocity,
		"radius": radius,
		"color": state.get("color", Color.WHITE),
		"damage": damage,
		"homing": homing,
		"btype": btype,
		"persist": true,
		"lifetime": lifetime,
	}

func _state_direction(state: Dictionary) -> Vector2:
	var direction: Vector2 = state.get("direction", Vector2(0, -1))
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		return Vector2(0, -1)
	return direction

func _inside_directional_lane(origin: Vector2, point: Vector2, direction: Vector2, max_forward: float, lane_width: float) -> bool:
	var to_point: Vector2 = point - origin
	var forward: float = to_point.dot(direction)
	if forward < 0.0 or forward > max_forward:
		return false
	var side: float = abs(to_point.dot(direction.orthogonal()))
	return side <= lane_width
