class_name BoardSelfTest
extends RefCounted

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const TEST_WIDTH: int = 6
const TEST_HEIGHT: int = 6
const TEST_MINES: int = 6
const TEST_SEED: int = 4700606
const FIRST_MOVE := Vector2i(2, 2)


static func run_all() -> Dictionary:
	var failures: Array[String] = []
	_run_test("Quantidade de minas correta", _test_mine_count, failures)
	_run_test("Reprodução com a mesma seed", _test_same_seed, failures)
	_run_test("Seeds diferentes geram campos diferentes", _test_different_seeds, failures)
	_run_test("Números adjacentes corretos", _test_adjacent_counts, failures)
	_run_test("Primeira revelação segura", _test_first_reveal_safe, failures)
	_run_test("Cascata não revela minas", _test_cascade_is_safe, failures)
	_run_test("Bandeira impede revelação", _test_flag_blocks_reveal, failures)
	_run_test("Vitória ao revelar casas seguras", _test_victory, failures)
	var passed: int = 8 - failures.size()
	return {
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
		"summary": "Diagnósticos: %d aprovados, %d falhas" % [passed, failures.size()],
	}


static func _run_test(test_name: String, test_callable: Callable, failures: Array[String]) -> void:
	var error_message: String = test_callable.call()
	if not error_message.is_empty():
		var detail := "%s — %s" % [test_name, error_message]
		failures.append(detail)
		push_error("[NeuroMine Lab] " + detail)


static func _new_generated_board(board_seed: int = TEST_SEED) -> MinesweeperBoard:
	var board := Board.new()
	board.configure(TEST_WIDTH, TEST_HEIGHT, TEST_MINES, board_seed)
	board.start_or_reveal_first(FIRST_MOVE)
	return board


static func _test_mine_count() -> String:
	var board := _new_generated_board()
	var found: int = 0
	for state: Dictionary in board.get_debug_board_state():
		found += 1 if state.has_mine else 0
	return "esperado %d, encontrado %d" % [TEST_MINES, found] if found != TEST_MINES else ""


static func _test_same_seed() -> String:
	var first_signature := _mine_signature(_new_generated_board(TEST_SEED))
	var second_signature := _mine_signature(_new_generated_board(TEST_SEED))
	return "assinaturas do campo divergiram" if first_signature != second_signature else ""


static func _test_different_seeds() -> String:
	var base_signature := _mine_signature(_new_generated_board(TEST_SEED))
	for offset: int in range(1, 6):
		if _mine_signature(_new_generated_board(TEST_SEED + offset)) != base_signature:
			return ""
	return "cinco seeds consecutivas produziram a mesma distribuição"


static func _test_adjacent_counts() -> String:
	var board := _new_generated_board()
	var states: Array[Dictionary] = board.get_debug_board_state()
	for state: Dictionary in states:
		if state.has_mine:
			continue
		var expected: int = 0
		var position: Vector2i = state.position
		for y: int in range(maxi(0, position.y - 1), mini(TEST_HEIGHT, position.y + 2)):
			for x: int in range(maxi(0, position.x - 1), mini(TEST_WIDTH, position.x + 2)):
				if states[y * TEST_WIDTH + x].has_mine:
					expected += 1
		if state.adjacent_mines != expected:
			return "%s possui %d, esperado %d" % [position, state.adjacent_mines, expected]
	return ""


static func _test_first_reveal_safe() -> String:
	var board := _new_generated_board()
	var first_state: Dictionary = board.get_debug_board_state()[FIRST_MOVE.y * TEST_WIDTH + FIRST_MOVE.x]
	return "a primeira casa contém mina" if first_state.has_mine else ""


static func _test_cascade_is_safe() -> String:
	var board := _new_generated_board()
	for state: Dictionary in board.get_debug_board_state():
		if state.visibility == Types.CellVisibility.REVEALED and state.has_mine:
			return "uma mina foi revelada durante abertura segura"
	return ""


static func _test_flag_blocks_reveal() -> String:
	var board := Board.new()
	board.configure(TEST_WIDTH, TEST_HEIGHT, TEST_MINES, TEST_SEED)
	var flagged_position := Vector2i(1, 1)
	board.toggle_flag(flagged_position)
	var reveal_result: bool = board.start_or_reveal_first(flagged_position)
	var state: Dictionary = board.get_cell_state(flagged_position)
	if reveal_result or state.visibility != Types.CellVisibility.FLAGGED or board.is_generated():
		return "casa marcada foi revelada ou iniciou a geração"
	return ""


static func _test_victory() -> String:
	var board := _new_generated_board()
	for state: Dictionary in board.get_debug_board_state():
		if not state.has_mine:
			board.reveal(state.position)
	if not board.is_victory() or board.get_unrevealed_safe_count() != 0:
		return "estado final não foi reconhecido como vitória"
	return ""


static func _mine_signature(board: MinesweeperBoard) -> String:
	var signature := ""
	for state: Dictionary in board.get_debug_board_state():
		signature += "1" if state.has_mine else "0"
	return signature
