class_name NeuralNetwork
extends RefCounted

const Layer := preload("res://scripts/neural/neural_layer.gd")
const Config := preload("res://scripts/neural/neural_network_config.gd")
const Snapshot := preload("res://scripts/neural/neural_network_snapshot.gd")
const ObservationSchema := preload("res://scripts/observation/observation_schema.gd")

var config: Config
var network_seed: int = 0
var layers: Array[Layer] = []
var last_activations: Array[PackedFloat32Array] = []
var last_error: String = ""


func configure(network_config: Config, seed: int) -> bool:
	last_error = ""
	if not is_instance_valid(network_config) or not network_config.is_valid():
		last_error = "Invalid network configuration."
		return false
	config = network_config.duplicate_config()
	network_seed = seed
	layers.clear()
	last_activations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = network_seed
	for layer_index: int in range(config.architecture.size() - 1):
		var layer := Layer.new()
		layer.configure(
			config.architecture[layer_index],
			config.architecture[layer_index + 1],
			config.activations[layer_index],
			rng
		)
		layers.append(layer)
	return true


func forward(inputs: PackedFloat32Array, capture_activations: bool = false) -> PackedFloat32Array:
	last_error = ""
	last_activations.clear()
	if not is_instance_valid(config) or layers.is_empty():
		last_error = "Network is not configured."
		return PackedFloat32Array()
	if inputs.size() != config.architecture[0]:
		last_error = "Expected %d inputs, received %d." % [config.architecture[0], inputs.size()]
		return PackedFloat32Array()
	for value: float in inputs:
		if is_nan(value) or is_inf(value):
			last_error = "Input contains a non-finite value."
			return PackedFloat32Array()
	var current: PackedFloat32Array = inputs.duplicate()
	for layer: Layer in layers:
		current = layer.forward(current)
		for value: float in current:
			if is_nan(value) or is_inf(value):
				last_error = "Activation contains a non-finite value."
				return PackedFloat32Array()
		if capture_activations:
			last_activations.append(current.duplicate())
	return current


func get_parameter_count() -> int:
	var total: int = 0
	for layer: Layer in layers:
		total += layer.get_parameter_count()
	return total


func get_flat_parameters() -> PackedFloat32Array:
	var parameters := PackedFloat32Array()
	parameters.resize(get_parameter_count())
	var offset: int = 0
	for layer: Layer in layers:
		var layer_parameters: PackedFloat32Array = layer.get_flat_parameters()
		for value: float in layer_parameters:
			parameters[offset] = value
			offset += 1
	return parameters


func set_flat_parameters(parameters: PackedFloat32Array) -> bool:
	last_error = ""
	if parameters.size() != get_parameter_count():
		last_error = "Expected %d parameters, received %d." % [get_parameter_count(), parameters.size()]
		return false
	for value: float in parameters:
		if is_nan(value) or is_inf(value):
			last_error = "Parameters contain a non-finite value."
			return false
	var offset: int = 0
	for layer: Layer in layers:
		offset = layer.set_parameters_from(parameters, offset)
		if offset < 0:
			last_error = "Could not import layer parameters."
			return false
	return true


func clone_network():
	var clone = get_script().new()
	clone.config = config.duplicate_config()
	clone.network_seed = network_seed
	for layer: Layer in layers:
		clone.layers.append(layer.duplicate_layer())
	return clone


func create_snapshot(metadata: Dictionary = {}) -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.observation_schema_version = ObservationSchema.VERSION
	snapshot.architecture.assign(config.architecture)
	snapshot.activations.assign(config.activations)
	snapshot.original_seed = network_seed
	snapshot.parameters = get_flat_parameters()
	snapshot.parameter_count = snapshot.parameters.size()
	snapshot.metadata = metadata.duplicate(true)
	return snapshot


func restore_snapshot(snapshot: Snapshot) -> bool:
	last_error = ""
	if not is_instance_valid(snapshot):
		last_error = "Snapshot is missing."
		return false
	if snapshot.format_version != Snapshot.FORMAT_VERSION:
		last_error = "Unsupported snapshot format."
		return false
	if snapshot.observation_schema_version != ObservationSchema.VERSION:
		last_error = "Observation schema mismatch."
		return false
	if snapshot.parameter_count != snapshot.parameters.size():
		last_error = "Snapshot parameter count mismatch."
		return false
	var restored_config := Config.new(snapshot.architecture, snapshot.activations)
	if not configure(restored_config, snapshot.original_seed):
		return false
	return set_flat_parameters(snapshot.parameters)


func get_activation_statistics() -> Array[Dictionary]:
	var statistics: Array[Dictionary] = []
	for layer_index: int in range(last_activations.size()):
		var values: PackedFloat32Array = last_activations[layer_index]
		if values.is_empty():
			continue
		var minimum: float = values[0]
		var maximum: float = values[0]
		var sum: float = 0.0
		var positive: int = 0
		var negative: int = 0
		for value: float in values:
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			sum += value
			positive += 1 if value > 0.0 else 0
			negative += 1 if value < 0.0 else 0
		statistics.append({
			"layer_index": layer_index,
			"neuron_count": values.size(),
			"minimum": minimum,
			"maximum": maximum,
			"mean": sum / float(values.size()),
			"positive_count": positive,
			"negative_count": negative,
			"values": values.duplicate(),
		})
	return statistics
