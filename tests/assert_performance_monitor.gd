extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var monitor_script = load("res://autoload/performance_monitor.gd")
	if monitor_script == null:
		_fail("Could not load performance_monitor.gd")
	var monitor = monitor_script.new()
	monitor.set_counter("enemy_bullets", 12)
	monitor.increment("enemy_bullets", 3)
	monitor.set_counter("fps", 60)
	var snap: Dictionary = monitor.snapshot()
	if int(snap["enemy_bullets"]) != 15:
		_fail("Expected enemy_bullets 15, got %s" % [snap["enemy_bullets"]])
	if int(snap["fps"]) != 60:
		_fail("Expected fps 60, got %s" % [snap["fps"]])
	monitor.reset_frame()
	var reset_snap: Dictionary = monitor.snapshot()
	if int(reset_snap.get("enemy_bullets", 0)) != 0:
		_fail("Expected enemy_bullets reset to 0")
	if int(reset_snap.get("fps", 0)) != 0:
		_fail("Expected fps reset to 0")
	quit(0)
