extends Node2D

# Main game scene — all game logic in one script for simplicity

var bullet_pool: Array = []
var enemies: Array = []
var items: Array = []
var boss: Dictionary = {}
var boss_alive: bool = false
var stage_controller: Dictionary = {}
var stage_timer: float = 0.0
var player_x: float = 240.0
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
var MAX_BULLETS: int = 5000
var SCREEN_W: int = 480
var SCREEN_H: int = 640

func _ready():
	randomize()
	for i in range(MAX_BULLETS):
		bullet_pool.append(_make_bullet())
	# Ensure GameManager globals are initialized
	GameManager.reset()
	_show_title()

func _make_bullet() -> Dictionary:
	return {"active":false,"x":0.0,"y":0.0,"vx":0.0,"vy":0.0,"radius":6.0,"color":Color.RED,"type":"circle","lifetime":600.0,"age":0.0,"damage":1.0,"homing":false,"btype":-1}

func _show_title():
	GameManager.state = "title"
	if AudioManager: AudioManager.stop_bgm()

func _start_game():
	GameManager.reset()
	GameManager.state = "stage"
	GameManager.current_stage = 1
	stage_timer = 0.0
	_reset_player()
	_clear_bullets()
	enemies.clear(); items.clear()
	_load_stage(1)
	boss = {}; boss_alive = false
	if AudioManager: AudioManager.bgm_stage_mid(1)

func _reset_player():
	player_x = 240.0; player_y = 540.0
	player_invincible = false; player_invincible_timer = 0.0
	player_just_hit = false; player_bombing = false
	player_bomb_timer = 0.0; player_bomb_radius = 0.0; player_bomb_phase = 0
	player_fire_cooldown = 0.0
	player_deathbomb_primed = false; player_deathbomb_timer = 0.0

func _respawn():
	GameManager.lives -= 1
	GameManager.bombs = GameManager.PLAYER_INITIAL_BOMBS
	var dropped: int = int(GameManager.shared_power * GameManager.DEATH_POWER_DROP)
	for i in range(mini(50, dropped)):
		_spawn_item(player_x+randf_range(-80,80), player_y+randf_range(-60,60), ["bullet_spread","bullet_linear","bullet_homing"][i%3])
	GameManager.shared_power = max(0, GameManager.shared_power - dropped)
	_reset_player()
	player_invincible = true
	player_invincible_timer = GameManager.INVINCIBLE_DURATION / 60.0

func _advance_stage():
	GameManager.current_stage += 1
	stage_timer = 0.0
	_clear_bullets()
	items.clear(); enemies.clear()
	boss = {}; boss_alive = false
	_load_stage(GameManager.current_stage)
	GameManager.state = "stage"
	if AudioManager: AudioManager.bgm_stage_mid(GameManager.current_stage)

func _load_stage(stage: int):
	match stage:
		1: stage_controller = {"boss_time": 4500, "waves": {}}
		2: stage_controller = {"boss_time": 4800, "waves": {}}
		3: stage_controller = {"boss_time": 5400, "waves": {}}
	# Stage waves defined inline below
	stage_controller["boss_spawned"] = false

func _clear_bullets():
	for b in bullet_pool: b.active = false

func _spawn_bullet_player(x: float, y: float, vx: float, vy: float, radius: float = 5.0, color: Color = Color(0,0.7,1), damage: float = 1.0, homing: bool = false, btype: int = -1, persist: bool = false, lifetime: float = 100.0):
	for b in bullet_pool:
		if not b.active:
			b.active = true; b.x = x; b.y = y; b.vx = vx; b.vy = vy
			b.radius = radius; b.color = color
			# `persist=true` makes the bullet survive enemy/boss hits (it
			# pierces). Implemented via type="bomb" so the existing collision
			# branch `if b.type == "player": b.active=false` skips it.
			b.type = "bomb" if persist else "player"
			b.lifetime = lifetime; b.age = 0; b.damage = damage
			b.homing = homing; b.btype = btype
			return

func _spawn_bullet_enemy(x: float, y: float, vx: float, vy: float, radius: float = 6.0, color: Color = Color.RED, btype: String = "circle", lifetime: float = 350.0):
	for b in bullet_pool:
		if not b.active:
			b.active = true; b.x = x; b.y = y; b.vx = vx; b.vy = vy
			b.radius = max(5.0, radius); b.color = color; b.type = btype
			b.lifetime = lifetime; b.age = 0; b.damage = 1.0
			return

func _spawn_item(x: float, y: float, item_type: String = "power"):
	items.append({"alive":true,"collected":false,"x":x,"y":y,"type":item_type,"radius":9.0,"vy":-2.5,"vx":randf_range(-0.3,0.3),"floating":true,"target_y":128.0,"drift_dir":0.0,"sway":randf_range(0,TAU),"birth":15.0,"anim":randf_range(0,TAU)})

func _spawn_enemy(x: float, y: float, hp: float = 5.0, pattern: String = "aimed", move: String = "straight", vx: float = 0.0, vy: float = 1.5, move_data: Dictionary = {}, strong: bool = false):
	# All non-boss enemy HP is doubled from the wave-scripted values so that
	# every regular enemy takes 2x as long to clear. Strong flag remains
	# purely visual/loot-tier and is not affected.
	var ehp: float = hp * 2.0
	enemies.append({"alive":true,"x":x,"y":y,"hp":ehp,"max_hp":ehp,"radius":18.0 if strong else 14.0,"vx":vx,"vy":vy,"move_timer":0.0,"move":move,"move_data":move_data,"pattern":pattern,"shoot_timer":randf_range(0,30),"shoot_phase":0,"strong":strong,"dying":false,"death_timer":0.0})

