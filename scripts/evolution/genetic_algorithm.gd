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


func configure(evolution_config: Config) -> bool:
	if not is_instance_valid(evolution_config) or not evolution_config.is_valid():
		last_error = "Invalid evolutionary configuration."
		return false
	config = evolution_config.duplicate_config()
	rng.seed = config.master_seed
	last_error = ""
	return true


func create_initial_population() -> Population:
	var population := Population.new()
	population.generation = 1
	for index: int in range(config.population_size):
		var individual := Individual.new()
		individual.identifier = make_identifier(1, index + 1)
		individual.birth_generation = 1
		individual.network = Network.new()
		individual.creation_seed = int(rng.randi())
		individual.network.configure(config.network_config, individual.creation_seed)
		individual.lineage.origin = "initial"
		population.individuals.append(individual)
	return population


func breed_next_generation(current: Population) -> Population:
	current.sort_by_fitness()
	var next := Population.new()
	next.generation = current.generation + 1
	for elite_index: int in range(config.elite_count):
		var parent: Individual = current.individuals[elite_index]
		var elite: Individual = parent.duplicate_individual(make_identifier(next.generation, next.individuals.size() + 1))
		elite.birth_generation = next.generation
		elite.lineage = Lineage.new()
		elite.lineage.origin = "elite"
		elite.lineage.parent_a_identifier = parent.identifier
		elite.lineage.inherited_from_a = elite.get_genome().size()
		_clear_evaluation(elite)
		next.individuals.append(elite)
	while next.individuals.size() < config.population_size:
		var parent_a: Individual = Selection.tournament(current.individuals, config.tournament_size, rng)
		var parent_b: Individual = Selection.tournament(current.individuals, config.tournament_size, rng)
		var crossover: Dictionary = Crossover.uniform(
			parent_a.get_genome(), parent_b.get_genome(), config.crossover_probability, rng
		)
		if not crossover.success:
			last_error = crossover.error
			return null
		var mutation: Dictionary = Mutation.gaussian(
			crossover.genome, config.mutation_probability, config.mutation_strength,
			config.parameter_absolute_limit, rng
		)
		var child := Individual.new()
		child.identifier = make_identifier(next.generation, next.individuals.size() + 1)
		child.birth_generation = next.generation
		child.creation_seed = int(rng.randi())
		child.network = parent_a.network.clone_network()
		child.set_genome(mutation.genome)
		child.lineage.parent_a_identifier = parent_a.identifier
		child.lineage.parent_b_identifier = parent_b.identifier
		child.lineage.inherited_from_a = crossover.inherited_a
		child.lineage.inherited_from_b = crossover.inherited_b
		child.lineage.crossover_applied = crossover.applied
		child.lineage.mutation_count = mutation.mutation_count
		child.lineage.mutation_max_delta = mutation.max_delta
		child.lineage.mutation_mean_absolute_delta = mutation.mean_absolute_delta
		child.lineage.mutation_strength = mutation.strength
		child.lineage.origin = "offspring"
		next.individuals.append(child)
	return next


static func make_identifier(generation: int, index: int) -> String:
	return "G%04d-I%04d" % [generation, index]


static func _clear_evaluation(individual: Individual) -> void:
	individual.fitness_total = 0.0
	individual.fitness_average = 0.0
	individual.victories = 0
	individual.win_rate = 0.0
	individual.average_progress = 0.0
	individual.best_progress = 0.0
	individual.average_moves = 0.0
	individual.evaluated_matches = 0
	individual.rank = 0
	individual.training_summary.clear()
	individual.validation_summary.clear()
