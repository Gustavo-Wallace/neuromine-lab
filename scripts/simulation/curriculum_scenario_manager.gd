class_name CurriculumScenarioManager
extends RefCounted

const Suite := preload("res://scripts/simulation/evaluation_suite.gd")
const Scenario := preload("res://scripts/simulation/evaluation_scenario.gd")

var master_seed: int = 0
var phase_index: int = 1
var width: int = 5
var height: int = 5
var mine_count: int = 3
var core_count: int = 4
var rotating_count: int = 8
var pool_size: int = 256
var training_pool: Suite
var validation_suite: Suite
var final_test_suite: Suite


func configure(config, phase) -> void:
	master_seed = config.master_seed
	phase_index = phase.index
	width = phase.width
	height = phase.height
	mine_count = phase.mine_count
	core_count = config.fixed_training_core_count
	rotating_count = config.rotating_training_count
	pool_size = config.training_pool_size
	training_pool = Suite.create_deterministic(
		"F%d-training-pool" % phase_index, pool_size, master_seed, _salt(100), width, height, mine_count
	)
	validation_suite = Suite.create_deterministic(
		"F%d-validation-fixed" % phase_index, config.validation_scenario_count,
		master_seed, _salt(200), width, height, mine_count
	)
	final_test_suite = Suite.create_deterministic(
		"F%d-final-test" % phase_index, config.final_test_scenario_count,
		master_seed, _salt(300), width, height, mine_count
	)


func create_training_suite(phase_generation: int) -> Suite:
	var suite := Suite.new()
	suite.suite_identifier = "F%d-training-G%04d" % [phase_index, phase_generation]
	suite.core_count = core_count
	for index: int in range(core_count):
		suite.scenarios.append(training_pool.scenarios[index].duplicate_scenario())
	var available: int = pool_size - core_count
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(master_seed ^ (phase_index * 1000003) ^ (phase_generation * 9176)) + 1
	var indices: Array[int] = []
	for index: int in range(core_count, pool_size): indices.append(index)
	for index: int in range(indices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: int = indices[index]; indices[index] = indices[swap_index]; indices[swap_index] = temporary
	for index: int in range(mini(rotating_count, available)):
		suite.scenarios.append(training_pool.scenarios[indices[index]].duplicate_scenario())
	return suite


func _salt(kind: int) -> int:
	return phase_index * 10000 + kind
