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
const OutputAnalyzer := preload("res://scripts/evolution/neural_output_analyzer.gd")
const StagnationTracker := preload("res://scripts/evolution/stagnation_tracker.gd")

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
var generations_without_improvement: int = 0
var initial_network: Network
var stagnation_tracker: StagnationTracker = StagnationTracker.new()
var _generation_started_usec: int = 0
var _paused_from_state: int = State.IDLE


func initialize(evolution_config: Config = null) -> bool:
	config = evolution_config.duplicate_config() if is_instance_valid(evolution_config) else Config.new()
	if not algorithm.configure(config):
		fail(algorithm.last_error)
		return false
	evaluator.configure(config)
	stagnation_tracker.configure(config.stagnation_limit, config.relevant_improvement_epsilon)
	_set_state(State.CREATING_POPULATION)
	population = algorithm.create_initial_population()
	initial_network = population.individuals[0].network.clone_network()
	training_suite = Suite.create_deterministic(
		"training-fixed", config.training_scenario_count, config.master_seed, 0,
		config.board_width, config.board_height, config.mine_count
	)
	validation_suite = Suite.create_deterministic(
		"validation-fixed", config.validation_scenario_count, config.master_seed, -1,
		config.board_width, config.board_height, config.mine_count
	)
	history.clear()
	global_champion = null
	generations_without_improvement = 0
	_set_state(State.IDLE)
	return true


func begin_generation() -> bool:
	if not is_instance_valid(population) or state not in [State.IDLE, State.GENERATION_COMPLETE]:
		return false
	_set_state(State.PREPARING_SCENARIOS)
	if not config.fixed_training_suite:
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


func is_stagnated() -> bool:
	return stagnation_tracker.is_stagnated()


func get_baseline_comparison() -> Dictionary:
	var comparison: Dictionary = {
		"suite_identifiers": validation_suite.get_identifiers(),
		"random": evaluator.evaluate_random_agent(validation_suite, config.master_seed + 8000),
		"untrained_neural": evaluator.evaluate_neural_network(initial_network, validation_suite),
	}
	if is_instance_valid(get_champion()):
		comparison["generation_champion"] = evaluator.evaluate_neural_network(get_champion().network, validation_suite)
	if is_instance_valid(global_champion):
		comparison["global_champion"] = global_champion.validation_summary.duplicate(true)
	return comparison


func _finish_generation() -> void:
	_set_state(State.RANKING)
	population.sort_by_fitness()
	var champion: Individual = population.get_champion()
	_set_state(State.VALIDATING_CHAMPION)
	evaluator.evaluate_individual(champion, validation_suite, true)
	var relevant_improvement: bool = stagnation_tracker.record(champion.validation_summary.fitness_average)
	if not is_instance_valid(global_champion) or _is_better_global(champion, global_champion):
		global_champion = champion.duplicate_individual(champion.identifier)
	generations_without_improvement = stagnation_tracker.generations_without_improvement
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
	result.validation_improved = relevant_improvement
	result.generations_without_improvement = generations_without_improvement
	var mutation_total: int = 0
	var offspring_count: int = 0
	var range_total: float = 0.0
	var stddev_total: float = 0.0
	var equal_total: float = 0.0
	var score_mean_total: float = 0.0
	var non_finite_total: int = 0
	var first_decision_set: Dictionary = {}
	for individual: Individual in population.individuals:
		if individual.lineage.origin == "offspring":
			mutation_total += individual.lineage.mutation_count
			offspring_count += 1
		var telemetry: Dictionary = individual.training_summary.get("neural_telemetry", {})
		range_total += float(telemetry.get("mean_score_range", 0.0))
		stddev_total += float(telemetry.get("score_stddev", 0.0))
		equal_total += float(telemetry.get("mean_near_equal_candidates", 0.0))
		score_mean_total += float(telemetry.get("score_mean", 0.0))
		non_finite_total += int(telemetry.get("non_finite_count", 0))
		for position: Vector2i in telemetry.get("first_decisions", []): first_decision_set[position] = true
	result.average_mutated_parameters = float(mutation_total) / float(maxi(1, offspring_count))
	var population_count: float = float(population.individuals.size())
	result.neural_output_metrics = {
		"mean_score_range": range_total / population_count,
		"score_stddev": stddev_total / population_count,
		"mean_near_equal_candidates": equal_total / population_count,
		"score_mean": score_mean_total / population_count,
		"non_finite_count": non_finite_total,
	}
	result.neural_output_condition = OutputAnalyzer.classify(result.neural_output_metrics)
	result.distinct_first_decisions = first_decision_set.size()
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
