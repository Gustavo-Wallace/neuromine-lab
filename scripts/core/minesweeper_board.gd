class_name MinesweeperBoard
extends RefCounted

signal board_changed
signal game_finished(victory: bool)

const Types := preload("res://scripts/core/minesweeper_types.gd")
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                         Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1),
]

var width: int = 0
var height: int = 0
var mine_count: int = 0
var seed: int = 0
var status: int = Types.GameStatus.READY

var _cells: Array[Types.CellData] = []
var _generated: bool = false
var _detonated_position: Vector2i = Vector2i(-1, -1)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(board_width: int, board_height: int, mines: int, board_seed: int) -> void:
	assert(board_width > 0 and board_height > 0, "Board dimensions must be positive.")
	assert(mines >= 0 and mines < board_width * board_height, "Mine count must leave at least one safe cell.")
	width = board_width
	height = board_height
	mine_count = mines
	seed = board_seed
	_create_empty_cells()
	board_changed.emit()


func start_or_reveal_first(cell_position: Vector2i) -> bool:
	if not _is_valid_position(cell_position) or is_finished():
		return false
	if _cell_at(cell_position).visibility == Types.CellVisibility.FLAGGED:
		return false
	if not _generated:
		_generate_field(cell_position)
		status = Types.GameStatus.PLAYING
	return reveal(cell_position)


func reveal(cell_position: Vector2i) -> bool:
	if not _is_valid_position(cell_position) or is_finished():
		return false
	if not _generated:
		return start_or_reveal_first(cell_position)

	var cell: Types.CellData = _cell_at(cell_position)
	if cell.visibility != Types.CellVisibility.COVERED:
		return false

	if cell.has_mine:
		cell.visibility = Types.CellVisibility.REVEALED
		_detonated_position = cell_position
		status = Types.GameStatus.LOST
		_reveal_all_mines()
		board_changed.emit()
		game_finished.emit(false)
		return true

	_reveal_safe_area(cell_position)
	if get_unrevealed_safe_count() == 0:
		status = Types.GameStatus.WON
		board_changed.emit()
		game_finished.emit(true)
	else:
		board_changed.emit()
	return true


func toggle_flag(cell_position: Vector2i) -> bool:
	if not _is_valid_position(cell_position) or is_finished():
		return false
	var cell: Types.CellData = _cell_at(cell_position)
	if cell.visibility == Types.CellVisibility.REVEALED:
		return false
	cell.visibility = (
		Types.CellVisibility.COVERED
		if cell.visibility == Types.CellVisibility.FLAGGED
		else Types.CellVisibility.FLAGGED
	)
	board_changed.emit()
	return true


func reset_same_seed() -> void:
	_create_empty_cells()
	board_changed.emit()


func generate_new_seed() -> int:
	var time_part: int = int(Time.get_unix_time_from_system() * 1000.0)
	var tick_part: int = Time.get_ticks_usec() % 1000000
	seed = abs(time_part * 1000003 + tick_part) % 1000000000000
	reset_same_seed()
	return seed


func get_cell_state(cell_position: Vector2i) -> Dictionary:
	if not _is_valid_position(cell_position):
		return {}
	var cell: Types.CellData = _cell_at(cell_position)
	var is_revealed: bool = cell.visibility == Types.CellVisibility.REVEALED
	return {
		"position": cell_position,
		"visibility": cell.visibility,
		"adjacent_mines": cell.adjacent_mines if is_revealed else -1,
		"has_mine": cell.has_mine if is_revealed else false,
		"detonated": is_revealed and cell_position == _detonated_position,
	}


func get_visible_board_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			result.append(get_cell_state(Vector2i(x, y)))
	return result


func get_debug_board_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var position := Vector2i(x, y)
			var cell: Types.CellData = _cell_at(position)
			result.append({
				"position": position,
				"visibility": cell.visibility,
				"adjacent_mines": cell.adjacent_mines,
				"has_mine": cell.has_mine,
				"detonated": position == _detonated_position,
			})
	return result


