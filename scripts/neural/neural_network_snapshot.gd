class_name NeuralNetworkSnapshot
extends RefCounted

const FORMAT_VERSION: int = 1

var format_version: int = FORMAT_VERSION
var observation_schema_version: int = 0
var architecture: Array[int] = []
var activations: Array[int] = []
var original_seed: int = 0
var parameters: PackedFloat32Array = PackedFloat32Array()
var parameter_count: int = 0
var metadata: Dictionary = {}


func duplicate_snapshot():
	var copy = get_script().new()
	copy.format_version = format_version
	copy.observation_schema_version = observation_schema_version
	copy.architecture.assign(architecture)
	copy.activations.assign(activations)
	copy.original_seed = original_seed
	copy.parameters = parameters.duplicate()
	copy.parameter_count = parameter_count
	copy.metadata = metadata.duplicate(true)
	return copy
