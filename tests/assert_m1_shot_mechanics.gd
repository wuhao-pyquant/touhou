extends SceneTree

var failed := false
var db = load("res://scripts/data/game_database.gd").new()
var executor = load("res://scripts/player/player_shot_executor.gd").new()

func _fail(message: String) -> void:
	if failed: return
	failed = true
	push_error("M1_FAIL: %s" % message)
	quit(1)

func _assert(condition: bool, message: String) -> bool:
	if not condition: _fail(message)
	return condition

func _new_main() -> Node:
	var shell = load("res://scripts/main.gd").new()
	shell.game_manager_ref = load("res://autoload/game_manager.gd").new()
	shell.audio_manager_ref = null
	shell.bullet_world.configure(1024, 8192, 512)
	shell._sync_bullet_world_compatibility_views()
	return shell

func _free_main(shell: Node) -> void:
	var gm = shell.game_manager_ref
	shell.free(); gm.free()

func _span(specs: Array) -> float:
	var minimum := INF; var maximum := -INF
	for spec in specs:
		minimum = minf(minimum, float(spec.position.x)); maximum = maxf(maximum, float(spec.position.x))
	return maximum - minimum

func _verify_specs_and_collision_semantics() -> void:
	var origin := Vector2(360.0, 700.0)
	var miko_a: Dictionary = db.shot_profile_by_id("ofuda_trace")
	var miko_wide: Array = executor.fire_pattern(miko_a, 5, false, origin)
	var miko_focus: Array = executor.fire_pattern(miko_a, 5, true, origin)
	_assert(_span(miko_wide) > _span(miko_focus), "Miko A focus must narrow emitted coverage.")
	_assert(float(miko_wide[0].behavior.tracking_range) > float(miko_focus[0].behavior.tracking_range), "Miko A focus must narrow tracking range.")
	_assert(float(miko_wide[0].behavior.acquisition_half_angle) > float(miko_focus[0].behavior.acquisition_half_angle), "Miko A focus must narrow acquisition cone.")
	_assert(float(miko_focus[0].behavior.turn_rate) > float(miko_wide[0].behavior.turn_rate), "Miko A focus must improve tracking accuracy/turn rate.")

	var miko_b: Dictionary = db.shot_profile_by_id("yin_yang_focus")
	_assert(_span(executor.fire_pattern(miko_b, 5, false, origin)) > 100.0, "Miko B unfocused satellites must stay at the sides.")
	_assert(_span(executor.fire_pattern(miko_b, 5, true, origin)) < 24.0, "Miko B focus must pull satellites inward.")

	var shell = _new_main()
	var star: Dictionary = db.shot_profile_by_id("stardust_spread")
	var star_spec: Dictionary = executor.fire_pattern(star, 5, false, origin)[3]
	var near_bullet := star_spec.duplicate(true); near_bullet["x"] = origin.x; near_bullet["y"] = origin.y - 40.0
	var far_bullet := star_spec.duplicate(true); far_bullet["x"] = origin.x; far_bullet["y"] = origin.y - 500.0
	_assert(shell._player_bullet_effective_damage(near_bullet) > shell._player_bullet_effective_damage(far_bullet), "Magician A must have real close-range damage benefit.")
	_assert(_span(executor.fire_pattern(star, 5, false, origin)) > _span(executor.fire_pattern(star, 5, true, origin)), "Magician A focus must narrow spread.")

	var laser: Dictionary = db.shot_profile_by_id("magic_laser")
	var laser_wide: Array = executor.fire_pattern(laser, 5, false, origin)
	var laser_focus: Array = executor.fire_pattern(laser, 5, true, origin)
	_assert(float(laser_wide[0].radius) > float(laser_focus[0].radius), "Magician B unfocused laser must be broader.")
	_assert(float(laser_wide[0].damage) < float(laser_focus[0].damage), "Magician B focused laser must be higher damage.")
	var piercing: Dictionary = laser_focus[1].duplicate(true)
	piercing.position = Vector2(360.0, 400.0); piercing.velocity = Vector2.ZERO
	shell.enemies = [
		{"alive":true,"dying":false,"x":360.0,"y":400.0,"radius":12.0,"hp":100.0,"strong":false,"drop_item_ids":[]},
		{"alive":true,"dying":false,"x":361.0,"y":400.0,"radius":12.0,"hp":100.0,"strong":false,"drop_item_ids":[]},
	]
	shell._spawn_player_bullet_spec(piercing)
	shell._check_collisions(false)
	_assert(float(shell.enemies[0].hp) < 100.0 and float(shell.enemies[1].hp) < 100.0, "Sustained laser segment must pierce multiple enemies.")
	_assert(bool(shell.bullet_pool[0].active), "Piercing laser must persist after collision.")
	var first_hp := float(shell.enemies[0].hp)
	shell._check_collisions(false)
	_assert(is_equal_approx(float(shell.enemies[0].hp), first_hp), "Laser repeat hits must obey deterministic cooldown.")

	var sword_a: Dictionary = db.shot_profile_by_id("sword_wave_fan")
	var sword_wide: Array = executor.fire_pattern(sword_a, 5, false, origin)
	var sword_focus: Array = executor.fire_pattern(sword_a, 5, true, origin)
	_assert(_span(sword_wide) > _span(sword_focus), "Swordswoman A focus must narrow the fan.")
	_assert(float(sword_focus[0].velocity.x) > 0.0 and float(sword_focus[-1].velocity.x) < 0.0, "Focused sword waves must cross inward.")
	var sword_near: Dictionary = sword_focus[2].duplicate(true); sword_near["x"] = origin.x; sword_near["y"] = origin.y - 50.0
	var sword_far: Dictionary = sword_focus[2].duplicate(true); sword_far["x"] = origin.x; sword_far["y"] = origin.y - 600.0
	_assert(shell._player_bullet_effective_damage(sword_near) > shell._player_bullet_effective_damage(sword_far), "Swordswoman A must have actual distance falloff.")

	var sword_b: Dictionary = db.shot_profile_by_id("returning_spirit_blades")
	var blade: Dictionary = executor.fire_pattern(sword_b, 5, false, origin)[0]
	shell._clear_bullets()
	shell._spawn_player_bullet_spec(blade)
	var live_blade: Dictionary = shell.bullet_pool[0]
	live_blade.age = float(live_blade.behavior.turn_age)
	live_blade.y = 250.0; shell.player_x = 360.0; shell.player_y = 700.0; shell.player_last_move_dir = Vector2.LEFT
	shell._prepare_bullet_world_step(0, live_blade, 1.0)
	var left_vx := float(live_blade.vx)
	shell.player_last_move_dir = Vector2.RIGHT
	shell._prepare_bullet_world_step(0, live_blade, 1.0)
	_assert(bool(live_blade.behavior.returned) and float(live_blade.vy) > 0.0, "Blade must reverse into a return path.")
	_assert(float(live_blade.vx) > left_vx, "Blade return path must respond to lateral player movement.")
	_assert(shell._player_bullet_can_hit(live_blade, "boss"), "Returning blade must permit its return-phase hit.")
	shell._record_player_bullet_hit(live_blade, "boss")
	_assert(not shell._player_bullet_can_hit(live_blade, "boss"), "Returning blade must be bounded to one hit per target per phase.")
	_free_main(shell)

