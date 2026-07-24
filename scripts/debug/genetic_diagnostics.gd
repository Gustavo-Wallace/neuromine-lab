class_name GeneticDiagnostics
extends RefCounted

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Algorithm := preload("res://scripts/evolution/genetic_algorithm.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Selection := preload("res://scripts/evolution/selection_operator.gd")
const Crossover := preload("res://scripts/evolution/crossover_operator.gd")
const Mutation := preload("res://scripts/evolution/mutation_operator.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const Evaluator := preload("res://scripts/evolution/fitness_evaluator.gd")
const Result := preload("res://scripts/simulation/simulation_result.gd")
const Board := preload("res://scripts/core/minesweeper_board.gd")


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	var config := _small_config()
	var first_algorithm := Algorithm.new(); first_algorithm.configure(config)
	var first: Population = first_algorithm.create_initial_population()
	_test("População inicial possui tamanho configurado", first.individuals.size() == config.population_size, failures)
	var sizes_valid: bool = true
	for item: Individual in first.individuals: sizes_valid = sizes_valid and item.get_genome().size() == 2065
	_test("Todos os genomas possuem 2.065 parâmetros", sizes_valid, failures)
	var same_algorithm := Algorithm.new(); same_algorithm.configure(config)
	var same: Population = same_algorithm.create_initial_population()
	_test("Mesma seed mestra reproduz população", _population_genomes(first) == _population_genomes(same), failures)
	var other_config: Config = config.duplicate_config(); other_config.master_seed += 1
	var other_algorithm := Algorithm.new(); other_algorithm.configure(other_config)
	_test("Seeds mestras distintas mudam população", _population_genomes(first) != _population_genomes(other_algorithm.create_initial_population()), failures)
	_assign_artificial_fitness(first)
	var parent_genomes: Array[PackedFloat32Array] = _population_genomes(first)
	var next: Population = first_algorithm.breed_next_generation(first)
	_test("Elites são preservados sem alterações", next.individuals[0].get_genome() == first.individuals[0].get_genome() and next.individuals[1].get_genome() == first.individuals[1].get_genome(), failures)
	var offspring: Individual = next.individuals[config.elite_count]
	var before_parent: PackedFloat32Array = first.individuals[0].get_genome()
	var child_genome: PackedFloat32Array = offspring.get_genome(); child_genome[0] += 0.75; offspring.set_genome(child_genome)
	_test("Descendentes são cópias profundas", offspring.network != first.individuals[0].network, failures)
	_test("Alterar descendente não altera pais", first.individuals[0].get_genome() == before_parent, failures)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var parent_a := PackedFloat32Array(); var parent_b := PackedFloat32Array(); parent_a.resize(200); parent_b.resize(200); parent_a.fill(1.0); parent_b.fill(2.0)
	var cross: Dictionary = Crossover.uniform(parent_a, parent_b, 1.0, rng)
	_test("Crossover usa parâmetros dos dois pais", cross.inherited_a > 0 and cross.inherited_b > 0 and cross.inherited_a + cross.inherited_b == 200, failures)
	_test("Crossover incompatível é rejeitado", not Crossover.uniform(PackedFloat32Array([1]), PackedFloat32Array([1, 2]), 1.0, rng).success, failures)
	var unchanged: Dictionary = Mutation.gaussian(PackedFloat32Array([1, 2, 3]), 0.0, 1.0, 5.0, rng)
	_test("Taxa de mutação zero não altera parâmetros", unchanged.genome == PackedFloat32Array([1, 2, 3]), failures)
	var mutated: Dictionary = Mutation.gaussian(PackedFloat32Array([0, 0, 0]), 1.0, 0.5, 5.0, rng)
	_test("Taxa máxima muta todos os parâmetros", mutated.mutation_count == 3 and mutated.genome != PackedFloat32Array([0, 0, 0]), failures)
	var finite: bool = true
	for value: float in mutated.genome: finite = finite and not is_nan(value) and not is_inf(value)
	_test("Parâmetros mutados permanecem finitos", finite, failures)
	var bounded: Dictionary = Mutation.gaussian(PackedFloat32Array([4.9, -4.9]), 1.0, 100.0, 5.0, rng)
	_test("Limite absoluto é respeitado", absf(bounded.genome[0]) <= 5.0 and absf(bounded.genome[1]) <= 5.0, failures)
	var selected: Individual = Selection.tournament(first.individuals, config.tournament_size, rng)
	_test("Torneio retorna participante válido", selected in first.individuals, failures)
	_test("População seguinte mantém tamanho", next.individuals.size() == config.population_size, failures)
	var identifiers: Dictionary = {}
	for item: Individual in next.individuals: identifiers[item.identifier] = true
	_test("IDs dos indivíduos são únicos", identifiers.size() == next.individuals.size(), failures)
	_test("Linhagens registram pais", not next.individuals.back().lineage.parent_a_identifier.is_empty() and not next.individuals.back().lineage.parent_b_identifier.is_empty(), failures)
	_test("Elites não recebem mutação", next.individuals[0].lineage.origin == "elite" and next.individuals[0].lineage.mutation_count == 0, failures)
	var evaluator := Evaluator.new(); evaluator.configure(config)
	var loss := Result.new(); loss.total_safe_cells = 10; loss.revealed_safe_cells = 5; loss.end_reason = Result.EndReason.MINE_DETONATED; loss.max_action_attempts = 40
	_test("Fitness segue fórmula documentada", is_equal_approx(float(evaluator.score_result(loss).fitness), 150.0), failures)
	var near_loss := Result.new(); near_loss.total_safe_cells = 100; near_loss.revealed_safe_cells = 99; near_loss.end_reason = Result.EndReason.MINE_DETONATED; near_loss.max_action_attempts = 400
	var victory := Result.new(); victory.victory = true; victory.total_safe_cells = 100; victory.revealed_safe_cells = 100; victory.move_count = 400; victory.max_action_attempts = 400; victory.end_reason = Result.EndReason.VICTORY
	_test("Vitória supera derrota próxima", evaluator.score_result(victory).fitness > evaluator.score_result(near_loss).fitness, failures)
	var manager := Manager.new(); manager.initialize(config); manager.run_generation_sync()
	var shared_scenarios: bool = true
	for item: Individual in manager.population.individuals:
		var recorded: Array[String] = []
		for match_summary: Dictionary in item.training_summary.matches: recorded.append(match_summary.scenario_identifier)
		shared_scenarios = shared_scenarios and recorded == manager.training_suite.get_identifiers()
	_test("Todos enfrentam os mesmos cenários", shared_scenarios, failures)
	_test("Evolução funciona sem interface", manager.state == Manager.State.GENERATION_COMPLETE and manager.history.size() == 1, failures)
	var paused := Manager.new(); paused.initialize(config); paused.begin_generation(); paused.process_evaluation_chunk(1); paused.pause(); paused.resume()
	while paused.state == Manager.State.EVALUATING: paused.process_evaluation_chunk(2)
	var direct := Manager.new(); direct.initialize(config); direct.run_generation_sync()
	_test("Pausar e continuar preserva resultado", paused.get_champion().identifier == direct.get_champion().identifier and is_equal_approx(paused.get_champion().fitness_average, direct.get_champion().fitness_average), failures)
	var champions_a: Array[String] = _run_champions(config, 3); var champions_b: Array[String] = _run_champions(config, 3)
	_test("Experimento completo reproduz campeões", champions_a == champions_b, failures)
	var visible_board := Board.new(); visible_board.configure(6, 6, 6, 555); visible_board.start_or_reveal_first(Vector2i(3, 3))
	var no_hidden: bool = true
	for cell: Dictionary in visible_board.get_agent_observation().cells:
		if int(cell.visibility) != MinesweeperTypes.CellVisibility.REVEALED: no_hidden = no_hidden and not cell.has("has_mine") and not cell.has("adjacent_mines")
	_test("Nenhuma informação oculta chega à rede", no_hidden, failures)
	return {"passed": 25 - failures.size(), "failed": failures.size(), "failures": failures}


static func _small_config() -> Config:
	var config := Config.new(); config.population_size = 6; config.elite_count = 2
	config.training_scenario_count = 2; config.validation_scenario_count = 3
	config.tournament_size = 3; config.master_seed = 77001
	return config


static func _assign_artificial_fitness(population: Population) -> void:
	for index: int in range(population.individuals.size()): population.individuals[index].fitness_average = float(population.individuals.size() - index)
	population.sort_by_fitness()


static func _population_genomes(population: Population) -> Array[PackedFloat32Array]:
	var result: Array[PackedFloat32Array] = []
	for item: Individual in population.individuals: result.append(item.get_genome())
	return result


static func _run_champions(config: Config, count: int) -> Array[String]:
	var manager := Manager.new(); manager.initialize(config)
	var result: Array[String] = []
	for index: int in range(count):
		manager.run_generation_sync(); result.append(manager.get_champion().identifier)
		if index < count - 1: manager.breed_next_generation()
	return result


static func _test(name: String, condition: bool, failures: Array[String]) -> void:
	if not condition:
		failures.append(name)
		push_error("[NeuroMine Lab] " + name)
