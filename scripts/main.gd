extends Node2D

# Main game scene - all game logic in one script for simplicity

const FixedTickClock := preload("res://scripts/runtime/fixed_tick_clock.gd")
const DeterministicRng := preload("res://scripts/runtime/deterministic_rng.gd")
const SimulationStateHasher := preload("res://scripts/runtime/simulation_state_hasher.gd")
const BulletWorld := preload("res://scripts/runtime/bullet_world.gd")
const BossStateMachine := preload("res://scripts/runtime/boss_state_machine.gd")
const GameplayInputBuffer := preload("res://scripts/runtime/gameplay_input_buffer.gd")
const Stage2EncounterController := preload("res://scripts/runtime/stage2_encounter_controller.gd")
const Stage2FieldTopologyRuntime := preload("res://scripts/runtime/stage2_field_topology_runtime.gd")
const ReplayData := preload("res://scripts/replay/replay_data.gd")
const ReplayHeader := preload("res://scripts/replay/replay_header.gd")

var fixed_tick_clock: RefCounted = FixedTickClock.new()
var gameplay_rng: RefCounted = DeterministicRng.new(1)
var simulation_state_hasher: RefCounted = SimulationStateHasher.new()
var bullet_world: RefCounted = BulletWorld.new()
var boss_state_machine: RefCounted = BossStateMachine.new()
var gameplay_input_buffer: RefCounted = GameplayInputBuffer.new()
var stage2_encounter_controller: RefCounted = Stage2EncounterController.new()
var stage2_field_topology_runtime: RefCounted = Stage2FieldTopologyRuntime.new()
var replay_data: RefCounted = ReplayData.new()
var gameplay_seed: int = 1
var gameplay_difficulty: String = "normal"
var simulation_tick_index: int = 0
var current_tick_input: Dictionary = GameplayInputBuffer.empty_tick_frame(0)
var replay_runtime_mode: String = "none"
var replay_identity: Dictionary = {}

# Compatibility views only. BulletWorld owns and mutates these arrays.
var bullet_pool: Array = []
var active_bullet_indices: Array[int] = []
var enemies: Array = []
var items: Array = []
var combat_effects: Array = []
var boss: Dictionary = {}
var boss_alive: bool = false
var stage_controller: Dictionary = {}
var stage_timer: float = 0.0
var current_stage_local: int = 1
var SCREEN_W: int = 720
var SCREEN_H: int = 960
var player_x: float = 360.0
var player_y: float = 540.0
var player_invincible: bool = false
var player_invincible_timer: float = 0.0
var player_just_hit: bool = false
var player_bombing: bool = false
var player_bomb_timer: float = 0.0
var player_bomb_radius: float = 0.0
var player_bomb_phase: int = 0
var player_bomb_wave_timer: float = 0.0
var player_bomb_config: Dictionary = {}
var player_fire_cooldown: float = 0.0
var _sfx_shoot_skip: int = 0
var player_deathbomb_primed: bool = false
var player_deathbomb_timer: float = 0.0
var MAX_BULLETS: int = 12000
var bullet_pool_hard_capacity: int = 24000
const PLAYFIELD_MARGIN := 16.0
const HUD_HEIGHT := 78.0
const GAMEPLAY_TOP := 82.0
const BULLET_POOL_GROWTH := 2048
const MAX_COMBAT_EFFECTS := 96
const SIMULATION_SNAPSHOT_VERSION := 2
const STAGE2_SIMULATION_SNAPSHOT_VERSION := 4
const REPLAY_RUNTIME_MODES := ["none", "recording", "playback"]
const STAGE2_FIELD_RECORD_LIMIT := 512
const STAGE2_FIELD_SOURCE_FIELDS := [
	"stage2_source_event_id", "stage2_source_spawn_id", "stage2_source_enemy_id",
	"stage2_primitive", "stage2_routing",
]
const STAGE2_FIELD_SEAM_FIELDS := [
	"stage2_bullet_uid", "stage2_source_event_id", "stage2_source_spawn_id",
	"stage2_source_enemy_id", "stage2_primitive", "stage2_routing",
	"stage2_reflection_count", "stage2_bullet_spawn_tick", "stage2_first_reflection_tick",
	"stage2_last_reflection_surface_id", "stage2_collision_enable_tick", "stage2_lifetime_end_tick",
]
const STAGE2_FIELD_OUTPUT_ARRAYS := [
	"warnings", "bullet_constructions", "bullet_updates", "bullet_removals",
	"source_activations", "source_removals", "state_transitions", "score_route_callbacks", "telemetry",
]
const GAME_MANAGER_STATE_FIELDS := [
	"score", "graze", "shared_power", "bullet_type", "lives", "bombs",
	"life_fragments", "bomb_fragments", "night_festival_seals", "current_stage",
	"state", "selected_protagonist_id", "selected_shot_id", "practice_mode",
	"practice_stage", "highest_reached_stage", "pause_return_state",
	"settings_return_state", "settings",
]
const GAMEPLAY_LEDGER_STATE_FIELDS := [
	"night_festival_multiplier", "highest_night_festival_multiplier",
	"spell_capture_active", "spell_capture_invalidated", "spell_capture_invalid_reason",
	"spell_capture_card_id", "spell_capture_base_value", "spell_capture_total_frames",
	"last_capture_result", "run_spell_attempts", "run_spell_captures", "continues_used",
]
const LEGACY_ENEMY_DROP_IDS := ["power", "point"]
const GRAZE_BOMB_FRAGMENT_INTERVAL := 90
const GRAZE_LIFE_FRAGMENT_INTERVAL := 300
const SHOT_NAMES_ZH := ["\u6563\u5c04", "\u8d2f\u901a", "\u8ffd\u8e2a"]
const BOSS_HP_BAR_Y_RATIO := 14.0 / 960.0
const BOSS_HP_BAR_H := 14.0
const BOSS_HP_BAR_WIDTH_RATIO := 560.0 / 720.0
const BOSS_HP_BAR_WIDTH_MIN := 320.0
const BOSS_HP_BAR_WIDTH_MAX := 680.0
const BOSS_INDICATOR_W_RATIO := 40.0 / 720.0
const BOSS_INDICATOR_H_RATIO := 10.0 / 960.0
const BOSS_INDICATOR_W_MIN := 20.0
const BOSS_INDICATOR_W_MAX := 80.0
var game_manager_ref: Object = null
var audio_manager_ref: Object = null
var performance_monitor_ref: Node = null
var _owned_fallback_game_manager: Node = null
var _owned_fallback_asset_registry: Node = null
var _runtime_shutdown_complete: bool = false
var ui_model: Object = load("res://scripts/ui/ui_model.gd").new()
var game_database_ref: Object = load("res://scripts/data/game_database.gd").new()
var game_database: Object = game_database_ref
var item_reward_system: Object = load("res://scripts/runtime/item_reward_system.gd").new()
var shot_executor: Object = load("res://scripts/player/player_shot_executor.gd").new()
var bomb_executor: Object = load("res://scripts/player/player_bomb_executor.gd").new()
var enemy_pattern_executor: Object = load("res://scripts/runtime/enemy_pattern_executor.gd").new()
var stage_director: Object = load("res://scripts/runtime/stage_director.gd").new()
var _enemy_bullet_type_ids_cache: Array = []
var _enemy_bullet_type_lookup_cache: Dictionary = {}
var _enemy_bullet_type_cache_source: Object = null
var player_last_move_dir: Vector2 = Vector2(0, -1)
var main_menu_cursor: int = 0
var character_menu_cursor: int = 0
var shot_menu_cursor: int = 0
var practice_menu_cursor: int = 0
var phase_practice_menu_cursor: int = 0
var selected_stage2_phase_practice_id := ""
var settings_menu_cursor: int = 0
var pause_menu_cursor: int = 0
var asset_registry_ref: Object = null
var asset_texture_cache: Dictionary = {}
var _stage_background_path_cache: Dictionary = {}
var _protagonist_asset_path_cache: Dictionary = {}
var _boss_asset_path_cache: Dictionary = {}
var _enemy_asset_path_cache: Dictionary = {}
var _bullet_asset_path_cache: Dictionary = {}
var _bomb_asset_path_cache: Dictionary = {}
var _item_asset_path_cache: Dictionary = {}
var _ui_asset_path_cache: Dictionary = {}

const ENEMY_BULLET_ART_BY_FAMILY := {
	"circle": "enemy_bullet_lotus_core",
	"rice": "enemy_bullet_mirror_drop",
	"butterfly": "enemy_bullet_moon_wisp",
	"needle": "enemy_bullet_ember_needle",
	"talisman": "enemy_bullet_boss_sigil",
	"star": "enemy_bullet_astral_star",
	"laser": "enemy_bullet_warning_ring",
	"large_orb": "enemy_bullet_slow_orb",
	"arrow": "enemy_bullet_fast_shard",
	"clock_gear": "enemy_bullet_clock_gear",
	"storm_arc": "enemy_bullet_storm_arc",
	"spiral_seed": "enemy_bullet_spiral_seed",
}

const PLAYER_BULLET_ART_BY_BTYPE := {
	-1: "player_bullet_bomb_seed",
	0: "player_bullet_spread_petal",
	1: "player_bullet_focus_lance",
	2: "player_bullet_homing_charm",
}

const ITEM_ART_BY_TYPE := {
	"power": "item_power_small",
	"bullet_spread": "item_power_large",
	"bullet_linear": "item_power_large",
	"bullet_homing": "item_power_large",
	"point": "item_score_small",
	"bomb_refill": "item_bomb_fragment",
	"bomb_fragment": "item_bomb_fragment",
	"life": "item_life_fragment",
	"life_fragment": "item_life_fragment",
	"night_festival_seal": "item_story_token",
	"full_power": "item_full_power",
}

const ITEM_EFFECT_MARKERS := {
	"power": {"label": "P", "color": Color(1.0, 0.30, 0.32)},
	"bullet_spread": {"label": "P", "color": Color(0.82, 0.42, 1.0)},
	"bullet_linear": {"label": "P", "color": Color(1.0, 0.34, 0.34)},
	"bullet_homing": {"label": "P", "color": Color(0.30, 1.0, 0.58)},
	"point": {"label": "点", "color": Color(0.34, 0.76, 1.0)},
	"bomb_refill": {"label": "B+", "color": Color(1.0, 0.72, 0.22)},
	"bomb_fragment": {"label": "B", "color": Color(1.0, 0.50, 0.20)},
	"life": {"label": "命+", "color": Color(1.0, 0.42, 0.66)},
	"life_fragment": {"label": "命", "color": Color(1.0, 0.54, 0.72)},
	"night_festival_seal": {"label": "印", "color": Color(0.94, 0.30, 0.38)},
	"full_power": {"label": "MAX", "color": Color(1.0, 0.86, 0.28)},
}

const BOMB_ART_PROFILE_BY_BEHAVIOR := {
	"boundary_bloom": "miko",
	"master_spark": "magician",
	"instant_slash": "swordswoman",
}

const SHOT_SFX_BY_ID := {
	"ofuda_trace": "shot_miko_ofuda",
	"yin_yang_focus": "shot_miko_orb",
	"stardust_spread": "shot_magician_stardust",
	"magic_laser": "shot_magician_laser",
	"sword_wave_fan": "shot_swordswoman_wave",
	"returning_spirit_blades": "shot_swordswoman_blade",
}

const SHOT_SELECTION_ART_BY_ID := {
	"ofuda_trace": "player_bullet_homing_charm",
	"yin_yang_focus": "player_bullet_focus_lance",
	"stardust_spread": "player_bullet_orbit_star",
	"magic_laser": "player_bullet_focus_lance",
	"sword_wave_fan": "player_bullet_spread_petal",
	"returning_spirit_blades": "player_bullet_bomb_seed",
}

func _resolve_singletons() -> void:
	var tree_root: Window = get_tree().root if is_inside_tree() and get_tree() else null
	var sibling_root: Node = get_parent() if is_inside_tree() else null
	var root_game_manager: Object = sibling_root.get_node_or_null("GameManager") if sibling_root else null
	if not root_game_manager and tree_root:
		root_game_manager = tree_root.get_node_or_null("GameManager")
	if root_game_manager:
		if is_instance_valid(_owned_fallback_game_manager) and _owned_fallback_game_manager != root_game_manager:
			_release_owned_fallback(_owned_fallback_game_manager)
			_owned_fallback_game_manager = null
		game_manager_ref = root_game_manager
	elif not game_manager_ref:
		game_manager_ref = load("res://autoload/game_manager.gd").new()
		_owned_fallback_game_manager = game_manager_ref

	var root_audio_manager: Object = sibling_root.get_node_or_null("AudioManager") if sibling_root else null
	if not root_audio_manager and tree_root:
		root_audio_manager = tree_root.get_node_or_null("AudioManager")
	if root_audio_manager:
		audio_manager_ref = root_audio_manager
	elif not audio_manager_ref and not is_inside_tree():
		audio_manager_ref = null

	var root_monitor: Node = sibling_root.get_node_or_null("PerformanceMonitor") if sibling_root else null
	if not root_monitor and tree_root:
		root_monitor = tree_root.get_node_or_null("PerformanceMonitor")
	if root_monitor:
		performance_monitor_ref = root_monitor

	var root_asset_registry: Object = sibling_root.get_node_or_null("AssetRegistry") if sibling_root else null
	if not root_asset_registry and tree_root:
		root_asset_registry = tree_root.get_node_or_null("AssetRegistry")
	if root_asset_registry:
		if is_instance_valid(_owned_fallback_asset_registry) and _owned_fallback_asset_registry != root_asset_registry:
			_release_owned_fallback(_owned_fallback_asset_registry)
			_owned_fallback_asset_registry = null
		if asset_registry_ref != root_asset_registry:
			asset_registry_ref = root_asset_registry
			_clear_asset_path_caches()
	elif not asset_registry_ref:
		asset_registry_ref = load("res://autoload/asset_registry.gd").new()
		_owned_fallback_asset_registry = asset_registry_ref
		_clear_asset_path_caches()

func _release_owned_fallback(owner: Node) -> void:
	if not is_instance_valid(owner):
		return
	if owner.has_method("shutdown_runtime"):
		owner.shutdown_runtime()
	owner.free()

func shutdown_runtime() -> void:
	if _runtime_shutdown_complete:
		return
	_runtime_shutdown_complete = true

	asset_texture_cache.clear()
	_clear_asset_path_caches()
	_enemy_bullet_type_ids_cache.clear()
	_enemy_bullet_type_lookup_cache.clear()
	bullet_pool.clear()
	active_bullet_indices.clear()
	enemies.clear()
	items.clear()
	combat_effects.clear()
	boss.clear()
	stage_controller.clear()
	current_tick_input.clear()
	replay_identity.clear()
	player_bomb_config.clear()

	if bullet_world:
		bullet_world.reset()
	if item_reward_system and item_reward_system.has_method("shutdown_runtime"):
		item_reward_system.shutdown_runtime()

	# A null public reference means a standalone shell explicitly transferred
	# fallback ownership to its caller for manual cleanup. Otherwise Main still
	# owns the fallback, even if a test replaced the public reference.
	if is_instance_valid(_owned_fallback_game_manager) and game_manager_ref != null:
		_release_owned_fallback(_owned_fallback_game_manager)
	if is_instance_valid(_owned_fallback_asset_registry) and asset_registry_ref != null:
		_release_owned_fallback(_owned_fallback_asset_registry)
	_owned_fallback_game_manager = null
	_owned_fallback_asset_registry = null

	game_manager_ref = null
	audio_manager_ref = null
	performance_monitor_ref = null
	asset_registry_ref = null
	_enemy_bullet_type_cache_source = null
	game_database = null
	game_database_ref = null
	ui_model = null
	item_reward_system = null
	shot_executor = null
	bomb_executor = null
	enemy_pattern_executor = null
	stage_director = null
	stage2_encounter_controller = null
	stage2_field_topology_runtime = null
	fixed_tick_clock = null
	gameplay_rng = null
	simulation_state_hasher = null
	bullet_world = null
	boss_state_machine = null
	gameplay_input_buffer = null
	replay_data = null

func _exit_tree() -> void:
	shutdown_runtime()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		shutdown_runtime()

func _menu_vertical_delta() -> int:
	var delta: int = 0
	if Input.is_action_just_pressed("move_up"):
		delta -= 1
	if Input.is_action_just_pressed("move_down"):
		delta += 1
	return delta

func _menu_horizontal_delta() -> int:
	var delta: int = 0
	if Input.is_action_just_pressed("move_left"):
		delta -= 1
	if Input.is_action_just_pressed("move_right"):
		delta += 1
	return delta

func _menu_confirm_pressed() -> bool:
	var pressed := Input.is_action_just_pressed("shoot")
	if pressed and audio_manager_ref:
		audio_manager_ref.play_sfx("menu_confirm")
	return pressed

func _menu_cancel_pressed() -> bool:
	var pressed := Input.is_action_just_pressed("bomb") or Input.is_action_just_pressed("pause")
	if pressed and audio_manager_ref:
		audio_manager_ref.play_sfx("menu_back")
	return pressed

func _set_ui_state(next_state: String) -> void:
	_resolve_singletons()
	if game_manager_ref:
		game_manager_ref.state = next_state
	_sync_canvas_origin(next_state)

func _open_settings(return_state: String) -> void:
	_resolve_singletons()
	if game_manager_ref:
		game_manager_ref.open_settings(return_state)

func _settings_dictionary() -> Dictionary:
	if game_manager_ref:
		var settings_value = game_manager_ref.get("settings")
		if settings_value is Dictionary:
			return settings_value
	return {}

func _settings_float(id: String, fallback: float) -> float:
	return float(_settings_dictionary().get(id, fallback))

func _settings_bool(id: String, fallback: bool) -> bool:
	return bool(_settings_dictionary().get(id, fallback))

func _apply_runtime_settings(settings_override: Dictionary = {}) -> void:
	_resolve_singletons()
	var runtime_settings: Dictionary = settings_override if not settings_override.is_empty() else _settings_dictionary()
	if audio_manager_ref and audio_manager_ref.has_method("apply_settings"):
		audio_manager_ref.apply_settings(runtime_settings)
	_apply_fullscreen_setting(bool(runtime_settings.get("fullscreen", false)))

func _desired_window_mode(fullscreen: bool, current_mode: int) -> int:
	if fullscreen:
		return DisplayServer.WINDOW_MODE_FULLSCREEN
	if current_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		return DisplayServer.WINDOW_MODE_WINDOWED
	return current_mode

func _apply_fullscreen_setting(fullscreen: bool) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var current_mode := DisplayServer.window_get_mode()
	var target_mode := _desired_window_mode(fullscreen, current_mode)
	if current_mode != target_mode:
		DisplayServer.window_set_mode(target_mode)
	return true

func _set_pause_audio(ducked: bool) -> void:
	_resolve_singletons()
	if audio_manager_ref and audio_manager_ref.has_method("set_pause_ducked"):
		audio_manager_ref.set_pause_ducked(ducked)

func _pause_gameplay(from_state: String) -> void:
	_resolve_singletons()
	if game_manager_ref:
		game_manager_ref.enter_pause(from_state)
	_sync_canvas_origin("paused")
	if audio_manager_ref:
		audio_manager_ref.play_sfx("pause")
	_set_pause_audio(true)

func _resume_gameplay() -> void:
	_resolve_singletons()
	if game_manager_ref:
		game_manager_ref.resume_from_pause()
	_sync_canvas_origin(String(game_manager_ref.state if game_manager_ref else "stage"))
	_set_pause_audio(false)

func _bullet_draw_color(base: Color, alpha_override: float = -1.0) -> Color:
	var brightness: float = clampf(_settings_float("bullet_brightness", 1.0), 0.5, 1.5)
	var alpha: float = base.a if alpha_override < 0.0 else alpha_override
	var adjusted := Color(base.r, base.g, base.b, alpha)
	if brightness < 1.0:
		adjusted = Color(base.r * brightness, base.g * brightness, base.b * brightness, alpha)
	elif brightness > 1.0:
		var lighten_amount: float = brightness - 1.0
		adjusted = Color(base.r, base.g, base.b, alpha).lerp(Color(1.0, 1.0, 1.0, alpha), lighten_amount)
	return Color(clampf(adjusted.r, 0.0, 1.0), clampf(adjusted.g, 0.0, 1.0), clampf(adjusted.b, 0.0, 1.0), alpha)

func get_asset_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if asset_texture_cache.has(path):
		return asset_texture_cache[path]
	var resource_exists := ResourceLoader.exists(path)
	var file_exists := FileAccess.file_exists(path)
	if not resource_exists and not file_exists:
		asset_texture_cache[path] = null
		return null
	if resource_exists:
		var loaded := load(path)
		if loaded is Texture2D:
			asset_texture_cache[path] = loaded
			return asset_texture_cache[path]
	var image := Image.new()
	if image.load(path) == OK:
		asset_texture_cache[path] = ImageTexture.create_from_image(image)
		return asset_texture_cache[path]
	asset_texture_cache[path] = null
	return asset_texture_cache[path]

func _asset_registry() -> Object:
	if not asset_registry_ref:
		_resolve_singletons()
	return asset_registry_ref

func _clear_asset_path_caches() -> void:
	_stage_background_path_cache.clear()
	_protagonist_asset_path_cache.clear()
	_boss_asset_path_cache.clear()
	_enemy_asset_path_cache.clear()
	_bullet_asset_path_cache.clear()
	_bomb_asset_path_cache.clear()
	_item_asset_path_cache.clear()
	_ui_asset_path_cache.clear()

