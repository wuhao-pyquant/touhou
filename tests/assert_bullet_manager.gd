extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var manager_script = load("res://scripts/runtime/bullet_manager.gd")
	if manager_script == null:
		_fail("Could not load bullet_manager.gd")
	var manager = manager_script.new()
	manager.configure(4)
	if manager.count_active() != 0:
		_fail("Fresh pool must have zero active bullets")

	var first: int = manager.spawn(manager.OWNER_ENEMY, manager.KIND_CIRCLE, Vector2(10, 20), Vector2(2, 3), 5.0, 10.0, 1.0, 2)
	if first != 0:
		_fail("Expected first spawn index 0, got %d" % first)
	if manager.count_active() != 1:
		_fail("Expected one active bullet after spawn")

	manager.update(2.0)
	if abs(manager.x[first] - 14.0) > 0.001:
		_fail("Expected x 14 after update, got %f" % manager.x[first])
	if abs(manager.y[first] - 26.0) > 0.001:
		_fail("Expected y 26 after update, got %f" % manager.y[first])

	manager.update(9.0)
	if manager.count_active() != 0:
		_fail("Bullet should expire after lifetime")

	manager.spawn(manager.OWNER_PLAYER, manager.KIND_PLAYER, Vector2.ZERO, Vector2(0, -5), 4.0, 20.0, 2.0, 1)
	manager.spawn(manager.OWNER_ENEMY, manager.KIND_RICE, Vector2.ONE, Vector2(0, 5), 4.0, 20.0, 1.0, 3)
	manager.clear_owner(manager.OWNER_ENEMY)
	if manager.count_active() != 1:
		_fail("clear_owner(OWNER_ENEMY) should leave one player bullet active")
	manager.clear()
	if manager.count_active() != 0:
		_fail("clear should deactivate every bullet")

	quit(0)
