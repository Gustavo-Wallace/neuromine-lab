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
	preset_option.add_item("Calibração sem crossover", Config.Preset.CALIBRATION_NO_CROSSOVER)
	preset_option.add_item("Configuração original", Config.Preset.ORIGINAL)
	preset_option.item_selected.connect(_on_preset_selected)
	selectors.add_child(preset_option)
	environment_option = OptionButton.new()
	environment_option.add_item("Calibração 5×5 / 3 minas", Config.BoardEnvironment.CALIBRATION_5X5)
	environment_option.add_item("Principal 6×6 / 6 minas", Config.BoardEnvironment.MAIN_6X6)
	environment_option.select(1)
	environment_option.item_selected.connect(_on_environment_selected)
	selectors.add_child(environment_option)
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
	config = Config.create_calibrated(environment_kind) if index == Config.Preset.CALIBRATION_NO_CROSSOVER else Config.create_original(environment_kind)
	_initialize_evolution()


func _on_environment_selected(index: int) -> void:
	config.apply_environment(index)
	_initialize_evolution()


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
	config_label.text = "%s | %s\nSeed %d | abertura fixa (%d,%d) | treino fixo %d / validação fixa %d\nFitness = progresso×%.0f + decisão segura×%.0f + vitória %.0f + eficiência×%.0f" % [
		config.preset_name, config.environment_name,
		config.master_seed, config.first_reveal.x, config.first_reveal.y,
		config.training_scenario_count, config.validation_scenario_count,
		config.progress_fitness_scale, config.safe_decision_bonus, config.victory_bonus, config.victory_efficiency_scale,
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
		var lines: Array[String] = []
		for index: int in range(maxi(0, manager.history.size() - 8), manager.history.size()):
			var item = manager.history[index]
			var variation: String = "+" if item.validation_improved else ("=" if index == 0 else "-")
			lines.append("%s G%04d %s | treino %.1f | média %.1f | val %.1f | %d vit | div %.4f | sem melhora %d" % [
				variation,
				item.generation, item.champion_identifier, item.population_best_fitness,
				item.population_average_fitness, item.champion_validation.get("fitness_average", 0.0),
				item.champion_validation.get("victories", 0), item.diversity.get("mean_parameter_stddev", 0.0),
				item.generations_without_improvement,
			])
		history_label.text = "\n".join(lines)
