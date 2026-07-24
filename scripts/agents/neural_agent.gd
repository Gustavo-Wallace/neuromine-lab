class_name NeuralAgent
extends MinesweeperAgent

const Provider := preload("res://scripts/observation/candidate_provider.gd")
const Encoder := preload("res://scripts/observation/observation_encoder.gd")
const Config := preload("res://scripts/neural/neural_network_config.gd")
const Network := preload("res://scripts/neural/neural_network.gd")
const Score := preload("res://scripts/agents/candidate_score.gd")
const ObservationData := preload("res://scripts/observation/candidate_observation.gd")
const ObservationSchema := preload("res://scripts/observation/observation_schema.gd")

var network: Network
var network_seed: int = 0
var agent_identifier: String = "neural-random"
var debug_enabled: bool = false
var last_ranking: Array[Score] = []
var last_chosen_candidate: Vector2i = Vector2i(-1, -1)
var last_chosen_score: float = 0.0

var _encoder: Encoder = Encoder.new()


func configure(random_seed: int) -> void:
	configure_neural(random_seed, false)


func configure_neural(seed: int, enable_debug: bool = false, network_config: Config = null) -> bool:
	agent_seed = seed
	network_seed = seed
	debug_enabled = enable_debug
	network = Network.new()
	var selected_config: Config = network_config if is_instance_valid(network_config) else Config.create_default()
	var configured: bool = network.configure(selected_config, network_seed)
	reset()
	return configured


func set_network(custom_network: Network, enable_debug: bool = false) -> void:
	network = custom_network
	network_seed = custom_network.network_seed
	agent_seed = network_seed
	debug_enabled = enable_debug
	reset()


func reset() -> void:
	last_ranking.clear()
	last_chosen_candidate = Vector2i(-1, -1)
	last_chosen_score = 0.0


func choose_action(visible_board_state: Dictionary) -> AgentAction:
	last_ranking.clear()
	last_chosen_candidate = Vector2i(-1, -1)
	last_chosen_score = 0.0
	if not is_instance_valid(network):
		return null
	var candidates: Array[Vector2i] = Provider.get_candidates(visible_board_state)
	if candidates.is_empty():
		return null
	var scored_candidates: Array[Score] = []
	for provider_index: int in range(candidates.size()):
		var candidate_position: Vector2i = candidates[provider_index]
		var observation: ObservationData = _encoder.encode_candidate(
			visible_board_state, candidate_position, debug_enabled
		)
		var output: PackedFloat32Array = network.forward(observation.get_vector(), false)
		if output.size() != 1:
			continue
		var retained_observation: ObservationData = observation if debug_enabled else null
		scored_candidates.append(Score.new(candidate_position, output[0], provider_index, retained_observation))
	if scored_candidates.is_empty():
		return null
	scored_candidates.sort_custom(_score_precedes)
	for ranking_index: int in range(scored_candidates.size()):
		scored_candidates[ranking_index].ranking_index = ranking_index + 1
	var winner: Score = scored_candidates[0]
	last_chosen_candidate = winner.candidate_position
	last_chosen_score = winner.raw_score
	if debug_enabled:
		last_ranking.assign(scored_candidates)
	return AgentAction.reveal(winner.candidate_position, {
		"agent": agent_identifier,
		"network_seed": network_seed,
		"score": winner.raw_score,
	})


func get_display_name() -> String:
	return "Neural aleatório"


func get_result_metadata() -> Dictionary:
	return {
		"agent_type": get_display_name(),
		"network_seed": network_seed,
		"architecture": network.config.architecture.duplicate(),
		"observation_schema_version": ObservationSchema.VERSION,
		"parameter_count": network.get_parameter_count(),
		"trained": false,
	}


func _score_precedes(first: Score, second: Score) -> bool:
	if first.raw_score == second.raw_score:
		return int(first.metadata.provider_index) < int(second.metadata.provider_index)
	return first.raw_score > second.raw_score
