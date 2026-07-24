class_name RandomAgent
extends MinesweeperAgent

const Types := preload("res://scripts/core/minesweeper_types.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset() -> void:
	_rng.seed = agent_seed


func choose_action(visible_board_state: Dictionary) -> AgentAction:
	var candidates: Array[Vector2i] = []
	var cells: Array = visible_board_state.get("cells", [])
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			continue
		var cell := cell_value as Dictionary
		if cell.get("visibility", -1) == Types.CellVisibility.COVERED:
			candidates.append(cell.get("position", Vector2i(-1, -1)))
	if candidates.is_empty():
		return null
	var chosen_index: int = _rng.randi_range(0, candidates.size() - 1)
	return AgentAction.reveal(candidates[chosen_index], {"agent": "random"})


func get_display_name() -> String:
	return "Aleatório"
