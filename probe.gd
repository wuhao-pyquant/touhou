extends SceneTree

var GM = null

func _init():
    var sce = load("res://scenes/main.tscn").instantiate()
    root.add_child(sce)
    GM = root.get_node("/root/GameManager")
    print("--- PROBE START ---")
    for i in range(60):
        sce._process(1.0/60.0)
    print("state=", GM.state, " player_y=", sce.player_y)
    Input.action_press("shoot")
    sce._process(1.0/60.0)
    Input.action_release("shoot")
    print("after shoot state=", GM.state)
    var old_y = sce.player_y
    Input.action_press("move_up")
    Input.action_press("shoot")
    for i in range(30):
        sce._process(1.0/60.0)
    Input.action_release("move_up")
    Input.action_release("shoot")
    print("delta_y=", sce.player_y - old_y)
    var fired = false
    for b in sce.bullet_pool:
        if b.active and b.type == "player":
            fired = true
            break
    print("player_fired=", fired)
    print("--- PROBE DONE ---")
    quit()
