extends Control

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const SelfTest := preload("res://scripts/debug/board_self_test.gd")
const INITIAL_WIDTH: int = 6
const INITIAL_HEIGHT: int = 6
const INITIAL_MINES: int = 6
const INITIAL_SEED: int = 4700606

@onready var board_view: BoardView = %BoardView
@onready var size_value: Label = %SizeValue
@onready var mines_value: Label = %MinesValue
@onready var remaining_value: Label = %RemainingValue
@onready var current_seed_value: LineEdit = %CurrentSeedValue
@onready var state_value: Label = %StateValue
@onready var revealed_value: Label = %RevealedValue
@onready var seed_input: LineEdit = %SeedInput
@onready var diagnostic_result: Label = %DiagnosticResult

var board: MinesweeperBoard


func _ready() -> void:
	board = Board.new()
	board.board_changed.connect(_refresh_dashboard)
	board.configure(INITIAL_WIDTH, INITIAL_HEIGHT, INITIAL_MINES, INITIAL_SEED)
	board_view.set_board(board)
	%SameFieldButton.pressed.connect(_on_same_field_pressed)
	%NewFieldButton.pressed.connect(_on_new_field_pressed)
	%LoadSeedButton.pressed.connect(_on_load_seed_pressed)
	%DiagnosticButton.pressed.connect(_on_diagnostic_pressed)
	seed_input.text_submitted.connect(_on_seed_submitted)
	_refresh_dashboard()


func _refresh_dashboard() -> void:
	if not is_instance_valid(board):
		return
	size_value.text = "%d × %d" % [board.width, board.height]
	mines_value.text = str(board.mine_count)
	remaining_value.text = str(board.get_estimated_remaining_mines())
	current_seed_value.text = str(board.seed)
	state_value.text = _status_text(board.status)
	revealed_value.text = "%d / %d" % [board.get_revealed_safe_count(), board.get_total_safe_count()]


func _status_text(game_status: int) -> String:
	match game_status:
		Types.GameStatus.READY:
			return "Aguardando primeira jogada"
		Types.GameStatus.PLAYING:
			return "Em andamento"
		Types.GameStatus.WON:
			return "Vitória"
		Types.GameStatus.LOST:
			return "Derrota"
	return "Desconhecido"


func _on_same_field_pressed() -> void:
	board.reset_same_seed()
	diagnostic_result.text = "Diagnósticos ainda não executados nesta sessão."
	diagnostic_result.remove_theme_color_override("font_color")


func _on_new_field_pressed() -> void:
	board.generate_new_seed()
	seed_input.clear()


func _on_seed_submitted(_submitted_text: String) -> void:
	_on_load_seed_pressed()


func _on_load_seed_pressed() -> void:
	var value := seed_input.text.strip_edges()
	if not value.is_valid_int():
		diagnostic_result.text = "Seed inválida: informe um número inteiro."
		diagnostic_result.add_theme_color_override("font_color", Color("fc8181"))
		return
	board.configure(board.width, board.height, board.mine_count, int(value))
	seed_input.clear()
	diagnostic_result.text = "Seed carregada. A primeira jogada definirá a área segura."
	diagnostic_result.add_theme_color_override("font_color", Color("63b3ed"))


func _on_diagnostic_pressed() -> void:
	diagnostic_result.text = "Executando diagnósticos…"
	var result: Dictionary = SelfTest.run_all()
	diagnostic_result.text = result.summary
	var result_color := Color("68d391") if result.failed == 0 else Color("fc8181")
	diagnostic_result.add_theme_color_override("font_color", result_color)
	print("[NeuroMine Lab] " + result.summary)
