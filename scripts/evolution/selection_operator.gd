class_name SelectionOperator
extends RefCounted

const Individual := preload("res://scripts/evolution/evolutionary_individual.gd")


static func tournament(individuals: Array[Individual], tournament_size: int, rng: RandomNumberGenerator) -> Individual:
	if individuals.is_empty():
		return null
	var winner: Individual = individuals[rng.randi_range(0, individuals.size() - 1)]
	for draw: int in range(1, tournament_size):
		var challenger: Individual = individuals[rng.randi_range(0, individuals.size() - 1)]
		if challenger.fitness_average > winner.fitness_average:
			winner = challenger
		elif challenger.fitness_average == winner.fitness_average and challenger.identifier < winner.identifier:
			winner = challenger
	return winner
