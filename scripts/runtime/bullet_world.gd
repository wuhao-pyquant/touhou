extends RefCounted

const VERSION := 1
const LASER_NONE := "none"
const LASER_WARNING := "warning"
const LASER_ACTIVE := "active"
const LASER_EXPIRED := "expired"
const LASER_STATES := [LASER_NONE, LASER_WARNING, LASER_ACTIVE, LASER_EXPIRED]

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
	}

func capture_state(bullet_pool: Array, active_indices: Array, spawn_cursor: int) -> Dictionary:
	var ordered_indices: Array[int] = []
	for value in active_indices:
		ordered_indices.append(int(value))
	ordered_indices.sort()
	var active_bullets: Array[Dictionary] = []
	for bullet_index in ordered_indices:
		if bullet_index < 0 or bullet_index >= bullet_pool.size():
			continue
		var bullet: Dictionary = bullet_pool[bullet_index]
		if bool(bullet.get("active", false)):
			active_bullets.append({"slot": bullet_index, "state": bullet.duplicate(true)})
	return {
		"version": VERSION,
		"capacity": bullet_pool.size(),
		"spawn_cursor": maxi(spawn_cursor, 0),
		"active_bullets": active_bullets,
	}

func restore_state(snapshot: Dictionary, bullet_pool: Array) -> Dictionary:
	if int(snapshot.get("version", -1)) != VERSION:
		return {"ok": false, "active_indices": [], "spawn_cursor": 0}
	var required_capacity := maxi(int(snapshot.get("capacity", bullet_pool.size())), 0)
	while bullet_pool.size() < required_capacity:
		bullet_pool.append(make_bullet_state())
	for bullet in bullet_pool:
		bullet["active"] = false
	var active_indices: Array[int] = []
	for entry in snapshot.get("active_bullets", []):
		var slot := int(entry.get("slot", -1))
		if slot < 0 or slot >= bullet_pool.size():
			continue
		var restored: Dictionary = entry.get("state", {}).duplicate(true)
		restored["active"] = true
		bullet_pool[slot] = restored
		active_indices.append(slot)
	active_indices.sort()
	return {
		"ok": true,
		"active_indices": active_indices,
		"spawn_cursor": int(snapshot.get("spawn_cursor", 0)),
	}

func circles_overlap(a_position: Vector2, a_radius: float, b_position: Vector2, b_radius: float) -> bool:
	var limit := maxf(a_radius, 0.0) + maxf(b_radius, 0.0)
	return a_position.distance_squared_to(b_position) < limit * limit

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
	bullet["laser_state"] = next_state
	if next_state == LASER_EXPIRED:
		bullet["active"] = false
	return true
