class_name NeuralActivation
extends RefCounted

enum Type {
	TANH,
	SIGMOID,
	LINEAR,
	RELU,
}


static func apply(value: float, activation_type: int) -> float:
	match activation_type:
		Type.TANH:
			return tanh(value)
		Type.SIGMOID:
			return 1.0 / (1.0 + exp(-clampf(value, -60.0, 60.0)))
		Type.LINEAR:
			return value
		Type.RELU:
			return maxf(0.0, value)
	return value


static func name_for(activation_type: int) -> String:
	match activation_type:
		Type.TANH:
			return "TANH"
		Type.SIGMOID:
			return "SIGMOID"
		Type.LINEAR:
			return "LINEAR"
		Type.RELU:
			return "RELU"
	return "UNKNOWN"
