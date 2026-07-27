class_name EvolutionPanel
extends VBoxContainer

signal watch_champion_requested(individual, scenario)

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Scenario := preload("res://scripts/simulation/evaluation_scenario.gd")
const OutputAnalyzer := preload("res://scripts/evolution/neural_output_analyzer.gd")

var manager: Manager
var config: Config = Config.new()
var speed_chunk: int = 2
var _running: bool = false
var _continuous: bool = false
var _restart_confirmation: bool = false
var _initial_neural_network
var _generation_target: int = -1

var state_label: Label
var generation_label: Label
var progress_bar: ProgressBar
var metrics_label: Label
var diversity_label: Label
var history_label: Label
var baseline_label: Label
var config_label: Label
var pause_button: Button
var restart_button: Button
var speed_option: OptionButton
var preset_option: OptionButton
var environment_option: OptionButton
var curriculum_label: Label
var curriculum_progress: ProgressBar
var final_test_label: Label
var comparison_label: Label
var advanced_container: VBoxContainer
var _inject_confirmation: bool = false
var _saved_comparison: Dictionary = {}


func _ready() -> void:
	_build_interface()
	_initialize_evolution()


func _build_interface() -> void:
	for existing_child: Node in get_children():
		existing_child.queue_free()
	var title := Label.new()
	title.text = "EVOLUÇÃO GENÉTICA  //  EXPERIMENTAL"
	title.add_theme_color_override("font_color", Color("7dd3fc"))
	title.add_theme_font_size_override("font_size", 12)
	add_child(title)
	state_label = Label.new()
	add_child(state_label)
	generation_label = Label.new()
	add_child(generation_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 18)
	add_child(progress_bar)
	var selectors := HBoxContainer.new()
	add_child(selectors)
	preset_option = OptionButton.new()
	preset_option.add_item("Currículo + diversidade", Config.Preset.CURRICULUM_DIVERSITY)
	preset_option.add_item("Calibração sem crossover", Config.Preset.CALIBRATION_NO_CROSSOVER)
	preset_option.add_item("Configuração original", Config.Preset.ORIGINAL)
	preset_option.item_selected.connect(_on_preset_selected)
	selectors.add_child(preset_option)
	environment_option = OptionButton.new()
	environment_option.add_item("Calibração 5×5 / 3 minas", Config.ENV_CALIBRATION_5X5)
	environment_option.add_item("Principal 6×6 / 6 minas", Config.ENV_MAIN_6X6)
	environment_option.select(1)
	environment_option.item_selected.connect(_on_environment_selected)
	selectors.add_child(environment_option)
	curriculum_label = Label.new()
	curriculum_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(curriculum_label)
	curriculum_progress = ProgressBar.new(); curriculum_progress.max_value = 3.0; curriculum_progress.show_percentage = false
	add_child(curriculum_progress)
	var primary := HBoxContainer.new()
	add_child(primary)
	primary.add_child(_button("Criar população", _on_create_population_pressed))
	primary.add_child(_button("1 geração", _on_one_generation_pressed))
	primary.add_child(_button("Contínuo", _on_continuous_pressed))
	pause_button = _button("Pausar", _on_pause_pressed)
	primary.add_child(pause_button)
	primary.add_child(_button("Parar", _on_stop_pressed))
	primary.add_child(_button("Teste 20 gerações", _on_twenty_generations_pressed))
	var secondary := HBoxContainer.new()
	add_child(secondary)
	secondary.add_child(_button("Próxima geração", _on_next_generation_pressed))
	restart_button = _button("Reiniciar", _on_restart_pressed)
	secondary.add_child(restart_button)
	speed_option = OptionButton.new()
	for data: Dictionary in [
		{"label": "Visual", "chunk": 1}, {"label": "Normal", "chunk": 2},
		{"label": "Rápido", "chunk": 4}, {"label": "Máximo", "chunk": 8},
	]:
		speed_option.add_item(data.label)
		speed_option.set_item_metadata(speed_option.item_count - 1, data.chunk)
	speed_option.select(1)
	speed_option.item_selected.connect(_on_speed_selected)
	secondary.add_child(speed_option)
	var curriculum_controls := HBoxContainer.new(); add_child(curriculum_controls)
	curriculum_controls.add_child(_button("Avançar fase", _on_advance_phase_pressed))
	curriculum_controls.add_child(_button("Bloquear automático", _on_block_automatic_pressed))
	curriculum_controls.add_child(_button("Teste final", _on_final_test_pressed))
	curriculum_controls.add_child(_button("Injetar diversidade", _on_inject_diversity_pressed))
	curriculum_controls.add_child(_button("Reiniciar fase", _on_restart_phase_pressed))
	config_label = Label.new()
	config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(config_label)
	metrics_label = Label.new()
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(metrics_label)
	diversity_label = Label.new()
	diversity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(diversity_label)
	var watch_row := HBoxContainer.new()
	add_child(watch_row)
	watch_row.add_child(_button("Ver treino", _on_watch_training_pressed))
	watch_row.add_child(_button("Ver validação", _on_watch_validation_pressed))
	watch_row.add_child(_button("Campo atual", _on_watch_manual_pressed))
	add_child(_button("Comparar baselines", _on_baseline_pressed))
	baseline_label = Label.new()
	baseline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	baseline_label.text = "Baselines ainda não calculados."
	add_child(baseline_label)
	final_test_label = Label.new(); final_test_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; final_test_label.text = "O TESTE FINAL NÃO INFLUENCIA A EVOLUÇÃO"
	add_child(final_test_label)
	var comparison_row := HBoxContainer.new(); add_child(comparison_row)
	comparison_row.add_child(_button("Salvar resumo", _on_save_summary_pressed))
	comparison_row.add_child(_button("Comparar execução", _on_compare_summary_pressed))
	comparison_label = Label.new(); comparison_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(comparison_label)
	var advanced_toggle := CheckButton.new(); advanced_toggle.text = "Detalhes avançados"; advanced_toggle.toggled.connect(_on_advanced_toggled); add_child(advanced_toggle)
	advanced_container = VBoxContainer.new(); advanced_container.visible = false; add_child(advanced_container)
	var scenario_row := HBoxContainer.new(); advanced_container.add_child(scenario_row)
	scenario_row.add_child(_button("Ver fixo", _on_watch_fixed_pressed)); scenario_row.add_child(_button("Ver rotativo", _on_watch_rotating_pressed)); scenario_row.add_child(_button("Ver validação", _on_watch_validation_pressed)); scenario_row.add_child(_button("Ver teste final", _on_watch_final_pressed))
	var history_title := Label.new()
	history_title.text = "HISTÓRICO DE GERAÇÕES"
	history_title.add_theme_color_override("font_color", Color("94a3b8"))
	add_child(history_title)
	history_label = Label.new()
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.text = "Nenhuma geração concluída."
	add_child(history_label)


