class_name ObservationInspector
extends VBoxContainer

signal active_changed(enabled: bool)
signal observation_selected(candidate_position: Vector2i)

const Provider := preload("res://scripts/observation/candidate_provider.gd")
const Encoder := preload("res://scripts/observation/observation_encoder.gd")
const Schema := preload("res://scripts/observation/observation_schema.gd")
const CandidateData := preload("res://scripts/observation/candidate_observation.gd")

@onready var inspector_toggle: CheckButton = $InspectorToggle
@onready var previous_button: Button = $Navigation/PreviousCandidateButton
@onready var next_button: Button = $Navigation/NextCandidateButton
@onready var copy_button: Button = $Tools/CopyVectorButton
@onready var show_indices: CheckButton = $Tools/ShowIndicesButton
@onready var output_label: Label = $InspectorScroll/InspectorOutput

var _board: MinesweeperBoard
var _encoder: Encoder = Encoder.new()
var _candidates: Array[Vector2i] = []
var _selected_index: int = -1
var _current_observation: CandidateData
var _action_count: int = -1
var _max_action_count: int = 1


func _ready() -> void:
	inspector_toggle.toggled.connect(_on_toggle_changed)
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	show_indices.toggled.connect(_on_show_indices_changed)
	_set_controls_enabled(false)


func setup(board: MinesweeperBoard) -> void:
	if is_instance_valid(_board) and _board.board_changed.is_connected(_on_board_changed):
		_board.board_changed.disconnect(_on_board_changed)
	_board = board
	_board.board_changed.connect(_on_board_changed)
	_max_action_count = maxi(1, board.width * board.height * 4)
	_refresh_candidates(false)


func is_active() -> bool:
	return inspector_toggle.button_pressed


func set_active(enabled: bool) -> void:
	inspector_toggle.button_pressed = enabled


func set_runtime_context(action_count: int, max_action_count: int) -> void:
	_action_count = action_count
	_max_action_count = maxi(1, max_action_count)


func use_board_action_count() -> void:
	_action_count = -1
	if is_active():
		_refresh_candidates(true)


func select_candidate(candidate_position: Vector2i) -> bool:
	if not is_active() or not is_instance_valid(_board):
		return false
	_refresh_candidates(false)
	var candidate_index: int = _candidates.find(candidate_position)
	if candidate_index < 0:
		return false
	_selected_index = candidate_index
	_encode_selected()
	return true


func get_current_observation() -> CandidateData:
	return _current_observation


func _on_toggle_changed(enabled: bool) -> void:
	_set_controls_enabled(enabled)
	active_changed.emit(enabled)
	if enabled:
		_refresh_candidates(false)
		if not _candidates.is_empty():
			_selected_index = clampi(_selected_index, 0, _candidates.size() - 1)
			_encode_selected()
	else:
		_current_observation = null
		output_label.text = "Inspetor desativado."


func _on_previous_pressed() -> void:
	if _candidates.is_empty():
		return
	_selected_index = wrapi(_selected_index - 1, 0, _candidates.size())
	_encode_selected()


func _on_next_pressed() -> void:
	if _candidates.is_empty():
		return
	_selected_index = wrapi(_selected_index + 1, 0, _candidates.size())
	_encode_selected()


func _on_copy_pressed() -> void:
	if not is_instance_valid(_current_observation):
		return
	var export_text: String = _build_export_text(_current_observation)
	DisplayServer.clipboard_set(export_text)
	print("[NeuroMine Lab / Observação]\n" + export_text)


func _on_show_indices_changed(_enabled: bool) -> void:
	_render_current()


func _on_board_changed() -> void:
	if not is_active():
		return
	var previous_position := (
		_current_observation.candidate_position
		if is_instance_valid(_current_observation) else Vector2i(-1, -1)
	)
	_refresh_candidates(false)
	var refreshed_index: int = _candidates.find(previous_position)
	if refreshed_index >= 0:
		_selected_index = refreshed_index
		_encode_selected()


