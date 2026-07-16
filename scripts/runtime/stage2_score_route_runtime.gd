class_name Stage2ScoreRouteRuntime
extends RefCounted

const ARTIFACT_ID := "m2_stage2_score_route_contract_v1"
const STAGE_ID := "youkai_market"
const SNAPSHOT_VERSION := 3
const DIFFICULTIES := ["normal", "hard"]
const STATES := [
	"inactive", "teaching_only", "awaiting_publication", "group_1_armed",
	"group_2_armed", "group_3_armed", "group_3_pending_final_cross",
	"complete", "invalidated", "expired",
]
const TERMINAL_STATES := ["complete", "invalidated", "expired"]
const BOOTH_SPAWNS := [
	"s2_b13_red_booth_master", "s2_b13_blue_booth_master", "s2_b13_yellow_booth_master",
]
const MIRROR_SPAWNS := ["s2_b15_left_mirror", "s2_b15_right_mirror"]
const EXPECTED_TARGETS := {
	1: "s2_b13_red_booth_master",
	2: "s2_b13_blue_booth_master",
	3: "s2_b13_yellow_booth_master",
}
const TARGET_ENEMIES := {
	"s2_b13_red_booth_master": "booth_master_red",
	"s2_b13_blue_booth_master": "booth_master_blue",
	"s2_b13_yellow_booth_master": "booth_master_yellow",
	"s2_b15_left_mirror": "water_mirror_yokai",
	"s2_b15_right_mirror": "water_mirror_yokai",
	"s2_b16_abacus_keeper": "closing_abacus_keeper",
}
const TARGET_EVENTS := {
	"s2_b13_red_booth_master": "s2_b13",
	"s2_b13_blue_booth_master": "s2_b14",
	"s2_b13_yellow_booth_master": "s2_b17",
	"s2_b15_left_mirror": "s2_b15",
	"s2_b15_right_mirror": "s2_b15",
	"s2_b16_abacus_keeper": "s2_b16",
}
const TEACHING_TARGETS := {
	"s2_b01_abacus_left": ["s2_b01", "market_abacus_frame"],
	"s2_b01_abacus_center": ["s2_b01", "market_abacus_frame"],
	"s2_b01_abacus_right": ["s2_b01", "market_abacus_frame"],
	"s2_b02_left_clerk": ["s2_b02", "abacus_clerk"],
	"s2_b02_center_clerk": ["s2_b02", "abacus_clerk"],
	"s2_b02_right_clerk": ["s2_b02", "abacus_clerk"],
	"s2_b03_red_ledger": ["s2_b03", "price_tag_yokai_red"],
	"s2_b03_blue_ledger": ["s2_b03", "price_tag_yokai_blue"],
	"s2_b04_left_booth_edge": ["s2_b04", "booth_edge_keeper"],
	"s2_b04_right_booth_edge": ["s2_b04", "booth_edge_keeper"],
	"s2_b05_left_bead_seller": ["s2_b05", "bead_seller"],
	"s2_b05_right_bead_seller": ["s2_b05", "bead_seller"],
}
const GROUP_START_TICKS := {1: 1800, 2: 1950, 3: 2100}
const GROUP_DEADLINES := {1: 1944, 2: 2094, 3: 2544}
const REQUIRED_SOURCES := {
	1: "s2_b13_blue_booth_master",
	2: "s2_b13_blue_booth_master",
	3: "s2_b16_abacus_keeper",
}
const REQUIRED_SOURCE_EVENTS := {1: "s2_b13", 2: "s2_b14", 3: "s2_b16"}
const INITIAL_EDGES := [
	["lane_left", "lane_center"], ["lane_center", "lane_right"],
	["lane_left", "booth_red"], ["lane_center", "booth_red"],
	["lane_right", "booth_red"], ["lane_center", "booth_blue"],
	["lane_right", "booth_yellow"],
]
const AFTER_RED_EDGES := [
	["lane_center", "lane_left"], ["lane_center", "lane_right"],
	["lane_center", "booth_blue"], ["lane_right", "booth_yellow"],
]
const AFTER_BLUE_EDGES := [
	["lane_center", "lane_left"], ["lane_right", "lane_center"],
	["lane_right", "booth_yellow"],
]
const MIRROR_ROWS := {
	"s2_b15_left_mirror": {
		"selected_spawn_id": "s2_b15_left_mirror",
		"surviving_spawn_id": "s2_b15_right_mirror",
		"token_alias": "mirror_token_left",
		"spawn_side": "left",
		"spawn_x": 228,
		"geometric_axis": "horizontal",
		"geometric_transform_id": "horizontal_left_to_right_once",
		"source_routing_id": "horizontal_mirror_to_right_lane_once",
		"source_lane_id": "lane_left",
		"mapped_lane_id": "lane_right",
		"revision_id": "stage_front_after_left_horizontal_transform",
	},
	"s2_b15_right_mirror": {
		"selected_spawn_id": "s2_b15_right_mirror",
		"surviving_spawn_id": "s2_b15_left_mirror",
		"token_alias": "mirror_token_right",
		"spawn_side": "right",
		"spawn_x": 492,
		"geometric_axis": "diagonal_down_left",
		"geometric_transform_id": "diagonal_right_to_left_after_delay",
		"source_routing_id": "diagonal_mirror_to_left_lane_after_delay",
		"source_lane_id": "lane_right",
		"mapped_lane_id": "lane_left",
		"revision_id": "stage_front_after_right_diagonal_transform",
	},
}
const MIRROR_EDGES := {
	"s2_b15_left_mirror": [
		["lane_center", "lane_left"], ["lane_right", "lane_center"],
		["lane_left", "lane_right"], ["lane_right", "booth_yellow"],
		["lane_right", "mirror_right"],
	],
	"s2_b15_right_mirror": [
		["lane_center", "lane_left"], ["lane_right", "lane_center"],
		["lane_right", "lane_left"], ["lane_left", "booth_yellow"],
		["lane_left", "mirror_left"],
	],
}
const FINAL_EDGES := {
	"s2_b15_left_mirror": [
		["lane_center", "lane_left"], ["lane_right", "lane_center"],
		["lane_left", "lane_right"], ["lane_right", "boss_gate"],
	],
	"s2_b15_right_mirror": [
		["lane_center", "lane_left"], ["lane_right", "lane_center"],
		["lane_right", "lane_left"], ["lane_left", "boss_gate"],
	],
}
const DROP_ALIASES := {
	"point_large": {"behavior": "canonical_item_batch", "canonical_item_id": "point", "count": 4},
	"point_small": {"behavior": "canonical_item_batch", "canonical_item_id": "point", "count": 1},
	"power_large": {"behavior": "canonical_item_batch", "canonical_item_id": "power", "count": 4},
	"power_small": {"behavior": "canonical_item_batch", "canonical_item_id": "power", "count": 1},
	"price_token_1": {"behavior": "route_token", "emits_resource_item": false, "metadata": {"token_kind": "posted_price", "posted_price": 1, "route_local": true, "persistent_inventory": false}},
	"price_token_2": {"behavior": "route_token", "emits_resource_item": false, "metadata": {"token_kind": "posted_price", "posted_price": 2, "route_local": true, "persistent_inventory": false}},
	"price_token_3": {"behavior": "route_token", "emits_resource_item": false, "metadata": {"token_kind": "posted_price", "posted_price": 3, "route_local": true, "persistent_inventory": false}},
	"mirror_token_left": {"behavior": "route_token", "emits_resource_item": false, "metadata": {"token_kind": "mirror_choice", "mirror_spawn_side": "left", "mirror_geometric_axis": "horizontal", "mirror_transform_id": "horizontal_left_to_right_once", "source_lane_id": "lane_left", "mapped_lane_id": "lane_right", "route_local": true, "persistent_inventory": false}},
	"mirror_token_right": {"behavior": "route_token", "emits_resource_item": false, "metadata": {"token_kind": "mirror_choice", "mirror_spawn_side": "right", "mirror_geometric_axis": "diagonal_down_left", "mirror_transform_id": "diagonal_right_to_left_after_delay", "source_lane_id": "lane_right", "mapped_lane_id": "lane_left", "route_local": true, "persistent_inventory": false}},
}
const SNAPSHOT_KEYS := [
	"version", "artifact_id", "stage_id", "configured", "difficulty", "stage_run_uid",
	"route_state", "last_stage_tick", "last_event_sequence", "last_callback_signature", "last_callback_record",
	"teaching_markers", "teaching_graze_uids", "publication", "settled_group_count",
	"point_value_multiplier", "topology_revision_id", "active_directed_edges",
	"defeated_booth_spawn_ids", "selected_mirror", "selected_mirror_kill_tick",
	"selected_mirror_kill_event_sequence",
	"surviving_mirror_kill_tick", "surviving_mirror_kill_event_sequence",
	"abacus_kill_tick", "abacus_kill_event_sequence", "first_kill_role",
	"mirror_activation_mask", "center_lane_preserved", "abacus_active",
	"emission_registry", "required_bullet_by_group", "accepted_graze_uids", "group_latches",
	"consumed_transition_keys", "settlement_records", "final_open_lane_id",
	"last_surviving_booth_node_id", "precommit_tick", "precommit_event_sequence", "terminal_reason",
	"terminal_cause_record",
]
const FROZEN_TELEMETRY_FIELDS_JSON := """{"stage_run_uid":{"type":"string","required":"all records","meaning":"Stable identity for one Stage 2 attempt and the scope for all route deduplication."},"difficulty":{"type":"enum(normal,hard)","required":"all records"},"stage_tick":{"type":"non_negative_integer","required":"all records"},"event_sequence":{"type":"non_negative_integer","required":"every callback","meaning":"Monotonic tie-breaker within a stage tick."},"event_id":{"type":"string","required":"every callback"},"route_state_before":{"type":"route_state_id","required":"every transition"},"route_state_after":{"type":"route_state_id","required":"every transition"},"transition_reason":{"type":"string","required":"every transition"},"group_index":{"type":"integer(1..3)","required":"armed, predicate, and settlement records"},"settled_group_count":{"type":"integer(0..3)","required":"every transition and settlement"},"published_price":{"type":"integer(1..3)","required":"publication and group records"},"expected_target_spawn_id":{"type":"string","required":"each group arm and booth defeat"},"defeated_spawn_id":{"type":"string","required":"each defeat callback"},"kill_tick":{"type":"non_negative_integer","required":"each defeat callback"},"kill_event_sequence":{"type":"non_negative_integer","required":"each defeat callback"},"player_center_x":{"type":"number","required":"every topology checkpoint","meaning":"Input to stage_front_topology.coordinate_contract.current_lane_algorithm."},"current_lane_id":{"type":"enum(lane_left,lane_center,lane_right)","required":"every topology checkpoint","meaning":"Deterministically derived from player_center_x, never supplied independently."},"lane_state_before_kill":{"type":"object","required":"each booth defeat","schema":{"revision_id":"string","current_lane_id":"enum(lane_left,lane_center,lane_right)","active_directed_edges":"array([from_node_id,to_node_id])"}},"killed_flag":{"type":"enum(red,blue,yellow)","required":"s2_b14 neighbor effect"},"affected_lane_ids":{"type":"ordered_array(enum(lane_left,lane_center,lane_right))","required":"each neighbor kill transform","meaning":"Must exactly equal the affected_lane_ids array declared by the applied transform."},"topology_revision_id":{"type":"stage_front_topology revision_id","required":"every topology checkpoint and transform"},"reachable_lane_graph":{"type":"array([from_node_id,to_node_id])","required":"s2_b14 and all topology evaluations","encoding":"Unique active edges sorted first by from_node_id and then by to_node_id; node and edge semantics come only from stage_front_topology."},"required_bullet_uid":{"type":"string","required":"each group after required bead selection"},"bullet_uid":{"type":"string","required":"every route graze callback"},"bullet_source_spawn_id":{"type":"string","required":"every route graze callback"},"bullet_spawn_tick":{"type":"non_negative_integer","required":"every required bead selection"},"first_reflection_tick":{"type":"non_negative_integer","required":"every qualifying route graze"},"reflection_count_before_graze":{"type":"positive_integer","required":"every route graze callback"},"graze_tick":{"type":"non_negative_integer","required":"every route graze callback"},"duplicate_graze_ignored":{"type":"boolean","required":"every repeated bullet_uid callback"},"selected_mirror_spawn_id":{"type":"enum(s2_b15_left_mirror,s2_b15_right_mirror)","required":"group 3 mirror choice"},"surviving_mirror_spawn_id":{"type":"enum(s2_b15_left_mirror,s2_b15_right_mirror)","required":"group 3 mirror choice and s2_b16 recovery","meaning":"The other spawn in the selected mirror_transform_table row; it must differ from selected_mirror_spawn_id."},"mirror_spawn_side":{"type":"enum(left,right)","required":"group 3 mirror choice"},"mirror_geometric_axis":{"type":"enum(horizontal,diagonal_down_left)","required":"group 3 mirror choice"},"mirror_transform_id":{"type":"enum(horizontal_left_to_right_once,diagonal_right_to_left_after_delay)","required":"group 3 mirror choice"},"source_lane_id":{"type":"enum(lane_left,lane_right)","required":"group 3 mirror choice"},"mapped_lane_id":{"type":"enum(lane_left,lane_right)","required":"group 3 mirror choice and topology evaluation"},"selected_mirror_kill_tick":{"type":"non_negative_integer","required":"s2_b15 mirror choice"},"surviving_mirror_kill_tick":{"type":"non_negative_integer","required":"s2_b16 recovery"},"surviving_mirror_kill_event_sequence":{"type":"non_negative_integer","required":"s2_b16 recovery"},"abacus_kill_tick":{"type":"non_negative_integer","required":"group 3 recovery"},"abacus_kill_event_sequence":{"type":"non_negative_integer","required":"s2_b16 recovery"},"first_kill_role":{"type":"enum(surviving_mirror,abacus_keeper)","required":"s2_b16 recovery","meaning":"First defeat in total event order among surviving_mirror_spawn_id and s2_b16_abacus_keeper; the already-defeated selected mirror is excluded."},"mirror_activation_mask":{"type":"integer(0..7)","required":"s2_b16 recovery","bit_definitions":{"bit_0_value_1":"left horizontal transform is the selected committed route","bit_1_value_2":"right diagonal transform is the selected committed route","bit_2_value_4":"surviving_mirror_spawn_id is alive at s2_b16 entry"},"score_candidate_values":[5,6]},"center_lane_preserved":{"type":"boolean","required":"s2_b16 recovery"},"price_page_tick":{"type":"non_negative_integer","required":"s2_b17 countdown"},"current_price":{"type":"integer(1..3)","required":"s2_b17 countdown"},"precommit_tick":{"type":"non_negative_integer","required":"group 3 precommit"},"final_open_lane_id":{"type":"enum(lane_left,lane_right)","required":"group 3 precommit and final crossing","derivation":"Exact mapped_lane_id from the frozen selected mirror_transform_table row after booth_yellow is verified as the last surviving booth."},"last_surviving_booth_node_id":{"type":"constant(booth_yellow)","required":"group 3 target defeat"},"final_lane_cross_lane_id":{"type":"enum(lane_left,lane_center,lane_right)","required":"s2_b18 crossing callback","meaning":"Lane derived from player_center_x at final_lane_cross_tick; success requires equality with frozen final_open_lane_id."},"final_lane_cross_tick":{"type":"non_negative_integer","required":"s2_b18 success"},"boss_gate_open_tick":{"type":"non_negative_integer","required":"s2_b18 completion"},"point_value_multiplier_before":{"type":"number","required":"every group settlement"},"point_value_multiplier_after":{"type":"number","required":"every group settlement"},"seal_item_id":{"type":"string","required":"group 3 settlement","constant":"night_festival_seal"},"seal_spawn_count":{"type":"non_negative_integer","required":"every group settlement"},"invalidation_reason":{"type":"invalidation_reason_id","required":"invalidated, expired, and ignored-duplicate records"}}"""

var _configured := false
var _difficulty := ""
var _stage_run_uid := ""
var _route_state := "inactive"
var _last_stage_tick := -1
var _last_event_sequence := -1
var _last_callback_signature := ""
var _last_callback_record: Dictionary = {}
var _teaching_markers: Array = []
var _teaching_graze_uids: Array = []
var _publication: Dictionary = {}
var _settled_group_count := 0
var _point_value_multiplier := 1.0
var _topology_revision_id := ""
var _active_directed_edges: Array = []
var _defeated_booth_spawn_ids: Array = []
var _selected_mirror: Dictionary = {}
var _selected_mirror_kill_tick := -1
var _selected_mirror_kill_event_sequence := -1
var _surviving_mirror_kill_tick := -1
var _surviving_mirror_kill_event_sequence := -1
var _abacus_kill_tick := -1
var _abacus_kill_event_sequence := -1
var _first_kill_role := ""
var _mirror_activation_mask := 0
var _center_lane_preserved := false
var _abacus_active := false
var _emission_registry: Dictionary = {}
var _required_bullet_by_group: Dictionary = {}
var _accepted_graze_uids: Array = []
var _group_latches: Dictionary = {}
var _consumed_transition_keys: Array = []
var _settlement_records: Array = []
var _final_open_lane_id := ""
var _last_surviving_booth_node_id := ""
var _precommit_tick := -1
var _precommit_event_sequence := -1
var _terminal_reason := ""
var _terminal_cause_record: Dictionary = {}
var _last_error := ""

func configure(contract: Dictionary, difficulty: String, stage_run_uid: String) -> bool:
	if not _validate_contract(contract):
		if _last_error.is_empty():
			_last_error = "approved Stage 2 score-route contract validation failed"
		return false
	if difficulty not in DIFFICULTIES:
		_last_error = "difficulty must be normal or hard"
		return false
	if stage_run_uid.strip_edges().is_empty():
		_last_error = "stage_run_uid must be nonempty"
		return false
	_reset_state()
	_configured = true
	_difficulty = difficulty
	_stage_run_uid = stage_run_uid
	_last_error = ""
	return true

