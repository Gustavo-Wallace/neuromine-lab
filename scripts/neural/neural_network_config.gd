class_name NeuralNetworkConfig
extends RefCounted

const Activation := preload("res://scripts/neural/neural_activation.gd")
const ObservationSchema := preload("res://scripts/observation/observation_schema.gd")

var architecture: Array[int] = []
var activations: Array[int] = []


func _init(layer_sizes: Array[int] = [], layer_activations: Array[int] = []) -> void:
	architecture.assign(layer_sizes)
	activations.assign(layer_activations)


static func create_default():
	return new(
		[ObservationSchema.TOTAL_INPUT_COUNT, 24, 12, 1],
		[Activation.Type.TANH, Activation.Type.TANH, Activation.Type.SIGMOID]
	)


func is_valid() -> bool:
	if architecture.size() < 2 or activations.size() != architecture.size() - 1:
		return false
	for size: int in architecture:
		if size <= 0:
			return false
	return true


func duplicate_config():
	return get_script().new(architecture, activations)


func get_architecture_text() -> String:
	var parts: Array[String] = []
	for size: int in architecture:
		parts.append(str(size))
	return " → ".join(parts)