func _nearest_enemy(px: float, py: float) -> Vector2:
	var best: float = 99999.0; var best_v: Vector2 = Vector2(px, py - 100)
	for e in enemies:
		if e.alive and not e.dying:
			var d: float = Vector2(px, py).distance_to(Vector2(e.x, e.y))
			if d < best: best = d; best_v = Vector2(e.x, e.y)
	return best_v

func _process(delta: float):
	delta = clampf(delta, 0.0, 0.05)
	var gm = get_node_or_null("/root/GameManager")
	var current_state: String = gm.state if gm else "title"
	match current_state:
		"title":
			if Input.is_action_just_pressed("shoot"): _start_game()
		"stage":
			_update_stage(delta)
		"boss":
			_update_boss(delta)
		"stage_clear":
			if Input.is_action_just_pressed("shoot"): _advance_stage()
		"final_clear", "game_over":
			if Input.is_action_just_pressed("shoot"): _show_title()
		"paused":
			if Input.is_action_just_pressed("pause"):
				if gm: gm.state = "stage"
	queue_redraw()

func _update_stage(delta: float):
	if Input.is_action_just_pressed("pause"): GameManager.state = "paused"; return
	stage_timer += delta * 60.0
	_stage_waves(int(stage_timer))
	if stage_timer >= stage_controller.boss_time and not stage_controller.boss_spawned:
		stage_controller.boss_spawned = true
	_update_player(delta)
	_update_bullets(delta, _nearest_enemy(player_x, player_y))
	_update_enemies(delta)
	_update_items(delta)
	_check_collisions(false)
	if player_just_hit:
		if GameManager.lives > 0: _respawn()
		else:
			GameManager.state = "game_over"
			if AudioManager: AudioManager.fade_bgm(-30.0, 0.8)
	if stage_controller.boss_spawned and _count_alive_enemies() == 0:
		_enter_boss()

func _update_boss(delta: float):
	if Input.is_action_just_pressed("pause"): GameManager.state = "paused"; return
	_update_player(delta)
	_update_bullets(delta, Vector2(boss.get("x",240), boss.get("y",130)) if boss_alive else Vector2.ZERO)
	_update_items(delta)
	if boss_alive: _update_boss_entity(delta)
	_check_collisions(true)
	if player_just_hit:
		if GameManager.lives > 0: _respawn()
		else:
			GameManager.state = "game_over"
			if AudioManager: AudioManager.fade_bgm(-30.0, 0.8)
	if not boss_alive:
		if GameManager.current_stage >= 3:
			GameManager.state = "final_clear"
			if AudioManager: AudioManager.fade_bgm(-30.0, 1.0)
		else:
			GameManager.state = "stage_clear"
			if AudioManager: AudioManager.fade_bgm(-12.0, 0.6)

func _enter_boss():
	GameManager.state = "boss"
	enemies.clear()
	for b in bullet_pool:
		if b.active and b.type in ["circle","rice","arrow","laser"]: b.active = false
	_init_boss()
	if AudioManager: AudioManager.bgm_stage_boss(GameManager.current_stage)

func _init_boss():
	boss = {"x":240.0,"y":-60.0,"hp":500.0,"max_hp":500.0,"radius":28.0,"phase":"entering","timer":0.0,"entered":false,"sway":randf_range(0,100),"declaring":false,"declare_timer":0.0,"card_name":"","cards":[],"card_idx":0,"card_hp":0.0,"card_timer":0.0,"card_shot":0.0,"flash":0.0,"rot":0.0,"anim":0.0,"alive":true}
	_load_boss_cards()
	boss_alive = true

func _load_boss_cards():
	match GameManager.current_stage:
		1: boss.cards = _stage1_cards()
		2: boss.cards = _stage2_cards()
		3: boss.cards = _stage3_cards()

func _stage1_cards() -> Array:
	return [
		{"name":"月光「Moonlight Ray」","hp":600,"time":28,"pattern":"moonlight"},
		{"name":"星符「Starfall」","hp":900,"time":32,"pattern":"starfall"},
		{"name":"蝶符「Phantom Butterfly」","hp":1300,"time":30,"pattern":"butterfly"},
		{"name":"神罰「Divine Punishment」","hp":1600,"time":25,"pattern":"divine"},
	]

func _stage2_cards() -> Array:
	return [
		{"name":"水符「Ripple Shield」","hp":900,"time":28,"pattern":"ripple"},
		{"name":"泡符「Bubble Burst」","hp":1300,"time":32,"pattern":"bubble"},
		{"name":"霧符「Mist Labyrinth」","hp":1800,"time":30,"pattern":"mist"},
		{"name":"湖符「Crystal Mirror」","hp":2400,"time":25,"pattern":"mirror"},
	]

func _stage3_cards() -> Array:
	return [
		{"name":"紅符「Scarlet Rain」","hp":1200,"time":28,"pattern":"scarlet"},
		{"name":"夜符「Midnight Blade」","hp":1700,"time":30,"pattern":"midnight"},
		{"name":"血符「Blood Vortex」","hp":2300,"time":32,"pattern":"vortex"},
		{"name":"闇符「Eternal Darkness」","hp":3000,"time":28,"pattern":"darkness"},
		{"name":"終符「Scarlet Apocalypse」","hp":4000,"time":25,"pattern":"apocalypse"},
	]

func _start_boss_card():
	var c: Dictionary = boss.cards[boss.card_idx]
	boss.card_name = c.name; boss.card_hp = c.hp; boss.max_hp = c.hp; boss.hp = c.hp
	boss.card_timer = c.time * 60.0; boss.card_shot = 0.0
	boss.declaring = true; boss.declare_timer = 90.0
	boss.phase = "active"

