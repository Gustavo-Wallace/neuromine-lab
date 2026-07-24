class_name ObservationDiagnostics
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const Schema := preload("res://scripts/observation/observation_schema.gd")
const Encoder := preload("res://scripts/observation/observation_encoder.gd")
const Provider := preload("res://scripts/observation/candidate_provider.gd")
const CandidateData := preload("res://scripts/observation/candidate_observation.gd")
const RandomAgentScript := preload("res://scripts/agents/random_agent.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_run_test("Vetor possui o tamanho do esquema", _test_vector_size, failures)
	_run_test("Ordem das características é estável", _test_feature_order, failures)
	_run_test("Todos os valores são finitos", _test_values_are_finite, failures)
	_run_test("Valores respeitam as faixas", _test_value_ranges, failures)
	_run_test("Codificação é determinística", _test_encoding_is_deterministic, failures)
	_run_test("Minas ocultas não alteram o vetor", _test_hidden_layout_does_not_leak, failures)
	_run_test("Mina coberta é indistinguível", _test_covered_mine_is_indistinguishable, failures)
	_run_test("Posições fora do campo estão corretas", _test_out_of_bounds, failures)
	_run_test("Direções seguem a ordem documentada", _test_direction_order, failures)
	_run_test("Pistas reveladas são normalizadas", _test_visible_clue_normalization, failures)
	_run_test("Bandeiras vizinhas usam estado visível", _test_visible_flag_counts, failures)
	_run_test("Candidatas excluem casas reveladas", _test_candidates_exclude_revealed, failures)
	_run_test("Candidatas excluem bandeiras", _test_candidates_exclude_flags, failures)
	_run_test("Ordem de candidatas é determinística", _test_candidate_order, failures)
	_run_test("Dimensões diferentes são suportadas", _test_different_dimensions, failures)
	_run_test("Vetor retornado é defensivo", _test_vector_is_defensive, failures)
	_run_test("RandomAgent permanece reproduzível", _test_random_agent_reproducibility, failures)
	_run_test("Observações funcionam em modo rápido", _test_headless_observation_generation, failures)
	return {
		"passed": 18 - failures.size(),
		"failed": failures.size(),
		"failures": failures,
	}


static func run_benchmark(iterations: int = 1000) -> Dictionary:
	var board := Board.new()
	board.configure(6, 6, 6, 4700606)
	board.start_or_reveal_first(Vector2i(2, 2))
	var visible_state: Dictionary = board.get_agent_observation(1, 144)
	var encoder := Encoder.new()
	var generated_count: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for iteration: int in range(iterations):
		generated_count += encoder.encode_all_candidates(visible_state, false).size()
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return {
		"iterations": iterations,
		"observations": generated_count,
		"elapsed_seconds": elapsed_seconds,
		"observations_per_second": float(generated_count) / elapsed_seconds if elapsed_seconds > 0.0 else 0.0,
	}


static func _run_test(test_name: String, test_callable: Callable, failures: Array[String]) -> void:
	var error_message: String = test_callable.call()
	if not error_message.is_empty():
		var detail := "%s — %s" % [test_name, error_message]
		failures.append(detail)
		push_error("[NeuroMine Lab] " + detail)


static func _test_vector_size() -> String:
	var encoder := Encoder.new()
	for test_case: Dictionary in [
		{"state": _make_observation(6, 6, 6), "position": Vector2i(3, 3)},
		{"state": _make_observation(6, 6, 6), "position": Vector2i(0, 0)},
		{"state": _make_observation(3, 9, 4), "position": Vector2i(2, 8)},
	]:
		var encoded: CandidateData = encoder.encode_candidate(test_case.state, test_case.position)
		if encoded.feature_count != Schema.TOTAL_INPUT_COUNT or encoded.get_vector().size() != 72:
			return "esperadas 72 entradas"
	return ""


static func _test_feature_order() -> String:
	var names: PackedStringArray = Schema.get_feature_names()
	if names.size() != 72:
		return "lista possui %d nomes" % names.size()
	if names[0] != "NW.is_out_of_bounds" or names[7] != "NW.remaining_mines_for_clue_normalized":
		return "primeiro grupo local divergiu"
	if names[8] != "N.is_out_of_bounds" or names[63] != "SE.remaining_mines_for_clue_normalized":
		return "ordem direcional divergiu"
	if names[64] != "candidate_x_normalized" or names[71] != "is_first_action":
		return "grupo global divergiu"
	return ""


static func _test_values_are_finite() -> String:
	var encoded: CandidateData = Encoder.new().encode_candidate(_make_observation(1, 1, 0), Vector2i.ZERO)
	for value: float in encoded.get_vector():
		if is_nan(value) or is_inf(value):
			return "encontrado valor não finito"
	return ""


static func _test_value_ranges() -> String:
	var state := _make_observation(3, 3, 1)
	for index: int in range(8):
		state.cells[index].visibility = Types.CellVisibility.FLAGGED
	var values: PackedFloat32Array = Encoder.new().encode_candidate(state, Vector2i(2, 2)).get_vector()
	for index: int in range(values.size()):
		var upper_bound: float = Schema.MAX_FLAGS_USED_RATIO if index == Schema.global_index(Schema.GlobalFeature.FLAGS_USED_RATIO) else 1.0
		if values[index] < 0.0 or values[index] > upper_bound:
			return "índice %d fora de [0, %.1f]: %f" % [index, upper_bound, values[index]]
	return ""


static func _test_encoding_is_deterministic() -> String:
	var state := _make_intermediate_observation()
	var encoder := Encoder.new()
	var first: PackedFloat32Array = encoder.encode_candidate(state, Vector2i(4, 4)).get_vector()
	var second: PackedFloat32Array = encoder.encode_candidate(state, Vector2i(4, 4)).get_vector()
	return "vetores divergiram" if first != second else ""


static func _test_hidden_layout_does_not_leak() -> String:
	var first_board := Board.new()
	first_board.configure(6, 6, 6, 1001)
	first_board.start_or_reveal_first(Vector2i(2, 2))
	var second_board := Board.new()
	second_board.configure(6, 6, 6, 2002)
	second_board.start_or_reveal_first(Vector2i(2, 2))
	if _mine_signature(first_board) == _mine_signature(second_board):
		return "seeds de teste produziram a mesma distribuição interna"
	var first_visible: Dictionary = _mask_as_fully_covered(first_board.get_agent_observation())
	var second_visible: Dictionary = _mask_as_fully_covered(second_board.get_agent_observation())
	var encoder := Encoder.new()
	var first_vector: PackedFloat32Array = encoder.encode_candidate(first_visible, Vector2i(2, 2)).get_vector()
	var second_vector: PackedFloat32Array = encoder.encode_candidate(second_visible, Vector2i(2, 2)).get_vector()
	return "distribuições ocultas alteraram o vetor" if first_vector != second_vector else ""


static func _test_covered_mine_is_indistinguishable() -> String:
	var mine_state := _make_observation(3, 3, 1)
	var safe_state: Dictionary = mine_state.duplicate(true)
	mine_state.cells[4]["has_mine"] = true
	safe_state.cells[4]["has_mine"] = false
	var encoder := Encoder.new()
	var mine_vector: PackedFloat32Array = encoder.encode_candidate(mine_state, Vector2i(1, 1)).get_vector()
	var safe_vector: PackedFloat32Array = encoder.encode_candidate(safe_state, Vector2i(1, 1)).get_vector()
	return "propriedade oculta influenciou a codificação" if mine_vector != safe_vector else ""


static func _test_out_of_bounds() -> String:
	var vector: PackedFloat32Array = Encoder.new().encode_candidate(_make_observation(4, 4, 2), Vector2i.ZERO).get_vector()
	var expected_oob: Array[int] = [0, 1, 2, 3, 5]
	for direction_index: int in range(8):
		var value: float = vector[Schema.local_index(direction_index, Schema.LocalFeature.IS_OUT_OF_BOUNDS)]
		if value != (1.0 if direction_index in expected_oob else 0.0):
			return "direção %d possui marcador incorreto" % direction_index
	return ""


static func _test_direction_order() -> String:
	var expected: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]
	return "offsets não correspondem a NW,N,NE,W,E,SW,S,SE" if Schema.DIRECTION_OFFSETS != expected else ""


