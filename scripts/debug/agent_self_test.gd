class_name AgentSelfTest
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const RandomAgentScript := preload("res://scripts/agents/random_agent.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")
const Statistics := preload("res://scripts/simulation/simulation_statistics.gd")
const Manager := preload("res://scripts/simulation/simulation_manager.gd")
const FIELD_SEED: int = 4700606
const AGENT_SEED: int = 91001


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_run_test("Agente ignora casas reveladas", _test_agent_skips_revealed, failures)
	_run_test("Agente ignora casas marcadas", _test_agent_skips_flagged, failures)
	_run_test("Observação não revela minas ocultas", _test_observation_is_sanitized, failures)
	_run_test("Seeds reproduzem a sequência de ações", _test_seed_reproducibility, failures)
	_run_test("Simulador encerra em vitória", _test_victory_termination, failures)
	_run_test("Simulador encerra ao detonar mina", _test_mine_termination, failures)
	_run_test("Limite máximo de ações funciona", _test_max_actions, failures)
	_run_test("Lote acumula estatísticas", _test_batch_statistics, failures)
	_run_test("Modo rápido independe da interface", _test_headless_independence, failures)
	_run_test("Resultado registra seeds e primeira ação", _test_result_metadata, failures)
	return {
		"passed": 10 - failures.size(),
		"failed": failures.size(),
		"failures": failures,
	}


static func _run_test(test_name: String, test_callable: Callable, failures: Array[String]) -> void:
	var error_message: String = test_callable.call()
	if not error_message.is_empty():
		var detail := "%s — %s" % [test_name, error_message]
		failures.append(detail)
		push_error("[NeuroMine Lab] " + detail)


static func _test_agent_skips_revealed() -> String:
	var agent := RandomAgentScript.new()
	agent.configure(AGENT_SEED)
	var observation := _observation_with_cells([
		{"position": Vector2i(0, 0), "visibility": Types.CellVisibility.REVEALED, "content": "safe", "adjacent_mines": 1},
		{"position": Vector2i(1, 0), "visibility": Types.CellVisibility.COVERED},
	])
	for iteration: int in range(8):
		var action: AgentAction = agent.choose_action(observation)
		if not is_instance_valid(action) or action.position != Vector2i(1, 0):
			return "selecionou uma casa revelada"
	return ""


static func _test_agent_skips_flagged() -> String:
	var agent := RandomAgentScript.new()
	agent.configure(AGENT_SEED)
	var observation := _observation_with_cells([
		{"position": Vector2i(0, 0), "visibility": Types.CellVisibility.FLAGGED},
		{"position": Vector2i(1, 0), "visibility": Types.CellVisibility.COVERED},
	])
	for iteration: int in range(8):
		var action: AgentAction = agent.choose_action(observation)
		if not is_instance_valid(action) or action.position != Vector2i(1, 0):
			return "selecionou uma casa marcada"
	return ""


static func _test_observation_is_sanitized() -> String:
	var board := Board.new()
	board.configure(6, 6, 6, FIELD_SEED)
	board.start_or_reveal_first(Vector2i(2, 2))
	var observation: Dictionary = board.get_agent_observation(1)
	if observation.has("field_seed"):
		return "a seed do campo foi entregue ao agente sem necessidade"
	for cell: Dictionary in observation.cells:
		if cell.has("has_mine"):
			return "a propriedade has_mine foi exposta"
		if cell.visibility != Types.CellVisibility.REVEALED and (cell.has("content") or cell.has("adjacent_mines")):
			return "uma casa oculta contém informação interna"
	return ""


static func _test_seed_reproducibility() -> String:
	var first_result: ResultScript = _run_random_match(FIELD_SEED, AGENT_SEED, true)
	var second_result: ResultScript = _run_random_match(FIELD_SEED, AGENT_SEED, true)
	if _history_signature(first_result.action_history) != _history_signature(second_result.action_history):
		return "sequências de ações divergiram"
	if first_result.end_reason != second_result.end_reason:
		return "resultados finais divergiram"
	return ""


static func _test_victory_termination() -> String:
	var result: ResultScript = _run_random_match(101, 202, false, 3, 3, 0)
	if not result.victory or result.end_reason != ResultScript.EndReason.VICTORY:
		return "partida sem minas não terminou em vitória"
	return ""


static func _test_mine_termination() -> String:
	var result: ResultScript = _run_random_match(303, 404, false, 2, 2, 2)
	if result.end_reason != ResultScript.EndReason.MINE_DETONATED or result.detonated_position == Vector2i(-1, -1):
		return "detonação não foi registrada (motivo=%d, posição=%s, jogadas=%d)" % [result.end_reason, result.detonated_position, result.move_count]
	return ""


static func _test_max_actions() -> String:
	var board := Board.new()
	board.configure(2, 2, 1, 505)
	var agent := RandomAgentScript.new()
	agent.configure(606)
	var simulator := Simulator.new()
	simulator.setup(board, agent, {"max_actions": 1})
	var result: ResultScript = simulator.run_to_completion()
	if result.end_reason != ResultScript.EndReason.MAX_ACTIONS_REACHED or result.move_count != 1:
		return "limite derivado/configurado não encerrou a partida"
	return ""


static func _test_batch_statistics() -> String:
	var statistics := Statistics.new()
	var manager := Manager.new()
	var batch: Dictionary = manager.run_batch(10, 6, 6, 6, FIELD_SEED, AGENT_SEED, statistics)
	if statistics.matches_played != 10:
		return "esperadas 10 partidas, registradas %d" % statistics.matches_played
	if statistics.victories + statistics.defeats + statistics.interrupted_matches != 10:
		return "totais de resultados não fecham"
	if batch.matches_per_second <= 0.0:
		return "desempenho do lote não foi medido"
	return ""


static func _test_headless_independence() -> String:
	var statistics := Statistics.new()
	var manager := Manager.new()
	manager.run_batch(2, 6, 6, 6, FIELD_SEED, AGENT_SEED, statistics)
	if manager.get_script().get_instance_base_type() != "RefCounted":
		return "gerenciador rápido não é baseado em RefCounted"
	return "" if statistics.matches_played == 2 else "lote headless não foi concluído"


static func _test_result_metadata() -> String:
	var result: ResultScript = _run_random_match(FIELD_SEED, AGENT_SEED, true)
	if result.field_seed != FIELD_SEED or result.agent_seed != AGENT_SEED:
		return "seeds do resultado estão incorretas"
	if result.first_move == Vector2i(-1, -1) or result.action_history.is_empty():
		return "primeira ação não foi registrada"
	if result.first_move != result.action_history[0].position:
		return "primeira ação diverge do histórico"
	return ""


static func _run_random_match(
	field_seed: int,
	agent_seed: int,
	record_history: bool,
	width: int = 6,
	height: int = 6,
	mines: int = 6
) -> ResultScript:
	var board := Board.new()
	board.configure(width, height, mines, field_seed)
	var agent := RandomAgentScript.new()
	agent.configure(agent_seed)
	var simulator := Simulator.new()
	simulator.setup(board, agent, {"record_history": record_history})
	return simulator.run_to_completion()


static func _observation_with_cells(cells: Array[Dictionary]) -> Dictionary:
	return {
		"width": cells.size(),
		"height": 1,
		"cells": cells,
		"estimated_remaining_mines": 0,
		"move_count": 0,
		"status": Types.GameStatus.PLAYING,
	}


static func _history_signature(history: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for event: Dictionary in history:
		var position: Vector2i = event.position
		parts.append("%d,%d:%s" % [position.x, position.y, event.outcome])
	return "|".join(parts)
