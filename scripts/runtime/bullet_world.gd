extends RefCounted

const VERSION := 2
const LASER_NONE := "none"
const LASER_WARNING := "warning"
const LASER_ACTIVE := "active"
const LASER_EXPIRED := "expired"
const LASER_STATES := [LASER_NONE, LASER_WARNING, LASER_ACTIVE, LASER_EXPIRED]

var pool: Array = []
var active_indices: Array[int] = []
var spawn_cursor: int = 0
var hard_capacity: int = 0
var growth_size: int = 1

var _next_active_indices: Array[int] = []
var _membership := PackedByteArray()
var _update_in_progress: bool = false

func configure(initial_capacity: int, maximum_capacity: int, growth: int) -> bool:
	if initial_capacity < 0 or maximum_capacity < initial_capacity or growth <= 0:
		return false
	hard_capacity = maximum_capacity
	growth_size = growth
	pool.clear()
	for _index in range(initial_capacity):
		pool.append(make_bullet_state())
	active_indices.clear()
	_next_active_indices.clear()
	_membership.resize(initial_capacity)
	_membership.fill(0)
	spawn_cursor = 0
	_update_in_progress = false
	return true

func make_bullet_state() -> Dictionary:
	return {
		"active": false,
		"x": 0.0,
		"y": 0.0,
		"vx": 0.0,
		"vy": 0.0,
		"radius": 6.0,
		"color": Color.RED,
		"type": "circle",
		"lifetime": 600.0,
		"age": 0.0,
		"damage": 1.0,
		"homing": false,
		"btype": -1,
		"grazed": false,
		"boss_hit": false,
		"motion": {},
		"has_motion": false,
		"motion_triggered": false,
		"laser_state": LASER_NONE,
		"laser_warning_remaining": 0.0,
		"laser_active_remaining": -1.0,
	}

func reset() -> void:
	for bullet in pool:
		bullet.active = false
	active_indices.clear()
	_next_active_indices.clear()
	_membership.resize(pool.size())
	_membership.fill(0)
	spawn_cursor = 0
	_update_in_progress = false

func rebuild_active_order() -> void:
	active_indices.clear()
	_membership.resize(pool.size())
	_membership.fill(0)
	for bullet_index in range(pool.size()):
		if bool(pool[bullet_index].get("active", false)):
			active_indices.append(bullet_index)
			_membership[bullet_index] = 1

func active_order() -> Array[int]:
	return active_indices.duplicate()

func claim_free_slot() -> int:
	var pool_size := pool.size()
	if pool_size > 0:
		for offset in range(pool_size):
			var bullet_index := (spawn_cursor + offset) % pool_size
			if not bool(pool[bullet_index].get("active", false)):
				spawn_cursor = (bullet_index + 1) % pool_size
				return bullet_index
	if pool_size >= hard_capacity:
		return -1
	var previous_size := pool_size
	var new_size := mini(maxi(pool_size + growth_size, 1), hard_capacity)
	for _index in range(previous_size, new_size):
		pool.append(make_bullet_state())
	_membership.resize(new_size)
	spawn_cursor = (previous_size + 1) % new_size
	return previous_size

func spawn_bullet(values: Dictionary) -> int:
	var bullet_index := claim_free_slot()
	if bullet_index < 0:
		return -1
	var state := make_bullet_state()
	for key in values:
		state[key] = values[key].duplicate(true) if values[key] is Array or values[key] is Dictionary else values[key]
	state.active = true
	if String(state.type) == "laser":
		var warning := maxf(float(state.get("laser_warning_remaining", 0.0)), 0.0)
		state.laser_state = LASER_WARNING if warning > 0.0 else LASER_ACTIVE
	else:
		state.laser_state = LASER_NONE
	pool[bullet_index] = state
	if _membership.size() != pool.size():
		_membership.resize(pool.size())
	if _membership[bullet_index] == 0:
		active_indices.append(bullet_index)
		_membership[bullet_index] = 1
	return bullet_index

