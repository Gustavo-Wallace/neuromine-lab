class_name DiagnosticSuite
extends RefCounted

const BoardTests := preload("res://scripts/debug/board_self_test.gd")
const AgentTests := preload("res://scripts/debug/agent_self_test.gd")
const ObservationTests := preload("res://scripts/debug/observation_diagnostics.gd")


static func run_all() -> Dictionary:
	var board_result: Dictionary = BoardTests.run_all()
	var agent_result: Dictionary = AgentTests.run_all()
	var observation_result: Dictionary = ObservationTests.run_all()
	var failures: Array = board_result.failures + agent_result.failures + observation_result.failures
	var passed: int = board_result.passed + agent_result.passed + observation_result.passed
	var failed: int = failures.size()
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
		"summary": "Diagnósticos: %d aprovados, %d falhas" % [passed, failed],
		"observation_benchmark": ObservationTests.run_benchmark(250),
	}
