class_name StagnationTracker
extends RefCounted

var limit: int = 15
var epsilon: float = 0.000001
var generations_without_improvement: int = 0
var best_value: float = -INF


func configure(stagnation_limit: int, improvement_epsilon: float) -> void:
	limit = stagnation_limit
	epsilon = improvement_epsilon
	reset()


func reset() -> void:
	generations_without_improvement = 0
	best_value = -INF


func record(value: float) -> bool:
	if best_value == -INF or value > best_value + epsilon:
		best_value = value
		generations_without_improvement = 0
		return true
	generations_without_improvement += 1
	return false


func is_stagnated() -> bool:
	return generations_without_improvement >= limit