func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _initialize_evolution() -> void:
	_running = false
	_continuous = false
	manager = Manager.new()
	manager.state_changed.connect(_on_state_changed)
	manager.progress_changed.connect(_on_progress_changed)
	manager.generation_completed.connect(_on_generation_completed)
	if not manager.initialize(config):
		state_label.text = "Erro: " + manager.last_error
		return
	_initial_neural_network = manager.population.individuals[0].network.clone_network()
	_generation_target = -1
	progress_bar.value = 0
	history_label.text = "Nenhuma geração concluída."
	baseline_label.text = "Baselines ainda não calculados."
	_refresh_labels()


func _on_one_generation_pressed() -> void:
	if not _running:
		_continuous = false
		_run_generations_async()


func _on_create_population_pressed() -> void:
	_initialize_evolution()


func _on_next_generation_pressed() -> void:
	if not _running and manager.state == Manager.State.GENERATION_COMPLETE:
		manager.breed_next_generation()
		_refresh_labels()


func _on_continuous_pressed() -> void:
	_continuous = true
	if not _running:
		_run_generations_async()


func _on_twenty_generations_pressed() -> void:
	if _running:
		return
	_generation_target = manager.history.size() + 20
	_continuous = true
	_run_generations_async()


func _run_generations_async() -> void:
	_running = true
	while _running:
		if manager.state == Manager.State.GENERATION_COMPLETE:
			manager.breed_next_generation()
		if manager.state == Manager.State.IDLE:
			manager.begin_generation()
		while _running and manager.state in [Manager.State.EVALUATING, Manager.State.PAUSED]:
			if manager.state == Manager.State.PAUSED:
				await get_tree().process_frame
				continue
			manager.process_evaluation_chunk(speed_chunk)
			await get_tree().process_frame
		if not _continuous or manager.state in [Manager.State.STOPPED, Manager.State.ERROR]:
			break
		if _generation_target >= 0 and manager.history.size() >= _generation_target:
			_continuous = false
			break
	_running = false
	_refresh_labels()