func retire_slot(bullet_index: int) -> bool:
	if bullet_index < 0 or bullet_index >= pool.size():
		return false
	pool[bullet_index].active = false
	if String(pool[bullet_index].get("type", "")) == "laser":
		pool[bullet_index].laser_state = LASER_EXPIRED
	if bullet_index < _membership.size():
		_membership[bullet_index] = 0
	active_indices.erase(bullet_index)
	_next_active_indices.erase(bullet_index)
	return true

func begin_update() -> Array[int]:
	_next_active_indices.clear()
	_update_in_progress = true
	return active_indices.duplicate()

func finish_update_slot(bullet_index: int, keep_active: bool) -> void:
	if bullet_index < 0 or bullet_index >= pool.size():
		return
	if keep_active and bool(pool[bullet_index].get("active", false)):
		_next_active_indices.append(bullet_index)
		_membership[bullet_index] = 1
	else:
		pool[bullet_index].active = false
		if String(pool[bullet_index].get("type", "")) == "laser":
			pool[bullet_index].laser_state = LASER_EXPIRED
		_membership[bullet_index] = 0

func end_update() -> void:
	active_indices.clear()
	for bullet_index in _next_active_indices:
		active_indices.append(bullet_index)
	_next_active_indices.clear()
	_update_in_progress = false

func update_bullets(tick_delta: float, retention_bounds: Rect2, prepare_step: Callable = Callable(), finish_step: Callable = Callable()) -> int:
	var processed := 0
	for bullet_index in begin_update():
		var bullet: Dictionary = pool[bullet_index]
		if not bool(bullet.get("active", false)):
			finish_update_slot(bullet_index, false)
			continue
		if String(bullet.type) == "laser" and advance_laser_lifecycle(bullet_index, tick_delta) == LASER_EXPIRED:
			finish_update_slot(bullet_index, false)
			continue
		if prepare_step.is_valid():
			prepare_step.call(bullet_index, bullet, tick_delta)
		bullet.x = float(bullet.x) + float(bullet.vx) * tick_delta
		bullet.y = float(bullet.y) + float(bullet.vy) * tick_delta
		if finish_step.is_valid():
			finish_step.call(bullet_index, bullet, tick_delta)
		bullet.age = float(bullet.age) + tick_delta
		var outside := float(bullet.x) < retention_bounds.position.x or float(bullet.x) > retention_bounds.end.x or float(bullet.y) < retention_bounds.position.y or float(bullet.y) > retention_bounds.end.y
		if outside:
			bullet.active = false
		elif String(bullet.type) in ["player", "bomb"]:
			if float(bullet.age) > float(bullet.lifetime):
				bullet.active = false
		elif float(bullet.age) > 1800.0 and float(bullet.age) > float(bullet.lifetime):
			bullet.active = false
		finish_update_slot(bullet_index, bool(bullet.active))
		processed += 1
	end_update()
	return processed

func advance_laser_lifecycle(bullet_index: int, tick_delta: float) -> String:
	if bullet_index < 0 or bullet_index >= pool.size():
		return LASER_NONE
	var bullet: Dictionary = pool[bullet_index]
	if String(bullet.get("type", "")) != "laser":
		return LASER_NONE
	var state := laser_state(bullet)
	if state == LASER_WARNING:
		bullet.laser_warning_remaining = maxf(0.0, float(bullet.get("laser_warning_remaining", 0.0)) - tick_delta)
		if float(bullet.laser_warning_remaining) <= 0.0:
			bullet.laser_state = LASER_ACTIVE
			state = LASER_ACTIVE
	if state == LASER_ACTIVE and float(bullet.get("laser_active_remaining", -1.0)) >= 0.0:
		bullet.laser_active_remaining = maxf(0.0, float(bullet.laser_active_remaining) - tick_delta)
		if float(bullet.laser_active_remaining) <= 0.0:
			set_laser_state(bullet, LASER_EXPIRED)
			state = LASER_EXPIRED
	return state

