class_name CandidateProvider
extends RefCounted

const Types := preload("res://scripts/core/minesweeper_types.gd")


static func get_candidates(visible_board_state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var width: int = int(visible_board_state.get("width", 0))
	var height: int = int(visible_board_state.get("height", 0))
	var cells: Array = visible_board_state.get("cells", [])
	for y: int in range(height):
		for x: int in range(width):
			var index: int = y * width + x
			if index < 0 or index >= cells.size() or not cells[index] is Dictionary:
				continue
			var cell := cells[index] as Dictionary
			if cell.get("visibility", -1) == Types.CellVisibility.COVERED:
				result.append(Vector2i(x, y))
	return result
