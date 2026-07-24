class_name CandidateObservation
extends RefCounted

var candidate_position: Vector2i
var schema_version: int
var feature_count: int

var _values: PackedFloat32Array
var _feature_names: PackedStringArray
var _debug_metadata: Dictionary
var _debug_visible_state: Dictionary


func _init(
	position: Vector2i,
	values: PackedFloat32Array,
	feature_names: PackedStringArray,
	version: int,
	metadata: Dictionary = {},
	debug_visible_state: Dictionary = {}
) -> void:
	candidate_position = position
	schema_version = version
	feature_count = values.size()
	_values = values.duplicate()
	_feature_names = feature_names.duplicate()
	_debug_metadata = metadata.duplicate(true)
	_debug_visible_state = debug_visible_state.duplicate(true)


func get_vector() -> PackedFloat32Array:
	return _values.duplicate()


func get_feature_names() -> PackedStringArray:
	return _feature_names.duplicate()


func get_debug_metadata() -> Dictionary:
	return _debug_metadata.duplicate(true)


func get_debug_visible_state() -> Dictionary:
	return _debug_visible_state.duplicate(true)


func get_value(index: int) -> float:
	return _values[index] if index >= 0 and index < _values.size() else 0.0
