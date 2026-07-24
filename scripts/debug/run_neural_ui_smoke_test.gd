extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var main := MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var agent_option: OptionButton = main.get_node("%AgentTypeOption")
	agent_option.select(1)
	agent_option.item_selected.emit(1)
	main.get_node("%ShowHeatmapButton").button_pressed = true
	main.get_node("%ShowValuesButton").button_pressed = true
	main.get_node("%ShowRankingButton").button_pressed = true
	main.get_node("%WatchAgentButton").pressed.emit()
	await process_frame

	var visual = main.get_node("VisualMatchController")
	if not visual.simulator.agent is NeuralAgentScript:
		failures.append("seleção não ativou o NeuralAgent")
	else:
		var neural_agent := visual.simulator.agent as NeuralAgentScript
		var pending_action = visual.simulator.get_pending_action()
		var heatmap_scores: Array = main.get("heatmap_view").get_scores()
		if neural_agent.last_ranking.is_empty() or heatmap_scores.size() != neural_agent.last_ranking.size():
			failures.append("heatmap não contém todas as pontuações do ranking")
		elif pending_action.position != neural_agent.last_ranking[0].candidate_position:
			failures.append("vencedora do ranking diverge da ação")
		elif heatmap_scores[0].candidate_position != neural_agent.last_ranking[0].candidate_position:
			failures.append("heatmap diverge do ranking")
		var ranking_list: ItemList = main.get_node("%NeuralInspector/RankingList")
		if ranking_list.item_count < 5:
			failures.append("lista visual não exibe as cinco melhores candidatas")
		if "2065" not in main.get_node("%NeuralInspector/NetworkInfo").text:
			failures.append("inspetor não mostra a quantidade de parâmetros")
		if "ATIVAÇÕES INTERNAS" not in main.get_node("%NeuralInspector/AdvancedContainer/ActivationInfo").text:
			failures.append("ativações internas não foram calculadas")
		ranking_list.item_selected.emit(0)
		await process_frame
		var observation_inspector = main.get_node("%ObservationInspector")
		if not observation_inspector.is_active() or observation_inspector.get_current_observation().candidate_position != neural_agent.last_ranking[0].candidate_position:
			failures.append("seleção do ranking não abriu a observação correspondente")

	visual.set_speed(10.0)
	var match_guard: int = 0
	while not visual.simulator.is_finished() and match_guard < 100:
		match_guard += 1
		await create_timer(0.05).timeout
	if not visual.simulator.is_finished():
		failures.append("partida visual com heatmap não foi concluída")

	visual.reset_same_match()
	var first_parameters: PackedFloat32Array = (visual.simulator.agent as NeuralAgentScript).network.get_flat_parameters()
	main.get_node("%RecreateNetworkButton").pressed.emit()
	var recreated_parameters: PackedFloat32Array = (visual.simulator.agent as NeuralAgentScript).network.get_flat_parameters()
	if first_parameters != recreated_parameters:
		failures.append("recriar mesma rede alterou os pesos")
	var old_seed: int = main.get("current_network_seed")
	main.get_node("%NewNetworkButton").pressed.emit()
	var new_seed: int = main.get("current_network_seed")
	var new_parameters: PackedFloat32Array = (visual.simulator.agent as NeuralAgentScript).network.get_flat_parameters()
	if new_seed == old_seed or new_parameters == recreated_parameters:
		failures.append("nova rede não alterou seed e parâmetros")

	main.get_node("%Batch10Button").pressed.emit()
	var guard: int = 0
	while main.get("_batch_running") and guard < 100:
		guard += 1
		await process_frame
	if main.get("neural_statistics").matches_played != 10:
		failures.append("lote neural não atualizou estatísticas neurais")
	if main.get("random_statistics").matches_played != 0:
		failures.append("lote neural contaminou estatísticas aleatórias")

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("Smoke neural UI: aprovado (seleção, heatmap, ranking, seeds e estatísticas separadas)")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[Smoke neural UI] " + failure)
		quit(failures.size())
