class_name SimulationManager
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const RandomAgentScript := preload("res://scripts/agents/random_agent.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const StatisticsScript := preload("res://scripts/simulation/simulation_statistics.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")


func run_batch(
	match_count: int,
	board_width: int,
	board_height: int,
	mine_count: int,
	field_seed_base: int,
	agent_seed_base: int,
	statistics: StatisticsScript,
	start_index: int = 0
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var last_result: ResultScript
	for local_index: int in range(match_count):
		var index: int = start_index + local_index
		var board := Board.new()
		board.configure(board_width, board_height, mine_count, field_seed_base + index)
		var agent := RandomAgentScript.new()
		agent.configure(agent_seed_base + index)
		var simulator := Simulator.new()
		simulator.setup(board, agent, {"record_history": false})
		last_result = simulator.run_to_completion()
		statistics.record(last_result)
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	statistics.set_last_batch_performance(match_count, elapsed_seconds)
	return {
		"count": match_count,
		"elapsed_seconds": elapsed_seconds,
		"matches_per_second": float(match_count) / elapsed_seconds if elapsed_seconds > 0.0 else 0.0,
		"last_result": last_result,
	}
