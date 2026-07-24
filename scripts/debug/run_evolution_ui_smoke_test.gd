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
	panel.config.validation_scenario_count = 3
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
	panel._on_watch_validation_pressed()
	await process_frame
	await process_frame
	var visual_ok: bool = (
		is_instance_valid(main.visual_controller.simulator)
		and main.visual_controller.simulator.agent is NeuralAgentScript
		and main.visual_controller.simulator.agent.trained
		and main.visual_controller.simulator.first_move == Vector2i(3, 3)
		and main.get_node("%ShowHeatmapButton").button_pressed
	)
	if paused_ok and generation_ok and visual_ok:
		print("Smoke evolução UI: aprovado (pausa, geração, campeão, abertura fixa e heatmap)")
		quit(0)
	else:
		printerr("Smoke evolução UI: falhou | pausa=%s geração=%s visual=%s" % [paused_ok, generation_ok, visual_ok])
		quit(1)
