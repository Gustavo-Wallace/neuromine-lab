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
	}
