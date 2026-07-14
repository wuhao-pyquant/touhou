extends RefCounted

const VERSION := 1

var initial_seed: int = 1
var draw_count: int = 0
var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void:
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	initial_seed = seed_value
	draw_count = 0
	_rng.seed = seed_value

func next_float() -> float:
	draw_count += 1
	return _rng.randf()

func range_float(from: float, to: float) -> float:
	draw_count += 1
	return _rng.randf_range(from, to)

func next_u32() -> int:
	draw_count += 1
	return _rng.randi()

func range_int(from: int, to: int) -> int:
	draw_count += 1
	return _rng.randi_range(from, to)

func snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"initial_seed": initial_seed,
		"state": _rng.state,
		"draw_count": draw_count,
	}

func restore(state: Dictionary) -> bool:
	if int(state.get("version", -1)) != VERSION:
		return false
	initial_seed = int(state.get("initial_seed", 1))
	draw_count = maxi(int(state.get("draw_count", 0)), 0)
	_rng.seed = initial_seed
	_rng.state = int(state.get("state", _rng.state))
	return true