func is_finished() -> bool:
	return status == Types.GameStatus.WON or status == Types.GameStatus.LOST


func is_victory() -> bool:
	return status == Types.GameStatus.WON


func is_generated() -> bool:
	return _generated


func get_flag_count() -> int:
	var total: int = 0
	for cell: Types.CellData in _cells:
		if cell.visibility == Types.CellVisibility.FLAGGED:
			total += 1
	return total


func get_estimated_remaining_mines() -> int:
	return mine_count - get_flag_count()


func get_total_safe_count() -> int:
	return width * height - mine_count


func get_revealed_safe_count() -> int:
	return get_total_safe_count() - get_unrevealed_safe_count()


func get_unrevealed_safe_count() -> int:
	if not _generated:
		return get_total_safe_count()
	var total: int = 0
	for cell: Types.CellData in _cells:
		if not cell.has_mine and cell.visibility != Types.CellVisibility.REVEALED:
			total += 1
	return total


func _create_empty_cells() -> void:
	_cells.clear()
	for index: int in range(width * height):
		_cells.append(Types.CellData.new())
	_generated = false
	_detonated_position = Vector2i(-1, -1)
	status = Types.GameStatus.READY


func _generate_field(first_position: Vector2i) -> void:
	var candidates: Array[Vector2i] = []
	var safe_positions: Dictionary = {first_position: true}
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = first_position + offset
		if _is_valid_position(neighbor):
			safe_positions[neighbor] = true

	var available_with_area: int = width * height - safe_positions.size()
	if available_with_area < mine_count:
		safe_positions = {first_position: true}

	for y: int in range(height):
		for x: int in range(width):
			var position := Vector2i(x, y)
			if not safe_positions.has(position):
				candidates.append(position)

	_rng.seed = seed
	_shuffle_positions(candidates)
	for index: int in range(mine_count):
		_cell_at(candidates[index]).has_mine = true

	_calculate_adjacent_counts()
	_generated = true


func _shuffle_positions(positions: Array[Vector2i]) -> void:
	for index: int in range(positions.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var temporary: Vector2i = positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = temporary


func _calculate_adjacent_counts() -> void:
	for y: int in range(height):
		for x: int in range(width):
			var position := Vector2i(x, y)
			var cell: Types.CellData = _cell_at(position)
			cell.adjacent_mines = 0
			if cell.has_mine:
				continue
			for offset: Vector2i in NEIGHBOR_OFFSETS:
				var neighbor: Vector2i = position + offset
				if _is_valid_position(neighbor) and _cell_at(neighbor).has_mine:
					cell.adjacent_mines += 1


func _reveal_safe_area(start_position: Vector2i) -> void:
	var pending: Array[Vector2i] = [start_position]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var position: Vector2i = pending.pop_front()
		if visited.has(position):
			continue
		visited[position] = true
		var cell: Types.CellData = _cell_at(position)
		if cell.has_mine or cell.visibility == Types.CellVisibility.FLAGGED:
			continue
		cell.visibility = Types.CellVisibility.REVEALED
		if cell.adjacent_mines != 0:
			continue
		for offset: Vector2i in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = position + offset
			if not _is_valid_position(neighbor):
				continue
			var neighbor_cell: Types.CellData = _cell_at(neighbor)
			if not neighbor_cell.has_mine and neighbor_cell.visibility == Types.CellVisibility.COVERED:
				pending.append(neighbor)


func _reveal_all_mines() -> void:
	for cell: Types.CellData in _cells:
		if cell.has_mine:
			cell.visibility = Types.CellVisibility.REVEALED


func _cell_at(cell_position: Vector2i) -> Types.CellData:
	return _cells[cell_position.y * width + cell_position.x]


func _is_valid_position(cell_position: Vector2i) -> bool:
	return (
		cell_position.x >= 0
		and cell_position.x < width
		and cell_position.y >= 0
		and cell_position.y < height
	)
