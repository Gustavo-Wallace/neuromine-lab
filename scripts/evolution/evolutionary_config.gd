class_name EvolutionaryConfig
extends RefCounted

const NetworkConfig := preload("res://scripts/neural/neural_network_config.gd")

var population_size: int = 48
var elite_count: int = 4
var training_scenario_count: int = 8
var validation_scenario_count: int = 20
var tournament_size: int = 3
var crossover_probability: float = 0.70
var mutation_probability: float = 0.08
var mutation_strength: float = 0.15
var parameter_absolute_limit: float = 5.0
var master_seed: int = 47005001
var board_width: int = 6
var board_height: int = 6
var mine_count: int = 6
var first_reveal: Vector2i = Vector2i(3, 3)
var network_config: NetworkConfig = NetworkConfig.create_default()
var progress_fitness_scale: float = 1000.0
var victory_bonus: float = 10000.0
var victory_efficiency_scale: float = 1000.0
var invalid_action_penalty: float = 100.0
var invalid_end_penalty: float = 250.0
var mine_detonation_penalty: float = 100.0


func is_valid() -> bool:
	return (
		population_size >= 2 and elite_count >= 1 and elite_count < population_size
		and training_scenario_count >= 1 and validation_scenario_count >= 1
		and tournament_size >= 1 and tournament_size <= population_size
		and crossover_probability >= 0.0 and crossover_probability <= 1.0
		and mutation_probability >= 0.0 and mutation_probability <= 1.0
		and mutation_strength >= 0.0 and parameter_absolute_limit > 0.0
		and mine_count >= 0 and mine_count < board_width * board_height
		and first_reveal == Vector2i(board_width / 2, board_height / 2)
		and is_instance_valid(network_config) and network_config.is_valid()
		and progress_fitness_scale >= 0.0 and victory_bonus > progress_fitness_scale
	)


func duplicate_config():
	var copy = get_script().new()
	for property_name: String in [
		"population_size", "elite_count", "training_scenario_count", "validation_scenario_count",
		"tournament_size", "crossover_probability", "mutation_probability", "mutation_strength",
		"parameter_absolute_limit", "master_seed", "board_width", "board_height", "mine_count", "first_reveal",
		"progress_fitness_scale", "victory_bonus", "victory_efficiency_scale",
		"invalid_action_penalty", "invalid_end_penalty", "mine_detonation_penalty"
	]:
		copy.set(property_name, get(property_name))
	copy.network_config = network_config.duplicate_config()
	return copy