func _draw_texture_rect_path(path: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var texture := get_asset_texture(path)
	if texture == null:
		return false
	draw_texture_rect(texture, rect, false, modulate)
	return true

func _draw_portrait_icon(path: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var texture := get_asset_texture(path)
	if texture == null:
		return false
	var texture_size := texture.get_size()
	var source_height := texture_size.y * 0.66
	var source_width := minf(texture_size.x, source_height * rect.size.x / rect.size.y)
	var source_rect := Rect2((texture_size.x - source_width) * 0.5, 0.0, source_width, source_height)
	draw_texture_rect_region(texture, rect, source_rect, modulate)
	return true

func _draw_texture_centered(path: String, center: Vector2, size: Vector2, modulate: Color = Color.WHITE, rotation: float = 0.0) -> bool:
	var texture := get_asset_texture(path)
	if texture == null:
		return false
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(size * -0.5, size), false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _full_screen_rect() -> Rect2:
	return Rect2(0, 0, SCREEN_W, SCREEN_H)

func _display_rect() -> Rect2:
	return Rect2(0, 0, SCREEN_W, SCREEN_H + HUD_HEIGHT)

func _stage_background_paths(stage_id: int) -> Dictionary:
	if _stage_background_path_cache.has(stage_id):
		return _stage_background_path_cache[stage_id]
	var registry := _asset_registry()
	if registry and registry.has_method("stage_background_layers"):
		_stage_background_path_cache[stage_id] = registry.stage_background_layers(stage_id)
	else:
		_stage_background_path_cache[stage_id] = {}
	return _stage_background_path_cache[stage_id]

func _bullet_asset_path(asset_id: String) -> String:
	if _bullet_asset_path_cache.is_empty():
		var registry := _asset_registry()
		if registry and registry.has_method("bullet_family_assets"):
			_bullet_asset_path_cache = registry.bullet_family_assets()
	if _bullet_asset_path_cache.has(asset_id):
		return String(_bullet_asset_path_cache[asset_id])
	return ""

func _enemy_asset_path(asset_id: String) -> String:
	if _enemy_asset_path_cache.is_empty():
		var registry := _asset_registry()
		if registry and registry.has_method("enemy_family_assets"):
			_enemy_asset_path_cache = registry.enemy_family_assets()
	if _enemy_asset_path_cache.has(asset_id):
		return String(_enemy_asset_path_cache[asset_id])
	return ""

func _item_asset_path(asset_id: String) -> String:
	if _item_asset_path_cache.is_empty():
		var registry := _asset_registry()
		if registry and registry.has_method("item_assets"):
			_item_asset_path_cache = registry.item_assets()
	if _item_asset_path_cache.has(asset_id):
		return String(_item_asset_path_cache[asset_id])
	return ""

func _ui_asset_path(asset_id: String) -> String:
	if _ui_asset_path_cache.is_empty():
		var registry := _asset_registry()
		if registry and registry.has_method("ui_assets"):
			_ui_asset_path_cache = registry.ui_assets()
	if _ui_asset_path_cache.has(asset_id):
		return String(_ui_asset_path_cache[asset_id])
	return ""

func _bomb_asset_group(profile_id: String) -> Dictionary:
	if _bomb_asset_path_cache.is_empty():
		var registry := _asset_registry()
		if registry and registry.has_method("bomb_assets"):
			_bomb_asset_path_cache = registry.bomb_assets()
	if _bomb_asset_path_cache.has(profile_id):
		return _bomb_asset_path_cache[profile_id]
	return {}

func _protagonist_asset_paths(id: String) -> Dictionary:
	if not _protagonist_asset_path_cache.has(id):
		var registry := _asset_registry()
		if registry and registry.has_method("protagonist_assets"):
			_protagonist_asset_path_cache[id] = registry.protagonist_assets(id)
		else:
			_protagonist_asset_path_cache[id] = {}
	return _protagonist_asset_path_cache[id]

func _boss_asset_paths(id: String) -> Dictionary:
	if not _boss_asset_path_cache.has(id):
		var registry := _asset_registry()
		if registry and registry.has_method("boss_assets"):
			_boss_asset_path_cache[id] = registry.boss_assets(id)
		else:
			_boss_asset_path_cache[id] = {}
	return _boss_asset_path_cache[id]

func _phase6_protagonist_sprite_path() -> String:
	var registry := _asset_registry()
	if not registry or not registry.has_method("protagonist_assets") or not game_manager_ref:
		return ""
	var assets: Dictionary = _protagonist_asset_paths(String(game_manager_ref.selected_protagonist_id))
	return String(assets.get("sprite", ""))

func _current_boss_asset_id() -> String:
	if boss.has("cards") and boss.cards is Array and not boss.cards.is_empty():
		var card_idx: int = clampi(int(boss.get("card_idx", 0)), 0, boss.cards.size() - 1)
		return String(boss.cards[card_idx].get("boss_id", ""))
	var boss_def: Dictionary = stage_director.boss_definition(_active_stage())
	return String(boss_def.get("id", ""))

func _current_boss_assets() -> Dictionary:
	return _boss_asset_paths(_current_boss_asset_id())

func _draw_phase6_stage_background(spell_state: bool) -> void:
	_draw_phase6_stage_background_rect(spell_state, _full_screen_rect())

func _draw_phase6_stage_background_rect(spell_state: bool, target_rect: Rect2) -> void:
	var layers: Dictionary = _stage_background_paths(_active_stage())
	var drew_any := false
	drew_any = _draw_texture_rect_path(String(layers.get("far", "")), target_rect, Color(1, 1, 1, 1.0)) or drew_any
	drew_any = _draw_texture_rect_path(String(layers.get("mid", "")), target_rect, Color(1, 1, 1, 0.82)) or drew_any
	if spell_state:
		drew_any = _draw_texture_rect_path(String(layers.get("spell", "")), target_rect, Color(1, 1, 1, 0.36)) or drew_any
	drew_any = _draw_texture_rect_path(String(layers.get("near", "")), target_rect, Color(1, 1, 1, 0.24)) or drew_any
	if not drew_any:
		draw_rect(target_rect, Color(0.02, 0.03, 0.06))

func _draw_phase6_boss_aura() -> void:
	if not boss_alive or not boss.has("phase") or boss.get("phase", "") == "defeated":
		return
	if float(boss.get("y", -60.0)) < 96.0:
		return
	var aura_path := String(_current_boss_assets().get("spell_aura", ""))
	var aura_size := Vector2.ONE * (250.0 if bool(boss.get("declaring", false)) else 190.0)
	_draw_texture_centered(aura_path, Vector2(float(boss.get("x", _screen_center_x())), float(boss.get("y", _boss_anchor_y()))), aura_size, Color(1, 1, 1, 0.34))

func _draw_phase6_bomb_plate() -> void:
	if not player_bombing or player_bomb_config.is_empty():
		return
	var behavior_id := String(player_bomb_config.get("behavior_id", "boundary_bloom"))
	var profile_id := String(BOMB_ART_PROFILE_BY_BEHAVIOR.get(behavior_id, "miko"))
	var total_frames: float = maxf(1.0, float(player_bomb_config.get("duration", 120)))
	var remaining_frames: float = maxf(0.0, player_bomb_timer * 60.0)
	var elapsed_ratio: float = clampf((total_frames - remaining_frames) / total_frames, 0.0, 1.0)
	var envelope := pow(sin(PI * elapsed_ratio), 0.62)
	var protagonist_assets := _protagonist_asset_paths(profile_id)
	var focus_path := String(protagonist_assets.get("focus_effects", ""))
	var origin := Vector2(player_x, player_y)
	match behavior_id:
		"master_spark":
			var direction: Vector2 = player_bomb_config.get("direction", Vector2(0, -1)).normalized()
			var side := direction.orthogonal()
			var beam_end := origin + direction * SCREEN_H * 1.15
			var beam_width := 72.0 + sin(elapsed_ratio * PI * 10.0) * 8.0
			var beam := PackedVector2Array([origin - side * beam_width, origin + side * beam_width, beam_end + side * beam_width * 0.48, beam_end - side * beam_width * 0.48])
			draw_colored_polygon(beam, Color(0.42, 0.76, 1.0, 0.13 * envelope))
			draw_polyline(PackedVector2Array([origin - side * beam_width, beam_end - side * beam_width * 0.48]), Color(0.82, 0.96, 1.0, 0.64 * envelope), 4.0)
			draw_polyline(PackedVector2Array([origin + side * beam_width, beam_end + side * beam_width * 0.48]), Color(0.70, 0.46, 1.0, 0.54 * envelope), 4.0)
			_draw_texture_centered(focus_path, origin, Vector2.ONE * (260.0 + 60.0 * envelope), Color(1, 1, 1, 0.82 * envelope), elapsed_ratio * 2.8)
		"instant_slash":
			var direction: Vector2 = player_bomb_config.get("direction", Vector2(0, -1)).normalized()
			_draw_texture_centered(focus_path, origin, Vector2.ONE * (330.0 + 190.0 * envelope), Color(1, 1, 1, 0.72 * envelope), -elapsed_ratio * 5.2)
			for i in range(7):
				var angle := direction.angle() + (float(i) - 3.0) * 0.18 + sin(elapsed_ratio * 12.0 + i) * 0.08
				var slash_dir := Vector2(cos(angle), sin(angle))
				var start := origin - slash_dir * 55.0 + slash_dir.orthogonal() * (float(i) - 3.0) * 24.0
				var finish := start + slash_dir * 690.0
				draw_line(start, finish, Color(0.70, 0.92, 1.0, 0.38 * envelope), 8.0 - float(i % 3))
				draw_line(start, finish, Color(1.0, 1.0, 1.0, 0.66 * envelope), 2.0)
		_:
			var outer_size := lerpf(220.0, SCREEN_W * 1.25, smoothstep(0.0, 0.78, elapsed_ratio))
			_draw_texture_centered(focus_path, origin, Vector2.ONE * outer_size, Color(1, 1, 1, 0.68 * envelope), elapsed_ratio * 3.4)
			_draw_texture_centered(focus_path, origin, Vector2.ONE * outer_size * 0.64, Color(1.0, 0.82, 0.68, 0.46 * envelope), -elapsed_ratio * 4.6)
			draw_circle(origin, player_bomb_radius, Color(0.96, 0.72, 1.0, 0.42 * envelope), false, 5.0)

func _draw_phase6_item_sprite(item: Dictionary, center: Vector2) -> bool:
	var type_id := String(item.get("type", ""))
	var asset_id := String(ITEM_ART_BY_TYPE.get(type_id, "item_score_small"))
	var size := Vector2.ONE * (38.0 if type_id in ["full_power", "bomb_refill", "life"] else 34.0)
	return _draw_texture_centered(_item_asset_path(asset_id), center, size)

func _item_effect_marker(type_id: String) -> Dictionary:
	return ITEM_EFFECT_MARKERS.get(type_id, {"label": "?", "color": Color.WHITE})

func _draw_item_effect_marker(font: Font, type_id: String, center: Vector2) -> void:
	var marker := _item_effect_marker(type_id)
	var label := String(marker.label)
	var font_size := 11 if label.length() > 1 else 13
	var width := maxf(18.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 7.0)
	var badge := Rect2(center.x - width * 0.5, center.y - 8.0, width, 16.0)
	draw_rect(badge, Color(0.015, 0.018, 0.03, 0.72))
	draw_rect(badge, marker.color, false, 1.5)
	draw_string(font, Vector2(badge.position.x, badge.position.y + 12.5), label, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color.WHITE)

func _draw_phase6_enemy_sprite(enemy: Dictionary, center: Vector2) -> bool:
	var family_id := String(enemy.get("family_id", "low_yokai"))
	var asset_id := "enemy_%s" % family_id
	var draw_size: float = clampf(float(enemy.get("radius", 14.0)) * 3.8, 42.0, 82.0)
	return _draw_texture_centered(_enemy_asset_path(asset_id), center, Vector2.ONE * draw_size)

func _draw_phase6_bullet_sprite(bullet: Dictionary) -> bool:
	var asset_id := ""
	var type_id := String(bullet.get("type", ""))
	if type_id == "player":
		asset_id = String(PLAYER_BULLET_ART_BY_BTYPE.get(int(bullet.get("btype", 0)), "player_bullet_spread_petal"))
	elif type_id == "bomb":
		asset_id = "player_bullet_bomb_seed"
		if int(bullet.get("btype", -1)) == 0:
			asset_id = "player_bullet_graze_spark"
		elif int(bullet.get("btype", -1)) == 1:
			asset_id = "player_bullet_focus_lance"
	else:
		asset_id = String(ENEMY_BULLET_ART_BY_FAMILY.get(type_id, "enemy_bullet_lotus_core"))
	var radius: float = float(bullet.get("radius", 5.0))
	var max_size := 64.0 if type_id == "bomb" else 48.0
	var draw_size := Vector2.ONE * clampf(radius * 4.6, 17.0, max_size)
	var velocity := Vector2(float(bullet.get("vx", 0.0)), float(bullet.get("vy", -1.0)))
	var rotation := velocity.angle() + PI * 0.5 if velocity.length_squared() > 0.0 else 0.0
	return _draw_texture_centered(_bullet_asset_path(asset_id), Vector2(float(bullet.get("x", 0.0)), float(bullet.get("y", 0.0))), draw_size, _bullet_draw_color(Color.WHITE), rotation)

func _draw_phase6_boss_sprite(center: Vector2) -> bool:
	var sprite_path := String(_current_boss_assets().get("sprite", ""))
	var draw_size := Vector2.ONE * clampf(float(boss.get("radius", 28.0)) * 3.8, 86.0, 128.0)
	var alpha := 0.72 if boss.get("phase", "") == "entering" else 0.94
	var tint := Color(1, 1, 1, alpha) if float(boss.get("flash", 0.0)) <= 0.0 else Color(1, 1, 1, 1.0)
	return _draw_texture_centered(sprite_path, center, draw_size, tint)

func _draw_phase6_player_sprite(center: Vector2) -> bool:
	var sprite_path := _phase6_protagonist_sprite_path()
	return _draw_texture_centered(sprite_path, center + Vector2(0, -7), Vector2(62, 62), Color(1, 1, 1, 0.96))

func _draw_phase6_ui_fullscreen(asset_id: String, alpha: float = 1.0) -> bool:
	return _draw_texture_rect_path(_ui_asset_path(asset_id), _full_screen_rect(), Color(1, 1, 1, alpha))

func _draw_phase6_ui_window(asset_id: String, alpha: float = 1.0) -> bool:
	return _draw_texture_rect_path(_ui_asset_path(asset_id), _display_rect(), Color(1, 1, 1, alpha))

func _draw_phase6_spell_banner(font: Font) -> void:
	if not boss_alive or not bool(boss.get("declaring", false)):
		return
	var banner_rect := Rect2(0, 0, SCREEN_W, minf(150.0, SCREEN_H * 0.18))
	_draw_texture_rect_path(_ui_asset_path("spell_banner"), banner_rect, Color(1, 1, 1, 0.86))
	var card_name := String(boss.get("card_name", ""))
	if not card_name.is_empty():
		draw_string(font, Vector2(_centered_text_x_at_size(font, card_name, 22), banner_rect.position.y + 82.0), card_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(1.0, 0.94, 0.78))

func _current_boss_card() -> Dictionary:
	if not boss.has("cards") or not boss.cards is Array or boss.cards.is_empty():
		return {}
	return boss.cards[clampi(int(boss.get("card_idx", 0)), 0, boss.cards.size() - 1)]

func _boss_timer_seconds() -> int:
	return maxi(0, int(ceil(float(boss.get("card_timer", 0.0)) / 60.0)))

func _draw_boss_status(font: Font) -> void:
	if not boss_alive or boss.get("phase", "") == "defeated":
		return
	var card := _current_boss_card()
	var kind := String(card.get("kind", "spell"))
	var kind_label := "非符" if kind == "nonspell" else "符卡"
	var timer_seconds := _boss_timer_seconds()
	var timer_color := Color(1.0, 0.34, 0.30) if timer_seconds <= 5 else Color(1.0, 0.9, 0.5)
	var label := "%s  %s" % [kind_label, String(boss.get("card_name", ""))]
	var y := _boss_hp_bar_rect().end.y + 20.0
	draw_string(font, Vector2(18.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, SCREEN_W - 100.0, 16, Color(0.96, 0.94, 0.90))
	draw_string(font, Vector2(SCREEN_W - 64.0, y), "%02d" % timer_seconds, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, timer_color)

func _draw_gameplay_hud(font: Font, gm: Object) -> void:
	var hud_origin_y := -HUD_HEIGHT
	draw_string(font, Vector2(12, hud_origin_y + 24), "SCORE  %09d" % gm.score, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(1.0, 0.88, 0.42))
	draw_string(font, Vector2(250, hud_origin_y + 24), "GRAZE  %05d" % gm.graze, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.46, 0.90, 1.0))
	draw_string(font, Vector2(12, hud_origin_y + 55), "POWER  %02d/50  Lv.%d  %s" % [gm.shared_power, gm.power_level(), _gameplay_shot_label()], HORIZONTAL_ALIGNMENT_LEFT, 400.0, 15, Color(0.82, 0.62, 1.0))
	var life_text := "残机  %s  [%d/5]" % ["♥".repeat(gm.lives), gm.life_fragments]
	var bomb_text := "炸弹  %s  [%d/3]" % ["◆".repeat(gm.bombs), gm.bomb_fragments]
	draw_string(font, Vector2(430, hud_origin_y + 24), life_text, HORIZONTAL_ALIGNMENT_LEFT, SCREEN_W - 440.0, 16, Color(1.0, 0.48, 0.62))
	draw_string(font, Vector2(430, hud_origin_y + 55), bomb_text, HORIZONTAL_ALIGNMENT_LEFT, SCREEN_W - 440.0, 16, Color(1.0, 0.72, 0.25))

func _draw_gameplay_hud_background() -> void:
	draw_rect(Rect2(0, -HUD_HEIGHT, SCREEN_W, HUD_HEIGHT), Color(0.025, 0.03, 0.055, 0.94))
	draw_line(Vector2(0, 0), Vector2(SCREEN_W, 0), Color(0.82, 0.64, 0.34, 0.68), 1.5)

func _should_show_focus_hitbox() -> bool:
	return not player_bombing and (_settings_bool("always_show_focus_hitbox", false) or _focus_held())

func _focus_held() -> bool:
	return bool(current_tick_input.get("focus", gameplay_input_buffer.held_focus))

func _item_magnetize_requested(focus_held: bool) -> bool:
	var top_collection_line := SCREEN_H * float(game_manager_ref.ITEM_TOP_RATIO if game_manager_ref else 0.2)
	return focus_held and player_y <= top_collection_line

func _player_hitbox_radius() -> float:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_hitbox_radius"):
		return float(game_manager_ref.selected_hitbox_radius())
	if game_manager_ref:
		return float(game_manager_ref.PLAYER_HITBOX)
	return 2.0

func _player_graze_radius() -> float:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_graze_radius"):
		return float(game_manager_ref.selected_graze_radius())
	if game_manager_ref:
		return float(game_manager_ref.PLAYER_GRAZE)
	return 10.0

func _boss_collision_radius() -> float:
	return maxf(45.0, float(boss.get("radius", 28.0)) * 1.6)

func _spawn_combat_effect(kind: String, position: Vector2, radius: float, color: Color) -> void:
	if combat_effects.size() >= MAX_COMBAT_EFFECTS:
		combat_effects.pop_front()
	combat_effects.append({
		"kind": kind, "position": position, "radius": radius, "color": color,
		"age": 0.0, "duration": 46.0 if kind == "enemy_defeat" else 92.0,
		"seed": int(position.x * 17.0 + position.y * 31.0 + simulation_tick_index * 13 + combat_effects.size()) & 1023,
	})

func _update_combat_effects(delta: float) -> void:
	for effect in combat_effects:
		effect.age = float(effect.age) + delta * 60.0
	for i in range(combat_effects.size() - 1, -1, -1):
		if float(combat_effects[i].age) >= float(combat_effects[i].duration):
			combat_effects.remove_at(i)

func _draw_combat_effects() -> void:
	for effect in combat_effects:
		var center: Vector2 = effect.position
		var progress := clampf(float(effect.age) / maxf(1.0, float(effect.duration)), 0.0, 1.0)
		var fade := 1.0 - progress
		var base_radius := float(effect.radius)
		var color: Color = effect.color
		var ring_radius := base_radius * (0.55 + progress * 2.8)
		draw_circle(center, ring_radius, Color(color.r, color.g, color.b, fade * 0.62), false, 3.0 + fade * 3.0)
		draw_circle(center, ring_radius * 0.55, Color(1.0, 0.92, 0.66, fade * 0.34), false, 2.0)
		var shard_count := 10 if String(effect.kind) == "enemy_defeat" else 22
		for i in range(shard_count):
			var angle := TAU * float(i) / float(shard_count) + float(int(effect.seed) % 37) * 0.031
			var distance := base_radius * (0.45 + progress * (2.0 + float(i % 4) * 0.22))
			var tangent := Vector2(cos(angle), sin(angle))
			var p1 := center + tangent * distance
			var p2 := p1 + tangent * (5.0 + base_radius * 0.22) * fade
			draw_line(p1, p2, Color(color.r, color.g, color.b, fade * 0.9), 1.5 + float(i % 3))

func _should_show_performance_hud() -> bool:
	return _settings_bool("show_performance_hud", false)

func _should_show_input_guide() -> bool:
	return _settings_bool("show_input_guide", true)

func _move_menu_cursor(cursor: int, delta: int, count: int) -> int:
	if delta == 0:
		return cursor
	var next_cursor: int = ui_model.move_cursor(cursor, delta, count)
	if next_cursor != cursor and audio_manager_ref:
		audio_manager_ref.play_sfx("menu_move")
	return next_cursor

func _entry_index_by_id(entries: Array, id: String) -> int:
	for i in range(entries.size()):
		if String(entries[i].get("id", "")) == id:
			return i
	return 0

func _entry_label_by_id(entries: Array, id: String) -> String:
	for entry in entries:
		if String(entry.get("id", "")) == id:
			return String(entry.get("label", ""))
	return ""

func _bullet_type_for_shot_id(shot_id: String) -> int:
	_resolve_singletons()
	var db = load("res://scripts/data/game_database.gd").new()
	var shot_profile: Dictionary = db.shot_profile_by_id(shot_id)
	if shot_profile.is_empty():
		return game_manager_ref.BulletType.SPREAD if game_manager_ref else 0
	return shot_executor.bullet_type_for_shot(shot_profile, game_manager_ref)

func _selected_shot_profile() -> Dictionary:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_shot_profile"):
		return game_manager_ref.selected_shot_profile()
	return {}

func _selected_bomb_profile() -> Dictionary:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.has_method("selected_bomb_profile"):
		return game_manager_ref.selected_bomb_profile()
	return {}

func _bomb_sfx_prefix() -> String:
	_resolve_singletons()
	var protagonist_id := String(game_manager_ref.selected_protagonist_id) if game_manager_ref else "miko"
	return "bomb_%s" % protagonist_id

func _stop_bomb_sfx() -> void:
	if not audio_manager_ref:
		return
	for protagonist_id in ["miko", "magician", "swordswoman"]:
		audio_manager_ref.stop_sfx("bomb_%s_loop" % protagonist_id)

func _enemy_bullet_types() -> Array:
	if _enemy_bullet_type_cache_source != game_database_ref or _enemy_bullet_type_ids_cache.is_empty():
		_rebuild_enemy_bullet_type_cache()
	return _enemy_bullet_type_ids_cache.duplicate()

func _rebuild_enemy_bullet_type_cache() -> void:
	var ids: Array = ["arrow"]
	var lookup := {"arrow": true}
	if game_database_ref:
		for family in game_database_ref.bullet_families():
			var family_id := String(family.get("id", ""))
			if family_id != "" and not ids.has(family_id):
				ids.append(family_id)
				lookup[family_id] = true
	_enemy_bullet_type_ids_cache = ids
	_enemy_bullet_type_lookup_cache = lookup
	_enemy_bullet_type_cache_source = game_database_ref

func _enemy_bullet_type_ids() -> Array:
	return _enemy_bullet_types()

func _is_enemy_bullet_type(type_id: String) -> bool:
	if _enemy_bullet_type_cache_source != game_database_ref or _enemy_bullet_type_lookup_cache.is_empty():
		_rebuild_enemy_bullet_type_cache()
	return _enemy_bullet_type_lookup_cache.has(type_id)

func _score_value(rule_id: String, fallback: int) -> int:
	if game_database_ref:
		return int(game_database_ref.scoring_rules().get(rule_id, fallback))
	return fallback

func _gameplay_shot_label() -> String:
	var shot := _selected_shot_profile()
	var fallback: String = SHOT_NAMES_ZH[game_manager_ref.bullet_type] if game_manager_ref else ""
	return String(shot.get("hud_name", shot.get("display_name", fallback)))

func _gameplay_protagonist_label() -> String:
	if game_manager_ref and game_manager_ref.has_method("protagonist_profile"):
		return String(game_manager_ref.protagonist_profile().get("display_name", ""))
	return ""

func _gameplay_bomb_label() -> String:
	var bomb := _selected_bomb_profile()
	return String(bomb.get("hud_name", bomb.get("display_name", "")))

func _gameplay_loadout_hud_rect() -> Rect2:
	return Rect2(10.0, 50.0, 360.0, 22.0)

func _performance_hud_rect() -> Rect2:
	return Rect2(8.0, 84.0, 152.0, 64.0)

func _spawn_player_bullet_spec(spec: Dictionary) -> void:
	_spawn_bullet_player(
		float(spec.position.x),
		float(spec.position.y),
		float(spec.velocity.x),
		float(spec.velocity.y),
		float(spec.radius),
		spec.color,
		float(spec.damage),
		bool(spec.homing),
		int(spec.btype),
		bool(spec.get("persist", false)),
		float(spec.lifetime),
		spec.get("behavior", {})
	)

func _shot_executor_fire_pattern(shot_profile: Dictionary, level: int, focused: bool, origin: Vector2) -> Array:
	if _uses_m0_legacy_gameplay() and shot_executor.has_method("fire_pattern_legacy"):
		return shot_executor.fire_pattern_legacy(shot_profile, level, focused, origin)
	return shot_executor.fire_pattern(shot_profile, level, focused, origin)

func _uses_m0_legacy_gameplay() -> bool:
	return String(replay_identity.get("content_hash", "")) == "m0-baseline-content-v1"

func _sync_character_cursor_to_selected() -> void:
	if not game_manager_ref:
		return
	var entries: Array = ui_model.protagonist_entries()
	character_menu_cursor = _entry_index_by_id(entries, String(game_manager_ref.selected_protagonist_id))

func _sync_shot_cursor_to_selected() -> void:
	if not game_manager_ref:
		return
	var entries: Array = ui_model.shot_entries(String(game_manager_ref.selected_protagonist_id))
	shot_menu_cursor = _entry_index_by_id(entries, String(game_manager_ref.selected_shot_id))

func _quit_runtime_safe(quit_target: Object = null) -> void:
	var target := quit_target
	if not target:
		if not is_inside_tree():
			return
		if DisplayServer.get_name() == "headless":
			return
		target = get_tree()
	target.call("quit")

func _screen_center_x() -> float:
	return SCREEN_W * 0.5

func _boss_anchor_y() -> float:
	return SCREEN_H * (130.0 / 960.0)

func _centered_text_x(font: Font, text: String) -> float:
	return maxf(0.0, (SCREEN_W - font.get_string_size(text).x) * 0.5)

func _centered_text_x_at_size(font: Font, text: String, font_size: int) -> float:
	return maxf(0.0, (SCREEN_W - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) * 0.5)

func _summary_box_rect() -> Rect2:
	var box_width: float = minf(320.0, SCREEN_W - 80.0)
	return Rect2((SCREEN_W - box_width) * 0.5, SCREEN_H * (180.0 / 960.0), box_width, 220.0)

func _boss_hp_bar_rect() -> Rect2:
	var bar_width: float = clampf(SCREEN_W * BOSS_HP_BAR_WIDTH_RATIO, BOSS_HP_BAR_WIDTH_MIN, BOSS_HP_BAR_WIDTH_MAX)
	return Rect2((SCREEN_W - bar_width) * 0.5, SCREEN_H * BOSS_HP_BAR_Y_RATIO, bar_width, BOSS_HP_BAR_H)

func _boss_indicator_width() -> float:
	return clampf(SCREEN_W * BOSS_INDICATOR_W_RATIO, BOSS_INDICATOR_W_MIN, BOSS_INDICATOR_W_MAX)

func _boss_indicator_rect() -> Rect2:
	var indicator_w: float = _boss_indicator_width()
	var indicator_h: float = SCREEN_H * BOSS_INDICATOR_H_RATIO
	var indicator_y: float = SCREEN_H - indicator_h - 6.0
	var center_min: float = PLAYFIELD_MARGIN + indicator_w * 0.5
	var center_max: float = SCREEN_W - PLAYFIELD_MARGIN - indicator_w * 0.5
	var clamped_center_x: float = clampf(boss.get("x", _screen_center_x()), center_min, center_max)
	return Rect2(clamped_center_x - indicator_w * 0.5, indicator_y, indicator_w, indicator_h)

func _init() -> void:
	_resolve_singletons()
	if game_manager_ref:
		MAX_BULLETS = game_manager_ref.MAX_BULLETS
		SCREEN_W = game_manager_ref.SCREEN_W
		SCREEN_H = game_manager_ref.SCREEN_H
	else:
		MAX_BULLETS = 12000
		SCREEN_W = 720
		SCREEN_H = 960
	bullet_world.configure(MAX_BULLETS, bullet_pool_hard_capacity, BULLET_POOL_GROWTH)
	_sync_bullet_world_compatibility_views()
	_apply_viewport_layout()

func set_gameplay_seed(seed_value: int) -> void:
	gameplay_seed = seed_value
	gameplay_rng.reseed(gameplay_seed)

func _is_stage2_phase_practice_id(phase_id: String) -> bool:
	return phase_id in ReplayHeader.STAGE2_PHASE_IDS

func _activate_stage2_phase_practice(phase_id: String) -> bool:
	if _active_stage() != 2 or not _is_stage2_phase_practice_id(phase_id):
		return false
	if stage2_encounter_controller == null or not stage2_encounter_controller.is_configured():
		return false
	if not stage2_encounter_controller.start_phase_practice(phase_id):
		return false
	stage_timer = 0.0
	_sync_stage2_phase_boss()
	return true

func _start_stage2_phase_practice(phase_id: String) -> bool:
	if not _is_stage2_phase_practice_id(phase_id):
		return false
	game_manager_ref.practice_mode = true
	game_manager_ref.practice_stage = 2
	_start_game()
	if not _activate_stage2_phase_practice(phase_id):
		return false
	selected_stage2_phase_practice_id = ""
	return true

func _apply_replay_header_setup(header: RefCounted) -> bool:
	game_manager_ref.selected_protagonist_id = String(header.protagonist)
	game_manager_ref.selected_shot_id = String(header.shot_type)
	game_manager_ref.practice_mode = String(header.mode) != ReplayHeader.MODE_STORY
	game_manager_ref.practice_stage = int(header.starting_stage)
	gameplay_difficulty = String(header.difficulty)
	set_gameplay_seed(int(header.seed))
	_start_game()
	if String(header.mode) == ReplayHeader.MODE_SPELL_PRACTICE and int(header.starting_stage) == 2:
		if not _activate_stage2_phase_practice(String(header.phase_id)):
			return false
	elif String(header.mode) == ReplayHeader.MODE_SPELL_PRACTICE:
		_enter_boss()
		var phase_id := String(header.phase_id)
		for card_index in range(boss.get("cards", []).size()):
			var card: Dictionary = boss.cards[card_index]
			if phase_id in [String(card.get("id", "")), String(card.get("pattern", "")), String(card.get("name", ""))]:
				boss.card_idx = card_index
				break
	replay_identity = header.to_dict().duplicate(true)
	return true

func start_replay_recording(header: RefCounted, initialize_run: bool = true) -> bool:
	if not replay_data.start_recording(header):
		return false
	replay_runtime_mode = "recording"
	if initialize_run:
		if not _apply_replay_header_setup(replay_data.header):
			replay_runtime_mode = "none"
			return false
	else:
		set_gameplay_seed(int(replay_data.header.seed))
		gameplay_difficulty = String(replay_data.header.difficulty)
		replay_identity = replay_data.header.to_dict().duplicate(true)
	return true

func stop_replay_recording() -> Dictionary:
	if replay_runtime_mode != "recording":
		return {}
	var document: Dictionary = replay_data.to_dict().duplicate(true)
	replay_runtime_mode = "none"
	return document

func start_replay_playback(document: Dictionary, expected_identity: Dictionary = {}, initialize_run: bool = true) -> bool:
	# ReplayData validates the complete document and expected identity before it
	# changes its own cursor/header. Live simulation setup happens only after that.
	if not replay_data.start_playback(document, expected_identity):
		return false
	replay_runtime_mode = "playback"
	if initialize_run:
		if not _apply_replay_header_setup(replay_data.header):
			replay_runtime_mode = "none"
			return false
	else:
		set_gameplay_seed(int(replay_data.header.seed))
		gameplay_difficulty = String(replay_data.header.difficulty)
		replay_identity = replay_data.header.to_dict().duplicate(true)
	return true

func stop_replay_playback() -> void:
	if replay_runtime_mode == "playback":
		replay_runtime_mode = "none"

func capture_bullet_world_state() -> Dictionary:
	return bullet_world.capture_state()

func restore_bullet_world_state(snapshot: Dictionary) -> bool:
	var restored: Dictionary = bullet_world.restore_state(snapshot)
	if not bool(restored.get("ok", false)):
		return false
	_sync_bullet_world_compatibility_views()
	return true

func _sync_bullet_world_compatibility_views() -> void:
	bullet_pool = bullet_world.pool
	active_bullet_indices = bullet_world.active_indices

func capture_boss_state() -> Dictionary:
	return boss_state_machine.capture_state(boss)

func _capture_game_manager_state() -> Dictionary:
	var manager_state := {}
	if game_manager_ref:
		for property_name in GAME_MANAGER_STATE_FIELDS:
			var value = game_manager_ref.get(property_name)
			manager_state[property_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return manager_state

func _gameplay_ledger_is_nondefault() -> bool:
	return game_manager_ref and (
		float(game_manager_ref.night_festival_multiplier) != 1.0
		or float(game_manager_ref.highest_night_festival_multiplier) != 1.0
		or bool(game_manager_ref.spell_capture_active)
		or bool(game_manager_ref.spell_capture_invalidated)
		or not game_manager_ref.last_capture_result.is_empty()
		or int(game_manager_ref.run_spell_attempts) != 0
		or int(game_manager_ref.run_spell_captures) != 0
		or int(game_manager_ref.continues_used) != 0
	)

func _capture_gameplay_ledger_state() -> Dictionary:
	var ledger := {}
	for property_name in GAMEPLAY_LEDGER_STATE_FIELDS:
		var value = game_manager_ref.get(property_name)
		ledger[property_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return ledger

func _capture_replay_runtime_state() -> Dictionary:
	var state := {
		"mode": replay_runtime_mode,
		"identity": replay_identity.duplicate(true),
	}
	if replay_runtime_mode != "none" and replay_data.header != null:
		state["data"] = replay_data.capture_runtime_state()
	return state

func capture_simulation_state() -> Dictionary:
	var snapshot := {
		"version": SIMULATION_SNAPSHOT_VERSION,
		"tick": simulation_tick_index,
		"gameplay_seed": gameplay_seed,
		"gameplay_difficulty": gameplay_difficulty,
		"clock": fixed_tick_clock.snapshot(),
		"rng": gameplay_rng.snapshot(),
		"input": gameplay_input_buffer.snapshot(),
		"manager": _capture_game_manager_state(),
		"current_stage_local": current_stage_local,
		"stage_timer": stage_timer,
		"stage_controller": stage_controller.duplicate(true),
		"player": {
			"position": Vector2(player_x, player_y),
			"last_move_dir": player_last_move_dir,
			"invincible": player_invincible,
			"invincible_timer": player_invincible_timer,
			"just_hit": player_just_hit,
			"bombing": player_bombing,
			"bomb_timer": player_bomb_timer,
			"bomb_radius": player_bomb_radius,
			"bomb_phase": player_bomb_phase,
			"bomb_wave_timer": player_bomb_wave_timer,
			"bomb_config": player_bomb_config.duplicate(true),
			"deathbomb_primed": player_deathbomb_primed,
			"deathbomb_timer": player_deathbomb_timer,
			"fire_cooldown": player_fire_cooldown,
			"shoot_sfx_skip": _sfx_shoot_skip,
		},
		"boss_alive": boss_alive,
		"boss": capture_boss_state(),
		"bullets": capture_bullet_world_state(),
		"enemies": enemies.duplicate(true),
		"items": items.duplicate(true),
		"combat_effects": combat_effects.duplicate(true),
		"replay": _capture_replay_runtime_state(),
	}
	if current_stage_local == 2:
		snapshot["version"] = STAGE2_SIMULATION_SNAPSHOT_VERSION
		snapshot["stage2_controller"] = stage2_encounter_controller.capture_snapshot() if stage2_encounter_controller != null and stage2_encounter_controller.is_configured() else {}
		snapshot["stage2_field_runtime"] = stage2_field_topology_runtime.capture_snapshot() if stage2_field_topology_runtime != null and stage2_field_topology_runtime.is_configured() else {}
	if _gameplay_ledger_is_nondefault():
		snapshot["gameplay_ledger"] = _capture_gameplay_ledger_state()
	return snapshot

func _validate_manager_snapshot(manager_state: Dictionary) -> bool:
	for field in GAME_MANAGER_STATE_FIELDS:
		if not manager_state.has(field):
			return false
	for field in ["score", "graze", "shared_power", "bullet_type", "lives", "bombs", "life_fragments", "bomb_fragments", "night_festival_seals", "current_stage", "practice_stage", "highest_reached_stage"]:
		if typeof(manager_state[field]) != TYPE_INT or int(manager_state[field]) < 0:
			return false
	for field in ["state", "selected_protagonist_id", "selected_shot_id", "pause_return_state", "settings_return_state"]:
		if typeof(manager_state[field]) != TYPE_STRING:
			return false
	if int(manager_state.current_stage) < 1 or int(manager_state.practice_stage) < 1 or int(manager_state.highest_reached_stage) < 1:
		return false
	return typeof(manager_state.practice_mode) == TYPE_BOOL and manager_state.settings is Dictionary

func _validate_gameplay_ledger_snapshot(ledger: Dictionary) -> bool:
	for field in GAMEPLAY_LEDGER_STATE_FIELDS:
		if not ledger.has(field): return false
	for field in ["spell_capture_base_value", "run_spell_attempts", "run_spell_captures", "continues_used"]:
		if typeof(ledger[field]) != TYPE_INT or int(ledger[field]) < 0: return false
	for field in ["night_festival_multiplier", "highest_night_festival_multiplier"]:
		if not _is_valid_snapshot_number(ledger[field], 1.0) or float(ledger[field]) > 2.0: return false
	if float(ledger.highest_night_festival_multiplier) < float(ledger.night_festival_multiplier):
		return false
	if not _is_valid_snapshot_number(ledger.spell_capture_total_frames, 1.0):
		return false
	for field in ["spell_capture_active", "spell_capture_invalidated"]:
		if typeof(ledger[field]) != TYPE_BOOL: return false
	if typeof(ledger.spell_capture_invalid_reason) != TYPE_STRING or typeof(ledger.spell_capture_card_id) != TYPE_STRING or not (ledger.last_capture_result is Dictionary):
		return false
	if int(ledger.run_spell_captures) > int(ledger.run_spell_attempts):
		return false
	var active := bool(ledger.spell_capture_active)
	var invalidated := bool(ledger.spell_capture_invalidated)
	var invalid_reason := String(ledger.spell_capture_invalid_reason)
	var card_id := String(ledger.spell_capture_card_id)
	if invalidated != (invalid_reason != ""):
		return false
	if active and (card_id == "" or int(ledger.run_spell_attempts) == 0):
		return false
	var last_result: Dictionary = ledger.last_capture_result
	if not last_result.is_empty() and not _validate_capture_result_snapshot(last_result):
		return false
	if not last_result.is_empty() and bool(last_result.captured) and int(ledger.run_spell_captures) == 0:
		return false
	if not active:
		if card_id == "":
			return int(ledger.spell_capture_base_value) == 0 and is_equal_approx(float(ledger.spell_capture_total_frames), 1.0) and not invalidated and last_result.is_empty()
		if last_result.is_empty() or int(ledger.run_spell_attempts) == 0:
			return false
		if String(last_result.card_id) != card_id or int(last_result.base_value) != int(ledger.spell_capture_base_value) or not is_equal_approx(float(last_result.total_frames), float(ledger.spell_capture_total_frames)):
			return false
		var result_reason := String(last_result.reason)
		if bool(last_result.captured):
			return not invalidated
		if result_reason == "timeout":
			return not invalidated
		return invalidated and invalid_reason == result_reason
	return true

func _validate_capture_result_snapshot(result: Dictionary) -> bool:
	for field in ["card_id", "captured", "reason", "bonus", "base_value", "remaining_frames", "total_frames", "multiplier"]:
		if not result.has(field):
			return false
	if typeof(result.card_id) != TYPE_STRING or String(result.card_id) == "" or typeof(result.captured) != TYPE_BOOL or typeof(result.reason) != TYPE_STRING:
		return false
	for field in ["bonus", "base_value"]:
		if typeof(result[field]) != TYPE_INT or int(result[field]) < 0:
			return false
	if not _is_valid_snapshot_number(result.remaining_frames, 0.0) or not _is_valid_snapshot_number(result.total_frames, 1.0):
		return false
	if float(result.remaining_frames) > float(result.total_frames):
		return false
	if not _is_valid_snapshot_number(result.multiplier, 1.0) or float(result.multiplier) > 2.0:
		return false
	if bool(result.captured):
		var expected_bonus := int(floor(float(result.base_value) * float(result.remaining_frames) / float(result.total_frames) * float(result.multiplier)))
		return String(result.reason) == "capture" and int(result.bonus) == expected_bonus
	return String(result.reason) != "" and String(result.reason) != "capture" and int(result.bonus) == 0

func _validate_gameplay_bullet_snapshot(bullets_snapshot: Dictionary) -> bool:
	for entry_value in bullets_snapshot.get("active_bullets", []):
		var entry: Dictionary = entry_value
		var bullet: Dictionary = entry.get("state", {})
		if String(bullet.get("type", "")) != "player":
			continue
		var owns_gameplay_fields := bullet.has("behavior") or bullet.has("hit_ledger") or bullet.has("hit_count")
		if not owns_gameplay_fields:
			continue
		if not (bullet.get("behavior") is Dictionary) or not (bullet.get("hit_ledger") is Dictionary) or typeof(bullet.get("hit_count")) != TYPE_INT:
			return false
		var behavior: Dictionary = bullet.behavior
		var ledger: Dictionary = bullet.hit_ledger
		if typeof(behavior.get("kind")) != TYPE_STRING or String(behavior.kind) == "":
			return false
		if behavior.has("piercing") and typeof(behavior.piercing) != TYPE_BOOL:
			return false
		if behavior.has("max_hits") and (typeof(behavior.max_hits) != TYPE_INT or int(behavior.max_hits) <= 0):
			return false
		var max_hits := int(behavior.get("max_hits", 1))
		var hit_count := int(bullet.hit_count)
		if hit_count < 0 or hit_count > max_hits:
			return false
		var kind := String(behavior.kind)
		match kind:
			"tracking_ofuda":
				for field in ["tracking_range", "acquisition_half_angle", "turn_rate", "max_deflect"]:
					if not _is_valid_snapshot_number(behavior.get(field), 0.0):
						return false
			"yinyang_satellite":
				if not _is_valid_snapshot_number(behavior.get("satellite_offset")) or typeof(behavior.get("focused")) != TYPE_BOOL:
					return false
			"distance_damage":
				var origin = behavior.get("origin")
				if not (origin is Vector2) or is_nan(origin.x) or is_nan(origin.y) or is_inf(origin.x) or is_inf(origin.y):
					return false
				for field in ["near_range", "near_multiplier", "far_multiplier"]:
					if not _is_valid_snapshot_number(behavior.get(field), 0.000001 if field == "near_range" else 0.0):
						return false
				if behavior.has("cross_slash") and typeof(behavior.cross_slash) != TYPE_BOOL:
					return false
			"sustained_laser":
				if not _is_valid_snapshot_number(behavior.get("repeat_interval"), 0.000001) or not bool(behavior.get("piercing", false)):
					return false
				if behavior.has("focused") and typeof(behavior.focused) != TYPE_BOOL:
					return false
			"returning_blade":
				if typeof(behavior.get("returned")) != TYPE_BOOL or not bool(behavior.get("piercing", false)):
					return false
				if not _is_valid_snapshot_number(behavior.get("turn_age"), 0.0) or not _is_valid_snapshot_number(behavior.get("return_speed"), 0.000001) or not _is_valid_snapshot_number(behavior.get("lateral_response"), 0.0):
					return false
			_:
				return false
		for target_key in ledger:
			if typeof(target_key) != TYPE_STRING:
				return false
			if kind == "sustained_laser":
				if not _is_valid_snapshot_number(ledger[target_key], 0.0) or float(ledger[target_key]) > float(bullet.age):
					return false
			elif typeof(ledger[target_key]) != TYPE_BOOL or not bool(ledger[target_key]):
				return false
		if (kind == "sustained_laser" and ledger.size() > hit_count) or (kind != "sustained_laser" and ledger.size() != hit_count):
			return false
	return true

func _validate_stage2_bullet_observability_snapshot(stage_state: Dictionary, bullets_snapshot: Dictionary, field_snapshot: Dictionary, field_probe: RefCounted) -> bool:
	var next_uid_value = stage_state.get("stage2_next_bullet_uid")
	if typeof(next_uid_value) != TYPE_INT or int(next_uid_value) <= 0:
		return false
	if typeof(stage_state.get("stage2_field_tick")) != TYPE_INT or typeof(stage_state.get("stage2_field_event_sequence")) != TYPE_INT:
		return false
	if typeof(stage_state.get("stage2_field_run_uid")) != TYPE_STRING or String(stage_state.stage2_field_run_uid) == "" or String(stage_state.stage2_field_run_uid).contains(":"):
		return false
	if not (stage_state.get("stage2_field_uid_to_slot") is Dictionary) or typeof(stage_state.get("stage2_field_hard_error")) != TYPE_STRING or String(stage_state.stage2_field_hard_error) != "":
		return false
	for record_key in ["stage2_field_warning_records", "stage2_field_source_activation_records", "stage2_field_source_removals", "stage2_field_state_transitions", "stage2_field_score_projections", "stage2_field_telemetry"]:
		if not (stage_state.get(record_key) is Array) or (stage_state[record_key] as Array).size() > STAGE2_FIELD_RECORD_LIMIT:
			return false
	if not (field_snapshot.get("payload") is Dictionary) or field_probe == null or field_probe.has_hard_error():
		return false
	var field_payload: Dictionary = field_snapshot.payload
	if String(field_payload.get("stage_run_uid", "")) != String(stage_state.stage2_field_run_uid):
		return false
	if int(field_payload.get("schedule_cursor_tick", -2)) != int(stage_state.stage2_field_tick) or int(field_payload.get("last_event_sequence", -2)) != int(stage_state.stage2_field_event_sequence):
		return false
	if not (field_payload.get("active_bullets") is Dictionary):
		return false
	if not (stage_state.get("stage2_field_activated_event_ids") is Array) or not (field_payload.get("activated_events") is Array):
		return false
	var activated_lookup := {}
	for event_value in stage_state.stage2_field_activated_event_ids:
		if typeof(event_value) != TYPE_STRING or activated_lookup.has(String(event_value)):
			return false
		activated_lookup[String(event_value)] = true
	if activated_lookup.size() != (field_payload.activated_events as Array).size():
		return false
	for event_value in field_payload.activated_events:
		if not activated_lookup.has(String(event_value)):
			return false
	var runtime_field_bullets: Dictionary = field_payload.active_bullets
	var field_bindings: Dictionary = stage_state.stage2_field_uid_to_slot
	if runtime_field_bullets.size() != field_bindings.size():
		return false
	var next_uid := int(next_uid_value)
	var seen_compat_uids := {}
	var seen_field_uids := {}
	var phase_source_fields := ["stage2_source_phase_id", "stage2_source_owner_id"]
	var bullets_by_slot := {}
	for entry_value in bullets_snapshot.get("active_bullets", []):
		if not (entry_value is Dictionary):
			return false
		var entry: Dictionary = entry_value
		if typeof(entry.get("slot")) != TYPE_INT or not (entry.get("state") is Dictionary):
			return false
		var slot := int(entry.slot)
		var bullet: Dictionary = entry.get("state", {})
		bullets_by_slot[slot] = bullet
		var uid_value = bullet.get("stage2_bullet_uid")
		var bullet_type := String(bullet.get("type", ""))
		var stage_source_count := 0
		for field in STAGE2_FIELD_SOURCE_FIELDS:
			if bullet.has(field):
				stage_source_count += 1
				if typeof(bullet[field]) != TYPE_STRING or String(bullet[field]) == "":
					return false
		var phase_source_count := 0
		for field in phase_source_fields:
			if bullet.has(field):
				phase_source_count += 1
				if typeof(bullet[field]) != TYPE_STRING or String(bullet[field]) == "":
					return false
		if stage_source_count not in [0, STAGE2_FIELD_SOURCE_FIELDS.size()] or phase_source_count not in [0, phase_source_fields.size()]:
			return false
		var has_stage_source := stage_source_count == STAGE2_FIELD_SOURCE_FIELDS.size()
		var has_phase_source := phase_source_count == phase_source_fields.size()
		var is_field_bullet := bool(bullet.get("stage2_field_owned", false))
		if is_field_bullet:
			if typeof(uid_value) != TYPE_STRING or not has_stage_source or has_phase_source or bullet_type in ["player", "bomb"]:
				return false
			var field_uid := String(uid_value)
			if field_uid == "" or seen_field_uids.has(field_uid) or not field_probe.validate_bullet_uid(field_uid):
				return false
			if not runtime_field_bullets.has(field_uid) or not field_bindings.has(field_uid) or typeof(field_bindings[field_uid]) != TYPE_INT or int(field_bindings[field_uid]) != slot:
				return false
			var runtime_bullet: Dictionary = runtime_field_bullets[field_uid]
			for seam_field in STAGE2_FIELD_SEAM_FIELDS:
				if not bullet.has(seam_field) or not runtime_bullet.has(seam_field) or bullet[seam_field] != runtime_bullet[seam_field]:
					return false
			if typeof(bullet.stage2_reflection_count) != TYPE_INT or int(bullet.stage2_reflection_count) < 0:
				return false
			for tick_field in ["stage2_bullet_spawn_tick", "stage2_collision_enable_tick", "stage2_lifetime_end_tick"]:
				if typeof(bullet[tick_field]) != TYPE_INT or int(bullet[tick_field]) < 0:
					return false
			if bullet.stage2_first_reflection_tick != null and typeof(bullet.stage2_first_reflection_tick) != TYPE_INT:
				return false
			if bullet.stage2_last_reflection_surface_id != null and (typeof(bullet.stage2_last_reflection_surface_id) != TYPE_STRING or String(bullet.stage2_last_reflection_surface_id) == ""):
				return false
			seen_field_uids[field_uid] = true
			continue
		if typeof(uid_value) != TYPE_INT:
			return false
		var uid := int(uid_value)
		if uid <= 0 or uid >= next_uid or seen_compat_uids.has(uid):
			return false
		seen_compat_uids[uid] = true
		if bullet_type in ["player", "bomb"]:
			if bullet.has("stage2_reflection_count") or has_stage_source or has_phase_source:
				return false
		else:
			if has_stage_source == has_phase_source:
				return false
			if typeof(bullet.get("stage2_reflection_count")) != TYPE_INT or int(bullet.stage2_reflection_count) < 0:
				return false
	if seen_field_uids.size() != runtime_field_bullets.size():
		return false
	for uid_value in field_bindings.keys():
		if typeof(uid_value) != TYPE_STRING or not seen_field_uids.has(String(uid_value)):
			return false
		var binding_slot := int(field_bindings[uid_value])
		if not bullets_by_slot.has(binding_slot) or String((bullets_by_slot[binding_slot] as Dictionary).get("stage2_bullet_uid", "")) != String(uid_value):
			return false
	return true

func _validate_legacy_bullet_observability_shape(stage_state: Dictionary, bullets_snapshot: Dictionary) -> bool:
	if stage_state.has("stage2_next_bullet_uid"):
		return false
	for entry_value in bullets_snapshot.get("active_bullets", []):
		var bullet: Dictionary = (entry_value as Dictionary).get("state", {})
		for field in bullet:
			if String(field).begins_with("stage2_"):
				return false
	return true

func _is_valid_snapshot_number(value: Variant, minimum: float = -INF) -> bool:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= minimum

func _validate_replay_runtime_snapshot(replay_state: Dictionary) -> bool:
	var mode := String(replay_state.get("mode", ""))
	if mode not in REPLAY_RUNTIME_MODES or not (replay_state.get("identity", {}) is Dictionary):
		return false
	if mode == "none":
		return not replay_state.has("data")
	var data = replay_state.get("data", null)
	if not (data is Dictionary):
		return false
	var probe := ReplayData.new()
	return probe.validate_runtime_state(data)

func validate_simulation_state(snapshot: Dictionary) -> bool:
	for section in ["clock", "rng", "input", "manager", "player", "boss", "bullets", "replay"]:
		if not (snapshot.get(section) is Dictionary):
			return false
	for section in ["stage_controller"]:
		if not (snapshot.get(section) is Dictionary):
			return false
	for section in ["enemies", "items", "combat_effects"]:
		if not (snapshot.get(section) is Array):
			return false
	if typeof(snapshot.get("tick")) != TYPE_INT or int(snapshot.tick) < 0:
		return false
	if typeof(snapshot.get("gameplay_seed")) != TYPE_INT or int(snapshot.gameplay_seed) != int(snapshot.rng.get("initial_seed", 0)):
		return false
	if String(snapshot.get("gameplay_difficulty", "")) not in ReplayHeader.SUPPORTED_DIFFICULTIES:
		return false
	if typeof(snapshot.get("current_stage_local")) != TYPE_INT or int(snapshot.current_stage_local) < 1:
		return false
	if int(snapshot.manager.get("current_stage", -1)) != int(snapshot.current_stage_local):
		return false
	var is_stage2_snapshot := int(snapshot.current_stage_local) == 2
	if is_stage2_snapshot:
		if int(snapshot.get("version", -1)) != STAGE2_SIMULATION_SNAPSHOT_VERSION or not (snapshot.get("stage2_controller") is Dictionary) or not (snapshot.get("stage2_field_runtime") is Dictionary):
			return false
	else:
		if int(snapshot.get("version", -1)) != SIMULATION_SNAPSHOT_VERSION or snapshot.has("stage2_controller") or snapshot.has("stage2_field_runtime"):
			return false
	if not _is_valid_snapshot_number(snapshot.get("stage_timer"), 0.0):
		return false
	var clock_probe := FixedTickClock.new()
	var rng_probe := DeterministicRng.new()
	var input_probe := GameplayInputBuffer.new()
	var bullet_probe := BulletWorld.new()
	if not clock_probe.restore(snapshot.clock) or clock_probe.tick_index != int(snapshot.tick):
		return false
	if not rng_probe.restore(snapshot.rng) or not input_probe.restore(snapshot.input):
		return false
	if not bullet_probe.validate_snapshot(snapshot.bullets):
		return false
	if not _validate_gameplay_bullet_snapshot(snapshot.bullets):
		return false
	if not is_stage2_snapshot and not _validate_legacy_bullet_observability_shape(snapshot.stage_controller, snapshot.bullets):
		return false
	if not _validate_manager_snapshot(snapshot.manager) or not _validate_replay_runtime_snapshot(snapshot.replay):
		return false
	if is_stage2_snapshot:
		var stage2_snapshot: Dictionary = snapshot.stage2_controller
		if stage2_snapshot.is_empty() or not stage_director.has_method("stage2_package"):
			return false
		var stage2_probe := Stage2EncounterController.new()
		if not stage2_probe.configure(stage_director.stage2_package(), String(snapshot.gameplay_difficulty), int(snapshot.gameplay_seed)):
			return false
		if not stage2_probe.validate_snapshot(stage2_snapshot) or not stage2_probe.restore_snapshot(stage2_snapshot):
			return false
		var stage2_kind := String(stage2_snapshot.get("encounter_kind", ""))
		if (stage2_kind in ["midboss", "boss"]) != bool(snapshot.get("boss_alive", false)):
			return false
		if stage2_kind in ["midboss", "boss"]:
			var active_definition: Dictionary = stage2_probe.active_phase_definition()
			var boss_snapshot_state: Dictionary = snapshot.boss.get("state", {})
			if String(boss_snapshot_state.get("stage2_phase_id", "")) != String(active_definition.get("id", "")):
				return false
		if not stage_director.has_method("stage2_field_topology_contract"):
			return false
		var field_contract: Dictionary = stage_director.stage2_field_topology_contract()
		var field_run_uid := _stage2_field_run_uid(int(snapshot.gameplay_seed), String(snapshot.gameplay_difficulty))
		var field_probe := Stage2FieldTopologyRuntime.new()
		if field_contract.is_empty() or not field_probe.configure(field_contract, String(snapshot.gameplay_difficulty), field_run_uid):
			return false
		if not field_probe.validate_snapshot(snapshot.stage2_field_runtime) or not field_probe.restore_snapshot(snapshot.stage2_field_runtime):
			return false
		if not _validate_stage2_bullet_observability_snapshot(snapshot.stage_controller, snapshot.bullets, snapshot.stage2_field_runtime, field_probe):
			return false
	if snapshot.has("gameplay_ledger") and (not (snapshot.gameplay_ledger is Dictionary) or not _validate_gameplay_ledger_snapshot(snapshot.gameplay_ledger)):
		return false
	var player_state: Dictionary = snapshot.player
	for field in ["position", "last_move_dir", "invincible", "invincible_timer", "just_hit", "bombing", "bomb_timer", "bomb_radius", "bomb_phase", "bomb_wave_timer", "bomb_config", "deathbomb_primed", "deathbomb_timer", "fire_cooldown", "shoot_sfx_skip"]:
		if not player_state.has(field):
			return false
	if not (player_state.position is Vector2) or not (player_state.last_move_dir is Vector2) or not (player_state.bomb_config is Dictionary):
		return false
	if is_nan(player_state.position.x) or is_nan(player_state.position.y) or is_inf(player_state.position.x) or is_inf(player_state.position.y):
		return false
	if is_nan(player_state.last_move_dir.x) or is_nan(player_state.last_move_dir.y) or is_inf(player_state.last_move_dir.x) or is_inf(player_state.last_move_dir.y):
		return false
	for field in ["invincible", "just_hit", "bombing", "deathbomb_primed"]:
		if typeof(player_state[field]) != TYPE_BOOL:
			return false
	for field in ["invincible_timer", "bomb_timer", "bomb_radius", "bomb_wave_timer", "deathbomb_timer", "fire_cooldown"]:
		if not _is_valid_snapshot_number(player_state[field]):
			return false
	for field in ["bomb_phase", "shoot_sfx_skip"]:
		if typeof(player_state[field]) != TYPE_INT or int(player_state[field]) < 0:
			return false
	for collection_name in ["enemies", "items", "combat_effects"]:
		for entry in snapshot[collection_name]:
			if not (entry is Dictionary):
				return false
	if typeof(snapshot.get("boss_alive")) != TYPE_BOOL:
		return false
	var boss_snapshot: Dictionary = snapshot.boss
	if int(boss_snapshot.get("version", -1)) != BossStateMachine.VERSION or not (boss_snapshot.get("state", {}) is Dictionary):
		return false
	var boss_state: Dictionary = boss_snapshot.state
	if not boss_state.is_empty() and boss_state_machine.restore_state(boss_snapshot).is_empty():
		return false
	if bool(snapshot.boss_alive) and boss_state.is_empty():
		return false
	return true

func restore_simulation_state(snapshot: Dictionary) -> bool:
	if not validate_simulation_state(snapshot):
		return false
	var restored_stage2_controller := Stage2EncounterController.new()
	var restored_stage2_field_runtime := Stage2FieldTopologyRuntime.new()
	if int(snapshot.current_stage_local) == 2:
		if not restored_stage2_controller.configure(stage_director.stage2_package(), String(snapshot.gameplay_difficulty), int(snapshot.gameplay_seed)):
			return false
		if not restored_stage2_controller.restore_snapshot(snapshot.stage2_controller):
			return false
		var field_contract: Dictionary = stage_director.stage2_field_topology_contract()
		if field_contract.is_empty() or not restored_stage2_field_runtime.configure(field_contract, String(snapshot.gameplay_difficulty), _stage2_field_run_uid(int(snapshot.gameplay_seed), String(snapshot.gameplay_difficulty))):
			return false
		if not restored_stage2_field_runtime.restore_snapshot(snapshot.stage2_field_runtime):
			return false
	# Every component has been validated against a disposable owner above; the
	# assignments below therefore form an all-or-nothing aggregate commit.
	fixed_tick_clock.restore(snapshot.clock)
	gameplay_rng.restore(snapshot.rng)
	gameplay_seed = int(snapshot.gameplay_seed)
	gameplay_difficulty = String(snapshot.gameplay_difficulty)
	gameplay_input_buffer.restore(snapshot.input)
	restore_bullet_world_state(snapshot.bullets)
	for property_name in GAME_MANAGER_STATE_FIELDS:
		var value = snapshot.manager[property_name]
		game_manager_ref.set(property_name, value.duplicate(true) if value is Array or value is Dictionary else value)
	game_manager_ref.night_festival_multiplier = 1.0
	game_manager_ref.highest_night_festival_multiplier = 1.0
	game_manager_ref.spell_capture_active = false
	game_manager_ref.spell_capture_invalidated = false
	game_manager_ref.spell_capture_invalid_reason = ""
	game_manager_ref.spell_capture_card_id = ""
	game_manager_ref.spell_capture_base_value = 0
	game_manager_ref.spell_capture_total_frames = 1.0
	game_manager_ref.last_capture_result = {}
	game_manager_ref.run_spell_attempts = 0
	game_manager_ref.run_spell_captures = 0
	game_manager_ref.continues_used = 0
	if snapshot.has("gameplay_ledger"):
		for property_name in GAMEPLAY_LEDGER_STATE_FIELDS:
			var ledger_value = snapshot.gameplay_ledger[property_name]
			game_manager_ref.set(property_name, ledger_value.duplicate(true) if ledger_value is Array or ledger_value is Dictionary else ledger_value)
	simulation_tick_index = int(snapshot.tick)
	current_stage_local = int(snapshot.current_stage_local)
	stage_timer = float(snapshot.stage_timer)
	stage_controller = snapshot.stage_controller.duplicate(true)
	stage2_encounter_controller = restored_stage2_controller
	stage2_field_topology_runtime = restored_stage2_field_runtime
	var player_state: Dictionary = snapshot.player
	player_x = float(player_state.position.x)
	player_y = float(player_state.position.y)
	player_last_move_dir = player_state.last_move_dir
	player_invincible = bool(player_state.invincible)
	player_invincible_timer = float(player_state.invincible_timer)
	player_just_hit = bool(player_state.just_hit)
	player_bombing = bool(player_state.bombing)
	player_bomb_timer = float(player_state.bomb_timer)
	player_bomb_radius = float(player_state.bomb_radius)
	player_bomb_phase = int(player_state.bomb_phase)
	player_bomb_wave_timer = float(player_state.bomb_wave_timer)
	player_bomb_config = player_state.bomb_config.duplicate(true)
	player_deathbomb_primed = bool(player_state.deathbomb_primed)
	player_deathbomb_timer = float(player_state.deathbomb_timer)
	player_fire_cooldown = float(player_state.fire_cooldown)
	_sfx_shoot_skip = int(player_state.shoot_sfx_skip)
	boss_alive = bool(snapshot.boss_alive)
	boss = boss_state_machine.restore_state(snapshot.boss) if boss_alive else snapshot.boss.state.duplicate(true)
	enemies = snapshot.enemies.duplicate(true)
	items = snapshot.items.duplicate(true)
	combat_effects = snapshot.combat_effects.duplicate(true)
	var replay_state: Dictionary = snapshot.replay
	replay_runtime_mode = String(replay_state.mode)
	replay_identity = replay_state.identity.duplicate(true)
	if replay_runtime_mode == "none":
		replay_data = ReplayData.new()
	else:
		replay_data.restore_runtime_state(replay_state.data)
	current_tick_input = gameplay_input_buffer.current_tick_frame.duplicate(true)
	return true

func simulation_state_hash() -> String:
	return simulation_state_hasher.hash_state(capture_simulation_state())

func _transition_boss_phase(next_phase: String, reset_timer: bool = false) -> bool:
	return boss_state_machine.transition(boss, next_phase, reset_timer)

func _active_stage() -> int:
	return game_manager_ref.current_stage if game_manager_ref else current_stage_local

func _set_active_stage(stage: int) -> void:
	current_stage_local = stage
	if game_manager_ref:
		game_manager_ref.current_stage = stage

func _apply_viewport_layout() -> void:
	player_x = SCREEN_W * 0.5
	player_y = SCREEN_H * 0.5625

func _ready():
	_resolve_singletons()
	set_gameplay_seed(gameplay_seed)
	fixed_tick_clock.reset()
	gameplay_input_buffer.reset()
	simulation_tick_index = 0
	bullet_world.configure(MAX_BULLETS, bullet_pool_hard_capacity, BULLET_POOL_GROWTH)
	_sync_bullet_world_compatibility_views()
	# Ensure GameManager globals are initialized
	game_manager_ref.reset()
	_apply_runtime_settings()
	_show_title()

func _make_bullet() -> Dictionary:
	return bullet_world.make_bullet_state()

func _show_title():
	_resolve_singletons()
	game_manager_ref.state = "title"
	_sync_canvas_origin("title")
	game_manager_ref.practice_mode = false
	selected_stage2_phase_practice_id = ""
	game_manager_ref.settings_return_state = "title"
	main_menu_cursor = 0
	_set_pause_audio(false)
	if audio_manager_ref: audio_manager_ref.stop_bgm()

func _start_game():
	_resolve_singletons()
	var selected_protagonist_id: String = String(game_manager_ref.selected_protagonist_id)
	var selected_shot_id: String = String(game_manager_ref.selected_shot_id)
	var selected_practice_mode: bool = bool(game_manager_ref.practice_mode)
	var selected_practice_stage: int = int(game_manager_ref.practice_stage)
	var highest_reached_stage: int = int(game_manager_ref.highest_reached_stage)
	var selected_settings: Dictionary = game_manager_ref.settings.duplicate(true)
	game_manager_ref.reset()
	game_manager_ref.selected_protagonist_id = selected_protagonist_id
	game_manager_ref.selected_shot_id = selected_shot_id
	game_manager_ref.practice_mode = selected_practice_mode
	game_manager_ref.practice_stage = selected_practice_stage
	game_manager_ref.highest_reached_stage = highest_reached_stage
	game_manager_ref.settings = selected_settings
	game_manager_ref.apply_selected_shot()
	_apply_runtime_settings()
	set_gameplay_seed(gameplay_seed)
	fixed_tick_clock.reset()
	gameplay_input_buffer.reset()
	simulation_tick_index = 0
	current_tick_input = GameplayInputBuffer.empty_tick_frame(0)
	game_manager_ref.state = "stage"
	_sync_canvas_origin("stage")
	var starting_stage := selected_practice_stage if selected_practice_mode else 1
	_set_active_stage(starting_stage)
	stage_timer = 0.0
	_reset_player()
	_clear_bullets()
	enemies.clear(); items.clear(); combat_effects.clear()
	_load_stage(starting_stage)
	boss = {}; boss_alive = false
	if audio_manager_ref: audio_manager_ref.bgm_stage_mid(starting_stage)

func _reset_player():
	_stop_bomb_sfx()
	player_x = SCREEN_W * 0.5
	player_y = SCREEN_H * 0.5625
	player_invincible = false; player_invincible_timer = 0.0
	player_just_hit = false; player_bombing = false
	player_bomb_timer = 0.0; player_bomb_radius = 0.0; player_bomb_phase = 0
	player_bomb_wave_timer = 0.0; player_bomb_config = {}
	player_fire_cooldown = 0.0
	player_deathbomb_primed = false; player_deathbomb_timer = 0.0
	player_last_move_dir = Vector2(0, -1)

func _respawn():
	if game_manager_ref.has_method("record_actual_miss"):
		game_manager_ref.record_actual_miss()
	game_manager_ref.lives -= 1
	game_manager_ref.bombs = game_manager_ref.PLAYER_INITIAL_BOMBS
	var dropped: int = int(game_manager_ref.shared_power * game_manager_ref.DEATH_POWER_DROP)
	for i in range(mini(50, dropped)):
		_spawn_item(player_x + gameplay_rng.range_float(-80.0, 80.0), player_y + gameplay_rng.range_float(-60.0, 60.0), "power")
	game_manager_ref.shared_power = max(0, game_manager_ref.shared_power - dropped)
	_reset_player()
	player_invincible = true
	player_invincible_timer = game_manager_ref.INVINCIBLE_DURATION / 60.0

func _advance_stage():
	_set_active_stage(_active_stage() + 1)
	stage_timer = 0.0
	_clear_bullets()
	items.clear(); enemies.clear(); combat_effects.clear()
	boss = {}; boss_alive = false
	_load_stage(_active_stage())
	game_manager_ref.state = "stage"
	if audio_manager_ref: audio_manager_ref.bgm_stage_mid(_active_stage())

func _restart_current_stage() -> void:
	_resolve_singletons()
	if not game_manager_ref:
		return
	var stage: int = clampi(game_manager_ref.current_stage, 1, game_manager_ref.stage_count())
	_set_active_stage(stage)
	stage_timer = 0.0
	_reset_player()
	_clear_bullets()
	enemies.clear()
	items.clear()
	combat_effects.clear()
	boss = {}
	boss_alive = false
	_load_stage(stage)
	game_manager_ref.state = game_manager_ref.STATE_STAGE
	_set_pause_audio(false)
	if audio_manager_ref:
		audio_manager_ref.bgm_stage_mid(stage)

func _load_stage(stage: int):
	if game_manager_ref:
		game_manager_ref.unlock_stage(stage)
	current_stage_local = stage
	if game_manager_ref:
		game_manager_ref.current_stage = stage
	stage_controller = stage_director.stage_controller(stage)
	stage2_encounter_controller = Stage2EncounterController.new()
	stage2_field_topology_runtime = Stage2FieldTopologyRuntime.new()
	if stage_controller.is_empty():
		return
	stage_controller["triggered_waves"] = {}
	stage_controller["boss_spawned"] = false
	if stage == 2:
		stage_controller["stage2_bound"] = false
		stage_controller["stage2_next_bullet_uid"] = 1
		stage_controller["stage2_event_ids"] = []
		stage_controller["stage2_stage_event_records"] = []
		stage_controller["stage2_spawn_ids"] = []
		stage_controller["stage2_warning_records"] = []
		stage_controller["stage2_phase_event_records"] = []
		stage_controller["stage2_boss_movement_records"] = []
		stage_controller["stage2_phase_resolutions"] = []
		stage_controller["stage2_field_run_uid"] = _stage2_field_run_uid(gameplay_seed, gameplay_difficulty)
		stage_controller["stage2_field_tick"] = -1
		stage_controller["stage2_field_event_sequence"] = -1
		stage_controller["stage2_field_uid_to_slot"] = {}
		stage_controller["stage2_field_activated_event_ids"] = []
		stage_controller["stage2_field_warning_records"] = []
		stage_controller["stage2_field_source_activation_records"] = []
		stage_controller["stage2_field_source_removals"] = []
		stage_controller["stage2_field_state_transitions"] = []
		stage_controller["stage2_field_score_projections"] = []
		stage_controller["stage2_field_telemetry"] = []
		stage_controller["stage2_field_hard_error"] = ""
		if not stage_director.has_method("stage2_package") or not stage2_encounter_controller.configure(stage_director.stage2_package(), gameplay_difficulty, gameplay_seed):
			stage_controller["stage2_hard_error"] = stage2_encounter_controller.last_error()
			return
		if not stage_director.has_method("stage2_field_topology_contract"):
			stage_controller["stage2_hard_error"] = "Stage 2 field topology contract query is unavailable"
			return
		var field_contract: Dictionary = stage_director.stage2_field_topology_contract()
		if field_contract.is_empty() or not stage2_field_topology_runtime.configure(field_contract, gameplay_difficulty, String(stage_controller.stage2_field_run_uid)):
			stage_controller["stage2_hard_error"] = stage2_field_topology_runtime.last_error() if stage2_field_topology_runtime != null else "Stage 2 field topology runtime is unavailable"
			return
		stage_controller["stage2_bound"] = true

func _stage2_field_run_uid(seed_value: int, difficulty: String) -> String:
	return "stage2_%s_%d" % [difficulty, seed_value]

func _clear_bullets():
	bullet_world.reset()
	_sync_bullet_world_compatibility_views()

func _rebuild_active_bullet_indices() -> void:
	bullet_world.rebuild_active_order()
	_sync_bullet_world_compatibility_views()

func _ensure_active_bullet_indices() -> void:
	_sync_bullet_world_compatibility_views()

func _claim_free_bullet_slot() -> int:
	return bullet_world.claim_free_slot()

func _spawn_bullet_values(bullet_values: Dictionary) -> int:
	if _active_stage() != 2:
		return int(bullet_world.spawn_bullet(bullet_values))
	var next_uid_value = stage_controller.get("stage2_next_bullet_uid")
	if typeof(next_uid_value) != TYPE_INT or int(next_uid_value) <= 0:
		return -1
	var next_uid := int(next_uid_value)
	bullet_values["stage2_bullet_uid"] = next_uid
	var bullet_index := int(bullet_world.spawn_bullet(bullet_values))
	if bullet_index >= 0:
		stage_controller["stage2_next_bullet_uid"] = next_uid + 1
	return bullet_index

func _spawn_bullet_player(x: float, y: float, vx: float, vy: float, radius: float = 5.0, color: Color = Color(0,0.7,1), damage: float = 1.0, homing: bool = false, btype: int = -1, persist: bool = false, lifetime: float = 100.0, behavior: Dictionary = {}):
	var bullet_values := {
		"x": x, "y": y, "vx": vx, "vy": vy,
		"radius": radius, "color": color,
		"type": "bomb" if persist else "player",
		"lifetime": lifetime, "age": 0.0, "damage": damage,
		"homing": homing, "btype": btype, "grazed": false,
		"boss_hit": false, "motion": {}, "has_motion": false,
		"motion_triggered": false,
	}
	if not behavior.is_empty():
		bullet_values["behavior"] = behavior.duplicate(true)
		bullet_values["hit_ledger"] = {}
		bullet_values["hit_count"] = 0
	var bullet_index: int = _spawn_bullet_values(bullet_values)
	_sync_bullet_world_compatibility_views()
	return bullet_index >= 0

func _spawn_bullet_enemy(x: float, y: float, vx: float, vy: float, radius: float = 6.0, color: Color = Color.RED, btype: String = "circle", lifetime: float = 350.0, motion: Dictionary = {}, stage2_source: Dictionary = {}):
	var bullet_values := {
		"x": x, "y": y, "vx": vx, "vy": vy,
		"radius": maxf(0.001, radius), "color": color, "type": btype,
		"lifetime": lifetime, "age": 0.0, "damage": 1.0,
		"homing": false, "btype": -1, "grazed": false, "boss_hit": false,
		"motion": motion.duplicate(true), "has_motion": not motion.is_empty(),
		"motion_triggered": false,
		"laser_warning_remaining": maxf(float(motion.get("warning_frames", 0.0)), 0.0),
		"laser_active_remaining": float(motion.get("active_frames", -1.0)),
	}
	if _active_stage() == 2:
		bullet_values["stage2_reflection_count"] = 0
		for field in ["stage2_source_event_id", "stage2_source_spawn_id", "stage2_source_enemy_id", "stage2_primitive", "stage2_routing", "stage2_source_phase_id", "stage2_source_owner_id"]:
			if stage2_source.has(field):
				var source_value = stage2_source[field]
				bullet_values[field] = source_value.duplicate(true) if source_value is Array or source_value is Dictionary else source_value
	var bullet_index: int = _spawn_bullet_values(bullet_values)
	_sync_bullet_world_compatibility_views()
	if bullet_index < 0:
		return false
	if btype == "laser" and audio_manager_ref:
		audio_manager_ref.play_sfx("laser_warning", -12.0)
	return true

func _stage_enemy_hp_mult() -> float:
	_resolve_singletons()
	if game_manager_ref and game_manager_ref.current_stage >= 1 and game_manager_ref.current_stage <= game_manager_ref.STAGE_MULTS.size():
		return float(game_manager_ref.STAGE_MULTS[game_manager_ref.current_stage - 1].enemy_hp)
	return 1.0

func _spawn_enemy_bullet_spec(spec: Dictionary, stage2_source: Dictionary = {}) -> void:
	_spawn_bullet_enemy(
		float(spec.position.x),
		float(spec.position.y),
		float(spec.velocity.x),
		float(spec.velocity.y),
		float(spec.radius),
		spec.get("color", Color.RED),
		String(spec.family_id),
		float(spec.get("lifetime", 350.0)),
		spec.get("motion", {}),
		stage2_source
	)

func _spawn_item(x: float, y: float, item_type: String = "power"):
	items.append({"alive":true,"collected":false,"x":x,"y":y,"type":item_type,"radius":9.0,"vy":-2.5,"vx":gameplay_rng.range_float(-0.3,0.3),"floating":true,"target_y":128.0,"drift_dir":0.0,"sway":gameplay_rng.range_float(0.0,TAU),"birth":15.0,"anim":gameplay_rng.range_float(0.0,TAU)})

func _spawn_enemy(x: float, y: float, hp: float = 5.0, pattern: String = "aimed", move: String = "straight", vx: float = 0.0, vy: float = 1.5, move_data: Dictionary = {}, strong: bool = false, drop_item_ids: Variant = null):
	var cfg: Dictionary = enemy_pattern_executor.spawn_config(pattern, hp, _stage_enemy_hp_mult(), strong)
	var ehp: float = float(cfg.hp)
	var radius := float(cfg.radius)
	var enemy := {"alive":true,"x":x,"y":y,"hp":ehp,"max_hp":ehp,"radius":radius,"vx":vx,"vy":vy,"move_timer":0.0,"move":move,"move_data":move_data.duplicate(true),"pattern":pattern,"shoot_timer":gameplay_rng.range_float(0.0,30.0),"shoot_phase":0,"strong":strong,"dying":false,"death_timer":0.0,"family_id":String(cfg.family_id),"drop_tier":String(cfg.drop_tier),"shoot_interval":float(cfg.shoot_interval)}
	if not _uses_m0_legacy_gameplay():
		var resolved_drop_item_ids: Array = []
		if drop_item_ids == null:
			resolved_drop_item_ids = LEGACY_ENEMY_DROP_IDS.duplicate()
		elif drop_item_ids is Array:
			resolved_drop_item_ids = drop_item_ids.duplicate(true)
		enemy["drop_item_ids"] = resolved_drop_item_ids
	enemies.append(enemy)

func _nearest_enemy(px: float, py: float) -> Vector2:
	var best: float = 99999.0; var best_v: Vector2 = Vector2(px, py - 100)
	for e in enemies:
		if e.alive and not e.dying:
			var d: float = Vector2(px, py).distance_to(Vector2(e.x, e.y))
			if d < best: best = d; best_v = Vector2(e.x, e.y)
	return best_v

func _update_title_menu() -> void:
	var entries: Array = ui_model.main_menu_entries()
	main_menu_cursor = _move_menu_cursor(main_menu_cursor, _menu_vertical_delta(), entries.size())
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	var selected_id: String = String(entries[main_menu_cursor].get("id", ""))
	match selected_id:
		"start":
			game_manager_ref.practice_mode = false
			_sync_character_cursor_to_selected()
			_set_ui_state("character_select")
		"practice":
			game_manager_ref.practice_mode = true
			practice_menu_cursor = clampi(int(game_manager_ref.practice_stage) - 1, 0, maxi(int(game_manager_ref.highest_reached_stage) - 1, 0))
			_set_ui_state("practice_select")
		"settings":
			_open_settings("title")
		"exit":
			_quit_runtime_safe()

func _update_practice_select_menu() -> void:
	var entries: Array = ui_model.practice_stage_entries(game_manager_ref.STAGE_NAMES, game_manager_ref.highest_reached_stage)
	practice_menu_cursor = clampi(practice_menu_cursor, 0, maxi(entries.size() - 1, 0))
	practice_menu_cursor = _move_menu_cursor(practice_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		_show_title()
		return
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	var selected_entry: Dictionary = entries[practice_menu_cursor]
	if String(selected_entry.get("id", "")) == "stage_2_phase_practice":
		phase_practice_menu_cursor = 0
		_set_ui_state(game_manager_ref.STATE_PHASE_PRACTICE_SELECT)
		return
	selected_stage2_phase_practice_id = ""
	game_manager_ref.practice_stage = int(selected_entry.get("stage", 1))
	_sync_character_cursor_to_selected()
	_set_ui_state("character_select")

func _update_phase_practice_select_menu() -> void:
	var entries: Array = ui_model.stage2_phase_practice_entries()
	phase_practice_menu_cursor = clampi(phase_practice_menu_cursor, 0, maxi(entries.size() - 1, 0))
	phase_practice_menu_cursor = _move_menu_cursor(phase_practice_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		_set_ui_state(game_manager_ref.STATE_PRACTICE_SELECT)
		return
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	selected_stage2_phase_practice_id = String(entries[phase_practice_menu_cursor].get("id", ""))
	game_manager_ref.practice_mode = true
	game_manager_ref.practice_stage = 2
	_sync_character_cursor_to_selected()
	_set_ui_state("character_select")

func _update_character_select_menu() -> void:
	var entries: Array = ui_model.protagonist_entries()
	character_menu_cursor = clampi(character_menu_cursor, 0, maxi(entries.size() - 1, 0))
	character_menu_cursor = _move_menu_cursor(character_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		if game_manager_ref.practice_mode:
			_set_ui_state(game_manager_ref.STATE_PHASE_PRACTICE_SELECT if not selected_stage2_phase_practice_id.is_empty() else game_manager_ref.STATE_PRACTICE_SELECT)
		else:
			_show_title()
		return
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	game_manager_ref.selected_protagonist_id = String(entries[character_menu_cursor].get("id", ""))
	shot_menu_cursor = 0
	_set_ui_state("shot_select")

func _update_shot_select_menu() -> void:
	var entries: Array = ui_model.shot_entries(String(game_manager_ref.selected_protagonist_id))
	shot_menu_cursor = clampi(shot_menu_cursor, 0, maxi(entries.size() - 1, 0))
	shot_menu_cursor = _move_menu_cursor(shot_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		_sync_character_cursor_to_selected()
		_set_ui_state("character_select")
		return
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	var selected_shot_id: String = String(entries[shot_menu_cursor].get("id", ""))
	game_manager_ref.selected_shot_id = selected_shot_id
	game_manager_ref.apply_selected_shot()
	if not selected_stage2_phase_practice_id.is_empty():
		if not _start_stage2_phase_practice(selected_stage2_phase_practice_id):
			game_manager_ref.state = "game_over"
		return
	_start_game()

func _update_settings_menu() -> void:
	var entries: Array = ui_model.settings_entries(game_manager_ref.settings)
	settings_menu_cursor = clampi(settings_menu_cursor, 0, maxi(entries.size() - 1, 0))
	settings_menu_cursor = _move_menu_cursor(settings_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		var return_state: String = String(game_manager_ref.settings_return_state)
		if return_state != game_manager_ref.STATE_PAUSED:
			_set_pause_audio(false)
		_set_ui_state(return_state if return_state != "" else "title")
		return
	if entries.is_empty():
		return
	var current_entry: Dictionary = entries[settings_menu_cursor]
	var current_id: String = String(current_entry.get("id", ""))
	var horizontal_delta: int = _menu_horizontal_delta()
	var changed: bool = false
	if horizontal_delta != 0 and String(current_entry.get("type", "")) == "range":
		var step: float = float(current_entry.get("step", 0.05))
		var minimum: float = float(current_entry.get("min", 0.0))
		var maximum: float = float(current_entry.get("max", 1.0))
		var current_value: float = float(game_manager_ref.settings.get(current_id, current_entry.get("value", minimum)))
		var next_value: float = clampf(current_value + step * horizontal_delta, minimum, maximum)
		game_manager_ref.settings[current_id] = snappedf(next_value, step)
		changed = true
	if _menu_confirm_pressed() and String(current_entry.get("type", "")) == "toggle":
		game_manager_ref.settings[current_id] = not bool(game_manager_ref.settings.get(current_id, current_entry.get("value", false)))
		changed = true
	if changed:
		_apply_runtime_settings()

func _update_pause_menu() -> void:
	var entries: Array = ui_model.pause_menu_entries()
	pause_menu_cursor = clampi(pause_menu_cursor, 0, maxi(entries.size() - 1, 0))
	pause_menu_cursor = _move_menu_cursor(pause_menu_cursor, _menu_vertical_delta(), entries.size())
	if _menu_cancel_pressed():
		_resume_gameplay()
		return
	if not _menu_confirm_pressed() or entries.is_empty():
		return
	var selected_id: String = String(entries[pause_menu_cursor].get("id", ""))
	match selected_id:
		"continue":
			_resume_gameplay()
		"restart_stage":
			_restart_current_stage()
		"settings":
			settings_menu_cursor = 0
			game_manager_ref.open_settings(game_manager_ref.STATE_PAUSED)
		"return_to_main_menu":
			_show_title()
		"exit_game":
			_quit_runtime_safe()

func _process(delta: float):
	_resolve_singletons()
	var gm = game_manager_ref
	var current_state: String = gm.state if gm else "title"
	if current_state in ["stage", "boss"]:
		if replay_runtime_mode != "playback":
			gameplay_input_buffer.sample_live_frame()
		_advance_gameplay_clock(delta)
	else:
		fixed_tick_clock.clear_accumulator()
		match current_state:
			"title":
				_update_title_menu()
			"practice_select":
				_update_practice_select_menu()
			"phase_practice_select":
				_update_phase_practice_select_menu()
			"character_select":
				_update_character_select_menu()
			"shot_select":
				_update_shot_select_menu()
			"settings":
				_update_settings_menu()
			"stage_clear":
				if Input.is_action_just_pressed("shoot"): _advance_stage()
			"final_clear", "game_over":
				if Input.is_action_just_pressed("shoot"): _show_title()
			"paused":
				_update_pause_menu()
	_sync_canvas_origin(String(gm.state if gm else "title"))
	_update_performance_counters()
	queue_redraw()

func _advance_gameplay_clock(frame_delta: float, sampled_frame: Dictionary = {}) -> int:
	if not sampled_frame.is_empty() and replay_runtime_mode != "playback":
		gameplay_input_buffer.sample_frame(sampled_frame)
	fixed_tick_clock.push_frame_delta(frame_delta)
	var executed_ticks := 0
	while fixed_tick_clock.pending_ticks > 0:
		if replay_runtime_mode == "playback" and not replay_data.has_next_frame():
			break
		if not fixed_tick_clock.consume_tick():
			break
		simulation_tick_index = fixed_tick_clock.tick_index
		if replay_runtime_mode == "playback":
			current_tick_input = gameplay_input_buffer.consume_injected_tick(simulation_tick_index, replay_data.next_frame())
		else:
			current_tick_input = gameplay_input_buffer.consume_tick(simulation_tick_index)
			if replay_runtime_mode == "recording":
				replay_data.record_tick(current_tick_input)
		var current_state := String(game_manager_ref.state if game_manager_ref else "title")
		match current_state:
			"stage":
				_update_stage(FixedTickClock.FIXED_DELTA_SECONDS)
			"boss":
				_update_boss(FixedTickClock.FIXED_DELTA_SECONDS)
			_:
				fixed_tick_clock.clear_accumulator()
				break
		executed_ticks += 1
		if String(game_manager_ref.state if game_manager_ref else "title") not in ["stage", "boss"]:
			fixed_tick_clock.clear_accumulator()
			break
	return executed_ticks

func _sync_canvas_origin(state: String) -> void:
	var gameplay_state := state in ["stage", "boss", "stage_clear", "final_clear", "game_over", "paused"]
	position = Vector2(0.0, HUD_HEIGHT if gameplay_state else 0.0)

func _update_stage(delta: float):
	if _active_stage() == 2:
		_update_stage2_main_flow(delta)
		return
	if bool(current_tick_input.get("pause", false)):
		pause_menu_cursor = 0
		_pause_gameplay(game_manager_ref.STATE_STAGE)
		return
	stage_timer += delta * 60.0
	_stage_waves(int(stage_timer))
	if stage_timer >= stage_controller.boss_time and not stage_controller.boss_spawned:
		stage_controller.boss_spawned = true
	_update_player(delta)
	_update_bullets(delta, _nearest_enemy(player_x, player_y))
	_update_enemies(delta)
	_update_items(delta)
	_update_combat_effects(delta)
	_check_collisions(false)
	if player_just_hit and not player_deathbomb_primed:
		if game_manager_ref.lives > 0: _respawn()
		else:
			if game_manager_ref.has_method("record_actual_miss"): game_manager_ref.record_actual_miss()
			player_just_hit = false
			game_manager_ref.state = "game_over"
			if audio_manager_ref: audio_manager_ref.fade_bgm(-30.0, 0.8)
	if stage_controller.boss_spawned and _count_alive_enemies() == 0:
		_enter_boss()

func _update_stage2_main_flow(delta: float) -> void:
	if stage2_encounter_controller == null or not stage2_encounter_controller.is_configured():
		_stage2_fail_closed(String(stage_controller.get("stage2_hard_error", "Stage 2 controller is unavailable")))
		return
	if bool(current_tick_input.get("pause", false)):
		pause_menu_cursor = 0
		_pause_gameplay(String(game_manager_ref.state))
		return
	var output: Dictionary = stage2_encounter_controller.advance(Vector2(player_x, player_y))
	if not bool(output.get("ok", false)):
		_stage2_fail_closed(String(output.get("error", stage2_encounter_controller.last_error())))
		return
	if not _consume_stage2_controller_output(output):
		return
	var telemetry: Dictionary = stage2_encounter_controller.telemetry_snapshot()
	stage_timer = float(telemetry.get("stage_runtime", {}).get("stage_tick", stage_timer))
	if stage2_encounter_controller.encounter_kind() == "complete":
		_finish_stage2_after_boss()
		return
	var encounter_active: bool = stage2_encounter_controller.encounter_kind() in ["midboss", "boss"]
	if encounter_active and not boss_alive:
		_sync_stage2_phase_boss()
	_update_player(delta)
	var bullet_target := Vector2(float(boss.get("x", _screen_center_x())), float(boss.get("y", _boss_anchor_y()))) if encounter_active and boss_alive else _nearest_enemy(player_x, player_y)
	_update_bullets(delta, bullet_target)
	if encounter_active:
		boss.anim = float(boss.get("anim", 0.0)) + 1.0
		boss.sway = float(boss.get("sway", 0.0)) + 1.0
		boss.card_shot = float(stage2_encounter_controller.active_phase_tick())
		var definition: Dictionary = stage2_encounter_controller.active_phase_definition()
		boss.card_timer = float(maxi(0, int(definition.get("timeout_ticks", 0)) - stage2_encounter_controller.active_phase_tick()))
	else:
		_update_enemies(delta)
	_update_items(delta)
	_update_combat_effects(delta)
	_check_collisions(encounter_active)
	if encounter_active and boss_alive and float(boss.get("hp", 0.0)) <= 0.0:
		var resolution: Dictionary = stage2_encounter_controller.resolve_active_phase("clear")
		if not bool(resolution.get("ok", false)):
			_stage2_fail_closed(String(resolution.get("error", stage2_encounter_controller.last_error())))
			return
		if not _consume_stage2_controller_output(resolution):
			return
		if stage2_encounter_controller.encounter_kind() == "complete":
			_finish_stage2_after_boss()
	_resolve_stage2_player_hit()

func _consume_stage2_controller_output(output: Dictionary) -> bool:
	var stage_events: Array = output.get("stage_events", [])
	for event_value in output.get("stage_events", []):
		if not (event_value is Dictionary):
			_stage2_fail_closed("Stage 2 controller emitted a malformed stage event")
			return false
		var event: Dictionary = event_value
		if not _stage2_begin_field_event(event):
			return false
		var event_ids: Array = stage_controller.get("stage2_event_ids", [])
		event_ids.append(String(event.get("id", "")))
		stage_controller["stage2_event_ids"] = event_ids
		var stage_records: Array = stage_controller.get("stage2_stage_event_records", [])
		stage_records.append(event.duplicate(true))
		stage_controller["stage2_stage_event_records"] = stage_records
		if not (event.get("gate") is Dictionary):
			var payload: Dictionary = event.get("payload", {})
			for spawn_value in payload.get("spawns", []):
				if not _spawn_stage2_authored_enemy(String(event.get("id", "")), spawn_value):
					return false
		if not _stage2_finish_field_event(event):
			return false
	if output.has("stage_tick") and stage_events.is_empty():
		var next_field_tick := int(stage_controller.get("stage2_field_tick", -1)) + 1
		if not _stage2_field_callback("advance", next_field_tick):
			return false
	for warning_value in output.get("warnings", []):
		var warning_records: Array = stage_controller.get("stage2_warning_records", [])
		warning_records.append(warning_value.duplicate(true))
		stage_controller["stage2_warning_records"] = warning_records
	for phase_event_value in output.get("events", []):
		var phase_event_records: Array = stage_controller.get("stage2_phase_event_records", [])
		phase_event_records.append(phase_event_value.duplicate(true))
		stage_controller["stage2_phase_event_records"] = phase_event_records
	for movement_value in output.get("boss_movements", []):
		var movement: Dictionary = movement_value
		var movement_records: Array = stage_controller.get("stage2_boss_movement_records", [])
		movement_records.append(movement.duplicate(true))
		stage_controller["stage2_boss_movement_records"] = movement_records
		_apply_stage2_boss_movement(movement)
	var validated_bullet_specs: Array[Dictionary] = []
	var active_definition: Dictionary = stage2_encounter_controller.active_phase_definition()
	var active_phase_id := String(active_definition.get("id", ""))
	var active_owner_id := String(active_definition.get("owner_id", ""))
	for bullet_spec_value in output.get("bullet_specs", []):
		if not (bullet_spec_value is Dictionary):
			_stage2_fail_closed("Stage 2 bullet producer emitted a malformed spec")
			return false
		var bullet_spec: Dictionary = bullet_spec_value
		var producer_phase_id := String(bullet_spec.get("phase_id", ""))
		if producer_phase_id == "" or producer_phase_id != active_phase_id or active_owner_id == "":
			_stage2_fail_closed("Stage 2 bullet producer phase does not match active phase ownership")
			return false
		validated_bullet_specs.append(bullet_spec)
	for validated_spec in validated_bullet_specs:
		_spawn_enemy_bullet_spec(validated_spec, {
			"stage2_source_phase_id": String(validated_spec.phase_id),
			"stage2_source_owner_id": active_owner_id,
		})
	for resolution_value in output.get("phase_resolutions", []):
		var resolution_records: Array = stage_controller.get("stage2_phase_resolutions", [])
		resolution_records.append(resolution_value.duplicate(true))
		stage_controller["stage2_phase_resolutions"] = resolution_records
		_clear_hostile_bullets()
	if not (output.get("phase_started", {}) as Dictionary).is_empty():
		_sync_stage2_phase_boss()
	var gate_completion: Dictionary = output.get("gate_completion", {})
	if not gate_completion.is_empty():
		if String(gate_completion.get("encounter_kind", "")) == "midboss":
			boss_alive = false
			boss = {}
			game_manager_ref.state = "stage"
		else:
			boss_alive = false
	return String(stage_controller.get("stage2_field_hard_error", "")) == ""

func _stage2_begin_field_event(event: Dictionary) -> bool:
	var event_id := String(event.get("id", ""))
	var payload_value = event.get("payload")
	if event_id == "" or not (payload_value is Dictionary) or typeof((payload_value as Dictionary).get("authored_tick")) != TYPE_INT:
		_stage2_fail_closed("Stage 2 field event is missing its canonical authored tick")
		return false
	var authored_tick := int((payload_value as Dictionary).authored_tick)
	if event_id == "s2_b12":
		if not _stage2_remove_runtime_source_if_live("s2_midboss_abacus_tsukumogami", authored_tick, "midboss_gate_exit"):
			return false
		if not _stage2_field_callback("clear_field_bullets", authored_tick, {"reason": "midboss_gate_exit"}):
			return false
	var carryover: Variant = _stage2_actual_live_carryover(event_id)
	if carryover == null:
		return false
	if not _stage2_field_callback("activate_event", authored_tick, {"event_id": event_id, "active_entity_ids": carryover}):
		return false
	var activated_ids: Array = stage_controller.get("stage2_field_activated_event_ids", [])
	if event_id in activated_ids:
		_stage2_fail_closed("Stage 2 field event activated more than once: %s" % event_id)
		return false
	activated_ids.append(event_id)
	stage_controller["stage2_field_activated_event_ids"] = activated_ids
	return true

func _stage2_finish_field_event(event: Dictionary) -> bool:
	var event_id := String(event.get("id", ""))
	var payload: Dictionary = event.get("payload", {})
	var authored_tick := int(payload.get("authored_tick", -1))
	if event_id in ["s2_b06", "s2_b18"]:
		if not _stage2_remove_all_field_enemy_sources(authored_tick, "%s_gate_entry" % event_id):
			return false
		if not _stage2_field_callback("clear_field_bullets", authored_tick, {"reason": "%s_gate_entry" % event_id}):
			return false
	return _stage2_field_callback("advance", authored_tick)

func _stage2_actual_live_carryover(event_id: String) -> Variant:
	var package: Dictionary = stage_director.stage2_package()
	var metadata: Dictionary = package.get("metadata", {})
	var event_metadata: Dictionary = metadata.get("event_metadata", {})
	var event_record: Dictionary = event_metadata.get(event_id, {})
	var source_event: Dictionary = event_record.get("source_event", {})
	var formation: Dictionary = source_event.get("formation", {})
	var declared_value = formation.get("active_entity_ids")
	if not (declared_value is Array):
		_stage2_fail_closed("Stage 2 carryover metadata is unavailable for %s" % event_id)
		return null
	var runtime_active: Array = stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", [])
	var result: Array = []
	for source_value in declared_value:
		if typeof(source_value) != TYPE_STRING:
			_stage2_fail_closed("Stage 2 carryover metadata contains a malformed source")
			return null
		var source_id := String(source_value)
		var live_in_main := source_id == "s2_midboss_abacus_tsukumogami"
		if not live_in_main:
			for enemy_value in enemies:
				var enemy: Dictionary = enemy_value
				if bool(enemy.get("stage2_field_owned", false)) and String(enemy.get("stage2_spawn_id", "")) == source_id and bool(enemy.get("alive", false)) and not bool(enemy.get("dying", false)):
					live_in_main = true
					break
		if live_in_main:
			if source_id not in runtime_active:
				_stage2_fail_closed("Stage 2 live source diverged from the field runtime: %s" % source_id)
				return null
			result.append(source_id)
	return result

func _stage2_remove_runtime_source_if_live(spawn_id: String, authored_tick: int, reason: String) -> bool:
	var active_sources: Array = stage2_field_topology_runtime.telemetry_snapshot().get("active_source_ids", [])
	if spawn_id not in active_sources:
		return true
	return _stage2_field_callback("remove_source", authored_tick, {"spawn_id": spawn_id, "reason": reason})

func _stage2_remove_all_field_enemy_sources(authored_tick: int, reason: String) -> bool:
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("stage2_field_owned", false)) or not bool(enemy.get("alive", false)) or bool(enemy.get("stage2_source_removal_forwarded", false)):
			continue
		var callback_kind := "accept_defeat" if bool(enemy.get("dying", false)) else "remove_source"
		var payload := {"spawn_id": String(enemy.get("stage2_spawn_id", ""))}
		if callback_kind == "remove_source":
			payload["reason"] = reason
		if not _stage2_field_callback(callback_kind, authored_tick, payload):
			return false
		enemy["stage2_source_defeat_forwarded"] = callback_kind == "accept_defeat"
		enemy["stage2_source_removal_forwarded"] = true
		enemy.alive = false
	return true

func _stage2_field_callback(kind: String, stage_tick: int, payload: Dictionary = {}) -> bool:
	if String(stage_controller.get("stage2_field_hard_error", "")) != "":
		return false
	if stage2_field_topology_runtime == null or not stage2_field_topology_runtime.is_configured():
		_stage2_reject_field_callback("Stage 2 field topology runtime is unavailable")
		return false
	if not _stage2_validate_live_field_bindings():
		_stage2_reject_field_callback("Stage 2 field runtime, UID binding, and BulletWorld diverged before callback")
		return false
	var live_runtime_snapshot: Dictionary = stage2_field_topology_runtime.capture_snapshot()
	if live_runtime_snapshot.is_empty():
		_stage2_reject_field_callback("Stage 2 field topology runtime snapshot is unavailable")
		return false
	var candidate_runtime: RefCounted = Stage2FieldTopologyRuntime.new()
	var field_contract: Dictionary = stage_director.stage2_field_topology_contract() if stage_director != null and stage_director.has_method("stage2_field_topology_contract") else {}
	if field_contract.is_empty() or not candidate_runtime.configure(field_contract, gameplay_difficulty, String(stage_controller.get("stage2_field_run_uid", ""))) or not candidate_runtime.restore_snapshot(live_runtime_snapshot):
		_stage2_reject_field_callback("Stage 2 field callback could not restore a disposable runtime")
		return false
	var candidate_world: RefCounted = BulletWorld.new()
	var world_restore: Dictionary = candidate_world.restore_state(bullet_world.capture_state())
	if not bool(world_restore.get("ok", false)):
		_stage2_reject_field_callback("Stage 2 field callback could not restore a disposable BulletWorld")
		return false
	var candidate_stage_controller: Dictionary = stage_controller.duplicate(true)
	var sequence := int(stage_controller.get("stage2_field_event_sequence", -1)) + 1
	candidate_stage_controller["stage2_field_event_sequence"] = sequence
	var output: Dictionary = {}
	match kind:
		"activate_event":
			output = candidate_runtime.activate_event(String(payload.get("event_id", "")), payload.get("active_entity_ids", []), stage_tick, sequence)
		"remove_source":
			output = candidate_runtime.remove_source(String(payload.get("spawn_id", "")), stage_tick, sequence, String(payload.get("reason", "despawn")))
		"accept_defeat":
			output = candidate_runtime.accept_defeat(String(payload.get("spawn_id", "")), stage_tick, sequence)
		"clear_field_bullets":
			output = candidate_runtime.clear_field_bullets(stage_tick, sequence, String(payload.get("reason", "explicit_clear")))
		"observe_graze":
			output = candidate_runtime.observe_graze(String(payload.get("bullet_uid", "")), stage_tick, sequence)
		"advance":
			output = candidate_runtime.advance(stage_tick, sequence)
		_:
			_stage2_reject_field_callback("Unknown Stage 2 field callback: %s" % kind)
			return false
	if typeof(output.get("ok")) != TYPE_BOOL or not bool(output.ok):
		var runtime_error := String(output.get("error", ""))
		if runtime_error == "":
			runtime_error = candidate_runtime.last_error()
		_stage2_reject_field_callback(runtime_error)
		return false
	if not _stage2_preflight_field_output(output, stage_tick, sequence, candidate_runtime, candidate_world, candidate_stage_controller):
		_stage2_reject_field_callback("Stage 2 field callback output failed transactional preflight: %s" % kind)
		return false
	# Apply only to disposable owners. The live runtime, cursor, UID ledger,
	# bindings, and slots remain untouched until every output has been consumed.
	var live_stage_controller := stage_controller
	var live_bullet_world := bullet_world
	var live_field_runtime := stage2_field_topology_runtime
	stage_controller = candidate_stage_controller
	bullet_world = candidate_world
	stage2_field_topology_runtime = candidate_runtime
	_sync_bullet_world_compatibility_views()
	var consumed := _consume_stage2_field_output(output)
	if kind == "advance":
		stage_controller["stage2_field_tick"] = stage_tick
	var candidate_valid := consumed and _stage2_validate_live_field_bindings()
	candidate_stage_controller = stage_controller
	candidate_world = bullet_world
	candidate_runtime = stage2_field_topology_runtime
	stage_controller = live_stage_controller
	bullet_world = live_bullet_world
	stage2_field_topology_runtime = live_field_runtime
	_sync_bullet_world_compatibility_views()
	if not candidate_valid:
		_stage2_reject_field_callback("Stage 2 field callback could not commit its isolated output: %s" % kind)
		return false
	# No user callback can observe the assignment sequence, so these three
	# validated owners become the live aggregate as one synchronous commit.
	stage_controller = candidate_stage_controller
	bullet_world = candidate_world
	stage2_field_topology_runtime = candidate_runtime
	_sync_bullet_world_compatibility_views()
	return true

func _stage2_preflight_field_output(output: Dictionary, expected_stage_tick: int, expected_sequence: int, candidate_runtime: RefCounted, candidate_world: RefCounted, candidate_stage_controller: Dictionary) -> bool:
	if output.is_empty() or typeof(output.get("stage_tick")) != TYPE_INT or int(output.stage_tick) != expected_stage_tick:
		return false
	if typeof(output.get("event_sequence")) != TYPE_INT or int(output.event_sequence) != expected_sequence:
		return false
	if not (output.get("telemetry_snapshot") is Dictionary):
		return false
	var runtime_telemetry: Dictionary = output.telemetry_snapshot
	if not (runtime_telemetry.get("active_source_ids") is Array) or not (runtime_telemetry.get("active_bullet_uids") is Array) or not (runtime_telemetry.get("hard_state") is Dictionary) or not (runtime_telemetry.get("counts") is Dictionary):
		return false
	for key in STAGE2_FIELD_OUTPUT_ARRAYS:
		if not (output.get(key) is Array):
			return false
		for record_value in output[key]:
			if not (record_value is Dictionary):
				return false
	var bindings_value = candidate_stage_controller.get("stage2_field_uid_to_slot")
	if not (bindings_value is Dictionary):
		return false
	var planned_bindings: Dictionary = (bindings_value as Dictionary).duplicate(true)
	var next_compatibility_uid = candidate_stage_controller.get("stage2_next_bullet_uid")
	if typeof(next_compatibility_uid) != TYPE_INT or int(next_compatibility_uid) <= 0:
		return false
	var world_pool: Array = candidate_world.pool
	var active_field_slot_count := 0
	var compatibility_uids := {}
	for active_slot_value in candidate_world.active_order():
		if typeof(active_slot_value) != TYPE_INT:
			return false
		var active_slot := int(active_slot_value)
		if active_slot < 0 or active_slot >= world_pool.size():
			return false
		var active_bullet: Dictionary = world_pool[active_slot]
		var active_uid = active_bullet.get("stage2_bullet_uid")
		if bool(active_bullet.get("stage2_field_owned", false)):
			if typeof(active_uid) != TYPE_STRING or not planned_bindings.has(String(active_uid)):
				return false
			var active_binding = planned_bindings[String(active_uid)]
			if typeof(active_binding) != TYPE_INT or int(active_binding) != active_slot:
				return false
			active_field_slot_count += 1
		else:
			if typeof(active_uid) != TYPE_INT or int(active_uid) <= 0 or int(active_uid) >= int(next_compatibility_uid) or compatibility_uids.has(int(active_uid)):
				return false
			compatibility_uids[int(active_uid)] = true
	if active_field_slot_count != planned_bindings.size():
		return false
	var occupied_field_slots := {}
	for uid_value in planned_bindings.keys():
		if typeof(uid_value) != TYPE_STRING or typeof(planned_bindings[uid_value]) != TYPE_INT:
			return false
		var uid := String(uid_value)
		var slot := int(planned_bindings[uid_value])
		if slot < 0 or slot >= world_pool.size() or occupied_field_slots.has(slot):
			return false
		var bullet: Dictionary = world_pool[slot]
		if not bool(bullet.get("active", false)) or not bool(bullet.get("stage2_field_owned", false)) or String(bullet.get("stage2_bullet_uid", "")) != uid:
			return false
		occupied_field_slots[slot] = true
	var removal_uid_lookup := {}
	for removal_value in output.bullet_removals:
		var removal: Dictionary = removal_value
		if typeof(removal.get("bullet_uid")) != TYPE_STRING:
			return false
		removal_uid_lookup[String(removal.bullet_uid)] = true
	for update_value in output.bullet_updates:
		var update: Dictionary = update_value
		if not _stage2_field_update_is_valid(update, candidate_runtime):
			return false
		if int(update.stage_tick) > expected_stage_tick or int(update.event_sequence) > expected_sequence:
			return false
		var update_uid := String(update.stage2_bullet_uid)
		if not planned_bindings.has(update_uid) or typeof(planned_bindings[update_uid]) != TYPE_INT:
			return false
		var update_slot := int(planned_bindings[update_uid])
		if update_slot < 0 or update_slot >= world_pool.size():
			return false
		var update_target: Dictionary = world_pool[update_slot]
		if not bool(update_target.get("active", false)) or String(update_target.get("stage2_bullet_uid", "")) != update_uid:
			return false
		var updated_runtime_bullet: Dictionary = candidate_runtime.bullet_state(update_uid)
		if updated_runtime_bullet.is_empty():
			if not removal_uid_lookup.has(update_uid):
				return false
		else:
			if not _stage2_field_record_matches_runtime(update, updated_runtime_bullet):
				return false
			if update.position != updated_runtime_bullet.get("position") or update.velocity_px_per_second != updated_runtime_bullet.get("velocity_px_per_second"):
				return false
	for removal_value in output.bullet_removals:
		var removal: Dictionary = removal_value
		var removal_uid := String(removal.bullet_uid)
		if typeof(removal.get("stage_tick")) != TYPE_INT or int(removal.stage_tick) < 0 or int(removal.stage_tick) > expected_stage_tick:
			return false
		if typeof(removal.get("event_sequence")) != TYPE_INT or int(removal.event_sequence) < 0 or typeof(removal.get("reason")) != TYPE_STRING or String(removal.reason) == "":
			return false
		if not planned_bindings.has(removal_uid) or typeof(planned_bindings[removal_uid]) != TYPE_INT:
			return false
		var removal_slot := int(planned_bindings[removal_uid])
		if removal_slot < 0 or removal_slot >= world_pool.size():
			return false
		var removal_target: Dictionary = world_pool[removal_slot]
		if not bool(removal_target.get("active", false)) or String(removal_target.get("stage2_bullet_uid", "")) != removal_uid:
			return false
		if not candidate_runtime.bullet_state(removal_uid).is_empty():
			return false
		planned_bindings.erase(removal_uid)
		occupied_field_slots.erase(removal_slot)
	var constructions: Array = output.bullet_constructions
	if candidate_world.active_order().size() - output.bullet_removals.size() + constructions.size() > int(candidate_world.hard_capacity):
		return false
	var construction_uids := {}
	for construction_value in constructions:
		var construction: Dictionary = construction_value
		if not _stage2_field_construction_is_valid_for_runtime(construction, candidate_runtime):
			return false
		if int(construction.stage2_bullet_spawn_tick) > expected_stage_tick:
			return false
		var construction_uid := String(construction.stage2_bullet_uid)
		if planned_bindings.has(construction_uid) or construction_uids.has(construction_uid):
			return false
		var visual := _stage2_field_visual_for_primitive(String(construction.stage2_primitive))
		if visual.is_empty() or typeof(visual.get("family_id")) != TYPE_STRING or String(visual.family_id) == "":
			return false
		if typeof(visual.get("radius")) not in [TYPE_INT, TYPE_FLOAT] or float(visual.radius) <= 0.0 or is_nan(float(visual.radius)) or is_inf(float(visual.radius)) or not (visual.get("color") is Color):
			return false
		var constructed_runtime_bullet: Dictionary = candidate_runtime.bullet_state(construction_uid)
		if constructed_runtime_bullet.is_empty() or not _stage2_field_record_matches_runtime(construction, constructed_runtime_bullet):
			return false
		if construction.position != constructed_runtime_bullet.get("position") or construction.velocity_px_per_second != constructed_runtime_bullet.get("velocity_px_per_second"):
			return false
		construction_uids[construction_uid] = true
		planned_bindings[construction_uid] = -1
	var planned_uids: Array = planned_bindings.keys()
	planned_uids.sort()
	var runtime_uids: Array = (runtime_telemetry.active_bullet_uids as Array).duplicate()
	runtime_uids.sort()
	return planned_uids == runtime_uids

func _consume_stage2_field_output(output: Dictionary) -> bool:
	if output.is_empty():
		return false
	for key in STAGE2_FIELD_OUTPUT_ARRAYS:
		if not (output.get(key) is Array):
			return false
	for update_value in output.bullet_updates:
		if not (update_value is Dictionary) or not _stage2_apply_field_bullet_update(update_value):
			return false
	for removal_value in output.bullet_removals:
		if not (removal_value is Dictionary) or not _stage2_apply_field_bullet_removal(removal_value):
			return false
	if not _stage2_materialize_field_constructions(output.bullet_constructions):
		return false
	for warning_value in output.warnings:
		if not (warning_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_warning_records", warning_value)
	for activation_value in output.source_activations:
		if not (activation_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_source_activation_records", activation_value)
	for source_removal_value in output.source_removals:
		if not (source_removal_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_source_removals", source_removal_value)
	for transition_value in output.state_transitions:
		if not (transition_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_state_transitions", transition_value)
	for projection_value in output.score_route_callbacks:
		if not (projection_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_score_projections", projection_value)
	for telemetry_value in output.telemetry:
		if not (telemetry_value is Dictionary):
			return false
		_stage2_append_bounded("stage2_field_telemetry", telemetry_value)
	if not (output.get("telemetry_snapshot") is Dictionary):
		return false
	var runtime_telemetry: Dictionary = output.telemetry_snapshot
	if not (runtime_telemetry.get("active_source_ids") is Array) or not (runtime_telemetry.get("hard_state") is Dictionary) or not (runtime_telemetry.get("counts") is Dictionary):
		return false
	_stage2_append_bounded("stage2_field_telemetry", {
		"kind": "runtime_snapshot",
		"stage_tick": int(output.get("stage_tick", -1)),
		"event_sequence": int(output.get("event_sequence", -1)),
		"current_event_id": String(runtime_telemetry.get("current_event_id", "")),
		"active_source_ids": (runtime_telemetry.get("active_source_ids", []) as Array).duplicate(),
		"active_bullet_count": int(runtime_telemetry.get("active_bullet_count", 0)),
		"hard_state": (runtime_telemetry.get("hard_state", {}) as Dictionary).duplicate(true),
		"counts": (runtime_telemetry.get("counts", {}) as Dictionary).duplicate(true),
	})
	return true

func _stage2_append_bounded(key: String, value: Dictionary) -> void:
	var records: Array = stage_controller.get(key, [])
	records.append(value.duplicate(true))
	while records.size() > STAGE2_FIELD_RECORD_LIMIT:
		records.pop_front()
	stage_controller[key] = records

func _stage2_materialize_field_constructions(constructions: Array) -> bool:
	if constructions.size() > int(bullet_world.hard_capacity) - bullet_world.active_order().size():
		return false
	var validated: Array[Dictionary] = []
	for construction_value in constructions:
		if not (construction_value is Dictionary) or not _stage2_field_construction_is_valid(construction_value):
			return false
		validated.append(construction_value)
	var spawned_slots: Array[int] = []
	var bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
	for construction in validated:
		var uid := String(construction.stage2_bullet_uid)
		var visual := _stage2_field_visual_for_primitive(String(construction.stage2_primitive))
		if visual.is_empty() or bindings.has(uid):
			for spawned_slot in spawned_slots:
				bullet_world.retire_slot(spawned_slot)
			return false
		var position: Array = construction.position
		var velocity: Array = construction.velocity_px_per_second
		var values := {
			"x": float(position[0]), "y": float(position[1]),
			"vx": float(velocity[0]) / 60.0, "vy": float(velocity[1]) / 60.0,
			"radius": float(visual.radius), "color": visual.color, "type": String(visual.family_id),
			"lifetime": float(int(construction.stage2_lifetime_end_tick) - int(construction.stage2_bullet_spawn_tick)),
			"age": 0.0, "damage": 1.0, "homing": false, "btype": -1, "grazed": false,
			"boss_hit": false, "motion": {}, "has_motion": false, "motion_triggered": false,
			"stage2_field_owned": true,
			"stage2_defer_linear_step_tick": int(construction.stage2_bullet_spawn_tick),
		}
		for seam_field in STAGE2_FIELD_SEAM_FIELDS:
			values[seam_field] = construction[seam_field]
		var slot := int(bullet_world.spawn_bullet(values))
		if slot < 0:
			for spawned_slot in spawned_slots:
				bullet_world.retire_slot(spawned_slot)
			return false
		spawned_slots.append(slot)
		bindings[uid] = slot
	stage_controller["stage2_field_uid_to_slot"] = bindings
	_sync_bullet_world_compatibility_views()
	return true

func _stage2_field_construction_is_valid(construction: Dictionary) -> bool:
	return _stage2_field_construction_is_valid_for_runtime(construction, stage2_field_topology_runtime)

func _stage2_field_construction_is_valid_for_runtime(construction: Dictionary, runtime: RefCounted) -> bool:
	if not _stage2_field_record_has_exact_seam(construction) or not _stage2_field_point_is_valid(construction.get("position")) or not _stage2_field_point_is_valid(construction.get("velocity_px_per_second")):
		return false
	if not _stage2_field_seam_is_valid(construction, runtime):
		return false
	return int(construction.stage2_bullet_spawn_tick) <= int(construction.stage2_collision_enable_tick) and int(construction.stage2_lifetime_end_tick) >= int(construction.stage2_collision_enable_tick)

func _stage2_field_update_is_valid(update: Dictionary, runtime: RefCounted) -> bool:
	if not _stage2_field_record_has_exact_seam(update) or not _stage2_field_point_is_valid(update.get("position")) or not _stage2_field_point_is_valid(update.get("velocity_px_per_second")):
		return false
	if not _stage2_field_seam_is_valid(update, runtime):
		return false
	if typeof(update.get("stage_tick")) != TYPE_INT or int(update.stage_tick) < 0:
		return false
	if typeof(update.get("event_sequence")) != TYPE_INT or int(update.event_sequence) < 0:
		return false
	return typeof(update.get("update_kind")) == TYPE_STRING and String(update.update_kind) in ["seed_activation", "rebound_turn"]

func _stage2_field_seam_is_valid(record: Dictionary, runtime: RefCounted) -> bool:
	if runtime == null or typeof(record.get("stage2_bullet_uid")) != TYPE_STRING or not runtime.validate_bullet_uid(String(record.stage2_bullet_uid)):
		return false
	for field in STAGE2_FIELD_SOURCE_FIELDS:
		if typeof(record[field]) != TYPE_STRING or String(record[field]) == "":
			return false
	for field in ["stage2_reflection_count", "stage2_bullet_spawn_tick", "stage2_collision_enable_tick", "stage2_lifetime_end_tick"]:
		if typeof(record[field]) != TYPE_INT or int(record[field]) < 0:
			return false
	var first_reflection = record.get("stage2_first_reflection_tick")
	if first_reflection != null and (typeof(first_reflection) != TYPE_INT or int(first_reflection) < int(record.stage2_bullet_spawn_tick)):
		return false
	var reflection_surface = record.get("stage2_last_reflection_surface_id")
	if reflection_surface != null and (typeof(reflection_surface) != TYPE_STRING or String(reflection_surface) == ""):
		return false
	return true

func _stage2_field_record_matches_runtime(record: Dictionary, runtime_bullet: Dictionary) -> bool:
	for seam_field in STAGE2_FIELD_SEAM_FIELDS:
		if not runtime_bullet.has(seam_field) or record[seam_field] != runtime_bullet[seam_field]:
			return false
	return true

func _stage2_field_record_has_exact_seam(record: Dictionary) -> bool:
	for field in STAGE2_FIELD_SEAM_FIELDS:
		if not record.has(field):
			return false
	return true

func _stage2_field_point_is_valid(value: Variant) -> bool:
	if not (value is Array) or (value as Array).size() != 2:
		return false
	for component in value:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(component)) or is_inf(float(component)):
			return false
	return true

func _stage2_field_visual_for_primitive(primitive: String) -> Dictionary:
	var family_id: String = String({
		"rebound_bead": "circle",
		"grid_edge": "needle",
		"lane_fan": "rice",
		"delayed_seed": "spiral_seed",
	}.get(primitive, ""))
	if String(family_id) == "" or game_database_ref == null:
		return {}
	var family: Dictionary = game_database_ref.bullet_family_by_id(String(family_id))
	if family.is_empty():
		return {}
	return {"family_id": String(family_id), "radius": float(family.get("radius", 5.0)), "color": family.get("color", Color.RED)}

func _stage2_apply_field_bullet_update(update: Dictionary) -> bool:
	if not _stage2_field_update_is_valid(update, stage2_field_topology_runtime):
		return false
	var uid := String(update.get("stage2_bullet_uid", ""))
	var bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
	if typeof(update.get("stage2_bullet_uid")) != TYPE_STRING or not bindings.has(uid) or typeof(bindings[uid]) != TYPE_INT:
		return false
	var slot := int(bindings[uid])
	if slot < 0 or slot >= bullet_pool.size() or not bool(bullet_pool[slot].get("active", false)) or String(bullet_pool[slot].get("stage2_bullet_uid", "")) != uid:
		return false
	var bullet: Dictionary = bullet_pool[slot]
	var position: Array = update.position
	var velocity: Array = update.velocity_px_per_second
	bullet.x = float(position[0])
	bullet.y = float(position[1])
	bullet.vx = float(velocity[0]) / 60.0
	bullet.vy = float(velocity[1]) / 60.0
	bullet["stage2_defer_linear_step_tick"] = int(update.stage_tick)
	for seam_field in STAGE2_FIELD_SEAM_FIELDS:
		bullet[seam_field] = update[seam_field]
	return true

func _stage2_apply_field_bullet_removal(removal: Dictionary) -> bool:
	if typeof(removal.get("bullet_uid")) != TYPE_STRING:
		return false
	var uid := String(removal.bullet_uid)
	var bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
	if not bindings.has(uid) or typeof(bindings[uid]) != TYPE_INT:
		return false
	var slot := int(bindings[uid])
	if slot < 0 or slot >= bullet_pool.size() or not bool(bullet_pool[slot].get("active", false)) or String(bullet_pool[slot].get("stage2_bullet_uid", "")) != uid:
		return false
	if not bullet_world.retire_slot(slot):
		return false
	bindings.erase(uid)
	stage_controller["stage2_field_uid_to_slot"] = bindings
	_sync_bullet_world_compatibility_views()
	return true

func _stage2_validate_live_field_bindings() -> bool:
	if stage2_field_topology_runtime == null or stage2_field_topology_runtime.has_hard_error():
		return false
	var active_uids: Array = stage2_field_topology_runtime.telemetry_snapshot().get("active_bullet_uids", [])
	var bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
	if active_uids.size() != bindings.size():
		return false
	for uid_value in active_uids:
		var uid := String(uid_value)
		if not bindings.has(uid) or typeof(bindings[uid]) != TYPE_INT:
			return false
		var slot := int(bindings[uid])
		if slot < 0 or slot >= bullet_pool.size():
			return false
		var bullet: Dictionary = bullet_pool[slot]
		var runtime_bullet: Dictionary = stage2_field_topology_runtime.bullet_state(uid)
		if not bool(bullet.get("active", false)) or not bool(bullet.get("stage2_field_owned", false)) or runtime_bullet.is_empty():
			return false
		for seam_field in STAGE2_FIELD_SEAM_FIELDS:
			if not bullet.has(seam_field) or bullet[seam_field] != runtime_bullet.get(seam_field):
				return false
	return true

func _spawn_stage2_authored_enemy(event_id: String, spawn_value: Variant) -> bool:
	if not (spawn_value is Dictionary):
		_stage2_fail_closed("Stage 2 authored enemy spawn is malformed")
		return false
	var spawn: Dictionary = spawn_value
	var movement: Dictionary = spawn.get("movement", {})
	var authored_pattern: Dictionary = spawn.get("pattern", {})
	var primitive := String(authored_pattern.get("primitive", ""))
	var spawn_id := String(spawn.get("id", ""))
	var field_definition: Dictionary = stage2_field_topology_runtime.definition_for_spawn(spawn_id)
	if field_definition.is_empty() or String(field_definition.get("event_id", "")) != event_id or String(field_definition.get("enemy_id", "")) != String(spawn.get("enemy_id", "")):
		_stage2_fail_closed("Stage 2 authored source is missing from the field contract: %s" % spawn_id)
		return false
	var field_source: Dictionary = field_definition.get("source", {})
	var field_pattern: Dictionary = field_source.get("pattern", {})
	if String(field_pattern.get("primitive", "")) != primitive or String(field_pattern.get("routing", "")) != String(authored_pattern.get("routing", "")):
		_stage2_fail_closed("Stage 2 authored source diverged from the field contract: %s" % spawn_id)
		return false
	var field_owned := String(authored_pattern.get("routing", "")) != "phase_owned"
	var translated_pattern := _stage2_legacy_pattern_for_primitive(primitive)
	var cfg: Dictionary = enemy_pattern_executor.spawn_config(translated_pattern, 5.0, _stage_enemy_hp_mult(), false)
	var origin: Vector2 = spawn.get("position", Vector2.ZERO)
	var destination: Vector2 = movement.get("to", origin)
	var duration_ticks := maxi(1, int(movement.get("duration_ticks", 1)))
	var hp := float(cfg.get("hp", 5.0))
	var enemy := {
		"alive": true,
		"x": origin.x,
		"y": origin.y,
		"hp": hp,
		"max_hp": hp,
		"radius": float(cfg.get("radius", 14.0)),
		"vx": (destination.x - origin.x) / float(duration_ticks),
		"vy": (destination.y - origin.y) / float(duration_ticks),
		"move_timer": 0.0,
		"move": "stage2_authored",
		"move_data": {
			"path": String(movement.get("path", "")),
			"origin": origin,
			"to": destination,
			"duration_ticks": duration_ticks,
		},
		"pattern": translated_pattern,
		"authored_pattern": authored_pattern.duplicate(true),
		"shoot_timer": float(maxi(0, int(authored_pattern.get("start_delay_ticks", 0)))),
		"shoot_phase": 0,
		"strong": false,
		"dying": false,
		"death_timer": 0.0,
		"family_id": String(cfg.get("family_id", "low_yokai")),
		"drop_tier": String(cfg.get("drop_tier", "standard")),
		"shoot_interval": float(maxi(1, int(authored_pattern.get("interval_ticks", 60)))),
		"drop_item_ids": (spawn.get("drop_item_ids", []) as Array).duplicate(true),
		"stage2_event_id": event_id,
		"stage2_spawn_id": spawn_id,
		"source_enemy_id": String(spawn.get("enemy_id", "")),
		"stage2_field_owned": field_owned,
		"stage2_source_defeat_forwarded": false,
		"stage2_source_removal_forwarded": false,
	}
	enemies.append(enemy)
	var spawn_ids: Array = stage_controller.get("stage2_spawn_ids", [])
	spawn_ids.append(spawn_id)
	stage_controller["stage2_spawn_ids"] = spawn_ids
	return true

func _stage2_legacy_pattern_for_primitive(primitive: String) -> String:
	match primitive:
		"rebound_bead":
			return "aimed"
		"grid_edge":
			return "spread"
		"lane_fan":
			return "downward"
		"delayed_seed":
			return "mist_delay"
		"rhythm_pulse":
			return "rhythm"
	return "aimed"

func _sync_stage2_phase_boss() -> void:
	var definition: Dictionary = stage2_encounter_controller.active_phase_definition()
	if definition.is_empty():
		return
	if not boss_alive:
		boss = boss_state_machine.create_initial_state(_screen_center_x(), _boss_anchor_y(), 0.0)
		_transition_boss_phase(BossStateMachine.PHASE_ACTIVE)
		boss.entered = true
		boss_alive = true
		enemies.clear()
		_clear_hostile_bullets()
	var phase_hp := float(definition.get("base_hp", 1.0))
	var timeout_ticks := int(definition.get("timeout_ticks", 1))
	var card := {
		"id": String(definition.get("id", "")),
		"name": String(definition.get("display_name", "")),
		"kind": String(definition.get("kind", "nonspell")),
		"hp": phase_hp,
		"base_hp": phase_hp,
		"time": float(timeout_ticks) / 60.0,
		"pattern": String(definition.get("id", "")),
		"boss_id": String(definition.get("owner_id", "")),
		"stage_index": 2,
	}
	boss.cards = [card]
	boss.card_idx = 0
	boss.card_name = String(card.name)
	boss.card_hp = phase_hp
	boss.max_hp = phase_hp
	boss.hp = phase_hp
	boss.card_timer = float(maxi(0, timeout_ticks - stage2_encounter_controller.active_phase_tick()))
	boss.card_shot = float(stage2_encounter_controller.active_phase_tick())
	boss.phase = BossStateMachine.PHASE_ACTIVE
	boss.entered = true
	boss.declaring = false
	boss.alive = true
	boss["stage2_encounter_kind"] = String(definition.get("encounter_kind", ""))
	boss["stage2_owner_id"] = String(definition.get("owner_id", ""))
	boss["stage2_phase_id"] = String(definition.get("id", ""))
	boss["stage2_phase_index"] = int(definition.get("phase_index", -1))
	boss["stage2_topology_id"] = String(definition.get("topology_id", ""))
	game_manager_ref.state = "boss"

func _apply_stage2_boss_movement(movement: Dictionary) -> void:
	if not boss_alive or not (movement.get("position") is Vector2):
		return
	var position_value: Vector2 = movement.position
	boss.x = clampf(position_value.x, 24.0, SCREEN_W - 24.0)
	boss.y = clampf(position_value.y, 48.0, SCREEN_H - 24.0)
	boss.target_x = boss.x
	boss.target_y = boss.y
	boss["stage2_movement_id"] = String(movement.get("id", ""))

func _clear_hostile_bullets() -> void:
	for bullet_index in bullet_world.active_order():
		var bullet: Dictionary = bullet_pool[bullet_index]
		if bool(bullet.get("active", false)) and not bool(bullet.get("stage2_field_owned", false)) and _is_enemy_bullet_type(String(bullet.get("type", ""))):
			bullet_world.retire_slot(bullet_index)
	_sync_bullet_world_compatibility_views()

func _resolve_stage2_player_hit() -> void:
	if player_just_hit and not player_deathbomb_primed:
		if game_manager_ref.lives > 0:
			_respawn()
		else:
			if game_manager_ref.has_method("record_actual_miss"):
				game_manager_ref.record_actual_miss()
			player_just_hit = false
			game_manager_ref.state = "game_over"
			if audio_manager_ref:
				audio_manager_ref.fade_bgm(-30.0, 0.8)

func _finish_stage2_after_boss() -> void:
	boss_alive = false
	boss = {}
	if game_manager_ref.practice_mode or game_manager_ref.current_stage >= game_manager_ref.stage_count():
		game_manager_ref.state = "final_clear"
		if audio_manager_ref:
			audio_manager_ref.fade_bgm(-30.0, 1.0)
	else:
		game_manager_ref.state = "stage_clear"
		if audio_manager_ref:
			audio_manager_ref.fade_bgm(-12.0, 0.6)

func _stage2_fail_closed(message: String) -> void:
	var stable_message := message if message != "" else "Stage 2 field integration rejected an unspecified runtime fault"
	stage_controller["stage2_hard_error"] = stable_message
	stage_controller["stage2_field_hard_error"] = stable_message
	var bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
	for uid_value in bindings.keys():
		var slot := int(bindings[uid_value])
		if slot >= 0 and slot < bullet_pool.size() and String(bullet_pool[slot].get("stage2_bullet_uid", "")) == String(uid_value):
			bullet_world.retire_slot(slot)
	stage_controller["stage2_field_uid_to_slot"] = {}
	_sync_bullet_world_compatibility_views()
	boss_alive = false
	if game_manager_ref:
		game_manager_ref.state = "game_over"

func _stage2_reject_field_callback(message: String) -> void:
	# Transaction rejection deliberately preserves the live field cursor/runtime,
	# UID ledger, binding map, and BulletWorld slots for deterministic diagnosis.
	var stable_message := message if message != "" else "Stage 2 field callback rejected an unspecified runtime fault"
	stage_controller["stage2_hard_error"] = stable_message
	stage_controller["stage2_field_hard_error"] = stable_message
	boss_alive = false
	if game_manager_ref:
		game_manager_ref.state = "game_over"

func _update_boss(delta: float):
	if _active_stage() == 2 and stage2_encounter_controller != null and stage2_encounter_controller.is_configured():
		_update_stage2_main_flow(delta)
		return
	if bool(current_tick_input.get("pause", false)):
		pause_menu_cursor = 0
		_pause_gameplay(game_manager_ref.STATE_BOSS)
		return
	_update_player(delta)
	_update_bullets(delta, Vector2(boss.get("x", _screen_center_x()), boss.get("y", _boss_anchor_y())) if boss_alive else Vector2.ZERO)
	_update_items(delta)
	_update_combat_effects(delta)
	if boss_alive: _update_boss_entity(delta)
	_check_collisions(true)
	if player_just_hit and not player_deathbomb_primed:
		if game_manager_ref.lives > 0: _respawn()
		else:
			if game_manager_ref.has_method("record_actual_miss"): game_manager_ref.record_actual_miss()
			player_just_hit = false
			game_manager_ref.state = "game_over"
			if audio_manager_ref: audio_manager_ref.fade_bgm(-30.0, 0.8)
	if not boss_alive:
		if game_manager_ref.practice_mode or game_manager_ref.current_stage >= game_manager_ref.stage_count():
			game_manager_ref.state = "final_clear"
			if audio_manager_ref: audio_manager_ref.fade_bgm(-30.0, 1.0)
		else:
			game_manager_ref.state = "stage_clear"
			if audio_manager_ref: audio_manager_ref.fade_bgm(-12.0, 0.6)

func _enter_boss():
	game_manager_ref.state = "boss"
	enemies.clear()
	for bullet_index in bullet_world.active_order():
		var b = bullet_pool[bullet_index]
		if b.active and _is_enemy_bullet_type(String(b.type)): bullet_world.retire_slot(bullet_index)
	_init_boss()
	if audio_manager_ref: audio_manager_ref.bgm_stage_boss(game_manager_ref.current_stage)

func _init_boss():
	boss = boss_state_machine.create_initial_state(_screen_center_x(), -60.0, gameplay_rng.range_float(0.0, 100.0))
	_load_boss_cards()
	boss_alive = true

func _load_boss_cards():
	var stage_index: int = _active_stage()
	var source_cards: Array = stage_director.boss_cards(stage_index)
	var boss_def: Dictionary = stage_director.boss_definition(stage_index)
	var boss_id := String(boss_def.get("id", ""))
	boss.cards = []
	for source_card in source_cards:
		var card: Dictionary = source_card.duplicate(true)
		var base_hp := float(card.get("hp", 500.0))
		card["base_hp"] = base_hp
		card["hp"] = game_manager_ref.balanced_boss_card_hp(stage_index, float(card.get("time", 30.0)), String(card.get("kind", "spell"))) if game_manager_ref else base_hp
		card["stage_index"] = stage_index
		card["boss_id"] = boss_id
		card["pattern"] = _resolve_boss_pattern_id(String(card.get("pattern", "moonlight")))
		boss.cards.append(card)

func _resolve_boss_pattern_id(pattern_id: String) -> String:
	var aliases: Dictionary = stage_director.pattern_aliases()
	return String(aliases.get(pattern_id, pattern_id))

func _stage1_cards() -> Array:
	return [
		{"name":"Moonlight Ray","hp":600,"time":28,"pattern":"moonlight"},
		{"name":"Starfall","hp":900,"time":32,"pattern":"starfall"},
		{"name":"Phantom Butterfly","hp":1300,"time":30,"pattern":"butterfly"},
		{"name":"Divine Punishment","hp":1600,"time":25,"pattern":"divine"},
	]
func _stage2_cards() -> Array:
	return [
		{"name":"Ripple Shield","hp":900,"time":28,"pattern":"ripple"},
		{"name":"Bubble Burst","hp":1300,"time":32,"pattern":"bubble"},
		{"name":"Mist Labyrinth","hp":1800,"time":30,"pattern":"mist"},
		{"name":"Crystal Mirror","hp":2400,"time":25,"pattern":"mirror"},
	]
func _stage3_cards() -> Array:
	return [
		{"name":"Scarlet Rain","hp":1200,"time":28,"pattern":"scarlet"},
		{"name":"Midnight Blade","hp":1700,"time":30,"pattern":"midnight"},
		{"name":"Blood Vortex","hp":2300,"time":32,"pattern":"vortex"},
		{"name":"Eternal Darkness","hp":3000,"time":28,"pattern":"darkness"},
		{"name":"Scarlet Apocalypse","hp":4000,"time":25,"pattern":"apocalypse"},
	]
func _start_boss_card():
	var c: Dictionary = boss.cards[boss.card_idx]
	boss.card_name = c.name; boss.card_hp = c.hp; boss.max_hp = c.hp; boss.hp = c.hp
	boss.card_timer = c.time * 60.0; boss.card_shot = 0.0
	boss.last_countdown_second = -1
	boss.move_mode = _boss_movement_mode(c)
	boss.declaring = true; boss.declare_timer = 90.0
	_transition_boss_phase(BossStateMachine.PHASE_ACTIVE)
	if String(c.get("kind", "spell")) == "spell" and game_manager_ref.has_method("begin_spell_capture"):
		var card_id := String(c.get("id", c.get("name", "card_%d" % int(boss.card_idx))))
		var capture_base := int(c.get("capture_base_value", _score_value("spell_capture_base", 100000)))
		game_manager_ref.begin_spell_capture(card_id, capture_base, float(c.time) * 60.0)
	if audio_manager_ref:
		audio_manager_ref.play_sfx("spell_announce")

func _update_boss_entity(delta: float):
	# All boss timing constants are authored in FRAMES (e.g. declare_timer=90
	# for 1.5s, boss_enter span=120 frames for 2s, cardShot frequency uses
	# `int(card_shot) % 12`). Convert delta to frames once, then use it
	# everywhere below - keeping units consistent with the rest of the game.
	var dt: float = delta * 60.0
	boss.anim += dt; boss.sway += dt
	boss.flash = max(0.0, boss.flash - dt)
	if boss.declaring:
		boss.declare_timer -= dt
		if boss.declare_timer <= 0: boss.declaring = false

	match boss.phase:
		"entering": _boss_enter(delta)
		"active": _boss_active(delta)
		"switching": _boss_switching(delta)
		"defeated": _boss_defeated(delta)

	if boss.phase in ["active","switching"] and not boss.declaring:
		_update_boss_movement_target()

	if boss.phase != "defeated":
		# Frame-rate-independent lerp toward target (per-frame factor ~0.08).
		var f: float = clampf(0.08 * dt, 0.0, 1.0)
		boss.x = lerpf(boss.x, boss.get("target_x", _screen_center_x()), f)
		boss.y = lerpf(boss.y, boss.get("target_y", _boss_anchor_y()), f)

	if boss.entered and boss.cards.size() > 0 and boss.card_idx == 0 and boss.card_hp == 0 and boss.phase == "active":
		_start_boss_card()

func _boss_movement_mode(card: Dictionary) -> String:
	var pattern := String(card.get("pattern", ""))
	if pattern in ["wind_aimed", "wind_lattice", "apocalypse", "final_lantern"]:
		return "sweep"
	if pattern in ["butterfly", "vortex", "darkness", "scarlet"]:
		return "orbit"
	if pattern in ["mirror", "rhythm_drum", "midnight"]:
		return "step"
	if pattern in ["large_orb_gate", "bubble", "ripple"]:
		return "pendulum"
	return "hover"

func _update_boss_movement_target() -> void:
	var t := float(boss.get("card_shot", 0.0))
	var center_x := _screen_center_x()
	var anchor_y := _boss_anchor_y()
	match String(boss.get("move_mode", "hover")):
		"sweep":
			boss.target_x = center_x + sin(t * 0.018) * SCREEN_W * 0.31
			boss.target_y = anchor_y + 28.0 + sin(t * 0.036) * 22.0
		"orbit":
			boss.target_x = center_x + sin(t * 0.022) * SCREEN_W * 0.23
			boss.target_y = anchor_y + 36.0 + cos(t * 0.031) * 42.0
		"step":
			var stops := [-0.30, 0.22, -0.08, 0.31]
			boss.target_x = center_x + SCREEN_W * float(stops[int(t / 105.0) % stops.size()])
			boss.target_y = anchor_y + 20.0 + sin(t * 0.052) * 18.0
		"pendulum":
			boss.target_x = center_x + sin(t * 0.012) * SCREEN_W * 0.27
			boss.target_y = anchor_y + 56.0 + cos(t * 0.024) * 28.0
		_:
			boss.target_x = center_x + sin(t * 0.02) * 86.0
			boss.target_y = anchor_y + 20.0 + cos(t * 0.032) * 20.0
	boss.target_x = clampf(float(boss.target_x), 72.0, SCREEN_W - 72.0)
	boss.target_y = clampf(float(boss.target_y), 104.0, SCREEN_H * 0.30)

func _boss_enter(delta: float):
	boss.timer += delta * 60.0
	var p: float = clampf(boss.timer / 120.0, 0.0, 1.0)
	var target_y := _boss_anchor_y()
	boss.y = -60.0 + (target_y + 60.0) * (1.0 - (1.0-p)*(1.0-p))
	if p >= 1.0:
		_transition_boss_phase(BossStateMachine.PHASE_ACTIVE)
		boss.entered = true

func _boss_active(delta: float):
	if boss.declaring: return
	var dt: float = delta * 60.0
	boss.card_timer -= dt
	_update_boss_countdown_cue()
	if boss.card_timer <= 0: _boss_card_timeout()
	boss.card_shot += dt
	if boss.card_idx < boss.cards.size():
		_boss_fire_pattern(delta)
	if boss.hp <= 0: _boss_card_clear()

func _update_boss_countdown_cue() -> void:
	var seconds_left := _boss_timer_seconds()
	if seconds_left <= 0 or seconds_left > 5:
		return
	if int(boss.get("last_countdown_second", -1)) == seconds_left:
		return
	boss.last_countdown_second = seconds_left
	if audio_manager_ref:
		audio_manager_ref.play_sfx("menu_move", -12.0 if seconds_left > 1 else -9.0)

func _boss_switching(delta: float):
	boss.timer += delta * 60.0
	if boss.timer > 40:
		boss.card_idx += 1; boss.timer = 0.0
		# Defensive: only start next card if it exists. The card-clear logic
		# routes "last card" straight to "defeated", so this should normally
		# never trigger - but a stray future caller shouldn't blow up.
		if boss.card_idx < boss.cards.size():
			_start_boss_card()
		else:
			_transition_boss_phase(BossStateMachine.PHASE_DEFEATED, true)

func _boss_defeated(delta: float):
	boss.timer += delta * 60.0
	boss.x += gameplay_rng.range_float(-2.0, 2.0) * delta * 60.0
	boss.y += 0.5 * delta * 60.0
	if boss.timer > 180: boss_alive = false

func _boss_card_clear():
	if game_manager_ref.has_method("finish_spell_capture") and bool(game_manager_ref.spell_capture_active):
		game_manager_ref.finish_spell_capture(float(boss.get("card_timer", 0.0)), false)
	var was_last_card: bool = boss.card_idx >= boss.cards.size() - 1
	var effect_position := Vector2(float(boss.get("x", _screen_center_x())), float(boss.get("y", _boss_anchor_y())))
	_spawn_combat_effect("boss_defeat" if was_last_card else "boss_phase", effect_position, 44.0 if was_last_card else 34.0, Color(1.0, 0.34, 0.25) if was_last_card else Color(0.98, 0.76, 0.32))
	for bullet_index in bullet_world.active_order():
		var b = bullet_pool[bullet_index]
		if b.active and _is_enemy_bullet_type(String(b.type)): bullet_world.retire_slot(bullet_index)
	# If the just-cleared card was the LAST card, the boss is dead - go to
	# the defeat animation instead of "switching" so we never try to start
	# a non-existent next card (which was an out-of-range index bug).
	if was_last_card:
		_transition_boss_phase(BossStateMachine.PHASE_DEFEATED, true)
	else:
		_transition_boss_phase(BossStateMachine.PHASE_SWITCHING, true)
	if audio_manager_ref: audio_manager_ref.play_sfx("boss_phase_clear", -5.0)

func _boss_card_timeout():
	if game_manager_ref.has_method("finish_spell_capture") and bool(game_manager_ref.spell_capture_active):
		game_manager_ref.finish_spell_capture(0.0, true)
	for bullet_index in bullet_world.active_order():
		var b = bullet_pool[bullet_index]
		if b.active and _is_enemy_bullet_type(String(b.type)): bullet_world.retire_slot(bullet_index)
	# Same as above - timeout on the last card also ends the fight.
	if boss.card_idx >= boss.cards.size() - 1:
		_transition_boss_phase(BossStateMachine.PHASE_DEFEATED, true)
	else:
		_transition_boss_phase(BossStateMachine.PHASE_SWITCHING, true)
	if audio_manager_ref: audio_manager_ref.play_sfx("boss_phase_clear", -7.0)

func _boss_fire_pattern(delta: float):
	var c: Dictionary = boss.cards[boss.card_idx]
	var mult: float = game_manager_ref.STAGE_MULTS[game_manager_ref.current_stage - 1].bullet_speed
	match c.pattern:
		"moonlight": _bullets_moonlight(mult)
		"starfall": _bullets_starfall(mult)
		"butterfly": _bullets_butterfly(mult)
		"divine": _bullets_divine(mult)
		"ripple": _bullets_ripple(mult)
		"bubble": _bullets_bubble(mult)
		"mist": _bullets_mist(mult)
		"mirror": _bullets_mirror(mult)
		"scarlet": _bullets_scarlet(mult)
		"midnight": _bullets_midnight(mult)
		"vortex": _bullets_vortex(mult)
		"darkness": _bullets_darkness(mult)
		"apocalypse": _bullets_apocalypse(mult)
		"wind_aimed": _bullets_wind_aimed(mult)
		"wind_lattice": _bullets_wind_lattice(mult)
		"rhythm_drum": _bullets_rhythm_drum(mult)
		"large_orb_gate": _bullets_large_orb_gate(mult)
		"final_lantern": _bullets_final_lantern(mult)

# Boss spell patterns (compact but varied)
func _bullets_moonlight(mult: float):
	if int(boss.card_shot) % 12 == 0:
		var a: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.12,0,0.12]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*2.5*mult,sin(a+off)*2.5*mult,5,Color(0.24,0.31,1))
	if int(boss.card_shot) % 50 == 0:
		for i in range(16): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/16*i+boss.card_shot*0.008)*1.8*mult,sin(TAU/16*i+boss.card_shot*0.008)*1.8*mult,3,Color(0.71,0.16,0.86))

func _bullets_starfall(mult: float):
	if int(boss.card_shot) % 6 == 0:
		var p: float = boss.card_shot * 0.04
		for i in range(7): _spawn_bullet_enemy(boss.x,boss.y,cos(p+(i-3)*0.17)*2.8*mult,sin(p+(i-3)*0.17)*2.8*mult,3,Color.YELLOW,"rice",350)
	if int(boss.card_shot) % 40 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.35,-0.15,0,0.15,0.35]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*3.2*mult,sin(a+off)*3.2*mult,5,Color.ORANGE,"arrow",280)

func _bullets_butterfly(mult: float):
	for arm in [1,-1]:
		if int(boss.card_shot) % 5 == 0:
			for i in range(8):
				var a: float = boss.card_shot*0.05*arm+TAU/8*i
				_spawn_bullet_enemy(boss.x,boss.y,cos(a)*(1.6+i*0.3)*mult,sin(a)*(1.6+i*0.3)*mult,3,Color.GREEN if arm==1 else Color(0.71,0.16,0.86))
	if int(boss.card_shot) % 15 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		_spawn_bullet_enemy(boss.x,boss.y,cos(a)*3.0*mult,sin(a)*3.0*mult,4,Color.WHITE)

func _bullets_divine(mult: float):
	if int(boss.card_shot) % 6 == 0:
		for i in range(20): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/20*i+boss.card_shot*0.012)*2.0*mult,sin(TAU/20*i+boss.card_shot*0.012)*2.0*mult,2,Color.RED)
	if int(boss.card_shot) % 35 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.4,-0.2,0,0.2,0.4]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*4.5*mult,sin(a+off)*4.5*mult,6,Color.ORANGE,"laser",250)

func _bullets_ripple(mult: float):
	if int(boss.card_shot) % 10 == 0:
		for i in range(18): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/18*i+boss.card_shot*0.01)*2.2*mult,sin(TAU/18*i+boss.card_shot*0.01)*2.2*mult,4,Color(0.16,0.39,1))
	if int(boss.card_shot) % 25 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.25,0,0.25]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*3.0*mult,sin(a+off)*3.0*mult,5,Color(0.16,0.86,0.94),"arrow")

