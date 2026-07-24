class_name DiagnosticSuite
extends RefCounted

const BoardTests := preload("res://scripts/debug/board_self_test.gd")
const AgentTests := preload("res://scripts/debug/agent_self_test.gd")


static func run_all() -> Dictionary:
	var board_result: Dictionary = BoardTests.run_all()
	var agent_result: Dictionary = AgentTests.run_all()
	var failures: Array = board_result.failures + agent_result.failures
	var passed: int = board_result.passed + agent_result.passed
	var failed: int = failures.size()
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
		"summary": "Diagnósticos: %d aprovados, %d falhas" % [passed, failed],
	}
