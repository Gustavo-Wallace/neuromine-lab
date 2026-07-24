class_name RandomAgent
extends MinesweeperAgent

const Provider := preload("res://scripts/observation/candidate_provider.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset() -> void:
	_rng.seed = agent_seed


func choose_action(visible_board_state: Dictionary) -> AgentAction:
	var candidates: Array[Vector2i] = Provider.get_candidates(visible_board_state)
	if candidates.is_empty():
		return null
	var chosen_index: int = _rng.randi_range(0, candidates.size() - 1)
	return AgentAction.reveal(candidates[chosen_index], {"agent": "random"})


func get_display_name() -> String:
	return "Aleatório"