func _fixed_boss_ttk(shot_id: String) -> int:
	var shell = _new_main()
	var gm = shell.game_manager_ref
	gm.selected_shot_id = shot_id; gm.shared_power = 50
	shell.player_x = 360.0; shell.player_y = 620.0
	shell.boss_alive = true
	shell.boss = {"x":360.0,"y":260.0,"radius":28.0,"phase":"active","declaring":false,"hp":2400.0,"max_hp":2400.0}
	var profile: Dictionary = db.shot_profile_by_id(shot_id)
	var interval := int(profile.fire_interval_frames)
	var frame := 0
	while float(shell.boss.hp) > 0.0 and frame < 3600:
		if frame % interval == 0:
			for spec in executor.fire_pattern(profile, 5, true, Vector2(shell.player_x, shell.player_y)):
				shell._spawn_player_bullet_spec(spec)
		shell._update_bullets(1.0 / 60.0, Vector2(shell.boss.x, shell.boss.y))
		shell._check_collisions(true)
		frame += 1
	_free_main(shell)
	return frame

func _verify_ttk_envelope() -> void:
	var ids := ["ofuda_trace", "yin_yang_focus", "stardust_spread", "magic_laser", "sword_wave_fan", "returning_spirit_blades"]
	var times: Array = []
	var total := 0.0
	for id in ids:
		var frames := _fixed_boss_ttk(id)
		_assert(frames < 3600, "%s failed to kill the fixed boss." % id)
		times.append(frames); total += frames
	var mean: float = total / float(times.size())
	var maximum_deviation := 0.0
	for frames in times:
		maximum_deviation = maxf(maximum_deviation, absf(float(frames) - mean) / mean * 100.0)
	print("M1_TTK frames=%s mean=%.3f max_deviation=%.3f%%" % [times, mean, maximum_deviation])
	_assert(maximum_deviation <= 15.0, "Fixed-boss real collision TTK deviation must stay within +/-15%%; got %.3f%% for %s." % [maximum_deviation, times])

func _init() -> void:
	_verify_specs_and_collision_semantics()
	if failed: return
	_verify_ttk_envelope()
	if failed: return
	print("PASS: M1 six-shot real update/collision mechanics and fixed-boss TTK benchmark.")
	quit(0)
