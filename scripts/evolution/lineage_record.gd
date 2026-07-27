class_name LineageRecord
extends RefCounted

var parent_a_identifier: String = ""
var parent_b_identifier: String = ""
var inherited_from_a: int = 0
var inherited_from_b: int = 0
var crossover_applied: bool = false
var mutation_count: int = 0
var mutation_max_delta: float = 0.0
var mutation_mean_absolute_delta: float = 0.0
var mutation_strength: float = 0.0
var origin: String = "initial"
var origin_phase: int = 1
var ancestor_identifier: String = ""
var transfer_kind: String = ""
var transfer_preserved: bool = false


func duplicate_record():
	var copy = get_script().new()
	for property_name: String in [
		"parent_a_identifier", "parent_b_identifier", "inherited_from_a", "inherited_from_b",
		"crossover_applied", "mutation_count", "mutation_max_delta",
		"mutation_mean_absolute_delta", "mutation_strength", "origin", "origin_phase",
		"ancestor_identifier", "transfer_kind", "transfer_preserved"
	]:
		copy.set(property_name, get(property_name))
	return copy


func to_dictionary() -> Dictionary:
	return {
		"parent_a": parent_a_identifier, "parent_b": parent_b_identifier,
		"inherited_a": inherited_from_a, "inherited_b": inherited_from_b,
		"crossover": crossover_applied, "mutation_count": mutation_count,
		"mutation_max_delta": mutation_max_delta,
		"mutation_mean_absolute_delta": mutation_mean_absolute_delta,
		"mutation_strength": mutation_strength, "origin": origin,
		"origin_phase": origin_phase, "ancestor_identifier": ancestor_identifier,
		"transfer_kind": transfer_kind, "transfer_preserved": transfer_preserved,
	}
