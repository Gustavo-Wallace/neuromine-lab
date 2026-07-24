class_name AgentAction
extends RefCounted

enum ActionType {
	REVEAL_CELL,
	PLACE_FLAG,
	REMOVE_FLAG,
}

var type: int = ActionType.REVEAL_CELL
var position: Vector2i = Vector2i(-1, -1)
var metadata: Dictionary = {}


func _init(action_type: int = ActionType.REVEAL_CELL, cell_position: Vector2i = Vector2i(-1, -1), action_metadata: Dictionary = {}) -> void:
	type = action_type
	position = cell_position
	metadata = action_metadata.duplicate(true)


static func reveal(cell_position: Vector2i, action_metadata: Dictionary = {}) -> AgentAction:
	return AgentAction.new(ActionType.REVEAL_CELL, cell_position, action_metadata)


func to_dictionary() -> Dictionary:
	return {
		"type": type,
		"position": position,
		"metadata": metadata.duplicate(true),
	}