func _bullets_bubble(mult: float):
	if int(boss.card_shot) % 8 == 0:
		for i in range(10):
			var speed: float = (1.5 + i * 0.16) * mult
			var angle: float = float(boss.card_shot) * 0.03 + TAU / 10.0 * i
			_spawn_bullet_enemy(boss.x, boss.y, cos(angle) * speed, sin(angle) * speed, 4, Color(0.82, 0.35, 1.0), "spiral_seed", 480, {"kind":"brake_restart", "brake":0.035, "trigger_age":46.0, "target_speed":speed * 1.1})
	if int(boss.card_shot) % 22 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.4,-0.2,0,0.2,0.4]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*3.2*mult,sin(a+off)*3.2*mult,5,Color.YELLOW,"arrow")

func _bullets_mist(mult: float):
	if int(boss.card_shot) % 6 == 0:
		for arm in range(3):
			for i in range(5):
				var a: float = TAU/3*arm+boss.card_shot*0.025+i*0.25
				_spawn_bullet_enemy(boss.x,boss.y,cos(a)*2.0*mult,sin(a)*2.0*mult,4,Color(0.71,0.16,0.86) if arm==0 else (Color(0.16,0.39,1) if arm==1 else Color(0.16,0.86,0.94)), "storm_arc", 430, {"kind":"curve", "turn_rate":(-0.005 if arm % 2 == 0 else 0.005)})

