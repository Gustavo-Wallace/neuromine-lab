class_name VisualMatchController
extends Node

signal state_changed(playback_state: int)
signal decision_preview(action: AgentAction)
signal action_completed(event: Dictionary)
signal match_completed(result)

enum PlaybackState {
	STOPPED,
	PLAYING,
	PAUSED,
	COMPLETED,
}

enum TimerPhase {
	IDLE,
	PREVIEW,
	BETWEEN_ACTIONS,
}

const RandomAgentScript := preload("res://scripts/agents/random_agent.gd")
const Simulator := preload("res://scripts/simulation/match_simulator.gd")
const ResultScript := preload("res://scripts/simulation/simulation_result.gd")
const BASE_ACTION_INTERVAL: float = 0.65
const PREVIEW_FRACTION: float = 0.35
const MINIMUM_TIMER_INTERVAL: float = 0.02

var playback_state: int = PlaybackState.STOPPED
var speed_multiplier: float = 1.0
var simulator: Simulator

var _timer: Timer
var _timer_phase: int = TimerPhase.IDLE
var _single_step_requested: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func configure_match(board: MinesweeperBoard, agent_seed: int) -> void:
	var agent := RandomAgentScript.new()
	agent.configure(agent_seed)
	configure_agent_match(board, agent)


func configure_agent_match(board: MinesweeperBoard, agent: MinesweeperAgent, configuration: Dictionary = {}) -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	simulator = Simulator.new()
	var simulator_configuration: Dictionary = configuration.duplicate(true)
	simulator_configuration["record_history"] = true
	simulator.setup(board, agent, simulator_configuration)
	_timer_phase = TimerPhase.IDLE
	_single_step_requested = false
	_set_state(PlaybackState.STOPPED)


func start() -> void:
	if not is_instance_valid(simulator):
		return
	if simulator.is_finished():
		simulator.reset_same_match()
	_set_state(PlaybackState.PLAYING)
	_timer.paused = false
	if _timer_phase == TimerPhase.IDLE:
		_prepare_preview()


func toggle_pause() -> void:
	if playback_state == PlaybackState.PLAYING:
		_timer.paused = true
		_set_state(PlaybackState.PAUSED)
	elif playback_state == PlaybackState.PAUSED:
		_timer.paused = false
		_set_state(PlaybackState.PLAYING)
		if _timer_phase == TimerPhase.IDLE:
			_prepare_preview()


func step_once() -> void:
	if not is_instance_valid(simulator):
		return
	if simulator.is_finished():
		return
	_single_step_requested = true
	_set_state(PlaybackState.PAUSED)
	_timer.paused = false
	if _timer_phase == TimerPhase.BETWEEN_ACTIONS:
		_timer.stop()
		_timer_phase = TimerPhase.IDLE
	if _timer_phase == TimerPhase.IDLE:
		_prepare_preview()


func stop() -> void:
	if not is_instance_valid(simulator):
		return
	_timer.stop()
	_timer_phase = TimerPhase.IDLE
	_single_step_requested = false
	var result: ResultScript = simulator.stop()
	_set_state(PlaybackState.STOPPED)
	match_completed.emit(result)


func reset_same_match() -> void:
	if not is_instance_valid(simulator):
		return
	_timer.stop()
	_timer_phase = TimerPhase.IDLE
	_single_step_requested = false
	simulator.reset_same_match()
	_set_state(PlaybackState.STOPPED)


func set_speed(multiplier: float) -> void:
	speed_multiplier = maxf(multiplier, 0.01)
	if not _timer.is_stopped() and not _timer.paused:
		_timer.start(_phase_duration(_timer_phase))


func get_agent_seed() -> int:
	return simulator.agent.agent_seed if is_instance_valid(simulator) else 0


func _prepare_preview() -> void:
	var action: AgentAction = simulator.prepare_next_action()
	if not is_instance_valid(action):
		if simulator.is_finished():
			_complete_match()
		return
	_timer_phase = TimerPhase.PREVIEW
	decision_preview.emit(action)
	_timer.start(_phase_duration(TimerPhase.PREVIEW))


func _on_timer_timeout() -> void:
	match _timer_phase:
		TimerPhase.PREVIEW:
			var event: Dictionary = simulator.execute_pending_action()
			action_completed.emit(event)
			if simulator.is_finished():
				_complete_match()
				return
			if _single_step_requested:
				_single_step_requested = false
				_timer_phase = TimerPhase.IDLE
				_timer.paused = false
				_set_state(PlaybackState.PAUSED)
				return
			_timer_phase = TimerPhase.BETWEEN_ACTIONS
			_timer.start(_phase_duration(TimerPhase.BETWEEN_ACTIONS))
		TimerPhase.BETWEEN_ACTIONS:
			_timer_phase = TimerPhase.IDLE
			if playback_state == PlaybackState.PLAYING:
				_prepare_preview()


func _complete_match() -> void:
	_timer.stop()
	_timer_phase = TimerPhase.IDLE
	_single_step_requested = false
	_set_state(PlaybackState.COMPLETED)
	match_completed.emit(simulator.get_result())


func _phase_duration(phase: int) -> float:
	var total_interval: float = BASE_ACTION_INTERVAL / speed_multiplier
	if phase == TimerPhase.PREVIEW:
		return maxf(MINIMUM_TIMER_INTERVAL, total_interval * PREVIEW_FRACTION)
	return maxf(MINIMUM_TIMER_INTERVAL, total_interval * (1.0 - PREVIEW_FRACTION))


func _set_state(new_state: int) -> void:
	playback_state = new_state
	state_changed.emit(playback_state)
