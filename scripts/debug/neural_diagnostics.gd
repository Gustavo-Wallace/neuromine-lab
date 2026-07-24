class_name NeuralDiagnostics
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const Schema := preload("res://scripts/observation/observation_schema.gd")
const Provider := preload("res://scripts/observation/candidate_provider.gd")
const Activation := preload("res://scripts/neural/neural_activation.gd")
const Config := preload("res://scripts/neural/neural_network_config.gd")
const Network := preload("res://scripts/neural/neural_network.gd")
const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")
const ScoreScript := preload("res://scripts/agents/candidate_score.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_run_test("Rede zerada produz saída esperada", _test_zero_network, failures)
	_run_test("Forward retorna uma saída", _test_output_count, failures)
	_run_test("Entrada com tamanho incorreto é rejeitada", _test_wrong_input_size, failures)
	_run_test("NaN e infinito são rejeitados", _test_non_finite_inputs, failures)
	_run_test("Inferência é determinística", _test_forward_determinism, failures)
	_run_test("Mesma seed reproduz parâmetros", _test_same_seed_parameters, failures)
	_run_test("Seeds diferentes alteram parâmetros", _test_different_seed_parameters, failures)
	_run_test("Parâmetros iniciais são finitos", _test_parameters_are_finite, failures)
	_run_test("Ativações são finitas", _test_activations_are_finite, failures)
	_run_test("Saída sigmoide está entre zero e um", _test_sigmoid_range, failures)
	_run_test("Clone preserva a rede", _test_clone_matches, failures)
	_run_test("Clone é uma cópia profunda", _test_clone_is_deep, failures)
	_run_test("Exportação e importação preservam saída", _test_parameter_roundtrip, failures)
	_run_test("Snapshot restaura a rede", _test_snapshot_restore, failures)
	_run_test("Quantidade de parâmetros está correta", _test_parameter_count, failures)
	_run_test("Ordem linear de parâmetros é estável", _test_parameter_order, failures)
	_run_test("Rede usa o tamanho do ObservationSchema", _test_schema_input_count, failures)
	_run_test("Minas ocultas não chegam ao agente neural", _test_no_hidden_mine_access, failures)
	_run_test("Agente pontua todas as candidatas", _test_scores_all_candidates, failures)
	_run_test("Agente não pontua casas reveladas", _test_does_not_score_revealed, failures)
	_run_test("Agente não pontua bandeiras", _test_does_not_score_flags, failures)
	_run_test("Maior pontuação é escolhida", _test_highest_score_wins, failures)
	_run_test("Empates preservam ordem determinística", _test_tie_breaking, failures)
	_run_test("Ranking está ordenado", _test_ranking_order, failures)
	_run_test("Sequência neural é reproduzível", _test_action_sequence_reproducibility, failures)
	_run_test("Agente neural funciona sem interface", _test_headless_neural_agent, failures)
	_run_test("Heatmap não influencia decisão", _test_heatmap_does_not_influence, failures)
	_run_test("Depuração não altera decisão", _test_debug_does_not_change_decision, failures)
	return {
		"passed": 28 - failures.size(),
		"failed": failures.size(),
		"failures": failures,
	}


static func _run_test(test_name: String, test_callable: Callable, failures: Array[String]) -> void:
	var message: String = test_callable.call()
	if not message.is_empty():
		var detail := "%s — %s" % [test_name, message]
		failures.append(detail)
		push_error("[NeuroMine Lab] " + detail)


static func _test_zero_network() -> String:
	var network: Network = _default_network(1)
	var parameters := PackedFloat32Array()
	parameters.resize(network.get_parameter_count())
	parameters.fill(0.0)
	network.set_flat_parameters(parameters)
	var output: PackedFloat32Array = network.forward(_zero_input())
	return "saída esperada 0,5, obtida %s" % output if output.size() != 1 or not is_equal_approx(output[0], 0.5) else ""


static func _test_output_count() -> String:
	return "quantidade de saídas diferente de 1" if _default_network(2).forward(_zero_input()).size() != 1 else ""


static func _test_wrong_input_size() -> String:
	return "entrada inválida foi aceita" if not _default_network(3).forward(PackedFloat32Array([0.0])).is_empty() else ""


static func _test_non_finite_inputs() -> String:
	var network: Network = _default_network(4)
	var nan_input: PackedFloat32Array = _zero_input()
	nan_input[0] = NAN
	var inf_input: PackedFloat32Array = _zero_input()
	inf_input[0] = INF
	return "valor não finito foi aceito" if not network.forward(nan_input).is_empty() or not network.forward(inf_input).is_empty() else ""


static func _test_forward_determinism() -> String:
	var network: Network = _default_network(5)
	var input: PackedFloat32Array = _pattern_input()
	return "saídas divergiram" if network.forward(input) != network.forward(input) else ""


static func _test_same_seed_parameters() -> String:
	return "parâmetros divergiram" if _default_network(6).get_flat_parameters() != _default_network(6).get_flat_parameters() else ""


static func _test_different_seed_parameters() -> String:
	return "parâmetros permaneceram iguais" if _default_network(7).get_flat_parameters() == _default_network(8).get_flat_parameters() else ""


static func _test_parameters_are_finite() -> String:
	for value: float in _default_network(9).get_flat_parameters():
		if is_nan(value) or is_inf(value):
			return "parâmetro não finito"
	return ""


static func _test_activations_are_finite() -> String:
	var network: Network = _default_network(10)
	network.forward(_pattern_input(), true)
	for layer: PackedFloat32Array in network.last_activations:
		for value: float in layer:
			if is_nan(value) or is_inf(value):
				return "ativação não finita"
	return ""


static func _test_sigmoid_range() -> String:
	var output: float = _default_network(11).forward(_pattern_input())[0]
	return "saída fora de [0,1]: %f" % output if output < 0.0 or output > 1.0 else ""


static func _test_clone_matches() -> String:
	var original: Network = _default_network(12)
	var clone: Network = original.clone_network()
	return "clone alterou parâmetros" if clone.get_flat_parameters() != original.get_flat_parameters() else ""


static func _test_clone_is_deep() -> String:
	var original: Network = _default_network(13)
	var original_parameters: PackedFloat32Array = original.get_flat_parameters()
	var clone: Network = original.clone_network()
	var clone_parameters: PackedFloat32Array = clone.get_flat_parameters()
	clone_parameters[0] += 1.0
	clone.set_flat_parameters(clone_parameters)
	return "alteração do clone atingiu a rede original" if original.get_flat_parameters() != original_parameters else ""


static func _test_parameter_roundtrip() -> String:
	var original: Network = _default_network(14)
	var restored: Network = _default_network(999)
	if not restored.set_flat_parameters(original.get_flat_parameters()):
		return "importação falhou"
	return "saída mudou após importação" if restored.forward(_pattern_input()) != original.forward(_pattern_input()) else ""


static func _test_snapshot_restore() -> String:
	var original: Network = _default_network(15)
	var restored := Network.new()
	if not restored.restore_snapshot(original.create_snapshot({"test": true})):
		return "restauração falhou: %s" % restored.last_error
	return "snapshot não preservou parâmetros" if restored.get_flat_parameters() != original.get_flat_parameters() else ""


static func _test_parameter_count() -> String:
	return "esperados 2065 parâmetros" if _default_network(16).get_parameter_count() != 2065 else ""


static func _test_parameter_order() -> String:
	var config := Config.new([2, 2], [Activation.Type.LINEAR])
	var network := Network.new()
	network.configure(config, 1)
	var parameters := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
	network.set_flat_parameters(parameters)
	var output: PackedFloat32Array = network.forward(PackedFloat32Array([1.0, 1.0]))
	if network.get_flat_parameters() != parameters or output != PackedFloat32Array([8.0, 13.0]):
		return "ordem não é pesos por saída seguidos de biases"
	return ""


static func _test_schema_input_count() -> String:
	var config: Config = Config.create_default()
	return "entrada da rede diverge do esquema" if config.architecture[0] != Schema.TOTAL_INPUT_COUNT else ""


static func _test_no_hidden_mine_access() -> String:
	var board := Board.new()
	board.configure(6, 6, 6, 123)
	board.start_or_reveal_first(Vector2i(2, 2))
	var visible: Dictionary = board.get_agent_observation()
	for cell: Dictionary in visible.cells:
		if cell.has("has_mine") or cell.has("hidden_adjacent_count") or cell.has("mine_position"):
			return "estado entregue contém informação oculta"
	var agent := NeuralAgentScript.new()
	agent.configure_neural(456, true)
	return "agente não produziu ação" if not is_instance_valid(agent.choose_action(visible)) else ""


static func _test_scores_all_candidates() -> String:
	var state := _visible_state(3, 2)
	var agent: NeuralAgentScript = _debug_agent(20)
	agent.choose_action(state)
	return "ranking incompleto" if agent.last_ranking.size() != Provider.get_candidates(state).size() else ""


static func _test_does_not_score_revealed() -> String:
	var state := _visible_state(3, 2)
	state.cells[1] = {"position": Vector2i(1, 0), "visibility": Types.CellVisibility.REVEALED, "content": "safe", "adjacent_mines": 1}
	var agent: NeuralAgentScript = _debug_agent(21)
	agent.choose_action(state)
	for score: ScoreScript in agent.last_ranking:
		if score.candidate_position == Vector2i(1, 0):
			return "casa revelada foi pontuada"
	return ""


static func _test_does_not_score_flags() -> String:
	var state := _visible_state(3, 2)
	state.cells[4].visibility = Types.CellVisibility.FLAGGED
	var agent: NeuralAgentScript = _debug_agent(22)
	agent.choose_action(state)
	for score: ScoreScript in agent.last_ranking:
		if score.candidate_position == Vector2i(1, 1):
			return "bandeira foi pontuada"
	return ""


static func _test_highest_score_wins() -> String:
	var agent: NeuralAgentScript = _controlled_x_agent(false)
	var action: AgentAction = agent.choose_action(_visible_state(3, 2))
	return "esperada candidata (2,0), obtida %s" % action.position if action.position != Vector2i(2, 0) else ""


static func _test_tie_breaking() -> String:
	var network: Network = _single_layer_network(Activation.Type.SIGMOID)
	var zero_parameters := PackedFloat32Array()
	zero_parameters.resize(network.get_parameter_count())
	zero_parameters.fill(0.0)
	network.set_flat_parameters(zero_parameters)
	var agent := NeuralAgentScript.new()
	agent.set_network(network, true)
	var action: AgentAction = agent.choose_action(_visible_state(3, 2))
	return "empate não escolheu a primeira candidata" if action.position != Vector2i(0, 0) else ""


static func _test_ranking_order() -> String:
	var agent: NeuralAgentScript = _controlled_x_agent(true)
	agent.choose_action(_visible_state(4, 2))
	for index: int in range(1, agent.last_ranking.size()):
		if agent.last_ranking[index - 1].raw_score < agent.last_ranking[index].raw_score:
			return "ranking não está em ordem decrescente"
	return ""


static func _test_action_sequence_reproducibility() -> String:
	var first: ResultScript = _run_neural_match(222, 333)
	var second: ResultScript = _run_neural_match(222, 333)
	var first_positions: Array[Vector2i] = []
	var second_positions: Array[Vector2i] = []
	for event: Dictionary in first.action_history:
		first_positions.append(event.position)
	for event: Dictionary in second.action_history:
		second_positions.append(event.position)
	if first.agent_metadata.get("observation_schema_version", -1) != Schema.VERSION:
		return "resultado não registrou a versão do esquema"
	if first.agent_metadata.get("architecture", []) != Config.create_default().architecture:
		return "resultado não registrou a arquitetura"
	return "sequências divergiram" if first_positions != second_positions else ""


static func _test_headless_neural_agent() -> String:
	var result: ResultScript = _run_neural_match(444, 555)
	return "partida headless não terminou" if result.end_reason not in [ResultScript.EndReason.VICTORY, ResultScript.EndReason.MINE_DETONATED] else ""


static func _test_heatmap_does_not_influence() -> String:
	var base_state := _visible_state(3, 2)
	var heatmap_state: Dictionary = base_state.duplicate(true)
	heatmap_state["heatmap_enabled"] = true
	heatmap_state["heatmap_values"] = [99.0, -99.0]
	var first: NeuralAgentScript = _debug_agent(24)
	var second: NeuralAgentScript = _debug_agent(24)
	return "metadado visual alterou decisão" if first.choose_action(base_state).position != second.choose_action(heatmap_state).position else ""


static func _test_debug_does_not_change_decision() -> String:
	var debug_agent := NeuralAgentScript.new()
	debug_agent.configure_neural(25, true)
	var fast_agent := NeuralAgentScript.new()
	fast_agent.configure_neural(25, false)
	var state := _visible_state(3, 2)
	return "depuração alterou decisão" if debug_agent.choose_action(state).position != fast_agent.choose_action(state).position else ""


static func _default_network(seed: int) -> Network:
	var network := Network.new()
	network.configure(Config.create_default(), seed)
	return network


static func _single_layer_network(activation_type: int) -> Network:
	var network := Network.new()
	network.configure(Config.new([Schema.TOTAL_INPUT_COUNT, 1], [activation_type]), 1)
	return network


static func _controlled_x_agent(enable_debug: bool) -> NeuralAgentScript:
	var network: Network = _single_layer_network(Activation.Type.SIGMOID)
	var parameters := PackedFloat32Array()
	parameters.resize(network.get_parameter_count())
	parameters.fill(0.0)
	parameters[Schema.global_index(Schema.GlobalFeature.CANDIDATE_X_NORMALIZED)] = 5.0
	network.set_flat_parameters(parameters)
	var agent := NeuralAgentScript.new()
	agent.set_network(network, enable_debug)
	return agent


static func _debug_agent(seed: int) -> NeuralAgentScript:
	var agent := NeuralAgentScript.new()
	agent.configure_neural(seed, true)
	return agent


static func _zero_input() -> PackedFloat32Array:
	var input := PackedFloat32Array()
	input.resize(Schema.TOTAL_INPUT_COUNT)
	input.fill(0.0)
	return input


static func _pattern_input() -> PackedFloat32Array:
	var input: PackedFloat32Array = _zero_input()
	for index: int in range(input.size()):
		input[index] = float(index % 11) / 10.0
	return input


static func _visible_state(width: int, height: int) -> Dictionary:
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			cells.append({"position": Vector2i(x, y), "visibility": Types.CellVisibility.COVERED})
	return {
		"width": width,
		"height": height,
		"cells": cells,
		"estimated_remaining_mines": 1,
		"mine_count": 1,
		"total_safe_cells": width * height - 1,
		"revealed_safe_cells": 0,
		"move_count": 0,
		"max_action_count": width * height * 4,
		"status": Types.GameStatus.READY,
	}


static func _run_neural_match(field_seed: int, network_seed: int) -> ResultScript:
	var board := Board.new()
	board.configure(6, 6, 6, field_seed)
	var agent := NeuralAgentScript.new()
	agent.configure_neural(network_seed, false)
	var simulator := Simulator.new()
	simulator.setup(board, agent, {"record_history": true})
	return simulator.run_to_completion()
