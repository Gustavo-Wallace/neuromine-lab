class_name ObservationSchema
extends RefCounted

const VERSION: int = 1

enum LocalFeature {
	IS_OUT_OF_BOUNDS,
	IS_COVERED,
	IS_FLAGGED,
	IS_REVEALED,
	VISIBLE_CLUE_NORMALIZED,
	COVERED_NEIGHBORS_NORMALIZED,
	FLAGGED_NEIGHBORS_NORMALIZED,
	REMAINING_MINES_FOR_CLUE_NORMALIZED,
	COUNT,
}

enum GlobalFeature {
	CANDIDATE_X_NORMALIZED,
	CANDIDATE_Y_NORMALIZED,
	BOARD_PROGRESS_NORMALIZED,
	REMAINING_MINES_RATIO,
	COVERED_CELLS_RATIO,
	FLAGS_USED_RATIO,
	CURRENT_ACTION_RATIO,
	IS_FIRST_ACTION,
	COUNT,
}

const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]
const DIRECTION_IDS: Array[String] = ["NW", "N", "NE", "W", "E", "SW", "S", "SE"]
const DIRECTION_NAMES: Array[String] = [
	"Noroeste", "Norte", "Nordeste", "Oeste", "Leste", "Sudoeste", "Sul", "Sudeste"
]
const LOCAL_FEATURE_NAMES: Array[String] = [
	"is_out_of_bounds",
	"is_covered",
	"is_flagged",
	"is_revealed",
	"visible_clue_normalized",
	"covered_neighbors_normalized",
	"flagged_neighbors_normalized",
	"remaining_mines_for_clue_normalized",
]
const GLOBAL_FEATURE_NAMES: Array[String] = [
	"candidate_x_normalized",
	"candidate_y_normalized",
	"board_progress_normalized",
	"remaining_mines_ratio",
	"covered_cells_ratio",
	"flags_used_ratio",
	"current_action_ratio",
	"is_first_action",
]

const DIRECTION_COUNT: int = 8
const LOCAL_FEATURE_COUNT: int = 8
const LOCAL_INPUT_COUNT: int = DIRECTION_COUNT * LOCAL_FEATURE_COUNT
const GLOBAL_FEATURE_COUNT: int = 8
const TOTAL_INPUT_COUNT: int = LOCAL_INPUT_COUNT + GLOBAL_FEATURE_COUNT
const NON_REVEALED_REMAINING_MINES_NEUTRAL: float = 0.5
const MAX_FLAGS_USED_RATIO: float = 2.0


static func local_index(direction_index: int, feature_index: int) -> int:
	return direction_index * LOCAL_FEATURE_COUNT + feature_index


static func global_index(feature_index: int) -> int:
	return LOCAL_INPUT_COUNT + feature_index


static func get_feature_names() -> PackedStringArray:
	var names := PackedStringArray()
	for direction_index: int in range(DIRECTION_COUNT):
		for feature_name: String in LOCAL_FEATURE_NAMES:
			names.append("%s.%s" % [DIRECTION_IDS[direction_index], feature_name])
	for feature_name: String in GLOBAL_FEATURE_NAMES:
		names.append(feature_name)
	return names
