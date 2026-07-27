class_name EvolutionManager
extends RefCounted

signal state_changed(new_state: int)
signal progress_changed(completed: int, total: int)
signal generation_completed(result)
signal phase_changed(phase_index: int)

enum State { IDLE, CREATING_POPULATION, PREPARING_SCENARIOS, EVALUATING, RANKING, VALIDATING_CHAMPION, BREEDING, GENERATION_COMPLETE, PAUSED, STOPPED, ERROR }

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Suite := preload("res://scripts/simulation/evaluation_suite.gd")
const CurriculumScenarios := preload("res://scripts/simulation/curriculum_scenario_manager.gd")
const Phase := preload("res://scripts/evolution/curriculum_phase.gd")
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
var final_test_suite: Suite
var global_champion: Individual
var history: Array[Generation] = []
var events: Array[Dictionary] = []
var evaluation_index: int = 0
var last_error: String = ""
var generations_without_improvement: int = 0
var initial_network: Network
var stagnation_tracker: StagnationTracker = StagnationTracker.new()
var phases: Array[Phase] = []
var current_phase_index: int = 1
var global_generation: int = 1
var phase_generation: int = 1
var automatic_advancement_blocked: bool = false
var scenario_manager: CurriculumScenarios
var phase_baselines: Dictionary = {}
var last_phase_criteria: Dictionary = {}
var final_test_execution_count: int = 0
var final_test_result: Dictionary = {}
var saved_experiment_summary: Dictionary = {}
var _generation_started_usec: int = 0
var _paused_from_state: int = State.IDLE


func initialize(evolution_config: Config = null) -> bool:
	config = evolution_config.duplicate_config() if is_instance_valid(evolution_config) else Config.create_curriculum()
	phases = Phase.create_all()
	current_phase_index = clampi(config.curriculum_start_phase, 1, phases.size()) if config.curriculum_enabled else 1
	global_generation = 1; phase_generation = 1
	if config.curriculum_enabled: get_current_phase().apply_to_config(config)
	if not algorithm.configure(config): fail(algorithm.last_error); return false
	algorithm.set_generation_context(current_phase_index, phase_generation, global_generation)
	evaluator.configure(config)
	stagnation_tracker.configure(config.stagnation_limit, config.relevant_improvement_epsilon)
	_set_state(State.CREATING_POPULATION)
	population = algorithm.create_initial_population()
	initial_network = population.individuals[0].network.clone_network()
	_prepare_phase_scenarios()
	history.clear(); events.clear(); global_champion = null; generations_without_improvement = 0
	phase_baselines.clear(); last_phase_criteria.clear(); final_test_execution_count = 0; final_test_result.clear()
	_set_state(State.IDLE)
	return true


func begin_generation() -> bool:
	if not is_instance_valid(population) or state not in [State.IDLE, State.GENERATION_COMPLETE]: return false
	_set_state(State.PREPARING_SCENARIOS)
	if config.curriculum_enabled:
		training_suite = scenario_manager.create_training_suite(phase_generation)
	elif not config.fixed_training_suite:
		training_suite = Suite.create_deterministic("training-g%04d" % population.generation, config.training_scenario_count, config.master_seed, population.generation, config.board_width, config.board_height, config.mine_count)
	evaluation_index = 0; _generation_started_usec = Time.get_ticks_usec(); _set_state(State.EVALUATING)
	progress_changed.emit(0, population.individuals.size())
	return true


func process_evaluation_chunk(individual_count: int = 1) -> bool:
	if state != State.EVALUATING: return false
	var limit: int = mini(population.individuals.size(), evaluation_index + maxi(1, individual_count))
	while evaluation_index < limit:
		evaluator.evaluate_individual(population.individuals[evaluation_index], training_suite, false)
		evaluation_index += 1; progress_changed.emit(evaluation_index, population.individuals.size())
	if evaluation_index >= population.individuals.size(): _finish_generation()
	return true


func run_generation_sync() -> Generation:
	if not begin_generation(): return null
	while state == State.EVALUATING: process_evaluation_chunk(population.individuals.size())
	return history.back() if not history.is_empty() else null


func breed_next_generation() -> bool:
	if state != State.GENERATION_COMPLETE: return false
	_set_state(State.BREEDING)
	var next: Population = algorithm.breed_next_generation(population)
	if not is_instance_valid(next): fail(algorithm.last_error); return false
	population = next; global_generation = population.generation; phase_generation += 1
	_set_state(State.IDLE)
	return true


