class_name BoardView
extends GridContainer

signal inspector_cell_hovered(cell_position: Vector2i)
signal inspector_cell_selected(cell_position: Vector2i)

const CELL_SCENE: PackedScene = preload("res://scenes/components/mine_cell.tscn")
const CELL_SIZE: float = 58.0

var _board: MinesweeperBoard
var _cells: Array[MineCellView] = []
var _highlighted_position: Vector2i = Vector2i(-1, -1)
var _interaction_enabled: bool = true
var _inspector_enabled: bool = false
var _observation_highlights: Array[Vector2i] = []


func set_board(board: MinesweeperBoard) -> void:
	if is_instance_valid(_board) and _board.board_changed.is_connected(_refresh_cells):
		_board.board_changed.disconnect(_refresh_cells)
	_board = board
	_board.board_changed.connect(_refresh_cells)
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_cells.clear()
	columns = _board.width
	custom_minimum_size = Vector2(_board.width, _board.height) * CELL_SIZE
	for y: int in range(_board.height):
		for x: int in range(_board.width):
			var cell := CELL_SCENE.instantiate() as MineCellView
			cell.setup(Vector2i(x, y))
			cell.reveal_requested.connect(_on_reveal_requested)
			cell.flag_requested.connect(_on_flag_requested)
			cell.inspector_hovered.connect(_on_inspector_hovered)
			add_child(cell)
			_cells.append(cell)
	_refresh_cells()


func _refresh_cells() -> void:
	if not is_instance_valid(_board):
		return
	if _cells.size() != _board.width * _board.height or columns != _board.width:
		_rebuild()
		return
	var states: Array[Dictionary] = _board.get_visible_board_state()
	for index: int in range(mini(states.size(), _cells.size())):
		_cells[index].display_state(states[index])


func _on_reveal_requested(cell_position: Vector2i) -> void:
	if _inspector_enabled:
		inspector_cell_selected.emit(cell_position)
	elif _interaction_enabled:
		_board.start_or_reveal_first(cell_position)


func _on_flag_requested(cell_position: Vector2i) -> void:
	if _interaction_enabled:
		_board.toggle_flag(cell_position)


func highlight_decision(cell_position: Vector2i) -> void:
	clear_decision_highlight()
	if cell_position.x < 0 or cell_position.x >= _board.width or cell_position.y < 0 or cell_position.y >= _board.height:
		return
	_highlighted_position = cell_position
	_cells[cell_position.y * _board.width + cell_position.x].set_decision_highlight(true)


func clear_decision_highlight() -> void:
	if _highlighted_position.x >= 0 and _highlighted_position.y >= 0 and not _cells.is_empty():
		var index: int = _highlighted_position.y * _board.width + _highlighted_position.x
		if index >= 0 and index < _cells.size():
			_cells[index].set_decision_highlight(false)
			_cells[index].display_state(_board.get_cell_state(_highlighted_position))
	_highlighted_position = Vector2i(-1, -1)


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled


func set_inspector_enabled(enabled: bool) -> void:
	_inspector_enabled = enabled
	if not enabled:
		clear_observation_highlight()


func highlight_observation_context(candidate_position: Vector2i) -> void:
	clear_observation_highlight()
	for y_offset: int in range(-1, 2):
		for x_offset: int in range(-1, 2):
			var position := candidate_position + Vector2i(x_offset, y_offset)
			if position.x < 0 or position.x >= _board.width or position.y < 0 or position.y >= _board.height:
				continue
			var index: int = position.y * _board.width + position.x
			var kind: int = 1 if position == candidate_position else 2
			_cells[index].set_inspector_highlight(kind)
			_cells[index].display_state(_board.get_cell_state(position))
			_observation_highlights.append(position)


func clear_observation_highlight() -> void:
	for position: Vector2i in _observation_highlights:
		var index: int = position.y * _board.width + position.x
		if index >= 0 and index < _cells.size():
			_cells[index].set_inspector_highlight(0)
			_cells[index].display_state(_board.get_cell_state(position))
	_observation_highlights.clear()


func _on_inspector_hovered(cell_position: Vector2i) -> void:
	if _inspector_enabled:
		inspector_cell_hovered.emit(cell_position)
