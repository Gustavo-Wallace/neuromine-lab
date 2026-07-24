extends SceneTree

const SelfTest := preload("res://scripts/debug/diagnostic_suite.gd")


func _initialize() -> void:
	var result: Dictionary = SelfTest.run_all()
	print(result.summary)
	if result.has("observation_benchmark"):
		print("Observações: %.0f/s" % result.observation_benchmark.observations_per_second)
	if result.failed > 0:
		for failure: String in result.failures:
			print("  FALHA: " + failure)
	quit(result.failed)
