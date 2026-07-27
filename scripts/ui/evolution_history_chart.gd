class_name EvolutionHistoryChart
extends Control

const VALIDATION_COLOR := Color("38bdf8")
const POPULATION_COLOR := Color("a3e635")
const GRID_COLOR := Color(0.35, 0.43, 0.55, 0.28)
const TEXT_COLOR := Color("94a3b8")

var validation_values: PackedFloat32Array = PackedFloat32Array()
var population_values: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 116)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_history(history: Array) -> void:
	validation_values.clear()
	population_values.clear()
	for result in history:
		validation_values.append(float(result.champion_validation.get("fitness_average", 0.0)))
		population_values.append(float(result.population_average_fitness))
	queue_redraw()


func _draw() -> void:
	var plot := Rect2(36.0, 17.0, maxf(1.0, size.x - 44.0), maxf(1.0, size.y - 35.0))
	draw_rect(plot, Color(0.04, 0.07, 0.11, 0.65), true)
	for step: int in range(3):
		var y: float = plot.position.y + plot.size.y * float(step) / 2.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID_COLOR, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, 11), "fitness", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(plot.position.x, size.y - 3), "Gerações", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(plot.end.x - 142, 11), "Validação", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, VALIDATION_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(plot.end.x - 76, 11), "Média", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, POPULATION_COLOR)
	if validation_values.is_empty():
		draw_string(ThemeDB.fallback_font, plot.get_center() + Vector2(-62, 4), "Aguardando 1ª geração", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_COLOR)
		return
	var minimum: float = minf(_minimum(validation_values), _minimum(population_values))
	var maximum: float = maxf(_maximum(validation_values), _maximum(population_values))
	if is_equal_approx(minimum, maximum):
		minimum -= 1.0
		maximum += 1.0
	_draw_series(validation_values, plot, minimum, maximum, VALIDATION_COLOR)
	_draw_series(population_values, plot, minimum, maximum, POPULATION_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(2, plot.position.y + 9), "%.0f" % maximum, HORIZONTAL_ALIGNMENT_LEFT, 32, 9, TEXT_COLOR)
	draw_string(ThemeDB.fallback_font, Vector2(2, plot.end.y), "%.0f" % minimum, HORIZONTAL_ALIGNMENT_LEFT, 32, 9, TEXT_COLOR)


func _draw_series(values: PackedFloat32Array, plot: Rect2, minimum: float, maximum: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in values.size():
		var ratio_x: float = float(index) / float(maxi(1, values.size() - 1))
		var ratio_y: float = (values[index] - minimum) / (maximum - minimum)
		points.append(Vector2(plot.position.x + ratio_x * plot.size.x, plot.end.y - ratio_y * plot.size.y))
	if points.size() == 1:
		draw_circle(points[0], 2.5, color)
	else:
		draw_polyline(points, color, 2.0, true)


func _minimum(values: PackedFloat32Array) -> float:
	var result: float = INF
	for value: float in values:
		result = minf(result, value)
	return result


func _maximum(values: PackedFloat32Array) -> float:
	var result: float = -INF
	for value: float in values:
		result = maxf(result, value)
	return result
