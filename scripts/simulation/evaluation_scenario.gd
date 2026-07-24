class_name EvaluationScenario
extends RefCounted

const GENERATOR_VERSION: int = 1

var width: int = 6
var height: int = 6
var mine_count: int = 6
var field_seed: int = 0
var first_reveal: Vector2i = Vector2i(3, 3)
var safe_radius: int = 1
var generator_version: int = GENERATOR_VERSION


func _init(
	board_width: int = 6,
	board_height: int = 6,
	mines: int = 6,
	seed: int = 0,
	start: Vector2i = Vector2i(3, 3),
	radius: int = 1,
	version: int = GENERATOR_VERSION
) -> void:
	width = board_width
	height = board_height
	mine_count = mines
	field_seed = seed
	first_reveal = start
	safe_radius = radius
	generator_version = version


func is_valid() -> bool:
	return (
		width > 0 and height > 0 and mine_count >= 0 and mine_count < width * height
		and first_reveal.x >= 0 and first_reveal.x < width
		and first_reveal.y >= 0 and first_reveal.y < height
		and safe_radius == 1 and generator_version == GENERATOR_VERSION
	)


func get_identifier() -> String:
	return "%dx%d:%d|seed=%d|start=%d,%d|safe_radius=%d|generator=%d" % [
		width, height, mine_count, field_seed, first_reveal.x, first_reveal.y,
		safe_radius, generator_version,
	]


func duplicate_scenario():
	return get_script().new(width, height, mine_count, field_seed, first_reveal, safe_radius, generator_version)


func to_dictionary() -> Dictionary:
	return {
		"identifier": get_identifier(), "width": width, "height": height,
		"mine_count": mine_count, "field_seed": field_seed, "first_reveal": first_reveal,
		"safe_radius": safe_radius, "generator_version": generator_version,
	}
