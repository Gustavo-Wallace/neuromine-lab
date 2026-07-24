class_name MatchSimulator
extends RefCounted

const Types := preload("res://scripts/core/minesweeper_types.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")
const ActionScript := preload("res://scripts/agents/agent_action.gd")

var board: MinesweeperBoard
var agent: MinesweeperAgent
var max_action_attempts: int = 0
var record_history: bool = false
var valid_action_count: int = 0
var invalid_action_count: int = 0
var action_attempt_count: int = 0
var first_move: Vector2i = Vector2i(-1, -1)

var _pending_action: AgentAction
var _result: ResultScript
var _history: Array[Dictionary] = []
var _started_usec: int = 0


func setup(match_board: MinesweeperBoard, match_agent: MinesweeperAgent, configuration: Dictionary = {}) -> void:
	board = match_board
	agent = match_agent
	max_action_attempts = int(configuration.get("max_actions", board.width * board.height * 4))
	record_history = bool(configuration.get("record_history", false))
	_clear_runtime_state()


func reset_same_match() -> void:
	board.reset_same_seed()
	agent.reset()
	_clear_runtime_state()


func prepare_next_action() -> AgentAction:
	if is_finished():
		return null
	if not is_instance_valid(board) or not is_instance_valid(agent):
		_finalize(ResultScript.EndReason.INVALID_STATE)
		return null
	if board.is_finished():
		_finalize(_reason_from_board())
		return null
	if action_attempt_count >= max_action_attempts:
		_finalize(ResultScript.EndReason.MAX_ACTIONS_REACHED)
		return null
	if is_instance_valid(_pending_action):
		return _pending_action
	if _started_usec == 0:
		_started_usec = Time.get_ticks_usec()
	var observation: Dictionary = board.get_agent_observation(valid_action_count, max_action_attempts)
	_pending_action = agent.choose_action(observation)
	if not is_instance_valid(_pending_action):
		_finalize(ResultScript.EndReason.NO_VALID_ACTIONS)
		return null
	return _pending_action


func execute_pending_action() -> Dictionary:
	if is_finished():
		return {"finished": true, "result": _result}
	if not is_instance_valid(_pending_action):
		_finalize(ResultScript.EndReason.INVALID_STATE)
		return {"finished": true, "result": _result}

	var action: AgentAction = _pending_action
	_pending_action = null
	action_attempt_count += 1
	var observation: Dictionary = board.get_agent_observation(valid_action_count, max_action_attempts)
	if not _is_action_valid(action, observation):
		invalid_action_count += 1
		var invalid_event := _make_event(action, false, "Inválida")
		_store_event(invalid_event)
		if action_attempt_count >= max_action_attempts:
			_finalize(ResultScript.EndReason.MAX_ACTIONS_REACHED)
		invalid_event["finished"] = is_finished()
		invalid_event["result"] = _result
		return invalid_event

	var action_applied: bool = _apply_action(action)
	if not action_applied:
		invalid_action_count += 1
		var rejected_event := _make_event(action, false, "Rejeitada")
		_store_event(rejected_event)
		if action_attempt_count >= max_action_attempts:
			_finalize(ResultScript.EndReason.MAX_ACTIONS_REACHED)
		rejected_event["finished"] = is_finished()
		rejected_event["result"] = _result
		return rejected_event

	valid_action_count += 1
	if first_move == Vector2i(-1, -1) and action.type == ActionScript.ActionType.REVEAL_CELL:
		first_move = action.position
	var was_mine: bool = board.status == Types.GameStatus.LOST and board.get_detonated_position() == action.position
	var event := _make_event(action, true, "Mina" if was_mine else "Seguro")
	_store_event(event)
	if board.is_finished():
		_finalize(_reason_from_board())
	elif action_attempt_count >= max_action_attempts:
		_finalize(ResultScript.EndReason.MAX_ACTIONS_REACHED)
	event["finished"] = is_finished()
	event["result"] = _result
	return event


func step() -> Dictionary:
	var action: AgentAction = prepare_next_action()
	if not is_instance_valid(action):
		return {"finished": is_finished(), "result": _result}
	return execute_pending_action()


func run_to_completion() -> ResultScript:
	while not is_finished():
		step()
	return _result


func stop() -> ResultScript:
	if not is_finished():
		_finalize(ResultScript.EndReason.MANUALLY_STOPPED)
	return _result


func is_finished() -> bool:
	return is_instance_valid(_result)


func get_result() -> ResultScript:
	return _result


func get_pending_action() -> AgentAction:
	return _pending_action


func _clear_runtime_state() -> void:
	_pending_action = null
	_result = null
	valid_action_count = 0
	invalid_action_count = 0
	action_attempt_count = 0
	first_move = Vector2i(-1, -1)
	_history.clear()
	_started_usec = 0


func _is_action_valid(action: AgentAction, observation: Dictionary) -> bool:
	if action.position.x < 0 or action.position.x >= board.width or action.position.y < 0 or action.position.y >= board.height:
		return false
	var index: int = action.position.y * board.width + action.position.x
	var cells: Array = observation.get("cells", [])
	if index < 0 or index >= cells.size() or not cells[index] is Dictionary:
		return false
	var visibility: int = cells[index].get("visibility", -1)
	match action.type:
		ActionScript.ActionType.REVEAL_CELL, ActionScript.ActionType.PLACE_FLAG:
			return visibility == Types.CellVisibility.COVERED
		ActionScript.ActionType.REMOVE_FLAG:
			return visibility == Types.CellVisibility.FLAGGED
	return false


func _apply_action(action: AgentAction) -> bool:
	match action.type:
		ActionScript.ActionType.REVEAL_CELL:
			return board.start_or_reveal_first(action.position)
		ActionScript.ActionType.PLACE_FLAG, ActionScript.ActionType.REMOVE_FLAG:
			return board.toggle_flag(action.position)
	return false


func _make_event(action: AgentAction, valid: bool, outcome: String) -> Dictionary:
	return {
		"number": action_attempt_count,
		"action": action.to_dictionary(),
		"valid": valid,
		"outcome": outcome,
		"position": action.position,
	}


func _store_event(event: Dictionary) -> void:
	if record_history:
		_history.append(event.duplicate(true))


func _reason_from_board() -> int:
	return ResultScript.EndReason.VICTORY if board.is_victory() else ResultScript.EndReason.MINE_DETONATED


func _finalize(reason: int) -> void:
	if is_finished():
		return
	_result = ResultScript.new()
	_result.victory = reason == ResultScript.EndReason.VICTORY
	_result.move_count = valid_action_count
	_result.revealed_safe_cells = board.get_revealed_safe_count() if is_instance_valid(board) else 0
	_result.total_safe_cells = board.get_total_safe_count() if is_instance_valid(board) else 0
	_result.progress_percent = (
		100.0 * float(_result.revealed_safe_cells) / float(_result.total_safe_cells)
		if _result.total_safe_cells > 0 else 0.0
	)
	_result.detonated_position = board.get_detonated_position() if is_instance_valid(board) else Vector2i(-1, -1)
	_result.field_seed = board.seed if is_instance_valid(board) else 0
	_result.agent_seed = agent.agent_seed if is_instance_valid(agent) else 0
	_result.first_move = first_move
	_result.end_reason = reason
	_result.invalid_action_count = invalid_action_count
	_result.agent_metadata = agent.get_result_metadata() if is_instance_valid(agent) else {}
	if record_history:
		_result.action_history.assign(_history)
	_result.duration_seconds = (
		float(Time.get_ticks_usec() - _started_usec) / 1000000.0
		if _started_usec > 0 else 0.0
	)
