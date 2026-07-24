class_name NeuralInspector
extends VBoxContainer

signal ranking_candidate_selected(candidate_position: Vector2i)

const NeuralAgentScript := preload("res://scripts/agents/neural_agent.gd")
const ScoreScript := preload("res://scripts/agents/candidate_score.gd")
const Activation := preload("res://scripts/neural/neural_activation.gd")

@onready var network_info: Label = $NetworkInfo
@onready var ranking_list: ItemList = $RankingList
@onready var open_inspector: CheckButton = $NeuralControls/OpenNeuralInspectorButton
@onready var advanced_container: VBoxContainer = $AdvancedContainer
@onready var layer_option: OptionButton = $AdvancedContainer/LayerOption
@onready var activation_info: Label = $AdvancedContainer/ActivationInfo

var _agent: NeuralAgentScript
var _ranking_positions: Array[Vector2i] = []
var _activation_statistics: Array[Dictionary] = []


func _ready() -> void:
	ranking_list.item_selected.connect(_on_ranking_item_selected)
	open_inspector.toggled.connect(_on_open_toggled)
	layer_option.item_selected.connect(_on_layer_selected)
	advanced_container.visible = false


func set_agent(agent: NeuralAgentScript) -> void:
	_agent = agent
	_refresh_network_info()
	ranking_list.clear()
	_ranking_positions.clear()
	activation_info.text = "Execute uma decisão neural para inspecionar ativações."


func update_decision(agent: NeuralAgentScript) -> void:
	_agent = agent
	_refresh_network_info()
	ranking_list.clear()
	_ranking_positions.clear()
	for index: int in range(mini(5, agent.last_ranking.size())):
		var score: ScoreScript = agent.last_ranking[index]
		ranking_list.add_item("%d. (%d, %d) — %.4f" % [
			index + 1, score.candidate_position.x, score.candidate_position.y, score.raw_score
		])
		_ranking_positions.append(score.candidate_position)
	if not agent.last_ranking.is_empty() and is_instance_valid(agent.last_ranking[0].observation):
		agent.network.forward(agent.last_ranking[0].observation.get_vector(), true)
		_activation_statistics = agent.network.get_activation_statistics()
		_refresh_layer_options()
		_render_activations()


func _refresh_network_info() -> void:
	if not is_instance_valid(_agent) or not is_instance_valid(_agent.network):
		network_info.text = "Rede neural ainda não configurada."
		return
	network_info.text = (
		"Arquitetura: %s\n" % _agent.network.config.get_architecture_text()
		+ "Entradas: %d  •  Saída: %d\n" % [
			_agent.network.config.architecture[0], _agent.network.config.architecture[-1]
		]
		+ "Parâmetros: %d\n" % _agent.network.get_parameter_count()
		+ "Seed: %d\n" % _agent.network_seed
		+ "Estado: NÃO TREINADA\n"
		+ "Pontuação é preferência, não probabilidade."
	)


func _refresh_layer_options() -> void:
	layer_option.clear()
	layer_option.add_item("Todas as camadas")
	for index: int in range(_activation_statistics.size()):
		layer_option.add_item("Camada %d" % (index + 1))
	layer_option.select(0)


func _render_activations() -> void:
	if _activation_statistics.is_empty():
		return
	var selected: int = layer_option.selected - 1
	var lines: Array[String] = ["ATIVAÇÕES INTERNAS", _agent.network.config.get_architecture_text()]
	for index: int in range(_activation_statistics.size()):
		if selected >= 0 and selected != index:
			continue
		var stats: Dictionary = _activation_statistics[index]
		var activation_name: String = Activation.name_for(_agent.network.layers[index].activation_type)
		lines.append(
			"Camada %d (%s, %d): min %.3f  máx %.3f  média %.3f  +%d / -%d" % [
				index + 1, activation_name, stats.neuron_count, stats.minimum, stats.maximum,
				stats.mean, stats.positive_count, stats.negative_count
			]
		)
	activation_info.text = "\n".join(lines)


func _on_ranking_item_selected(index: int) -> void:
	if index >= 0 and index < _ranking_positions.size():
		ranking_candidate_selected.emit(_ranking_positions[index])


func _on_open_toggled(enabled: bool) -> void:
	advanced_container.visible = enabled


func _on_layer_selected(_index: int) -> void:
	_render_activations()
