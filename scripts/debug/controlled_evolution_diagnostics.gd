class_name ControlledEvolutionDiagnostics
extends RefCounted

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")


static func run_all() -> Dictionary:
	var config: Config = Config.create_calibrated(); config.population_size = 12; config.elite_count = 2
	config.tournament_size = 3; config.crossover_probability = 0.7
	config.mutation_probability = 1.0; config.mutation_strength = 0.5; config.master_seed = 99117
	var algorithm := Algorithm.new(); algorithm.configure(config)
	var population: Population = algorithm.create_initial_population()
	_score_toward_target(population)
	var initial_best: float = population.get_champion().fitness_average
	for generation: int in range(8):
		population = algorithm.breed_next_generation(population)
		_score_toward_target(population)
	var improved: bool = population.get_champion().fitness_average > initial_best
	var failures: Array[String] = []
	if not improved:
		failures.append("Evolução artificial não aumentou o melhor fitness")
		push_error("[NeuroMine Lab] " + failures[0])
	return {"passed": 1 - failures.size(), "failed": failures.size(), "failures": failures}


static func _score_toward_target(population: Population) -> void:
	for item: Individual in population.individuals:
		item.fitness_average = -absf(item.get_genome()[0] - 2.0)
	population.sort_by_fitness()
