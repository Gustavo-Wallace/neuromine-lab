class_name EvolutionaryPopulation
extends RefCounted

const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")

var generation: int = 0
var individuals: Array[Individual] = []


func sort_by_fitness() -> void:
	individuals.sort_custom(func(a: Individual, b: Individual) -> bool:
		if a.fitness_average == b.fitness_average:
			if a.victories == b.victories:
				return a.identifier < b.identifier
			return a.victories > b.victories
		return a.fitness_average > b.fitness_average
	)
	for index: int in range(individuals.size()):
		individuals[index].rank = index + 1


func get_champion() -> Individual:
	return individuals[0] if not individuals.is_empty() else null


func get_diversity_metrics(sample_pairs: int = 96) -> Dictionary:
	if individuals.is_empty():
		return {}
	var genomes: Array[PackedFloat32Array] = []
	for individual: Individual in individuals:
		genomes.append(individual.get_genome())
	var parameter_count: int = genomes[0].size()
	var mean_stddev: float = 0.0
	var population_mean := PackedFloat32Array()
	population_mean.resize(parameter_count)
	for parameter_index: int in range(parameter_count):
		var mean: float = 0.0
		for genome: PackedFloat32Array in genomes:
			mean += genome[parameter_index]
		mean /= float(genomes.size())
		population_mean[parameter_index] = mean
		var variance: float = 0.0
		for genome: PackedFloat32Array in genomes:
			var delta: float = genome[parameter_index] - mean
			variance += delta * delta
		mean_stddev += sqrt(variance / float(genomes.size()))
	mean_stddev /= float(parameter_count)
	var pair_count: int = 0
	var pair_distance_sum: float = 0.0
	var identical_count: int = 0
	var identical_genome_count: int = 0
	for genome_index: int in range(genomes.size()):
		for previous_index: int in range(genome_index):
			if genomes[genome_index] == genomes[previous_index]:
				identical_genome_count += 1
				break
	for first_index: int in range(genomes.size()):
		for second_index: int in range(first_index + 1, genomes.size()):
			if pair_count >= sample_pairs:
				break
			var distance: float = _mean_absolute_distance(genomes[first_index], genomes[second_index])
			pair_distance_sum += distance
			identical_count += 1 if distance <= 0.0000001 else 0
			pair_count += 1
		if pair_count >= sample_pairs:
			break
	var champion_distance: float = _mean_absolute_distance(individuals[0].get_genome(), population_mean)
	return {
		"mean_parameter_stddev": mean_stddev,
		"approximate_mean_genome_distance": pair_distance_sum / float(maxi(1, pair_count)),
		"identical_genome_pairs": identical_count,
		"identical_genome_count": identical_genome_count,
		"sampled_pairs": pair_count,
		"champion_to_population_mean_distance": champion_distance,
	}


static func _mean_absolute_distance(first: PackedFloat32Array, second: PackedFloat32Array) -> float:
	if first.size() != second.size() or first.is_empty():
		return INF
	var total: float = 0.0
	for index: int in range(first.size()):
		total += absf(first[index] - second[index])
	return total / float(first.size())
