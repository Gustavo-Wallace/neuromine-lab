class_name NeuralOutputAnalyzer
extends RefCounted

enum Condition { HEALTHY, LOW_DIFFERENTIATION, SATURATED_ZERO, SATURATED_ONE, INVALID }

const ZERO_THRESHOLD: float = 0.05
const ONE_THRESHOLD: float = 0.95
const LOW_RANGE_THRESHOLD: float = 0.01


static func classify(summary: Dictionary) -> int:
	if int(summary.get("non_finite_count", 0)) > 0:
		return Condition.INVALID
	var mean: float = float(summary.get("score_mean", 0.5))
	if mean <= ZERO_THRESHOLD:
		return Condition.SATURATED_ZERO
	if mean >= ONE_THRESHOLD:
		return Condition.SATURATED_ONE
	if float(summary.get("mean_score_range", 0.0)) < LOW_RANGE_THRESHOLD:
		return Condition.LOW_DIFFERENTIATION
	return Condition.HEALTHY


static func to_text(condition: int) -> String:
	match condition:
		Condition.HEALTHY: return "saudáveis"
		Condition.LOW_DIFFERENTIATION: return "baixa diferenciação"
		Condition.SATURATED_ZERO: return "saturadas em zero"
		Condition.SATURATED_ONE: return "saturadas em um"
		Condition.INVALID: return "inválidas"
	return "desconhecidas"