func advance_phase(manual: bool = true) -> bool:
	if not config.curriculum_enabled or current_phase_index >= phases.size(): return false
	var previous_phase: int = current_phase_index; var previous_champion: String = global_champion.identifier if is_instance_valid(global_champion) else ""
	current_phase_index += 1; global_generation += 1; phase_generation = 1
	get_current_phase().apply_to_config(config); evaluator.configure(config); algorithm.config = config.duplicate_config()
	population = algorithm.transfer_population(population, current_phase_index, global_generation)
	_prepare_phase_scenarios(); global_champion = null; phase_baselines.clear(); stagnation_tracker.configure(config.stagnation_limit, config.relevant_improvement_epsilon); generations_without_improvement = 0
	events.append({"type": "phase_change", "global_generation": global_generation, "from_phase": previous_phase, "to_phase": current_phase_index, "manual": manual, "previous_champion": previous_champion, "transfer": algorithm.last_breeding_metrics.duplicate(true)})
	_set_state(State.IDLE); phase_changed.emit(current_phase_index)
	return true


func restart_current_phase() -> void:
	global_generation += 1; phase_generation = 1; algorithm.set_generation_context(current_phase_index, phase_generation, global_generation)
	population = algorithm.create_initial_population(); global_champion = null; phase_baselines.clear(); stagnation_tracker.reset(); generations_without_improvement = 0
	events.append({"type": "phase_restart", "global_generation": global_generation, "phase": current_phase_index})
	_set_state(State.IDLE)


func inject_diversity() -> Dictionary:
	if state not in [State.IDLE, State.GENERATION_COMPLETE]: return {}
	var outcome: Dictionary = algorithm.inject_diversity(population)
	events.append({"type": "diversity_injection", "global_generation": global_generation, "phase": current_phase_index, "outcome": outcome.duplicate(true)})
	_set_state(State.IDLE)
	return outcome


func execute_final_test() -> Dictionary:
	var champion: Individual = global_champion if is_instance_valid(global_champion) else get_champion()
	if not is_instance_valid(champion) or not is_instance_valid(final_test_suite): return {}
	final_test_execution_count += 1
	var champion_summary: Dictionary = evaluator.evaluate_neural_network(champion.network, final_test_suite)
	var random_summary: Dictionary = evaluator.evaluate_random_agent(final_test_suite, config.master_seed + 99000)
	var neural_summary: Dictionary = evaluator.evaluate_neural_network(initial_network, final_test_suite)
	final_test_result = {
		"execution_count": final_test_execution_count, "suite_identifiers": final_test_suite.get_identifiers(),
		"champion": champion_summary, "random": random_summary, "untrained_neural": neural_summary,
		"validation_difference": champion_summary.fitness_average - champion.validation_summary.get("fitness_average", 0.0),
	}
	events.append({"type": "final_test", "global_generation": global_generation, "phase": current_phase_index, "execution_count": final_test_execution_count})
	return final_test_result.duplicate(true)


func get_baseline_comparison() -> Dictionary:
	_ensure_phase_baselines()
	var comparison: Dictionary = {"suite_identifiers": validation_suite.get_identifiers(), "random": phase_baselines.random, "untrained_neural": phase_baselines.untrained_neural}
	if is_instance_valid(get_champion()): comparison["generation_champion"] = evaluator.evaluate_neural_network(get_champion().network, validation_suite)
	if is_instance_valid(global_champion): comparison["global_champion"] = global_champion.validation_summary.duplicate(true)
	return comparison


func create_experiment_summary() -> Dictionary:
	var first_victory_generation: int = -1; var stagnant_generations: int = 0
	for result: Generation in history:
		if first_victory_generation < 0 and int(result.champion_validation.get("victories", 0)) > 0: first_victory_generation = result.global_generation
		if result.generations_without_improvement >= config.stagnation_limit: stagnant_generations += 1
	var latest: Generation = history.back() if not history.is_empty() else null
	return {
		"preset": config.preset_name, "master_seed": config.master_seed, "phase": current_phase_index,
		"generation_count": history.size(), "best_validation": global_champion.validation_summary.get("fitness_average", 0.0) if is_instance_valid(global_champion) else 0.0,
		"final_validation": latest.champion_validation.get("fitness_average", 0.0) if is_instance_valid(latest) else 0.0,
		"victories": latest.champion_validation.get("victories", 0) if is_instance_valid(latest) else 0,
		"final_diversity": latest.diversity.get("mean_parameter_stddev", 0.0) if is_instance_valid(latest) else 0.0,
		"generalization_gap": latest.generalization_gap if is_instance_valid(latest) else 0.0,
		"total_seconds": _history_time(), "first_victory_generation": first_victory_generation, "stagnant_generations": stagnant_generations,
	}


