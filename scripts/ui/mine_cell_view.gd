class_name MineCellView
extends Button

signal reveal_requested(cell_position: Vector2i)
signal flag_requested(cell_position: Vector2i)
signal inspector_hovered(cell_position: Vector2i)

const Types := preload("res://scripts/core/minesweeper_types.gd")
const COLOR_COVERED := Color("25344a")
const COLOR_COVERED_HOVER := Color("31445f")
const COLOR_REVEALED := Color("111a28")
const COLOR_BORDER := Color("40536d")
const COLOR_FLAG := Color("f2b84b")
const COLOR_MINE := Color("df5b65")
const NUMBER_COLORS: Array[Color] = [
	Color("a8b3c7"),
	Color("63b3ed"),
	Color("68d391"),
	Color("f6ad55"),
	Color("d6a5ff"),
	Color("fc8181"),
	Color("4fd1c5"),
	Color("f7fafc"),
	Color("a0aec0"),
]

var cell_position: Vector2i
var _decision_highlighted: bool = false
var _inspector_highlight: int = 0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 22)
	mouse_entered.connect(_on_mouse_entered)


func setup(position: Vector2i) -> void:
	cell_position = position
	tooltip_text = "Coluna %d, linha %d" % [position.x + 1, position.y + 1]


func display_state(state: Dictionary) -> void:
	var visibility: int = state.visibility
	match visibility:
		Types.CellVisibility.COVERED:
			text = ""
			_set_covered_style()
		Types.CellVisibility.FLAGGED:
			text = "◆"
			_set_covered_style(COLOR_FLAG)
		Types.CellVisibility.REVEALED:
			if state.has_mine:
				text = "●"
				_set_revealed_style(COLOR_MINE, state.detonated)
			else:
				var adjacent: int = state.adjacent_mines
				text = str(adjacent) if adjacent > 0 else ""
				_set_revealed_style(NUMBER_COLORS[adjacent], false)
	if _inspector_highlight > 0:
		_apply_inspector_highlight()
	if _decision_highlighted:
		_apply_decision_highlight()


func set_decision_highlight(enabled: bool) -> void:
	_decision_highlighted = enabled
	if enabled:
		_apply_decision_highlight()


func set_inspector_highlight(highlight_kind: int) -> void:
	_inspector_highlight = highlight_kind
	if highlight_kind > 0:
		_apply_inspector_highlight()


func _on_mouse_entered() -> void:
	inspector_hovered.emit(cell_position)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			reveal_requested.emit(cell_position)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			flag_requested.emit(cell_position)
			accept_event()


func _set_covered_style(font_color: Color = Color("dce6f5")) -> void:
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	add_theme_stylebox_override("normal", _make_style(COLOR_COVERED, COLOR_BORDER, 2))
	add_theme_stylebox_override("hover", _make_style(COLOR_COVERED_HOVER, Color("6383aa"), 2))
	add_theme_stylebox_override("pressed", _make_style(Color("1d293b"), Color("63b3ed"), 2))


func _set_revealed_style(font_color: Color, detonated: bool) -> void:
	var background := Color("542832") if detonated else COLOR_REVEALED
	var border := COLOR_MINE if detonated else Color("26364b")
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	var style := _make_style(background, border, 1)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)


func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _apply_decision_highlight() -> void:
	var style := _make_style(Color("24415a"), Color("63b3ed"), 3)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)


func _apply_inspector_highlight() -> void:
	var background := Color("244235") if _inspector_highlight == 1 else Color("242b40")
	var border := Color("68d391") if _inspector_highlight == 1 else Color("7f8fb3")
	var width: int = 3 if _inspector_highlight == 1 else 2
	var style := _make_style(background, border, width)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