static func _test_visible_clue_normalization() -> String:
	var state := _make_observation(3, 3, 2)
	_set_revealed_clue(state, Vector2i(1, 0), 2)
	var vector: PackedFloat32Array = Encoder.new().encode_candidate(state, Vector2i(1, 1)).get_vector()
	var clue_index: int = Schema.local_index(1, Schema.LocalFeature.VISIBLE_CLUE_NORMALIZED)
	return "pista 2 não foi codificada como 0,25" if not is_equal_approx(vector[clue_index], 0.25) else ""


static func _test_visible_flag_counts() -> String:
	var state := _make_observation(5, 5, 5)
	_set_revealed_clue(state, Vector2i(2, 1), 3)
	state.cells[0 * 5 + 1].visibility = Types.CellVisibility.FLAGGED
	state.cells[0 * 5 + 2].visibility = Types.CellVisibility.FLAGGED
	var vector: PackedFloat32Array = Encoder.new().encode_candidate(state, Vector2i(2, 2)).get_vector()
	var flag_index: int = Schema.local_index(1, Schema.LocalFeature.FLAGGED_NEIGHBORS_NORMALIZED)
	return "duas bandeiras não foram normalizadas como 0,25" if not is_equal_approx(vector[flag_index], 0.25) else ""


static func _test_candidates_exclude_revealed() -> String:
	var state := _make_observation(3, 2, 1)
	_set_revealed_clue(state, Vector2i(1, 0), 1)
	return "casa revelada foi listada" if Vector2i(1, 0) in Provider.get_candidates(state) else ""