func _update_boss_entity(delta: float):
	# All boss timing constants are authored in FRAMES (e.g. declare_timer=90
	# for 1.5s, boss_enter span=120 frames for 2s, cardShot frequency uses
	# `int(card_shot) % 12`). Convert delta to frames once, then use it
	# everywhere below — keeping units consistent with the rest of the game.
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
		boss.target_x = 240.0 + sin(boss.sway * 0.025) * 70.0
		boss.target_y = 130.0 + cos(boss.sway * 0.035) * 18.0

	if boss.phase != "defeated":
		# Frame-rate-independent lerp toward target (per-frame factor ~0.08).
		var f: float = clampf(0.08 * dt, 0.0, 1.0)
		boss.x = lerpf(boss.x, boss.get("target_x", 240.0), f)
		boss.y = lerpf(boss.y, boss.get("target_y", 130.0), f)

	if boss.entered and boss.cards.size() > 0 and boss.card_idx == 0 and boss.card_hp == 0 and boss.phase == "active":
		_start_boss_card()

func _boss_enter(delta: float):
	boss.timer += delta * 60.0
	var p: float = clampf(boss.timer / 120.0, 0.0, 1.0)
	boss.y = -60.0 + (190.0) * (1.0 - (1.0-p)*(1.0-p))
	if p >= 1.0:
		boss.phase = "active"; boss.entered = true

func _boss_active(delta: float):
	if boss.declaring: return
	var dt: float = delta * 60.0
	boss.card_timer -= dt
	if boss.card_timer <= 0: _boss_card_timeout()
	boss.card_shot += dt
	if boss.card_idx < boss.cards.size():
		_boss_fire_pattern(delta)
	if boss.hp <= 0: _boss_card_clear()

func _boss_switching(delta: float):
	boss.timer += delta * 60.0
	if boss.timer > 40:
		boss.card_idx += 1; boss.timer = 0.0
		# Defensive: only start next card if it exists. The card-clear logic
		# routes "last card" straight to "defeated", so this should normally
		# never trigger — but a stray future caller shouldn't blow up.
		if boss.card_idx < boss.cards.size():
			_start_boss_card()
		else:
			boss.phase = "defeated"; boss.timer = 0.0

func _boss_defeated(delta: float):
	boss.timer += delta * 60.0
	boss.x += randf_range(-2.0, 2.0) * delta * 60.0
	boss.y += 0.5 * delta * 60.0
	if boss.timer > 180: boss_alive = false

func _boss_card_clear():
	for b in bullet_pool:
		if b.active and b.type in ["circle","rice","arrow","laser"]: b.active = false
	# If the just-cleared card was the LAST card, the boss is dead — go to
	# the defeat animation instead of "switching" so we never try to start
	# a non-existent next card (which was an out-of-range index bug).
	if boss.card_idx >= boss.cards.size() - 1:
		boss.phase = "defeated"
		boss.timer = 0.0
	else:
		boss.phase = "switching"; boss.timer = 0.0
	if AudioManager: AudioManager.play_sfx("kill", -5.0)

func _boss_card_timeout():
	for b in bullet_pool:
		if b.active and b.type in ["circle","rice","arrow","laser"]: b.active = false
	# Same as above — timeout on the last card also ends the fight.
	if boss.card_idx >= boss.cards.size() - 1:
		boss.phase = "defeated"
		boss.timer = 0.0
	else:
		boss.phase = "switching"; boss.timer = 0.0
	if AudioManager: AudioManager.play_sfx("kill", -7.0)

func _boss_fire_pattern(delta: float):
	var c: Dictionary = boss.cards[boss.card_idx]
	var mult: float = GameManager.STAGE_MULTS[GameManager.current_stage - 1].bullet_speed
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
		for i in range(10): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.03+TAU/10*i)*(1.5+i*0.2)*mult,sin(boss.card_shot*0.03+TAU/10*i)*(1.5+i*0.2)*mult,4,Color(0.16,0.39,1),"circle",480)
	if int(boss.card_shot) % 22 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.4,-0.2,0,0.2,0.4]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*3.2*mult,sin(a+off)*3.2*mult,5,Color.YELLOW,"arrow")

func _bullets_mist(mult: float):
	if int(boss.card_shot) % 4 == 0:
		for arm in range(3):
			for i in range(7):
				var a: float = TAU/3*arm+boss.card_shot*0.025+i*0.25
				_spawn_bullet_enemy(boss.x,boss.y,cos(a)*2.0*mult,sin(a)*2.0*mult,3,Color(0.71,0.16,0.86) if arm==0 else (Color(0.16,0.39,1) if arm==1 else Color(0.16,0.86,0.94)))

func _bullets_mirror(mult: float):
	if int(boss.card_shot) % 20 == 0:
		for ab in [0.0,PI/2,PI/4,-PI/4]:
			for d in [-1,1]: _spawn_bullet_enemy(boss.x,boss.y,cos(ab+d*0.3)*4.0*mult,sin(ab+d*0.3)*4.0*mult,6,Color.RED,"laser")
	if int(boss.card_shot) % 8 == 0:
		for i in range(24): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/24*i+boss.card_shot*0.02)*2.2*mult,sin(TAU/24*i+boss.card_shot*0.02)*2.2*mult,3,Color(0.16,0.39,1))

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
		if int(boss.card_shot) % 4 == 0:
			for i in range(10): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.035*arm+TAU/10*i)*(2.0+i*0.25)*mult,sin(boss.card_shot*0.035*arm+TAU/10*i)*(2.0+i*0.25)*mult,3,Color.RED if arm==1 else Color(0.71,0.2,0.24))
	if int(boss.card_shot) % 18 == 0:
		for i in range(28): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/28*i+boss.card_shot*0.02)*3.0*mult,sin(TAU/28*i+boss.card_shot*0.02)*3.0*mult,2,Color(1,0.24,0.24))

func _bullets_darkness(mult: float):
	if int(boss.card_shot) % 5 == 0:
		for i in range(24): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/24*i+boss.card_shot*0.018)*2.2*mult,sin(TAU/24*i+boss.card_shot*0.018)*2.2*mult,2,Color(0.71,0.16,0.86))
	if int(boss.card_shot) % 25 == 0:
		for i in range(4): _spawn_bullet_enemy(boss.x,boss.y,cos(boss.card_shot*0.04+TAU/4*i)*5.0*mult,sin(boss.card_shot*0.04+TAU/4*i)*5.0*mult,7,Color(1,0.24,0.24),"laser")

