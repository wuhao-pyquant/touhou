extends RefCounted

const VERSION := 1
const PHASE_ENTERING := "entering"
const PHASE_ACTIVE := "active"
const PHASE_SWITCHING := "switching"
const PHASE_DEFEATED := "defeated"
const PHASES := [PHASE_ENTERING, PHASE_ACTIVE, PHASE_SWITCHING, PHASE_DEFEATED]
const TRANSITIONS := {
	PHASE_ENTERING: [PHASE_ACTIVE],
	PHASE_ACTIVE: [PHASE_ACTIVE, PHASE_SWITCHING, PHASE_DEFEATED],
	PHASE_SWITCHING: [PHASE_ACTIVE, PHASE_DEFEATED],
	PHASE_DEFEATED: [],
}

func create_initial_state(x: float, y: float, sway: float) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"hp": 500.0,
		"max_hp": 500.0,
		"radius": 28.0,
		"phase": PHASE_ENTERING,
		"timer": 0.0,
		"entered": false,
		"sway": sway,
		"declaring": false,
		"declare_timer": 0.0,
		"card_name": "",
		"cards": [],
		"card_idx": 0,
		"card_hp": 0.0,
		"card_timer": 0.0,
		"card_shot": 0.0,
		"flash": 0.0,
		"rot": 0.0,
		"anim": 0.0,
		"alive": true,
	}

func transition(state: Dictionary, next_phase: String, reset_timer: bool = false) -> bool:
	var current := String(state.get("phase", ""))
	if current not in PHASES or next_phase not in TRANSITIONS.get(current, []):
		return false
	state["phase"] = next_phase
	if reset_timer:
		state["timer"] = 0.0
	return true

func is_damageable(state: Dictionary) -> bool:
	return String(state.get("phase", "")) == PHASE_ACTIVE and not bool(state.get("declaring", false))

func capture_state(state: Dictionary) -> Dictionary:
	return {"version": VERSION, "state": state.duplicate(true)}

func restore_state(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("version", -1)) != VERSION:
		return {}
	var restored: Dictionary = snapshot.get("state", {}).duplicate(true)
	if String(restored.get("phase", "")) not in PHASES:
		return {}
	return restored
