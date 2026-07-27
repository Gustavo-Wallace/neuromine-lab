class_name GeneticAlgorithm
extends RefCounted

const Config := preload("res://scripts/evolution/evolutionary_config.gd")
const Population := preload("res://scripts/evolution/evolutionary_population.gd")
const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")
const Lineage := preload("res://scripts/evolution/lineage_record.gd")
const Network := preload("res://scripts/neural/neural_network.gd")
const Selection := preload("res://scripts/evolution/selection_operator.gd")
const Crossover := preload("res://scripts/evolution/crossover_operator.gd")
const Mutation := preload("res://scripts/evolution/mutation_operator.gd")

var config: Config
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_error: String = ""
var phase_index: int = 1
var phase_generation: int = 1
var global_generation: int = 1
var last_breeding_metrics: Dictionary = {}


func configure(evolution_config: Config) -> bool:
	if not is_instance_valid(evolution_config) or not evolution_config.is_valid():
		last_error = "Invalid evolutionary configuration."
		return false
	config = evolution_config.duplicate_config()
	rng.seed = config.master_seed
	last_error = ""
	return true


func set_generation_context(phase: int, phase_gen: int, global_gen: int) -> void:
	phase_index = phase
	phase_generation = phase_gen
	global_generation = global_gen


func create_initial_population() -> Population:
	var population := Population.new()
	population.generation = global_generation
	for index: int in range(config.population_size):
		var individual: Individual = _create_random_individual(index + 1, "initial")
		population.individuals.append(individual)
	last_breeding_metrics = {"immigrants": config.population_size, "clone_rejections": 0, "additional_mutations": 0, "immigrant_replacements": 0}
	return population


func breed_next_generation(current: Population) -> Population:
	current.sort_by_fitness()
	var before_diversity: Dictionary = current.get_diversity_metrics()
	global_generation = current.generation + 1
	phase_generation += 1
	var next := Population.new()
	next.generation = global_generation
	var clone_rejections: int = 0
	var additional_mutations: int = 0
	var immigrant_replacements: int = 0
	var immigrant_count: int = roundi(config.population_size * config.immigrant_fraction) if config.curriculum_enabled else 0
	var parent_counts: Dictionary = {}
	var upper_quartile_parent_count: int = 0
	for elite_index: int in range(config.elite_count):
		var parent: Individual = current.individuals[elite_index]
		var elite: Individual = parent.duplicate_individual(_identifier(next.individuals.size() + 1))
		_stamp(elite)
		elite.lineage = Lineage.new()
		elite.lineage.origin = "elite"
		elite.lineage.origin_phase = phase_index
		elite.lineage.parent_a_identifier = parent.identifier
		elite.lineage.ancestor_identifier = parent.identifier
		elite.lineage.inherited_from_a = elite.get_genome().size()
		_clear_evaluation(elite)
		next.individuals.append(elite)
	var offspring_target: int = config.population_size - immigrant_count
	while next.individuals.size() < offspring_target:
		var parent_a: Individual = Selection.tournament(current.individuals, config.tournament_size, rng)
		var parent_b: Individual = null
		var source_genome: PackedFloat32Array
		var crossover: Dictionary
		if config.crossover_enabled:
			parent_b = Selection.tournament(current.individuals, config.tournament_size, rng)
			crossover = Crossover.uniform(parent_a.get_genome(), parent_b.get_genome(), config.crossover_probability, rng)
			if not crossover.success: last_error = crossover.error; return null
			source_genome = crossover.genome
		else:
			source_genome = parent_a.get_genome().duplicate()
			crossover = {"applied": false, "inherited_a": source_genome.size(), "inherited_b": 0}
		var mutation: Dictionary = Mutation.gaussian(source_genome, config.mutation_probability, config.mutation_strength, config.parameter_absolute_limit, rng)
		var child: Individual = _create_from_parent(parent_a, next.individuals.size() + 1, mutation, "offspring")
		child.lineage.parent_b_identifier = parent_b.identifier if is_instance_valid(parent_b) else ""
		child.lineage.crossover_applied = crossover.applied
		child.lineage.inherited_from_a = crossover.inherited_a
		child.lineage.inherited_from_b = crossover.inherited_b
		var retries: int = 0
		while config.curriculum_enabled and _exact_copy_count(next.individuals, child.get_genome()) >= config.maximum_identical_genomes and retries < config.clone_retry_limit:
			clone_rejections += 1
			var extra: Dictionary = Mutation.gaussian(child.get_genome(), config.mutation_probability, config.mutation_strength, config.parameter_absolute_limit, rng)
			child.set_genome(extra.genome)
			child.lineage.mutation_count += int(extra.mutation_count)
			additional_mutations += int(extra.mutation_count)
			retries += 1
		if config.curriculum_enabled and _exact_copy_count(next.individuals, child.get_genome()) >= config.maximum_identical_genomes:
			child = _create_random_individual(next.individuals.size() + 1, "immigrant")
			immigrant_count += 1
			immigrant_replacements += 1
		else:
			parent_counts[parent_a.identifier] = int(parent_counts.get(parent_a.identifier, 0)) + 1
			if parent_a.rank <= ceili(float(current.individuals.size()) * 0.25): upper_quartile_parent_count += 1
		next.individuals.append(child)
	while next.individuals.size() < config.population_size:
		next.individuals.append(_create_random_individual(next.individuals.size() + 1, "immigrant"))
	var maximum_descendants: int = 0
	for count: int in parent_counts.values(): maximum_descendants = maxi(maximum_descendants, count)
	last_breeding_metrics = {
		"immigrants": immigrant_count, "immigrant_percent": 100.0 * float(immigrant_count) / float(config.population_size),
		"clone_rejections": clone_rejections, "additional_mutations": additional_mutations,
		"immigrant_replacements": immigrant_replacements, "diversity_before": before_diversity,
		"diversity_after": next.get_diversity_metrics(), "represented_lineages": parent_counts.size() + immigrant_count,
		"maximum_descendants_from_one_ancestor": maximum_descendants,
		"upper_quartile_pool_participation": float(upper_quartile_parent_count) / float(maxi(1, offspring_target - config.elite_count)),
		"immigrant_mean_distance": _immigrant_mean_distance(next),
	}
	return next


