extends SceneTree

const ObservationTests := preload("res://scripts/debug/observation_diagnostics.gd")


func _initialize() -> void:
	var result: Dictionary = ObservationTests.run_benchmark(1000)
	print("Benchmark de observação: %d vetores em %.3f s (%.0f observações/s)" % [
		result.observations,
		result.elapsed_seconds,
		result.observations_per_second,
	])
	quit(0)
