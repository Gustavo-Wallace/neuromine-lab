extends SceneTree

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Network := preload("res://scripts/neural/neural_network.gd")
const Config := preload("res://scripts/neural/neural_network_config.gd")
const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")
const Statistics := preload("res://scripts/simulation/simulation_statistics.gd")
const Manager := preload("res://scripts/simulation/simulation_manager.gd")


func _initialize() -> void:
	var network := Network.new()
	network.configure(Config.create_default(), 73001)
	var input := PackedFloat32Array()
	input.resize(network.config.architecture[0])
	input.fill(0.5)
	var inference_iterations: int = 5000
	var started_usec: int = Time.get_ticks_usec()
	for index: int in range(inference_iterations):
		network.forward(input)
	var inference_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0

	var board := Board.new()
	board.configure(6, 6, 6, 4700606)
	var state: Dictionary = board.get_agent_observation(0, 144)
	var agent := NeuralAgentScript.new()
	agent.configure_neural(73001, false)
	var candidate_iterations: int = 100
	var candidate_count: int = 0
	started_usec = Time.get_ticks_usec()
	for index: int in range(candidate_iterations):
		agent.choose_action(state)
		candidate_count += 36
	var candidate_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0

	var statistics := Statistics.new()
	var manager := Manager.new()
	var batch: Dictionary = manager.run_neural_batch(100, 6, 6, 6, 4700606, 73001, statistics)
	var random_statistics := Statistics.new()
	var random_batch: Dictionary = manager.run_batch(100, 6, 6, 6, 4700606, 91001, random_statistics)
	print("Benchmark neural:")
	print("  Inferências: %.0f/s" % (float(inference_iterations) / inference_seconds))
	print("  Candidatas avaliadas: %.0f/s" % (float(candidate_count) / candidate_seconds))
	print("  Partidas neurais: %.1f/s" % batch.matches_per_second)
	print("  Progresso médio: %.2f%%" % statistics.get_average_progress())
	print("Comparação de 100 partidas (não representa aprendizado):")
	print("  Aleatório: %.2f%% de progresso, %.1f partidas/s" % [random_statistics.get_average_progress(), random_batch.matches_per_second])
	print("  Neural aleatório: %.2f%% de progresso, %.1f partidas/s" % [statistics.get_average_progress(), batch.matches_per_second])
	quit(0)