func transfer_population(current: Population, new_phase: int, new_global_generation: int) -> Population:
	current.sort_by_fitness()
	phase_index = new_phase
	phase_generation = 1
	global_generation = new_global_generation
	var next := Population.new(); next.generation = global_generation
	var preserve_count: int = roundi(config.population_size * config.transfer_preserved_fraction)
	var descendant_count: int = roundi(config.population_size * config.transfer_descendant_fraction)
	var top_count: int = maxi(1, ceili(float(current.individuals.size()) * 0.25))
	for index: int in range(preserve_count):
		var ancestor: Individual = current.individuals[index]
		var preserved: Individual = ancestor.duplicate_individual(_identifier(next.individuals.size() + 1))
		_stamp(preserved); _clear_evaluation(preserved)
		preserved.lineage = Lineage.new(); preserved.lineage.origin = "transferred_preserved"
		preserved.lineage.origin_phase = new_phase - 1; preserved.lineage.ancestor_identifier = ancestor.identifier
		preserved.lineage.parent_a_identifier = ancestor.identifier; preserved.lineage.transfer_kind = "preserved"; preserved.lineage.transfer_preserved = true
		next.individuals.append(preserved)
	for index: int in range(descendant_count):
		var ancestor: Individual = current.individuals[rng.randi_range(0, top_count - 1)]
		var mutation: Dictionary = Mutation.gaussian(ancestor.get_genome(), config.mutation_probability, config.mutation_strength, config.parameter_absolute_limit, rng)
		var descendant: Individual = _create_from_parent(ancestor, next.individuals.size() + 1, mutation, "transferred_descendant")
		descendant.lineage.origin_phase = new_phase - 1; descendant.lineage.ancestor_identifier = ancestor.identifier; descendant.lineage.transfer_kind = "descendant"
		next.individuals.append(descendant)
	while next.individuals.size() < config.population_size:
		var immigrant: Individual = _create_random_individual(next.individuals.size() + 1, "transferred_immigrant")
		immigrant.lineage.transfer_kind = "immigrant"
		next.individuals.append(immigrant)
	last_breeding_metrics = {
		"transfer": true, "preserved": preserve_count, "descendants": descendant_count,
		"immigrants": config.population_size - preserve_count - descendant_count,
		"diversity_after": next.get_diversity_metrics(),
	}
	return next