func _bullets_apocalypse(mult: float):
	if int(boss.card_shot) % 4 == 0:
		for i in range(30): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/30*i+boss.card_shot*0.02)*2.0*mult,sin(TAU/30*i+boss.card_shot*0.02)*2.0*mult,2,Color(1,0.24,0.24))
	if int(boss.card_shot) % 5 == 0:
		for i in range(24): _spawn_bullet_enemy(boss.x,boss.y,cos(TAU/24*i-boss.card_shot*0.025)*2.5*mult,sin(TAU/24*i-boss.card_shot*0.025)*2.5*mult,2,Color.ORANGE)
	if int(boss.card_shot) % 20 == 0:
		var a: float = (Vector2(player_x,player_y)-Vector2(boss.x,boss.y)).angle()
		for off in [-0.5,-0.25,0,0.25,0.5]: _spawn_bullet_enemy(boss.x,boss.y,cos(a+off)*4.5*mult,sin(a+off)*4.5*mult,6,Color(0.71,0.2,0.24),"laser")
	if int(boss.card_shot) % (2 if boss.card_timer < 600 else 4) == 0:
		var a: float = randf_range(0,TAU); _spawn_bullet_enemy(boss.x,boss.y,cos(a)*randf_range(3,6)*mult,sin(a)*randf_range(3,6)*mult,3,Color.WHITE)

# Stage wave spawning
func _stage_waves(timer: int):
	match GameManager.current_stage:
		1: _waves_s1(timer)
		2: _waves_s2(timer)
		3: _waves_s3(timer)

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
		if Input.is_action_just_pressed("bomb") and GameManager.bombs > 0: _start_bomb(); player_deathbomb_primed = false; player_just_hit = false; return
		if player_deathbomb_timer <= 0: player_deathbomb_primed = false; return

	if player_invincible and not player_bombing:
		player_invincible_timer -= delta
		if player_invincible_timer <= 0: player_invincible = false

	if player_bombing: _update_bomb(delta)

	var focus: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = GameManager.PLAYER_SPEED_LOW if focus else GameManager.PLAYER_SPEED_HIGH
	var dx: float = Input.get_axis("move_left", "move_right")
	var dy: float = Input.get_axis("move_up", "move_down")
	if dx != 0 and dy != 0: dx *= 0.7071; dy *= 0.7071
	player_x += dx * speed * delta * 60.0
	player_y += dy * speed * delta * 60.0
	player_x = clampf(player_x, 16.0, 464.0)
	player_y = clampf(player_y, 16.0, 624.0)

	player_fire_cooldown -= delta
	if Input.is_action_pressed("shoot") and player_fire_cooldown <= 0:
		player_fire_cooldown = GameManager.PLAYER_FIRE_INTERVAL / 60.0
		_shoot()

	if Input.is_action_just_pressed("bomb") and GameManager.bombs > 0 and not player_deathbomb_primed and not player_bombing:
		_start_bomb()

func _shoot():
	var level: int = GameManager.power_level()
	var bt: int = GameManager.bullet_type
	var dmg_val: float = GameManager.BULLET_DMG[bt]
	match bt:
		GameManager.BulletType.SPREAD: _shoot_spread(level, dmg_val)
		GameManager.BulletType.LINEAR: _shoot_linear(level, dmg_val)
		GameManager.BulletType.HOMING: _shoot_homing(level, dmg_val)
	# Throttle shoot SFX so 20 Hz fire doesn't sound like a machine-gun
	_sfx_shoot_skip = (_sfx_shoot_skip + 1) % 2
	if _sfx_shoot_skip == 0 and AudioManager:
		AudioManager.play_sfx("shoot", -12.0)

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
	if GameManager.bombs <= 0: return
	GameManager.bombs -= 1
	player_bomb_config = GameManager.BOMB_CONFIG[GameManager.bullet_type]
	player_bombing = true; player_bomb_timer = player_bomb_config.duration / 60.0
	player_bomb_phase = 0; player_bomb_wave_timer = 0.0; player_bomb_radius = 0.0
	player_invincible = true; player_invincible_timer = player_bomb_config.duration / 60.0
	if AudioManager: AudioManager.play_sfx("bomb", -4.0)

