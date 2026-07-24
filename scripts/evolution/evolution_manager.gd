class_name EvolutionManager
extends RefCounted

signal state_changed(new_state: int)
signal progress_changed(completed: int, total: int)
signal generation_completed(result)

enum State {
	IDLE, CREATING_POPULATION, PREPARING_SCENARIOS, EVALUATING, RANKING,
	VALIDATING_CHAMPION, BREEDING, GENERATION_COMPLETE, PAUSED, STOPPED, ERROR,
}

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Suite := preload("res://scripts/simulation/evaluation_suite.gd")
const Evaluator := preload("res://scripts/evolution/fitness_evaluator.gd")
const Generation := preload("res://scripts/evolution/generation_result.gd")
const Network := preload("res://scripts/neural/neural_network.gd")

var state: int = State.IDLE
var config: Config
var algorithm: Algorithm = Algorithm.new()
var evaluator: Evaluator = Evaluator.new()
var population: Population
var training_suite: Suite
var validation_suite: Suite
var global_champion: Individual
var history: Array[Generation] = []
var evaluation_index: int = 0
var last_error: String = ""
var _generation_started_usec: int = 0
var _paused_from_state: int = State.IDLE


func initialize(evolution_config: Config = null) -> bool:
	config = evolution_config.duplicate_config() if is_instance_valid(evolution_config) else Config.new()
	if not algorithm.configure(config):
		fail(algorithm.last_error)
		return false
	evaluator.configure(config)
	_set_state(State.CREATING_POPULATION)
	population = algorithm.create_initial_population()
	validation_suite = Suite.create_deterministic(
		"validation-fixed", config.validation_scenario_count, config.master_seed, -1,
		config.board_width, config.board_height, config.mine_count
	)
	history.clear()
	global_champion = null
	_set_state(State.IDLE)
	return true


func begin_generation() -> bool:
	if not is_instance_valid(population) or state not in [State.IDLE, State.GENERATION_COMPLETE]:
		return false
	_set_state(State.PREPARING_SCENARIOS)
	training_suite = Suite.create_deterministic(
		"training-g%04d" % population.generation, config.training_scenario_count,
		config.master_seed, population.generation, config.board_width, config.board_height, config.mine_count
	)
	evaluation_index = 0
	_generation_started_usec = Time.get_ticks_usec()
	_set_state(State.EVALUATING)
	progress_changed.emit(0, population.individuals.size())
	return true


func process_evaluation_chunk(individual_count: int = 1) -> bool:
	if state != State.EVALUATING:
		return false
	var limit: int = mini(population.individuals.size(), evaluation_index + maxi(1, individual_count))
	while evaluation_index < limit:
		evaluator.evaluate_individual(population.individuals[evaluation_index], training_suite, false)
		evaluation_index += 1
		progress_changed.emit(evaluation_index, population.individuals.size())
	if evaluation_index >= population.individuals.size():
		_finish_generation()
	return true


func run_generation_sync() -> Generation:
	if not begin_generation():
		return null
	while state == State.EVALUATING:
		process_evaluation_chunk(population.individuals.size())
	return history.back() if not history.is_empty() else null


func breed_next_generation() -> bool:
	if state != State.GENERATION_COMPLETE:
		return false
	_set_state(State.BREEDING)
	var next: Population = algorithm.breed_next_generation(population)
	if not is_instance_valid(next):
		fail(algorithm.last_error)
		return false
	population = next
	_set_state(State.IDLE)
	return true


func pause() -> void:
	if state in [State.EVALUATING, State.PREPARING_SCENARIOS, State.BREEDING]:
		_paused_from_state = state
		_set_state(State.PAUSED)


func resume() -> void:
	if state == State.PAUSED:
		_set_state(_paused_from_state)


func stop() -> void:
	_set_state(State.STOPPED)


func fail(message: String) -> void:
	last_error = message
	_set_state(State.ERROR)


func get_champion() -> Individual:
	return population.get_champion() if is_instance_valid(population) else null


func get_state_text() -> String:
	return State.keys()[state].capitalize().replace("_", " ")


func _finish_generation() -> void:
	_set_state(State.RANKING)
	population.sort_by_fitness()
	var champion: Individual = population.get_champion()
	_set_state(State.VALIDATING_CHAMPION)
	evaluator.evaluate_individual(champion, validation_suite, true)
	if not is_instance_valid(global_champion) or _is_better_global(champion, global_champion):
		global_champion = champion.duplicate_individual(champion.identifier)
	var result := Generation.new()
	result.generation = population.generation
	result.champion_identifier = champion.identifier
	result.champion_training = champion.training_summary.duplicate(true)
	result.champion_validation = champion.validation_summary.duplicate(true)
	var fitness_sum: float = 0.0
	for individual: Individual in population.individuals:
		fitness_sum += individual.fitness_average
	result.population_average_fitness = fitness_sum / float(population.individuals.size())
	result.population_best_fitness = champion.fitness_average
	result.population_worst_fitness = population.individuals.back().fitness_average
	var middle: int = population.individuals.size() / 2
	result.population_median_fitness = (
		(population.individuals[middle - 1].fitness_average + population.individuals[middle].fitness_average) * 0.5
		if population.individuals.size() % 2 == 0 else population.individuals[middle].fitness_average
	)
	result.diversity = population.get_diversity_metrics()
	result.training_scenarios = training_suite.get_identifiers()
	result.elapsed_seconds = float(Time.get_ticks_usec() - _generation_started_usec) / 1000000.0
	history.append(result)
	_set_state(State.GENERATION_COMPLETE)
	generation_completed.emit(result)


static func _is_better_global(candidate: Individual, incumbent: Individual) -> bool:
	var first: Dictionary = candidate.validation_summary
	var second: Dictionary = incumbent.validation_summary
	if float(first.get("fitness_average", -INF)) != float(second.get("fitness_average", -INF)):
		return float(first.get("fitness_average", -INF)) > float(second.get("fitness_average", -INF))
	if int(first.get("victories", 0)) != int(second.get("victories", 0)):
		return int(first.get("victories", 0)) > int(second.get("victories", 0))
	if float(first.get("average_progress", 0.0)) != float(second.get("average_progress", 0.0)):
		return float(first.get("average_progress", 0.0)) > float(second.get("average_progress", 0.0))
	return float(first.get("average_moves", INF)) < float(second.get("average_moves", INF))


func _set_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(state)