func inject_diversity(current: Population) -> Dictionary:
	current.sort_by_fitness()
	var elite_genomes: Array[PackedFloat32Array] = []
	for index: int in range(config.elite_count): elite_genomes.append(current.individuals[index].get_genome())
	var non_elite_count: int = current.individuals.size() - config.elite_count
	var replacement_count: int = roundi(float(non_elite_count) * 0.20)
	var mutation_count: int = roundi(float(non_elite_count - replacement_count) * 0.20)
	for offset: int in range(replacement_count):
		var index: int = current.individuals.size() - 1 - offset
		current.individuals[index] = _create_random_individual(index + 1, "manual_immigrant")
	for offset: int in range(mutation_count):
		var index: int = config.elite_count + offset
		var mutation: Dictionary = Mutation.gaussian(current.individuals[index].get_genome(), config.mutation_probability, 0.12, config.parameter_absolute_limit, rng)
		current.individuals[index].set_genome(mutation.genome)
		current.individuals[index].lineage.mutation_count += int(mutation.mutation_count)
		_clear_evaluation(current.individuals[index])
	var elites_preserved: bool = true
	for index: int in range(config.elite_count): elites_preserved = elites_preserved and current.individuals[index].get_genome() == elite_genomes[index]
	return {"replaced": replacement_count, "mutated": mutation_count, "elites_preserved": elites_preserved, "diversity_after": current.get_diversity_metrics()}


func _create_random_individual(index: int, origin: String) -> Individual:
	var individual := Individual.new(); individual.identifier = _identifier(index); _stamp(individual)
	individual.creation_seed = int(rng.randi()); individual.network = Network.new(); individual.network.configure(config.network_config, individual.creation_seed)
	individual.lineage.origin = origin; individual.lineage.origin_phase = phase_index
	return individual


func _create_from_parent(parent: Individual, index: int, mutation: Dictionary, origin: String) -> Individual:
	var child := Individual.new(); child.identifier = _identifier(index); _stamp(child)
	child.creation_seed = int(rng.randi()); child.network = parent.network.clone_network(); child.set_genome(mutation.genome)
	child.lineage.origin = origin; child.lineage.origin_phase = phase_index; child.lineage.parent_a_identifier = parent.identifier; child.lineage.ancestor_identifier = parent.identifier
	child.lineage.inherited_from_a = child.get_genome().size(); child.lineage.mutation_count = mutation.mutation_count
	child.lineage.mutation_max_delta = mutation.max_delta; child.lineage.mutation_mean_absolute_delta = mutation.mean_absolute_delta; child.lineage.mutation_strength = mutation.strength
	return child


func _stamp(individual: Individual) -> void:
	individual.birth_generation = global_generation; individual.global_generation = global_generation
	individual.phase_generation = phase_generation; individual.origin_phase = phase_index


func _identifier(index: int) -> String:
	return "F%d-G%04d-I%04d" % [phase_index, phase_generation, index] if config.curriculum_enabled else "G%04d-I%04d" % [global_generation, index]


func _exact_copy_count(individuals: Array[Individual], genome: PackedFloat32Array) -> int:
	var count: int = 0
	for individual: Individual in individuals:
		if individual.get_genome() == genome: count += 1
	return count


func _immigrant_mean_distance(population: Population) -> float:
	var immigrants: Array[Individual] = []; var residents: Array[Individual] = []
	for individual: Individual in population.individuals:
		if "immigrant" in individual.lineage.origin: immigrants.append(individual)
		else: residents.append(individual)
	if immigrants.is_empty() or residents.is_empty(): return 0.0
	var total: float = 0.0; var pairs: int = 0
	for immigrant: Individual in immigrants:
		for resident_index: int in range(mini(8, residents.size())):
			total += Population._mean_absolute_distance(immigrant.get_genome(), residents[resident_index].get_genome()); pairs += 1
	return total / float(maxi(1, pairs))


static func make_identifier(generation: int, index: int) -> String:
	return "G%04d-I%04d" % [generation, index]


static func _clear_evaluation(individual: Individual) -> void:
	individual.fitness_total = 0.0; individual.fitness_average = 0.0; individual.victories = 0; individual.win_rate = 0.0
	individual.average_progress = 0.0; individual.best_progress = 0.0; individual.average_moves = 0.0
	individual.evaluated_matches = 0; individual.rank = 0; individual.training_summary.clear(); individual.validation_summary.clear()