func _update_bomb(delta: float):
	player_bomb_timer -= delta; player_bomb_wave_timer -= delta
	var bc: Dictionary = player_bomb_config
	player_bomb_radius += bc.radius / bc.duration * 2.0 * delta * 60.0
	if player_bomb_radius > bc.radius: player_bomb_radius = bc.radius
	var wave_int: float = bc.duration / bc.waves / 60.0
	if player_bomb_wave_timer <= 0 and player_bomb_phase < bc.waves:
		player_bomb_wave_timer = wave_int
		# Three visually distinct bomb shapes, chosen by the weapon the player
		# is currently holding. Previously all three branches produced the
		# same omni-directional round-bullet ring, making them look identical
		# in the air.
		match GameManager.bullet_type:
			GameManager.BulletType.SPREAD:
				# Big omni-direction flash ring of circles. Many bullets, slow,
				# all directions. Pierces so all waves actually pass through
				# packed enemy clusters instead of dying on the first hit.
				var n: int = bc.bullets
				var spd: float = bc.speed
				for i in range(n):
					var a: float = TAU/n*i + player_bomb_phase * 0.3
					_spawn_bullet_player(player_x, player_y,
						cos(a)*spd, sin(a)*spd,
						7, Color(0.78,0.39,1.0,1.0), 3.0, false, -1, true, 80.0)
			GameManager.BulletType.LINEAR:
				# Piercing spokes: a small number of long fast rods that pass
				# straight through enemies (they don't despawn on hit). Double
				# spokes each wave so the pattern slowly rotates.
				var spokes: int = 8
				var spd: float = bc.speed * 1.6
				for i in range(spokes):
					var a: float = TAU/spokes*i + player_bomb_phase * (PI / 4)
					_spawn_bullet_player(player_x, player_y,
						cos(a)*spd, sin(a)*spd,
						12, Color(1.0, 0.31, 0.31), bc.dmg, false, 1, true, 120.0)
			GameManager.BulletType.HOMING:
				# A swarm of slow homing seekers out in a spiral. They seek the
				# nearest enemy and nibble through HP. Distinct, lingering.
				var n: int = bc.bullets
				var spd: float = bc.speed
				for i in range(n):
					var a: float = TAU/n*i + player_bomb_phase * 0.6
					_spawn_bullet_player(player_x, player_y,
						cos(a)*spd, sin(a)*spd,
						4, Color(0.31, 1.0, 0.55), bc.dmg, true, 2, true, 90.0)
		player_bomb_phase += 1
	for b in bullet_pool:
		if b.active and b.type in ["circle","rice","arrow","laser"]:
			if Vector2(b.x,b.y).distance_to(Vector2(player_x,player_y)) < player_bomb_radius: b.active = false
	if player_bomb_timer <= 0:
		# End bomb state but DO NOT clear player_invincible here.
		# _start_bomb() set the invincibility timer to the bomb's duration;
		# the timer is held frozen while `player_bombing` was true (see
		# _update_player). After the bomb visual ends, that invincibility
		# window starts ticking normally, giving the player a brief grace
		# period during and after the bomb release.
		player_bombing = false

func _update_bullets(delta: float, target: Vector2):
	for b in bullet_pool:
		if not b.active: continue
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
			const TURN_RATE: float = 0.03       # rad / frame ~ 1.7°/frame
			const MAX_DEFLECT: float = PI/3.0   # 60° cone around straight-up
			var origin: Vector2 = Vector2(b.x, b.y)
			var best_d2: float = MAX_REACH * MAX_REACH + 1.0
			var tg: Vector2 = Vector2.ZERO
			for e in enemies:
				if not e.alive or e.dying: continue
				if e.y > b.y + REACH_AHEAD: continue  # only chase enemies above us
				var rel: Vector2 = Vector2(e.x - b.x, e.y - b.y)
				var d2: float = rel.length_squared()
				if d2 < best_d2:
					best_d2 = d2; tg = Vector2(e.x, e.y)
			if boss_alive and boss.get("phase","active") not in ["entering","switching","defeated"] and not boss.get("declaring", false):
				if boss.y < b.y + REACH_AHEAD:
					var brel: Vector2 = Vector2(boss.x - b.x, boss.y - b.y)
					var bd2: float = brel.length_squared()
					if bd2 < best_d2:
						best_d2 = bd2; tg = Vector2(boss.x, boss.y)
			var spd: float = sqrt(b.vx*b.vx + b.vy*b.vy)
			if tg != Vector2.ZERO and spd > 0.0:
				var cur: float = Vector2(b.vx, b.vy).angle()
				var goal: float = (tg - origin).angle()
				var diff: float = fposmod(goal - cur + PI, TAU) - PI
				var turn: float = clampf(diff, -TURN_RATE, TURN_RATE)
				var na: float = cur + turn
				# Lock heading to forward cone around -PI/2 (straight up).
				# -PI/2 is up in screen coords. Clamp na into [-PI/2 - MAX_DEFLECT,
				# -PI/2 + MAX_DEFLECT].
				na = clampf(na, -PI/2 - MAX_DEFLECT, -PI/2 + MAX_DEFLECT)
				b.vx = cos(na) * spd
				b.vy = sin(na) * spd
		b.x += b.vx * delta * 60.0; b.y += b.vy * delta * 60.0
		b.age += delta * 60.0
		if b.age > b.lifetime or b.x < -60 or b.x > 540 or b.y < -60 or b.y > 700: b.active = false

func _update_enemies(delta: float):
	for e in enemies:
		if not e.alive: continue
		if e.dying: e.death_timer -= delta; if e.death_timer <= 0: e.alive = false; continue
		e.move_timer += delta * 60.0
		if e.move_timer > 1200: e.alive = false; continue
		match e.move:
			"straight": e.x += e.vx * delta * 60.0; e.y += e.vy * delta * 60.0
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
		e.x = clampf(e.x, 24, 456)
		if e.y > 680: e.alive = false

		# Dead/dying enemies must never emit any bullets — the dying branch
		# above already `continue`s, and we re-check here defensively so any
		# future code path that puts a dying enemy back into the loop stays
		# consistent with that invariant.
		if e.dying:
			continue
		# Only fire once the enemy has entered the visible play area.
		# `shoot_timer` is frozen while the enemy is fully off-screen,
		# so bullets never appear "from nowhere" at the screen edge.
		var on_screen: bool = e.y >= -2.0 and e.y <= 640.0 and e.x >= -2.0 and e.x <= 482.0
		if on_screen:
			e.shoot_timer -= delta * 60.0
		if on_screen and not e.dying and e.shoot_timer <= 0:
			e.shoot_timer = 60.0 * (0.7 if e.strong else 1.0); e.shoot_phase += 1
			var mult: float = GameManager.STAGE_MULTS[GameManager.current_stage - 1].bullet_speed
			match e.pattern:
				"aimed":
					var a: float = (Vector2(player_x,player_y)-Vector2(e.x,e.y)).angle()
					_spawn_bullet_enemy(e.x,e.y,cos(a)*2.5*mult,sin(a)*2.5*mult,5,Color.PURPLE)
				"spread":
					var a: float = (Vector2(player_x,player_y)-Vector2(e.x,e.y)).angle()
					for off in [-0.3,0,0.3]: _spawn_bullet_enemy(e.x,e.y,cos(a+off)*2.5*mult,sin(a+off)*2.5*mult,4,Color.ORANGE)
				"ring":
					for i in range(12): _spawn_bullet_enemy(e.x,e.y,cos(TAU/12*i+e.shoot_phase*0.3)*2.0*mult,sin(TAU/12*i+e.shoot_phase*0.3)*2.0*mult,4,Color.GREEN)
				"double_spread":
					var a: float = (Vector2(player_x,player_y)-Vector2(e.x,e.y)).angle()
					for off in [-0.5,-0.25,0,0.25,0.5]: _spawn_bullet_enemy(e.x,e.y,cos(a+off)*2.2*mult,sin(a+off)*2.2*mult,4,Color.ORANGE)
				"downward": _spawn_bullet_enemy(e.x,e.y,0,3.5*mult,5,Color.RED)
				"wave":
					for i in range(5): _spawn_bullet_enemy(e.x+i*10-20,e.y,cos(PI/2+sin(e.shoot_phase*0.15+i*0.6)*0.8)*2.0*mult,sin(PI/2+sin(e.shoot_phase*0.15+i*0.6)*0.8)*2.0*mult,4,Color.CYAN,"rice")
				"spiral":
					for i in range(8): _spawn_bullet_enemy(e.x,e.y,cos(e.shoot_phase*0.12+TAU/8*i)*2.5*mult,sin(e.shoot_phase*0.12+TAU/8*i)*2.5*mult,4,Color.MAGENTA)

