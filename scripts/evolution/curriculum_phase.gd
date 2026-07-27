class_name CurriculumPhase
extends RefCounted

var index: int = 1
var display_name: String = "Fundamentos"
var width: int = 5
var height: int = 5
var mine_count: int = 3
var minimum_generations: int = 10
var recommended_maximum_generations: int = 30
var required_validation_wins: int = 6
var minimum_validation_fitness: float = 4000.0
var require_baseline_improvement: bool = false
var automatic_advancement_available: bool = true


static func create_all() -> Array[CurriculumPhase]:
	var first := new()
	var second := new()
	second.index = 2
	second.display_name = "Transição"
	second.width = 6
	second.height = 6
	second.mine_count = 4
	second.required_validation_wins = 3
	second.minimum_validation_fitness = 0.0
	second.require_baseline_improvement = true
	var third := new()
	third.index = 3
	third.display_name = "Principal"
	third.width = 6
	third.height = 6
	third.mine_count = 6
	third.minimum_generations = 0
	third.required_validation_wins = 0
	third.minimum_validation_fitness = 0.0
	third.automatic_advancement_available = false
	return [first, second, third]


func get_full_name() -> String:
	return "%d — %s %d×%d / %d minas" % [index, display_name, width, height, mine_count]


func apply_to_config(config) -> void:
	config.board_width = width
	config.board_height = height
	config.mine_count = mine_count
	config.first_reveal = Vector2i(width / 2, height / 2)
	config.environment_name = get_full_name()


func criteria_status(phase_generation: int, validation: Dictionary, baselines: Dictionary = {}) -> Dictionary:
	var generations_ok: bool = phase_generation >= minimum_generations
	var wins_ok: bool = int(validation.get("victories", 0)) >= required_validation_wins
	var fitness_ok: bool = float(validation.get("fitness_average", 0.0)) >= minimum_validation_fitness
	var baselines_ok: bool = true
	if require_baseline_improvement:
		var target: float = float(validation.get("fitness_average", -INF))
		baselines_ok = (
			target > float(baselines.get("random", {}).get("fitness_average", INF))
			and target > float(baselines.get("untrained_neural", {}).get("fitness_average", INF))
		)
	return {
		"generations_ok": generations_ok, "wins_ok": wins_ok,
		"fitness_ok": fitness_ok, "baselines_ok": baselines_ok,
		"all_met": automatic_advancement_available and generations_ok and wins_ok and fitness_ok and baselines_ok,
	}