func collision_enabled(bullet: Dictionary) -> bool:
	if not bool(bullet.get("active", false)):
		return false
	return String(bullet.get("type", "")) != "laser" or laser_state(bullet) == LASER_ACTIVE

func circles_overlap(a_position: Vector2, a_radius: float, b_position: Vector2, b_radius: float) -> bool:
	var limit := maxf(a_radius, 0.0) + maxf(b_radius, 0.0)
	return a_position.distance_squared_to(b_position) < limit * limit

func query_circle(position: Vector2, radius: float, accepted_types: Array = [], rejected_types: Array = []) -> Array[int]:
	var result: Array[int] = []
	for bullet_index in active_indices:
		var bullet: Dictionary = pool[bullet_index]
		var type_id := String(bullet.get("type", ""))
		if not collision_enabled(bullet):
			continue
		if not accepted_types.is_empty() and type_id not in accepted_types:
			continue
		if type_id in rejected_types:
			continue
		if circles_overlap(position, radius, Vector2(float(bullet.x), float(bullet.y)), float(bullet.radius)):
			result.append(bullet_index)
	return result

func laser_state(bullet: Dictionary) -> String:
	if not bool(bullet.get("active", false)):
		return LASER_EXPIRED if String(bullet.get("type", "")) == "laser" else LASER_NONE
	if String(bullet.get("type", "")) != "laser":
		return LASER_NONE
	var explicit_state := String(bullet.get("laser_state", LASER_ACTIVE))
	return explicit_state if explicit_state in LASER_STATES and explicit_state != LASER_NONE else LASER_ACTIVE

func set_laser_state(bullet: Dictionary, next_state: String) -> bool:
	if String(bullet.get("type", "")) != "laser" or next_state not in [LASER_WARNING, LASER_ACTIVE, LASER_EXPIRED]:
		return false
	bullet.laser_state = next_state
	if next_state == LASER_EXPIRED:
		bullet.active = false
	return true

func _capture_from(source_pool: Array, source_order: Array, cursor: int, maximum_capacity: int, growth: int) -> Dictionary:
	var order: Array[int] = []
	var active_bullets: Array[Dictionary] = []
	for value in source_order:
		var bullet_index := int(value)
		if bullet_index < 0 or bullet_index >= source_pool.size():
			continue
		var bullet: Dictionary = source_pool[bullet_index]
		if not bool(bullet.get("active", false)):
			continue
		order.append(bullet_index)
		active_bullets.append({"slot": bullet_index, "state": bullet.duplicate(true)})
	return {
		"version": VERSION,
		"capacity": source_pool.size(),
		"hard_capacity": maxi(maximum_capacity, source_pool.size()),
		"growth_size": maxi(growth, 1),
		"spawn_cursor": cursor,
		"active_order": order,
		"active_bullets": active_bullets,
	}

func capture_state(compat_pool: Array = [], compat_active_indices: Array = [], compat_spawn_cursor: int = -1) -> Dictionary:
	if compat_spawn_cursor >= 0 or not compat_pool.is_empty() or not compat_active_indices.is_empty():
		return _capture_from(compat_pool, compat_active_indices, maxi(compat_spawn_cursor, 0), maxi(compat_pool.size(), hard_capacity), growth_size)
	return _capture_from(pool, active_indices, spawn_cursor, hard_capacity, growth_size)