func _on_pause_pressed() -> void:
	if manager.state == Manager.State.PAUSED:
		manager.resume()
		pause_button.text = "Pausar"
	else:
		manager.pause()
		pause_button.text = "Retomar"


func _on_stop_pressed() -> void:
	_running = false
	_continuous = false
	manager.stop()


func _on_restart_pressed() -> void:
	if not _restart_confirmation:
		_restart_confirmation = true
		restart_button.text = "Confirmar?"
		return
	_restart_confirmation = false
	restart_button.text = "Reiniciar"
	_initialize_evolution()


func _on_speed_selected(index: int) -> void:
	speed_chunk = int(speed_option.get_item_metadata(index))


func _on_preset_selected(index: int) -> void:
	var environment_kind: int = config.environment
	match index:
		Config.Preset.CURRICULUM_DIVERSITY: config = Config.create_curriculum()
		Config.Preset.CALIBRATION_NO_CROSSOVER: config = Config.create_calibrated(environment_kind)
		Config.Preset.ORIGINAL: config = Config.create_original(environment_kind)
	_initialize_evolution()


func _on_environment_selected(index: int) -> void:
	if config.curriculum_enabled:
		config.curriculum_start_phase = 1 if index == Config.ENV_CALIBRATION_5X5 else 3
	config.apply_environment(index)
	_initialize_evolution()


func _on_advance_phase_pressed() -> void:
	if not _running: manager.advance_phase(true); _refresh_labels()


func _on_block_automatic_pressed() -> void:
	manager.automatic_advancement_blocked = not manager.automatic_advancement_blocked
	_refresh_labels()


func _on_final_test_pressed() -> void:
	final_test_label.text = "Executando teste final isolado…"
	await get_tree().process_frame
	var result: Dictionary = manager.execute_final_test()
	if result.is_empty(): final_test_label.text = "Teste final indisponível antes de um campeão."; return
	var summary: Dictionary = result.champion
	var random_summary: Dictionary = result.random; var neural_summary: Dictionary = result.untrained_neural
	final_test_label.text = "O TESTE FINAL NÃO INFLUENCIA A EVOLUÇÃO\nExecuções: %d\nCampeão: fit %.1f | prog %.1f%% | vit %d | seguras %.1f | jogadas %.1f | Δ validação %.1f\nAleatório: %.1f | %.1f%% | %d vit | %.1f seguras | %.1f jogadas\nNeural inicial: %.1f | %.1f%% | %d vit | %.1f seguras | %.1f jogadas" % [result.execution_count, summary.fitness_average, summary.average_progress * 100.0, summary.victories, summary.average_safe_decisions, summary.average_moves, result.validation_difference, random_summary.fitness_average, random_summary.average_progress * 100.0, random_summary.victories, random_summary.average_safe_decisions, random_summary.average_moves, neural_summary.fitness_average, neural_summary.average_progress * 100.0, neural_summary.victories, neural_summary.average_safe_decisions, neural_summary.average_moves]


func _on_inject_diversity_pressed() -> void:
	if not _inject_confirmation:
		_inject_confirmation = true; final_test_label.text = "Confirmar injeção de diversidade? Pressione novamente."; return
	_inject_confirmation = false
	var outcome: Dictionary = manager.inject_diversity()
	final_test_label.text = "Diversidade injetada: %d imigrantes, %d descendentes reforçados; elites preservados: %s" % [outcome.get("replaced", 0), outcome.get("mutated", 0), outcome.get("elites_preserved", false)]


func _on_restart_phase_pressed() -> void:
	if not _restart_confirmation: _restart_confirmation = true; restart_button.text = "Confirmar fase?"; return
	_restart_confirmation = false; restart_button.text = "Reiniciar"; manager.restart_current_phase(); _refresh_labels()


