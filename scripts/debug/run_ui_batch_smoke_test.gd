extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var cases: Array[Dictionary] = [
		{"count": 10, "button": "%Batch10Button"},
		{"count": 100, "button": "%Batch100Button"},
		{"count": 1000, "button": "%Batch1000Button"},
	]
	for test_case: Dictionary in cases:
		main.get_node("%ResetStatsButton").pressed.emit()
		main.get_node(test_case.button).pressed.emit()
		var frame_guard: int = 0
		while main.get("_batch_running") and frame_guard < 100:
			frame_guard += 1
			await process_frame
		var expected: int = test_case.count
		var recorded: int = main.get("statistics").matches_played
		if recorded != expected:
			failures.append("lote %d registrou %d partidas" % [expected, recorded])
		if frame_guard >= 100:
			failures.append("lote %d excedeu o limite de frames" % expected)
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("Smoke de lotes UI: aprovado (10, 100 e 1.000 partidas)")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[Smoke de lotes UI] " + failure)
		quit(failures.size())
