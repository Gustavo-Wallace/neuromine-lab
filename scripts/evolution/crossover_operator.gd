class_name CrossoverOperator
extends RefCounted


static func uniform(
	first: PackedFloat32Array, second: PackedFloat32Array,
	probability: float, rng: RandomNumberGenerator
) -> Dictionary:
	if first.size() != second.size() or first.is_empty():
		return {"success": false, "error": "Incompatible genomes."}
	var child := PackedFloat32Array()
	child.resize(first.size())
	var inherited_a: int = 0
	var inherited_b: int = 0
	var applied: bool = rng.randf() < probability
	if not applied:
		var selected_first: bool = rng.randf() < 0.5
		var source: PackedFloat32Array = first if selected_first else second
		child = source.duplicate()
		inherited_a = child.size() if selected_first else 0
		inherited_b = 0 if selected_first else child.size()
	else:
		for index: int in range(first.size()):
			if rng.randf() < 0.5:
				child[index] = first[index]
				inherited_a += 1
			else:
				child[index] = second[index]
				inherited_b += 1
	return {
		"success": true, "genome": child, "applied": applied,
		"inherited_a": inherited_a, "inherited_b": inherited_b,
	}
