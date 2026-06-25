# ============================================================================
# MARKET SCREEN — Исправленная навигация и выбор
# ============================================================================
extends Control

const AgentMiniCardScene := preload("res://ui/components/agent_mini_card.tscn")

@onready var budget_lbl: Label = $MainVBox/Header/BudgetLabel
@onready var agent_grid: GridContainer = $MainVBox/HSplit/GridPanel/VBox/Scroll/AgentGrid
@onready var role_option: OptionButton = $MainVBox/HSplit/GridPanel/VBox/FilterBar/RoleOption
@onready var player_card = $MainVBox/HSplit/DetailPanel/DetailVBox/PlayerCard
@onready var fee_label: Label = $MainVBox/HSplit/DetailPanel/DetailVBox/HireVBox/FeeLabel
@onready var hire_btn: Button = $MainVBox/HSplit/DetailPanel/DetailVBox/HireVBox/HireBtn
@onready var analyst_hint: Label = $MainVBox/HSplit/DetailPanel/DetailVBox/AnalystHint

var sort_option: OptionButton
var selected_agent_id: String = ""

func _ready() -> void:
	_setup_filters()
	_update_ui()

func _update_ui() -> void:
	budget_lbl.text = "$" + str(EconomyManager.get_budget())
	_build_grid()
	
	var pool = AgentPool.get_pool()
	if not pool.is_empty() and selected_agent_id == "":
		_on_agent_selected(pool[0])
	elif selected_agent_id != "":
		var agent = AgentPool.get_agent_by_id(selected_agent_id)
		if not agent.is_empty():
			_on_agent_selected(agent)

func _build_grid() -> void:
	for child in agent_grid.get_children(): child.queue_free()
	
	var pool = AgentPool.get_pool()
	var role_filter = _get_role_filter_id()
	
	var visible_agents = []
	for agent in pool:
		if role_filter != "" and agent["role"] != role_filter: continue
		visible_agents.append(agent)
		
	# Сортировка
	var sort_mode = _get_sort_mode()
	if sort_mode > 0:
		visible_agents.sort_custom(func(a, b):
			var has_analyst = StaffManager.has_analyst()
			if sort_mode == 1: # Скилл убыв
				return Scouting.get_perceived_overall(a, has_analyst) > Scouting.get_perceived_overall(b, has_analyst)
			elif sort_mode == 2: # Скилл возр
				return Scouting.get_perceived_overall(a, has_analyst) < Scouting.get_perceived_overall(b, has_analyst)
			elif sort_mode == 3: # Потенциал убыв
				var p_a = Scouting.get_visible_skills(a, has_analyst).get("potential", {}).get("value", 0)
				var p_b = Scouting.get_visible_skills(b, has_analyst).get("potential", {}).get("value", 0)
				if typeof(p_a) == TYPE_STRING or typeof(p_b) == TYPE_STRING:
					return a.get("potential", 0) > b.get("potential", 0) # Fallback if hidden
				return p_a > p_b
			return true
		)
	
	var valid_selection = false
	for agent in visible_agents:
		if agent["id"] == selected_agent_id: valid_selection = true
		
		var mini = AgentMiniCardScene.instantiate()
		agent_grid.add_child(mini)
		mini.setup(agent)
		mini.set_selected(agent["id"] == selected_agent_id)
		mini.mini_card_pressed.connect(_on_agent_selected)
		
	if not valid_selection:
		if visible_agents.size() > 0:
			_on_agent_selected(visible_agents[0])
		else:
			selected_agent_id = ""
			player_card.visible = false
			hire_btn.disabled = true
			fee_label.text = ""

func _on_agent_selected(data: Dictionary) -> void:
	selected_agent_id = data["id"]
	player_card.visible = true
	player_card.set_player_data(data)
	
	var sal = data.get("contract", {}).get("salary", 500)
	var fee = int(sal * 0.5)
	fee_label.text = "Стоимость подписания: $" + str(fee)
	
	var can_hire = EconomyManager.can_afford(fee) and RosterManager.get_roster_size() < 5
	hire_btn.disabled = not can_hire
	hire_btn.text = "НАНЯТЬ ЗА $" + str(fee) if RosterManager.get_roster_size() < 5 else "СОСТАВ ПОЛОН"
	
	_refresh_grid_highlights()

func _refresh_grid_highlights() -> void:
	for child in agent_grid.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.player_data["id"] == selected_agent_id)

func _on_hire_pressed() -> void:
	if selected_agent_id == "": return
	var agent = AgentPool.get_agent_by_id(selected_agent_id)
	var fee = int(agent.get("contract", {}).get("salary", 500) * 0.5)
	
	if EconomyManager.spend_money(fee, "hire_agent"):
		var signed = ContractManager.sign_player(agent, 2, agent["contract"]["salary"])
		RosterManager.add_player(signed)
		AgentPool.remove_from_pool(selected_agent_id)
		selected_agent_id = ""
		_update_ui()

func _get_role_filter_id() -> String:
	match role_option.selected:
		1: return "entry"
		2: return "awper"
		3: return "support"
		4: return "lurker"
		5: return "igl"
		_: return ""

func _setup_filters() -> void:
	role_option.clear()
	role_option.add_item("Все роли", 0)
	role_option.add_item("Entry", 1)
	role_option.add_item("AWPer", 2)
	role_option.add_item("Support", 3)
	role_option.add_item("Lurker", 4)
	role_option.add_item("IGL", 5)
	
	# Добавляем сортировку динамически
	var filter_bar = role_option.get_parent()
	
	sort_option = OptionButton.new()
	filter_bar.add_child(sort_option)
	sort_option.add_item("Сорт: По умолчанию", 0)
	sort_option.add_item("Сорт: По скиллу (Убыв)", 1)
	sort_option.add_item("Сорт: По скиллу (Возр)", 2)
	sort_option.add_item("Сорт: По потенциалу", 3)
	sort_option.item_selected.connect(_on_role_filter_changed)

func _get_sort_mode() -> int:
	if sort_option == null: return 0
	return sort_option.selected

func _on_role_filter_changed(_idx: int) -> void:
	_update_ui()

func _on_back_pressed() -> void:
	# ИСПРАВЛЕНО: Теперь ведет в Состав
	get_tree().change_scene_to_file("res://ui/screens/roster_screen.tscn")
