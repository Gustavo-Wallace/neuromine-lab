class_name CandidateScore
extends RefCounted

const ObservationData := preload("res://scripts/observation/candidate_observation.gd")
const ActionData := preload("res://scripts/agents/agent_action.gd")

var candidate_position: Vector2i = Vector2i(-1, -1)
var raw_score: float = 0.0
var normalized_score: float = 0.0
var ranking_index: int = -1
var observation: ObservationData
var action: ActionData
var metadata: Dictionary = {}


func _init(
	position: Vector2i = Vector2i(-1, -1),
	score: float = 0.0,
	provider_index: int = -1,
	candidate_observation: ObservationData = null
) -> void:
	candidate_position = position
	raw_score = score
	normalized_score = score
	observation = candidate_observation
	action = ActionData.reveal(position, {"agent": "neural"})
	metadata = {"provider_index": provider_index}


func duplicate_score(include_observation: bool = true):
	var copy = get_script().new(
		candidate_position,
		raw_score,
		int(metadata.get("provider_index", -1)),
		observation if include_observation else null
	)
	copy.normalized_score = normalized_score
	copy.ranking_index = ranking_index
	copy.metadata = metadata.duplicate(true)
	return copy
