class_name MinesweeperAgent
extends RefCounted

var agent_seed: int = 0


func configure(random_seed: int) -> void:
	agent_seed = random_seed
	reset()


func reset() -> void:
	pass


func choose_action(_visible_board_state: Dictionary) -> AgentAction:
	return null


func get_display_name() -> String:
	return "Agente base"


func get_result_metadata() -> Dictionary:
	return {
		"agent_type": get_display_name(),
		"agent_seed": agent_seed,
	}
