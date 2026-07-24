class_name SimulationResult
extends RefCounted

enum EndReason {
	VICTORY,
	MINE_DETONATED,
	NO_VALID_ACTIONS,
	MAX_ACTIONS_REACHED,
	INVALID_STATE,
	MANUALLY_STOPPED,
}

var victory: bool = false
var move_count: int = 0
var revealed_safe_cells: int = 0
var total_safe_cells: int = 0
var progress_percent: float = 0.0
var detonated_position: Vector2i = Vector2i(-1, -1)
var field_seed: int = 0
var agent_seed: int = 0
var first_move: Vector2i = Vector2i(-1, -1)
var scenario_identifier: String = ""
var end_reason: int = EndReason.INVALID_STATE
var duration_seconds: float = 0.0
var invalid_action_count: int = 0
var max_action_attempts: int = 0
var action_history: Array[Dictionary] = []
var agent_metadata: Dictionary = {}


static func reason_to_string(reason: int) -> String:
	match reason:
		EndReason.VICTORY:
			return "Vitória"
		EndReason.MINE_DETONATED:
			return "Mina detonada"
		EndReason.NO_VALID_ACTIONS:
			return "Sem ações válidas"
		EndReason.MAX_ACTIONS_REACHED:
			return "Limite de ações"
		EndReason.INVALID_STATE:
			return "Estado inválido"
		EndReason.MANUALLY_STOPPED:
			return "Interrompida manualmente"
	return "Desconhecido"


func to_dictionary(include_history: bool = false) -> Dictionary:
	var data := {
		"victory": victory,
		"move_count": move_count,
		"revealed_safe_cells": revealed_safe_cells,
		"total_safe_cells": total_safe_cells,
		"progress_percent": progress_percent,
		"detonated_position": detonated_position,
		"field_seed": field_seed,
		"agent_seed": agent_seed,
		"first_move": first_move,
		"scenario_identifier": scenario_identifier,
		"end_reason": end_reason,
		"duration_seconds": duration_seconds,
		"invalid_action_count": invalid_action_count,
		"max_action_attempts": max_action_attempts,
		"agent_metadata": agent_metadata.duplicate(true),
	}
	if include_history:
		data["action_history"] = action_history.duplicate(true)
	return data
