extends Control

const Board := preload("res://scripts/core/minesweeper_board.gd")
const Types := preload("res://scripts/core/minesweeper_types.gd")
const SelfTest := preload("res://scripts/debug/diagnostic_suite.gd")
const Statistics := preload("res://scripts/simulation/simulation_statistics.gd")
const Manager := preload("res://scripts/simulation/simulation_manager.gd")
const VisualControllerScript := preload("res://scripts/simulation/visual_match_controller.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")
const INITIAL_WIDTH: int = 6
const INITIAL_HEIGHT: int = 6
const INITIAL_MINES: int = 6
const INITIAL_SEED: int = 4700606
const INITIAL_AGENT_SEED: int = 91001
const HISTORY_DISPLAY_LIMIT: int = 12
const BATCH_CHUNK_SIZE: int = 50
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0]

@onready var board_view: BoardView = %BoardView
@onready var visual_controller: VisualControllerScript = %VisualMatchController
@onready var size_value: Label = %SizeValue
@onready var mines_value: Label = %MinesValue
@onready var remaining_value: Label = %RemainingValue
@onready var current_seed_value: LineEdit = %CurrentSeedValue
@onready var state_value: Label = %StateValue
@onready var revealed_value: Label = %RevealedValue
@onready var seed_input: LineEdit = %SeedInput
@onready var diagnostic_result: Label = %DiagnosticResult
@onready var agent_details: Label = %AgentDetails
@onready var speed_option: OptionButton = %SpeedOption
@onready var batch_result: Label = %BatchResult
@onready var statistics_value: Label = %StatisticsValue
@onready var history_value: Label = %HistoryValue

var board: MinesweeperBoard
var statistics: Statistics = Statistics.new()
var simulation_manager: Manager = Manager.new()
var current_agent_seed: int = INITIAL_AGENT_SEED
var current_coordinate: Vector2i = Vector2i(-1, -1)
var current_result_text: String = "—"
var action_history_lines: Array[String] = []
var _batch_running: bool = false


func _ready() -> void:
	board = Board.new()
	board.board_changed.connect(_refresh_dashboard)
	board.configure(INITIAL_WIDTH, INITIAL_HEIGHT, INITIAL_MINES, INITIAL_SEED)
	board_view.set_board(board)
	visual_controller.configure_match(board, current_agent_seed)
	_connect_interface()
	_setup_speed_options()
	_refresh_dashboard()
	_refresh_agent_panel()
	_refresh_statistics()


func _connect_interface() -> void:
	%SameFieldButton.pressed.connect(_on_same_field_pressed)
	%NewFieldButton.pressed.connect(_on_new_field_pressed)
	%LoadSeedButton.pressed.connect(_on_load_seed_pressed)
	%DiagnosticButton.pressed.connect(_on_diagnostic_pressed)
	seed_input.text_submitted.connect(_on_seed_submitted)
	%WatchAgentButton.pressed.connect(_on_watch_agent_pressed)
	%PauseAgentButton.pressed.connect(_on_pause_agent_pressed)
	%NextMoveButton.pressed.connect(_on_next_move_pressed)
	%StopAgentButton.pressed.connect(_on_stop_agent_pressed)
	%RestartMatchButton.pressed.connect(_on_restart_match_pressed)
	%NewMatchButton.pressed.connect(_on_new_match_pressed)
	%ResetStatsButton.pressed.connect(_on_reset_statistics_pressed)
	%Batch1Button.pressed.connect(_on_batch_requested.bind(1))
	%Batch10Button.pressed.connect(_on_batch_requested.bind(10))
	%Batch100Button.pressed.connect(_on_batch_requested.bind(100))
	%Batch1000Button.pressed.connect(_on_batch_requested.bind(1000))
	visual_controller.state_changed.connect(_on_visual_state_changed)
	visual_controller.decision_preview.connect(_on_decision_preview)
	visual_controller.action_completed.connect(_on_visual_action_completed)
	visual_controller.match_completed.connect(_on_visual_match_completed)


func _setup_speed_options() -> void:
	for speed: float in SPEEDS:
		speed_option.add_item(_format_speed(speed))
		speed_option.set_item_metadata(speed_option.item_count - 1, speed)
	speed_option.select(2)
	speed_option.item_selected.connect(_on_speed_selected)
	visual_controller.set_speed(SPEEDS[2])


func _refresh_dashboard() -> void:
	if not is_instance_valid(board):
		return
	size_value.text = "%d × %d" % [board.width, board.height]
	mines_value.text = str(board.mine_count)
	remaining_value.text = str(board.get_estimated_remaining_mines())
	current_seed_value.text = str(board.seed)
	state_value.text = _board_status_text(board.status)
	revealed_value.text = "%d / %d" % [board.get_revealed_safe_count(), board.get_total_safe_count()]
	_refresh_agent_panel()


