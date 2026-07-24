class_name NeuralHeatmapView
extends RefCounted

var enabled: bool = false
var show_values: bool = false
var show_ranking: bool = false
var frozen: bool = false
var _board_view: BoardView
var _scores: Array = []


func setup(board_view: BoardView) -> void:
	_board_view = board_view


func update_scores(scores: Array) -> void:
	if frozen:
		return
	_scores.assign(scores)
	_apply()


func set_enabled(value: bool) -> void:
	enabled = value
	_apply()


func set_show_values(value: bool) -> void:
	show_values = value
	_apply()


func set_show_ranking(value: bool) -> void:
	show_ranking = value
	_apply()


func set_frozen(value: bool) -> void:
	frozen = value


func clear(force: bool = false) -> void:
	if frozen and not force:
		return
	_scores.clear()
	if is_instance_valid(_board_view):
		_board_view.clear_neural_heatmap()


func get_scores() -> Array:
	return _scores.duplicate()


func _apply() -> void:
	if not is_instance_valid(_board_view):
		return
	if enabled and not _scores.is_empty():
		_board_view.apply_neural_heatmap(_scores, show_values, show_ranking)
	else:
		_board_view.clear_neural_heatmap()
