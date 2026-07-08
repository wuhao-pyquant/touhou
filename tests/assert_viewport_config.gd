extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _verify_gameplay_fallbacks(gm: Object, main: Node2D) -> void:
	for stage in [4, 5, 6]:
		gm.current_stage = stage
		main._load_stage(stage)
		_assert(main.stage_controller.has("boss_time"), "stage %d missing boss_time" % stage)
		_assert(main.stage_controller.has("waves"), "stage %d missing waves table" % stage)
		_assert(main.stage_controller.has("boss_spawned"), "stage %d missing boss_spawned flag" % stage)
		_assert(main.stage_controller.has("fallback_from"), "stage %d missing fallback marker" % stage)

		main._stage_waves(0)
		main._stage_waves(120)
		main._stage_waves(420)

		main.boss = {}
		main._load_boss_cards()
		_assert(main.boss.has("cards"), "stage %d boss cards fallback is empty" % stage)
		var cards: Array = main.boss.get("cards", [])
		_assert(cards.size() > 0, "stage %d boss cards fallback is empty" % stage)

func _verify_item_boundary(gm: Object, main: Node2D) -> void:
	var right_limit: float = float(gm.SCREEN_W - 11)
	var baseline_x: float = gm.SCREEN_W * 0.78
	main.items = []
	main.items.append({
		"alive": true,
		"collected": false,
		"x": baseline_x,
		"y": 200.0,
		"type": "power",
		"radius": 9.0,
		"vy": 0.0,
		"vx": 0.0,
		"floating": false,
		"target_y": 128.0,
		"drift_dir": 1.0,
		"sway": 0.0,
		"birth": 0.0,
		"anim": 0.0
	})
	main._update_items(1.0)
	var it: Dictionary = main.items[0]
	_assert(it.x > baseline_x, "Item should not reverse direction at baseline right-side x")
	_assert(is_equal_approx(it.drift_dir, 1.0), "Item drift_dir should still be +1 before reaching SCREEN_W - 11")

	main.items = []
	main.items.append({
		"alive": true,
		"collected": false,
		"x": gm.SCREEN_W - 20.0,
		"y": 200.0,
		"type": "power",
		"radius": 9.0,
		"vy": 0.0,
		"vx": 0.0,
		"floating": false,
		"target_y": 128.0,
		"drift_dir": 1.0,
		"sway": 0.0,
		"birth": 0.0,
		"anim": 0.0
	})
	main._update_items(1.0)
	_assert(is_equal_approx(main.items[0].x, right_limit), "Item x should clamp to SCREEN_W - 11 on right edge")

func _verify_main_player_layout(gm: Object, root_gm: Node, main_scene: PackedScene) -> void:
	var main = main_scene.instantiate()
	get_root().add_child(main)
	_assert(main.is_inside_tree(), "Main scene should be inside the tree after add_child()")
	_assert(main.get_parent().get_node_or_null("GameManager") != null, "Main scene parent should expose GameManager")
	main._resolve_singletons()
	_assert(root_gm != null, "Expected /root/GameManager autoload to exist during viewport test")
	_assert(main.game_manager_ref == root_gm, "Main scene should bind to /root/GameManager after _ready()")

	_assert(main.player_x == gm.SCREEN_W * 0.5, "Initial player_x is not viewport-centered")
	main._reset_player()
	_assert(main.player_y == gm.SCREEN_H * 0.5625, "Reset player_y is not viewport-scaled")
	root_gm.state = "title"
	root_gm.current_stage = 3
	main._start_game()
	_assert(root_gm.state == "stage", "_start_game() should update /root/GameManager.state")
	_assert(root_gm.current_stage == 1, "_start_game() should reset /root/GameManager.current_stage to stage 1")
	_assert(main.game_manager_ref == root_gm, "Main scene should keep using /root/GameManager after _start_game()")
	main._init_boss()
	_assert(is_equal_approx(main.boss.x, gm.SCREEN_W * 0.5), "Boss spawn x should center on SCREEN_W")
	main.boss.phase = "active"
	main.boss.declaring = false
	main.boss.sway = 0.0
	main._update_boss_entity(0.0)
	_assert(is_equal_approx(main.boss.target_x, gm.SCREEN_W * 0.5), "Boss target_x should center on SCREEN_W")

	# Viewport-aware boss HUD geometry
	var original_w: int = main.SCREEN_W
	var original_h: int = main.SCREEN_H
	main.boss = {}
	main.SCREEN_W = gm.SCREEN_W
	main.SCREEN_H = gm.SCREEN_H
	_verify_boss_hud_geometry(main)
	main.SCREEN_W = 960
	main.SCREEN_H = 1440
	_verify_boss_hud_geometry(main)
	main.SCREEN_W = original_w
	main.SCREEN_H = original_h

	_verify_item_boundary(gm, main)
	_verify_gameplay_fallbacks(gm, main)
	main.queue_free()

