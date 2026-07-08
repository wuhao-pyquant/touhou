extends RefCounted
class_name BulletManager

const OWNER_PLAYER := 0
const OWNER_ENEMY := 1

const KIND_PLAYER := 0
const KIND_CIRCLE := 1
const KIND_RICE := 2
const KIND_BUTTERFLY := 3
const KIND_NEEDLE := 4
const KIND_TALISMAN := 5
const KIND_STAR := 6
const KIND_LASER := 7
const KIND_LARGE_ORB := 8

var capacity: int = 0
var active := PackedByteArray()
var owner := PackedInt32Array()
var kind := PackedInt32Array()
var color_index := PackedInt32Array()
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var radius := PackedFloat32Array()
var lifetime := PackedFloat32Array()
var age := PackedFloat32Array()
var damage := PackedFloat32Array()
var _active_count: int = 0
var _cursor: int = 0

func configure(new_capacity: int) -> void:
	capacity = max(0, new_capacity)
	active.resize(capacity)
	owner.resize(capacity)
	kind.resize(capacity)
	color_index.resize(capacity)
	x.resize(capacity)
	y.resize(capacity)
	vx.resize(capacity)
	vy.resize(capacity)
	radius.resize(capacity)
	lifetime.resize(capacity)
	age.resize(capacity)
	damage.resize(capacity)
	clear()

func clear() -> void:
	for i in range(capacity):
		active[i] = 0
		owner[i] = OWNER_ENEMY
		kind[i] = KIND_CIRCLE
		color_index[i] = 0
		x[i] = 0.0
		y[i] = 0.0
		vx[i] = 0.0
		vy[i] = 0.0
		radius[i] = 0.0
		lifetime[i] = 0.0
		age[i] = 0.0
		damage[i] = 0.0
	_active_count = 0
	_cursor = 0

func spawn(new_owner: int, new_kind: int, position: Vector2, velocity: Vector2, new_radius: float, new_lifetime: float, new_damage: float, new_color_index: int) -> int:
	if capacity <= 0:
		return -1
	for offset in range(capacity):
		var idx := (_cursor + offset) % capacity
		if active[idx] == 0:
			active[idx] = 1
			owner[idx] = new_owner
			kind[idx] = new_kind
			color_index[idx] = new_color_index
			x[idx] = position.x
			y[idx] = position.y
			vx[idx] = velocity.x
			vy[idx] = velocity.y
			radius[idx] = new_radius
			lifetime[idx] = new_lifetime
			age[idx] = 0.0
			damage[idx] = new_damage
			_active_count += 1
			_cursor = (idx + 1) % capacity
			return idx
	return -1

func update(delta_frames: float) -> void:
	for i in range(capacity):
		if active[i] == 0:
			continue
		x[i] += vx[i] * delta_frames
		y[i] += vy[i] * delta_frames
		age[i] += delta_frames
		if age[i] > lifetime[i]:
			active[i] = 0
			_active_count -= 1

func clear_owner(target_owner: int) -> void:
	for i in range(capacity):
		if active[i] == 1 and owner[i] == target_owner:
			active[i] = 0
			_active_count -= 1

func count_active() -> int:
	return _active_count

func snapshot_active_indices() -> Array:
	var out: Array = []
	for i in range(capacity):
		if active[i] == 1:
			out.append(i)
	return out
