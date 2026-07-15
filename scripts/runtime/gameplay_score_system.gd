extends RefCounted
class_name GameplayScoreSystem

const MULTIPLIER_STEP := 0.1
const MULTIPLIER_MAX := 2.0

func multiplier_for_seals(seal_count: int) -> float:
	return minf(MULTIPLIER_MAX, 1.0 + float(maxi(seal_count, 0)) * MULTIPLIER_STEP)

func apply_night_festival_seal(game_manager_ref: Object) -> float:
	game_manager_ref.night_festival_seals += 1
	game_manager_ref.night_festival_multiplier = multiplier_for_seals(game_manager_ref.night_festival_seals)
	game_manager_ref.highest_night_festival_multiplier = maxf(
		float(game_manager_ref.highest_night_festival_multiplier),
		float(game_manager_ref.night_festival_multiplier)
	)
	return float(game_manager_ref.night_festival_multiplier)

func begin_spell(game_manager_ref: Object, card_id: String, base_value: int, total_frames: float) -> void:
	game_manager_ref.spell_capture_active = true
	game_manager_ref.spell_capture_invalidated = false
	game_manager_ref.spell_capture_invalid_reason = ""
	game_manager_ref.spell_capture_card_id = card_id
	game_manager_ref.spell_capture_base_value = maxi(base_value, 0)
	game_manager_ref.spell_capture_total_frames = maxf(total_frames, 1.0)
	game_manager_ref.run_spell_attempts += 1

func invalidate_spell(game_manager_ref: Object, reason: String) -> void:
	if not bool(game_manager_ref.spell_capture_active):
		return
	game_manager_ref.spell_capture_invalidated = true
	if String(game_manager_ref.spell_capture_invalid_reason) == "":
		game_manager_ref.spell_capture_invalid_reason = reason

func record_bomb(game_manager_ref: Object) -> void:
	invalidate_spell(game_manager_ref, "bomb")

func record_actual_miss(game_manager_ref: Object) -> void:
	invalidate_spell(game_manager_ref, "miss")
	game_manager_ref.night_festival_seals = 0
	game_manager_ref.night_festival_multiplier = 1.0

func capture_bonus(base_value: int, remaining_frames: float, total_frames: float, multiplier: float) -> int:
	var remaining_ratio := clampf(remaining_frames / maxf(total_frames, 1.0), 0.0, 1.0)
	return int(floor(float(maxi(base_value, 0)) * remaining_ratio * clampf(multiplier, 1.0, MULTIPLIER_MAX)))

func finish_spell(game_manager_ref: Object, remaining_frames: float, timed_out: bool = false) -> Dictionary:
	if not bool(game_manager_ref.spell_capture_active):
		return {}
	var reason := "capture"
	var captured := true
	if timed_out:
		reason = "timeout"
		captured = false
	elif bool(game_manager_ref.spell_capture_invalidated):
		reason = String(game_manager_ref.spell_capture_invalid_reason)
		captured = false
	var bonus := 0
	var bounded_remaining_frames := clampf(remaining_frames, 0.0, float(game_manager_ref.spell_capture_total_frames))
	if captured:
		bonus = capture_bonus(
			int(game_manager_ref.spell_capture_base_value),
			bounded_remaining_frames,
			float(game_manager_ref.spell_capture_total_frames),
			float(game_manager_ref.night_festival_multiplier)
		)
		game_manager_ref.score += bonus
		game_manager_ref.run_spell_captures += 1
	var result := {
		"card_id": String(game_manager_ref.spell_capture_card_id),
		"captured": captured,
		"reason": reason,
		"bonus": bonus,
		"base_value": int(game_manager_ref.spell_capture_base_value),
		"remaining_frames": bounded_remaining_frames,
		"total_frames": float(game_manager_ref.spell_capture_total_frames),
		"multiplier": float(game_manager_ref.night_festival_multiplier),
	}
	game_manager_ref.last_capture_result = result.duplicate(true)
	game_manager_ref.spell_capture_active = false
	return result
