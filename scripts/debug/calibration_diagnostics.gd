class_name CalibrationDiagnostics
extends RefCounted

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Evaluator := preload("res://scripts/evolution/fitness_evaluator.gd")
const Result := preload("res://scripts/simulation/simulation_result.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const OutputAnalyzer := preload("res://scripts/evolution/neural_output_analyzer.gd")
const Stagnation := preload("res://scripts/evolution/stagnation_tracker.gd")
const Board := preload("res://scripts/core/minesweeper_board.gd")


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	var calibrated: Config = Config.create_calibrated()
	_test("Preset calibrado possui valores esperados", calibrated.population_size == 96 and calibrated.elite_count == 8 and calibrated.tournament_size == 4 and not calibrated.crossover_enabled and calibrated.mutation_probability == 0.02 and calibrated.mutation_strength == 0.08 and calibrated.training_scenario_count == 12 and calibrated.validation_scenario_count == 30, failures)
	var breeding_config: Config = calibrated.duplicate_config(); breeding_config.training_scenario_count = 1; breeding_config.validation_scenario_count = 1
	var algorithm := Algorithm.new(); algorithm.configure(breeding_config)
	var population: Population = algorithm.create_initial_population(); _assign_fitness(population)
	var next: Population = algorithm.breed_next_generation(population)
	var no_crossover: bool = true; var one_parent: bool = true; var mutation_total: int = 0; var offspring_count: int = 0
	for item: Individual in next.individuals:
		if item.lineage.origin == "offspring":
			no_crossover = no_crossover and not item.lineage.crossover_applied and item.lineage.inherited_from_b == 0
			one_parent = one_parent and not item.lineage.parent_a_identifier.is_empty() and item.lineage.parent_b_identifier.is_empty()
			mutation_total += item.lineage.mutation_count; offspring_count += 1
	_test("Crossover não ocorre no preset", no_crossover, failures)
	_test("Descendente possui um pai genético", one_parent, failures)
	var mutation_average: float = float(mutation_total) / float(offspring_count)
	_test("Mutações médias são compatíveis com 2%", mutation_average >= 30.0 and mutation_average <= 55.0, failures)
	var elites_identical: bool = true
	for index: int in range(calibrated.elite_count): elites_identical = elites_identical and next.individuals[index].get_genome() == population.individuals[index].get_genome()
	_test("Elites permanecem idênticos", elites_identical, failures)
	var small: Config = _small_calibrated(Config.ENV_MAIN_6X6)
	var fixed_manager := Manager.new(); fixed_manager.initialize(small); fixed_manager.run_generation_sync(); var training_ids: Array[String] = fixed_manager.training_suite.get_identifiers(); fixed_manager.breed_next_generation(); fixed_manager.run_generation_sync()
	_test("Suíte de treinamento permanece fixa", fixed_manager.training_suite.get_identifiers() == training_ids, failures)
	var validation_ids: Array[String] = fixed_manager.validation_suite.get_identifiers(); fixed_manager.breed_next_generation(); fixed_manager.run_generation_sync()
	_test("Suíte de validação permanece fixa", fixed_manager.validation_suite.get_identifiers() == validation_ids, failures)
	var comparison: Dictionary = fixed_manager.get_baseline_comparison()
	var validation_name: String = fixed_manager.validation_suite.suite_identifier
	_test("Baselines e campeão usam mesma validação", comparison.suite_identifiers == validation_ids and comparison.random.suite_identifier == validation_name and comparison.untrained_neural.suite_identifier == validation_name and comparison.generation_champion.suite_identifier == validation_name, failures)
	var scored_result := Result.new(); scored_result.total_safe_cells = 10; scored_result.revealed_safe_cells = 5; scored_result.safe_decision_count = 3; scored_result.max_action_attempts = 40; scored_result.end_reason = Result.EndReason.MINE_DETONATED
	var evaluator := Evaluator.new(); evaluator.configure(calibrated); var score: Dictionary = evaluator.score_result(scored_result)
	_test("Decisões seguras são contabilizadas", score.safe_decisions == 3, failures)
	_test("Fitness segue fórmula calibrada", is_equal_approx(score.fitness, 590.0), failures)
	var board := Board.new(); board.configure(6, 6, 6, 77); board.start_or_reveal_first(Vector2i(3, 3)); var hidden_safe: bool = true
	for cell: Dictionary in board.get_agent_observation().cells:
		if int(cell.visibility) != MinesweeperTypes.CellVisibility.REVEALED: hidden_safe = hidden_safe and not cell.has("has_mine")
	_test("Minas ocultas ficam fora da observação", hidden_safe and board.get_debug_board_state()[0].has("has_mine"), failures)
	var tracker := Stagnation.new(); tracker.configure(15, 0.001); tracker.record(10.0); tracker.record(10.0); tracker.record(9.0)
	_test("Detector contabiliza gerações sem melhoria", tracker.generations_without_improvement == 2, failures)
	tracker.record(11.0)
	_test("Melhoria reinicia estagnação", tracker.generations_without_improvement == 0, failures)
	_test("Saturação de saída é detectada", OutputAnalyzer.classify({"score_mean": 0.01, "mean_score_range": 0.001}) == OutputAnalyzer.Condition.SATURATED_ZERO and OutputAnalyzer.classify({"score_mean": 0.99, "mean_score_range": 0.001}) == OutputAnalyzer.Condition.SATURATED_ONE, failures)
	_test("Pontuações uniformes são detectadas", OutputAnalyzer.classify({"score_mean": 0.5, "mean_score_range": 0.001}) == OutputAnalyzer.Condition.LOW_DIFFERENTIATION, failures)
	var easy := Manager.new(); easy.initialize(_small_calibrated(Config.ENV_CALIBRATION_5X5)); easy.run_generation_sync()
	var main := Manager.new(); main.initialize(_small_calibrated(Config.ENV_MAIN_6X6)); main.run_generation_sync()
	_test("Modos 5×5 e 6×6 não misturam estatísticas", easy.config.get_experiment_identifier() != main.config.get_experiment_identifier() and easy.history.size() == 1 and main.history.size() == 1 and easy.training_suite.get_identifiers() != main.training_suite.get_identifiers(), failures)
	var reproduce_a := Manager.new(); reproduce_a.initialize(small); reproduce_a.run_generation_sync()
	var reproduce_b := Manager.new(); reproduce_b.initialize(small); reproduce_b.run_generation_sync()
	_test("Mesma seed reproduz experimento", reproduce_a.get_champion().identifier == reproduce_b.get_champion().identifier and reproduce_a.get_champion().get_genome() == reproduce_b.get_champion().get_genome(), failures)
	var paused := Manager.new(); paused.initialize(small); paused.begin_generation(); paused.process_evaluation_chunk(1); paused.pause(); paused.resume(); while paused.state == Manager.State.EVALUATING: paused.process_evaluation_chunk(2)
	_test("Pausa não altera resultados", paused.get_champion().identifier == reproduce_a.get_champion().identifier and is_equal_approx(paused.get_champion().fitness_average, reproduce_a.get_champion().fitness_average), failures)
	var better := Individual.new(); better.validation_summary = {"fitness_average": 100.0, "victories": 1, "average_progress": 0.5, "average_moves": 5.0}
	var worse := Individual.new(); worse.validation_summary = {"fitness_average": 90.0, "victories": 9, "average_progress": 0.9, "average_moves": 1.0}
	_test("Campeão global não é substituído por pior", not Manager._is_better_global(worse, better), failures)
	_test("Campeão é comparado com baselines", comparison.has("random") and comparison.has("untrained_neural") and comparison.has("generation_champion") and comparison.has("global_champion") and comparison.global_champion.evaluated_matches == small.validation_scenario_count, failures)
	return {"passed": 20 - failures.size(), "failed": failures.size(), "failures": failures}


static func _small_calibrated(environment_kind: int) -> Config:
	var config: Config = Config.create_calibrated(environment_kind)
	config.population_size = 6; config.elite_count = 2; config.tournament_size = 3
	config.training_scenario_count = 2; config.validation_scenario_count = 3
	return config


static func _assign_fitness(population: Population) -> void:
	for index: int in range(population.individuals.size()): population.individuals[index].fitness_average = float(population.individuals.size() - index)
	population.sort_by_fitness()


static func _test(name: String, condition: bool, failures: Array[String]) -> void:
	if not condition:
		failures.append(name); push_error("[NeuroMine Lab] " + name)
