class_name ScenarioDiagnostics
extends RefCounted

const Scenario := preload("res://scripts/simulation/evaluation_scenario.gd")
const Suite := preload("res://scripts/simulation/evaluation_suite.gd")
const Board := preload("res://scripts/core/minesweeper_board.gd")
const Evaluator := preload("res://scripts/evolution/fitness_evaluator.gd")
const Action := preload("res://scripts/agents/agent_action.gd")

class ProbeAgent extends MinesweeperAgent:
	var first_observation: Dictionary = {}
	func choose_action(observation: Dictionary) -> AgentAction:
		if first_observation.is_empty(): first_observation = observation.duplicate(true)
		for cell: Dictionary in observation.cells:
			if int(cell.visibility) == MinesweeperTypes.CellVisibility.COVERED:
				return Action.reveal(cell.position)
		return null


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	var central := Scenario.new(6, 6, 6, 123, Vector2i(3, 3))
	var alternate := Scenario.new(6, 6, 6, 123, Vector2i(1, 1))
	_test("Seed isolada não é identidade completa", central.get_identifier() != alternate.get_identifier(), failures)
	var board_a := _generated_board(central); var board_b := _generated_board(central)
	_test("Seed e primeira coordenada reproduzem campo", board_a.get_debug_board_state() == board_b.get_debug_board_state(), failures)
	var board_c := _generated_board(alternate)
	_test("Primeiras coordenadas distintas podem mudar campo", _mine_positions(board_a) != _mine_positions(board_c), failures)
	var suite_a: Suite = Suite.create_deterministic("train", 8, 900, 4)
	var suite_b: Suite = Suite.create_deterministic("train", 8, 900, 4)
	_test("Todos recebem os mesmos cenários na geração", suite_a.get_identifiers() == suite_b.get_identifiers(), failures)
	var starts_equal: bool = true
	for scenario: Scenario in suite_a.scenarios: starts_equal = starts_equal and scenario.first_reveal == Vector2i(3, 3)
	_test("Primeira revelação é idêntica para todos", starts_equal, failures)
	var probe := ProbeAgent.new(); Evaluator.new().run_scenario(probe, central)
	_test("Rede age somente após abertura fixa", not probe.first_observation.is_empty() and int(probe.first_observation.move_count) == 1 and int(probe.first_observation.revealed_safe_cells) > 0, failures)
	var training: Suite = Suite.create_deterministic("training", 8, 77, 1)
	var validation: Suite = Suite.create_deterministic("validation", 20, 77, -1)
	var overlap: bool = false
	for identifier: String in training.get_identifiers(): overlap = overlap or identifier in validation.get_identifiers()
	_test("Validação não se mistura ao treinamento", not overlap and training.suite_identifier != validation.suite_identifier, failures)
	var validation_copy: Array[String] = validation.get_identifiers()
	Suite.create_deterministic("training-2", 8, 77, 2)
	_test("Suíte de validação permanece fixa", validation.get_identifiers() == validation_copy, failures)
	return {"passed": 8 - failures.size(), "failed": failures.size(), "failures": failures}


static func _generated_board(scenario: Scenario) -> Board:
	var board := Board.new()
	board.configure(scenario.width, scenario.height, scenario.mine_count, scenario.field_seed)
	board.start_or_reveal_first(scenario.first_reveal)
	return board


static func _mine_positions(board: Board) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Dictionary in board.get_debug_board_state():
		if cell.has_mine: result.append(cell.position)
	return result


static func _test(name: String, condition: bool, failures: Array[String]) -> void:
	if not condition:
		failures.append(name)
		push_error("[NeuroMine Lab] " + name)
