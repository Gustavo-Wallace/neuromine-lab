extends SceneTree

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")


func _initialize() -> void:
	var curriculum := Manager.new(); curriculum.initialize(Config.create_curriculum()); curriculum.automatic_advancement_blocked = true
	_run_generations(curriculum, 20, "CURRICULUM_F1")
	var curriculum_phase1_summary: Dictionary = curriculum.create_experiment_summary()
	var curriculum_phase1_validation: Array[String] = curriculum.validation_suite.get_identifiers()
	var criteria: Dictionary = curriculum.last_phase_criteria.duplicate(true)
	print("CURRICULUM_CRITERIA|phase=1|generations=%s|wins=%s|fitness=%s|baselines=%s|all=%s" % [criteria.get("generations_ok", false), criteria.get("wins_ok", false), criteria.get("fitness_ok", false), criteria.get("baselines_ok", false), criteria.get("all_met", false)])
	if bool(criteria.get("all_met", false)):
		curriculum.advance_phase(false)
		curriculum.automatic_advancement_blocked = true
		_run_generations(curriculum, 10, "CURRICULUM_F2")
	else:
		print("CURRICULUM_PHASE2|not_reached")
	var final_test: Dictionary = curriculum.execute_final_test()
	_print_final_test(final_test, curriculum)
	var calibrated_config: Config = Config.create_calibrated(Config.ENV_CALIBRATION_5X5)
	var calibrated := Manager.new(); calibrated.initialize(calibrated_config)
	_run_generations(calibrated, 20, "CALIBRATED_F1")
	var calibrated_summary: Dictionary = calibrated.create_experiment_summary()
	print("CONTROLLED_COMPARISON|same_validation=%s|curr_best=%.3f|cal_best=%.3f|curr_final=%.3f|cal_final=%.3f|curr_wins=%d|cal_wins=%d|curr_div=%.6f|cal_div=%.6f|curr_gap=%.3f|cal_gap=%.3f|curr_sec=%.3f|cal_sec=%.3f|curr_first_win=%d|cal_first_win=%d|curr_stagnant=%d|cal_stagnant=%d" % [
		curriculum_phase1_validation == calibrated.validation_suite.get_identifiers(),
		curriculum_phase1_summary.best_validation, calibrated_summary.best_validation, curriculum_phase1_summary.final_validation, calibrated_summary.final_validation,
		curriculum_phase1_summary.victories, calibrated_summary.victories, curriculum_phase1_summary.final_diversity, calibrated_summary.final_diversity,
		curriculum_phase1_summary.generalization_gap, calibrated_summary.generalization_gap, curriculum_phase1_summary.total_seconds, calibrated_summary.total_seconds,
		curriculum_phase1_summary.first_victory_generation, calibrated_summary.first_victory_generation, curriculum_phase1_summary.stagnant_generations, calibrated_summary.stagnant_generations,
	])
	quit(0)


func _run_generations(manager: Manager, count: int, label: String) -> void:
	for index: int in range(count):
		var result = manager.run_generation_sync()
		print("%s|global=%d|phase_gen=%d|train=%.3f|mean=%.3f|validation=%.3f|wins=%d|div=%.6f|gap=%.3f|immigrants=%d|clones=%d|sec=%.3f" % [label, result.global_generation, result.phase_generation, result.population_best_fitness, result.population_average_fitness, result.champion_validation.fitness_average, result.champion_validation.victories, result.diversity.mean_parameter_stddev, result.generalization_gap, result.breeding_metrics.get("immigrants", 0), result.breeding_metrics.get("clone_rejections", 0), result.elapsed_seconds])
		if index < count - 1: manager.breed_next_generation()


func _print_final_test(result: Dictionary, manager: Manager) -> void:
	if result.is_empty(): print("FINAL_TEST|unavailable"); return
	var champion: Dictionary = result.champion
	print("FINAL_TEST|phase=%d|executions=%d|fitness=%.3f|progress=%.3f|wins=%d|safe=%.3f|moves=%.3f|validation_delta=%.3f|random=%.3f|neural=%.3f" % [manager.current_phase_index, result.execution_count, champion.fitness_average, champion.average_progress * 100.0, champion.victories, champion.average_safe_decisions, champion.average_moves, result.validation_difference, result.random.fitness_average, result.untrained_neural.fitness_average])