func _refresh_agent_panel() -> void:
	if not is_instance_valid(board) or not is_instance_valid(visual_controller):
		return
	var coordinate_text := "—" if current_coordinate == Vector2i(-1, -1) else "(%d, %d)" % [current_coordinate.x, current_coordinate.y]
	var progress: float = 100.0 * float(board.get_revealed_safe_count()) / float(board.get_total_safe_count())
	var move_count: int = visual_controller.simulator.valid_action_count if is_instance_valid(visual_controller.simulator) else 0
	agent_details.text = (
		"Tipo: Aleatório\n"
		+ "Estado: %s\n" % _playback_state_text(visual_controller.playback_state)
		+ "Jogada atual: %d\n" % move_count
		+ "Coordenada: %s\n" % coordinate_text
		+ "Seed do agente: %d\n" % current_agent_seed
		+ "Resultado: %s\n" % current_result_text
		+ "Progresso: %.1f%%" % progress
	)


func _refresh_statistics() -> void:
	var fewest := "—" if statistics.fewest_moves_in_victory < 0 else str(statistics.fewest_moves_in_victory)
	statistics_value.text = (
		"Partidas: %d\n" % statistics.matches_played
		+ "Vitórias / derrotas: %d / %d\n" % [statistics.victories, statistics.defeats]
		+ "Taxa de vitória: %.1f%%\n" % statistics.get_win_rate()
		+ "Progresso médio / melhor: %.1f%% / %.1f%%\n" % [statistics.get_average_progress(), statistics.best_progress]
		+ "Média de jogadas: %.1f\n" % statistics.get_average_moves()
		+ "Menor vitória: %s\n" % fewest
		+ "Minas detonadas / interrompidas: %d / %d\n" % [statistics.detonated_mines, statistics.interrupted_matches]
		+ "Ações inválidas: %d\n" % statistics.invalid_actions
		+ "Último lote: %.0f partidas/s" % statistics.last_batch_matches_per_second
	)


func _board_status_text(game_status: int) -> String:
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


func _playback_state_text(playback_state: int) -> String:
	match playback_state:
		VisualControllerScript.PlaybackState.STOPPED:
			return "Parado"
		VisualControllerScript.PlaybackState.PLAYING:
			return "Jogando"
		VisualControllerScript.PlaybackState.PAUSED:
			return "Pausado"
		VisualControllerScript.PlaybackState.COMPLETED:
			return "Concluído"
	return "Desconhecido"


func _on_same_field_pressed() -> void:
	visual_controller.reset_same_match()
	_reset_visual_presentation()
	diagnostic_result.text = "Diagnósticos ainda não executados nesta sessão."
	diagnostic_result.remove_theme_color_override("font_color")


func _on_new_field_pressed() -> void:
	board.generate_new_seed()
	visual_controller.configure_match(board, current_agent_seed)
	seed_input.clear()
	_reset_visual_presentation()


func _on_seed_submitted(_submitted_text: String) -> void:
	_on_load_seed_pressed()


func _on_load_seed_pressed() -> void:
	var value := seed_input.text.strip_edges()
	if not value.is_valid_int():
		diagnostic_result.text = "Seed inválida: informe um número inteiro."
		diagnostic_result.add_theme_color_override("font_color", Color("fc8181"))
		return
	board.configure(board.width, board.height, board.mine_count, int(value))
	visual_controller.configure_match(board, current_agent_seed)
	seed_input.clear()
	_reset_visual_presentation()
	diagnostic_result.text = "Seed carregada. A primeira jogada definirá a área segura."
	diagnostic_result.add_theme_color_override("font_color", Color("63b3ed"))


func _on_watch_agent_pressed() -> void:
	if visual_controller.playback_state == VisualControllerScript.PlaybackState.PAUSED:
		visual_controller.start()
		return
	visual_controller.reset_same_match()
	_reset_visual_presentation()
	visual_controller.start()


func _on_pause_agent_pressed() -> void:
	visual_controller.toggle_pause()


func _on_next_move_pressed() -> void:
	if visual_controller.playback_state == VisualControllerScript.PlaybackState.STOPPED:
		visual_controller.reset_same_match()
		_reset_visual_presentation()
	elif visual_controller.playback_state == VisualControllerScript.PlaybackState.PLAYING:
		visual_controller.toggle_pause()
	visual_controller.step_once()


func _on_stop_agent_pressed() -> void:
	if visual_controller.playback_state in [VisualControllerScript.PlaybackState.PLAYING, VisualControllerScript.PlaybackState.PAUSED]:
		visual_controller.stop()