func _on_watch_fixed_pressed() -> void:
	var champion: Individual = manager.global_champion if is_instance_valid(manager.global_champion) else manager.get_champion()
	if is_instance_valid(champion) and manager.training_suite.scenarios.size() > 0: watch_champion_requested.emit(champion, manager.training_suite.scenarios[0])


func _on_watch_rotating_pressed() -> void:
	var champion: Individual = manager.global_champion if is_instance_valid(manager.global_champion) else manager.get_champion()
	var index: int = config.fixed_training_core_count
	if is_instance_valid(champion) and manager.training_suite.scenarios.size() > index: watch_champion_requested.emit(champion, manager.training_suite.scenarios[index])


func _on_watch_final_pressed() -> void:
	var champion: Individual = manager.global_champion if is_instance_valid(manager.global_champion) else manager.get_champion()
	if is_instance_valid(champion): watch_champion_requested.emit(champion, manager.final_test_suite.scenarios[0])


func _on_advanced_toggled(enabled: bool) -> void: advanced_container.visible = enabled


func _on_save_summary_pressed() -> void:
	_saved_comparison = manager.create_experiment_summary(); comparison_label.text = "Resumo salvo em memória: " + str(_saved_comparison.get("preset", ""))


func _on_compare_summary_pressed() -> void:
	if _saved_comparison.is_empty(): comparison_label.text = "Salve primeiro o resumo de uma execução."; return
	var current: Dictionary = manager.create_experiment_summary()
	comparison_label.text = "%s vs %s | gerações %d/%d | melhor val %.1f/%.1f | final %.1f/%.1f | vit %d/%d | div %.4f/%.4f | gap %.1f/%.1f | tempo %.1f/%.1f" % [_saved_comparison.preset, current.preset, _saved_comparison.generation_count, current.generation_count, _saved_comparison.best_validation, current.best_validation, _saved_comparison.final_validation, current.final_validation, _saved_comparison.victories, current.victories, _saved_comparison.final_diversity, current.final_diversity, _saved_comparison.generalization_gap, current.generalization_gap, _saved_comparison.total_seconds, current.total_seconds]


func _on_watch_training_pressed() -> void:
	var champion: Individual = manager.get_champion()
	if is_instance_valid(champion) and is_instance_valid(manager.training_suite):
		watch_champion_requested.emit(champion, manager.training_suite.scenarios[0])


func _on_watch_validation_pressed() -> void:
	if is_instance_valid(manager.global_champion):
		watch_champion_requested.emit(manager.global_champion, manager.validation_suite.scenarios[0])


func _on_watch_manual_pressed() -> void:
	var champion: Individual = manager.global_champion if is_instance_valid(manager.global_champion) else manager.get_champion()
	if not is_instance_valid(champion):
		return
	watch_champion_requested.emit(champion, Scenario.new(
		config.board_width, config.board_height, config.mine_count,
		int(Time.get_ticks_usec()), config.first_reveal
	))


func _on_baseline_pressed() -> void:
	baseline_label.text = "Calculando nos %d cenários fixos…" % config.validation_scenario_count
	await get_tree().process_frame
	var comparison: Dictionary = manager.get_baseline_comparison()
	var lines: Array[String] = []
	for entry: Dictionary in [
		{"name": "BASELINE ALEATÓRIO", "key": "random"},
		{"name": "BASELINE NEURAL NÃO TREINADO", "key": "untrained_neural"},
		{"name": "CAMPEÃO DA GERAÇÃO", "key": "generation_champion"},
		{"name": "CAMPEÃO GLOBAL", "key": "global_champion"},
	]:
		var summary: Dictionary = comparison.get(entry.key, {})
		if summary.is_empty():
			lines.append(entry.name + ": —")
		else:
			lines.append("%s: fit %.1f | prog %.1f%% | vit %d | seguras %.1f | jogadas %.1f" % [
				entry.name, summary.fitness_average, summary.average_progress * 100.0,
				summary.victories, summary.average_safe_decisions, summary.average_moves,
			])
	baseline_label.text = "\n".join(lines)


func _on_state_changed(_new_state: int) -> void:
	_refresh_labels()