func _bullets_mirror(mult: float):
	if int(boss.card_shot) % 20 == 0:
		for ab in [0.0,PI/2,PI/4,-PI/4]:
			for d in [-1,1]: _spawn_bullet_enemy(boss.x,boss.y,cos(ab+d*0.3)*4.0*mult,sin(ab+d*0.3)*4.0*mult,6,Color.RED,"laser")
	if int(boss.card_shot) % 8 == 0:
		for i in range(20):
			var a: float = TAU / 20.0 * i + float(boss.card_shot) * 0.02
			_spawn_bullet_enemy(boss.x,boss.y,cos(a)*2.2*mult,sin(a)*2.2*mult,5,Color(0.95,0.3,0.55),"clock_gear",460,{"bounce_count":1})

func _bullets_scarlet(mult: float):
	if int(boss.card_shot) % 4 == 0:
		for i in range(7): _spawn_bullet_enemy(boss.x,boss.y,cos(PI*0.4+i*PI*0.2/7+sin(boss.card_shot*0.02)*0.4)*2.8*mult,sin(PI*0.4+i*PI*0.2/7+sin(boss.card_shot*0.02)*0.4)*2.8*mult,3,Color(1,0.24,0.24))
	if int(boss.card_shot) % 30 == 0:
		for i in range(22): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/22*i+boss.card_shot*0.015)*2.0*mult,sin(TAU/22*i+boss.card_shot*0.015)*2.0*mult,3,Color.RED)

