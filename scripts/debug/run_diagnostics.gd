extends SceneTree

const SelfTest := preload("res://scripts/debug/board_self_test.gd")


func _initialize() -> void:
	var result: Dictionary = SelfTest.run_all()
	print(result.summary)
	if result.failed > 0:
		for failure: String in result.failures:
			print("  FALHA: " + failure)
	quit(result.failed)
