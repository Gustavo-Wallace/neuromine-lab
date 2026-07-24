class_name EvolutionaryConfig
extends RefCounted

const NetworkConfig := preload("res://scripts/neural/neural_network_config.gd")

enum Preset { CALIBRATION_NO_CROSSOVER, ORIGINAL }
enum BoardEnvironment { CALIBRATION_5X5, MAIN_6X6 }

var preset: int = Preset.CALIBRATION_NO_CROSSOVER
var preset_name: String = "CALIBRAÇÃO SEM CROSSOVER"
var environment: int = BoardEnvironment.MAIN_6X6
var environment_name: String = "Principal 6×6 / 6 minas"
var population_size: int = 96
var elite_count: int = 8
var training_scenario_count: int = 12
var validation_scenario_count: int = 30
var tournament_size: int = 4
var crossover_enabled: bool = false
var crossover_probability: float = 0.0
var mutation_probability: float = 0.02
var mutation_strength: float = 0.08
var parameter_absolute_limit: float = 5.0
var master_seed: int = 47006001
var board_width: int = 6
var board_height: int = 6
var mine_count: int = 6
var first_reveal: Vector2i = Vector2i(3, 3)
var network_config: NetworkConfig = NetworkConfig.create_default()
var fixed_training_suite: bool = true
var linear_progress_fitness: bool = true
var progress_fitness_scale: float = 1500.0
var safe_decision_bonus: float = 30.0
var victory_bonus: float = 10000.0
var victory_efficiency_scale: float = 1000.0
var invalid_action_penalty: float = 500.0
var invalid_end_penalty: float = 500.0
var mine_detonation_penalty: float = 250.0
var stagnation_limit: int = 15
var relevant_improvement_epsilon: float = 0.000001
var equal_score_tolerance: float = 0.0001


static func create_calibrated(environment_kind: int = BoardEnvironment.MAIN_6X6):
	var config = new()
	config.apply_environment(environment_kind)
	return config


static func create_original(environment_kind: int = BoardEnvironment.MAIN_6X6):
	var config = new()
	config.preset = Preset.ORIGINAL
	config.preset_name = "CONFIGURAÇÃO ORIGINAL"
	config.population_size = 48
	config.elite_count = 4
	config.training_scenario_count = 8
	config.validation_scenario_count = 20
	config.tournament_size = 3
	config.crossover_enabled = true
	config.crossover_probability = 0.70
	config.mutation_probability = 0.08
	config.mutation_strength = 0.15
	config.fixed_training_suite = false
	config.linear_progress_fitness = false
	config.progress_fitness_scale = 1000.0
	config.safe_decision_bonus = 0.0
	config.invalid_action_penalty = 100.0
	config.invalid_end_penalty = 250.0
	config.mine_detonation_penalty = 100.0
	config.apply_environment(environment_kind)
	return config


func apply_environment(environment_kind: int) -> void:
	environment = environment_kind
	if environment == BoardEnvironment.CALIBRATION_5X5:
		environment_name = "Calibração 5×5 / 3 minas"
		board_width = 5
		board_height = 5
		mine_count = 3
	else:
		environment_name = "Principal 6×6 / 6 minas"
		board_width = 6
		board_height = 6
		mine_count = 6
	first_reveal = Vector2i(board_width / 2, board_height / 2)


func get_experiment_identifier() -> String:
	return "%s|%s|master=%d" % [preset_name, environment_name, master_seed]


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
		and stagnation_limit > 0 and equal_score_tolerance >= 0.0
	)


func duplicate_config():
	var copy = get_script().new()
	for property_name: String in [
		"preset", "preset_name", "environment", "environment_name", "population_size", "elite_count",
		"training_scenario_count", "validation_scenario_count", "tournament_size", "crossover_enabled",
		"crossover_probability", "mutation_probability", "mutation_strength", "parameter_absolute_limit",
		"master_seed", "board_width", "board_height", "mine_count", "first_reveal", "fixed_training_suite",
		"linear_progress_fitness", "progress_fitness_scale", "safe_decision_bonus", "victory_bonus",
		"victory_efficiency_scale", "invalid_action_penalty", "invalid_end_penalty",
		"mine_detonation_penalty", "stagnation_limit", "relevant_improvement_epsilon", "equal_score_tolerance"
	]:
		copy.set(property_name, get(property_name))
	copy.network_config = network_config.duplicate_config()
	return copy