func _bullets_midnight(mult: float):
	if int(boss.card_shot) % 7 == 0:
		for i in range(4): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.06+TAU/4*i)*4.0*mult,sin(boss.card_shot*0.06+TAU/4*i)*4.0*mult,5,Color(0.71,0.16,0.86),"laser")
	if int(boss.card_shot) % 5 == 0:
		for arm in [1,-1]:
			for i in range(8): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.04*arm+TAU/8*i)*2.5*mult,sin(boss.card_shot*0.04*arm+TAU/8*i)*2.5*mult,3,Color(0.71,0.16,0.86) if arm==1 else Color.ORANGE)

func _bullets_vortex(mult: float):
	for arm in [-1,1]:
		if int(boss.card_shot) % 6 == 0:
			for i in range(8):
				var a: float = float(boss.card_shot) * 0.035 * arm + TAU / 8.0 * i
				_spawn_bullet_enemy(boss.x,boss.y,cos(a)*(2.0+i*0.2)*mult,sin(a)*(2.0+i*0.2)*mult,5,Color(0.95,0.3,0.55),"clock_gear",420,{"kind":"curve", "turn_rate":0.008*arm})
	if int(boss.card_shot) % 18 == 0:
		for i in range(28): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/28*i+boss.card_shot*0.02)*3.0*mult,sin(TAU/28*i+boss.card_shot*0.02)*3.0*mult,2,Color(1,0.24,0.24))