func _refresh_candidates(reencode: bool) -> void:
	if not is_instance_valid(_board):
		return
	var observation: Dictionary = _board.get_agent_observation(_action_count, _max_action_count)
	_candidates = Provider.get_candidates(observation)
	if _candidates.is_empty():
		_selected_index = -1
		if not is_instance_valid(_current_observation):
			output_label.text = "Nenhuma candidata disponível."
		return
	_selected_index = clampi(_selected_index, 0, _candidates.size() - 1)
	if reencode:
		_encode_selected()


func _encode_selected() -> void:
	if _selected_index < 0 or _selected_index >= _candidates.size():
		return
	var visible_state: Dictionary = _board.get_agent_observation(_action_count, _max_action_count)
	_current_observation = _encoder.encode_candidate(visible_state, _candidates[_selected_index], true)
	_render_current()
	observation_selected.emit(_current_observation.candidate_position)


func _render_current() -> void:
	if not is_instance_valid(_current_observation):
		return
	var values: PackedFloat32Array = _current_observation.get_vector()
	var names: PackedStringArray = _current_observation.get_feature_names()
	var metadata: Dictionary = _current_observation.get_debug_metadata()
	var position: Vector2i = _current_observation.candidate_position
	var lines: Array[String] = [
		"Candidata: (%d, %d)" % [position.x, position.y],
		"Esquema: v%d" % _current_observation.schema_version,
		"Entradas: %d" % _current_observation.feature_count,
		"Ordem: NW, N, NE, W, E, SW, S, SE",
		"",
		"GLOBAIS",
	]
	for global_feature: int in range(Schema.GLOBAL_FEATURE_COUNT):
		var index: int = Schema.global_index(global_feature)
		lines.append(_format_feature_line(index, names[index], values[index]))
	for direction_index: int in range(Schema.DIRECTION_COUNT):
		var state: Dictionary = metadata.direction_states[direction_index]
		lines.append("")
		lines.append("%s — %s  %s" % [
			Schema.DIRECTION_NAMES[direction_index].to_upper(),
			str(state.position),
			str(state.state).replace("_", " ")
		])
		for local_feature: int in range(Schema.LOCAL_FEATURE_COUNT):
			var index: int = Schema.local_index(direction_index, local_feature)
			lines.append(_format_feature_line(index, names[index], values[index]))
	if not metadata.overflagged_clues.is_empty():
		lines.append("")
		lines.append("AVISO: há pista(s) com bandeiras em excesso.")
	output_label.text = "\n".join(lines)


func _format_feature_line(index: int, feature_name: String, value: float) -> String:
	var prefix := "[%02d] " % index if show_indices.button_pressed else ""
	return "%s%s: %s" % [prefix, feature_name, _format_decimal(value)]


func _build_export_text(observation: CandidateData) -> String:
	var position: Vector2i = observation.candidate_position
	var values: PackedFloat32Array = observation.get_vector()
	var names: PackedStringArray = observation.get_feature_names()
	var value_parts: Array[String] = []
	var named_parts: Array[String] = []
	for index: int in range(values.size()):
		value_parts.append("%.6f" % values[index])
		named_parts.append("[%02d] %s=%.6f" % [index, names[index], values[index]])
	return (
		"candidate=(%d,%d)\n" % [position.x, position.y]
		+ "schema_version=%d\n" % observation.schema_version
		+ "input_count=%d\n" % observation.feature_count
		+ "features=\n%s\n" % "\n".join(named_parts)
		+ "values=[%s]" % ", ".join(value_parts)
	)


func _format_decimal(value: float) -> String:
	return ("%.3f" % value).replace(".", ",")


func _set_controls_enabled(enabled: bool) -> void:
	previous_button.disabled = not enabled
	next_button.disabled = not enabled
	copy_button.disabled = not enabled
	show_indices.disabled = not enabled
