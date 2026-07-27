class_name CurriculumDiagnostics
extends RefCounted

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Phase := preload("res://scripts/evolution/curriculum_phase.gd")
const ScenarioManager := preload("res://scripts/simulation/curriculum_scenario_manager.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Evaluator := preload("res://scripts/evolution/fitness_evaluator.gd")
const Board := preload("res://scripts/core/minesweeper_board.gd")


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	var phases: Array[Phase] = Phase.create_all()
	_test("Três fases possuem configuração correta", phases.size() == 3 and phases[0].width == 5 and phases[0].mine_count == 3 and phases[1].width == 6 and phases[1].mine_count == 4 and phases[2].mine_count == 6, failures)
	var config: Config = _small_config(); var manager := Manager.new(); manager.initialize(config); manager.automatic_advancement_blocked = true
	manager.run_generation_sync(); var phase_one_top: PackedFloat32Array = manager.get_champion().get_genome(); var architecture: Array[int] = manager.get_champion().network.config.architecture.duplicate()
	var global_before: int = manager.global_generation; manager.advance_phase(true)
	var transferred_works = manager.run_generation_sync()
	_test("Rede anterior funciona na fase seguinte", is_instance_valid(transferred_works) and manager.get_champion().evaluated_matches == config.training_scenario_count, failures)
	_test("Arquitetura permanece compatível", manager.get_champion().network.config.architecture == architecture, failures)
	var preserved_found: bool = false
	for item: Individual in manager.population.individuals:
		if item.lineage.transfer_preserved and item.get_genome() == phase_one_top: preserved_found = true
	_test("Transferência preserva melhores genomas", preserved_found, failures)
	var descendant: Individual
	for item: Individual in manager.population.individuals:
		if item.lineage.transfer_kind == "descendant": descendant = item; break
	var ancestor_unchanged: PackedFloat32Array = phase_one_top.duplicate(); var changed: PackedFloat32Array = descendant.get_genome(); changed[0] += 0.5; descendant.set_genome(changed)
	_test("Descendentes transferidos são cópias profundas", phase_one_top == ancestor_unchanged, failures)
	var immigrants_without_parents: bool = true
	for item: Individual in manager.population.individuals:
		if item.lineage.transfer_kind == "immigrant": immigrants_without_parents = immigrants_without_parents and item.lineage.parent_a_identifier.is_empty() and item.lineage.parent_b_identifier.is_empty()
	_test("Imigrantes não possuem pais", immigrants_without_parents, failures)
	var old_fitness_cleared: bool = true
	manager.advance_phase(true)
	for item: Individual in manager.population.individuals: old_fitness_cleared = old_fitness_cleared and item.evaluated_matches == 0 and item.fitness_average == 0.0
	_test("Nova fase não reutiliza fitness", old_fitness_cleared, failures)
	_test("Contagem global não reinicia", manager.global_generation > global_before, failures)
	_test("Contagem da fase reinicia", manager.phase_generation == 1, failures)
	var scenarios := ScenarioManager.new(); scenarios.configure(config, phases[0]); var train_one = scenarios.create_training_suite(1); var train_two = scenarios.create_training_suite(2)
	_test("Quatro cenários fixos permanecem", train_one.get_identifiers().slice(0, 4) == train_two.get_identifiers().slice(0, 4), failures)
	_test("Oito cenários rotativos mudam", train_one.get_identifiers().slice(4) != train_two.get_identifiers().slice(4), failures)
	_test("Todos recebem o mesmo conjunto", scenarios.create_training_suite(7).get_identifiers() == scenarios.create_training_suite(7).get_identifiers(), failures)
	var reevaluate := Manager.new(); reevaluate.initialize(config); reevaluate.automatic_advancement_blocked = true; reevaluate.run_generation_sync(); reevaluate.breed_next_generation(); var elite_empty: bool = reevaluate.population.individuals[0].evaluated_matches == 0; reevaluate.run_generation_sync()
	_test("Elites são reavaliados", elite_empty and reevaluate.population.individuals[0].evaluated_matches == config.training_scenario_count, failures)
	var train_ids: Array[String] = scenarios.training_pool.get_identifiers(); var validation_ids: Array[String] = scenarios.validation_suite.get_identifiers(); var final_ids: Array[String] = scenarios.final_test_suite.get_identifiers()
	_test("Treino validação e teste são disjuntos", not _overlaps(train_ids, validation_ids) and not _overlaps(train_ids, final_ids) and not _overlaps(validation_ids, final_ids), failures)
	var champion_before: String = reevaluate.global_champion.identifier; var genome_before: PackedFloat32Array = reevaluate.global_champion.get_genome(); reevaluate.execute_final_test()
	_test("Teste final não altera campeão", reevaluate.global_champion.identifier == champion_before and reevaluate.global_champion.get_genome() == genome_before, failures)
	var command_manager := Manager.new(); command_manager.initialize(config); command_manager.run_generation_sync()
	_test("Teste final executa somente sob comando", command_manager.final_test_execution_count == 0 and command_manager.final_test_result.is_empty(), failures)
	var robust: Dictionary = Evaluator.calculate_robust_fitness([100.0, 200.0, 300.0, 400.0], 0.8, 0.2)
	_test("Fitness robusto segue fórmula", is_equal_approx(robust.selection_fitness, 220.0), failures)
	_test("Quartil inferior é correto", is_equal_approx(robust.lower_quartile_fitness, 100.0), failures)
	var immigrant_algorithm := Algorithm.new(); immigrant_algorithm.configure(config); immigrant_algorithm.set_generation_context(1, 1, 1); var immigrant_population: Population = immigrant_algorithm.create_initial_population(); _assign_fitness(immigrant_population); var immigrant_next: Population = immigrant_algorithm.breed_next_generation(immigrant_population)
	var immigrant_count: int = 0
	for item: Individual in immigrant_next.individuals:
		if "immigrant" in item.lineage.origin: immigrant_count += 1
	_test("Dez por cento de imigrantes são inseridos", absf(float(immigrant_count) / float(config.population_size) - 0.10) <= 0.06, failures)
	_test("Imigrantes preservam diversidade", immigrant_next.get_diversity_metrics().mean_parameter_stddev > 0.0, failures)
	var clone_config: Config = _small_config(); clone_config.mutation_probability = 0.0; var clone_algorithm := Algorithm.new(); clone_algorithm.configure(clone_config); var clone_population: Population = clone_algorithm.create_initial_population(); var shared: PackedFloat32Array = clone_population.individuals[0].get_genome()
	for item: Individual in clone_population.individuals: item.set_genome(shared); item.fitness_average = 1.0
	clone_population.sort_by_fitness(); var elite_zero: PackedFloat32Array = clone_population.individuals[0].get_genome(); var elite_one: PackedFloat32Array = clone_population.individuals[1].get_genome(); var clone_next: Population = clone_algorithm.breed_next_generation(clone_population); var exact_count: int = 0
	for item: Individual in clone_next.individuals:
		if item.get_genome() == shared: exact_count += 1
	_test("Limite de clones funciona", exact_count <= clone_config.maximum_identical_genomes and clone_algorithm.last_breeding_metrics.clone_rejections > 0, failures)
	_test("Elites não são alterados pelo limite", clone_next.individuals[0].get_genome() == elite_zero and clone_next.individuals[1].get_genome() == elite_one, failures)
	var latest = reevaluate.history.back(); var expected_gap: float = latest.champion_training.selection_fitness - latest.champion_validation.selection_fitness
	_test("Gap de generalização é correto", is_equal_approx(latest.generalization_gap, expected_gap), failures)
	_test("Classificação de sobreajuste funciona", reevaluate.classify_generalization_gap(5.0) == "saudável" and reevaluate.classify_generalization_gap(15.0) == "atenção" and reevaluate.classify_generalization_gap(35.0) == "sobreajuste provável" and reevaluate.classify_generalization_gap(60.0) == "sobreajuste severo", failures)
	var criteria: Dictionary = phases[0].criteria_status(10, {"victories": 6, "fitness_average": 4000.0})
	_test("Avanço automático respeita critérios", criteria.all_met and not phases[0].criteria_status(9, {"victories": 6, "fitness_average": 4000.0}).all_met, failures)
	var manual := Manager.new(); manual.initialize(config); var manual_phase: int = manual.current_phase_index; var manual_ok: bool = manual.advance_phase(true)
	_test("Avanço manual funciona", manual_ok and manual.current_phase_index == manual_phase + 1, failures)
	var injection := Manager.new(); injection.initialize(config); injection.run_generation_sync(); var injection_elites: Array[PackedFloat32Array] = []
	for index: int in range(config.elite_count): injection_elites.append(injection.population.individuals[index].get_genome())
	var injection_result: Dictionary = injection.inject_diversity(); var preserved: bool = injection_result.elites_preserved
	for index: int in range(config.elite_count): preserved = preserved and injection.population.individuals[index].get_genome() == injection_elites[index]
	_test("Injeção preserva elites", preserved, failures)
	var reproduce_a := Manager.new(); reproduce_a.initialize(config); reproduce_a.run_generation_sync(); var reproduce_b := Manager.new(); reproduce_b.initialize(config); reproduce_b.run_generation_sync()
	_test("Mesma seed reproduz currículo", reproduce_a.training_suite.get_identifiers() == reproduce_b.training_suite.get_identifiers() and reproduce_a.get_champion().get_genome() == reproduce_b.get_champion().get_genome(), failures)
	var paused := Manager.new(); paused.initialize(config); paused.begin_generation(); paused.process_evaluation_chunk(1); paused.pause(); paused.resume(); while paused.state == Manager.State.EVALUATING: paused.process_evaluation_chunk(2)
	_test("Pausa preserva determinismo", paused.get_champion().identifier == reproduce_a.get_champion().identifier and is_equal_approx(paused.get_champion().fitness_average, reproduce_a.get_champion().fitness_average), failures)
	var board := Board.new(); board.configure(5, 5, 3, 101); board.start_or_reveal_first(Vector2i(2, 2)); var hidden_safe: bool = true
	for cell: Dictionary in board.get_agent_observation().cells:
		if int(cell.visibility) != MinesweeperTypes.CellVisibility.REVEALED: hidden_safe = hidden_safe and not cell.has("has_mine")
	_test("Nenhuma informação oculta chega à rede", hidden_safe, failures)
	return {"passed": 30 - failures.size(), "failed": failures.size(), "failures": failures}


static func _small_config() -> Config:
	var config: Config = Config.create_curriculum(); config.population_size = 12; config.elite_count = 2; config.tournament_size = 3
	config.fixed_training_core_count = 4; config.rotating_training_count = 2; config.training_scenario_count = 6; config.training_pool_size = 32; config.validation_scenario_count = 4; config.final_test_scenario_count = 6
	return config


static func _assign_fitness(population: Population) -> void:
	for index: int in range(population.individuals.size()): population.individuals[index].fitness_average = float(population.individuals.size() - index)
	population.sort_by_fitness()


static func _overlaps(first: Array[String], second: Array[String]) -> bool:
	for value: String in first:
		if value in second: return true
	return false


static func _test(name: String, condition: bool, failures: Array[String]) -> void:
	if not condition: failures.append(name); push_error("[NeuroMine Lab] " + name)