func _bullets_darkness(mult: float):
	if int(boss.card_shot) % 5 == 0:
		for i in range(24): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/24*i+boss.card_shot*0.018)*2.2*mult,sin(TAU/24*i+boss.card_shot*0.018)*2.2*mult,2,Color(0.71,0.16,0.86))
	if int(boss.card_shot) % 25 == 0:
		for i in range(4): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.04+TAU/4*i)*5.0*mult,sin(boss.card_shot*0.04+TAU/4*i)*5.0*mult,7,Color(1,0.24,0.24),"laser")

func _bullets_apocalypse(mult: float):
	if int(boss.card_shot) % 7 == 0:
		for i in range(24):
			var a: float = TAU / 24.0 * i + float(boss.card_shot) * 0.02
			_spawn_bullet_enemy(boss.x,boss.y,cos(a)*1.65*mult,sin(a)*1.65*mult,4,Color(0.82,0.35,1.0),"spiral_seed",430,{"kind":"accelerate", "accel":0.012, "max_speed":3.2*mult})
	if int(boss.card_shot) % 9 == 0:
		for i in range(18):
			var a: float = TAU / 18.0 * i - float(boss.card_shot) * 0.025
			_spawn_bullet_enemy(boss.x,boss.y,cos(a)*2.3*mult,sin(a)*2.3*mult,4,Color(1.0,0.5,0.2),"arrow",360)
	if int(boss.card_shot) % 20 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.5,-0.25,0,0.25,0.5]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*4.5*mult,sin(a+off)*4.5*mult,6,Color(0.71,0.2,0.24),"laser")
	if int(boss.card_shot) % (2 if boss.card_timer < 600 else 4) == 0:
		var a: float = gameplay_rng.range_float(0.0, TAU)
		var speed_x: float = gameplay_rng.range_float(3.0, 6.0) * mult
		var speed_y: float = gameplay_rng.range_float(3.0, 6.0) * mult
		_spawn_bullet_enemy(boss.x, boss.y, cos(a) * speed_x, sin(a) * speed_y, 3, Color.WHITE)

func _bullets_wind_aimed(mult: float):
	if int(boss.card_shot) % 6 == 0:
		var a: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.3, -0.12, 0.12, 0.3]:
			_spawn_bullet_enemy(boss.x, boss.y, cos(a + off) * 3.4 * mult, sin(a + off) * 3.4 * mult, 4, Color(1.0, 0.72, 0.2), "needle", 290)
	if int(boss.card_shot) % 36 == 0:
		for i in range(14):
			var w: float = TAU / 14.0 * i + boss.card_shot * 0.015
			_spawn_bullet_enemy(boss.x, boss.y, cos(w) * 2.1 * mult, sin(w) * 2.1 * mult, 4, Color(0.35, 0.78, 1.0), "storm_arc", 360, {"kind":"curve", "turn_rate":(-0.006 if i % 2 == 0 else 0.006)})

func _bullets_wind_lattice(mult: float):
	if int(boss.card_shot) % 8 == 0:
		for lane in [-2, -1, 0, 1, 2]:
			var a1: float = PI * 0.5 + lane * 0.12 + sin(boss.card_shot * 0.02) * 0.2
			var a2: float = PI * 0.5 - lane * 0.12 - sin(boss.card_shot * 0.02) * 0.2
			_spawn_bullet_enemy(boss.x - 56 + lane * 28, boss.y, cos(a1) * 2.7 * mult, sin(a1) * 2.7 * mult, 4, Color(1.0, 0.72, 0.2), "needle", 330)
			_spawn_bullet_enemy(boss.x + 56 - lane * 28, boss.y, cos(a2) * 2.7 * mult, sin(a2) * 2.7 * mult, 4, Color(0.45, 0.66, 1.0), "star", 330)
	if int(boss.card_shot) % 42 == 0:
		var aimed: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.2, 0.0, 0.2]:
			_spawn_bullet_enemy(boss.x, boss.y, cos(aimed + off) * 3.2 * mult, sin(aimed + off) * 3.2 * mult, 5, Color(0.95, 0.22, 0.25), "talisman", 320)

func _bullets_rhythm_drum(mult: float):
	if int(boss.card_shot) % 12 == 0:
		var count := 10 if int(boss.card_shot / 12.0) % 2 == 0 else 14
		for i in range(count):
			var a: float = TAU / float(count) * i + boss.card_shot * 0.018
			var family := "star" if count == 10 else "rice"
			var speed: float = 2.25 * mult
			_spawn_bullet_enemy(boss.x, boss.y, cos(a) * speed, sin(a) * speed, 4, Color(0.45, 0.66, 1.0) if family == "star" else Color(0.16, 0.86, 0.94), family, 360, {"kind":"brake_restart", "brake":0.04, "trigger_age":30.0, "target_speed":speed})
	if int(boss.card_shot) % 48 == 0:
		var aimed: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.32, -0.16, 0.0, 0.16, 0.32]:
			_spawn_bullet_enemy(boss.x, boss.y, cos(aimed + off) * 3.0 * mult, sin(aimed + off) * 3.0 * mult, 5, Color(0.95, 0.22, 0.25), "talisman", 320)

func _bullets_large_orb_gate(mult: float):
	if int(boss.card_shot) % 38 == 0:
		var aimed: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.44, 0.0, 0.44]:
			var speed: float = 1.55 * mult
			_spawn_bullet_enemy(boss.x, boss.y, cos(aimed + off) * speed, sin(aimed + off) * speed, 10, Color(0.62, 0.38, 1.0), "large_orb", 520, {"kind":"brake_restart", "brake":0.02, "trigger_age":58.0, "target_speed":speed * 1.15, "aim_on_trigger":off == 0.0})
	if int(boss.card_shot) % 9 == 0:
		for i in range(8):
			var a: float = TAU / 8.0 * i + boss.card_shot * 0.025
			_spawn_bullet_enemy(boss.x, boss.y, cos(a) * 2.35 * mult, sin(a) * 2.35 * mult, 4, Color(0.16, 0.86, 0.94), "rice", 360)

func _bullets_final_lantern(mult: float):
	if int(boss.card_shot) % 5 == 0:
		for i in range(18):
			var a: float = TAU / 18.0 * i + boss.card_shot * 0.016
			var family := "talisman" if i % 2 == 0 else "star"
			var color := Color(0.95, 0.22, 0.25) if family == "talisman" else Color(0.45, 0.66, 1.0)
			var motion: Dictionary = {"kind":"curve", "turn_rate":(-0.004 if i % 4 < 2 else 0.004)} if family == "talisman" else {"kind":"accelerate", "accel":0.008, "max_speed":3.0*mult}
			_spawn_bullet_enemy(boss.x, boss.y, cos(a) * 2.05 * mult, sin(a) * 2.05 * mult, 4, color, family, 400, motion)
	if int(boss.card_shot) % 28 == 0:
		var aimed: float = (Vector2(player_x, player_y) - Vector2(boss.x, boss.y)).angle()
		for off in [-0.42, -0.21, 0.0, 0.21, 0.42]:
			_spawn_bullet_enemy(boss.x, boss.y, cos(aimed + off) * 3.6 * mult, sin(aimed + off) * 3.6 * mult, 5, Color(1.0, 0.42, 0.18), "laser", 300)
	if int(boss.card_shot) % 70 == 0:
		for off in [-0.5, 0.5]:
			_spawn_bullet_enemy(boss.x + off * 80.0, boss.y, off * 0.8 * mult, 1.5 * mult, 10, Color(0.62, 0.38, 1.0), "large_orb", 520)

# Stage wave spawning
func _stage_waves(timer: int):
	if stage_controller.is_empty():
		return
	var triggered: Dictionary = stage_controller.get("triggered_waves", {})
	for event in stage_director.due_wave_events(_active_stage(), timer, triggered):
		_spawn_stage_wave_event(event)
	stage_controller["triggered_waves"] = triggered

func _spawn_stage_wave_event(event: Dictionary) -> void:
	_spawn_enemy(
		float(event.get("x", 0.0)),
		float(event.get("y", -20.0)),
		float(event.get("hp", 5.0)),
		String(event.get("pattern", "aimed")),
		String(event.get("move", "straight")),
		float(event.get("vx", 0.0)),
		float(event.get("vy", 1.5)),
		event.get("move_data", {}),
		bool(event.get("strong", false)),
		event.get("drop_item_ids", null)
	)

func _waves_s1(timer: int):
	var w: int = timer
	if w == 0: _spawn_enemy(100,-20,4,"downward"); _spawn_enemy(380,-20,4,"downward")
	if w == 120: _spawn_enemy(240,-20,5,"spread","enter_and_stop",0,2.5,{"move_time":55})
	if w == 300: for i in range(4): _spawn_enemy(100+i*90,-20-i*12,2,"aimed","sine",0,1.5,{"amplitude":18+i*4})
	if w == 540: _spawn_enemy(240,30,12,"ring","sine",0.8,0.5,{"amplitude":50})
	if w == 780: _spawn_enemy(80,-20,6,"spread","enter_and_stop",0,2.0,{"move_time":60}); _spawn_enemy(400,-20,6,"spread","enter_and_stop",0,2.2,{"move_time":60})
	if w == 1080: for i in range(5): _spawn_enemy(70+i*85,-20-i*15,3,"aimed","sine",0,1.6,{"amplitude":25})
	if w == 1380: _spawn_enemy(140,30,14,"ring","circle",0,0,{"center_x":160,"center_y":100,"radius":50}); _spawn_enemy(340,30,14,"ring","circle",0,0,{"center_x":320,"center_y":100,"radius":50})
	if w == 1740: for i in range(4): _spawn_enemy(80+i*100,-30,4,"downward","enter_and_stop",0,1.4,{"move_time":70})
	if w == 2100: _spawn_enemy(-20,180,5,"aimed","straight",2.0,0); _spawn_enemy(500,220,5,"aimed","straight",-2.0,0)
	if w == 2500: _spawn_enemy(240,40,20,"double_spread","sine",0.3,0.7,{"amplitude":80})
	if w == 2900: for i in range(3): _spawn_enemy(120+i*120,-25,6,"spread","enter_and_stop",0,1.6,{"move_time":70})
	if w == 3300: _spawn_enemy(240,60,22,"ring","sine",0.2,0.5,{"amplitude":70})
	if w == 3700: _spawn_enemy(70,-20,5,"spread","straight",1.2,1.3); _spawn_enemy(410,-20,5,"spread","straight",-1.2,1.3); _spawn_enemy(80,-40,4,"aimed","straight",0.8,1.8); _spawn_enemy(400,-40,4,"aimed","straight",-0.8,1.8)
	if w == 4000: _spawn_enemy(240,-20,35,"double_spread","enter_and_stop",0,1.8,{"move_time":80}); _spawn_enemy(90,-10,5,"aimed","straight",0,1.2); _spawn_enemy(390,-10,5,"aimed","straight",0,1.2)
	if w == 4200: for i in range(4): _spawn_enemy(90+i*95,-15-i*8,4,"spread","enter_and_stop",0,1.8,{"move_time":65})

func _waves_s2(timer: int):
	var w: int = timer
	if w == 0: _spawn_enemy(80,-20,5,"spread"); _spawn_enemy(400,-20,5,"spread"); _spawn_enemy(240,-40,4,"aimed")
	if w == 100: _spawn_enemy(240,-20,8,"double_spread","enter_and_stop",0,2.0,{"move_time":60})
	if w == 250: for i in range(5): _spawn_enemy(80+i*80,-20-i*10,3,"aimed","sine",0,1.4,{"amplitude":20+i*5})
	if w == 480: _spawn_enemy(240,30,16,"ring","sine",0.6,0.5,{"amplitude":60})
	if w == 720: _spawn_enemy(70,-20,9,"double_spread","enter_and_stop",0,2.0,{"move_time":65}); _spawn_enemy(410,-20,9,"double_spread","enter_and_stop",0,2.0,{"move_time":65})
	if w == 1000: for x in [60,180,300,420]: _spawn_enemy(x,-15,5,"aimed","sine",0,1.7,{"amplitude":30})
	if w == 1300: _spawn_enemy(100,30,20,"ring","circle",0,0,{"center_x":120,"center_y":90,"radius":60}); _spawn_enemy(380,30,20,"ring","circle",0,0,{"center_x":360,"center_y":90,"radius":60})
	if w == 1600: for i in range(5): _spawn_enemy(60+i*90,-25-i*8,5,"wave","enter_and_stop",0,1.6,{"move_time":65})
	if w == 1900: _spawn_enemy(-20,150,7,"aimed","straight",2.5,0.2); _spawn_enemy(500,190,7,"aimed","straight",-2.5,-0.1)
	if w == 2250: _spawn_enemy(240,40,25,"double_spread","sine",0.4,0.4,{"amplitude":70},true)
	if w == 2600: for i in range(4): _spawn_enemy(80+i*105,-30,8,"spread","enter_and_stop",0,1.8,{"move_time":75})
	if w == 2950: _spawn_enemy(240,50,30,"ring","sine",0.3,0.4,{"amplitude":90})
	if w == 3300: for x in [70,240,410]: _spawn_enemy(x,-20,10,"double_spread","enter_and_stop",0,1.5,{"move_time":70})
	if w == 3650: _spawn_enemy(80,-20,8,"spread","straight",1.0,1.5); _spawn_enemy(400,-20,8,"spread","straight",-1.0,1.5)
	if w == 3950: _spawn_enemy(240,-20,40,"double_spread","enter_and_stop",0,1.6,{"move_time":85},true); _spawn_enemy(170,-10,8,"spread"); _spawn_enemy(310,-10,8,"spread")
	if w == 4200: for i in range(5): _spawn_enemy(60+i*85,-15-i*6,6,"aimed","enter_and_stop",0,1.7,{"move_time":60})
	if w == 4500: for i in range(3): for x in [80,240,400]: _spawn_enemy(x,-20-i*12,4,"downward","straight",0,1.5+i*0.2)

func _waves_s3(timer: int):
	var w: int = timer
	if w == 0: for x in [60,200,340,420]: _spawn_enemy(x,-20,7,"spread")
	if w == 80: _spawn_enemy(240,-20,10,"spiral","enter_and_stop",0,2.2,{"move_time":55})
	if w == 200: for x in [70,170,270,370]: _spawn_enemy(x,-20,5,"aimed","sine",0,1.5,{"amplitude":25})
	if w == 400: _spawn_enemy(240,30,22,"ring","sine",0.8,0.4,{"amplitude":65})
	if w == 600: for x in [60,180,300,420]: _spawn_enemy(x,-15-x*0.02,7,"aimed","sine",0,1.8,{"amplitude":35})
	if w == 850: _spawn_enemy(-20,140,8,"double_spread","straight",2.8,0.1); _spawn_enemy(500,170,8,"double_spread","straight",-2.8,-0.1)
	if w == 1100: _spawn_enemy(120,30,25,"ring","circle",0,0,{"center_x":120,"center_y":80,"radius":55},true); _spawn_enemy(360,30,25,"ring","circle",0,0,{"center_x":360,"center_y":80,"radius":55},true)
	if w == 1350: for x in [60,160,260,360]: _spawn_enemy(x,-20,6,"downward","enter_and_stop",0,1.5,{"move_time":65})
	if w == 1600: _spawn_enemy(240,40,35,"double_spread","sine",0.4,0.5,{"amplitude":85})
	if w == 1900: for i in range(4): _spawn_enemy(70+i*110,-25,9,"spread","enter_and_stop",0,1.9,{"move_time":70})
	if w == 2200: _spawn_enemy(100,30,25,"double_spread","sine",0.5,0.4,{"amplitude":60},true); _spawn_enemy(210,-10,6,"aimed"); _spawn_enemy(270,-10,6,"aimed")
	if w == 2550: for i in range(5): _spawn_enemy(50+i*92,-30-i*8,7,"spread","enter_and_stop",0,1.7,{"move_time":75})
	if w == 2900: _spawn_enemy(240,50,40,"ring","sine",0.2,0.5,{"amplitude":95})
	if w == 3250: for x in [60,180,300,420]: _spawn_enemy(x,-25,11,"double_spread","enter_and_stop",0,1.6,{"move_time":80})
	if w == 3600: _spawn_enemy(120,-20,25,"double_spread","enter_and_stop",0,1.7,{"move_time":80},true); _spawn_enemy(360,-20,25,"double_spread","enter_and_stop",0,1.7,{"move_time":80},true)
	if w == 3950: for x in [80,400]: _spawn_enemy(x,-20,10,"spread","straight",0.8 if x<200 else -0.8,1.5)
	if w == 4250: _spawn_enemy(240,-20,50,"double_spread","enter_and_stop",0,1.5,{"move_time":90},true); for i in range(3): for s in [-1,1]: _spawn_enemy(240+s*(40+i*30),-15-i*10,7,"aimed","straight",s*0.5,1.3)
	if w == 4550: for x in [70,170,270,370]: _spawn_enemy(x,-20,9,"spread","enter_and_stop",0,1.8,{"move_time":70})
	if w == 4800: _spawn_enemy(240,30,25,"ring","sine",0.3,0.4,{"amplitude":75},true)
	if w == 5050: for i in range(4): for x in [80,250,400]: _spawn_enemy(x,-20-i*12,5,"downward","straight",0,1.6+i*0.3)

func _update_player(delta: float):
	if player_deathbomb_primed:
		player_deathbomb_timer -= delta
		if bool(current_tick_input.get("bomb", false)) and game_manager_ref.bombs > 0: _start_bomb(); player_deathbomb_primed = false; player_just_hit = false; return
		if player_deathbomb_timer <= 0: player_deathbomb_primed = false; return

	if player_invincible and not player_bombing:
		player_invincible_timer -= delta
		if player_invincible_timer <= 0: player_invincible = false

	if player_bombing: _update_bomb(delta)

	var focus: bool = _focus_held()
	var speed: float = game_manager_ref.selected_speed_low() if focus else game_manager_ref.selected_speed_high()
	var dx: float = GameplayInputBuffer.axis_float(int(current_tick_input.get("move_x", 0)))
	var dy: float = GameplayInputBuffer.axis_float(int(current_tick_input.get("move_y", 0)))
	if dx != 0 and dy != 0: dx *= 0.7071; dy *= 0.7071
	if dx != 0.0 or dy != 0.0:
		player_last_move_dir = Vector2(dx, dy).normalized()
	player_x += dx * speed * delta * 60.0
	player_y += dy * speed * delta * 60.0
	player_x = clampf(player_x, PLAYFIELD_MARGIN, SCREEN_W - PLAYFIELD_MARGIN)
	player_y = clampf(player_y, PLAYFIELD_MARGIN, SCREEN_H - PLAYFIELD_MARGIN)

	player_fire_cooldown -= delta
	if bool(current_tick_input.get("shoot", false)) and player_fire_cooldown <= 0:
		player_fire_cooldown = game_manager_ref.selected_fire_interval_frames() / 60.0
		_shoot()

	if bool(current_tick_input.get("bomb", false)) and game_manager_ref.bombs > 0 and not player_deathbomb_primed and not player_bombing:
		_start_bomb()

