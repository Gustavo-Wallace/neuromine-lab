extends SceneTree

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")
const OutputAnalyzer := preload("res://scripts/evolution/neural_output_analyzer.gd")


func _initialize() -> void:
	_run_environment(Config.ENV_CALIBRATION_5X5, 20)
	_run_environment(Config.ENV_MAIN_6X6, 10)
	quit(0)


func _run_environment(environment_kind: int, generation_count: int) -> void:
	var config: Config = Config.create_calibrated(environment_kind)
	var manager := Manager.new()
	manager.initialize(config)
	var total_started: int = Time.get_ticks_usec()
	for index: int in range(generation_count):
		var result = manager.run_generation_sync()
		print("AUDIT_PROGRESS|%s|G=%d|TRAIN=%.3f|MEAN=%.3f|VAL=%.3f|DIV=%.6f|MUT=%.2f|OUTPUT=%s|NOIMP=%d|SEC=%.3f" % [
			config.environment_name, result.generation, result.population_best_fitness,
			result.population_average_fitness, result.champion_validation.fitness_average,
			result.diversity.mean_parameter_stddev, result.average_mutated_parameters,
			OutputAnalyzer.to_text(result.neural_output_condition),
			result.generations_without_improvement, result.elapsed_seconds,
		])
		if index < generation_count - 1:
			manager.breed_next_generation()
	var comparison: Dictionary = manager.get_baseline_comparison()
	var first = manager.history[0]
	var last = manager.history.back()
	var mutation_sum: float = 0.0
	var mutation_generations: int = 0
	var saturated_generations: int = 0
	var elapsed_sum: float = 0.0
	for result in manager.history:
		elapsed_sum += result.elapsed_seconds
		if result.average_mutated_parameters > 0.0:
			mutation_sum += result.average_mutated_parameters
			mutation_generations += 1
		if result.neural_output_condition in [OutputAnalyzer.Condition.SATURATED_ZERO, OutputAnalyzer.Condition.SATURATED_ONE, OutputAnalyzer.Condition.INVALID]:
			saturated_generations += 1
	print("AUDIT_SUMMARY|%s|GENERATIONS=%d|TRAIN_FIRST=%.3f|TRAIN_LAST=%.3f|MEAN_FIRST=%.3f|MEAN_LAST=%.3f|VAL_FIRST=%.3f|VAL_LAST=%.3f|VAL_GLOBAL=%.3f|DIV_FIRST=%.6f|DIV_LAST=%.6f|MUT_AVG=%.2f|SATURATED=%d|SEC_AVG=%.3f|SEC_TOTAL=%.3f" % [
		config.environment_name, generation_count, first.population_best_fitness, last.population_best_fitness,
		first.population_average_fitness, last.population_average_fitness,
		first.champion_validation.fitness_average, last.champion_validation.fitness_average,
		manager.global_champion.validation_summary.fitness_average,
		first.diversity.mean_parameter_stddev, last.diversity.mean_parameter_stddev,
		mutation_sum / float(maxi(1, mutation_generations)), saturated_generations,
		elapsed_sum / float(generation_count), float(Time.get_ticks_usec() - total_started) / 1000000.0,
	])
	for key: String in ["random", "untrained_neural", "generation_champion", "global_champion"]:
		var summary: Dictionary = comparison[key]
		print("AUDIT_BASELINE|%s|%s|FIT=%.3f|PROGRESS=%.3f|WINS=%d|SAFE=%.3f|MOVES=%.3f" % [
			config.environment_name, key, summary.fitness_average, summary.average_progress * 100.0,
			summary.victories, summary.average_safe_decisions, summary.average_moves,
		])
