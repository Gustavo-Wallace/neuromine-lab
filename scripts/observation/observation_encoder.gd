class_name ObservationEncoder
extends RefCounted

const Types := preload("res://scripts/core/minesweeper_types.gd")
const Schema := preload("res://scripts/observation/observation_schema.gd")
const CandidateData := preload("res://scripts/observation/candidate_observation.gd")
const Provider := preload("res://scripts/observation/candidate_provider.gd")


func encode_candidate(
	visible_board_state: Dictionary,
	candidate_position: Vector2i,
	debug_enabled: bool = false
) -> CandidateData:
	var width: int = int(visible_board_state.get("width", 0))
	var height: int = int(visible_board_state.get("height", 0))
	if candidate_position.x < 0 or candidate_position.x >= width or candidate_position.y < 0 or candidate_position.y >= height:
		return null

	var values := PackedFloat32Array()
	values.resize(Schema.TOTAL_INPUT_COUNT)
	values.fill(0.0)
	var overflagged_clues: Array[Dictionary] = []
	var direction_states: Array[Dictionary] = []

	for direction_index: int in range(Schema.DIRECTION_COUNT):
		var neighbor_position: Vector2i = candidate_position + Schema.DIRECTION_OFFSETS[direction_index]
		_encode_local_direction(
			visible_board_state,
			neighbor_position,
			direction_index,
			values,
			overflagged_clues,
			direction_states
		)

	_encode_global_features(visible_board_state, candidate_position, values)
	var metadata := {
		"direction_order": Schema.DIRECTION_IDS.duplicate(),
		"overflagged_clues": overflagged_clues,
		"direction_states": direction_states,
		"covered_neighbors_exclude_flags": true,
		"flags_used_ratio_limit": Schema.MAX_FLAGS_USED_RATIO,
	}
	var debug_state: Dictionary = visible_board_state.duplicate(true) if debug_enabled else {}
	return CandidateData.new(
		candidate_position,
		values,
		Schema.get_feature_names(),
		Schema.VERSION,
		metadata,
		debug_state
	)


func encode_all_candidates(visible_board_state: Dictionary, debug_enabled: bool = false) -> Array[CandidateData]:
	var observations: Array[CandidateData] = []
	for candidate_position: Vector2i in Provider.get_candidates(visible_board_state):
		observations.append(encode_candidate(visible_board_state, candidate_position, debug_enabled))
	return observations


func _encode_local_direction(
	visible_board_state: Dictionary,
	position: Vector2i,
	direction_index: int,
	values: PackedFloat32Array,
	overflagged_clues: Array[Dictionary],
	direction_states: Array[Dictionary]
) -> void:
	var base_index: int = Schema.local_index(direction_index, 0)
	var width: int = int(visible_board_state.get("width", 0))
	var height: int = int(visible_board_state.get("height", 0))
	if position.x < 0 or position.x >= width or position.y < 0 or position.y >= height:
		values[base_index + Schema.LocalFeature.IS_OUT_OF_BOUNDS] = 1.0
		values[base_index + Schema.LocalFeature.REMAINING_MINES_FOR_CLUE_NORMALIZED] = Schema.NON_REVEALED_REMAINING_MINES_NEUTRAL
		direction_states.append({"direction": direction_index, "position": position, "state": "out_of_bounds"})
		return

	var cell: Dictionary = _get_cell(visible_board_state, position)
	var visibility: int = int(cell.get("visibility", -1))
	values[base_index + Schema.LocalFeature.IS_COVERED] = 1.0 if visibility == Types.CellVisibility.COVERED else 0.0
	values[base_index + Schema.LocalFeature.IS_FLAGGED] = 1.0 if visibility == Types.CellVisibility.FLAGGED else 0.0
	values[base_index + Schema.LocalFeature.IS_REVEALED] = 1.0 if visibility == Types.CellVisibility.REVEALED else 0.0
	values[base_index + Schema.LocalFeature.REMAINING_MINES_FOR_CLUE_NORMALIZED] = Schema.NON_REVEALED_REMAINING_MINES_NEUTRAL

	var state_name := "covered"
	if visibility == Types.CellVisibility.FLAGGED:
		state_name = "flagged"
	elif visibility == Types.CellVisibility.REVEALED:
		state_name = "revealed"
	direction_states.append({"direction": direction_index, "position": position, "state": state_name})

	if visibility != Types.CellVisibility.REVEALED or cell.get("content", "") != "safe":
		return
	var clue: int = clampi(int(cell.get("adjacent_mines", 0)), 0, 8)
	var neighbor_counts: Vector2i = _count_visible_neighbors(visible_board_state, position)
	var covered_neighbors: int = neighbor_counts.x
	var flagged_neighbors: int = neighbor_counts.y
	values[base_index + Schema.LocalFeature.VISIBLE_CLUE_NORMALIZED] = float(clue) / 8.0
	values[base_index + Schema.LocalFeature.COVERED_NEIGHBORS_NORMALIZED] = float(covered_neighbors) / 8.0
	values[base_index + Schema.LocalFeature.FLAGGED_NEIGHBORS_NORMALIZED] = float(flagged_neighbors) / 8.0
	var raw_remaining: int = clue - flagged_neighbors
	var clamped_remaining: int = clampi(raw_remaining, -8, 8)
	values[base_index + Schema.LocalFeature.REMAINING_MINES_FOR_CLUE_NORMALIZED] = float(clamped_remaining + 8) / 16.0
	if raw_remaining < 0:
		overflagged_clues.append({
			"direction": direction_index,
			"position": position,
			"clue": clue,
			"flagged_neighbors": flagged_neighbors,
			"raw_remaining": raw_remaining,
		})