func _validated_snapshot(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("version", -1)) != VERSION:
		return {}
	for key in ["capacity", "hard_capacity", "growth_size", "spawn_cursor"]:
		if typeof(snapshot.get(key)) != TYPE_INT:
			return {}
	var capacity := int(snapshot.capacity)
	var maximum_capacity := int(snapshot.hard_capacity)
	var growth := int(snapshot.growth_size)
	var cursor := int(snapshot.spawn_cursor)
	if capacity < 0 or maximum_capacity < capacity or growth <= 0:
		return {}
	if (capacity == 0 and cursor != 0) or (capacity > 0 and (cursor < 0 or cursor >= capacity)):
		return {}
	var source_order = snapshot.get("active_order", null)
	var source_entries = snapshot.get("active_bullets", null)
	if not (source_order is Array) or not (source_entries is Array):
		return {}
	var order: Array[int] = []
	var seen := {}
	for value in source_order:
		if typeof(value) != TYPE_INT:
			return {}
		var bullet_index := int(value)
		if bullet_index < 0 or bullet_index >= capacity or seen.has(bullet_index):
			return {}
		seen[bullet_index] = true
		order.append(bullet_index)
	var states := {}
	for value in source_entries:
		if not (value is Dictionary):
			return {}
		var entry: Dictionary = value
		if typeof(entry.get("slot")) != TYPE_INT or not (entry.get("state") is Dictionary):
			return {}
		var bullet_index := int(entry.slot)
		var bullet: Dictionary = entry.state
		if bullet_index < 0 or bullet_index >= capacity or states.has(bullet_index):
			return {}
		if not seen.has(bullet_index) or not bool(bullet.get("active", false)):
			return {}
		for required_key in ["active", "x", "y", "vx", "vy", "radius", "color", "type", "lifetime", "age", "damage", "homing", "btype", "grazed", "boss_hit", "motion", "has_motion", "motion_triggered", "laser_state", "laser_warning_remaining", "laser_active_remaining"]:
			if not bullet.has(required_key):
				return {}
		for numeric_key in ["x", "y", "vx", "vy", "radius", "lifetime", "age", "damage", "laser_warning_remaining", "laser_active_remaining"]:
			if typeof(bullet[numeric_key]) not in [TYPE_FLOAT, TYPE_INT]:
				return {}
			var number := float(bullet[numeric_key])
			if is_nan(number) or is_inf(number):
				return {}
		if float(bullet.radius) <= 0.0 or float(bullet.lifetime) < 0.0 or not (bullet.color is Color) or not (bullet.motion is Dictionary):
			return {}
		for boolean_key in ["active", "homing", "grazed", "boss_hit", "has_motion", "motion_triggered"]:
			if typeof(bullet[boolean_key]) != TYPE_BOOL:
				return {}
		if String(bullet.type) == "laser" and String(bullet.laser_state) not in [LASER_WARNING, LASER_ACTIVE]:
			return {}
		if String(bullet.type) != "laser" and String(bullet.laser_state) != LASER_NONE:
			return {}
		states[bullet_index] = bullet.duplicate(true)
	if states.size() != order.size():
		return {}
	return {
		"capacity": capacity,
		"hard_capacity": maximum_capacity,
		"growth_size": growth,
		"spawn_cursor": cursor,
		"active_order": order,
		"states": states,
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	return not _validated_snapshot(snapshot).is_empty()

func restore_state(snapshot: Dictionary, destination_pool: Array = []) -> Dictionary:
	var restored := _validated_snapshot(snapshot)
	if restored.is_empty():
		return {"ok": false, "active_indices": [], "spawn_cursor": 0}
	configure(int(restored.capacity), int(restored.hard_capacity), int(restored.growth_size))
	spawn_cursor = int(restored.spawn_cursor)
	for bullet_index in restored.active_order:
		pool[bullet_index] = restored.states[bullet_index].duplicate(true)
		active_indices.append(bullet_index)
		_membership[bullet_index] = 1
	if not is_same(destination_pool, pool):
		destination_pool.clear()
		for bullet in pool:
			destination_pool.append(bullet.duplicate(true))
	return {
		"ok": true,
		"active_indices": active_indices.duplicate(),
		"spawn_cursor": spawn_cursor,
		"capacity": pool.size(),
	}