func pause() -> void:
	if state in [State.EVALUATING, State.PREPARING_SCENARIOS, State.BREEDING]: _paused_from_state = state; _set_state(State.PAUSED)
func resume() -> void:
	if state == State.PAUSED: _set_state(_paused_from_state)
func stop() -> void: _set_state(State.STOPPED)
func fail(message: String) -> void: last_error = message; _set_state(State.ERROR)
func get_champion() -> Individual: return population.get_champion() if is_instance_valid(population) else null
func get_state_text() -> String: return State.keys()[state].capitalize().replace("_", " ")
func is_stagnated() -> bool: return stagnation_tracker.is_stagnated()
func get_current_phase() -> Phase: return phases[current_phase_index - 1]
func get_next_phase() -> Phase: return phases[current_phase_index] if current_phase_index < phases.size() else null


func _prepare_phase_scenarios() -> void:
	if config.curriculum_enabled:
		scenario_manager = CurriculumScenarios.new(); scenario_manager.configure(config, get_current_phase())
		training_suite = scenario_manager.create_training_suite(phase_generation); validation_suite = scenario_manager.validation_suite; final_test_suite = scenario_manager.final_test_suite
	else:
		training_suite = Suite.create_deterministic("training-fixed", config.training_scenario_count, config.master_seed, 0, config.board_width, config.board_height, config.mine_count)
		var compatible_phase: Phase = phases[2]
		for candidate: Phase in phases:
			if candidate.width == config.board_width and candidate.height == config.board_height and candidate.mine_count == config.mine_count: compatible_phase = candidate; break
		scenario_manager = CurriculumScenarios.new(); scenario_manager.configure(config, compatible_phase)
		validation_suite = scenario_manager.validation_suite; final_test_suite = scenario_manager.final_test_suite


func _finish_generation() -> void:
	_set_state(State.RANKING); population.sort_by_fitness(); var champion: Individual = population.get_champion()
	var phase_had_victory_before: bool = _phase_has_prior_victory()
	_set_state(State.VALIDATING_CHAMPION); evaluator.evaluate_individual(champion, validation_suite, true)
	var relevant_improvement: bool = stagnation_tracker.record(champion.validation_summary.fitness_average)
	var new_global: bool = not is_instance_valid(global_champion) or _is_better_global(champion, global_champion)
	if new_global: global_champion = champion.duplicate_individual(champion.identifier); events.append({"type": "global_champion", "global_generation": global_generation, "phase": current_phase_index, "identifier": champion.identifier})
	generations_without_improvement = stagnation_tracker.generations_without_improvement
	var result := Generation.new(); result.generation = population.generation; result.global_generation = global_generation; result.phase_generation = phase_generation; result.phase_index = current_phase_index
	result.champion_identifier = champion.identifier; result.champion_training = champion.training_summary.duplicate(true); result.champion_validation = champion.validation_summary.duplicate(true)
	var fitness_sum: float = 0.0
	for individual: Individual in population.individuals: fitness_sum += individual.fitness_average
	result.population_average_fitness = fitness_sum / float(population.individuals.size()); result.population_best_fitness = champion.fitness_average; result.population_worst_fitness = population.individuals.back().fitness_average
	var middle: int = population.individuals.size() / 2; result.population_median_fitness = (population.individuals[middle - 1].fitness_average + population.individuals[middle].fitness_average) * 0.5 if population.individuals.size() % 2 == 0 else population.individuals[middle].fitness_average
	result.diversity = population.get_diversity_metrics(); result.diversity_after_evaluation = result.diversity.duplicate(true); result.breeding_metrics = algorithm.last_breeding_metrics.duplicate(true)
	result.training_scenarios = training_suite.get_identifiers(); result.validation_improved = relevant_improvement; result.generations_without_improvement = generations_without_improvement
	_fill_neural_and_mutation_metrics(result)
	result.generalization_gap = champion.training_summary.get("selection_fitness", champion.fitness_average) - champion.validation_summary.get("selection_fitness", champion.validation_summary.get("fitness_average", 0.0))
	var validation_value: float = maxf(1.0, absf(champion.validation_summary.get("selection_fitness", 0.0))); result.generalization_gap_percent = 100.0 * result.generalization_gap / validation_value; result.generalization_classification = classify_generalization_gap(result.generalization_gap_percent)
	result.core_fitness = champion.training_summary.get("core_fitness", 0.0); result.rotating_fitness = champion.training_summary.get("rotating_fitness", 0.0)
	result.elapsed_seconds = float(Time.get_ticks_usec() - _generation_started_usec) / 1000000.0; history.append(result)
	if int(champion.validation_summary.get("victories", 0)) > 0 and not phase_had_victory_before: events.append({"type": "first_victory", "global_generation": global_generation, "phase": current_phase_index})
	if config.curriculum_enabled: _update_phase_criteria(champion)
	_set_state(State.GENERATION_COMPLETE); generation_completed.emit(result)
	if config.curriculum_enabled and config.automatic_phase_advancement and not automatic_advancement_blocked and bool(last_phase_criteria.get("all_met", false)): advance_phase(false)