func _encode_global_features(
	visible_board_state: Dictionary,
	candidate_position: Vector2i,
	values: PackedFloat32Array
) -> void:
	var width: int = int(visible_board_state.get("width", 0))
	var height: int = int(visible_board_state.get("height", 0))
	var cell_count: int = maxi(1, width * height)
	var mine_count: int = maxi(0, int(visible_board_state.get("mine_count", 0)))
	var flag_count: int = 0
	var covered_count: int = 0
	for cell_value: Variant in visible_board_state.get("cells", []):
		if not cell_value is Dictionary:
			continue
		var visibility: int = int((cell_value as Dictionary).get("visibility", -1))
		if visibility == Types.CellVisibility.COVERED:
			covered_count += 1
		elif visibility == Types.CellVisibility.FLAGGED:
			flag_count += 1

	var total_safe: int = maxi(0, int(visible_board_state.get("total_safe_cells", 0)))
	var revealed_safe: int = maxi(0, int(visible_board_state.get("revealed_safe_cells", 0)))
	var move_count: int = maxi(0, int(visible_board_state.get("move_count", 0)))
	var default_max_actions: int = maxi(1, width * height * 4)
	var max_actions: int = maxi(1, int(visible_board_state.get("max_action_count", default_max_actions)))
	values[Schema.global_index(Schema.GlobalFeature.CANDIDATE_X_NORMALIZED)] = float(candidate_position.x) / float(maxi(1, width - 1))
	values[Schema.global_index(Schema.GlobalFeature.CANDIDATE_Y_NORMALIZED)] = float(candidate_position.y) / float(maxi(1, height - 1))
	values[Schema.global_index(Schema.GlobalFeature.BOARD_PROGRESS_NORMALIZED)] = clampf(
		float(revealed_safe) / float(total_safe) if total_safe > 0 else 0.0, 0.0, 1.0
	)
	values[Schema.global_index(Schema.GlobalFeature.REMAINING_MINES_RATIO)] = clampf(
		float(maxi(0, mine_count - flag_count)) / float(mine_count) if mine_count > 0 else 0.0, 0.0, 1.0
	)
	values[Schema.global_index(Schema.GlobalFeature.COVERED_CELLS_RATIO)] = clampf(float(covered_count) / float(cell_count), 0.0, 1.0)
	values[Schema.global_index(Schema.GlobalFeature.FLAGS_USED_RATIO)] = clampf(
		float(flag_count) / float(mine_count) if mine_count > 0 else 0.0, 0.0, Schema.MAX_FLAGS_USED_RATIO
	)
	values[Schema.global_index(Schema.GlobalFeature.CURRENT_ACTION_RATIO)] = clampf(float(move_count) / float(max_actions), 0.0, 1.0)
	values[Schema.global_index(Schema.GlobalFeature.IS_FIRST_ACTION)] = 1.0 if move_count == 0 else 0.0


func _count_visible_neighbors(visible_board_state: Dictionary, center: Vector2i) -> Vector2i:
	var covered_count: int = 0
	var flagged_count: int = 0
	var width: int = int(visible_board_state.get("width", 0))
	var height: int = int(visible_board_state.get("height", 0))
	for offset: Vector2i in Schema.DIRECTION_OFFSETS:
		var position: Vector2i = center + offset
		if position.x < 0 or position.x >= width or position.y < 0 or position.y >= height:
			continue
		var visibility: int = int(_get_cell(visible_board_state, position).get("visibility", -1))
		if visibility == Types.CellVisibility.COVERED:
			covered_count += 1
		elif visibility == Types.CellVisibility.FLAGGED:
			flagged_count += 1
	return Vector2i(covered_count, flagged_count)


func _get_cell(visible_board_state: Dictionary, position: Vector2i) -> Dictionary:
	var width: int = int(visible_board_state.get("width", 0))
	var cells: Array = visible_board_state.get("cells", [])
	var index: int = position.y * width + position.x
	return cells[index] as Dictionary if index >= 0 and index < cells.size() and cells[index] is Dictionary else {}