func _shoot():
	var shot_profile := _selected_shot_profile()
	var level: int = game_manager_ref.power_level()
	var focused := _focus_held()
	var specs: Array = _shot_executor_fire_pattern(shot_profile, level, focused, Vector2(player_x, player_y))
	for spec in specs:
		_spawn_player_bullet_spec(spec)
	# Throttle shoot SFX so 20 Hz fire doesn't sound like a machine-gun
	_sfx_shoot_skip = (_sfx_shoot_skip + 1) % 2
	if _sfx_shoot_skip == 0 and audio_manager_ref:
		var shot_sfx := String(SHOT_SFX_BY_ID.get(String(shot_profile.get("id", "")), "shot_miko_ofuda"))
		audio_manager_ref.play_sfx(shot_sfx, -12.0)

func _shoot_spread(level: int, dmg_val: float):
	var spd: float = -8.0; var r: float = 4.0; var c: Color = Color(0.71,0.31,1.0)
	match level:
		5: for ox in [-28,-22,-15,-8,0,8,15,22,28]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.06,spd,r,c,dmg_val,false,0)
		4: for ox in [-20,-12,-4,0,4,12,20]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.07,spd,r,c,dmg_val,false,0)
		3: for ox in [-14,-6,0,6,14]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.08,spd,r,c,dmg_val,false,0)
		2: for ox in [-8,0,8]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.09,spd,r,c,dmg_val,false,0)
		1: for ox in [-5,5]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.1,spd,r,c,dmg_val,false,0)
		_: _spawn_bullet_player(player_x,player_y-20,0,spd,r,c,dmg_val,false,0)

func _shoot_linear(level: int, dmg_val: float):
	var spd: float = -9.0; var r: float = 5.0; var c: Color = Color.RED
	match level:
		5: for ox in [-3,0,3]: _spawn_bullet_player(player_x+ox,player_y-18,0,spd,r,c,dmg_val,false,1); _spawn_bullet_player(player_x-6,player_y-24,0,spd,r,c,dmg_val,false,1); _spawn_bullet_player(player_x+6,player_y-24,0,spd,r,c,dmg_val,false,1)
		4: for ox in [-3,0,3]: _spawn_bullet_player(player_x+ox,player_y-18,0,spd,r,c,dmg_val,false,1)
		3: for ox in [-2,2]: _spawn_bullet_player(player_x+ox,player_y-18,0,spd,r,c,dmg_val,false,1)
		2: _spawn_bullet_player(player_x,player_y-18,0,spd,r+1,c,dmg_val,false,1)
		1: _spawn_bullet_player(player_x,player_y-18,0,spd,r,c,dmg_val+0.2,false,1)
		_: _spawn_bullet_player(player_x,player_y-18,0,spd,r,c,dmg_val,false,1)

func _shoot_homing(level: int, dmg_val: float):
	var spd: float = -5.0; var r: float = 3.0; var c: Color = Color.GREEN
	match level:
		5: for ox in [-20,-10,0,10,20]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.03,spd,r,c,dmg_val,true,2)
		4: for ox in [-15,-5,0,5,15]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.04,spd,r,c,dmg_val,true,2)
		3: for ox in [-10,0,10]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.05,spd,r,c,dmg_val,true,2)
		2: for ox in [-5,5]: _spawn_bullet_player(player_x+ox,player_y-20,ox*0.06,spd,r,c,dmg_val,true,2)
		1: _spawn_bullet_player(player_x,player_y-20,0,spd,r,c,dmg_val,true,2)
		_: _spawn_bullet_player(player_x,player_y-20,0,spd,r,c,dmg_val,true,2)

func _start_bomb():
	if game_manager_ref.bombs <= 0: return
	game_manager_ref.bombs -= 1
	if game_manager_ref.has_method("record_bomb_used"):
		game_manager_ref.record_bomb_used()
	player_bomb_config = bomb_executor.start_state(_selected_bomb_profile(), Vector2(player_x, player_y), player_last_move_dir)
	player_bombing = true
	player_bomb_timer = int(player_bomb_config.duration) / 60.0
	player_bomb_phase = 0; player_bomb_wave_timer = 0.0; player_bomb_radius = 0.0
	player_invincible = true; player_invincible_timer = int(player_bomb_config.duration) / 60.0
	if audio_manager_ref:
		var bomb_prefix := _bomb_sfx_prefix()
		audio_manager_ref.play_sfx("%s_start" % bomb_prefix, -4.0)
		audio_manager_ref.play_sfx("%s_loop" % bomb_prefix, -7.0)

func _update_bomb(delta: float):
	player_bomb_timer -= delta; player_bomb_wave_timer -= delta
	var bc: Dictionary = player_bomb_config
	player_bomb_radius += float(bc.get("clear_radius", 160.0)) / float(bc.get("duration", 120)) * 2.0 * delta * 60.0
	player_bomb_radius = min(player_bomb_radius, float(bc.get("clear_radius", 160.0)))
	var total_waves: int = max(1, int(bc.get("waves", 1)))
	var wave_int: float = float(bc.get("duration", 60)) / float(total_waves) / 60.0
	if player_bomb_wave_timer <= 0.0 and player_bomb_phase < total_waves:
		player_bomb_wave_timer = wave_int
		for spec in bomb_executor.wave_specs(bc, player_bomb_phase):
			_spawn_player_bullet_spec(spec)
		if boss_alive and boss.get("phase", "") == "active" and not bool(boss.get("declaring", false)):
			var ratio_damage: float = float(boss.get("max_hp", boss.get("hp", 0.0))) * float(bc.get("boss_damage_ratio", 0.0)) / float(total_waves)
			boss.hp -= ratio_damage if ratio_damage > 0.0 else float(bc.get("boss_damage_per_wave", 0.0))
		player_bomb_phase += 1
	for bullet_index in bullet_world.active_order():
		var b = bullet_pool[bullet_index]
		if b.active and not bool(b.get("stage2_field_owned", false)) and _is_enemy_bullet_type(String(b.type)):
			if bomb_executor.should_clear_enemy_bullet(bc, b, Vector2(player_x, player_y)):
				bullet_world.retire_slot(bullet_index)
	if player_bomb_timer <= 0:
		# End bomb state but DO NOT clear player_invincible here.
		# _start_bomb() set the invincibility timer to the bomb's duration;
		# the timer is held frozen while `player_bombing` was true (see
		# _update_player). After the bomb visual ends, that invincibility
		# window starts ticking normally, giving the player a brief grace
		# period during and after the bomb release.
		player_bombing = false
		if audio_manager_ref:
			var bomb_prefix := _bomb_sfx_prefix()
			audio_manager_ref.stop_sfx("%s_loop" % bomb_prefix)
			audio_manager_ref.play_sfx("%s_finish" % bomb_prefix, -4.0)

func _update_enemy_bullet_motion(b: Dictionary, dt: float) -> void:
	var motion: Dictionary = b.get("motion", {})
	if motion.is_empty():
		return
	var kind := String(motion.get("kind", "linear"))
	if not motion.has("heading") and Vector2(float(b.vx), float(b.vy)).length_squared() > 0.0:
		motion["heading"] = Vector2(float(b.vx), float(b.vy)).angle()
	var trigger_age := float(motion.get("trigger_age", -1.0))
	if not bool(b.get("motion_triggered", false)) and trigger_age >= 0.0 and float(b.age) >= trigger_age:
		b.motion_triggered = true
		var heading := float(motion.get("heading", Vector2(float(b.vx), float(b.vy)).angle()))
		if bool(motion.get("aim_on_trigger", false)):
			heading = (Vector2(player_x, player_y) - Vector2(float(b.x), float(b.y))).angle()
		var target_speed := float(motion.get("target_speed", Vector2(float(b.vx), float(b.vy)).length()))
		b.vx = cos(heading) * target_speed
		b.vy = sin(heading) * target_speed
	match kind:
		"curve":
			var turn := float(motion.get("turn_rate", 0.0)) * dt
			var velocity := Vector2(float(b.vx), float(b.vy)).rotated(turn)
			b.vx = velocity.x; b.vy = velocity.y
		"accelerate":
			var velocity := Vector2(float(b.vx), float(b.vy))
			var speed := velocity.length()
			if speed > 0.0:
				speed = clampf(speed + float(motion.get("accel", 0.0)) * dt, 0.05, float(motion.get("max_speed", 8.0)))
				velocity = velocity.normalized() * speed
				b.vx = velocity.x; b.vy = velocity.y
		"brake_restart":
			if not bool(b.get("motion_triggered", false)):
				var velocity := Vector2(float(b.vx), float(b.vy))
				var speed := maxf(0.05, velocity.length() - float(motion.get("brake", 0.04)) * dt)
				if velocity.length_squared() > 0.0:
					velocity = velocity.normalized() * speed
					b.vx = velocity.x; b.vy = velocity.y
		"delayed_aim":
			if not bool(b.get("motion_triggered", false)):
				b.vx = 0.0; b.vy = 0.0
	b.motion = motion

func _apply_enemy_bullet_bounce(b: Dictionary) -> void:
	var motion: Dictionary = b.get("motion", {})
	var remaining := int(motion.get("bounce_count", 0))
	if remaining <= 0:
		return
	var bounced := false
	if float(b.x) <= 8.0 or float(b.x) >= SCREEN_W - 8.0:
		b.x = clampf(float(b.x), 8.0, SCREEN_W - 8.0)
		b.vx = -float(b.vx)
		bounced = true
	if float(b.y) <= 8.0 or float(b.y) >= SCREEN_H - 8.0:
		b.y = clampf(float(b.y), 8.0, SCREEN_H - 8.0)
		b.vy = -float(b.vy)
		bounced = true
	if bounced:
		motion["bounce_count"] = remaining - 1
		b.motion = motion
		if b.has("stage2_reflection_count"):
			b.stage2_reflection_count = int(b.stage2_reflection_count) + 1

func _update_bullets(delta: float, target: Vector2):
	var dt := delta * 60.0
	bullet_world.update_bullets(dt, Rect2(-60.0, -60.0, SCREEN_W + 120.0, SCREEN_H + 120.0), Callable(self, "_prepare_bullet_world_step"), Callable(self, "_finish_bullet_world_step"))
	_sync_bullet_world_compatibility_views()

func _prepare_bullet_world_step(_bullet_index: int, b: Dictionary, dt: float) -> void:
	if bool(b.get("stage2_field_owned", false)) and typeof(b.get("stage2_defer_linear_step_tick")) == TYPE_INT and int(b.stage2_defer_linear_step_tick) == int(stage_controller.get("stage2_field_tick", -1)):
		b["stage2_deferred_vx"] = float(b.vx)
		b["stage2_deferred_vy"] = float(b.vy)
		b.vx = 0.0
		b.vy = 0.0
	if true:
		var behavior: Dictionary = b.get("behavior", {})
		if String(behavior.get("kind", "")) == "returning_blade":
			if not bool(behavior.get("returned", false)) and float(b.age) >= float(behavior.get("turn_age", 40.0)):
				behavior["returned"] = true
			if bool(behavior.get("returned", false)):
				var response := float(behavior.get("lateral_response", 80.0))
				var return_target := Vector2(player_x + player_last_move_dir.x * response, player_y)
				var return_direction := (return_target - Vector2(float(b.x), float(b.y))).normalized()
				if return_direction != Vector2.ZERO:
					var return_speed := float(behavior.get("return_speed", 6.0))
					b.vx = return_direction.x * return_speed
					b.vy = return_direction.y * return_speed
			b.behavior = behavior
		if b.homing and b.btype >= 0:
			# Tracking ("seeker") player bullet.
			# Behaviour contract:
			#  - By default the bullet flies straight up like a normal shot.
			#  - Only when an enemy lies somewhere *ahead of it* (above the
			#    bullet, within reach horizontally too) does the bullet pick
			#    the nearest such enemy and curve toward it.
			#  - Turn rate is capped so the bullet can't snap around.
			#  - The upward angle is locked to a forward cone: the bullet's
			#    travel heading must stay in [-PI/2 - MAX_DEFLECT, -PI/2 + MAX_DEFLECT].
			#    It can never go horizontal or downward. Untracked bullets
			#    simply fly up and off the top of the screen.
			const MAX_REACH: float = 320.0     # search radius (px)
			const REACH_AHEAD: float = 0.0      # enemy must be ABOVE bullet (e.y < b.y)
			const TURN_RATE: float = 0.03       # rad / frame ~ 1.7閹?frame
			const MAX_DEFLECT: float = PI/3.0   # 60閹?cone around straight-up
			var max_reach := float(behavior.get("tracking_range", MAX_REACH))
			var turn_rate := float(behavior.get("turn_rate", TURN_RATE))
			var max_deflect := float(behavior.get("max_deflect", MAX_DEFLECT))
			var acquisition_half_angle := float(behavior.get("acquisition_half_angle", PI / 2.0))
			var origin: Vector2 = Vector2(b.x, b.y)
			var best_d2: float = max_reach * max_reach + 1.0
			var tg: Vector2 = Vector2.ZERO
			for e in enemies:
				if not e.alive or e.dying: continue
				if e.y > b.y + REACH_AHEAD: continue  # only chase enemies above us
				var rel: Vector2 = Vector2(e.x - b.x, e.y - b.y)
				if absf(wrapf(rel.angle() + PI / 2.0, -PI, PI)) > acquisition_half_angle: continue
				var d2: float = rel.length_squared()
				if d2 < best_d2:
					best_d2 = d2; tg = Vector2(e.x, e.y)
			if boss_alive and boss.get("phase","active") not in ["entering","switching","defeated"] and not boss.get("declaring", false):
				if boss.y < b.y + REACH_AHEAD:
					var brel: Vector2 = Vector2(boss.x - b.x, boss.y - b.y)
					var bd2: float = brel.length_squared()
					if absf(wrapf(brel.angle() + PI / 2.0, -PI, PI)) <= acquisition_half_angle and bd2 < best_d2:
						best_d2 = bd2; tg = Vector2(boss.x, boss.y)
			var spd: float = sqrt(b.vx*b.vx + b.vy*b.vy)
			if tg != Vector2.ZERO and spd > 0.0:
				var cur: float = Vector2(b.vx, b.vy).angle()
				var goal: float = (tg - origin).angle()
				var diff: float = fposmod(goal - cur + PI, TAU) - PI
				var turn: float = clampf(diff, -turn_rate, turn_rate)
				var na: float = cur + turn
				# Lock heading to forward cone around -PI/2 (straight up).
				# -PI/2 is up in screen coords. Clamp na into [-PI/2 - MAX_DEFLECT,
				# -PI/2 + MAX_DEFLECT].
				na = clampf(na, -PI/2 - max_deflect, -PI/2 + max_deflect)
				b.vx = cos(na) * spd
				b.vy = sin(na) * spd
		var has_enemy_motion: bool = bool(b.has_motion)
		if has_enemy_motion:
			_update_enemy_bullet_motion(b, dt)

func _finish_bullet_world_step(_bullet_index: int, b: Dictionary, _dt: float) -> void:
	if bool(b.get("stage2_field_owned", false)):
		if b.has("stage2_deferred_vx") and b.has("stage2_deferred_vy"):
			b.vx = float(b.stage2_deferred_vx)
			b.vy = float(b.stage2_deferred_vy)
		b.erase("stage2_deferred_vx")
		b.erase("stage2_deferred_vy")
		b.erase("stage2_defer_linear_step_tick")
		return
	if bool(b.has_motion) and int(b.motion.get("bounce_count", 0)) > 0:
		_apply_enemy_bullet_bounce(b)

func _stage2_forward_field_source_defeat(enemy: Dictionary) -> bool:
	if not bool(enemy.get("stage2_field_owned", false)) or bool(enemy.get("stage2_source_defeat_forwarded", false)):
		return true
	if not _stage2_field_callback("accept_defeat", int(stage_controller.get("stage2_field_tick", -1)), {"spawn_id": String(enemy.get("stage2_spawn_id", ""))}):
		return false
	enemy["stage2_source_defeat_forwarded"] = true
	enemy["stage2_source_removal_forwarded"] = true
	return true

func _stage2_forward_field_source_removal(enemy: Dictionary, reason: String) -> bool:
	if not bool(enemy.get("stage2_field_owned", false)) or bool(enemy.get("stage2_source_removal_forwarded", false)):
		return true
	if not _stage2_field_callback("remove_source", int(stage_controller.get("stage2_field_tick", -1)), {"spawn_id": String(enemy.get("stage2_spawn_id", "")), "reason": reason}):
		return false
	enemy["stage2_source_removal_forwarded"] = true
	return true

func _update_enemies(delta: float):
	for e in enemies:
		if not e.alive: continue
		if e.dying:
			if not _stage2_forward_field_source_defeat(e):
				return
			e.death_timer -= delta
			if e.death_timer <= 0: e.alive = false
			continue
		e.move_timer += delta * 60.0
		if e.move_timer > 1200:
			if not _stage2_forward_field_source_removal(e, "movement_timeout"):
				return
			e.alive = false
			continue
		match e.move:
			"straight": e.x += e.vx * delta * 60.0; e.y += e.vy * delta * 60.0
			"stage2_authored":
				var duration_ticks := maxf(1.0, float(e.move_data.get("duration_ticks", 1.0)))
				var travel_ratio := clampf(float(e.move_timer) / duration_ticks, 0.0, 1.0)
				var authored_origin: Vector2 = e.move_data.get("origin", Vector2(float(e.x), float(e.y)))
				var authored_destination: Vector2 = e.move_data.get("to", authored_origin)
				e.x = lerpf(authored_origin.x, authored_destination.x, travel_ratio)
				e.y = lerpf(authored_origin.y, authored_destination.y, travel_ratio)
			"sine": e.x += e.vx * delta * 60.0 + sin(e.move_timer*0.08)*e.move_data.get("amplitude",0)*0.05*delta*60.0; e.y += e.vy * delta * 60.0
			"circle":
				if e.move_data.has("center_x"):
					var a: float = e.move_timer * 0.02 * e.move_data.get("speed",1.0)
					e.x = e.move_data.center_x + cos(a) * e.move_data.get("radius",60.0)
					e.y = e.move_data.center_y + sin(a) * e.move_data.get("radius",60.0)
				else: e.x += e.vx * delta * 60.0; e.y += e.vy * delta * 60.0
			"enter_and_stop":
				var lim: float = e.move_data.get("move_time",90.0)
				if e.move_timer < lim: e.x += e.vx * delta * 60.0; e.y += e.vy * delta * 60.0
				else: e.y += sin(e.move_timer*0.03)*0.3*delta*60.0
		e.x = clampf(e.x, 24, SCREEN_W - 24)
		if e.y > SCREEN_H + 40:
			if not _stage2_forward_field_source_removal(e, "left_playfield"):
				return
			e.alive = false
			continue

		# Dead/dying enemies must never emit any bullets - the dying branch
		# above already `continue`s, and we re-check here defensively so any
		# future code path that puts a dying enemy back into the loop stays
		# consistent with that invariant.
		if e.dying:
			continue
		if bool(e.get("stage2_field_owned", false)):
			continue
		# Only fire once the enemy has entered the visible play area.
		# `shoot_timer` is frozen while the enemy is fully off-screen,
		# so bullets never appear "from nowhere" at the screen edge.
		var on_screen: bool = e.y >= -2.0 and e.y <= SCREEN_H and e.x >= -2.0 and e.x <= SCREEN_W + 2
		if on_screen:
			e.shoot_timer -= delta * 60.0
		if on_screen and not e.dying and e.shoot_timer <= 0:
			e.shoot_timer = float(e.get("shoot_interval", 60.0))
			e.shoot_phase += 1
			var mult: float = game_manager_ref.STAGE_MULTS[game_manager_ref.current_stage - 1].bullet_speed
			for spec in enemy_pattern_executor.bullet_specs(e, Vector2(player_x, player_y), mult):
				var stage2_source := {}
				if _active_stage() == 2 and e.has("stage2_event_id"):
					var authored_pattern: Dictionary = e.get("authored_pattern", {})
					stage2_source = {
						"stage2_source_event_id": String(e.get("stage2_event_id", "")),
						"stage2_source_spawn_id": String(e.get("stage2_spawn_id", "")),
						"stage2_source_enemy_id": String(e.get("source_enemy_id", "")),
						"stage2_primitive": String(authored_pattern.get("primitive", "")),
						"stage2_routing": String(authored_pattern.get("routing", "")),
					}
				_spawn_enemy_bullet_spec(spec, stage2_source)

func _update_items(delta: float):
	for it in items:
		if it.collected: continue
		it.anim += 0.06 * delta * 60.0
		if it.birth > 0: it.birth -= delta * 60.0
		if not bool(it.get("magnetized", false)) and _item_magnetize_requested(_focus_held()):
			it.magnetized = true
			it.floating = false

		# Phase 1 - float straight up to the top 1/5 of the screen (target_y).
		# This is reached both at spawn from enemy drops (y around e.y) and at
		# the player's death pickups (y around player_y). Items keep a small
		# sway for visual flavour while rising.
		if it.floating:
			if it.y <= it.target_y:
				it.floating = false
				# Initialize horizontal drift direction (random, +1 or -1).
				if it.get("drift_dir", 0.0) == 0.0:
					it["drift_dir"] = 1.0 if gameplay_rng.next_float() < 0.5 else -1.0
				it.vy = 0.4   # slow fall after reaching top
				it.vx = it["drift_dir"] * 0.7
			else:
				it.y += it.vy * delta * 60.0
				it.x += sin(it.anim*0.06*2+it.sway)*0.5*delta*60.0
				it.x = clampf(it.x,11, SCREEN_W - 11)
			continue

		# Shift permanently magnetizes a drop from any phase, including while
		# a bomb is active. This makes collection independent of bomb visuals.
		if it.get("magnetized", false):
			var a: float = (Vector2(player_x,player_y)-Vector2(it.x,it.y)).angle()
			it.vx = cos(a)*20.0; it.vy = sin(a)*20.0
		else:
			# Slow horizontal drift with wall bounce.
			var dir: float = it.get("drift_dir", 1.0)
			var drift_speed: float = 0.7
			if it.x <= 11.0:
				dir = 1.0
			elif it.x >= SCREEN_W - 11.0:
				dir = -1.0
			it["drift_dir"] = dir
			it.vx = dir * drift_speed
			# Slow downward fall; gently accelerate near the bottom of the screen.
			var base: float = 0.4
			if it.y > 428.0:
				base += (it.y-428.0)/212.0*2.0
			it.vy = base

		it.x += it.vx * delta * 60.0
		it.y += it.vy * delta * 60.0
		it.x = clampf(it.x, 11, SCREEN_W - 11)
		if it.y > SCREEN_H + 30:
			it.alive = false

func _count_alive_enemies() -> int:
	var c: int = 0
	for e in enemies: if e.alive and not e.dying: c += 1
	return c

func _count_active_bullets_by_owner() -> Dictionary:
	var player_count: int = 0
	var enemy_count: int = 0
	_ensure_active_bullet_indices()
	for bullet_index in active_bullet_indices:
		var b = bullet_pool[bullet_index]
		if not b.active:
			continue
		if b.type == "player" or b.type == "bomb":
			player_count += 1
		elif _is_enemy_bullet_type(String(b.type)):
			enemy_count += 1
	return {"player": player_count, "enemy": enemy_count}

func _count_bullet_draw_groups() -> int:
	var groups: Dictionary = {}
	_ensure_active_bullet_indices()
	for bullet_index in active_bullet_indices:
		var b = bullet_pool[bullet_index]
		if not b.active:
			continue
		groups["%s:%s" % [String(b.type), str(b.get("btype", ""))]] = true
	return groups.size()

func _update_performance_counters() -> void:
	var monitor: Node = performance_monitor_ref if performance_monitor_ref else get_node_or_null("/root/PerformanceMonitor")
	if not monitor:
		return
	var player_bullet_count: int = 0
	var enemy_bullet_count: int = 0
	var draw_groups: Dictionary = {}
	_ensure_active_bullet_indices()
	for bullet_index in active_bullet_indices:
		var b = bullet_pool[bullet_index]
		if not b.active:
			continue
		if b.type == "player" or b.type == "bomb":
			player_bullet_count += 1
		else:
			enemy_bullet_count += 1
		draw_groups["%s:%s" % [String(b.type), str(b.get("btype", ""))]] = true
	monitor.reset_frame()
	monitor.set_counter("fps", int(Engine.get_frames_per_second()))
	monitor.set_counter("player_bullets", player_bullet_count)
	monitor.set_counter("enemy_bullets", enemy_bullet_count)
	monitor.set_counter("enemies", _count_alive_enemies())
	monitor.set_counter("items", items.size())
	monitor.set_counter("boss_alive", 1 if boss_alive else 0)
	monitor.set_counter("draw_groups", draw_groups.size())

func _player_bullet_effective_damage(bullet: Dictionary) -> float:
	var behavior: Dictionary = bullet.get("behavior", {})
	if String(behavior.get("kind", "")) != "distance_damage":
		return float(bullet.damage)
	var origin: Vector2 = behavior.get("origin", Vector2(float(bullet.x), float(bullet.y)))
	var distance := origin.distance_to(Vector2(float(bullet.x), float(bullet.y)))
	var ratio := clampf(distance / maxf(float(behavior.get("near_range", 1.0)), 1.0), 0.0, 1.0)
	var multiplier := lerpf(float(behavior.get("near_multiplier", 1.0)), float(behavior.get("far_multiplier", 1.0)), ratio)
	return float(bullet.damage) * multiplier

func _player_bullet_hit_phase(bullet: Dictionary) -> String:
	var behavior: Dictionary = bullet.get("behavior", {})
	return "return" if String(behavior.get("kind", "")) == "returning_blade" and bool(behavior.get("returned", false)) else "outbound"

func _player_bullet_can_hit(bullet: Dictionary, target_key: String) -> bool:
	var behavior: Dictionary = bullet.get("behavior", {})
	if int(bullet.get("hit_count", 0)) >= int(behavior.get("max_hits", 1)):
		return false
	var ledger: Dictionary = bullet.get("hit_ledger", {})
	if String(behavior.get("kind", "")) == "sustained_laser":
		return float(bullet.age) - float(ledger.get(target_key, -1000000.0)) >= float(behavior.get("repeat_interval", 6.0))
	return not ledger.has("%s:%s" % [target_key, _player_bullet_hit_phase(bullet)])

func _record_player_bullet_hit(bullet: Dictionary, target_key: String) -> void:
	var behavior: Dictionary = bullet.get("behavior", {})
	var ledger: Dictionary = bullet.get("hit_ledger", {})
	if String(behavior.get("kind", "")) == "sustained_laser":
		ledger[target_key] = float(bullet.age)
	else:
		ledger["%s:%s" % [target_key, _player_bullet_hit_phase(bullet)]] = true
	bullet.hit_ledger = ledger
	bullet.hit_count = int(bullet.get("hit_count", 0)) + 1

func _player_bullet_is_piercing(bullet: Dictionary) -> bool:
	return bool(bullet.get("behavior", {}).get("piercing", false))

func _retire_player_bullet_after_hit(bullet_index: int, bullet: Dictionary) -> bool:
	var behavior: Dictionary = bullet.get("behavior", {})
	var reached_hit_cap := int(bullet.get("hit_count", 0)) >= int(behavior.get("max_hits", 1))
	if _player_bullet_is_piercing(bullet) and not reached_hit_cap:
		return false
	bullet_world.retire_slot(bullet_index)
	return true

func _stage2_field_collision_enabled(bullet: Dictionary) -> bool:
	if not bool(bullet.get("stage2_field_owned", false)):
		return true
	if typeof(bullet.get("stage2_collision_enable_tick")) != TYPE_INT:
		return false
	return int(stage_controller.get("stage2_field_tick", -1)) >= int(bullet.stage2_collision_enable_tick)

func _check_collisions(is_boss: bool):
	var player_hitbox_radius: float = _player_hitbox_radius()
	var player_graze_radius: float = _player_graze_radius()
	var player_candidates: Array[int] = bullet_world.query_circle(Vector2(player_x, player_y), player_graze_radius, [], ["player", "bomb"])
	for bullet_index in bullet_world.active_order():
		var b = bullet_pool[bullet_index]
		if not bullet_world.collision_enabled(b) or not _stage2_field_collision_enabled(b): continue
		if b.type == "player" or b.type == "bomb":
			if is_boss and boss_alive:
				if boss.declaring or boss.phase in ["entering","switching","defeated"]: continue
				if b.type == "bomb" and bool(b.get("boss_hit", false)): continue
				if bullet_world.circles_overlap(Vector2(float(b.x), float(b.y)), float(b.radius), Vector2(float(boss.x), float(boss.y)), _boss_collision_radius()) and (b.type == "bomb" or _player_bullet_can_hit(b, "boss")):
					boss.hp -= b.damage if b.type == "bomb" else _player_bullet_effective_damage(b)
					if audio_manager_ref: audio_manager_ref.play_sfx("boss_hit")
					if b.type == "player":
						_record_player_bullet_hit(b, "boss")
						_retire_player_bullet_after_hit(bullet_index, b)
					else:
						b.boss_hit = true
			else:
				for enemy_index in range(enemies.size()):
					var e: Dictionary = enemies[enemy_index]
					if not e.alive or e.dying: continue
					if bullet_world.circles_overlap(Vector2(float(b.x), float(b.y)), float(b.radius), Vector2(float(e.x), float(e.y)), float(e.radius)):
						var player_bullet_retired := false
						var target_key := "enemy:%d" % enemy_index
						if b.type == "player" and not _player_bullet_can_hit(b, target_key): continue
						e.hp -= b.damage if b.type == "bomb" else _player_bullet_effective_damage(b)
						if audio_manager_ref: audio_manager_ref.play_sfx("enemy_hit")
						if b.type == "player":
							_record_player_bullet_hit(b, target_key)
							player_bullet_retired = _retire_player_bullet_after_hit(bullet_index, b)
						if e.hp <= 0 and not e.dying:
							e.dying = true; e.death_timer = 8.0
							if not _stage2_forward_field_source_defeat(e):
								return
							_spawn_combat_effect("enemy_defeat", Vector2(e.x, e.y), float(e.radius), Color(1.0, 0.72, 0.28) if e.strong else Color(0.76, 0.42, 1.0))
							if e.has("drop_item_ids"):
								_emit_enemy_drops(e)
							else:
								_drop_item(e.x, e.y, e.strong, String(e.get("drop_tier", "")))
							game_manager_ref.score += int(game_database_ref.scoring_rules().enemy_defeat) if game_database_ref else 50
							if audio_manager_ref: audio_manager_ref.play_sfx("enemy_defeat", -6.0 if e.strong else -8.0)
						if player_bullet_retired or not _player_bullet_is_piercing(b): break
		else:
			if bullet_index not in player_candidates:
				continue
			var dx: float = float(b.x) - player_x
			var dy: float = float(b.y) - player_y
			var graze_limit: float = float(b.radius) + player_graze_radius
			if absf(dx) > graze_limit or absf(dy) > graze_limit:
				continue
			var distance_squared: float = dx * dx + dy * dy
			var hit_limit: float = float(b.radius) + player_hitbox_radius
			if not player_invincible and distance_squared < hit_limit * hit_limit:
				if not bool(b.get("stage2_field_owned", false)):
					bullet_world.retire_slot(bullet_index)
				if not player_just_hit:
					player_just_hit = true
					player_deathbomb_primed = true
					player_deathbomb_timer = game_manager_ref.DEATHBOMB_WINDOW / 60.0
					if audio_manager_ref:
						audio_manager_ref.play_sfx("player_hit", -2.0)
						audio_manager_ref.play_sfx("deathbomb_window")
			elif distance_squared < graze_limit * graze_limit and not bool(b.get("grazed", false)):
				if bool(b.get("stage2_field_owned", false)):
					var grazed_uid := String(b.get("stage2_bullet_uid", ""))
					if not _stage2_field_callback("observe_graze", int(stage_controller.get("stage2_field_tick", -1)), {"bullet_uid": grazed_uid}):
						return
					var committed_bindings: Dictionary = stage_controller.get("stage2_field_uid_to_slot", {})
					if not committed_bindings.has(grazed_uid):
						_stage2_fail_closed("Stage 2 grazed field bullet lost its committed UID binding")
						return
					var committed_slot := int(committed_bindings[grazed_uid])
					if committed_slot < 0 or committed_slot >= bullet_pool.size() or not bool(bullet_pool[committed_slot].get("active", false)):
						_stage2_fail_closed("Stage 2 grazed field bullet lost its committed BulletWorld slot")
						return
					bullet_pool[committed_slot].grazed = true
				else:
					b.grazed = true
				game_manager_ref.graze += 1; game_manager_ref.score += _score_value("graze", 10)
				if audio_manager_ref: audio_manager_ref.play_sfx("graze")

	# Item collection
	for it in items:
		if it.collected or not it.alive: continue
		if Vector2(it.x,it.y).distance_to(Vector2(player_x,player_y)) < it.radius + 24.0:
			_collect(it)

