class_name NeuralLayer
extends RefCounted

const Activation := preload("res://scripts/neural/neural_activation.gd")

var input_count: int = 0
var output_count: int = 0
var activation_type: int = Activation.Type.LINEAR
var weights: PackedFloat32Array = PackedFloat32Array()
var biases: PackedFloat32Array = PackedFloat32Array()


func configure(layer_inputs: int, layer_outputs: int, layer_activation: int, rng: RandomNumberGenerator) -> void:
	input_count = layer_inputs
	output_count = layer_outputs
	activation_type = layer_activation
	weights.resize(input_count * output_count)
	biases.resize(output_count)
	var xavier_limit: float = sqrt(6.0 / float(input_count + output_count))
	for index: int in range(weights.size()):
		weights[index] = rng.randf_range(-xavier_limit, xavier_limit)
	for index: int in range(biases.size()):
		biases[index] = 0.0


func forward(inputs: PackedFloat32Array) -> PackedFloat32Array:
	var outputs := PackedFloat32Array()
	if inputs.size() != input_count:
		return outputs
	outputs.resize(output_count)
	for output_index: int in range(output_count):
		var sum: float = biases[output_index]
		var weight_offset: int = output_index * input_count
		for input_index: int in range(input_count):
			sum += weights[weight_offset + input_index] * inputs[input_index]
		outputs[output_index] = Activation.apply(sum, activation_type)
	return outputs


func get_parameter_count() -> int:
	return weights.size() + biases.size()


func get_flat_parameters() -> PackedFloat32Array:
	var parameters := PackedFloat32Array()
	parameters.resize(get_parameter_count())
	for index: int in range(weights.size()):
		parameters[index] = weights[index]
	for index: int in range(biases.size()):
		parameters[weights.size() + index] = biases[index]
	return parameters


func set_flat_parameters(parameters: PackedFloat32Array) -> bool:
	if parameters.size() != get_parameter_count():
		return false
	return set_parameters_from(parameters, 0) == parameters.size()


func set_parameters_from(parameters: PackedFloat32Array, offset: int) -> int:
	if offset < 0 or offset + get_parameter_count() > parameters.size():
		return -1
	for index: int in range(weights.size()):
		weights[index] = parameters[offset + index]
	var bias_offset: int = offset + weights.size()
	for index: int in range(biases.size()):
		biases[index] = parameters[bias_offset + index]
	return offset + get_parameter_count()


func duplicate_layer():
	var copy = get_script().new()
	copy.input_count = input_count
	copy.output_count = output_count
	copy.activation_type = activation_type
	copy.weights = weights.duplicate()
	copy.biases = biases.duplicate()
	return copy