func _on_restart_match_pressed() -> void:
	visual_controller.reset_same_match()
	_reset_visual_presentation()


func _on_new_match_pressed() -> void:
	board.generate_new_seed()
	current_agent_seed = (current_agent_seed + 1) % 1000000000000
	visual_controller.configure_match(board, current_agent_seed)
	_reset_visual_presentation()


func _on_speed_selected(index: int) -> void:
	visual_controller.set_speed(float(speed_option.get_item_metadata(index)))


func _on_visual_state_changed(_playback_state: int) -> void:
	var agent_controls_board: bool = visual_controller.playback_state != VisualControllerScript.PlaybackState.STOPPED
	board_view.set_interaction_enabled(not agent_controls_board and not _batch_running)
	_refresh_agent_panel()


func _on_decision_preview(action: AgentAction) -> void:
	current_coordinate = action.position
	board_view.highlight_decision(action.position)
	_refresh_agent_panel()


func _on_visual_action_completed(event: Dictionary) -> void:
	board_view.clear_decision_highlight()
	var position: Vector2i = event.get("position", Vector2i(-1, -1))
	var line := "#%02d — Revelar (%d, %d) — %s" % [event.get("number", 0), position.x, position.y, event.get("outcome", "?")]
	action_history_lines.append(line)
	while action_history_lines.size() > HISTORY_DISPLAY_LIMIT:
		action_history_lines.pop_front()
	history_value.text = "\n".join(action_history_lines)
	_refresh_agent_panel()


func _on_visual_match_completed(result: ResultScript) -> void:
	board_view.clear_decision_highlight()
	statistics.record(result)
	current_result_text = "%s — %d jogadas" % [ResultScript.reason_to_string(result.end_reason), result.move_count]
	_refresh_statistics()
	_refresh_agent_panel()


func _on_batch_requested(match_count: int) -> void:
	if not _batch_running:
		_run_batch_async(match_count)


func _run_batch_async(match_count: int) -> void:
	if visual_controller.playback_state == VisualControllerScript.PlaybackState.PLAYING:
		visual_controller.toggle_pause()
	_batch_running = true
	_set_batch_buttons_enabled(false)
	board_view.set_interaction_enabled(false)
	batch_result.text = "Executando %s partidas…" % _format_integer(match_count)
	var started_usec: int = Time.get_ticks_usec()
	var completed: int = 0
	while completed < match_count:
		var chunk_count: int = mini(BATCH_CHUNK_SIZE, match_count - completed)
		simulation_manager.run_batch(
			chunk_count,
			board.width,
			board.height,
			board.mine_count,
			board.seed,
			current_agent_seed,
			statistics,
			completed
		)
		completed += chunk_count
		batch_result.text = "Executando lote: %s / %s" % [_format_integer(completed), _format_integer(match_count)]
		_refresh_statistics()
		await get_tree().process_frame
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	statistics.set_last_batch_performance(match_count, elapsed_seconds)
	batch_result.text = "%s partidas em %.3f s — %.0f partidas/s" % [
		_format_integer(match_count), elapsed_seconds, statistics.last_batch_matches_per_second
	]
	_refresh_statistics()
	_batch_running = false
	_set_batch_buttons_enabled(true)
	board_view.set_interaction_enabled(visual_controller.playback_state == VisualControllerScript.PlaybackState.STOPPED)


func _on_reset_statistics_pressed() -> void:
	statistics.reset()
	batch_result.text = "Estatísticas zeradas."
	_refresh_statistics()


func _set_batch_buttons_enabled(enabled: bool) -> void:
	for button: Button in [%Batch1Button, %Batch10Button, %Batch100Button, %Batch1000Button, %ResetStatsButton]:
		button.disabled = not enabled


func _reset_visual_presentation() -> void:
	current_coordinate = Vector2i(-1, -1)
	current_result_text = "—"
	action_history_lines.clear()
	history_value.text = "Aguardando ações do agente."
	board_view.clear_decision_highlight()
	_refresh_agent_panel()


func _on_diagnostic_pressed() -> void:
	diagnostic_result.text = "Executando diagnósticos…"
	var result: Dictionary = SelfTest.run_all()
	diagnostic_result.text = result.summary
	var result_color := Color("68d391") if result.failed == 0 else Color("fc8181")
	diagnostic_result.add_theme_color_override("font_color", result_color)
	print("[NeuroMine Lab] " + result.summary)


func _format_speed(speed: float) -> String:
	return ("%.2f" % speed).trim_suffix("0").trim_suffix("0").trim_suffix(".").replace(".", ",") + "×"


func _format_integer(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "." + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result
