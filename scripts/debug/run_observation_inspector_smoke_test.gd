extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const Schema := preload("res://scripts/observation/observation_schema.gd")
const CandidateData := preload("res://scripts/observation/candidate_observation.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var inspector = main.get_node("%ObservationInspector")
	var board_view = main.get_node("%BoardView")
	var visual = main.get_node("VisualMatchController")
	var toggle: CheckButton = inspector.get_node("InspectorToggle")
	toggle.button_pressed = true
	await process_frame
	var first_observation: CandidateData = inspector.get_current_observation()
	if not is_instance_valid(first_observation) or first_observation.feature_count != Schema.TOTAL_INPUT_COUNT:
		failures.append("ativação não produziu uma observação de 72 entradas")

	var geometry_cases: Array[Dictionary] = [
		{"position": Vector2i(0, 0), "highlight_count": 4, "name": "canto"},
		{"position": Vector2i(0, 2), "highlight_count": 6, "name": "borda"},
		{"position": Vector2i(3, 3), "highlight_count": 9, "name": "centro"},
	]
	for test_case: Dictionary in geometry_cases:
		if not inspector.select_candidate(test_case.position):
			failures.append("não selecionou candidata no %s" % test_case.name)
			continue
		var highlight_count: int = board_view.get("_observation_highlights").size()
		if highlight_count != test_case.highlight_count:
			failures.append("%s destacou %d células, esperado %d" % [test_case.name, highlight_count, test_case.highlight_count])

	var generated_before_click: bool = main.get("board").is_generated()
	board_view.inspector_cell_selected.emit(Vector2i(2, 2))
	if main.get("board").is_generated() != generated_before_click:
		failures.append("clique do inspetor revelou a casa")

	inspector.get_node("Tools/ShowIndicesButton").button_pressed = true
	if "[00]" not in inspector.get_node("InspectorScroll/InspectorOutput").text:
		failures.append("visualização de índices não foi aplicada")

	main.get_node("%WatchAgentButton").pressed.emit()
	await process_frame
	var pending_action = visual.simulator.get_pending_action()
	var agent_observation: CandidateData = inspector.get_current_observation()
	if not is_instance_valid(pending_action) or not is_instance_valid(agent_observation):
		failures.append("prévia visual não gerou ação e observação")
	elif agent_observation.candidate_position != pending_action.position:
		failures.append("inspetor não acompanhou a decisão do agente")
	visual.reset_same_match()
	toggle.button_pressed = false
	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("Smoke do inspetor: aprovado (manual, canto, borda, centro e agente visual)")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[Smoke do inspetor] " + failure)
		quit(failures.size())