func _update_items(delta: float):
	for it in items:
		if it.collected: continue
		it.anim += 0.06 * delta * 60.0
		if it.birth > 0: it.birth -= delta * 60.0

		# Phase 1 — float straight up to the top 1/5 of the screen (target_y).
		# This is reached both at spawn from enemy drops (y around e.y) and at
		# the player's death pickups (y around player_y). Items keep a small
		# sway for visual flavour while rising.
		if it.floating:
			if it.y <= it.target_y:
				it.floating = false
				# Initialize horizontal drift direction (random, +1 or -1).
				if it.get("drift_dir", 0.0) == 0.0:
					it["drift_dir"] = 1.0 if randf() < 0.5 else -1.0
				it.vy = 0.4   # slow fall after reaching top
				it.vx = it["drift_dir"] * 0.7
			else:
				it.y += it.vy * delta * 60.0
				it.x += sin(it.anim*0.06*2+it.sway)*0.5*delta*60.0
				it.x = clampf(it.x,11,469)
			continue

		# Phase 2 — drifting at the top. A permanent "magnetized" flag turns
		# on the first time the player holds Shift in the upper area (y<128)
		# while this item is in mid-flight. Once magnetized, the item flies
		# toward the player EVERY subsequent frame regardless of whether
		# Shift is still held or where the player is — exactly so the player
		# can tap Shift once at the top and then dive back down to dodge
		# while the items continue to be vacuumed up.
		# `magnetized` is missing on legacy items (init → false).
		if it.get("magnetized", false) == false:
			if Input.is_key_pressed(KEY_SHIFT) and player_y < 128.0:
				it["magnetized"] = true
		if it.get("magnetized", false):
			var a: float = (Vector2(player_x,player_y)-Vector2(it.x,it.y)).angle()
			it.vx = cos(a)*20.0; it.vy = sin(a)*20.0
		else:
			# Slow horizontal drift with wall bounce.
			var dir: float = it.get("drift_dir", 1.0)
			var drift_speed: float = 0.7
			if it.x <= 11.0:
				dir = 1.0
			elif it.x >= 469.0:
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
		it.x = clampf(it.x,11,469)
		if it.y > 670: it.alive = false

func _count_alive_enemies() -> int:
	var c: int = 0
	for e in enemies: if e.alive and not e.dying: c += 1
	return c

func _check_collisions(is_boss: bool):
	for b in bullet_pool:
		if not b.active: continue
		if b.type == "player" or b.type == "bomb":
			if is_boss and boss_alive:
				if boss.declaring or boss.phase in ["entering","switching","defeated"]: continue
				if Vector2(b.x,b.y).distance_to(Vector2(boss.x,boss.y)) < b.radius + boss.radius*0.7:
					boss.hp -= b.damage
					if b.type == "player": b.active = false
			else:
				for e in enemies:
					if not e.alive or e.dying: continue
					if Vector2(b.x,b.y).distance_to(Vector2(e.x,e.y)) < b.radius + e.radius:
						e.hp -= b.damage
						if b.type == "player": b.active = false
						if e.hp <= 0 and not e.dying:
							e.dying = true; e.death_timer = 8.0
							_drop_item(e.x,e.y,e.strong)
							GameManager.score += 50
							if AudioManager: AudioManager.play_sfx("kill", -6.0 if e.strong else -8.0)
						break
		elif b.type in ["circle","rice","arrow","laser"]:
			if not player_invincible and Vector2(b.x,b.y).distance_to(Vector2(player_x,player_y)) < b.radius + GameManager.PLAYER_HITBOX:
				player_deathbomb_primed = true; player_deathbomb_timer = GameManager.DEATHBOMB_WINDOW/60.0
				player_just_hit = true; b.active = false
				if AudioManager: AudioManager.play_sfx("hit", -2.0)

	# Graze
	for b in bullet_pool:
		if b.active and b.type in ["circle","rice","arrow","laser"]:
			if Vector2(b.x,b.y).distance_to(Vector2(player_x,player_y)) < GameManager.PLAYER_GRAZE + b.radius:
				GameManager.graze += 1; GameManager.score += 10

	# Item collection
	for it in items:
		if it.collected or not it.alive: continue
		if Vector2(it.x,it.y).distance_to(Vector2(player_x,player_y)) < it.radius + 24.0:
			_collect(it)

