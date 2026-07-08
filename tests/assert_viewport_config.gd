extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	if width != 720:
		_fail("Expected viewport_width 720, got %d" % width)
	if height != 960:
		_fail("Expected viewport_height 960, got %d" % height)

	var gm_script = load("res://autoload/game_manager.gd")
	if gm_script == null:
		_fail("Could not load GameManager script")
	var gm = gm_script.new()
	if gm.SCREEN_W != 720:
		_fail("Expected GameManager.SCREEN_W 720, got %d" % gm.SCREEN_W)
	if gm.SCREEN_H != 960:
		_fail("Expected GameManager.SCREEN_H 960, got %d" % gm.SCREEN_H)
	var rect: Rect2 = gm.playfield_rect()
	if rect.position != Vector2.ZERO:
		_fail("Expected playfield origin Vector2.ZERO, got %s" % [rect.position])
	if rect.size != Vector2(720, 960):
		_fail("Expected playfield size 720x960, got %s" % [rect.size])
	if gm.stage_count() != 6:
		_fail("Expected six configured stage names, got %d" % gm.stage_count())
	quit(0)
