class_name FitnessEvaluator
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")
const RandomAgentScript := preload("res://scripts/agents/random_agent.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const Result := preload("res://scripts/simulation/simulation_result.gd")
const Scenario := preload("res://scripts/simulation/evaluation_scenario.gd")
const Suite := preload("res://scripts/simulation/evaluation_suite.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const EvolutionConfig := preload("res://scripts/evolution/evolutionary_config.gd")

var config: EvolutionConfig = EvolutionConfig.new()


func configure(evolution_config: EvolutionConfig) -> void:
	config = evolution_config.duplicate_config()


func evaluate_individual(individual: Individual, suite: Suite, validation: bool = false) -> Dictionary:
	var summaries: Array[Dictionary] = []
	for scenario: Scenario in suite.scenarios:
		var agent := NeuralAgentScript.new()
		agent.set_network(individual.network.clone_network(), false)
		agent.agent_identifier = individual.identifier
		agent.trained = true
		agent.telemetry_enabled = true
		agent.telemetry_tolerance = config.equal_score_tolerance
		var result: Result = run_scenario(agent, scenario)
		var scored: Dictionary = score_result(result)
		scored["neural_telemetry"] = agent.get_telemetry_summary()
		summaries.append(scored)
	var summary: Dictionary = _aggregate(summaries, suite.suite_identifier)
	if validation:
		individual.validation_summary = summary.duplicate(true)
	else:
		individual.update_training_summary(summary)
	return summary


func evaluate_random_agent(suite: Suite, agent_seed: int) -> Dictionary:
	var summaries: Array[Dictionary] = []
	for scenario_index: int in range(suite.scenarios.size()):
		var agent := RandomAgentScript.new()
		agent.configure(agent_seed + scenario_index)
		summaries.append(score_result(run_scenario(agent, suite.scenarios[scenario_index])))
	return _aggregate(summaries, suite.suite_identifier)


func evaluate_neural_network(network, suite: Suite) -> Dictionary:
	var temporary := Individual.new()
	temporary.identifier = "baseline-neural"
	temporary.network = network.clone_network()
	return evaluate_individual(temporary, suite, true)


func run_scenario(agent: MinesweeperAgent, scenario: Scenario) -> Result:
	var board := Board.new()
	board.configure(scenario.width, scenario.height, scenario.mine_count, scenario.field_seed)
	if not board.start_or_reveal_first(scenario.first_reveal):
		var invalid := Result.new()
		invalid.end_reason = Result.EndReason.INVALID_STATE
		invalid.scenario_identifier = scenario.get_identifier()
		return invalid
	var simulator := Simulator.new()
	simulator.setup(board, agent, {
		"max_actions": scenario.width * scenario.height * 4,
		"observation_action_offset": 1,
		"fixed_first_move": scenario.first_reveal,
		"scenario_identifier": scenario.get_identifier(),
	})
	return simulator.run_to_completion()


func score_result(result: Result) -> Dictionary:
	# Formula v1: progresso², vitória e eficiência; penalidades explícitas ficam
	# centralizadas em EvolutionaryConfig para que UI, testes e evolução concordem.
	var progress: float = (
		float(result.revealed_safe_cells) / float(result.total_safe_cells)
		if result.total_safe_cells > 0 else 0.0
	)
	var score: float = progress * config.progress_fitness_scale if config.linear_progress_fitness else progress * progress * config.progress_fitness_scale
	score += float(result.safe_decision_count) * config.safe_decision_bonus
	if result.victory:
		score += config.victory_bonus
		var maximum_actions: int = maxi(1, result.max_action_attempts)
		score += (1.0 - clampf(float(result.move_count) / float(maximum_actions), 0.0, 1.0)) * config.victory_efficiency_scale
	score -= float(result.invalid_action_count) * config.invalid_action_penalty
	if result.end_reason in [Result.EndReason.INVALID_STATE, Result.EndReason.MAX_ACTIONS_REACHED]:
		score -= config.invalid_end_penalty
	if result.end_reason == Result.EndReason.MINE_DETONATED:
		score -= config.mine_detonation_penalty
	return {
		"scenario_identifier": result.scenario_identifier, "fitness": score,
		"victory": result.victory, "progress": progress, "moves": result.move_count,
		"safe_decisions": result.safe_decision_count,
		"invalid_actions": result.invalid_action_count, "end_reason": result.end_reason,
	}


func _aggregate(matches: Array[Dictionary], suite_identifier: String) -> Dictionary:
	var total_fitness: float = 0.0
	var victories: int = 0
	var total_progress: float = 0.0
	var best_progress: float = 0.0
	var total_moves: int = 0
	var total_safe_decisions: int = 0
	var telemetry_decisions: int = 0
	var telemetry_score_count: int = 0
	var telemetry_score_mean_sum: float = 0.0
	var telemetry_stddev_sum: float = 0.0
	var telemetry_range_sum: float = 0.0
	var telemetry_equal_sum: float = 0.0
	var telemetry_non_finite: int = 0
	var first_decisions: Array[Vector2i] = []
	for match_summary: Dictionary in matches:
		total_fitness += float(match_summary.fitness)
		victories += 1 if match_summary.victory else 0
		total_progress += float(match_summary.progress)
		best_progress = maxf(best_progress, float(match_summary.progress))
		total_moves += int(match_summary.moves)
		total_safe_decisions += int(match_summary.get("safe_decisions", 0))
		var telemetry: Dictionary = match_summary.get("neural_telemetry", {})
		if not telemetry.is_empty():
			telemetry_decisions += int(telemetry.get("decision_count", 0))
			telemetry_score_count += int(telemetry.get("score_count", 0))
			telemetry_score_mean_sum += float(telemetry.get("score_mean", 0.0))
			telemetry_stddev_sum += float(telemetry.get("score_stddev", 0.0))
			telemetry_range_sum += float(telemetry.get("mean_score_range", 0.0))
			telemetry_equal_sum += float(telemetry.get("mean_near_equal_candidates", 0.0))
			telemetry_non_finite += int(telemetry.get("non_finite_count", 0))
			var first_position: Vector2i = telemetry.get("first_decision", Vector2i(-1, -1))
			if first_position != Vector2i(-1, -1): first_decisions.append(first_position)
	var count: int = matches.size()
	return {
		"suite_identifier": suite_identifier, "fitness_total": total_fitness,
		"fitness_average": total_fitness / float(maxi(1, count)),
		"victories": victories, "win_rate": 100.0 * float(victories) / float(maxi(1, count)),
		"average_progress": total_progress / float(maxi(1, count)), "best_progress": best_progress,
		"average_moves": float(total_moves) / float(maxi(1, count)), "evaluated_matches": count,
		"safe_decisions": total_safe_decisions,
		"average_safe_decisions": float(total_safe_decisions) / float(maxi(1, count)),
		"neural_telemetry": {
			"decision_count": telemetry_decisions, "score_count": telemetry_score_count,
			"score_mean": telemetry_score_mean_sum / float(maxi(1, count)),
			"score_stddev": telemetry_stddev_sum / float(maxi(1, count)),
			"mean_score_range": telemetry_range_sum / float(maxi(1, count)),
			"mean_near_equal_candidates": telemetry_equal_sum / float(maxi(1, count)),
			"non_finite_count": telemetry_non_finite, "first_decisions": first_decisions,
		},
		"matches": matches.duplicate(true),
	}