func _drop_item(x: float, y: float, strong: bool):
	if strong: items.append({"alive":true,"collected":false,"x":x,"y":y,"type":"bomb_refill","radius":9.0,"vy":-2.5,"vx":randf_range(-0.3,0.3),"floating":true,"target_y":128.0,"drift_dir":0.0,"sway":randf_range(0,TAU),"birth":15.0,"anim":randf_range(0,TAU)})
	else:
		var r: float = randf()
		var t: String = "power"
		if r < 0.40: t = "power"
		elif r < 0.58: t = "point"
		elif r < 0.68: t = "bomb_refill"
		elif r < 0.72: t = "life"
		else: t = ["bullet_spread","bullet_linear","bullet_homing"][randi()%3]
		items.append({"alive":true,"collected":false,"x":x,"y":y,"type":t,"radius":9.0,"vy":-2.5,"vx":randf_range(-0.3,0.3),"floating":true,"target_y":128.0,"drift_dir":0.0,"sway":randf_range(0,TAU),"birth":15.0,"anim":randf_range(0,TAU)})

func _collect(it: Dictionary):
	it.collected = true; it.alive = false
	match it.type:
		"bullet_spread", "bullet_linear", "bullet_homing":
			var bt: int = 0
			if it.type == "bullet_linear": bt = 1
			elif it.type == "bullet_homing": bt = 2
			GameManager.switch_bullet_type(bt)
			if GameManager.add_power(): pass
			GameManager.score += 10
		"power":
			if GameManager.add_power(): pass
			GameManager.score += 10
		"point":
			GameManager.score += 10 * (1 + GameManager.shared_power)
		"bomb_refill":
			GameManager.bombs = min(GameManager.bombs+1, 5); GameManager.score += 100
		"life":
			GameManager.lives = min(GameManager.lives+1, 6); GameManager.score += 500

