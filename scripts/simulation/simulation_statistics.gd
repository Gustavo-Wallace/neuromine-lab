class_name SimulationStatistics
extends RefCounted

const ResultScript := preload("res://scripts/simulation/simulation_result.gd")

var matches_played: int = 0
var victories: int = 0
var defeats: int = 0
var interrupted_matches: int = 0
var detonated_mines: int = 0
var invalid_actions: int = 0
var progress_sum: float = 0.0
var best_progress: float = 0.0
var move_sum: int = 0
var fewest_moves_in_victory: int = -1
var last_batch_matches_per_second: float = 0.0


func reset() -> void:
	matches_played = 0
	victories = 0
	defeats = 0
	interrupted_matches = 0
	detonated_mines = 0
	invalid_actions = 0
	progress_sum = 0.0
	best_progress = 0.0
	move_sum = 0
	fewest_moves_in_victory = -1
	last_batch_matches_per_second = 0.0


func record(result: ResultScript) -> void:
	matches_played += 1
	move_sum += result.move_count
	progress_sum += result.progress_percent
	best_progress = maxf(best_progress, result.progress_percent)
	invalid_actions += result.invalid_action_count
	if result.victory:
		victories += 1
		if fewest_moves_in_victory < 0 or result.move_count < fewest_moves_in_victory:
			fewest_moves_in_victory = result.move_count
	elif result.end_reason == ResultScript.EndReason.MINE_DETONATED:
		defeats += 1
		detonated_mines += 1
	else:
		interrupted_matches += 1


func set_last_batch_performance(match_count: int, elapsed_seconds: float) -> void:
	last_batch_matches_per_second = float(match_count) / elapsed_seconds if elapsed_seconds > 0.0 else 0.0


func get_win_rate() -> float:
	return 100.0 * float(victories) / float(matches_played) if matches_played > 0 else 0.0


func get_average_progress() -> float:
	return progress_sum / float(matches_played) if matches_played > 0 else 0.0


func get_average_moves() -> float:
	return float(move_sum) / float(matches_played) if matches_played > 0 else 0.0


func to_dictionary() -> Dictionary:
	return {
		"matches_played": matches_played,
		"victories": victories,
		"defeats": defeats,
		"win_rate": get_win_rate(),
		"average_progress": get_average_progress(),
		"best_progress": best_progress,
		"average_moves": get_average_moves(),
		"fewest_moves_in_victory": fewest_moves_in_victory,
		"detonated_mines": detonated_mines,
		"interrupted_matches": interrupted_matches,
		"invalid_actions": invalid_actions,
		"last_batch_matches_per_second": last_batch_matches_per_second,
	}
