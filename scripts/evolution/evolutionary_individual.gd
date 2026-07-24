class_name EvolutionaryIndividual
extends RefCounted

const Network := preload("res://scripts/neural/neural_network.gd")
const Lineage := preload("res://scripts/evolution/lineage_record.gd")

var identifier: String = ""
var birth_generation: int = 0
var creation_seed: int = 0
var network: Network
var fitness_total: float = 0.0
var fitness_average: float = 0.0
var victories: int = 0
var win_rate: float = 0.0
var average_progress: float = 0.0
var best_progress: float = 0.0
var average_moves: float = 0.0
var evaluated_matches: int = 0
var rank: int = 0
var lineage: Lineage = Lineage.new()
var training_summary: Dictionary = {}
var validation_summary: Dictionary = {}


func get_genome() -> PackedFloat32Array:
	return network.get_flat_parameters() if is_instance_valid(network) else PackedFloat32Array()


func set_genome(parameters: PackedFloat32Array) -> bool:
	return is_instance_valid(network) and network.set_flat_parameters(parameters)


func update_training_summary(summary: Dictionary) -> void:
	training_summary = summary.duplicate(true)
	fitness_total = float(summary.get("fitness_total", 0.0))
	fitness_average = float(summary.get("fitness_average", 0.0))
	victories = int(summary.get("victories", 0))
	win_rate = float(summary.get("win_rate", 0.0))
	average_progress = float(summary.get("average_progress", 0.0))
	best_progress = float(summary.get("best_progress", 0.0))
	average_moves = float(summary.get("average_moves", 0.0))
	evaluated_matches = int(summary.get("evaluated_matches", 0))


func duplicate_individual(new_identifier: String = ""):
	var copy = get_script().new()
	copy.identifier = identifier if new_identifier.is_empty() else new_identifier
	copy.birth_generation = birth_generation
	copy.creation_seed = creation_seed
	copy.network = network.clone_network()
	copy.fitness_total = fitness_total
	copy.fitness_average = fitness_average
	copy.victories = victories
	copy.win_rate = win_rate
	copy.average_progress = average_progress
	copy.best_progress = best_progress
	copy.average_moves = average_moves
	copy.evaluated_matches = evaluated_matches
	copy.rank = rank
	copy.lineage = lineage.duplicate_record()
	copy.training_summary = training_summary.duplicate(true)
	copy.validation_summary = validation_summary.duplicate(true)
	return copy


func create_snapshot() -> Dictionary:
	return {
		"identifier": identifier, "birth_generation": birth_generation, "creation_seed": creation_seed,
		"network": network.create_snapshot({"individual": identifier}),
		"lineage": lineage.to_dictionary(), "training": training_summary.duplicate(true),
		"validation": validation_summary.duplicate(true),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if not snapshot.has("network"):
		return false
	var restored := Network.new()
	if not restored.restore_snapshot(snapshot.network):
		return false
	identifier = str(snapshot.get("identifier", identifier))
	birth_generation = int(snapshot.get("birth_generation", birth_generation))
	creation_seed = int(snapshot.get("creation_seed", creation_seed))
	network = restored
	training_summary = snapshot.get("training", {}).duplicate(true)
	validation_summary = snapshot.get("validation", {}).duplicate(true)
	if not training_summary.is_empty():
		update_training_summary(training_summary)
	return true


func is_better_than(other) -> bool:
	return not is_instance_valid(other) or fitness_average > other.fitness_average