func _draw():
	if not is_inside_tree(): return
	# Items
	for it in items:
		if not it.alive or it.birth > 0: continue
		var ix: int = int(it.x); var iy: int = int(it.y)
		match it.type:
			"power": draw_circle(Vector2(ix,iy),9,Color.RED); draw_circle(Vector2(ix,iy),9,Color.WHITE,false,2)
			"point":
				var pts: PackedVector2Array = PackedVector2Array([Vector2(ix,iy-9),Vector2(ix+9,iy),Vector2(ix,iy+9),Vector2(ix-9,iy)])
				draw_colored_polygon(pts,Color.BLUE); draw_polyline(pts,Color.WHITE,1,true)
			"bomb_refill":
				var pts2: PackedVector2Array = PackedVector2Array()
				for i in range(6): var a: float = TAU/6*i-PI/2; pts2.append(Vector2(ix+cos(a)*(9 if i%2==0 else 4.5),iy+sin(a)*(9 if i%2==0 else 4.5)))
				draw_colored_polygon(pts2,Color.ORANGE)
			"life": draw_rect(Rect2(ix-9,iy-9,18,18),Color.PINK); draw_rect(Rect2(ix-9,iy-9,18,18),Color.WHITE,false,2)
			_:
				var bt: int = 0
				if it.type == "bullet_linear": bt = 1
				elif it.type == "bullet_homing": bt = 2
				var hex: PackedVector2Array = PackedVector2Array()
				for i in range(6): hex.append(Vector2(ix+cos(TAU/6*i-PI/6)*10,iy+sin(TAU/6*i-PI/6)*10))
				draw_colored_polygon(hex,GameManager.BULLET_COLORS[bt]); draw_polyline(hex,Color.WHITE,2,true)

	# Enemies
	for e in enemies:
		if not e.alive or e.dying: continue
		var ix: int = int(e.x); var iy: int = int(e.y)
		var col: Color = Color.GOLD if e.strong else Color(0.47,0.16,0.71)
		draw_circle(Vector2(ix,iy),e.radius,col); draw_circle(Vector2(ix,iy),e.radius,Color.WHITE,false,1)
		draw_line(Vector2(ix-e.radius,iy+2),Vector2(ix-e.radius-8,iy-8+sin(e.move_timer*0.1)*3),Color(0.71,0.31,0.94),2)
		draw_line(Vector2(ix+e.radius,iy+2),Vector2(ix+e.radius+8,iy-8+sin(e.move_timer*0.1)*3),Color(0.71,0.31,0.94),2)
		draw_circle(Vector2(ix-3,iy-2),2,Color.WHITE); draw_circle(Vector2(ix+3,iy-2),2,Color.WHITE)
		if e.strong:
			var cr: PackedVector2Array = PackedVector2Array([Vector2(ix,iy-e.radius-8),Vector2(ix-5,iy-e.radius-1),Vector2(ix+5,iy-e.radius-1)])
			draw_colored_polygon(cr,Color.GOLD)

	# Bullets
	for b in bullet_pool:
		if not b.active: continue
		if b.type == "player": draw_circle(Vector2(b.x,b.y),b.radius,Color(b.color.r,b.color.g,b.color.b,0.5)); draw_circle(Vector2(b.x,b.y),b.radius*0.5,Color.WHITE)
		elif b.type == "bomb": draw_circle(Vector2(b.x,b.y),b.radius,Color(b.color.r,b.color.g,b.color.b,0.5))
		else: draw_circle(Vector2(b.x,b.y),b.radius*1.5,Color(b.color.r,b.color.g,b.color.b,0.15)); draw_circle(Vector2(b.x,b.y),b.radius,b.color); draw_circle(Vector2(b.x,b.y),b.radius,Color.BLACK,false,1); draw_circle(Vector2(b.x,b.y),b.radius*0.4,Color.WHITE)

	# Boss
	if boss_alive and boss.phase != "defeated":
		var ix: int = int(boss.x); var iy: int = int(boss.y)
		var col: Color = Color.WHITE if boss.flash > 0 else Color(0.86,0.24,0.24)
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(6): var a: float = TAU/6*i-PI/2+boss.rot*0.02; pts.append(Vector2(ix+cos(a)*boss.radius,iy+sin(a)*boss.radius))
		draw_colored_polygon(pts,col); draw_polyline(pts,Color.WHITE,2,true)
		draw_circle(Vector2(ix,iy),6,Color.WHITE); draw_circle(Vector2(ix,iy),4,Color.RED)
		# HP bar
		var r: float = boss.hp/max(1.0,boss.max_hp)
		draw_rect(Rect2(140,28,200,14),Color.BLACK)
		draw_rect(Rect2(140,28,200*r,14),Color.RED if r>0.5 else Color.ORANGE)
		draw_rect(Rect2(140,28,200,14),Color.WHITE,false,1)
		# Bottom-of-screen horizontal-position indicator: a red translucent
		# band that moves left/right with the boss so the player knows where
		# the boss is horizontally without having to look to the top.
		# Clamped inside the playfield (x: 16..464), centered on boss.x.
		var indicator_x: float = clampf(boss.x, 36.0, 444.0)
		var indicator_w: float = 40.0
		var indicator_h: float = 24.0
		var indicator_y: float = 610.0
		var ind_rect := Rect2(indicator_x - indicator_w/2.0, indicator_y, indicator_w, indicator_h)
		draw_rect(ind_rect, Color(0.86, 0.16, 0.16, 0.35))
		draw_rect(ind_rect, Color(1.0, 0.4, 0.4, 0.7), false, 1)

	# Player
	if player_invincible and not player_bombing and int(player_invincible_timer*60)%10<5: pass
	else:
		var ix: int = int(player_x); var iy: int = int(player_y)
		if Input.is_key_pressed(KEY_SHIFT) and not player_bombing:
			draw_circle(Vector2(player_x,player_y),GameManager.PLAYER_HITBOX,Color.WHITE,false,1)
			draw_circle(Vector2(player_x,player_y),GameManager.PLAYER_GRAZE,Color(0.31,0.71,1,0.25),false,1)
		if player_bombing:
			draw_circle(Vector2(player_x,player_y),player_bomb_radius,Color(player_bomb_config.color.r,player_bomb_config.color.g,player_bomb_config.color.b,0.3),false,3)
		draw_circle(Vector2(ix,iy-12),6,Color(1,0.86,0.75))
		draw_rect(Rect2(ix-6,iy-4,12,16),Color(0.78,0.12,0.16)); draw_rect(Rect2(ix-6,iy-4,12,16),Color.WHITE,false,1)
		draw_rect(Rect2(ix-7,iy-1,14,3),Color(0.31,0.08,0.31))

	# Title screen
	var gm_title = get_node_or_null("/root/GameManager")
	if gm_title and gm_title.state == "title":
		draw_circle(Vector2(240, 320), 60, Color(0.2, 0.2, 0.4, 0.5))
		draw_string(SystemFont.new(), Vector2(140, 240), "Eastern Barrage")
		draw_string(SystemFont.new(), Vector2(110, 270), "~ Touhou-style Danmaku ~")
		draw_string(SystemFont.new(), Vector2(140, 380), "Press Z to Start")
		draw_string(SystemFont.new(), Vector2(60, 500), "Arrow Keys - Move | Z - Shoot | X - Bomb")
		draw_string(SystemFont.new(), Vector2(90, 520), "Shift - Focus | Esc - Pause")
		return
	# Game-over / all-clear summary screen — shows when state is game_over
	# or final_clear. Without this branch the game would render the empty
	# Stage background forever with no UI hint at all.
	if gm_title and gm_title.state in ["game_over", "final_clear"]:
		var sf = SystemFont.new()
		var banner: String = "All Stages Cleared!" if gm_title.state == "final_clear" else "Game Over"
		var bonus: int = gm_title.score + gm_title.graze * 10
		var box_rect := Rect2(120, 180, 240, 220)
		draw_rect(box_rect, Color(0.05, 0.05, 0.1, 0.8))
		draw_rect(box_rect, Color(0.86, 0.24, 0.24), false, 2)
		draw_string(sf, Vector2(120, 230), banner)
		draw_string(sf, Vector2(140, 280), "Score: %d" % gm_title.score)
		draw_string(sf, Vector2(140, 310), "Graze: %d  (+%d)" % [gm_title.graze, gm_title.graze*10])
		draw_string(sf, Vector2(140, 340), "Bonus: %d" % bonus)
		var total_y := 380
		if gm_title.state == "final_clear":
			total_y = 370
			draw_string(sf, Vector2(140, total_y), "TOTAL: %d" % bonus)
			total_y += 30
		draw_string(sf, Vector2(140, total_y), "Press Z to return")
		return


	var gm = GameManager
	var font = SystemFont.new()
	draw_string(font,Vector2(10,20),"Score: %d"%gm.score)
	draw_string(font,Vector2(10,35),"Graze: %d"%gm.graze)
	draw_string(font,Vector2(10,50),"Shot: %s Lv.%d"%[gm.BULLET_NAMES[gm.bullet_type],gm.power_level()])
	# Right-aligned life/bomb indicators: heart/diamond count can grow up to
	# 6/5, so we anchor the trailing edge 12px inside the right screen edge
	# and let the string extend to the left as lives/bombs increase — never
	# off the right side.
	var life_str = "Life: "+"♥".repeat(gm.lives)
	var bomb_str = "Bomb: "+"◆".repeat(gm.bombs)
	var life_w = font.get_string_size(life_str).x
	var bomb_w = font.get_string_size(bomb_str).x
	draw_string(font, Vector2(468 - life_w, 20), life_str)
	draw_string(font, Vector2(468 - bomb_w, 35), bomb_str)
	draw_string(font,Vector2(10,625),gm.STAGE_NAMES[gm.current_stage-1])
