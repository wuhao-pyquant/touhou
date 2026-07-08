extends Node

var counters: Dictionary = {}

func set_counter(name: String, value: int) -> void:
	counters[name] = value

func increment(name: String, amount: int = 1) -> void:
	counters[name] = int(counters.get(name, 0)) + amount

func snapshot() -> Dictionary:
	return counters.duplicate(true)

func reset_frame() -> void:
	counters.clear()