func _on_progress_changed(completed: int, total: int) -> void:
	progress_bar.max_value = total
	progress_bar.value = completed
	_refresh_labels()


func _on_generation_completed(_result) -> void:
	_refresh_labels()


func _refresh_labels() -> void:
	if not is_instance_valid(manager) or not is_instance_valid(manager.population):
		return
	state_label.text = "Estado: %s" % manager.get_state_text()
	environment_option.disabled = config.curriculum_enabled
	if config.curriculum_enabled:
		var phase = manager.get_current_phase(); var next_phase = manager.get_next_phase(); var criteria: Dictionary = manager.last_phase_criteria
		curriculum_label.text = "CURRÍCULO EVOLUTIVO\nFase atual: %s\nGeração: global %d | fase %d\nPróxima: %s\nCritérios: vitórias %s | validação %s | gerações %d/%d | automático %s" % [phase.get_full_name(), manager.global_generation, manager.phase_generation, next_phase.get_full_name() if is_instance_valid(next_phase) else "fase final", "OK" if criteria.get("wins_ok", false) else "pendente", "OK" if criteria.get("fitness_ok", false) and criteria.get("baselines_ok", false) else "pendente", manager.phase_generation, phase.minimum_generations, "bloqueado" if manager.automatic_advancement_blocked else "ativo"]
		curriculum_progress.value = float(manager.current_phase_index)
	else:
		curriculum_label.text = "Execução sem currículo"; curriculum_progress.value = 0
	config_label.text = "%s | %s\nSeed %d | abertura fixa (%d,%d) | núcleo %d + rotativos %d | validação %d | teste final %d\nFitness robusto considera a média e os piores campos." % [
		config.preset_name, config.environment_name,
		config.master_seed, config.first_reveal.x, config.first_reveal.y,
		config.fixed_training_core_count if config.curriculum_enabled else 0,
		config.rotating_training_count if config.curriculum_enabled else config.training_scenario_count,
		config.validation_scenario_count, config.final_test_scenario_count,
	]
	var current_index: int = mini(manager.evaluation_index + 1, manager.population.individuals.size())
	var current_identifier: String = manager.population.individuals[current_index - 1].identifier if current_index > 0 else "—"
	var completed_matches: int = manager.evaluation_index * config.training_scenario_count
	var total_matches: int = manager.population.individuals.size() * config.training_scenario_count
	generation_label.text = "Geração %d | População %d\nIndivíduo %s (%d/%d) | avaliações %d/%d | partida %d/%d" % [
		manager.population.generation, manager.population.individuals.size(),
		current_identifier, manager.evaluation_index, manager.population.individuals.size(),
		completed_matches, total_matches, mini(config.training_scenario_count, completed_matches % config.training_scenario_count + 1),
		config.training_scenario_count,
	]
	var champion: Individual = manager.get_champion()
	if is_instance_valid(champion):
		metrics_label.text = "Campeão %s | rank %d\nFitness %.1f | vitórias %.1f%% | progresso %.1f%% | %.1f jogadas" % [
			champion.identifier, champion.rank, champion.fitness_average, champion.win_rate,
			champion.average_progress * 100.0, champion.average_moves,
		]
	if not manager.history.is_empty():
		var latest = manager.history.back()
		metrics_label.text += "\nPopulação: melhor %.1f | média %.1f | mediana %.1f | pior %.1f\nValidação: %.1f fit | %.1f%% vit | %.1f%% prog | última geração %.2fs" % [
			latest.population_best_fitness, latest.population_average_fitness,
			latest.population_median_fitness, latest.population_worst_fitness,
			latest.champion_validation.get("fitness_average", 0.0), latest.champion_validation.get("win_rate", 0.0),
			latest.champion_validation.get("average_progress", 0.0) * 100.0, latest.elapsed_seconds,
		]
		metrics_label.text += "\nRobusto %.1f | média campos %.1f | quartil inferior %.1f | núcleo %.1f | rotativos %.1f\nGap %.1f (%.1f%%) — %s" % [latest.champion_training.get("selection_fitness", 0.0), latest.champion_training.get("fitness_mean", 0.0), latest.champion_training.get("lower_quartile_fitness", 0.0), latest.core_fitness, latest.rotating_fitness, latest.generalization_gap, latest.generalization_gap_percent, latest.generalization_classification]
		if is_instance_valid(manager.global_champion):
			var global_age: int = manager.population.generation - manager.global_champion.birth_generation
			metrics_label.text += "\nGlobal %s (G%d, idade %d) | treino %.1f | validação %.1f | %d vit | %.1f%% prog" % [
				manager.global_champion.identifier, manager.global_champion.birth_generation, global_age,
				manager.global_champion.fitness_average, manager.global_champion.validation_summary.get("fitness_average", 0.0),
				manager.global_champion.validation_summary.get("victories", 0),
				manager.global_champion.validation_summary.get("average_progress", 0.0) * 100.0,
			]
		diversity_label.text = "Diversidade: σ %.4f | distância %.4f | genomas idênticos %d | campeão↔média %.4f" % [
			latest.diversity.get("mean_parameter_stddev", 0.0),
			latest.diversity.get("approximate_mean_genome_distance", 0.0),
			latest.diversity.get("identical_genome_count", 0),
			latest.diversity.get("champion_to_population_mean_distance", 0.0),
		]
		diversity_label.text += "\nMutados/filho %.1f | amplitude %.5f | σ scores %.5f | quase iguais %.1f | 1ª decisões distintas %d\nESTAGNAÇÃO: %d/%d gerações sem melhoria | SAÍDAS NEURAIS: %s%s" % [
			latest.average_mutated_parameters, latest.neural_output_metrics.get("mean_score_range", 0.0),
			latest.neural_output_metrics.get("score_stddev", 0.0), latest.neural_output_metrics.get("mean_near_equal_candidates", 0.0),
			latest.distinct_first_decisions, latest.generations_without_improvement, config.stagnation_limit,
			OutputAnalyzer.to_text(latest.neural_output_condition),
			"\nALERTA: população estagnada; considere aumentar diversidade ou ajustar mutação." if manager.is_stagnated() else "",
		]
		if not latest.breeding_metrics.is_empty():
			diversity_label.text += "\nImigrantes %.1f%% | linhagens %d | máx/ancestral %d | clones rejeitados %d | distância imigrantes %.4f | quartil no pool %.1f%%" % [latest.breeding_metrics.get("immigrant_percent", 0.0), latest.breeding_metrics.get("represented_lineages", 0), latest.breeding_metrics.get("maximum_descendants_from_one_ancestor", 0), latest.breeding_metrics.get("clone_rejections", 0), latest.breeding_metrics.get("immigrant_mean_distance", 0.0), latest.breeding_metrics.get("upper_quartile_pool_participation", 0.0) * 100.0]
		var lines: Array[String] = []
		for index: int in range(maxi(0, manager.history.size() - 8), manager.history.size()):
			var item = manager.history[index]
			var variation: String = "+" if item.validation_improved else ("=" if index == 0 else "-")
			lines.append("%s Global %04d F%d-G%04d %s | treino %.1f média %.1f | val %.1f %d vit | div %.4f | gap %.1f | sem melhora %d" % [
				variation,
				item.global_generation, item.phase_index, item.phase_generation, item.champion_identifier, item.population_best_fitness,
				item.population_average_fitness, item.champion_validation.get("fitness_average", 0.0),
				item.champion_validation.get("victories", 0), item.diversity.get("mean_parameter_stddev", 0.0),
				item.generalization_gap, item.generations_without_improvement,
			])
		for event_index: int in range(maxi(0, manager.events.size() - 8), manager.events.size()):
			var event: Dictionary = manager.events[event_index]
			match event.get("type", ""):
				"phase_change": lines.append("EVENTO: fase %d → %d | transferência %s" % [event.from_phase, event.to_phase, str(event.transfer)])
				"diversity_injection": lines.append("EVENTO: injeção manual de diversidade")
				"first_victory": lines.append("EVENTO: primeira vitória da fase %d" % event.phase)
				"global_champion": lines.append("EVENTO: novo campeão global %s" % event.identifier)
				"final_test": lines.append("EVENTO: teste final executado #%d" % event.execution_count)
				"phase_restart": lines.append("EVENTO: fase %d reiniciada" % event.phase)
		history_label.text = "\n".join(lines)
