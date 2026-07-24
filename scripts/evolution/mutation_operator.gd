class_name MutationOperator
extends RefCounted


static func gaussian(
	genome: PackedFloat32Array, probability: float, strength: float,
	absolute_limit: float, rng: RandomNumberGenerator
) -> Dictionary:
	var mutated: PackedFloat32Array = genome.duplicate()
	var mutation_count: int = 0
	var maximum_delta: float = 0.0
	var total_absolute_delta: float = 0.0
	for index: int in range(mutated.size()):
		if rng.randf() >= probability:
			continue
		var delta: float = _standard_normal(rng) * strength
		var previous: float = mutated[index]
		mutated[index] = clampf(previous + delta, -absolute_limit, absolute_limit)
		var applied_delta: float = mutated[index] - previous
		mutation_count += 1
		maximum_delta = maxf(maximum_delta, absf(applied_delta))
		total_absolute_delta += absf(applied_delta)
	return {
		"genome": mutated, "mutation_count": mutation_count,
		"max_delta": maximum_delta,
		"mean_absolute_delta": total_absolute_delta / float(maxi(1, mutation_count)),
		"strength": strength,
	}


static func _standard_normal(rng: RandomNumberGenerator) -> float:
	var first: float = maxf(rng.randf(), 0.0000001)
	var second: float = rng.randf()
	return sqrt(-2.0 * log(first)) * cos(TAU * second)
