class_name GenerationResult
extends RefCounted

var generation: int = 0
var champion_identifier: String = ""
var champion_training: Dictionary = {}
var champion_validation: Dictionary = {}
var population_average_fitness: float = 0.0
var population_best_fitness: float = 0.0
var population_median_fitness: float = 0.0
var population_worst_fitness: float = 0.0
var diversity: Dictionary = {}
var training_scenarios: Array[String] = []
var elapsed_seconds: float = 0.0
var average_mutated_parameters: float = 0.0
var neural_output_metrics: Dictionary = {}
var neural_output_condition: int = 0
var distinct_first_decisions: int = 0
var generations_without_improvement: int = 0
var validation_improved: bool = false


func to_dictionary() -> Dictionary:
	return {
		"generation": generation, "champion_identifier": champion_identifier,
		"champion_training": champion_training.duplicate(true),
		"champion_validation": champion_validation.duplicate(true),
		"population_average_fitness": population_average_fitness,
		"population_best_fitness": population_best_fitness,
		"population_median_fitness": population_median_fitness,
		"population_worst_fitness": population_worst_fitness,
		"diversity": diversity.duplicate(true),
		"training_scenarios": training_scenarios.duplicate(), "elapsed_seconds": elapsed_seconds,
		"average_mutated_parameters": average_mutated_parameters,
		"neural_output_metrics": neural_output_metrics.duplicate(true),
		"neural_output_condition": neural_output_condition,
		"distinct_first_decisions": distinct_first_decisions,
		"generations_without_improvement": generations_without_improvement,
		"validation_improved": validation_improved,
	}
