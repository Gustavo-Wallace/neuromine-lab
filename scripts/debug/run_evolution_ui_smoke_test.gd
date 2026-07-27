extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var panel = main.evolution_panel
	panel.config.population_size = 6
	panel.config.elite_count = 2
	panel.config.training_scenario_count = 2
	panel.config.fixed_training_core_count = 1
	panel.config.rotating_training_count = 1
	panel.config.training_pool_size = 16
	panel.config.validation_scenario_count = 3
	panel.config.final_test_scenario_count = 5
	panel._initialize_evolution()
	panel._on_one_generation_pressed()
	await process_frame
	panel._on_pause_pressed()
	var paused_ok: bool = panel.manager.state == Manager.State.PAUSED
	await process_frame
	panel._on_pause_pressed()
	var frames: int = 0
	while panel.manager.history.is_empty() and frames < 300:
		await process_frame
		frames += 1
	var generation_ok: bool = panel.manager.history.size() == 1 and panel.manager.state == Manager.State.GENERATION_COMPLETE
	var latest = panel.manager.history.back()
	var displayed_values_ok: bool = (
		panel.history_chart.validation_values.size() == 1
		and is_equal_approx(panel.history_chart.validation_values[0], float(latest.champion_validation.get("fitness_average", 0.0)))
		and is_equal_approx(panel.history_chart.population_values[0], latest.population_average_fitness)
		and panel.generation_champion_label.text.contains("Validação %.1f" % latest.champion_validation.get("fitness_average", 0.0))
		and panel.global_champion_label.text.contains("Validação %.1f" % panel.manager.global_champion.validation_summary.get("fitness_average", 0.0))
		and panel.phase_summary_label.text.contains("Diversidade %.4f" % latest.diversity.get("mean_parameter_stddev", 0.0))
		and panel.phase_summary_label.text.contains("Gap de generalização %.1f" % latest.generalization_gap)
	)
	var layout_ok: bool = not panel.advanced_container.visible and panel.get_combined_minimum_size().y <= 720.0
	panel._on_watch_validation_pressed()
	await process_frame
	await process_frame
	var visual_ok: bool = (
		is_instance_valid(main.visual_controller.simulator)
		and main.visual_controller.simulator.agent is NeuralAgentScript
		and main.visual_controller.simulator.agent.trained
		and main.visual_controller.simulator.first_move == panel.manager.config.first_reveal
		and main.get_node("%ShowHeatmapButton").button_pressed
	)
	if paused_ok and generation_ok and displayed_values_ok and layout_ok and visual_ok:
		print("Smoke evolução UI: aprovado (geração completa, valores exatos, resumo em 720p, gráfico e heatmap)")
		quit(0)
	else:
		printerr("Smoke evolução UI: falhou | pausa=%s geração=%s valores=%s layout=%s visual=%s" % [paused_ok, generation_ok, displayed_values_ok, layout_ok, visual_ok])
		quit(1)