static func _test_candidates_exclude_flags() -> String:
	var state := _make_observation(3, 2, 1)
	state.cells[4].visibility = Types.CellVisibility.FLAGGED
	return "bandeira foi listada" if Vector2i(1, 1) in Provider.get_candidates(state) else ""


static func _test_candidate_order() -> String:
	var state := _make_observation(3, 2, 1)
	state.cells[1].visibility = Types.CellVisibility.FLAGGED
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var first: Array[Vector2i] = Provider.get_candidates(state)
	var second: Array[Vector2i] = Provider.get_candidates(state)
	return "ordem não é linha a linha determinística" if first != expected or second != first else ""


static func _test_different_dimensions() -> String:
	var encoder := Encoder.new()
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(4, 7), Vector2i(9, 3)]:
		var state := _make_observation(dimensions.x, dimensions.y, 0)
		var encoded: CandidateData = encoder.encode_candidate(state, dimensions - Vector2i.ONE)
		if encoded.feature_count != 72:
			return "falha em tabuleiro %s" % dimensions
	return ""


static func _test_vector_is_defensive() -> String:
	var state := _make_observation(3, 3, 1)
	var encoded: CandidateData = Encoder.new().encode_candidate(state, Vector2i(1, 1), true)
	var original_value: float = encoded.get_value(0)
	var external_vector: PackedFloat32Array = encoded.get_vector()
	external_vector[0] = 99.0
	var external_debug: Dictionary = encoded.get_debug_visible_state()
	external_debug.cells[0].visibility = 999
	if encoded.get_value(0) != original_value or state.cells[0].visibility == 999:
		return "cópia externa modificou dados internos"
	return ""


static func _test_random_agent_reproducibility() -> String:
	var first: ResultScript = _run_random_match(4700606, 91001)
	var second: ResultScript = _run_random_match(4700606, 91001)
	var first_positions: Array[Vector2i] = []
	var second_positions: Array[Vector2i] = []
	for event: Dictionary in first.action_history:
		first_positions.append(event.position)
	for event: Dictionary in second.action_history:
		second_positions.append(event.position)
	return "sequência mudou após CandidateProvider" if first_positions != second_positions else ""


static func _test_headless_observation_generation() -> String:
	var board := Board.new()
	board.configure(6, 6, 6, 321)
	var agent := RandomAgentScript.new()
	agent.configure(654)
	var simulator := Simulator.new()
	simulator.setup(board, agent)
	var encoder := Encoder.new()
	var generated: int = 0
	while not simulator.is_finished():
		generated += encoder.encode_all_candidates(
			board.get_agent_observation(simulator.valid_action_count, simulator.max_action_attempts)
		).size()
		simulator.step()
	return "nenhuma observação gerada sem UI" if generated <= 0 else ""


static func _make_observation(width: int, height: int, mine_count: int) -> Dictionary:
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			cells.append({"position": Vector2i(x, y), "visibility": Types.CellVisibility.COVERED})
	return {
		"width": width,
		"height": height,
		"cells": cells,
		"estimated_remaining_mines": mine_count,
		"mine_count": mine_count,
		"total_safe_cells": width * height - mine_count,
		"revealed_safe_cells": 0,
		"move_count": 0,
		"max_action_count": maxi(1, width * height * 4),
		"status": Types.GameStatus.READY,
	}


static func _make_intermediate_observation() -> Dictionary:
	var state := _make_observation(6, 6, 6)
	_set_revealed_clue(state, Vector2i(3, 3), 2)
	_set_revealed_clue(state, Vector2i(3, 4), 1)
	state.cells[2 * 6 + 3].visibility = Types.CellVisibility.FLAGGED
	state.revealed_safe_cells = 2
	state.move_count = 3
	return state


static func _set_revealed_clue(state: Dictionary, position: Vector2i, clue: int) -> void:
	var index: int = position.y * int(state.width) + position.x
	state.cells[index] = {
		"position": position,
		"visibility": Types.CellVisibility.REVEALED,
		"content": "safe",
		"adjacent_mines": clue,
	}


static func _mask_as_fully_covered(source: Dictionary) -> Dictionary:
	var masked := _make_observation(int(source.width), int(source.height), int(source.mine_count))
	masked.max_action_count = source.max_action_count
	return masked


static func _mine_signature(board: MinesweeperBoard) -> String:
	var signature := ""
	for state: Dictionary in board.get_debug_board_state():
		signature += "1" if state.has_mine else "0"
	return signature


static func _run_random_match(field_seed: int, agent_seed: int) -> ResultScript:
	var board := Board.new()
	board.configure(6, 6, 6, field_seed)
	var agent := RandomAgentScript.new()
	agent.configure(agent_seed)
	var simulator := Simulator.new()
	simulator.setup(board, agent, {"record_history": true})
	return simulator.run_to_completion()