func _verify_boss_hud_geometry(main: Node2D) -> void:
	var base_hp: Rect2 = main._boss_hp_bar_rect()
	var expected_hp_w: float = clampf(main.SCREEN_W * 200.0 / 720.0, 120.0, 360.0)
	_assert(is_equal_approx(base_hp.size.x, expected_hp_w), "HP bar width should follow viewport width ratio")
	_assert(is_equal_approx(base_hp.position.x, (main.SCREEN_W - expected_hp_w) * 0.5), "HP bar should stay centered by viewport")
	_assert(is_equal_approx(base_hp.position.y, main.SCREEN_H * (28.0 / 960.0)), "HP bar Y should be viewport-driven")
	_assert(is_equal_approx(base_hp.size.y, 14.0), "HP bar height should remain fixed at 14")

	var base_indicator_w: float = main._boss_indicator_width()
	var expected_indicator_w: float = clampf(main.SCREEN_W * (40.0 / 720.0), 20.0, 80.0)
	_assert(is_equal_approx(base_indicator_w, expected_indicator_w), "Indicator width should follow viewport width ratio")
	_assert(base_indicator_w > 0.0, "Indicator width should stay positive")

	main.boss = {"x": -250.0}
	var left_rect: Rect2 = main._boss_indicator_rect()
	var left_target_x: float = 16.0
	_assert(is_equal_approx(left_rect.position.x, left_target_x), "Indicator should clamp to left playfield margin")

	main.boss = {"x": main.SCREEN_W + 250.0}
	var right_rect: Rect2 = main._boss_indicator_rect()
	_assert(is_equal_approx(right_rect.position.x, main.SCREEN_W - 16.0 - base_indicator_w), "Indicator should clamp to right playfield margin")
	_assert(is_equal_approx(right_rect.position.y, main.SCREEN_H * (610.0 / 960.0)), "Indicator Y should be viewport-derived")
	_assert(is_equal_approx(right_rect.size.y, main.SCREEN_H * (24.0 / 960.0)), "Indicator height should be viewport-derived")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	_assert(width == 720, "Expected viewport_width 720, got %d" % width)
	_assert(height == 960, "Expected viewport_height 960, got %d" % height)

	var gm_script = load("res://autoload/game_manager.gd")
	if gm_script == null:
		_fail("Could not load GameManager script")
	var gm = gm_script.new()
	_assert(gm.SCREEN_W == 720, "Expected GameManager.SCREEN_W 720, got %d" % gm.SCREEN_W)
	_assert(gm.SCREEN_H == 960, "Expected GameManager.SCREEN_H 960, got %d" % gm.SCREEN_H)
	var rect: Rect2 = gm.playfield_rect()
	_assert(rect.position == Vector2.ZERO, "Expected playfield origin Vector2.ZERO, got %s" % [rect.position])
	_assert(rect.size == Vector2(720, 960), "Expected playfield size 720x960, got %s" % [rect.size])
	_assert(gm.stage_count() == 6, "Expected six configured stage names, got %d" % gm.stage_count())

	var main_scene = load("res://scenes/main.tscn")
	if main_scene == null:
		_fail("Could not load main scene")
	var created_root_gm := false
	var root_gm = get_root().get_node_or_null("GameManager")
	if root_gm == null:
		root_gm = gm_script.new()
		root_gm.name = "GameManager"
		get_root().add_child(root_gm)
		created_root_gm = true
	_verify_main_player_layout(gm, root_gm, main_scene)
	if created_root_gm:
		root_gm.queue_free()
	quit(0)