func _fill_neural_and_mutation_metrics(result: Generation) -> void:
	var mutation_total: int = 0; var offspring_count: int = 0; var range_total: float = 0.0; var stddev_total: float = 0.0; var equal_total: float = 0.0; var score_mean_total: float = 0.0; var non_finite_total: int = 0; var first_decision_set: Dictionary = {}
	for individual: Individual in population.individuals:
		if "offspring" in individual.lineage.origin or "descendant" in individual.lineage.origin: mutation_total += individual.lineage.mutation_count; offspring_count += 1
		var telemetry: Dictionary = individual.training_summary.get("neural_telemetry", {}); range_total += telemetry.get("mean_score_range", 0.0); stddev_total += telemetry.get("score_stddev", 0.0); equal_total += telemetry.get("mean_near_equal_candidates", 0.0); score_mean_total += telemetry.get("score_mean", 0.0); non_finite_total += telemetry.get("non_finite_count", 0)
		for position: Vector2i in telemetry.get("first_decisions", []): first_decision_set[position] = true
	result.average_mutated_parameters = float(mutation_total) / float(maxi(1, offspring_count)); var count: float = float(population.individuals.size())
	result.neural_output_metrics = {"mean_score_range": range_total / count, "score_stddev": stddev_total / count, "mean_near_equal_candidates": equal_total / count, "score_mean": score_mean_total / count, "non_finite_count": non_finite_total}
	result.neural_output_condition = OutputAnalyzer.classify(result.neural_output_metrics); result.distinct_first_decisions = first_decision_set.size()


func _update_phase_criteria(champion: Individual) -> void:
	_ensure_phase_baselines(); last_phase_criteria = get_current_phase().criteria_status(phase_generation, champion.validation_summary, phase_baselines)


func _ensure_phase_baselines() -> void:
	if not phase_baselines.is_empty(): return
	phase_baselines = {"random": evaluator.evaluate_random_agent(validation_suite, config.master_seed + current_phase_index * 8000), "untrained_neural": evaluator.evaluate_neural_network(initial_network, validation_suite)}


func classify_generalization_gap(percent: float) -> String:
	var magnitude: float = maxf(0.0, percent)
	if magnitude < config.overfit_attention_percent: return "saudável"
	if magnitude < config.overfit_probable_percent: return "atenção"
	if magnitude < config.overfit_severe_percent: return "sobreajuste provável"
	return "sobreajuste severo"


func _phase_has_prior_victory() -> bool:
	for result: Generation in history:
		if result.phase_index == current_phase_index and int(result.champion_validation.get("victories", 0)) > 0: return true
	return false


func _history_time() -> float:
	var total: float = 0.0
	for result: Generation in history: total += result.elapsed_seconds
	return total


static func _is_better_global(candidate: Individual, incumbent: Individual) -> bool:
	var first: Dictionary = candidate.validation_summary; var second: Dictionary = incumbent.validation_summary
	if float(first.get("fitness_average", -INF)) != float(second.get("fitness_average", -INF)): return float(first.get("fitness_average", -INF)) > float(second.get("fitness_average", -INF))
	if int(first.get("victories", 0)) != int(second.get("victories", 0)): return int(first.get("victories", 0)) > int(second.get("victories", 0))
	if float(first.get("average_progress", 0.0)) != float(second.get("average_progress", 0.0)): return float(first.get("average_progress", 0.0)) > float(second.get("average_progress", 0.0))
	return float(first.get("average_moves", INF)) < float(second.get("average_moves", INF))


func _set_state(new_state: int) -> void: state = new_state; state_changed.emit(state)
