extends SceneTree

const Statistics := preload("res://scripts/simulation/simulation_statistics.gd")
const Manager := preload("res://scripts/simulation/simulation_manager.gd")


func _initialize() -> void:
	var manager := Manager.new()
	for match_count: int in [10, 100, 1000]:
		var statistics := Statistics.new()
		var result: Dictionary = manager.run_batch(match_count, 6, 6, 6, 4700606, 91001, statistics)
		print("Benchmark: %s partidas em %.3f s (%.0f partidas/s)" % [
			_format_integer(match_count), result.elapsed_seconds, result.matches_per_second
		])
		print("  Resultados: %d vitórias, %d derrotas, %.2f%% de progresso médio" % [
			statistics.victories, statistics.defeats, statistics.get_average_progress()
		])
	quit(0)


func _format_integer(value: int) -> String:
	return "1.000" if value == 1000 else str(value)
