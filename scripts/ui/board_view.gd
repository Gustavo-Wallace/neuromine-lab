class_name BoardView
extends GridContainer

const CELL_SCENE: PackedScene = preload("res://scenes/components/mine_cell.tscn")
const CELL_SIZE: float = 58.0

var _board: MinesweeperBoard
var _cells: Array[MineCellView] = []


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
	_board.start_or_reveal_first(cell_position)


func _on_flag_requested(cell_position: Vector2i) -> void:
	_board.toggle_flag(cell_position)
