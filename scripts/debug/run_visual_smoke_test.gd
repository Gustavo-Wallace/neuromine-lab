extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const VisualControllerScript := preload("res://scripts/simulation/visual_match_controller.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var visual: VisualControllerScript = main.get_node("VisualMatchController")
	visual.set_speed(10.0)
	visual.start()
	visual.toggle_pause()
	await create_timer(0.08).timeout
	if visual.simulator.valid_action_count != 0 or visual.playback_state != VisualControllerScript.PlaybackState.PAUSED:
		failures.append("pausa não congelou a decisão pendente")
	visual.step_once()
	await create_timer(0.08).timeout
	if visual.simulator.valid_action_count != 1 or visual.playback_state != VisualControllerScript.PlaybackState.PAUSED:
		failures.append("avanço unitário não executou exatamente uma jogada")
	visual.set_speed(5.0)
	if not is_equal_approx(visual.speed_multiplier, 5.0):
		failures.append("mudança de velocidade não foi aplicada")
	visual.start()
	await create_timer(0.18).timeout
	if visual.simulator.valid_action_count < 1:
		failures.append("modo visual não avançou em reprodução")
	visual.reset_same_match()
	if visual.playback_state != VisualControllerScript.PlaybackState.STOPPED or visual.simulator.board.status != Types.GameStatus.READY:
		failures.append("reinício não restaurou a partida")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("Smoke visual: aprovado (pausa, avanço unitário, velocidade e reinício)")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[Smoke visual] " + failure)
		quit(failures.size())