func _settle_realtime_graze_rewards(graze_total: int) -> void:
	# Compatibility seam: graze is score-only in M1. Resource fragments are
	# granted exclusively by authored item drops.
	var _score_only_total := graze_total

func _spawn_authored_item(x: float, y: float, item_type: String, ordinal: int) -> void:
	var side := -1.0 if ordinal % 2 == 0 else 1.0
	var lane := float(ordinal / 2 + 1)
	items.append({
		"alive":true, "collected":false,
		"x":x + side * lane * 6.0, "y":y,
		"type":item_type, "radius":9.0,
		"vy":-2.5, "vx":side * (0.12 + lane * 0.04),
		"floating":true, "target_y":128.0,
		"drift_dir":side, "sway":fposmod(float(ordinal) * 1.61803398875, TAU),
		"birth":15.0, "anim":fposmod(float(ordinal) * 0.754877666, TAU),
	})

func _emit_enemy_drops(enemy: Dictionary) -> void:
	var drop_item_ids: Array = enemy.get("drop_item_ids", LEGACY_ENEMY_DROP_IDS)
	for ordinal in range(drop_item_ids.size()):
		_spawn_authored_item(float(enemy.x), float(enemy.y), String(drop_item_ids[ordinal]), ordinal)

func _drop_item_type(strong: bool, roll: float, drop_tier: String = "") -> String:
	var tier := drop_tier
	if tier == "":
		tier = "rich" if strong else "light"
	return item_reward_system.choose_drop(tier, roll)

func _drop_item(x: float, y: float, strong: bool, drop_tier: String = "", roll_override: float = -1.0):
	var drop_roll: float = roll_override if roll_override >= 0.0 else gameplay_rng.next_float()
	var t: String = _drop_item_type(strong, drop_roll, drop_tier)
	items.append({"alive":true,"collected":false,"x":x,"y":y,"type":t,"radius":9.0,"vy":-2.5,"vx":gameplay_rng.range_float(-0.3,0.3),"floating":true,"target_y":128.0,"drift_dir":0.0,"sway":gameplay_rng.range_float(0.0,TAU),"birth":15.0,"anim":gameplay_rng.range_float(0.0,TAU)})

func _collect(it: Dictionary):
	_collect_item(it)

func _collect_item(it: Dictionary):
	it.collected = true
	it.alive = false
	var result: Dictionary = item_reward_system.apply_collection(String(it.type), game_manager_ref, float(it.get("y", player_y)), game_manager_ref.SCREEN_H * game_manager_ref.ITEM_TOP_RATIO)
	if audio_manager_ref:
		audio_manager_ref.play_sfx("item_collect")
		var resource_delta: Dictionary = result.get("resource_delta", {})
		if int(resource_delta.get("lives", 0)) > 0:
			audio_manager_ref.play_sfx("life_gain")
		if int(resource_delta.get("bombs", 0)) > 0:
			audio_manager_ref.play_sfx("bomb_gain")

func _draw_ui_background(accent: Color) -> void:
	draw_rect(_display_rect(), Color(0.04, 0.05, 0.08))
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H * 0.34), Color(accent.r, accent.g, accent.b, 0.18))
	draw_circle(Vector2(SCREEN_W * 0.5, SCREEN_H * 0.22), SCREEN_W * 0.18, Color(accent.r, accent.g, accent.b, 0.18))
	draw_line(Vector2(84, SCREEN_H * 0.18), Vector2(SCREEN_W - 84, SCREEN_H * 0.18), Color(1, 1, 1, 0.22), 2)

func _draw_ui_heading(font: Font, title: String, subtitle: String, title_size: int = 34) -> void:
	draw_string(font, Vector2(_centered_text_x_at_size(font, title, title_size), 156), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color.WHITE)
	if subtitle != "":
		draw_string(font, Vector2(_centered_text_x_at_size(font, subtitle, 18), 190), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.82, 0.86, 0.95))

func _draw_menu_entries(font: Font, entries: Array, cursor: int, start_y: float, row_height: float) -> void:
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y: float = start_y + row_height * i
		var selected: bool = i == cursor
		var row_rect := Rect2(76, y - 28.0, SCREEN_W - 152.0, 58.0)
		if selected:
			draw_rect(row_rect, Color(0.86, 0.18, 0.28, 0.34))
			draw_rect(row_rect, Color(1.0, 0.72, 0.78, 0.82), false, 2)
		var marker: String = "\u25b6" if selected else " "
		var label: String = "%s %s" % [marker, String(entry.get("label", ""))]
		var label_color := Color.WHITE if selected else Color(0.82, 0.86, 0.95)
		draw_string(font, Vector2(106, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, label_color)
		var description: String = String(entry.get("description", ""))
		if description != "":
			draw_string(font, Vector2(132, y + 24.0), description, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.58, 0.65, 0.76))

func _draw_entry_detail_lines(font: Font, entries: Array, cursor: int, start_y: float, row_height: float) -> void:
	if entries.is_empty():
		return
	var entry: Dictionary = entries[clampi(cursor, 0, entries.size() - 1)]
	var detail_lines: Array = entry.get("detail_lines", [])
	var y := start_y + entries.size() * row_height + 22.0
	for i in range(min(detail_lines.size(), 4)):
		draw_string(font, Vector2(78, y + i * 22.0), String(detail_lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.78, 0.82, 0.88))

func _draw_character_choice_cards(font: Font, entries: Array, cursor: int) -> void:
	var card_width := 174.0
	var card_height := 342.0
	var gap := 18.0
	var start_x := (SCREEN_W - card_width * entries.size() - gap * maxi(entries.size() - 1, 0)) * 0.5
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var selected := i == cursor
		var card := Rect2(start_x + i * (card_width + gap), 232.0, card_width, card_height)
		draw_rect(card, Color(0.025, 0.035, 0.055, 0.90 if selected else 0.72))
		draw_rect(card, Color(1.0, 0.68, 0.34, 0.96) if selected else Color(0.34, 0.78, 0.88, 0.52), false, 3.0 if selected else 1.5)
		var assets := _protagonist_asset_paths(String(entry.get("id", "")))
		var portrait_rect := Rect2(card.position.x + 12.0, card.position.y + 12.0, card_width - 24.0, 222.0)
		_draw_portrait_icon(String(assets.get("portrait", "")), portrait_rect, Color.WHITE if selected else Color(0.78, 0.82, 0.88, 0.88))
		draw_rect(portrait_rect, Color(1.0, 0.78, 0.45, 0.72) if selected else Color(0.42, 0.72, 0.82, 0.40), false, 1.5)
		var label := String(entry.get("label", ""))
		draw_string(font, Vector2(card.position.x + 8.0, card.position.y + 269.0), label, HORIZONTAL_ALIGNMENT_CENTER, card_width - 16.0, 21, Color.WHITE)
		draw_string(font, Vector2(card.position.x + 10.0, card.position.y + 304.0), String(entry.get("description", "")), HORIZONTAL_ALIGNMENT_CENTER, card_width - 20.0, 14, Color(0.78, 0.84, 0.91))
		if selected:
			draw_circle(Vector2(card.end.x - 16.0, card.position.y + 16.0), 7.0, Color(1.0, 0.34, 0.28))

func _draw_shot_choice_cards(font: Font, entries: Array, cursor: int) -> void:
	var card_width := 250.0
	var card_height := 286.0
	var gap := 32.0
	var start_x := (SCREEN_W - card_width * entries.size() - gap * maxi(entries.size() - 1, 0)) * 0.5
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var selected := i == cursor
		var card := Rect2(start_x + i * (card_width + gap), 274.0, card_width, card_height)
		draw_rect(card, Color(0.025, 0.035, 0.055, 0.90 if selected else 0.72))
		draw_rect(card, Color(1.0, 0.68, 0.34, 0.96) if selected else Color(0.34, 0.78, 0.88, 0.52), false, 3.0 if selected else 1.5)
		var asset_id := String(SHOT_SELECTION_ART_BY_ID.get(String(entry.get("id", "")), "player_bullet_focus_lance"))
		_draw_texture_centered(_bullet_asset_path(asset_id), Vector2(card.get_center().x, card.position.y + 91.0), Vector2(112.0, 112.0), Color.WHITE if selected else Color(0.76, 0.82, 0.90, 0.88))
		var label := String(entry.get("label", ""))
		draw_string(font, Vector2(card.position.x + 12.0, card.position.y + 176.0), label, HORIZONTAL_ALIGNMENT_CENTER, card_width - 24.0, 22, Color.WHITE)
		draw_string(font, Vector2(card.position.x + 18.0, card.position.y + 214.0), String(entry.get("description", "")), HORIZONTAL_ALIGNMENT_CENTER, card_width - 36.0, 15, Color(0.78, 0.84, 0.91))
		if selected:
			draw_circle(Vector2(card.end.x - 18.0, card.position.y + 18.0), 8.0, Color(1.0, 0.34, 0.28))

func _setting_value_text(entry: Dictionary) -> String:
	match String(entry.get("type", "")):
		"toggle":
			return "\u5f00\u542f" if bool(entry.get("value", false)) else "\u5173\u95ed"
		"range":
			return "%d%%" % int(round(float(entry.get("value", 0.0)) * 100.0))
		_:
			return String(entry.get("value", ""))

func _draw_settings_entries(font: Font, entries: Array, cursor: int) -> void:
	var start_y: float = 254.0
	var row_height: float = 72.0
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y: float = start_y + row_height * i
		var selected: bool = i == cursor
		var row_rect := Rect2(54, y - 30.0, SCREEN_W - 108.0, 62.0)
		draw_rect(row_rect, Color(0.025, 0.035, 0.055, 0.88 if selected else 0.72))
		draw_rect(row_rect, Color(1.0, 0.68, 0.34, 0.96) if selected else Color(0.34, 0.78, 0.88, 0.46), false, 2.5 if selected else 1.25)
		if selected:
			draw_circle(Vector2(row_rect.end.x - 16.0, row_rect.position.y + 14.0), 6.0, Color(1.0, 0.34, 0.28))
		var marker: String = "\u25b6" if selected else " "
		var label_color := Color.WHITE if selected else Color(0.84, 0.88, 0.94)
		draw_string(font, Vector2(78, y), "%s %s" % [marker, String(entry.get("label", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, label_color)
		draw_string(font, Vector2(102, y + 23.0), String(entry.get("description", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.58, 0.65, 0.76))
		var value_text: String = _setting_value_text(entry)
		var value_w: float = font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x
		draw_string(font, Vector2(SCREEN_W - 78.0 - value_w, y), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.92, 0.58))

func _draw_control_hint(font: Font, hint: String, y: float, font_size: int = 16, color: Color = Color(0.68, 0.74, 0.84)) -> void:
	if not _should_show_input_guide():
		return
	draw_string(font, Vector2(_centered_text_x_at_size(font, hint, font_size), y), hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _performance_monitor_node() -> Node:
	if performance_monitor_ref:
		return performance_monitor_ref
	if is_inside_tree() and has_node("/root/PerformanceMonitor"):
		return get_node_or_null("/root/PerformanceMonitor")
	return null

func _draw_performance_hud(font: Font) -> void:
	if not _should_show_performance_hud():
		return
	var monitor: Node = _performance_monitor_node()
	var snapshot: Dictionary = monitor.snapshot() if monitor and monitor.has_method("snapshot") else {}
	var fps_value: int = int(snapshot.get("fps", Engine.get_frames_per_second()))
	var player_bullets: int = int(snapshot.get("player_bullets", 0))
	var enemy_bullets: int = int(snapshot.get("enemy_bullets", 0))
	var enemy_count: int = int(snapshot.get("enemies", 0))
	var item_count: int = int(snapshot.get("items", 0))
	var draw_groups: int = int(snapshot.get("draw_groups", 0))
	var lines := [
		"FPS %d" % fps_value,
		"P %d  E %d" % [player_bullets, enemy_bullets],
		"EN %d  I %d  G %d" % [enemy_count, item_count, draw_groups],
	]
	var box_rect := _performance_hud_rect()
	draw_rect(box_rect, Color(0.0, 0.0, 0.0, 0.58))
	draw_rect(box_rect, Color(0.7, 0.9, 1.0, 0.46), false, 1)
	for i in range(lines.size()):
		draw_string(font, Vector2(box_rect.position.x + 8.0, box_rect.position.y + 18.0 + 18.0 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.84, 0.95, 1.0))

func _draw_gameplay_input_guide(font: Font) -> void:
	if not _should_show_input_guide():
		return
	var hint := "Shift \u4f4e\u901f/\u5224\u5b9a\u70b9    Z \u5c04\u51fb    X \u70b8\u5f39    Esc \u6682\u505c"
	var text_w: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	draw_string(font, Vector2(maxf(10.0, SCREEN_W - 12.0 - text_w), SCREEN_H - 36.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.68, 0.74, 0.84))

func _draw_title_screen() -> void:
	var font := SystemFont.new()
	_draw_ui_background(Color(0.55, 0.14, 0.22))
	_draw_texture_rect_path(_ui_asset_path("title_key_art"), Rect2(0, 0, SCREEN_W, SCREEN_H * 0.46), Color(1, 1, 1, 0.38))
	_draw_phase6_ui_window("main_menu_frame", 0.82)
	_draw_ui_heading(font, "\u4e1c\u65b9\u5f39\u5e55", "\u6807\u9898\u83dc\u5355", 38)
	_draw_menu_entries(font, ui_model.main_menu_entries(), main_menu_cursor, 314.0, 76.0)
	var hint := "\u65b9\u5411\u952e\u9009\u62e9    Z \u786e\u8ba4    X/Esc \u8fd4\u56de"
	_draw_control_hint(font, hint, SCREEN_H - 78.0)

func _draw_character_select_screen() -> void:
	var font := SystemFont.new()
	_draw_ui_background(Color(0.16, 0.38, 0.56))
	_draw_phase6_ui_window("character_select_frame", 0.84)
	var mode_label: String = "\u6a21\u5f0f\uff1a\u7ec3\u4e60" if game_manager_ref.practice_mode else "\u6a21\u5f0f\uff1a\u6545\u4e8b"
	_draw_ui_heading(font, "\u89d2\u8272\u9009\u62e9", mode_label, 34)
	var entries: Array = ui_model.protagonist_entries()
	_draw_character_choice_cards(font, entries, character_menu_cursor)
	_draw_entry_detail_lines(font, entries, character_menu_cursor, 592.0, 0.0)
	var hint := "\u65b9\u5411\u952e\u9009\u62e9    Z \u786e\u8ba4    X/Esc \u8fd4\u56de\u6807\u9898"
	_draw_control_hint(font, hint, SCREEN_H - 78.0)

func _draw_practice_select_screen() -> void:
	var font := SystemFont.new()
	_draw_ui_background(Color(0.18, 0.42, 0.36))
	_draw_phase6_ui_window("main_menu_frame", 0.68)
	_draw_ui_heading(font, "关卡练习", "已到达关卡可选择", 34)
	var entries: Array = ui_model.practice_stage_entries(game_manager_ref.STAGE_NAMES, game_manager_ref.highest_reached_stage)
	_draw_menu_entries(font, entries, practice_menu_cursor, 282.0, 76.0)
	_draw_control_hint(font, "方向键选择    Z 确认    X/Esc 返回", SCREEN_H - 78.0)

func _draw_phase_practice_select_screen() -> void:
	var font := SystemFont.new()
	_draw_ui_background(Color(0.30, 0.20, 0.42))
	_draw_phase6_ui_window("main_menu_frame", 0.72)
	_draw_ui_heading(font, "第二关 符卡练习", "选择一个已批准的阶段", 34)
	var entries: Array = ui_model.stage2_phase_practice_entries()
	_draw_menu_entries(font, entries, phase_practice_menu_cursor, 224.0, 64.0)
	_draw_control_hint(font, "方向键选择    Z 确认    X/Esc 返回", SCREEN_H - 78.0)

func _draw_shot_select_screen() -> void:
	var font := SystemFont.new()
	_draw_ui_background(Color(0.46, 0.32, 0.12))
	_draw_phase6_ui_window("main_menu_frame", 0.50)
	var protagonists: Array = ui_model.protagonist_entries()
	var protagonist_label: String = _entry_label_by_id(protagonists, String(game_manager_ref.selected_protagonist_id))
	_draw_ui_heading(font, "\u5c04\u51fb\u9009\u62e9", "\u5df2\u9009\u89d2\u8272\uff1a%s" % protagonist_label, 34)
	var shots: Array = ui_model.shot_entries(String(game_manager_ref.selected_protagonist_id))
	_draw_shot_choice_cards(font, shots, shot_menu_cursor)
	_draw_entry_detail_lines(font, shots, shot_menu_cursor, 594.0, 0.0)
	var hint := "\u65b9\u5411\u952e\u9009\u62e9    Z \u5f00\u59cb    X/Esc \u8fd4\u56de\u89d2\u8272"
	_draw_control_hint(font, hint, SCREEN_H - 78.0)

func _draw_settings_screen() -> void:
	var font := SystemFont.new()
	_draw_phase6_stage_background_rect(false, _display_rect())
	draw_rect(_display_rect(), Color(0.01, 0.015, 0.025, 0.70))
	_draw_phase6_ui_window("main_menu_frame", 0.82)
	var subtitle := "\u5de6\u53f3\u8c03\u6574    Z \u5207\u6362    X/Esc \u8fd4\u56de" if _should_show_input_guide() else ""
	_draw_ui_heading(font, "\u8bbe\u7f6e", subtitle, 34)
	_draw_settings_entries(font, ui_model.settings_entries(game_manager_ref.settings), settings_menu_cursor)

func _draw_pause_overlay() -> void:
	var entries: Array = ui_model.pause_menu_entries()
	var font := SystemFont.new()
	draw_rect(Rect2(0, -HUD_HEIGHT, SCREEN_W, SCREEN_H + HUD_HEIGHT), Color(0.0, 0.0, 0.0, 0.56))
	_draw_phase6_ui_fullscreen("pause_panel", 0.76)
	var row_height := 54.0
	var panel_width: float = minf(420.0, SCREEN_W - 80.0)
	var panel_height: float = 112.0 + row_height * entries.size()
	var panel_rect := Rect2((SCREEN_W - panel_width) * 0.5, SCREEN_H * 0.075, panel_width, panel_height)
	draw_rect(panel_rect, Color(0.05, 0.06, 0.09, 0.9))
	draw_rect(panel_rect, Color(0.88, 0.24, 0.32, 0.84), false, 2)
	var title := "\u6682\u505c"
	draw_string(font, Vector2(_centered_text_x_at_size(font, title, 30), panel_rect.position.y + 50.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color.WHITE)
	var start_y := panel_rect.position.y + 102.0
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var y: float = start_y + row_height * i
		var selected: bool = i == pause_menu_cursor
		var row_rect := Rect2(panel_rect.position.x + 26.0, y - 28.0, panel_width - 52.0, 44.0)
		if selected:
			draw_rect(row_rect, Color(0.86, 0.18, 0.28, 0.36))
			draw_rect(row_rect, Color(1.0, 0.72, 0.78, 0.82), false, 2)
		var marker := "\u25b6" if selected else " "
		var label := "%s %s" % [marker, String(entry.get("label", ""))]
		draw_string(font, Vector2(row_rect.position.x + 18.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color.WHITE if selected else Color(0.84, 0.88, 0.94))
	var hint := "Z \u786e\u8ba4    X/Esc \u7ee7\u7eed"
	_draw_control_hint(font, hint, panel_rect.position.y + panel_height - 24.0)

func _draw():
	if not is_inside_tree(): return
	var gm_ui = game_manager_ref
	if gm_ui:
		match gm_ui.state:
			"title":
				_draw_title_screen()
				return
			"character_select":
				_draw_character_select_screen()
				return
			"practice_select":
				_draw_practice_select_screen()
				return
			"phase_practice_select":
				_draw_phase_practice_select_screen()
				return
			"shot_select":
				_draw_shot_select_screen()
				return
			"settings":
				_draw_settings_screen()
				return
	var font := SystemFont.new()
	_draw_phase6_stage_background(gm_ui != null and gm_ui.state == "boss")
	_draw_gameplay_hud_background()
	_draw_combat_effects()
	_draw_phase6_boss_aura()
	_draw_phase6_bomb_plate()
	# Items
	for it in items:
		if not it.alive or it.birth > 0: continue
		if float(it.y) < 20.0: continue
		var ix: int = int(it.x); var iy: int = int(it.y)
		if _draw_phase6_item_sprite(it, Vector2(ix, iy)):
			_draw_item_effect_marker(font, String(it.type), Vector2(ix, iy))
			continue
		match it.type:
			"power": draw_circle(Vector2(ix,iy),9,Color.RED); draw_circle(Vector2(ix,iy),9,Color.WHITE,false,2)
			"full_power": draw_circle(Vector2(ix,iy),11,Color(1.0,0.72,0.16)); draw_circle(Vector2(ix,iy),11,Color.WHITE,false,2)
			"point":
				var pts: PackedVector2Array = PackedVector2Array([Vector2(ix,iy-9),Vector2(ix+9,iy),Vector2(ix,iy+9),Vector2(ix-9,iy)])
				draw_colored_polygon(pts,Color.BLUE); draw_polyline(pts,Color.WHITE,1,true)
			"bomb_refill":
				var pts2: PackedVector2Array = PackedVector2Array()
				for i in range(6): var a: float = TAU/6*i-PI/2; pts2.append(Vector2(ix+cos(a)*(9 if i%2==0 else 4.5),iy+sin(a)*(9 if i%2==0 else 4.5)))
				draw_colored_polygon(pts2,Color.ORANGE)
			"bomb_fragment":
				var bomb_pts: PackedVector2Array = PackedVector2Array([Vector2(ix,iy-10),Vector2(ix+8,iy-2),Vector2(ix+5,iy+8),Vector2(ix-5,iy+8),Vector2(ix-8,iy-2)])
				draw_colored_polygon(bomb_pts,Color(1.0,0.46,0.12))
				draw_polyline(bomb_pts,Color.WHITE,1,true)
				draw_circle(Vector2(ix,iy),3,Color(1.0,0.86,0.42))
			"night_festival_seal":
				var seal_pts: PackedVector2Array = PackedVector2Array([Vector2(ix, iy - 11), Vector2(ix + 8, iy - 3), Vector2(ix + 7, iy + 8), Vector2(ix - 7, iy + 8), Vector2(ix - 8, iy - 3)])
				draw_colored_polygon(seal_pts, Color(0.85, 0.18, 0.34))
				draw_polyline(seal_pts, Color.WHITE, 1, true)
				draw_line(Vector2(ix - 4, iy), Vector2(ix + 4, iy), Color(1.0, 0.86, 0.42), 2)
			"life", "life_fragment": draw_rect(Rect2(ix-9,iy-9,18,18),Color.PINK); draw_rect(Rect2(ix-9,iy-9,18,18),Color.WHITE,false,2)
			_:
				var bt: int = 0
				if it.type == "bullet_linear": bt = 1
				elif it.type == "bullet_homing": bt = 2
				var hex: PackedVector2Array = PackedVector2Array()
				for i in range(6): hex.append(Vector2(ix+cos(TAU/6*i-PI/6)*10,iy+sin(TAU/6*i-PI/6)*10))
				draw_colored_polygon(hex,game_manager_ref.BULLET_COLORS[bt]); draw_polyline(hex,Color.WHITE,2,true)
		_draw_item_effect_marker(font, String(it.type), Vector2(ix, iy))

	# Enemies
	for e in enemies:
		if not e.alive or e.dying: continue
		var enemy_visual_half := clampf(float(e.radius) * 1.9, 21.0, 41.0)
		if float(e.y) < enemy_visual_half: continue
		var ix: int = int(e.x); var iy: int = int(e.y)
		if _draw_phase6_enemy_sprite(e, Vector2(ix, iy)):
			continue
		var col: Color = Color.GOLD if e.strong else Color(0.47,0.16,0.71)
		draw_circle(Vector2(ix,iy),e.radius,col); draw_circle(Vector2(ix,iy),e.radius,Color.WHITE,false,1)
		draw_line(Vector2(ix-e.radius,iy+2),Vector2(ix-e.radius-8,iy-8+sin(e.move_timer*0.1)*3),Color(0.71,0.31,0.94),2)
		draw_line(Vector2(ix+e.radius,iy+2),Vector2(ix+e.radius+8,iy-8+sin(e.move_timer*0.1)*3),Color(0.71,0.31,0.94),2)
		draw_circle(Vector2(ix-3,iy-2),2,Color.WHITE); draw_circle(Vector2(ix+3,iy-2),2,Color.WHITE)
		if e.strong:
			var cr: PackedVector2Array = PackedVector2Array([Vector2(ix,iy-e.radius-8),Vector2(ix-5,iy-e.radius-1),Vector2(ix+5,iy-e.radius-1)])
			draw_colored_polygon(cr,Color.GOLD)

	# Boss body stays below live bullets so spell patterns remain readable.
	if boss_alive and boss.has("phase") and boss.get("phase", "") != "defeated":
		var boss_center := Vector2(float(boss.get("x", _screen_center_x())), float(boss.get("y", _boss_anchor_y())))
		var boss_visual_half := clampf(float(boss.get("radius", 28.0)) * 1.9, 43.0, 64.0)
		if boss_center.y >= boss_visual_half and not _draw_phase6_boss_sprite(boss_center):
			var ix: int = int(boss_center.x); var iy: int = int(boss_center.y)
			var col: Color = Color.WHITE if boss.flash > 0 else Color(0.86,0.24,0.24)
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6): var a: float = TAU/6*i-PI/2+boss.rot*0.02; pts.append(Vector2(ix+cos(a)*boss.radius,iy+sin(a)*boss.radius))
			draw_colored_polygon(pts,col); draw_polyline(pts,Color.WHITE,2,true)
			draw_circle(Vector2(ix,iy),6,Color.WHITE); draw_circle(Vector2(ix,iy),4,Color.RED)

	# Bullets
	_ensure_active_bullet_indices()
	for bullet_index in active_bullet_indices:
		var b = bullet_pool[bullet_index]
		if not b.active: continue
		if float(b.y) < maxf(float(b.radius) * 2.3, 8.0): continue
		if _draw_phase6_bullet_sprite(b):
			continue
		if b.type == "player":
			draw_circle(Vector2(b.x,b.y), b.radius, _bullet_draw_color(b.color, 0.5))
			draw_circle(Vector2(b.x,b.y), b.radius * 0.5, _bullet_draw_color(Color.WHITE))
		elif b.type == "bomb":
			draw_circle(Vector2(b.x,b.y), b.radius, _bullet_draw_color(b.color, 0.5))
		else:
			draw_circle(Vector2(b.x,b.y), b.radius * 1.5, _bullet_draw_color(b.color, 0.15))
			draw_circle(Vector2(b.x,b.y), b.radius, _bullet_draw_color(b.color))
			draw_circle(Vector2(b.x,b.y), b.radius, Color.BLACK, false, 1)
			draw_circle(Vector2(b.x,b.y), b.radius * 0.4, _bullet_draw_color(Color.WHITE))

	# Boss
	if boss_alive and boss.has("phase") and boss.get("phase", "") != "defeated":
		# HP bar
		var r: float = boss.hp/max(1.0,boss.max_hp)
		var hp_bar: Rect2 = _boss_hp_bar_rect()
		draw_rect(hp_bar,Color.BLACK)
		draw_rect(Rect2(hp_bar.position.x, hp_bar.position.y, hp_bar.size.x * r, hp_bar.size.y),Color.RED if r>0.5 else Color.ORANGE)
		draw_rect(hp_bar,Color.WHITE,false,1)
		# Bottom-of-screen horizontal-position indicator: a red translucent
		# band that moves left/right with the boss so the player knows where
		# the boss is horizontally without having to look to the top.
		# Clamped within screen margins and centered on boss.x.
		var ind_rect := _boss_indicator_rect()
		draw_rect(ind_rect, Color(0.86, 0.16, 0.16, 0.35))
		draw_rect(ind_rect, Color(1.0, 0.4, 0.4, 0.7), false, 1)

	# Player
	if player_invincible and not player_bombing and int(player_invincible_timer*60)%10<5: pass
	else:
		var ix: int = int(player_x); var iy: int = int(player_y)
		if not _draw_phase6_player_sprite(Vector2(ix, iy)):
			draw_circle(Vector2(ix,iy-12),6,Color(1,0.86,0.75))
			draw_rect(Rect2(ix-6,iy-4,12,16),Color(0.78,0.12,0.16)); draw_rect(Rect2(ix-6,iy-4,12,16),Color.WHITE,false,1)
			draw_rect(Rect2(ix-7,iy-1,14,3),Color(0.31,0.08,0.31))
		if _should_show_focus_hitbox():
			draw_circle(Vector2(player_x,player_y),_player_hitbox_radius(),Color.WHITE,false,1)
			draw_circle(Vector2(player_x,player_y),_player_graze_radius(),Color(0.31,0.71,1,0.25),false,1)

	var gm_title = game_manager_ref
	# Game-over / all-clear summary screen - shows when state is game_over
	# or final_clear. Without this branch the game would render the empty
	# Stage background forever with no UI hint at all.
	if gm_title and gm_title.state in ["game_over", "final_clear"]:
		var sf = SystemFont.new()
		var banner: String = "\u7ec3\u4e60\u5b8c\u6210" if gm_title.state == "final_clear" and gm_title.practice_mode else ("\u5168\u5173\u901a\u8fc7" if gm_title.state == "final_clear" else "\u6e38\u620f\u7ed3\u675f")
		var bonus: int = gm_title.score + gm_title.graze * 10
		var box_rect := _summary_box_rect()
		var text_x := box_rect.position.x + 20.0
		_draw_phase6_ui_fullscreen("result_frame", 0.70)
		draw_rect(box_rect, Color(0.05, 0.05, 0.1, 0.8))
		draw_rect(box_rect, Color(0.86, 0.24, 0.24), false, 2)
		draw_string(sf, Vector2(_centered_text_x(sf, banner), box_rect.position.y + 50.0), banner)
		draw_string(sf, Vector2(text_x, box_rect.position.y + 100.0), "\u5f97\u5206: %d" % gm_title.score)
		draw_string(sf, Vector2(text_x, box_rect.position.y + 130.0), "\u64e6\u5f39: %d  (+%d)" % [gm_title.graze, gm_title.graze*10])
		draw_string(sf, Vector2(text_x, box_rect.position.y + 160.0), "\u5956\u52b1: %d" % bonus)
		var total_y := box_rect.position.y + 200.0
		if gm_title.state == "final_clear":
			total_y = box_rect.position.y + 190.0
			draw_string(sf, Vector2(text_x, total_y), "\u603b\u8ba1: %d" % bonus)
			total_y += 30
		if _should_show_input_guide():
			draw_string(sf, Vector2(text_x, total_y), "\u6309 Z \u8fd4\u56de\u6807\u9898")
		return


	var gm = game_manager_ref
	_draw_phase6_spell_banner(font)
	_draw_gameplay_hud(font, gm)
	_draw_boss_status(font)
	draw_string(font, Vector2(10, SCREEN_H - 15), "%s  |  夜祭印 %d" % [gm.STAGE_NAMES[gm.current_stage - 1], gm.night_festival_seals], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.88, 0.86, 0.72))
	_draw_gameplay_input_guide(font)
	_draw_performance_hud(font)
	if gm.state == gm.STATE_PAUSED:
		_draw_pause_overlay()
