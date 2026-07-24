extends SceneTree

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Manager := preload("res://scripts/evolution/evolution_manager.gd")


func _initialize() -> void:
	var manager := Manager.new()
	var config := Config.new()
	if not manager.initialize(config):
		printerr("Falha ao inicializar: " + manager.last_error)
		quit(1)
		return
	var initial_network = manager.population.individuals[0].network.clone_network()
	var total_started: int = Time.get_ticks_usec()
	for index: int in range(3):
		var result = manager.run_generation_sync()
		print("G%04d | campeão %s | treino %.2f | validação %.2f | vit %.1f%% | progresso %.1f%% | %.2fs" % [
			result.generation, result.champion_identifier, result.population_best_fitness,
			result.champion_validation.fitness_average, result.champion_validation.win_rate,
			result.champion_validation.average_progress * 100.0, result.elapsed_seconds,
		])
		if index < 2:
			manager.breed_next_generation()
	var elapsed: float = float(Time.get_ticks_usec() - total_started) / 1000000.0
	var random_summary: Dictionary = manager.evaluator.evaluate_random_agent(manager.validation_suite, config.master_seed + 8000)
	var initial_summary: Dictionary = manager.evaluator.evaluate_neural_network(initial_network, manager.validation_suite)
	var champion: Dictionary = manager.global_champion.validation_summary
	print("Validação comum | aleatório %.2f | neural %.2f | campeão %.2f" % [
		random_summary.fitness_average, initial_summary.fitness_average, champion.fitness_average,
	])
	print("3 gerações padrão em %.2fs | histórico %d | genoma %d" % [elapsed, manager.history.size(), manager.global_champion.get_genome().size()])
	quit(0)