func load_contract(path: String, difficulty: String, stage_run_uid: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		_last_error = "score-route contract file is unavailable"
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_last_error = "score-route contract JSON is malformed"
		return false
	return configure(parsed, difficulty, stage_run_uid)

func last_error() -> String:
	return _last_error

func is_configured() -> bool:
	return _configured

func route_state() -> String:
	return _route_state

func difficulty() -> String:
	return _difficulty

func stage_run_uid() -> String:
	return _stage_run_uid

func settled_group_count() -> int:
	return _settled_group_count

func point_value_multiplier() -> float:
	return _point_value_multiplier

func final_open_lane_id() -> String:
	return _final_open_lane_id

func settlement_records() -> Array:
	return _settlement_records.duplicate(true)

func topology_snapshot() -> Dictionary:
	return {
		"topology_revision_id": _topology_revision_id,
		"reachable_lane_graph": _sorted_edges(_active_directed_edges),
	}

func resolve_drop_alias(alias_id: String) -> Dictionary:
	if not DROP_ALIASES.has(alias_id):
		return {"ok": false, "error": "unknown Stage 2 drop alias"}
	var resolved: Dictionary = DROP_ALIASES[alias_id].duplicate(true)
	resolved["ok"] = true
	resolved["alias_id"] = alias_id
	return resolved

func on_stage_event_entry(event_id: String, stage_tick: int, event_sequence: int, payload: Dictionary = {}) -> Dictionary:
	if not _valid_stage_event_id(event_id):
		return _reject("stage event id is not canonical")
	if event_id == "s2_b01" and stage_tick != 0:
		return _reject("s2_b01 must enter at tick zero")
	if event_id == "s2_b12" and not _publication_payload_well_formed(payload):
		return _reject("s2_b12 publication payload is malformed")
	if event_id != "s2_b12" and not payload.is_empty():
		return _reject("only s2_b12 accepts a stage-event payload")
	var begun := _begin_callback("stage_event_entry", {"event_id": event_id, "payload": payload}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	if _route_state in TERMINAL_STATES:
		return _ignored("terminal route ignores stage events")
	if event_id == "s2_b01":
		if _route_state == "inactive":
			_route_state = "teaching_only"
		return _accepted()
	if event_id == "s2_b06":
		if _route_state == "teaching_only":
			_teaching_markers.clear()
			_teaching_graze_uids.clear()
			_route_state = "awaiting_publication"
		return _accepted()
	if event_id == "s2_b12":
		if _route_state != "awaiting_publication":
			return _ignored("publication is not currently armed")
		if stage_tick > 1794 or not _valid_publication(payload):
			_expire("publication_mismatch")
			return _accepted({"invalidation_reason": "publication_mismatch"})
		_publication = {"red": 3, "blue": 2, "yellow": 1, "completion_tick": stage_tick}
		_route_state = "group_1_armed"
		_topology_revision_id = "stage_front_initial"
		_active_directed_edges = INITIAL_EDGES.duplicate(true)
		return _accepted()
	if event_id == "s2_b16" and _route_state == "group_3_armed" and not _selected_mirror.is_empty():
		_activate_abacus()
	return _accepted()

func on_enemy_defeat(event_id: String, defeated_spawn_id: String, enemy_id: String, player_center_x: float, stage_tick: int, event_sequence: int) -> Dictionary:
	var is_teaching_target := TEACHING_TARGETS.has(defeated_spawn_id)
	if not TARGET_ENEMIES.has(defeated_spawn_id) and not is_teaching_target:
		return _reject("defeat spawn id is not a score-route source")
	if is_teaching_target:
		var teaching_tuple: Array = TEACHING_TARGETS[defeated_spawn_id]
		if String(teaching_tuple[0]) != event_id or String(teaching_tuple[1]) != enemy_id:
			return _reject("teaching defeat callback source tuple is contradictory")
	else:
		var expected_event_id := String(TARGET_EVENTS[defeated_spawn_id])
		if defeated_spawn_id in MIRROR_SPAWNS and not _selected_mirror.is_empty():
			expected_event_id = "s2_b16"
		if String(TARGET_ENEMIES[defeated_spawn_id]) != enemy_id or expected_event_id != event_id:
			return _reject("defeat callback source tuple is contradictory")
	if not is_finite(player_center_x):
		return _reject("player collision-center x must be finite")
	if not is_teaching_target and defeated_spawn_id in MIRROR_SPAWNS and _selected_mirror.is_empty():
		return _reject("the first mirror defeat must use on_mirror_choice")
	var begun := _begin_callback("enemy_defeat", {"event_id": event_id, "spawn_id": defeated_spawn_id, "enemy_id": enemy_id, "player_center_x": player_center_x}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	if _route_state in TERMINAL_STATES:
		return _ignored("terminal route ignores defeats")
	if event_id == "s2_b16" and defeated_spawn_id in MIRROR_SPAWNS + ["s2_b16_abacus_keeper"] and stage_tick < 2250:
		return _ignored("mirror recovery window is not open")
	if _route_state == "teaching_only":
		if is_teaching_target and defeated_spawn_id not in _teaching_markers:
			_teaching_markers.append(defeated_spawn_id)
		return _accepted()
	if is_teaching_target:
		return _ignored("teaching defeat cannot affect the post-midboss route")
	if defeated_spawn_id in BOOTH_SPAWNS:
		return _process_booth_defeat(defeated_spawn_id, player_center_x, stage_tick, event_sequence)
	if defeated_spawn_id == String(_selected_mirror.get("surviving_spawn_id", "")):
		if _surviving_mirror_kill_tick >= 0:
			return _ignored("duplicate surviving-mirror defeat")
		_surviving_mirror_kill_tick = stage_tick
		_surviving_mirror_kill_event_sequence = event_sequence
		if _first_kill_role.is_empty():
			_first_kill_role = "surviving_mirror"
		_remove_edge(_mirror_attachment_edge(defeated_spawn_id))
		return _try_precommit(stage_tick, event_sequence)
	if defeated_spawn_id == "s2_b16_abacus_keeper":
		if _abacus_kill_tick >= 0:
			return _ignored("duplicate abacus defeat")
		if _selected_mirror.is_empty():
			return _ignored("abacus recovery is not armed before mirror selection")
		_activate_abacus()
		_center_lane_preserved = _has_center_lane_connection()
		_abacus_kill_tick = stage_tick
		_abacus_kill_event_sequence = event_sequence
		if _first_kill_role.is_empty():
			_first_kill_role = "abacus_keeper"
		_remove_edge(["lane_center", "abacus_center"])
		_abacus_active = false
		if _first_kill_role != "surviving_mirror":
			return _invalidate_result("abacus_before_surviving_mirror")
		return _try_precommit(stage_tick, event_sequence)
	return _ignored("defeat is not active for the frozen mirror row")

func on_required_bullet_emitted(event_id: String, bullet_uid: String, bullet_source_spawn_id: String, bullet_spawn_tick: int, bullet_spawn_event_sequence: int, stage_tick: int, event_sequence: int) -> Dictionary:
	if bullet_uid.strip_edges().is_empty() or bullet_source_spawn_id.strip_edges().is_empty():
		return _reject("bullet emission requires nonempty bullet identity and source")
	if bullet_spawn_tick < 0 or bullet_spawn_event_sequence < 0 or bullet_spawn_tick != stage_tick:
		return _reject("bullet emission order is malformed")
	if not _valid_required_source_tuple(event_id, bullet_source_spawn_id):
		return _reject("bullet emission source tuple is not canonical")
	var emission := {
		"event_id": event_id,
		"source_spawn_id": bullet_source_spawn_id,
		"bullet_spawn_tick": bullet_spawn_tick,
		"bullet_spawn_event_sequence": bullet_spawn_event_sequence,
		"callback_stage_tick": stage_tick,
		"callback_event_sequence": event_sequence,
	}
	if _emission_registry.has(bullet_uid):
		if _emission_registry[bullet_uid] == emission:
			return _ignored("duplicate_transition_callback")
		return _reject("bullet UID was reused with a contradictory immutable emission tuple")
	if bullet_uid in _teaching_graze_uids:
		return _reject("bullet UID was already used by teaching telemetry")
	for frozen_group_key in _required_bullet_by_group:
		var frozen_group := int(frozen_group_key)
		if event_id != REQUIRED_SOURCE_EVENTS[frozen_group] or bullet_source_spawn_id != REQUIRED_SOURCES[frozen_group]:
			continue
		var frozen_uid := String(_required_bullet_by_group[frozen_group_key])
		var frozen_emission: Dictionary = _emission_registry.get(frozen_uid, {})
		if _emission_tuple_precedes(emission, bullet_uid, frozen_emission, frozen_uid):
			return _reject("emission would contradict an immutable required-bullet selection")
	var begun := _begin_callback("required_bullet_emitted", {"event_id": event_id, "bullet_uid": bullet_uid, "source": bullet_source_spawn_id, "spawn_tick": bullet_spawn_tick, "spawn_event_sequence": bullet_spawn_event_sequence}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	_emission_registry[bullet_uid] = emission
	if _route_state in TERMINAL_STATES or _route_state == "teaching_only":
		return _ignored("no post-midboss rebound selection is armed")
	var group_index := _armed_group_index()
	if group_index == 0 or _route_state == "group_3_pending_final_cross":
		return _ignored("no rebound selection is armed")
	if event_id != String(REQUIRED_SOURCE_EVENTS[group_index]) or bullet_source_spawn_id != String(REQUIRED_SOURCES[group_index]):
		return _ignored("emitted bullet is not the required group source")
	if bullet_spawn_tick < int(GROUP_START_TICKS[group_index]) or bullet_spawn_tick > int(GROUP_DEADLINES[group_index]):
		return _ignored("emitted bullet lies outside the predicate window")
	return _accepted({"group_index": group_index, "recorded_bullet_uid": bullet_uid})

func on_reflected_bullet_graze(event_id: String, bullet_uid: String, bullet_source_spawn_id: String, bullet_spawn_tick: int, bullet_spawn_event_sequence: int, first_reflection_tick: int, reflection_count_before_graze: int, stage_tick: int, event_sequence: int) -> Dictionary:
	if bullet_uid.strip_edges().is_empty() or bullet_source_spawn_id.strip_edges().is_empty():
		return _reject("graze callback requires nonempty bullet identity and source")
	if bullet_spawn_tick < 0 or bullet_spawn_event_sequence < 0 or first_reflection_tick < bullet_spawn_tick or reflection_count_before_graze < 1:
		return _reject("graze callback has an invalid reflection timeline")
	if first_reflection_tick > stage_tick:
		return _reject("graze precedes its first reflection")
	if _route_state == "teaching_only" and _emission_registry.has(bullet_uid):
		return _reject("teaching graze UID collides with an emitted route bullet")
	if _route_state == "teaching_only":
		if not TEACHING_TARGETS.has(bullet_source_spawn_id) or String((TEACHING_TARGETS[bullet_source_spawn_id] as Array)[0]) != event_id:
			return _reject("teaching graze source tuple is not canonical")
	if _route_state != "teaching_only":
		if not _emission_registry.has(bullet_uid):
			return _reject("graze references an unregistered bullet UID")
		var emission: Dictionary = _emission_registry[bullet_uid]
		if emission.get("event_id") != event_id or emission.get("source_spawn_id") != bullet_source_spawn_id or emission.get("bullet_spawn_tick") != bullet_spawn_tick or emission.get("bullet_spawn_event_sequence") != bullet_spawn_event_sequence:
			return _reject("graze metadata contradicts the immutable emission tuple")
	var begun := _begin_callback("reflected_bullet_graze", {"event_id": event_id, "bullet_uid": bullet_uid, "source": bullet_source_spawn_id, "spawn_tick": bullet_spawn_tick, "spawn_event_sequence": bullet_spawn_event_sequence, "reflection_tick": first_reflection_tick, "reflection_count": reflection_count_before_graze}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	if bullet_uid in _accepted_graze_uids or bullet_uid in _teaching_graze_uids:
		return _ignored("duplicate_transition_callback", {"duplicate_graze_ignored": true})
	if _route_state == "teaching_only":
		_teaching_graze_uids.append(bullet_uid)
		return _accepted({"teaching_only": true})
	if _route_state in TERMINAL_STATES:
		return _ignored("terminal route ignores grazes")
	var group_index := _armed_group_index()
	if group_index == 0 or group_index == 3 and _route_state == "group_3_pending_final_cross":
		return _ignored("no rebound predicate is armed")
	if event_id != String(REQUIRED_SOURCE_EVENTS[group_index]) or bullet_source_spawn_id != String(REQUIRED_SOURCES[group_index]):
		return _ignored("unselected bullet retains gameplay-only graze behavior")
	if bullet_spawn_tick < int(GROUP_START_TICKS[group_index]) or stage_tick > int(GROUP_DEADLINES[group_index]):
		return _ignored("bullet lies outside the armed predicate window")
	var key := str(group_index)
	var selected_uid := _select_required_bullet_uid(group_index)
	if selected_uid.is_empty():
		return _ignored("required bullet emission was not observed")
	if not _required_bullet_by_group.has(key):
		_required_bullet_by_group[key] = selected_uid
	elif String(_required_bullet_by_group[key]) != selected_uid:
		return _reject("frozen required bullet selection contradicts the emission registry")
	if selected_uid != bullet_uid:
		return _ignored("graze did not use the first emitted required bullet UID")
	_accepted_graze_uids.append(bullet_uid)
	var graze_latch := _latch(group_index)
	graze_latch["graze"] = true
	graze_latch["graze_tick"] = stage_tick
	graze_latch["graze_event_sequence"] = event_sequence
	graze_latch["graze_bullet_uid"] = bullet_uid
	graze_latch["graze_source_spawn_id"] = bullet_source_spawn_id
	graze_latch["graze_bullet_spawn_tick"] = bullet_spawn_tick
	graze_latch["graze_bullet_spawn_event_sequence"] = bullet_spawn_event_sequence
	graze_latch["first_reflection_tick"] = first_reflection_tick
	graze_latch["reflection_count_before_graze"] = reflection_count_before_graze
	return _try_settle_or_precommit(group_index, stage_tick, event_sequence)

func on_topology_checkpoint(event_id: String, player_center_x: float, stage_tick: int, event_sequence: int, expected_revision_id: String = "") -> Dictionary:
	if not _valid_stage_event_id(event_id) or not is_finite(player_center_x):
		return _reject("topology checkpoint payload is malformed")
	if not expected_revision_id.is_empty() and expected_revision_id != _topology_revision_id:
		return _reject("topology checkpoint contradicts the active revision")
	var begun := _begin_callback("topology_checkpoint", {"event_id": event_id, "player_center_x": player_center_x, "expected_revision_id": expected_revision_id}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	return _accepted({
		"current_lane_id": lane_id_for_x(player_center_x),
		"topology_revision_id": _topology_revision_id,
		"reachable_lane_graph": _sorted_edges(_active_directed_edges),
	})

func on_mirror_choice(selected_spawn_id: String, player_center_x: float, stage_tick: int, event_sequence: int) -> Dictionary:
	if selected_spawn_id not in MIRROR_SPAWNS or not is_finite(player_center_x):
		return _reject("mirror choice payload is malformed")
	var begun := _begin_callback("mirror_choice", {"spawn_id": selected_spawn_id, "player_center_x": player_center_x}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	if _route_state in TERMINAL_STATES:
		return _ignored("terminal route ignores mirror choice")
	if not _selected_mirror.is_empty():
		if String(_selected_mirror.get("selected_spawn_id", "")) == selected_spawn_id:
			return _ignored("duplicate_transition_callback")
		return _invalidate_result("mirror_choice_ambiguous")
	if _route_state != "group_3_armed" or stage_tick < 2100:
		return _ignored("mirror choice is not armed")
	if stage_tick > 2244:
		_expire("mirror_choice_expired")
		return _accepted({"invalidation_reason": "mirror_choice_expired"})
	var activated_edges: Array = AFTER_BLUE_EDGES.duplicate(true)
	activated_edges.append(["lane_left", "mirror_left"])
	activated_edges.append(["lane_right", "mirror_right"])
	var mirror_node := "mirror_left" if selected_spawn_id == "s2_b15_left_mirror" else "mirror_right"
	if not _can_reach(lane_id_for_x(player_center_x), mirror_node, activated_edges, _difficulty == "normal"):
		return _invalidate_result("topology_predicate_failed")
	_selected_mirror = MIRROR_ROWS[selected_spawn_id].duplicate(true)
	_selected_mirror_kill_tick = stage_tick
	_selected_mirror_kill_event_sequence = event_sequence
	_mirror_activation_mask = 5 if selected_spawn_id == "s2_b15_left_mirror" else 6
	_topology_revision_id = String(_selected_mirror["revision_id"])
	_active_directed_edges = MIRROR_EDGES[selected_spawn_id].duplicate(true)
	_latch(3)["mirror"] = true
	return _accepted({"selected_mirror": _selected_mirror.duplicate(true), "mirror_activation_mask": _mirror_activation_mask})

func on_final_lane_crossing(event_id: String, player_center_x: float, boss_gate_open_tick: int, stage_tick: int, event_sequence: int) -> Dictionary:
	if event_id != "s2_b18" or not is_finite(player_center_x) or boss_gate_open_tick < 0 or boss_gate_open_tick > stage_tick:
		return _reject("final crossing payload is malformed")
	var begun := _begin_callback("final_lane_crossing", {"event_id": event_id, "player_center_x": player_center_x, "boss_gate_open_tick": boss_gate_open_tick}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	if _route_state == "complete":
		return _ignored("duplicate_transition_callback")
	if _route_state != "group_3_pending_final_cross":
		return _ignored("final crossing is not armed")
	if stage_tick < 2550:
		return _ignored("final crossing window is not open")
	if stage_tick > 2700:
		_expire("final_lane_cross_expired")
		return _accepted()
	var crossing_lane := lane_id_for_x(player_center_x)
	if crossing_lane != _final_open_lane_id:
		return _invalidate_result("wrong_final_lane_cross")
	return _settle_group(3, stage_tick, event_sequence, {"final_lane_cross_lane_id": crossing_lane, "final_lane_cross_tick": stage_tick, "boss_gate_open_tick": boss_gate_open_tick})

func on_player_miss(event_id: String, stage_tick: int, event_sequence: int) -> Dictionary:
	return _unstated_player_action("player_miss", event_id, stage_tick, event_sequence)

func on_player_bomb(event_id: String, stage_tick: int, event_sequence: int) -> Dictionary:
	return _unstated_player_action("player_bomb", event_id, stage_tick, event_sequence)

func capture_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION, "artifact_id": ARTIFACT_ID, "stage_id": STAGE_ID,
		"configured": _configured, "difficulty": _difficulty, "stage_run_uid": _stage_run_uid,
		"route_state": _route_state, "last_stage_tick": _last_stage_tick,
		"last_event_sequence": _last_event_sequence, "last_callback_signature": _last_callback_signature, "last_callback_record": _last_callback_record.duplicate(true),
		"teaching_markers": _teaching_markers.duplicate(true), "teaching_graze_uids": _teaching_graze_uids.duplicate(true),
		"publication": _publication.duplicate(true), "settled_group_count": _settled_group_count,
		"point_value_multiplier": _point_value_multiplier, "topology_revision_id": _topology_revision_id,
		"active_directed_edges": _active_directed_edges.duplicate(true), "defeated_booth_spawn_ids": _defeated_booth_spawn_ids.duplicate(true),
		"selected_mirror": _selected_mirror.duplicate(true), "selected_mirror_kill_tick": _selected_mirror_kill_tick,
		"selected_mirror_kill_event_sequence": _selected_mirror_kill_event_sequence,
		"surviving_mirror_kill_tick": _surviving_mirror_kill_tick, "surviving_mirror_kill_event_sequence": _surviving_mirror_kill_event_sequence,
		"abacus_kill_tick": _abacus_kill_tick, "abacus_kill_event_sequence": _abacus_kill_event_sequence,
		"first_kill_role": _first_kill_role, "mirror_activation_mask": _mirror_activation_mask,
		"center_lane_preserved": _center_lane_preserved, "abacus_active": _abacus_active,
		"emission_registry": _emission_registry.duplicate(true), "required_bullet_by_group": _required_bullet_by_group.duplicate(true), "accepted_graze_uids": _accepted_graze_uids.duplicate(true),
		"group_latches": _group_latches.duplicate(true), "consumed_transition_keys": _consumed_transition_keys.duplicate(true),
		"settlement_records": _settlement_records.duplicate(true), "final_open_lane_id": _final_open_lane_id,
		"last_surviving_booth_node_id": _last_surviving_booth_node_id, "precommit_tick": _precommit_tick,
		"precommit_event_sequence": _precommit_event_sequence, "terminal_reason": _terminal_reason,
		"terminal_cause_record": _terminal_cause_record.duplicate(true),
	}

func validate_snapshot(snapshot: Dictionary) -> bool:
	return _validate_snapshot(snapshot)

func restore_snapshot(snapshot: Dictionary) -> bool:
	if not _validate_snapshot(snapshot):
		_last_error = "score-route snapshot validation failed"
		return false
	_apply_snapshot(snapshot)
	_last_error = ""
	return true

func deterministic_hash(value: Variant) -> int:
	return hash(JSON.stringify(_canonical(value), "", true, true))

static func lane_id_for_x(player_center_x: float) -> String:
	var clamped_x := clampf(player_center_x, 24.0, 696.0)
	if clamped_x < 248.0:
		return "lane_left"
	if clamped_x < 472.0:
		return "lane_center"
	return "lane_right"

func _process_booth_defeat(spawn_id: String, player_center_x: float, stage_tick: int, event_sequence: int) -> Dictionary:
	if spawn_id in _defeated_booth_spawn_ids:
		return _ignored("duplicate_transition_callback")
	var group_index := _armed_group_index()
	if group_index == 0 or _route_state == "group_3_pending_final_cross":
		return _ignored("no booth target is armed")
	if spawn_id != String(EXPECTED_TARGETS[group_index]):
		return _invalidate_result("wrong_booth_order")
	if stage_tick < int(GROUP_START_TICKS[group_index]):
		return _ignored("booth target window is not open")
	if stage_tick > int(GROUP_DEADLINES[group_index]):
		_expire("price_countdown_expired" if group_index == 3 else "required_rebound_graze_missing")
		return _accepted()
	var lane := lane_id_for_x(player_center_x)
	var target_node: String = ["", "booth_red", "booth_blue", "booth_yellow"][group_index]
	var topology_ok := _can_reach(lane, target_node, _active_directed_edges, _difficulty == "normal")
	if not topology_ok:
		return _invalidate_result("topology_predicate_failed")
	_defeated_booth_spawn_ids.append(spawn_id)
	var latch := _latch(group_index)
	latch["target"] = true
	latch["topology"] = true
	latch["target_tick"] = stage_tick
	latch["target_event_sequence"] = event_sequence
	latch["current_lane_id"] = lane
	latch["topology_revision_id"] = _topology_revision_id
	if group_index == 1:
		_topology_revision_id = "stage_front_after_red_neighbor_flip"
		_active_directed_edges = AFTER_RED_EDGES.duplicate(true)
	elif group_index == 2:
		_topology_revision_id = "stage_front_after_blue_neighbor_flip"
		_active_directed_edges = AFTER_BLUE_EDGES.duplicate(true)
	else:
		_last_surviving_booth_node_id = "booth_yellow"
		_final_open_lane_id = String(_selected_mirror.get("mapped_lane_id", ""))
		if _final_open_lane_id.is_empty() or not _has_edge([_final_open_lane_id, "booth_yellow"]):
			return _invalidate_result("topology_predicate_failed")
		_active_directed_edges = FINAL_EDGES[String(_selected_mirror["selected_spawn_id"])].duplicate(true)
		_topology_revision_id = "stage_front_final_gate_open_%s" % _final_open_lane_id
	return _try_settle_or_precommit(group_index, stage_tick, event_sequence)

func _try_settle_or_precommit(group_index: int, stage_tick: int, event_sequence: int) -> Dictionary:
	if group_index == 3:
		return _try_precommit(stage_tick, event_sequence)
	var latch := _latch(group_index)
	if bool(latch.get("target", false)) and bool(latch.get("topology", false)) and bool(latch.get("graze", false)):
		return _settle_group(group_index, stage_tick, event_sequence)
	return _accepted()

func _try_precommit(stage_tick: int, event_sequence: int) -> Dictionary:
	if _route_state != "group_3_armed":
		return _accepted()
	var latch := _latch(3)
	var recovery_ok := _first_kill_role == "surviving_mirror" and _surviving_mirror_kill_tick >= 0 and _abacus_kill_tick >= 0 and _center_lane_preserved
	latch["recovery"] = recovery_ok
	if bool(latch.get("mirror", false)) and bool(latch.get("target", false)) and bool(latch.get("topology", false)) and bool(latch.get("graze", false)) and recovery_ok:
		if stage_tick > 2544:
			_expire("price_countdown_expired")
			return _accepted()
		_route_state = "group_3_pending_final_cross"
		_precommit_tick = stage_tick
		_precommit_event_sequence = event_sequence
		return _accepted({"precommit_tick": stage_tick, "final_open_lane_id": _final_open_lane_id})
	return _accepted()

func _settle_group(group_index: int, stage_tick: int, event_sequence: int, extra: Dictionary = {}) -> Dictionary:
	var transition_key := "%s:%d:settle" % [_stage_run_uid, group_index]
	if transition_key in _consumed_transition_keys:
		return _ignored("duplicate_transition_callback")
	var before := _point_value_multiplier
	var producer_state := _route_state
	_settled_group_count += 1
	_point_value_multiplier = 1.0 + 0.25 * float(_settled_group_count)
	var record := {
		"stage_run_uid": _stage_run_uid, "difficulty": _difficulty,
		"group_index": group_index, "transition": "group_%d_settlement" % group_index,
		"stage_tick": stage_tick, "event_sequence": event_sequence,
		"point_item_additive_delta": 0.25, "point_value_multiplier_before": before,
		"point_value_multiplier_after": _point_value_multiplier,
		"seal_item_id": "night_festival_seal", "seal_spawn_count": 1 if group_index == 3 else 0,
	}
	for key in extra:
		record[key] = extra[key]
	_consumed_transition_keys.append(transition_key)
	_settlement_records.append(record)
	if group_index == 1:
		_route_state = "group_2_armed"
	elif group_index == 2:
		_route_state = "group_3_armed"
	else:
		_route_state = "complete"
		_terminal_reason = "route_complete"
		_freeze_terminal_cause("complete", "route_complete", producer_state, 2700)
	return _accepted({"settlement_records": [record.duplicate(true)]})

func _unstated_player_action(kind: String, event_id: String, stage_tick: int, event_sequence: int) -> Dictionary:
	if not _valid_stage_event_id(event_id):
		return _reject("player action event id is not canonical")
	var begun := _begin_callback(kind, {"event_id": event_id}, stage_tick, event_sequence)
	if not bool(begun.get("ok", false)) or bool(begun.get("ignored", false)):
		return begun
	return _accepted({"route_invalidation_forbidden": true})

func _begin_callback(kind: String, payload: Dictionary, stage_tick: int, event_sequence: int) -> Dictionary:
	if not _configured:
		return _reject("score-route runtime is not configured")
	if stage_tick < 0 or event_sequence < 0:
		return _reject("callback order values must be nonnegative")
	var callback_record := {"kind": kind, "payload": payload.duplicate(true), "stage_tick": stage_tick, "event_sequence": event_sequence}
	var signature := JSON.stringify(_canonical(callback_record), "", true, true)
	if stage_tick == _last_stage_tick and event_sequence == _last_event_sequence and signature == _last_callback_signature:
		return _ignored("duplicate_transition_callback")
	if stage_tick < _last_stage_tick or stage_tick == _last_stage_tick and event_sequence <= _last_event_sequence:
		return _reject("callback order is stale or contradictory")
	_last_stage_tick = stage_tick
	_last_event_sequence = event_sequence
	_last_callback_signature = signature
	_last_callback_record = callback_record
	_advance_deadlines(stage_tick)
	return {"ok": true, "accepted": true, "ignored": false, "settlement_records": []}

func _advance_deadlines(stage_tick: int) -> void:
	if _route_state == "awaiting_publication" and stage_tick > 1794:
		_expire("publication_mismatch")
	elif _route_state == "group_1_armed" and stage_tick > 1944:
		_expire("required_rebound_graze_missing")
	elif _route_state == "group_2_armed" and stage_tick > 2094:
		_expire("required_rebound_graze_missing")
	elif _route_state == "group_3_armed":
		if _selected_mirror.is_empty() and stage_tick > 2244:
			_expire("mirror_choice_expired")
		elif not _selected_mirror.is_empty() and stage_tick > 2394 and (_surviving_mirror_kill_tick < 0 or _abacus_kill_tick < 0 or not _center_lane_preserved):
			_expire("price_countdown_expired")
		elif stage_tick > 2544:
			_expire("price_countdown_expired")
	elif _route_state == "group_3_pending_final_cross" and stage_tick > 2700:
		_expire("final_lane_cross_expired")

func _armed_group_index() -> int:
	if _route_state == "group_1_armed": return 1
	if _route_state == "group_2_armed": return 2
	if _route_state in ["group_3_armed", "group_3_pending_final_cross"]: return 3
	return 0

func _valid_required_source_tuple(event_id: String, source_spawn_id: String) -> bool:
	for group_index in [1, 2, 3]:
		if event_id == String(REQUIRED_SOURCE_EVENTS[group_index]) and source_spawn_id == String(REQUIRED_SOURCES[group_index]):
			return true
	return false

func _select_required_bullet_uid(group_index: int) -> String:
	return _select_required_bullet_uid_from_registry(group_index, _emission_registry)

func _select_required_bullet_uid_from_registry(group_index: int, registry: Dictionary) -> String:
	var candidates: Array = []
	for uid_value in registry:
		var emission_value: Variant = registry[uid_value]
		if not (emission_value is Dictionary):
			continue
		var emission: Dictionary = emission_value
		if emission.get("event_id") != REQUIRED_SOURCE_EVENTS[group_index] or emission.get("source_spawn_id") != REQUIRED_SOURCES[group_index]:
			continue
		if int(emission.get("bullet_spawn_tick", -1)) < int(GROUP_START_TICKS[group_index]):
			continue
		if int(emission.get("bullet_spawn_tick", -1)) > int(GROUP_DEADLINES[group_index]):
			continue
		candidates.append({
			"uid": String(uid_value),
			"tick": int(emission.get("bullet_spawn_tick")),
			"sequence": int(emission.get("bullet_spawn_event_sequence")),
		})
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["tick"] != b["tick"]:
			return a["tick"] < b["tick"]
		if a["sequence"] != b["sequence"]:
			return a["sequence"] < b["sequence"]
		return a["uid"] < b["uid"]
	)
	return String(candidates[0]["uid"])

func _emission_tuple_precedes(left: Dictionary, left_uid: String, right: Dictionary, right_uid: String) -> bool:
	if right.is_empty(): return true
	var left_tick := int(left.get("bullet_spawn_tick", -1))
	var right_tick := int(right.get("bullet_spawn_tick", -1))
	if left_tick != right_tick: return left_tick < right_tick
	var left_sequence := int(left.get("bullet_spawn_event_sequence", -1))
	var right_sequence := int(right.get("bullet_spawn_event_sequence", -1))
	if left_sequence != right_sequence: return left_sequence < right_sequence
	return left_uid < right_uid

func _latch(group_index: int) -> Dictionary:
	var key := str(group_index)
	if not _group_latches.has(key):
		_group_latches[key] = {"target": false, "topology": false, "graze": false, "mirror": false, "recovery": false}
	return _group_latches[key]

func _invalidate_result(reason: String) -> Dictionary:
	var producer_state := _route_state
	_route_state = "invalidated"
	_terminal_reason = reason
	_freeze_terminal_cause("invalidated", reason, producer_state, -1)
	return _accepted({"invalidation_reason": reason, "gameplay_fallback": reason in ["abacus_before_surviving_mirror", "wrong_final_lane_cross"]})

func _expire(reason: String) -> void:
	var producer_state := _route_state
	_route_state = "expired"
	_terminal_reason = reason
	_freeze_terminal_cause("expired", reason, producer_state, _terminal_deadline_for_reason(reason, producer_state))

func _freeze_terminal_cause(terminal_state: String, reason: String, producer_state: String, deadline_tick: int) -> void:
	if not _terminal_cause_record.is_empty():
		return
	var callback_record := _last_callback_record.duplicate(true)
	_terminal_cause_record = {
		"terminal_state": terminal_state,
		"reason": reason,
		"producer_state": producer_state,
		"deadline_tick": deadline_tick,
		"callback_record": callback_record,
		"callback_signature": JSON.stringify(_canonical(callback_record), "", true, true),
		"history": _terminal_history(),
	}

func _terminal_deadline_for_reason(reason: String, producer_state: String) -> int:
	if reason == "publication_mismatch": return 1794
	if reason == "required_rebound_graze_missing": return 1944 if producer_state == "group_1_armed" else 2094
	if reason == "mirror_choice_expired": return 2244
	if reason == "price_countdown_expired":
		if not _selected_mirror.is_empty() and (_surviving_mirror_kill_tick < 0 or _abacus_kill_tick < 0 or not _center_lane_preserved): return 2394
		return 2544
	if reason == "final_lane_cross_expired": return 2700
	return -1

func _terminal_history() -> Dictionary:
	return {
		"publication": _publication.duplicate(true),
		"settled_group_count": _settled_group_count,
		"point_value_multiplier": _point_value_multiplier,
		"topology_revision_id": _topology_revision_id,
		"active_directed_edges": _active_directed_edges.duplicate(true),
		"defeated_booth_spawn_ids": _defeated_booth_spawn_ids.duplicate(true),
		"selected_mirror": _selected_mirror.duplicate(true),
		"selected_mirror_kill_tick": _selected_mirror_kill_tick,
		"selected_mirror_kill_event_sequence": _selected_mirror_kill_event_sequence,
		"surviving_mirror_kill_tick": _surviving_mirror_kill_tick,
		"surviving_mirror_kill_event_sequence": _surviving_mirror_kill_event_sequence,
		"abacus_kill_tick": _abacus_kill_tick,
		"abacus_kill_event_sequence": _abacus_kill_event_sequence,
		"first_kill_role": _first_kill_role,
		"mirror_activation_mask": _mirror_activation_mask,
		"center_lane_preserved": _center_lane_preserved,
		"abacus_active": _abacus_active,
		"required_bullet_by_group": _required_bullet_by_group.duplicate(true),
		"accepted_graze_uids": _accepted_graze_uids.duplicate(true),
		"group_latches": _group_latches.duplicate(true),
		"consumed_transition_keys": _consumed_transition_keys.duplicate(true),
		"settlement_records": _settlement_records.duplicate(true),
		"final_open_lane_id": _final_open_lane_id,
		"last_surviving_booth_node_id": _last_surviving_booth_node_id,
		"precommit_tick": _precommit_tick,
		"precommit_event_sequence": _precommit_event_sequence,
	}

func _activate_abacus() -> void:
	if not _abacus_active:
		_active_directed_edges.append(["lane_center", "abacus_center"])
		_abacus_active = true

func _has_center_lane_connection() -> bool:
	for edge_value in _active_directed_edges:
		var edge: Array = edge_value
		if edge[0] in ["lane_left", "lane_center", "lane_right"] and edge[1] in ["lane_left", "lane_center", "lane_right"] and (edge[0] == "lane_center" or edge[1] == "lane_center"):
			return true
	return false

func _mirror_attachment_edge(spawn_id: String) -> Array:
	return ["lane_right", "mirror_right"] if spawn_id == "s2_b15_right_mirror" else ["lane_left", "mirror_left"]

func _remove_edge(edge: Array) -> void:
	var index := _active_directed_edges.find(edge)
	if index >= 0:
		_active_directed_edges.remove_at(index)

func _has_edge(edge: Array) -> bool:
	return edge in _active_directed_edges

func _can_reach(from_node: String, to_node: String, edges: Array, normal_projection: bool) -> bool:
	var projected: Array = edges.duplicate(true)
	if normal_projection:
		for edge_value in edges:
			var edge: Array = edge_value
			if String(edge[0]).begins_with("lane_") and String(edge[1]).begins_with("lane_"):
				var reverse := [edge[1], edge[0]]
				if reverse not in projected:
					projected.append(reverse)
	var queue: Array = [from_node]
	var visited: Array = []
	while not queue.is_empty():
		var node: String = queue.pop_front()
		if node == to_node:
			return true
		if node in visited:
			continue
		visited.append(node)
		var next_nodes: Array = []
		for edge_value in projected:
			var edge: Array = edge_value
			if edge[0] == node:
				next_nodes.append(String(edge[1]))
		next_nodes.sort()
		for next_node in next_nodes:
			if next_node not in visited and next_node not in queue:
				queue.append(next_node)
	return false

func _sorted_edges(edges: Array) -> Array:
	var result := edges.duplicate(true)
	result.sort_custom(func(a: Array, b: Array) -> bool:
		return "%s\u0000%s" % a < "%s\u0000%s" % b
	)
	return result

func _accepted(extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "accepted": true, "ignored": false, "settlement_records": []}
	for key in extra:
		result[key] = extra[key]
	return result

func _ignored(reason: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": true, "accepted": false, "ignored": true, "invalidation_reason": reason, "settlement_records": []}
	for key in extra:
		result[key] = extra[key]
	return result

func _reject(message: String) -> Dictionary:
	_last_error = message
	return {"ok": false, "accepted": false, "ignored": false, "error": message, "settlement_records": []}

func _valid_stage_event_id(event_id: String) -> bool:
	if not event_id.begins_with("s2_b") or event_id.length() != 6:
		return false
	var number := event_id.substr(4).to_int()
	return number >= 1 and number <= 18 and event_id == "s2_b%02d" % number

func _valid_publication(payload: Dictionary) -> bool:
	return bool(payload.get("publication_complete", false)) and payload.get("prices", {}) == {"red": 3, "blue": 2, "yellow": 1}

func _publication_payload_well_formed(payload: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(payload, ["publication_complete", "prices"]):
		return false
	if typeof(payload.get("publication_complete")) != TYPE_BOOL:
		return false
	var prices_value: Variant = payload.get("prices")
	if not (prices_value is Dictionary):
		return false
	var prices: Dictionary = prices_value
	var keys: Array = prices.keys()
	keys.sort()
	if keys != ["blue", "red", "yellow"]:
		return false
	for value in prices.values():
		if typeof(value) != TYPE_INT:
			return false
	return true

func _validate_contract(contract: Dictionary) -> bool:
	var root_keys := [
		"schema_version", "artifact_id", "source_artifact_id", "source_path", "dependency_commit", "stage_id", "tick_rate",
		"difficulty_scope", "contract_scope", "drop_aliases", "published_order", "teaching_sequence", "route_states",
		"state_transitions", "event_ordering", "stage_front_topology", "rebound_graze_contract", "groups",
		"invalidation_reasons", "telemetry_fields", "invariants",
	]
	if not _dictionary_has_exact_keys(contract, root_keys): return _contract_validation_failure("root keys")
	if contract.get("schema_version") != 1 or contract.get("artifact_id") != ARTIFACT_ID or contract.get("stage_id") != STAGE_ID or contract.get("tick_rate") != 60: return _contract_validation_failure("root identity")
	if contract.get("source_artifact_id") != "m2_stage2_yokai_market_choreography_v1" or contract.get("source_path") != "content/runtime/m2_stage2_choreography.json" or contract.get("dependency_commit") != "db6b0808f7c5d322d22b22143a6dd0ec2080485a": return _contract_validation_failure("source identity")
	if not _matches_contract_projection(contract.get("difficulty_scope"), DIFFICULTIES): return _contract_validation_failure("difficulty scope")
	if not _matches_contract_projection(contract.get("contract_scope"), {
		"teaching_event_ids": ["s2_b01", "s2_b02", "s2_b03", "s2_b04", "s2_b05"],
		"publication_event_id": "s2_b12",
		"settlement_event_ids": ["s2_b13", "s2_b14", "s2_b15", "s2_b16", "s2_b17", "s2_b18"],
		"adds_runtime_content": false, "adds_enemies": false, "adds_waves": false, "adds_controls": false,
	}): return _contract_validation_failure("contract scope")
	if not _matches_contract_projection(contract.get("event_ordering"), {
		"total_order": ["stage_tick ascending", "event_sequence ascending"],
		"same_tick_rule": "Process defeat, graze, topology, and crossing callbacks one at a time in event_sequence order, applying each state transition before the next callback.",
		"simultaneous_booth_defeats": "Do not coalesce. A booth defeat that is not the currently expected target invalidates the chain even when another booth was defeated on the same tick.",
		"idempotency_key": "stage_run_uid plus group_index plus transition name",
	}): return _contract_validation_failure("event ordering")
	if not _matches_contract_projection(contract.get("rebound_graze_contract"), {
		"required_beads_per_group": 1,
		"selection_rule": "For each group, select the first bullet emitted by required_source_spawn_id at or after the group start tick, ordered by bullet_spawn_tick, event_sequence, then bullet_uid. The selected bullet_uid is immutable for that group.",
		"qualification_rule": "The selected bullet counts only when reflection_count_before_graze is at least 1 and the first accepted graze occurs inside the group's predicate window.",
		"uid_scope": "bullet_uid is stable and unique within stage_run_uid from bullet spawn through destruction.",
		"deduplication_rule": "The first qualifying graze for a bullet_uid is accepted. Repeated callbacks for the same bullet_uid are telemetry-only duplicate_graze_ignored events and never add progress or invalidate the route.",
		"cross_group_rule": "A bullet_uid accepted by one group cannot be selected by or satisfy another group.",
		"unselected_bullet_rule": "Grazes on non-selected bullets retain ordinary gameplay graze behavior but do not satisfy this score route.",
	}): return _contract_validation_failure("rebound graze contract")
	var telemetry_value: Variant = contract.get("telemetry_fields")
	if not (telemetry_value is Dictionary): return _contract_validation_failure("telemetry shape")
	var telemetry: Dictionary = telemetry_value
	if not _dictionary_has_exact_keys(telemetry, [
		"stage_run_uid", "difficulty", "stage_tick", "event_sequence", "event_id", "route_state_before", "route_state_after", "transition_reason", "group_index", "settled_group_count", "published_price", "expected_target_spawn_id", "defeated_spawn_id", "kill_tick", "kill_event_sequence", "player_center_x", "current_lane_id", "lane_state_before_kill", "killed_flag", "affected_lane_ids", "topology_revision_id", "reachable_lane_graph", "required_bullet_uid", "bullet_uid", "bullet_source_spawn_id", "bullet_spawn_tick", "first_reflection_tick", "reflection_count_before_graze", "graze_tick", "duplicate_graze_ignored", "selected_mirror_spawn_id", "surviving_mirror_spawn_id", "mirror_spawn_side", "mirror_geometric_axis", "mirror_transform_id", "source_lane_id", "mapped_lane_id", "selected_mirror_kill_tick", "surviving_mirror_kill_tick", "surviving_mirror_kill_event_sequence", "abacus_kill_tick", "abacus_kill_event_sequence", "first_kill_role", "mirror_activation_mask", "center_lane_preserved", "price_page_tick", "current_price", "precommit_tick", "final_open_lane_id", "last_surviving_booth_node_id", "final_lane_cross_lane_id", "final_lane_cross_tick", "boss_gate_open_tick", "point_value_multiplier_before", "point_value_multiplier_after", "seal_item_id", "seal_spawn_count", "invalidation_reason",
	]): return _contract_validation_failure("telemetry keys")
	var expected_telemetry_value: Variant = JSON.parse_string(FROZEN_TELEMETRY_FIELDS_JSON)
	if not (expected_telemetry_value is Dictionary) or not _matches_contract_projection(telemetry, expected_telemetry_value): return _contract_validation_failure("telemetry projection")
	if not _matches_contract_projection(contract.get("drop_aliases"), DROP_ALIASES):
		return _contract_validation_failure("drop aliases")
	if not _validate_contract_teaching_and_publication(contract):
		return _contract_validation_failure("teaching and publication")
	if not _validate_contract_topology(contract):
		return _contract_validation_failure("topology")
	if not _validate_contract_groups(contract):
		return _contract_validation_failure("groups")
	if not _validate_contract_state_machine(contract):
		return _contract_validation_failure("state machine")
	if not _validate_contract_invariants(contract):
		return _contract_validation_failure("invariants")
	return true

func _contract_validation_failure(section: String) -> bool:
	_last_error = "approved Stage 2 score-route contract validation failed: %s" % section
	return false

func _validate_contract_teaching_and_publication(contract: Dictionary) -> bool:
	var expected_teaching := {
		"classification": "instruction_only", "entry_event_id": "s2_b01", "exit_event_id": "s2_b06", "route_state": "teaching_only",
		"resolved_hooks": [
			{"event_id": "s2_b01", "spawn_ids": ["s2_b01_abacus_left", "s2_b01_abacus_center", "s2_b01_abacus_right"], "hooks": ["rebound_graze_uid", "price_chain_group_1"], "resolution": "Record rebound UID deduplication and teaching marker 1 only."},
			{"event_id": "s2_b02", "spawn_ids": ["s2_b02_left_clerk", "s2_b02_center_clerk", "s2_b02_right_clerk"], "hooks": ["rebound_graze_uid", "m_route_cross"], "resolution": "Record a non-scoring rebound-and-cross rehearsal only."},
			{"event_id": "s2_b03", "spawn_ids": ["s2_b03_red_ledger", "s2_b03_blue_ledger"], "hooks": ["kill_order", "price_chain_group_2"], "resolution": "Record the red-before-blue teaching marker only."},
			{"event_id": "s2_b04", "spawn_ids": ["s2_b04_left_booth_edge", "s2_b04_right_booth_edge"], "hooks": ["booth_lane_state", "center_lane_entry"], "resolution": "Record lane-state recognition only."},
			{"event_id": "s2_b05", "spawn_ids": ["s2_b05_left_bead_seller", "s2_b05_right_bead_seller"], "hooks": ["rebound_graze_uid", "price_chain_group_3"], "resolution": "Record teaching marker 3 only, then discard all teaching markers at s2_b06."},
		],
		"post_midboss_effect": {"settled_group_count_delta": 0, "point_value_multiplier_delta": 0.0, "seal_spawn_count": 0, "carry_graze_uids_forward": false},
		"isolation_reason": "The teaching events never publish a complete three-price red-blue-yellow target set: s2_b03 contains only red and blue ledgers, while s2_b05 contains bead sellers. Therefore their group-numbered hooks cannot satisfy the final post-midboss predicate.",
	}
	var expected_published := {
		"publication_event_id": "s2_b12", "publication_completion_condition": "three_flags_visible_and_midboss_exit_clear_complete", "arm_no_later_than_tick": 1794, "strict_price_direction": "high_to_low",
		"entries": [
		{"order_index": 1, "color": "red", "posted_price": 3, "publication_spawn_id": "s2_b12_red_flag_runner", "price_alias": "price_token_3", "target_event_id": "s2_b13", "target_spawn_id": "s2_b13_red_booth_master", "target_enemy_id": "booth_master_red"},
		{"order_index": 2, "color": "blue", "posted_price": 2, "publication_spawn_id": "s2_b12_blue_flag_runner", "price_alias": "price_token_2", "target_event_id": "s2_b13", "target_spawn_id": "s2_b13_blue_booth_master", "target_enemy_id": "booth_master_blue"},
		{"order_index": 3, "color": "yellow", "posted_price": 1, "publication_spawn_id": "s2_b12_yellow_flag_runner", "price_alias": "price_token_1", "target_event_id": "s2_b13", "target_spawn_id": "s2_b13_yellow_booth_master", "target_enemy_id": "booth_master_yellow"},
		],
	}
	return _matches_contract_projection(contract.get("teaching_sequence"), expected_teaching) and _matches_contract_projection(contract.get("published_order"), expected_published)

func _validate_contract_topology(contract: Dictionary) -> bool:
	var topology_value: Variant = contract.get("stage_front_topology")
	if not (topology_value is Dictionary): return false
	var topology: Dictionary = topology_value
	var projection := {
		"topology_version": 1,
		"node_id_namespace": "stage_front_route_node",
		"nodes": [
			{"node_id": "lane_left", "kind": "lane"},
			{"node_id": "lane_center", "kind": "lane"},
			{"node_id": "lane_right", "kind": "lane"},
			{"node_id": "booth_red", "kind": "booth_target", "source_spawn_id": "s2_b13_red_booth_master"},
			{"node_id": "booth_blue", "kind": "booth_target", "source_spawn_id": "s2_b13_blue_booth_master"},
			{"node_id": "booth_yellow", "kind": "booth_target", "source_spawn_id": "s2_b13_yellow_booth_master"},
			{"node_id": "mirror_left", "kind": "mirror", "source_spawn_id": "s2_b15_left_mirror"},
			{"node_id": "mirror_right", "kind": "mirror", "source_spawn_id": "s2_b15_right_mirror"},
			{"node_id": "abacus_center", "kind": "recovery_enemy", "source_spawn_id": "s2_b16_abacus_keeper"},
			{"node_id": "boss_gate", "kind": "stage_front_exit", "source_event_id": "s2_b18"},
		],
		"edge_contract": {
			"encoding": "Each directed edge is a unique two-string array [from_node_id, to_node_id].",
			"graph_semantics": "Only listed active edges exist. Removing a missing edge or adding an existing edge is a contract error unless the operation explicitly removes then re-adds that same edge.",
			"reachability_algorithm": "Run breadth-first search over outgoing directed edges in lexicographic to_node_id order. A zero-edge path makes a node reachable from itself. Inactive enemy nodes and their incident edges are excluded.",
			"normal_projection": "Normal applies the same node activation, target removal, mirror mapping, and final-gate operations, but treats every active lane-to-lane edge as traversable in both directions during reachability. Enemy attachment edges remain directed.",
			"hard_projection": "Hard uses the directed edges exactly as listed and applies every ordered transform below.",
		},
		"coordinate_contract": {
			"sample_point": "player collision-center x at the callback being evaluated",
			"combat_x_min": 24,
			"combat_x_max": 696,
			"out_of_bounds_rule": "Clamp player_center_x to the inclusive range 24 through 696 before deriving a lane.",
			"lane_partitions": [
				{"lane_id": "lane_left", "minimum_x_inclusive": 24, "maximum_x_exclusive": 248},
				{"lane_id": "lane_center", "minimum_x_inclusive": 248, "maximum_x_exclusive": 472},
				{"lane_id": "lane_right", "minimum_x_inclusive": 472, "maximum_x_inclusive": 696},
			],
			"current_lane_algorithm": "After clamping, return lane_left when x is less than 248, lane_center when x is less than 472, otherwise lane_right.",
			"checkpoint_samples": {
				"group_1": "sample at the s2_b13_red_booth_master defeat callback before applying the red-kill transform",
				"group_2": "sample at the s2_b13_blue_booth_master defeat callback after the red-kill transform and before applying the blue-kill transform",
				"mirror_choice": "sample at the selected s2_b15 mirror defeat callback before applying its mirror transform",
				"group_3_target": "sample at the s2_b13_yellow_booth_master defeat callback after the selected mirror transform and before applying the yellow-kill transform",
				"final_cross": "derive the crossing lane from the same x partition at final_lane_cross_tick",
			},
		},
		"transform_callback_order": [
			"Derive current_lane_id from player_center_x using the checkpoint rule.",
			"Evaluate and latch the applicable pre-transform reachability predicate against topology_revision_id.",
			"Apply the declared remove_edges and add_edges exactly once, then emit the new topology_revision_id and reachable_lane_graph.",
			"Evaluate group settlement using the latched topology result plus the other group predicates. A later graze callback may complete a group, but it cannot resample or rewrite the topology result captured at the target defeat callback.",
		],
		"initial_graph": {"revision_id": "stage_front_initial", "activation_event_id": "s2_b13", "directed_edges": INITIAL_EDGES},
		"neighbor_kill_transforms": {
			"red_kill": {"trigger_event_id": "s2_b13", "trigger_spawn_id": "s2_b13_red_booth_master", "input_revision_id": "stage_front_initial", "killed_flag": "red", "killed_lane_id": "lane_left", "affected_lane_ids": ["lane_left", "lane_center"], "remove_edges": [["lane_left", "lane_center"], ["lane_left", "booth_red"], ["lane_center", "booth_red"], ["lane_right", "booth_red"]], "add_edges": [["lane_center", "lane_left"]], "output_revision_id": "stage_front_after_red_neighbor_flip", "output_directed_edges": AFTER_RED_EDGES},
			"blue_kill": {"trigger_event_id": "s2_b14", "trigger_spawn_id": "s2_b13_blue_booth_master", "input_revision_id": "stage_front_after_red_neighbor_flip", "killed_flag": "blue", "killed_lane_id": "lane_center", "affected_lane_ids": ["lane_center", "lane_right"], "remove_edges": [["lane_center", "lane_right"], ["lane_center", "booth_blue"]], "add_edges": [["lane_right", "lane_center"]], "output_revision_id": "stage_front_after_blue_neighbor_flip", "output_directed_edges": AFTER_BLUE_EDGES},
		},
		"mirror_transform_table": [
			{"selected_spawn_id": "s2_b15_left_mirror", "surviving_spawn_id": "s2_b15_right_mirror", "token_alias": "mirror_token_left", "spawn_side": "left", "spawn_x": 228, "geometric_axis": "horizontal", "geometric_transform_id": "horizontal_left_to_right_once", "source_routing_id": "horizontal_mirror_to_right_lane_once", "source_lane_id": "lane_left", "mapped_lane_id": "lane_right"},
			{"selected_spawn_id": "s2_b15_right_mirror", "surviving_spawn_id": "s2_b15_left_mirror", "token_alias": "mirror_token_right", "spawn_side": "right", "spawn_x": 492, "geometric_axis": "diagonal_down_left", "geometric_transform_id": "diagonal_right_to_left_after_delay", "source_routing_id": "diagonal_mirror_to_left_lane_after_delay", "source_lane_id": "lane_right", "mapped_lane_id": "lane_left"},
		],
		"mirror_graph_transform": {
			"activation_event_id": "s2_b15",
			"input_revision_id": "stage_front_after_blue_neighbor_flip",
			"activation_add_edges": [["lane_left", "mirror_left"], ["lane_right", "mirror_right"]],
			"selection_precondition": "Before defeating the selected mirror, current_lane_id must reach that mirror's node in the activated Hard graph. Resolve the selected row from mirror_transform_table by exact selected_spawn_id.",
			"selection_operations": [
				"Remove the edge from the selected row's source_lane_id to its selected mirror node.",
				"Remove [lane_right, booth_yellow].",
				"Add [source_lane_id, mapped_lane_id].",
				"Add [mapped_lane_id, booth_yellow].",
				"Leave the other mirror attachment active; that other spawn is surviving_spawn_id for the s2_b16 order comparison.",
			],
			"output_by_selected_spawn_id": {
				"s2_b15_left_mirror": {"revision_id": "stage_front_after_left_horizontal_transform", "directed_edges": MIRROR_EDGES["s2_b15_left_mirror"]},
				"s2_b15_right_mirror": {"revision_id": "stage_front_after_right_diagonal_transform", "directed_edges": MIRROR_EDGES["s2_b15_right_mirror"]},
			},
		},
		"abacus_activation": {
			"event_id": "s2_b16", "spawn_id": "s2_b16_abacus_keeper", "add_edge": ["lane_center", "abacus_center"],
			"center_lane_preserved_algorithm": "At the abacus defeat callback, center_lane_preserved is true exactly when lane_center has at least one active incoming or outgoing lane-to-lane edge. Enemy attachment edges do not count.",
			"defeat_cleanup": "Remove [lane_center, abacus_center] when the abacus keeper is defeated. Remove the surviving mirror attachment when surviving_mirror_spawn_id is defeated.",
		},
		"final_open_lane_algorithm": {
			"trigger_event_id": "s2_b17",
			"target_spawn_id": "s2_b13_yellow_booth_master",
			"precondition": "Immediately before the yellow defeat, the defeated booth set is exactly red and blue, so booth_yellow is the last surviving booth node, and current_lane_id reaches booth_yellow in the selected mirror graph.",
			"steps": [
				"Resolve the selected mirror row by selected_mirror_spawn_id.",
				"Set final_open_lane_id to that row's mapped_lane_id.",
				"Require the active edge [final_open_lane_id, booth_yellow].",
				"Remove [final_open_lane_id, booth_yellow] when yellow is defeated.",
				"Add [final_open_lane_id, boss_gate].",
				"Freeze final_open_lane_id through s2_b18; it cannot be recomputed from later player movement.",
			],
			"result_by_selected_spawn_id": {
				"s2_b15_left_mirror": {"final_open_lane_id": "lane_right", "final_gate_edge": ["lane_right", "boss_gate"], "final_directed_edges": FINAL_EDGES["s2_b15_left_mirror"]},
				"s2_b15_right_mirror": {"final_open_lane_id": "lane_left", "final_gate_edge": ["lane_left", "boss_gate"], "final_directed_edges": FINAL_EDGES["s2_b15_right_mirror"]},
			},
		},
		"hard_predicate_algorithms": {
			"hard_current_lane_to_red_booth_edge_exists": "In stage_front_initial, derive current_lane_id at the red defeat callback and require directed reachability to booth_red before applying red_kill.",
			"hard_neighbor_flag_edge_reachable": "In stage_front_after_red_neighbor_flip, derive current_lane_id at the blue defeat callback and require directed reachability to booth_blue before applying blue_kill.",
			"hard_selected_transform_to_final_gate_reachable": "At mirror choice require current_lane_id to reach the selected mirror node in the activated graph; after applying its exact table row require mapped_lane_id to reach booth_yellow; after the yellow transform require the literal edge [final_open_lane_id, boss_gate] and require the s2_b18 crossing lane to equal final_open_lane_id.",
		},
	}
	return _matches_contract_projection(topology, projection)

func _validate_contract_groups(contract: Dictionary) -> bool:
	var expected_groups := [
		{
			"group_index": 1, "group_id": "posted_price_3_red", "armed_state": "group_1_armed", "published_price": 3,
			"window": {"start_event_id": "s2_b13", "start_tick": 1800, "predicate_deadline_event_id": "s2_b13", "predicate_deadline_tick": 1944},
			"expected_target": {"event_id": "s2_b13", "spawn_id": "s2_b13_red_booth_master", "enemy_id": "booth_master_red"},
			"required_rebound": {"source_event_id": "s2_b13", "required_source_spawn_id": "s2_b13_blue_booth_master", "source_enemy_id": "booth_master_blue", "source_primitive": "rebound_bead", "minimum_accepted_unique_uids": 1, "maximum_accepted_unique_uids": 1},
			"order_predicate": "settled_group_count equals 0 and the first defeated booth master after arming is s2_b13_red_booth_master",
			"shared_topology_predicate": "Derive current_lane_id from player_center_x at the red defeat callback and evaluate reachability to booth_red in stage_front_initial before applying the red-kill transform.",
			"difficulty_topology_predicates": {
				"normal": {"predicate_id": "normal_red_lane_reachable", "required_state": "red_target_lane_open"},
				"hard": {"predicate_id": "hard_current_lane_to_red_booth_edge_exists", "required_state": "hard_red_target_edge_open", "non_numeric_topology_test": "Run stage_front_topology.hard_predicate_algorithms.hard_current_lane_to_red_booth_edge_exists against the canonical directed graph."},
			},
			"success_rule": "Latch the expected target defeat, one qualifying required bullet_uid, and the topology predicate in any callback order within the window; settle on the callback tick that completes the set.",
			"settlement": {"settlement_tick_rule": "earliest tick at which all group-1 predicates are latched, no later than 1944", "point_value_additive_delta": 0.25, "point_value_multiplier_after": 1.25, "seal_item_id": "night_festival_seal", "seal_spawn_count": 0, "next_state": "group_2_armed"},
			"expiry_rule": "At tick 1944 after all callbacks, transition to expired if any required predicate is absent.",
		},
		{
			"group_index": 2, "group_id": "posted_price_2_blue", "armed_state": "group_2_armed", "published_price": 2,
			"window": {"start_event_id": "s2_b14", "start_tick": 1950, "predicate_deadline_event_id": "s2_b14", "predicate_deadline_tick": 2094},
			"expected_target": {"owner_event_id": "s2_b13", "active_event_id": "s2_b14", "spawn_id": "s2_b13_blue_booth_master", "enemy_id": "booth_master_blue"},
			"required_rebound": {"source_event_id": "s2_b13", "active_event_id": "s2_b14", "required_source_spawn_id": "s2_b13_blue_booth_master", "source_enemy_id": "booth_master_blue", "source_primitive": "rebound_bead", "minimum_accepted_unique_uids": 1, "maximum_accepted_unique_uids": 1},
			"order_predicate": "settled_group_count equals 1, red is already settled, and the next defeated booth master is s2_b13_blue_booth_master",
			"shared_topology_predicate": "Apply stage_front_topology.neighbor_kill_transforms.red_kill, derive current_lane_id at the blue defeat callback, and require reachability to booth_blue before applying the blue-kill transform.",
			"difficulty_topology_predicates": {
				"normal": {"predicate_id": "normal_neighbor_state_reaches_blue_lane", "required_state": "blue_target_lane_open_after_red"},
				"hard": {"predicate_id": "hard_neighbor_flag_edge_reachable", "required_state": "neighbor_flip_graph_reaches_blue_booth", "non_numeric_topology_test": "Run stage_front_topology.hard_predicate_algorithms.hard_neighbor_flag_edge_reachable against revision stage_front_after_red_neighbor_flip."},
			},
			"success_rule": "Latch the blue defeat, one new qualifying required bullet_uid emitted at or after tick 1950, and the committed neighbor topology by tick 2094; settle on the callback tick that completes the set.",
			"settlement": {"settlement_tick_rule": "earliest tick at which all group-2 predicates are latched, no later than 2094", "point_value_additive_delta": 0.25, "point_value_multiplier_after": 1.5, "seal_item_id": "night_festival_seal", "seal_spawn_count": 0, "next_state": "group_3_armed"},
			"expiry_rule": "At tick 2094 after all callbacks, transition to expired if any required predicate is absent.",
		},
		{
			"group_index": 3, "group_id": "posted_price_1_yellow_final", "armed_state": "group_3_armed", "published_price": 1,
			"window": {"start_event_id": "s2_b15", "start_tick": 2100, "mirror_choice_deadline_event_id": "s2_b15", "mirror_choice_deadline_tick": 2244, "recovery_deadline_event_id": "s2_b16", "recovery_deadline_tick": 2394, "predicate_deadline_event_id": "s2_b17", "predicate_deadline_tick": 2544, "final_cross_event_id": "s2_b18", "final_cross_start_tick": 2550, "final_cross_deadline_tick": 2700},
			"expected_target": {"owner_event_id": "s2_b13", "settlement_event_id": "s2_b18", "spawn_id": "s2_b13_yellow_booth_master", "enemy_id": "booth_master_yellow"},
			"mirror_choice": {
				"event_id": "s2_b15", "allowed_spawn_ids": MIRROR_SPAWNS, "enemy_id": "water_mirror_yokai",
				"predicate": "Exactly one allowed mirror is defeated by tick 2244. Resolve its exact mirror_transform_table row and freeze selected_mirror_spawn_id, surviving_mirror_spawn_id, mirror_spawn_side, mirror_geometric_axis, mirror_transform_id, source_lane_id, mapped_lane_id, and activation_tick.",
			},
			"mirror_before_abacus_recovery": {
				"event_id": "s2_b16", "abacus_spawn_id": "s2_b16_abacus_keeper", "abacus_enemy_id": "closing_abacus_keeper",
				"predicate": "The selected mirror was already defeated during s2_b15. At s2_b16 entry, compare the still-alive surviving_mirror_spawn_id from the frozen transform row against s2_b16_abacus_keeper: the surviving mirror defeat must precede the abacus keeper defeat in total event order, first_kill_role must equal surviving_mirror, and center_lane_preserved must be true by tick 2394.",
				"reachable_success_order": ["selected s2_b15 mirror defeated and route committed by tick 2244", "other s2_b15 mirror remains alive as surviving_mirror_spawn_id at tick 2250", "surviving_mirror_spawn_id defeated during s2_b16", "s2_b16_abacus_keeper defeated after the surviving mirror"],
				"gameplay_fallback_is_not_score_success": "At tick 2250 both surviving_mirror_spawn_id and s2_b16_abacus_keeper are alive. Defeating the abacus keeper before that surviving mirror is therefore a reachable recoverable outer-route fallback, but it invalidates this score chain.",
			},
			"required_rebound": {"source_event_id": "s2_b16", "required_source_spawn_id": "s2_b16_abacus_keeper", "source_enemy_id": "closing_abacus_keeper", "source_primitive": "rebound_bead", "minimum_accepted_unique_uids": 1, "maximum_accepted_unique_uids": 1},
			"order_predicate": "settled_group_count equals 2, red and blue are settled, and the next defeated booth master is s2_b13_yellow_booth_master by tick 2544",
			"shared_topology_predicate": "Resolve and apply the exact selected mirror table row, replace the yellow booth attachment with [mapped_lane_id, booth_yellow], verify yellow is the last surviving booth, then compute and freeze final_open_lane_id with stage_front_topology.final_open_lane_algorithm.",
			"difficulty_topology_predicates": {
				"normal": {"predicate_id": "normal_selected_mirror_maps_to_open_lane", "required_state": "mapped_lane_id_equals_final_open_lane_id_under_undirected_lane_projection"},
				"hard": {"predicate_id": "hard_selected_transform_to_final_gate_reachable", "required_state": "selected_mirror_transform_graph_reaches_yellow_then_final_gate", "non_numeric_topology_test": "Run stage_front_topology.hard_predicate_algorithms.hard_selected_transform_to_final_gate_reachable with the selected mirror table row and exact directed graph revisions."},
			},
			"precommit_rule": "By tick 2544, latch exactly one selected mirror and its surviving counterpart, surviving-mirror-before-abacus recovery, one qualifying abacus bullet_uid, yellow as the third booth defeat, and the applicable computable topology predicate; then freeze final_open_lane_id in group_3_pending_final_cross.",
			"success_rule": "While group_3_pending_final_cross, accept exactly one crossing of final_open_lane_id during s2_b18 ticks 2550 through 2700. The crossing callback is the group-3 settlement tick.",
			"settlement": {
				"settlement_tick_rule": "final_lane_cross_tick in the inclusive range 2550 through 2700 after all preconditions were frozen by tick 2544", "point_value_additive_delta": 0.25, "point_value_multiplier_after": 1.75, "seal_item_id": "night_festival_seal", "seal_spawn_count": 1,
				"atomic_effects": ["increment settled_group_count from 2 to 3", "set point_value_multiplier from 1.50 to 1.75", "spawn exactly one canonical night_festival_seal", "transition to complete"], "next_state": "complete",
			},
			"expiry_rule": "Expire at tick 2544 if preconditions are incomplete, or at tick 2700 if the preconditions are frozen but no valid final open-lane crossing occurred.",
		},
	]
	return _matches_contract_projection(contract.get("groups"), expected_groups)

func _validate_contract_invariants(contract: Dictionary) -> bool:
	var expected := [
		{"invariant_id": "source_referential_integrity", "rule": "Every event, spawn, enemy, and canonical item ID in this contract is present in m2_stage2_choreography.json or GameDatabase."},
		{"invariant_id": "teaching_isolation", "rule": "s2_b01 through s2_b05 can never arm, increment, or complete the post-midboss chain; all teaching markers and teaching graze UIDs are cleared at s2_b06."},
		{"invariant_id": "strict_published_order", "rule": "The only successful booth order is s2_b13_red_booth_master, then s2_b13_blue_booth_master, then s2_b13_yellow_booth_master, corresponding exactly to prices 3, 2, 1."},
		{"invariant_id": "finite_single_pass_state_machine", "rule": "A group can settle at most once per stage_run_uid, terminal states cannot rearm, and there is no retry before a stage restart creates a new stage_run_uid."},
		{"invariant_id": "required_rebound_uid_uniqueness", "rule": "Exactly one selected rebound bullet_uid must qualify in each successful group; each UID contributes at most once globally and must have reflection_count_before_graze at least 1."},
		{"invariant_id": "point_value_additive_progression", "rule": "The canonical point item value multiplier is 1.00, 1.25, 1.50, then 1.75 after zero, one, two, then three settled groups. The three 25% deltas are additive, not compounded, and never affect power or route tokens."},
		{"invariant_id": "earned_group_rewards_do_not_rollback", "rule": "Invalidation or expiry blocks future settlements but does not reverse multipliers from groups that already settled."},
		{"invariant_id": "seal_exactly_once", "rule": "Groups 1 and 2 spawn zero seals. Group 3 and the route complete transition are one atomic callback that spawns exactly one canonical night_festival_seal; duplicate callbacks spawn zero additional seals."},
		{"invariant_id": "drop_alias_canonical_whitelist", "rule": "Resource-producing aliases resolve only to canonical power or point. The sole route reward uses canonical night_festival_seal. No alias resolves to bomb_fragment, life_fragment, or full_power."},
		{"invariant_id": "route_tokens_are_non_resource", "rule": "mirror_token_left, mirror_token_right, and price_token_1 through price_token_3 are route-local metadata and never enter persistent inventory or invoke item collection rewards."},
		{"invariant_id": "normal_hard_scoring_fairness", "rule": "Normal and Hard use identical target order, tick deadlines, one selected rebound UID per group, additive point multipliers, and exactly-one-seal reward."},
		{"invariant_id": "hard_topology_is_stateful_not_numeric", "rule": "Hard success additionally evaluates the computable directed-graph predicates hard_current_lane_to_red_booth_edge_exists, hard_neighbor_flag_edge_reachable, and hard_selected_transform_to_final_gate_reachable; bullet count, speed, and numeric thresholds do not substitute for these topology predicates."},
		{"invariant_id": "topology_reconstruction_is_deterministic", "rule": "Given player_center_x, selected_mirror_spawn_id, and the ordered defeat callbacks, a runtime must reconstruct exactly one topology revision from stage_front_initial through the declared red, blue, mirror, and yellow transforms without inventing nodes or edges."},
		{"invariant_id": "mirror_side_axis_mapping_is_exact", "rule": "s2_b15_left_mirror is spawn side left with horizontal_left_to_right_once from lane_left to lane_right; s2_b15_right_mirror is spawn side right with diagonal_right_to_left_after_delay from lane_right to lane_left. Spawn side, geometric axis, transform ID, source lane, and mapped lane are distinct fields and must match mirror_transform_table."},
		{"invariant_id": "abacus_fallback_compares_surviving_mirror", "rule": "selected_mirror_spawn_id is defeated during s2_b15. The s2_b16 success/fallback order compares s2_b16_abacus_keeper only with the other still-alive surviving_mirror_spawn_id; surviving mirror then abacus is score success, while abacus then surviving mirror is the reachable gameplay-only fallback."},
		{"invariant_id": "gameplay_fallback_not_score_success", "rule": "The s2_b16 recoverable outer route and the s2_b18 wrong-order outer crossing may continue gameplay but can never settle a score group or spawn the route seal."},
		{"invariant_id": "no_unstated_miss_or_bomb_condition", "rule": "Player death, bomb use, and ordinary non-route grazes do not invalidate this route because the source choreography defines no such score hook."},
	]
	return _matches_contract_projection(contract.get("invariants"), expected)

func _validate_contract_state_machine(contract: Dictionary) -> bool:
	var expected_states := [
		{"state_id": "inactive", "meaning": "No Stage 2 score route state has been allocated for this stage run.", "allowed_next_states": ["teaching_only"]},
		{"state_id": "teaching_only", "meaning": "s2_b01 through s2_b05 may emit rehearsal telemetry but cannot settle rewards.", "allowed_next_states": ["awaiting_publication"]},
		{"state_id": "awaiting_publication", "meaning": "Teaching state has been cleared at s2_b06; wait for the exact s2_b12 price mapping.", "allowed_next_states": ["group_1_armed", "expired"]},
		{"state_id": "group_1_armed", "meaning": "Only the red price-3 booth target may settle next.", "allowed_next_states": ["group_2_armed", "invalidated", "expired"]},
		{"state_id": "group_2_armed", "meaning": "Only the blue price-2 booth target may settle next after the neighbor-lane state commits.", "allowed_next_states": ["group_3_armed", "invalidated", "expired"]},
		{"state_id": "group_3_armed", "meaning": "The mirror-before-abacus recovery, yellow price-1 target, rebound graze, and topology predicates must all latch by the price countdown deadline.", "allowed_next_states": ["group_3_pending_final_cross", "invalidated", "expired"]},
		{"state_id": "group_3_pending_final_cross", "meaning": "All group-3 preconditions are frozen; only the s2_b18 final open-lane crossing may commit the route.", "allowed_next_states": ["complete", "invalidated", "expired"]},
		{"state_id": "complete", "meaning": "All three groups are settled and the single seal settlement is closed for this stage run.", "terminal": true},
		{"state_id": "invalidated", "meaning": "An explicit wrong action broke the chain. Earned earlier group multipliers remain, but no later group or seal may settle.", "terminal": true},
		{"state_id": "expired", "meaning": "A required predicate missed its finite deadline. Earned earlier group multipliers remain, but no later group or seal may settle.", "terminal": true},
	]
	var expected_transitions := [
		{"from": "inactive", "to": "teaching_only", "event_id": "s2_b01", "tick": 0, "condition": "stage_run_uid is allocated"},
		{"from": "teaching_only", "to": "awaiting_publication", "event_id": "s2_b06", "condition": "midboss gate entry clears all teaching markers and teaching graze UIDs"},
		{"from": "awaiting_publication", "to": "group_1_armed", "event_id": "s2_b12", "condition": "publication completion is observed by tick 1794 and the exact 3-2-1 mapping matches published_order"},
		{"from": "group_1_armed", "to": "group_2_armed", "event_id": "s2_b13", "condition": "group 1 settles"},
		{"from": "group_2_armed", "to": "group_3_armed", "event_id": "s2_b14", "condition": "group 2 settles"},
		{"from": "group_3_armed", "to": "group_3_pending_final_cross", "event_id": "s2_b17", "condition": "all group-3 preconditions latch no later than tick 2544"},
		{"from": "group_3_pending_final_cross", "to": "complete", "event_id": "s2_b18", "condition": "the final open lane is crossed during ticks 2550 through 2700 and group 3 settles atomically"},
	]
	var expected_reasons := [
		{"reason_id": "publication_mismatch", "terminal_state": "expired", "condition": "s2_b12 is incomplete at tick 1794 or does not publish red=3, blue=2, yellow=1", "reward_behavior": "no group reward and no seal"},
		{"reason_id": "wrong_booth_order", "terminal_state": "invalidated", "condition": "a booth master other than the currently expected red, blue, or yellow target is defeated while a group is armed", "reward_behavior": "retain already-settled multipliers; block all later settlements and the seal"},
		{"reason_id": "required_rebound_graze_missing", "terminal_state": "expired", "condition": "the selected required bullet_uid has no qualifying post-reflection graze by its group predicate deadline", "reward_behavior": "retain already-settled multipliers; block all later settlements and the seal"},
		{"reason_id": "topology_predicate_failed", "terminal_state": "invalidated", "condition": "the applicable Normal or Hard lane/graph state is false when its target settlement is evaluated", "reward_behavior": "retain already-settled multipliers; block all later settlements and the seal"},
		{"reason_id": "mirror_choice_ambiguous", "terminal_state": "invalidated", "condition": "both s2_b15 mirrors are selected as the score route, or the selected mapping changes after it is frozen", "reward_behavior": "block group 3 and the seal"},
		{"reason_id": "mirror_choice_expired", "terminal_state": "expired", "condition": "no s2_b15 mirror is selected by tick 2244", "reward_behavior": "block group 3 and the seal"},
		{"reason_id": "abacus_before_surviving_mirror", "terminal_state": "invalidated", "condition": "After selected_mirror_spawn_id was defeated and frozen during s2_b15, s2_b16_abacus_keeper is defeated before the still-alive surviving_mirror_spawn_id in total event order during s2_b16.", "reward_behavior": "allow the choreography's gameplay fallback, but block group 3 and the seal"},
		{"reason_id": "price_countdown_expired", "terminal_state": "expired", "condition": "all group-3 preconditions are not frozen by tick 2544", "reward_behavior": "retain group-1 and group-2 multipliers; block group 3 and the seal"},
		{"reason_id": "final_lane_cross_expired", "terminal_state": "expired", "condition": "no qualifying final_open_lane_id crossing occurs by tick 2700", "reward_behavior": "retain group-1 and group-2 multipliers; block group 3 and the seal"},
		{"reason_id": "wrong_final_lane_cross", "terminal_state": "invalidated", "condition": "a lane other than final_open_lane_id is used as the s2_b18 settlement crossing while group_3_pending_final_cross", "reward_behavior": "allow the choreography's wrong-order outer-route fallback, but block group 3 and the seal"},
		{"reason_id": "duplicate_transition_callback", "terminal_state": "unchanged", "condition": "an already-consumed idempotency key or bullet_uid callback is received again", "reward_behavior": "ignore the duplicate, emit telemetry, and do not duplicate any reward"},
	]
	return _matches_contract_projection(contract.get("route_states"), expected_states) and _matches_contract_projection(contract.get("state_transitions"), expected_transitions) and _matches_contract_projection(contract.get("invalidation_reasons"), expected_reasons)

func _matches_contract_projection(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not (actual is Dictionary): return false
		var actual_dictionary: Dictionary = actual
		var expected_dictionary: Dictionary = expected
		if not _dictionary_has_exact_keys(actual_dictionary, expected_dictionary.keys()): return false
		for key in expected_dictionary:
			if not actual_dictionary.has(key) or not _matches_contract_projection(actual_dictionary[key], expected_dictionary[key]): return false
		return true
	if expected is Array:
		if not (actual is Array): return false
		var actual_array: Array = actual
		var expected_array: Array = expected
		if actual_array.size() != expected_array.size(): return false
		for index in range(expected_array.size()):
			if not _matches_contract_projection(actual_array[index], expected_array[index]): return false
		return true
	if typeof(expected) in [TYPE_INT, TYPE_FLOAT] and typeof(actual) in [TYPE_INT, TYPE_FLOAT]:
		return float(actual) == float(expected)
	return typeof(actual) == typeof(expected) and actual == expected

func _dictionary_has_exact_keys(dictionary: Dictionary, expected_keys_value: Array) -> bool:
	var actual_keys: Array = dictionary.keys()
	var expected_keys: Array = expected_keys_value.duplicate()
	actual_keys.sort()
	expected_keys.sort()
	return actual_keys == expected_keys

func _validate_snapshot(snapshot: Dictionary) -> bool:
	var keys: Array = snapshot.keys()
	keys.sort()
	var expected_keys: Array = SNAPSHOT_KEYS.duplicate()
	expected_keys.sort()
	if keys != expected_keys or not _configured or not _snapshot_shapes_are_valid(snapshot):
		return false
	if snapshot.get("version") != SNAPSHOT_VERSION or snapshot.get("artifact_id") != ARTIFACT_ID or snapshot.get("stage_id") != STAGE_ID:
		return false
	if snapshot.get("configured") != true or snapshot.get("difficulty") != _difficulty or snapshot.get("stage_run_uid") != _stage_run_uid:
		return false
	var state := String(snapshot.get("route_state", ""))
	var count := int(snapshot.get("settled_group_count", -1))
	if state not in STATES or count < 0 or count > 3 or float(snapshot.get("point_value_multiplier", 0.0)) != 1.0 + 0.25 * count:
		return false
	if int(snapshot.get("last_stage_tick", -2)) < -1 or int(snapshot.get("last_event_sequence", -2)) < -1:
		return false
	if (int(snapshot.get("last_stage_tick")) == -1) != (int(snapshot.get("last_event_sequence")) == -1):
		return false
	if int(snapshot.get("last_event_sequence")) >= 0 and String(snapshot.get("last_callback_signature")).is_empty():
		return false
	if int(snapshot.get("last_event_sequence")) == -1 and not String(snapshot.get("last_callback_signature")).is_empty():
		return false
	if not _snapshot_callback_record_is_valid(snapshot): return false
	var records: Array = snapshot.get("settlement_records", [])
	if records.size() != count:
		return false
	for index in range(records.size()):
		var record_value: Variant = records[index]
		if not (record_value is Dictionary): return false
		var record: Dictionary = record_value
		var record_keys := ["difficulty", "event_sequence", "group_index", "point_item_additive_delta", "point_value_multiplier_after", "point_value_multiplier_before", "seal_item_id", "seal_spawn_count", "stage_run_uid", "stage_tick", "transition"]
		if index == 2: record_keys.append_array(["boss_gate_open_tick", "final_lane_cross_lane_id", "final_lane_cross_tick"])
		if not _dictionary_has_exact_keys(record, record_keys): return false
		for string_key in ["stage_run_uid", "difficulty", "transition", "seal_item_id"]:
			if typeof(record.get(string_key)) != TYPE_STRING: return false
		for int_key in ["group_index", "stage_tick", "event_sequence", "seal_spawn_count"]:
			if typeof(record.get(int_key)) != TYPE_INT: return false
		for float_key in ["point_item_additive_delta", "point_value_multiplier_before", "point_value_multiplier_after"]:
			if typeof(record.get(float_key)) != TYPE_FLOAT: return false
		if int(record.get("group_index", 0)) != index + 1 or String(record.get("stage_run_uid", "")) != _stage_run_uid:
			return false
		if String(record.get("difficulty", "")) != _difficulty or String(record.get("transition", "")) != "group_%d_settlement" % (index + 1): return false
		if float(record.get("point_item_additive_delta", 0.0)) != 0.25: return false
		if float(record.get("point_value_multiplier_before", 0.0)) != 1.0 + 0.25 * index: return false
		if float(record.get("point_value_multiplier_after", 0.0)) != 1.0 + 0.25 * (index + 1): return false
		if String(record.get("seal_item_id", "")) != "night_festival_seal" or int(record.get("seal_spawn_count", -1)) != (1 if index == 2 else 0): return false
		var settlement_tick := int(record.get("stage_tick", -1))
		var settlement_sequence := int(record.get("event_sequence", -1))
		var window_min: int = [1800, 1950, 2550][index]
		var window_max: int = [1944, 2094, 2700][index]
		if settlement_tick < window_min or settlement_tick > window_max or settlement_sequence < 0: return false
		if not _order_not_after(settlement_tick, settlement_sequence, int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
		if index > 0:
			var previous: Dictionary = records[index - 1]
			if not _order_precedes(int(previous.get("stage_tick")), int(previous.get("event_sequence")), settlement_tick, settlement_sequence): return false
		if index == 2:
			if typeof(record.get("final_lane_cross_tick")) != TYPE_INT or typeof(record.get("final_lane_cross_lane_id")) != TYPE_STRING: return false
			if record.get("final_lane_cross_tick") != settlement_tick or record.get("final_lane_cross_lane_id") != snapshot.get("final_open_lane_id"): return false
			if typeof(record.get("boss_gate_open_tick")) != TYPE_INT or int(record.get("boss_gate_open_tick")) < 0 or int(record.get("boss_gate_open_tick")) > settlement_tick: return false
	var consumed: Array = snapshot.get("consumed_transition_keys", [])
	if consumed.size() != records.size(): return false
	for index in range(records.size()):
		if typeof(consumed[index]) != TYPE_STRING: return false
		if consumed[index] != "%s:%d:settle" % [_stage_run_uid, index + 1]: return false
	var selected: Dictionary = snapshot.get("selected_mirror", {})
	if not selected.is_empty():
		var selected_id := String(selected.get("selected_spawn_id", ""))
		if not MIRROR_ROWS.has(selected_id) or selected != MIRROR_ROWS[selected_id]: return false
		if snapshot.get("final_open_lane_id") not in ["", selected.get("mapped_lane_id")]: return false
		if int(snapshot.get("selected_mirror_kill_tick")) < 2100 or int(snapshot.get("selected_mirror_kill_tick")) > 2244: return false
		if int(snapshot.get("selected_mirror_kill_event_sequence")) < 0: return false
		if not _order_not_after(int(snapshot.get("selected_mirror_kill_tick")), int(snapshot.get("selected_mirror_kill_event_sequence")), int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
		if int(snapshot.get("mirror_activation_mask")) != (5 if selected_id == "s2_b15_left_mirror" else 6): return false
	else:
		if int(snapshot.get("selected_mirror_kill_tick")) != -1 or int(snapshot.get("selected_mirror_kill_event_sequence")) != -1 or int(snapshot.get("mirror_activation_mask")) != 0: return false
		if not String(snapshot.get("final_open_lane_id")).is_empty(): return false
	var survivor_tick := int(snapshot.get("surviving_mirror_kill_tick"))
	var survivor_sequence := int(snapshot.get("surviving_mirror_kill_event_sequence"))
	var abacus_tick := int(snapshot.get("abacus_kill_tick"))
	var abacus_sequence := int(snapshot.get("abacus_kill_event_sequence"))
	if (survivor_tick == -1) != (survivor_sequence == -1) or (abacus_tick == -1) != (abacus_sequence == -1): return false
	if survivor_tick >= 0 and selected.is_empty(): return false
	if abacus_tick >= 0 and selected.is_empty(): return false
	if survivor_tick >= 0 and (survivor_tick < 2250 or survivor_tick > 2394): return false
	if abacus_tick >= 0 and (abacus_tick < 2250 or abacus_tick > 2394): return false
	if survivor_tick >= 0 and not _order_not_after(survivor_tick, survivor_sequence, int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
	if abacus_tick >= 0 and not _order_not_after(abacus_tick, abacus_sequence, int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
	if survivor_tick >= 0 and not _order_precedes(int(snapshot.get("selected_mirror_kill_tick")), int(snapshot.get("selected_mirror_kill_event_sequence")), survivor_tick, survivor_sequence): return false
	if abacus_tick >= 0 and not _order_precedes(int(snapshot.get("selected_mirror_kill_tick")), int(snapshot.get("selected_mirror_kill_event_sequence")), abacus_tick, abacus_sequence): return false
	var first_role := String(snapshot.get("first_kill_role"))
	if first_role not in ["", "surviving_mirror", "abacus_keeper"]: return false
	if first_role == "surviving_mirror" and survivor_tick < 0: return false
	if first_role == "abacus_keeper" and abacus_tick < 0: return false
	if bool(snapshot.get("center_lane_preserved")) and abacus_tick < 0: return false
	if bool(snapshot.get("abacus_active")) and abacus_tick >= 0: return false
	if first_role == "surviving_mirror" and abacus_tick >= 0 and not (survivor_tick < abacus_tick or survivor_tick == abacus_tick and survivor_sequence < abacus_sequence): return false
	if first_role == "abacus_keeper" and survivor_tick >= 0 and not (abacus_tick < survivor_tick or abacus_tick == survivor_tick and abacus_sequence < survivor_sequence): return false
	var defeated: Array = snapshot.get("defeated_booth_spawn_ids", [])
	for index in range(defeated.size()):
		if index >= BOOTH_SPAWNS.size() or defeated[index] != BOOTH_SPAWNS[index]: return false
	if defeated.size() < count or defeated.size() > mini(3, count + 1): return false
	if String(snapshot.get("final_open_lane_id")).is_empty() != ("s2_b13_yellow_booth_master" not in defeated): return false
	if snapshot.get("last_surviving_booth_node_id") != ("booth_yellow" if "s2_b13_yellow_booth_master" in defeated else ""): return false
	var expected_count_by_state := {"inactive": 0, "teaching_only": 0, "awaiting_publication": 0, "group_1_armed": 0, "group_2_armed": 1, "group_3_armed": 2, "group_3_pending_final_cross": 2, "complete": 3}
	if expected_count_by_state.has(state) and count != int(expected_count_by_state[state]): return false
	if state in ["invalidated", "expired"] and count > 2: return false
	var publication: Dictionary = snapshot.get("publication", {})
	if state in ["inactive", "teaching_only", "awaiting_publication"]:
		if not publication.is_empty(): return false
	elif state not in ["expired"] or not publication.is_empty():
		if publication.get("red") != 3 or publication.get("blue") != 2 or publication.get("yellow") != 1 or typeof(publication.get("completion_tick")) != TYPE_INT or int(publication.get("completion_tick")) < 0 or int(publication.get("completion_tick")) > 1794: return false
	if state == "complete" and (count != 3 or snapshot.get("terminal_reason") != "route_complete"):
		return false
	if state in ["invalidated", "expired"] and String(snapshot.get("terminal_reason", "")).is_empty():
		return false
	if state not in TERMINAL_STATES and not String(snapshot.get("terminal_reason", "")).is_empty(): return false
	var expired_reasons := ["publication_mismatch", "required_rebound_graze_missing", "mirror_choice_expired", "price_countdown_expired", "final_lane_cross_expired"]
	var invalidated_reasons := ["wrong_booth_order", "topology_predicate_failed", "mirror_choice_ambiguous", "abacus_before_surviving_mirror", "wrong_final_lane_cross"]
	if state == "expired" and snapshot.get("terminal_reason") not in expired_reasons: return false
	if state == "invalidated" and snapshot.get("terminal_reason") not in invalidated_reasons: return false
	if state == "complete" and (selected.is_empty() or String(snapshot.get("final_open_lane_id")).is_empty()): return false
	var teaching_markers: Array = snapshot.get("teaching_markers", [])
	var teaching_uids: Array = snapshot.get("teaching_graze_uids", [])
	if state != "teaching_only" and (not teaching_markers.is_empty() or not teaching_uids.is_empty()): return false
	for marker in teaching_markers:
		if typeof(marker) != TYPE_STRING or not TEACHING_TARGETS.has(marker): return false
	for teaching_uid in teaching_uids:
		if typeof(teaching_uid) != TYPE_STRING or String(teaching_uid).strip_edges().is_empty(): return false
	if _has_duplicates(teaching_markers) or _has_duplicates(teaching_uids): return false
	var accepted: Array = snapshot.get("accepted_graze_uids", [])
	var bullets: Dictionary = snapshot.get("required_bullet_by_group", {})
	for group_key in bullets:
		if typeof(group_key) != TYPE_STRING or group_key not in ["1", "2", "3"] or typeof(bullets[group_key]) != TYPE_STRING or String(bullets[group_key]).strip_edges().is_empty(): return false
	var selected_uids: Array = bullets.values()
	var unique_selected: Array = []
	for selected_uid in selected_uids:
		if selected_uid in unique_selected: return false
		if selected_uid not in accepted: return false
		unique_selected.append(selected_uid)
	var unique_accepted: Array = []
	for accepted_uid in accepted:
		if typeof(accepted_uid) != TYPE_STRING or String(accepted_uid).strip_edges().is_empty(): return false
		if accepted_uid in unique_accepted:
			return false
		unique_accepted.append(accepted_uid)
	for uid in accepted:
		if uid not in selected_uids: return false
	if not _snapshot_emissions_are_valid(snapshot): return false
	if not _snapshot_latches_are_valid(snapshot): return false
	if not _snapshot_settlements_match_latches(snapshot): return false
	if not _snapshot_graph_is_valid(snapshot): return false
	if not _snapshot_state_graph_is_valid(snapshot): return false
	if not _snapshot_terminal_reason_is_valid(snapshot): return false
	if not _snapshot_state_window_is_valid(snapshot): return false
	return true

func _snapshot_shapes_are_valid(snapshot: Dictionary) -> bool:
	if typeof(snapshot.get("version")) != TYPE_INT or typeof(snapshot.get("configured")) != TYPE_BOOL: return false
	for key in ["difficulty", "stage_run_uid", "route_state", "last_callback_signature", "topology_revision_id", "first_kill_role", "final_open_lane_id", "last_surviving_booth_node_id", "terminal_reason"]:
		if typeof(snapshot.get(key)) != TYPE_STRING: return false
	for key in ["last_stage_tick", "last_event_sequence", "settled_group_count", "selected_mirror_kill_tick", "selected_mirror_kill_event_sequence", "surviving_mirror_kill_tick", "surviving_mirror_kill_event_sequence", "abacus_kill_tick", "abacus_kill_event_sequence", "mirror_activation_mask", "precommit_tick", "precommit_event_sequence"]:
		if typeof(snapshot.get(key)) != TYPE_INT: return false
	for key in ["configured", "center_lane_preserved", "abacus_active"]:
		if typeof(snapshot.get(key)) != TYPE_BOOL: return false
	if typeof(snapshot.get("point_value_multiplier")) != TYPE_FLOAT: return false
	for key in ["teaching_markers", "teaching_graze_uids", "active_directed_edges", "defeated_booth_spawn_ids", "accepted_graze_uids", "consumed_transition_keys", "settlement_records"]:
		if not (snapshot.get(key) is Array): return false
	for key in ["last_callback_record", "publication", "selected_mirror", "emission_registry", "required_bullet_by_group", "group_latches", "terminal_cause_record"]:
		if not (snapshot.get(key) is Dictionary): return false
	if not _edges_are_well_formed(snapshot.get("active_directed_edges")): return false
	return true

func _snapshot_graph_is_valid(snapshot: Dictionary) -> bool:
	var revision := String(snapshot.get("topology_revision_id"))
	var expected: Array = []
	if revision == "":
		expected = []
	elif revision == "stage_front_initial":
		expected = INITIAL_EDGES.duplicate(true)
	elif revision == "stage_front_after_red_neighbor_flip":
		expected = AFTER_RED_EDGES.duplicate(true)
	elif revision == "stage_front_after_blue_neighbor_flip":
		expected = AFTER_BLUE_EDGES.duplicate(true)
	elif revision in ["stage_front_after_left_horizontal_transform", "stage_front_after_right_diagonal_transform"]:
		var selected: Dictionary = snapshot.get("selected_mirror", {})
		if selected.is_empty() or revision != String(selected.get("revision_id", "")): return false
		expected = MIRROR_EDGES[String(selected.get("selected_spawn_id"))].duplicate(true)
		if int(snapshot.get("surviving_mirror_kill_tick")) >= 0:
			expected.erase(_mirror_attachment_edge(String(selected.get("surviving_spawn_id"))))
		if bool(snapshot.get("abacus_active")):
			expected.append(["lane_center", "abacus_center"])
	elif revision.begins_with("stage_front_final_gate_open_"):
		var selected: Dictionary = snapshot.get("selected_mirror", {})
		if selected.is_empty() or revision != "stage_front_final_gate_open_%s" % snapshot.get("final_open_lane_id"): return false
		expected = FINAL_EDGES[String(selected.get("selected_spawn_id"))].duplicate(true)
	else:
		return false
	return _sorted_edges(snapshot.get("active_directed_edges", [])) == _sorted_edges(expected)

func _snapshot_latches_are_valid(snapshot: Dictionary) -> bool:
	var latches: Dictionary = snapshot.get("group_latches", {})
	var defeated: Array = snapshot.get("defeated_booth_spawn_ids", [])
	var bullets: Dictionary = snapshot.get("required_bullet_by_group", {})
	var accepted: Array = snapshot.get("accepted_graze_uids", [])
	var settled_count := int(snapshot.get("settled_group_count"))
	for group_index in range(1, settled_count + 1):
		if not latches.has(str(group_index)): return false
	var state := String(snapshot.get("route_state"))
	if state in ["group_3_pending_final_cross", "complete"] and not latches.has("3"): return false
	for group_key in latches:
		if group_key not in ["1", "2", "3"] or not (latches[group_key] is Dictionary): return false
		var group_index := int(group_key)
		var latch: Dictionary = latches[group_key]
		var graze_metadata_keys := ["graze_bullet_uid", "graze_source_spawn_id", "graze_bullet_spawn_tick", "graze_bullet_spawn_event_sequence", "first_reflection_tick", "reflection_count_before_graze"]
		var allowed_keys := ["target", "topology", "graze", "mirror", "recovery", "current_lane_id", "topology_revision_id", "target_tick", "target_event_sequence", "graze_tick", "graze_event_sequence"] + graze_metadata_keys
		for latch_key in latch:
			if latch_key not in allowed_keys: return false
		for bool_key in ["target", "topology", "graze", "mirror", "recovery"]:
			if typeof(latch.get(bool_key)) != TYPE_BOOL: return false
		if bool(latch.get("target")) != (String(EXPECTED_TARGETS[group_index]) in defeated): return false
		if bool(latch.get("topology")) != bool(latch.get("target")): return false
		if bool(latch.get("target")):
			if latch.get("current_lane_id") not in ["lane_left", "lane_center", "lane_right"] or typeof(latch.get("topology_revision_id")) != TYPE_STRING: return false
			if typeof(latch.get("target_tick")) != TYPE_INT or typeof(latch.get("target_event_sequence")) != TYPE_INT: return false
			if int(latch.get("target_tick")) < int(GROUP_START_TICKS[group_index]) or int(latch.get("target_tick")) > int(GROUP_DEADLINES[group_index]) or int(latch.get("target_event_sequence")) < 0: return false
			if not _order_not_after(int(latch.get("target_tick")), int(latch.get("target_event_sequence")), int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
		elif latch.has("current_lane_id") or latch.has("topology_revision_id") or latch.has("target_tick") or latch.has("target_event_sequence"):
			return false
		var selected_uid := String(bullets.get(group_key, ""))
		if bool(latch.get("graze")) != (not selected_uid.is_empty() and selected_uid in accepted): return false
		if bool(latch.get("graze")):
			if typeof(latch.get("graze_tick")) != TYPE_INT or typeof(latch.get("graze_event_sequence")) != TYPE_INT: return false
			if int(latch.get("graze_tick")) < int(GROUP_START_TICKS[group_index]) or int(latch.get("graze_tick")) > int(GROUP_DEADLINES[group_index]) or int(latch.get("graze_event_sequence")) < 0: return false
			if not _order_not_after(int(latch.get("graze_tick")), int(latch.get("graze_event_sequence")), int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
			for string_key in ["graze_bullet_uid", "graze_source_spawn_id"]:
				if typeof(latch.get(string_key)) != TYPE_STRING or String(latch.get(string_key)).strip_edges().is_empty(): return false
			for int_key in ["graze_bullet_spawn_tick", "graze_bullet_spawn_event_sequence", "first_reflection_tick", "reflection_count_before_graze"]:
				if typeof(latch.get(int_key)) != TYPE_INT: return false
			if latch.get("graze_bullet_uid") != selected_uid or latch.get("graze_source_spawn_id") != REQUIRED_SOURCES[group_index]: return false
			if int(latch.get("graze_bullet_spawn_tick")) < int(GROUP_START_TICKS[group_index]) or int(latch.get("graze_bullet_spawn_tick")) > int(latch.get("graze_tick")) or int(latch.get("graze_bullet_spawn_event_sequence")) < 0: return false
			if int(latch.get("first_reflection_tick")) < int(latch.get("graze_bullet_spawn_tick")) or int(latch.get("first_reflection_tick")) > int(latch.get("graze_tick")) or int(latch.get("reflection_count_before_graze")) < 1: return false
			var registry: Dictionary = snapshot.get("emission_registry", {})
			if not registry.has(selected_uid): return false
			var emission: Dictionary = registry[selected_uid]
			if emission.get("event_id") != REQUIRED_SOURCE_EVENTS[group_index] or emission.get("source_spawn_id") != latch.get("graze_source_spawn_id") or emission.get("bullet_spawn_tick") != latch.get("graze_bullet_spawn_tick") or emission.get("bullet_spawn_event_sequence") != latch.get("graze_bullet_spawn_event_sequence"): return false
			if not _order_not_after(int(emission.get("callback_stage_tick")), int(emission.get("callback_event_sequence")), int(latch.get("graze_tick")), int(latch.get("graze_event_sequence"))): return false
		else:
			if latch.has("graze_tick") or latch.has("graze_event_sequence"): return false
			for metadata_key in graze_metadata_keys:
				if latch.has(metadata_key): return false
		if group_index < 3 and (bool(latch.get("mirror")) or bool(latch.get("recovery"))): return false
		if group_index == 3:
			if bool(latch.get("mirror")) != not (snapshot.get("selected_mirror", {}) as Dictionary).is_empty(): return false
			var recovery: bool = snapshot.get("first_kill_role") == "surviving_mirror" and int(snapshot.get("surviving_mirror_kill_tick")) >= 0 and int(snapshot.get("abacus_kill_tick")) >= 0 and bool(snapshot.get("center_lane_preserved"))
			if bool(latch.get("recovery")) != recovery: return false
		if group_index <= settled_count and (not bool(latch.get("target")) or not bool(latch.get("topology")) or not bool(latch.get("graze"))): return false
	if state == "group_3_pending_final_cross":
		var final_latch: Dictionary = latches.get("3", {})
		for required_key in ["target", "topology", "graze", "mirror", "recovery"]:
			if not bool(final_latch.get(required_key, false)): return false
	var all_group_3_latched := false
	if latches.has("3"):
		var group_3_latch: Dictionary = latches["3"]
		all_group_3_latched = bool(group_3_latch.get("target")) and bool(group_3_latch.get("topology")) and bool(group_3_latch.get("graze")) and bool(group_3_latch.get("mirror")) and bool(group_3_latch.get("recovery"))
	if all_group_3_latched:
		if int(snapshot.get("precommit_tick")) < 0 or int(snapshot.get("precommit_tick")) > 2544 or int(snapshot.get("precommit_event_sequence")) < 0: return false
	else:
		if int(snapshot.get("precommit_tick")) != -1 or int(snapshot.get("precommit_event_sequence")) != -1: return false
	return true

func _snapshot_callback_record_is_valid(snapshot: Dictionary) -> bool:
	var record: Dictionary = snapshot.get("last_callback_record", {})
	var tick := int(snapshot.get("last_stage_tick"))
	var sequence := int(snapshot.get("last_event_sequence"))
	if tick == -1:
		return record.is_empty()
	if not _snapshot_callback_record_fields_are_valid(record, snapshot): return false
	if record.get("stage_tick") != tick or record.get("event_sequence") != sequence: return false
	return snapshot.get("last_callback_signature") == JSON.stringify(_canonical(record), "", true, true)

func _snapshot_callback_record_fields_are_valid(record: Dictionary, snapshot: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(record, ["event_sequence", "kind", "payload", "stage_tick"]): return false
	if typeof(record.get("kind")) != TYPE_STRING or not (record.get("payload") is Dictionary) or typeof(record.get("stage_tick")) != TYPE_INT or typeof(record.get("event_sequence")) != TYPE_INT: return false
	var tick := int(record.get("stage_tick"))
	var sequence := int(record.get("event_sequence"))
	if tick < 0 or sequence < 0: return false
	return _snapshot_callback_payload_is_valid(String(record.get("kind")), record.get("payload"), tick, sequence, snapshot)

func _snapshot_callback_payload_is_valid(kind: String, payload_value: Variant, callback_tick: int, callback_sequence: int, snapshot: Dictionary) -> bool:
	if not (payload_value is Dictionary): return false
	var payload: Dictionary = payload_value
	if kind == "stage_event_entry":
		if not _dictionary_has_exact_keys(payload, ["event_id", "payload"]) or typeof(payload.get("event_id")) != TYPE_STRING or not (payload.get("payload") is Dictionary): return false
		var event_id := String(payload.get("event_id"))
		var event_payload: Dictionary = payload.get("payload")
		if not _valid_stage_event_id(event_id) or event_id == "s2_b01" and callback_tick != 0: return false
		return _publication_payload_well_formed(event_payload) if event_id == "s2_b12" else event_payload.is_empty()
	if kind == "enemy_defeat":
		if not _dictionary_has_exact_keys(payload, ["enemy_id", "event_id", "player_center_x", "spawn_id"]): return false
		if typeof(payload.get("event_id")) != TYPE_STRING or typeof(payload.get("spawn_id")) != TYPE_STRING or typeof(payload.get("enemy_id")) != TYPE_STRING or typeof(payload.get("player_center_x")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(payload.get("player_center_x"))): return false
		var spawn_id := String(payload.get("spawn_id"))
		if TEACHING_TARGETS.has(spawn_id):
			var teaching_tuple: Array = TEACHING_TARGETS[spawn_id]
			return payload.get("event_id") == teaching_tuple[0] and payload.get("enemy_id") == teaching_tuple[1]
		if not TARGET_ENEMIES.has(spawn_id) or payload.get("enemy_id") != TARGET_ENEMIES[spawn_id]: return false
		var expected_event := String(TARGET_EVENTS[spawn_id])
		if spawn_id in MIRROR_SPAWNS and not (snapshot.get("selected_mirror", {}) as Dictionary).is_empty(): expected_event = "s2_b16"
		return payload.get("event_id") == expected_event
	if kind == "required_bullet_emitted":
		if not _dictionary_has_exact_keys(payload, ["bullet_uid", "event_id", "source", "spawn_event_sequence", "spawn_tick"]): return false
		if typeof(payload.get("event_id")) != TYPE_STRING or typeof(payload.get("bullet_uid")) != TYPE_STRING or typeof(payload.get("source")) != TYPE_STRING or typeof(payload.get("spawn_tick")) != TYPE_INT or typeof(payload.get("spawn_event_sequence")) != TYPE_INT: return false
		var uid := String(payload.get("bullet_uid"))
		if uid.strip_edges().is_empty() or String(payload.get("source")).strip_edges().is_empty() or int(payload.get("spawn_tick")) != callback_tick or int(payload.get("spawn_event_sequence")) < 0: return false
		if not _valid_required_source_tuple(String(payload.get("event_id")), String(payload.get("source"))): return false
		var registry: Dictionary = snapshot.get("emission_registry", {})
		if not registry.has(uid): return false
		var emission_value: Variant = registry[uid]
		if not (emission_value is Dictionary): return false
		return emission_value == {"event_id": payload.get("event_id"), "source_spawn_id": payload.get("source"), "bullet_spawn_tick": payload.get("spawn_tick"), "bullet_spawn_event_sequence": payload.get("spawn_event_sequence"), "callback_stage_tick": callback_tick, "callback_event_sequence": callback_sequence}
	if kind == "reflected_bullet_graze":
		if not _dictionary_has_exact_keys(payload, ["bullet_uid", "event_id", "reflection_count", "reflection_tick", "source", "spawn_event_sequence", "spawn_tick"]): return false
		if typeof(payload.get("event_id")) != TYPE_STRING or typeof(payload.get("bullet_uid")) != TYPE_STRING or typeof(payload.get("source")) != TYPE_STRING: return false
		for key in ["spawn_tick", "spawn_event_sequence", "reflection_tick", "reflection_count"]:
			if typeof(payload.get(key)) != TYPE_INT: return false
		var uid := String(payload.get("bullet_uid"))
		var source := String(payload.get("source"))
		var spawn_tick := int(payload.get("spawn_tick"))
		var spawn_sequence := int(payload.get("spawn_event_sequence"))
		var reflection_tick := int(payload.get("reflection_tick"))
		if uid.strip_edges().is_empty() or source.strip_edges().is_empty() or spawn_tick < 0 or spawn_sequence < 0 or reflection_tick < spawn_tick or reflection_tick > callback_tick or int(payload.get("reflection_count")) < 1: return false
		var registry: Dictionary = snapshot.get("emission_registry", {})
		if registry.has(uid):
			var emission_value: Variant = registry[uid]
			if not (emission_value is Dictionary): return false
			var emission: Dictionary = emission_value
			return emission.get("event_id") == payload.get("event_id") and emission.get("source_spawn_id") == source and emission.get("bullet_spawn_tick") == spawn_tick and emission.get("bullet_spawn_event_sequence") == spawn_sequence
		if uid not in snapshot.get("teaching_graze_uids", []): return false
		if not TEACHING_TARGETS.has(source): return false
		return String((TEACHING_TARGETS[source] as Array)[0]) == payload.get("event_id")
	if kind == "topology_checkpoint":
		if not _dictionary_has_exact_keys(payload, ["event_id", "expected_revision_id", "player_center_x"]): return false
		if not _valid_stage_event_id(String(payload.get("event_id", ""))) or typeof(payload.get("player_center_x")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(payload.get("player_center_x"))) or typeof(payload.get("expected_revision_id")) != TYPE_STRING: return false
		return String(payload.get("expected_revision_id")).is_empty() or payload.get("expected_revision_id") == snapshot.get("topology_revision_id")
	if kind == "mirror_choice":
		return _dictionary_has_exact_keys(payload, ["player_center_x", "spawn_id"]) and payload.get("spawn_id") in MIRROR_SPAWNS and typeof(payload.get("player_center_x")) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(payload.get("player_center_x")))
	if kind == "final_lane_crossing":
		if not _dictionary_has_exact_keys(payload, ["boss_gate_open_tick", "event_id", "player_center_x"]): return false
		return payload.get("event_id") == "s2_b18" and typeof(payload.get("player_center_x")) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(payload.get("player_center_x"))) and typeof(payload.get("boss_gate_open_tick")) == TYPE_INT and int(payload.get("boss_gate_open_tick")) >= 0 and int(payload.get("boss_gate_open_tick")) <= callback_tick
	if kind in ["player_miss", "player_bomb"]:
		return _dictionary_has_exact_keys(payload, ["event_id"]) and typeof(payload.get("event_id")) == TYPE_STRING and _valid_stage_event_id(String(payload.get("event_id")))
	return false

func _snapshot_emissions_are_valid(snapshot: Dictionary) -> bool:
	var registry: Dictionary = snapshot.get("emission_registry", {})
	var teaching_uids: Array = snapshot.get("teaching_graze_uids", [])
	for uid_value in registry:
		if typeof(uid_value) != TYPE_STRING or String(uid_value).strip_edges().is_empty() or uid_value in teaching_uids: return false
		var emission_value: Variant = registry[uid_value]
		if not (emission_value is Dictionary): return false
		var emission: Dictionary = emission_value
		var keys: Array = emission.keys()
		keys.sort()
		if keys != ["bullet_spawn_event_sequence", "bullet_spawn_tick", "callback_event_sequence", "callback_stage_tick", "event_id", "source_spawn_id"]: return false
		for key in ["bullet_spawn_event_sequence", "bullet_spawn_tick", "callback_event_sequence", "callback_stage_tick"]:
			if typeof(emission.get(key)) != TYPE_INT or int(emission.get(key)) < 0: return false
		if typeof(emission.get("event_id")) != TYPE_STRING or typeof(emission.get("source_spawn_id")) != TYPE_STRING: return false
		if not _valid_required_source_tuple(String(emission.get("event_id")), String(emission.get("source_spawn_id"))): return false
		if emission.get("bullet_spawn_tick") != emission.get("callback_stage_tick"): return false
		if not _order_not_after(int(emission.get("callback_stage_tick")), int(emission.get("callback_event_sequence")), int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
	var bullets: Dictionary = snapshot.get("required_bullet_by_group", {})
	for group_key in bullets:
		var uid := String(bullets[group_key])
		if not registry.has(uid): return false
		var group_index := int(group_key)
		if uid != _select_required_bullet_uid_from_registry(group_index, registry): return false
	return true

func _snapshot_state_graph_is_valid(snapshot: Dictionary) -> bool:
	var state := String(snapshot.get("route_state"))
	var revision := String(snapshot.get("topology_revision_id"))
	var selected: Dictionary = snapshot.get("selected_mirror", {})
	var defeated: Array = snapshot.get("defeated_booth_spawn_ids", [])
	if state in ["inactive", "teaching_only", "awaiting_publication"]:
		return revision.is_empty() and selected.is_empty() and defeated.is_empty()
	if state == "group_1_armed":
		return selected.is_empty() and (revision == "stage_front_initial" and defeated.is_empty() or revision == "stage_front_after_red_neighbor_flip" and defeated == [BOOTH_SPAWNS[0]])
	if state == "group_2_armed":
		return selected.is_empty() and (revision == "stage_front_after_red_neighbor_flip" and defeated == [BOOTH_SPAWNS[0]] or revision == "stage_front_after_blue_neighbor_flip" and defeated == [BOOTH_SPAWNS[0], BOOTH_SPAWNS[1]])
	if state == "group_3_armed":
		if selected.is_empty(): return revision == "stage_front_after_blue_neighbor_flip" and defeated == [BOOTH_SPAWNS[0], BOOTH_SPAWNS[1]]
		if "s2_b13_yellow_booth_master" in defeated: return revision.begins_with("stage_front_final_gate_open_")
		return revision == String(selected.get("revision_id")) and defeated == [BOOTH_SPAWNS[0], BOOTH_SPAWNS[1]]
	if state in ["group_3_pending_final_cross", "complete"]:
		return not selected.is_empty() and defeated == BOOTH_SPAWNS and revision == "stage_front_final_gate_open_%s" % snapshot.get("final_open_lane_id")
	if state in ["invalidated", "expired"]:
		if int(snapshot.get("settled_group_count")) < 2 and not selected.is_empty(): return false
		return true
	return false

func _snapshot_terminal_reason_is_valid(snapshot: Dictionary) -> bool:
	var state := String(snapshot.get("route_state"))
	var cause: Dictionary = snapshot.get("terminal_cause_record", {})
	if state not in TERMINAL_STATES:
		return cause.is_empty()
	if cause.is_empty() or not _dictionary_has_exact_keys(cause, ["callback_record", "callback_signature", "deadline_tick", "history", "producer_state", "reason", "terminal_state"]): return false
	if typeof(cause.get("terminal_state")) != TYPE_STRING or typeof(cause.get("reason")) != TYPE_STRING or typeof(cause.get("producer_state")) != TYPE_STRING or typeof(cause.get("deadline_tick")) != TYPE_INT or typeof(cause.get("callback_signature")) != TYPE_STRING: return false
	if not (cause.get("callback_record") is Dictionary) or not (cause.get("history") is Dictionary): return false
	if cause.get("terminal_state") != state or cause.get("reason") != snapshot.get("terminal_reason") or cause.get("producer_state") not in STATES: return false
	var callback: Dictionary = cause.get("callback_record")
	if not _snapshot_callback_record_fields_are_valid(callback, snapshot): return false
	if cause.get("callback_signature") != JSON.stringify(_canonical(callback), "", true, true): return false
	if not _order_not_after(int(callback.get("stage_tick")), int(callback.get("event_sequence")), int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
	if callback.get("stage_tick") == snapshot.get("last_stage_tick") and callback.get("event_sequence") == snapshot.get("last_event_sequence") and callback != snapshot.get("last_callback_record"): return false
	var history: Dictionary = cause.get("history")
	if history != _snapshot_terminal_history(snapshot): return false
	var reason := String(cause.get("reason"))
	var producer_state := String(cause.get("producer_state"))
	var deadline := int(cause.get("deadline_tick"))
	var cause_tick := int(callback.get("stage_tick"))
	var cause_sequence := int(callback.get("event_sequence"))
	var payload: Dictionary = callback.get("payload")
	var kind := String(callback.get("kind"))
	var count := int(snapshot.get("settled_group_count"))
	if reason == "route_complete":
		if state != "complete" or producer_state != "group_3_pending_final_cross" or deadline != 2700 or kind != "final_lane_crossing" or count != 3 or cause_tick < 2550 or cause_tick > 2700: return false
		if lane_id_for_x(float(payload.get("player_center_x"))) != snapshot.get("final_open_lane_id"): return false
		var records: Array = snapshot.get("settlement_records", [])
		if records.size() != 3: return false
		var final_record: Dictionary = records[2]
		return final_record.get("stage_tick") == cause_tick and final_record.get("event_sequence") == cause_sequence and final_record.get("final_lane_cross_tick") == cause_tick and final_record.get("final_lane_cross_lane_id") == lane_id_for_x(float(payload.get("player_center_x"))) and final_record.get("boss_gate_open_tick") == payload.get("boss_gate_open_tick")
	if state == "complete": return false
	if reason == "publication_mismatch":
		if state != "expired" or producer_state != "awaiting_publication" or deadline != 1794 or count != 0 or not (snapshot.get("publication", {}) as Dictionary).is_empty(): return false
		return cause_tick > deadline or kind == "stage_event_entry" and payload.get("event_id") == "s2_b12" and not _valid_publication(payload.get("payload"))
	if reason == "required_rebound_graze_missing":
		var group_index := 0
		if producer_state == "group_1_armed": group_index = 1
		elif producer_state == "group_2_armed": group_index = 2
		if state != "expired" or group_index == 0 or deadline != int(GROUP_DEADLINES[group_index]) or cause_tick <= deadline or count != group_index - 1: return false
		return not _history_group_latch_complete(history, group_index)
	if reason == "mirror_choice_expired":
		return state == "expired" and producer_state == "group_3_armed" and deadline == 2244 and cause_tick > deadline and count == 2 and (history.get("selected_mirror", {}) as Dictionary).is_empty()
	if reason == "price_countdown_expired":
		if state != "expired" or producer_state != "group_3_armed" or count != 2 or cause_tick <= deadline or deadline not in [2394, 2544]: return false
		if deadline == 2394: return not _history_recovery_complete(history)
		return not _history_group_latch_complete(history, 3) or int(history.get("precommit_tick")) < 0
	if reason == "final_lane_cross_expired":
		return state == "expired" and producer_state == "group_3_pending_final_cross" and deadline == 2700 and cause_tick > deadline and count == 2 and _history_group_latch_complete(history, 3) and int(history.get("precommit_tick")) >= 0
	if deadline != -1 or state != "invalidated": return false
	if reason == "wrong_booth_order":
		var group_index := _group_index_for_state(producer_state)
		return kind == "enemy_defeat" and group_index > 0 and payload.get("spawn_id") in BOOTH_SPAWNS and payload.get("spawn_id") != EXPECTED_TARGETS[group_index] and count == group_index - 1 and cause_tick <= int(GROUP_DEADLINES[group_index])
	if reason == "topology_predicate_failed":
		return _snapshot_terminal_topology_failure_is_valid(producer_state, kind, payload, cause_tick, history)
	if reason == "mirror_choice_ambiguous":
		var selected: Dictionary = history.get("selected_mirror", {})
		return producer_state == "group_3_armed" and kind == "mirror_choice" and not selected.is_empty() and payload.get("spawn_id") in MIRROR_SPAWNS and payload.get("spawn_id") != selected.get("selected_spawn_id") and count == 2
	if reason == "abacus_before_surviving_mirror":
		var selected: Dictionary = history.get("selected_mirror", {})
		return producer_state == "group_3_armed" and kind == "enemy_defeat" and payload.get("event_id") == "s2_b16" and payload.get("spawn_id") == "s2_b16_abacus_keeper" and not selected.is_empty() and cause_tick >= 2250 and cause_tick <= 2394 and history.get("first_kill_role") == "abacus_keeper" and history.get("abacus_kill_tick") == cause_tick and history.get("abacus_kill_event_sequence") == cause_sequence and int(history.get("surviving_mirror_kill_tick")) == -1 and count == 2
	if reason == "wrong_final_lane_cross":
		return producer_state == "group_3_pending_final_cross" and kind == "final_lane_crossing" and cause_tick >= 2550 and cause_tick <= 2700 and lane_id_for_x(float(payload.get("player_center_x"))) != snapshot.get("final_open_lane_id") and count == 2
	return false

func _snapshot_terminal_history(snapshot: Dictionary) -> Dictionary:
	var keys := [
		"publication", "settled_group_count", "point_value_multiplier", "topology_revision_id", "active_directed_edges", "defeated_booth_spawn_ids", "selected_mirror",
		"selected_mirror_kill_tick", "selected_mirror_kill_event_sequence", "surviving_mirror_kill_tick", "surviving_mirror_kill_event_sequence", "abacus_kill_tick",
		"abacus_kill_event_sequence", "first_kill_role", "mirror_activation_mask", "center_lane_preserved", "abacus_active", "required_bullet_by_group", "accepted_graze_uids", "group_latches", "consumed_transition_keys",
		"settlement_records", "final_open_lane_id", "last_surviving_booth_node_id", "precommit_tick", "precommit_event_sequence",
	]
	var history := {}
	for key in keys:
		var value: Variant = snapshot[key]
		history[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return history

func _history_group_latch_complete(history: Dictionary, group_index: int) -> bool:
	var latches: Dictionary = history.get("group_latches", {})
	if not latches.has(str(group_index)) or not (latches[str(group_index)] is Dictionary): return false
	var latch: Dictionary = latches[str(group_index)]
	if not bool(latch.get("target")) or not bool(latch.get("topology")) or not bool(latch.get("graze")): return false
	return group_index < 3 or bool(latch.get("mirror")) and bool(latch.get("recovery"))

func _history_recovery_complete(history: Dictionary) -> bool:
	return history.get("first_kill_role") == "surviving_mirror" and int(history.get("surviving_mirror_kill_tick")) >= 0 and int(history.get("abacus_kill_tick")) >= 0 and bool(history.get("center_lane_preserved"))

func _group_index_for_state(state: String) -> int:
	if state == "group_1_armed": return 1
	if state == "group_2_armed": return 2
	if state == "group_3_armed": return 3
	return 0

func _snapshot_terminal_topology_failure_is_valid(producer_state: String, kind: String, payload: Dictionary, cause_tick: int, history: Dictionary) -> bool:
	if producer_state != "group_3_armed" and kind == "mirror_choice": return false
	if kind == "mirror_choice":
		if cause_tick < 2100 or cause_tick > 2244 or not (history.get("selected_mirror", {}) as Dictionary).is_empty(): return false
		var activated_edges: Array = AFTER_BLUE_EDGES.duplicate(true)
		activated_edges.append(["lane_left", "mirror_left"])
		activated_edges.append(["lane_right", "mirror_right"])
		var mirror_node := "mirror_left" if payload.get("spawn_id") == "s2_b15_left_mirror" else "mirror_right"
		return not _can_reach(lane_id_for_x(float(payload.get("player_center_x"))), mirror_node, activated_edges, _difficulty == "normal")
	if kind != "enemy_defeat": return false
	var group_index := _group_index_for_state(producer_state)
	if group_index == 0 or payload.get("spawn_id") != EXPECTED_TARGETS[group_index] or cause_tick < int(GROUP_START_TICKS[group_index]) or cause_tick > int(GROUP_DEADLINES[group_index]): return false
	var target_node: String = ["", "booth_red", "booth_blue", "booth_yellow"][group_index]
	return not _can_reach(lane_id_for_x(float(payload.get("player_center_x"))), target_node, history.get("active_directed_edges", []), _difficulty == "normal")

func _snapshot_settlements_match_latches(snapshot: Dictionary) -> bool:
	var records: Array = snapshot.get("settlement_records", [])
	var latches: Dictionary = snapshot.get("group_latches", {})
	for index in range(mini(2, records.size())):
		var group_key := str(index + 1)
		if not latches.has(group_key): return false
		var latch: Dictionary = latches[group_key]
		var expected_tick := int(latch.get("target_tick"))
		var expected_sequence := int(latch.get("target_event_sequence"))
		if _order_precedes(expected_tick, expected_sequence, int(latch.get("graze_tick")), int(latch.get("graze_event_sequence"))):
			expected_tick = int(latch.get("graze_tick"))
			expected_sequence = int(latch.get("graze_event_sequence"))
		var record: Dictionary = records[index]
		if int(record.get("stage_tick")) != expected_tick or int(record.get("event_sequence")) != expected_sequence: return false
	var precommit_tick := int(snapshot.get("precommit_tick"))
	var precommit_sequence := int(snapshot.get("precommit_event_sequence"))
	if precommit_tick >= 0:
		if not _order_not_after(precommit_tick, precommit_sequence, int(snapshot.get("last_stage_tick")), int(snapshot.get("last_event_sequence"))): return false
		var group_3_latch: Dictionary = latches.get("3", {})
		var orders := [
			[int(snapshot.get("selected_mirror_kill_tick")), int(snapshot.get("selected_mirror_kill_event_sequence"))],
			[int(snapshot.get("surviving_mirror_kill_tick")), int(snapshot.get("surviving_mirror_kill_event_sequence"))],
			[int(snapshot.get("abacus_kill_tick")), int(snapshot.get("abacus_kill_event_sequence"))],
			[int(group_3_latch.get("target_tick", -1)), int(group_3_latch.get("target_event_sequence", -1))],
			[int(group_3_latch.get("graze_tick", -1)), int(group_3_latch.get("graze_event_sequence", -1))],
		]
		var latest_order: Array = [-1, -1]
		for order_value in orders:
			var order: Array = order_value
			if order[0] < 0 or not _order_not_after(int(order[0]), int(order[1]), precommit_tick, precommit_sequence): return false
			if latest_order[0] < 0 or _order_precedes(int(latest_order[0]), int(latest_order[1]), int(order[0]), int(order[1])):
				latest_order = order
		if [precommit_tick, precommit_sequence] != latest_order: return false
	return true

func _snapshot_state_window_is_valid(snapshot: Dictionary) -> bool:
	var state := String(snapshot.get("route_state"))
	var tick := int(snapshot.get("last_stage_tick"))
	if state == "inactive": return tick == -1
	if state == "teaching_only": return tick >= 0 and tick < 750
	if state == "awaiting_publication": return tick >= 750 and tick <= 1794
	if state == "group_1_armed": return tick <= 1944
	if state == "group_2_armed": return tick <= 2094
	if state == "group_3_armed":
		if (snapshot.get("selected_mirror", {}) as Dictionary).is_empty(): return tick <= 2244
		if int(snapshot.get("surviving_mirror_kill_tick")) < 0 or int(snapshot.get("abacus_kill_tick")) < 0 or not bool(snapshot.get("center_lane_preserved")): return tick <= 2394
		return tick <= 2544
	if state == "group_3_pending_final_cross": return tick <= 2700
	if state == "complete": return tick >= 2550
	return true

func _edges_are_well_formed(edges_value: Variant) -> bool:
	if not (edges_value is Array): return false
	var edges: Array = edges_value
	var seen: Array = []
	for edge_value in edges:
		if not (edge_value is Array): return false
		var edge: Array = edge_value
		if edge.size() != 2 or typeof(edge[0]) != TYPE_STRING or typeof(edge[1]) != TYPE_STRING or edge in seen: return false
		seen.append(edge)
	return true

func _order_precedes(left_tick: int, left_sequence: int, right_tick: int, right_sequence: int) -> bool:
	return left_tick < right_tick or left_tick == right_tick and left_sequence < right_sequence

func _order_not_after(left_tick: int, left_sequence: int, right_tick: int, right_sequence: int) -> bool:
	return left_tick < right_tick or left_tick == right_tick and left_sequence <= right_sequence

func _has_duplicates(values: Array) -> bool:
	var seen: Array = []
	for value in values:
		if value in seen: return true
		seen.append(value)
	return false

func _apply_snapshot(snapshot: Dictionary) -> void:
	_configured = bool(snapshot["configured"]); _difficulty = String(snapshot["difficulty"]); _stage_run_uid = String(snapshot["stage_run_uid"])
	_route_state = String(snapshot["route_state"]); _last_stage_tick = int(snapshot["last_stage_tick"]); _last_event_sequence = int(snapshot["last_event_sequence"]); _last_callback_signature = String(snapshot["last_callback_signature"]); _last_callback_record = snapshot["last_callback_record"].duplicate(true)
	_teaching_markers = snapshot["teaching_markers"].duplicate(true); _teaching_graze_uids = snapshot["teaching_graze_uids"].duplicate(true); _publication = snapshot["publication"].duplicate(true)
	_settled_group_count = int(snapshot["settled_group_count"]); _point_value_multiplier = float(snapshot["point_value_multiplier"]); _topology_revision_id = String(snapshot["topology_revision_id"]); _active_directed_edges = snapshot["active_directed_edges"].duplicate(true)
	_defeated_booth_spawn_ids = snapshot["defeated_booth_spawn_ids"].duplicate(true); _selected_mirror = snapshot["selected_mirror"].duplicate(true); _selected_mirror_kill_tick = int(snapshot["selected_mirror_kill_tick"]); _selected_mirror_kill_event_sequence = int(snapshot["selected_mirror_kill_event_sequence"])
	_surviving_mirror_kill_tick = int(snapshot["surviving_mirror_kill_tick"]); _surviving_mirror_kill_event_sequence = int(snapshot["surviving_mirror_kill_event_sequence"]); _abacus_kill_tick = int(snapshot["abacus_kill_tick"]); _abacus_kill_event_sequence = int(snapshot["abacus_kill_event_sequence"])
	_first_kill_role = String(snapshot["first_kill_role"]); _mirror_activation_mask = int(snapshot["mirror_activation_mask"]); _center_lane_preserved = bool(snapshot["center_lane_preserved"]); _abacus_active = bool(snapshot["abacus_active"])
	_emission_registry = snapshot["emission_registry"].duplicate(true); _required_bullet_by_group = snapshot["required_bullet_by_group"].duplicate(true); _accepted_graze_uids = snapshot["accepted_graze_uids"].duplicate(true); _group_latches = snapshot["group_latches"].duplicate(true)
	_consumed_transition_keys = snapshot["consumed_transition_keys"].duplicate(true); _settlement_records = snapshot["settlement_records"].duplicate(true); _final_open_lane_id = String(snapshot["final_open_lane_id"]); _last_surviving_booth_node_id = String(snapshot["last_surviving_booth_node_id"]); _precommit_tick = int(snapshot["precommit_tick"]); _precommit_event_sequence = int(snapshot["precommit_event_sequence"]); _terminal_reason = String(snapshot["terminal_reason"]); _terminal_cause_record = snapshot["terminal_cause_record"].duplicate(true)

func _reset_state() -> void:
	_configured = false; _difficulty = ""; _stage_run_uid = ""; _route_state = "inactive"
	_last_stage_tick = -1; _last_event_sequence = -1; _last_callback_signature = ""; _last_callback_record = {}
	_teaching_markers = []; _teaching_graze_uids = []; _publication = {}; _settled_group_count = 0; _point_value_multiplier = 1.0
	_topology_revision_id = ""; _active_directed_edges = []; _defeated_booth_spawn_ids = []; _selected_mirror = {}; _selected_mirror_kill_tick = -1; _selected_mirror_kill_event_sequence = -1
	_surviving_mirror_kill_tick = -1; _surviving_mirror_kill_event_sequence = -1; _abacus_kill_tick = -1; _abacus_kill_event_sequence = -1; _first_kill_role = ""
	_mirror_activation_mask = 0; _center_lane_preserved = false; _abacus_active = false; _emission_registry = {}; _required_bullet_by_group = {}; _accepted_graze_uids = []; _group_latches = {}
	_consumed_transition_keys = []; _settlement_records = []; _final_open_lane_id = ""; _last_surviving_booth_node_id = ""; _precommit_tick = -1; _precommit_event_sequence = -1; _terminal_reason = ""; _terminal_cause_record = {}

func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys(); keys.sort()
		for key in keys: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_canonical(item))
		return result
	return value
