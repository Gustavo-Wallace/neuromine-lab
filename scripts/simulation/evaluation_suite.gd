class_name EvaluationSuite
extends RefCounted

const Scenario := preload("res://scripts/simulation/evaluation_scenario.gd")

var suite_identifier: String = ""
var scenarios: Array[Scenario] = []
var core_count: int = 0


static func create_deterministic(
	identifier: String, count: int, master_seed: int, generation: int,
	width: int = 6, height: int = 6, mine_count: int = 6
):
	var suite = new()
	suite.suite_identifier = identifier
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(master_seed, generation)
	var center := Vector2i(width / 2, height / 2)
	for index: int in range(count):
		var field_seed: int = int(rng.randi())
		suite.scenarios.append(Scenario.new(width, height, mine_count, field_seed, center))
	return suite


static func _mix_seed(master_seed: int, generation: int) -> int:
	var mixed: int = master_seed ^ (generation * 1103515245 + 12345)
	return abs(mixed) + 1


func get_identifiers() -> Array[String]:
	var result: Array[String] = []
	for scenario: Scenario in scenarios:
		result.append(scenario.get_identifier())
	return result


func duplicate_suite():
	var copy = get_script().new()
	copy.suite_identifier = suite_identifier
	copy.core_count = core_count
	for scenario: Scenario in scenarios:
		copy.scenarios.append(scenario.duplicate_scenario())
	return copy
