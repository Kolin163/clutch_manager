# ============================================================================
# ROSTER SELECT — Экран выбора состава (Исправлено лого)
# ============================================================================
extends Control

const AgentMiniCardScene := preload("res://ui/components/agent_mini_card.tscn")

const REQUIRED_ROSTER_SIZE := 5
const STARTING_CONTRACT_SEASONS := 2
const SIGNING_FEE_RATIO := 0.5
const AGENT_LIMIT := 12

@onready var team_info: Label = $SafeArea/MainVBox/Header/TeamInfo
@onready var budget_label: Label = $SafeArea/MainVBox/Header/BudgetLabel
@onready var available_grid: GridContainer = $SafeArea/MainVBox/HSplit/AvailablePanel/AvailableScroll/AvailableGrid
@onready var slots_container: VBoxContainer = $SafeArea/MainVBox/HSplit/SelectedPanel/SlotsContainer
@onready var salary_label: Label = $SafeArea/MainVBox/HSplit/SelectedPanel/InfoVBox/SalaryLabel
@onready var start_button: Button = $SafeArea/MainVBox/Footer/StartButton
@onready var roles_info: Label = $SafeArea/MainVBox/HSplit/SelectedPanel/InfoVBox/RolesInfo
@onready var slots_title: Label = $SafeArea/MainVBox/HSplit/SelectedPanel/Label

var selected_players: Array[Dictionary] = []
var available_agents: Array[Dictionary] = []
var signing_total_label: Label = null

var role_option: OptionButton
var sort_option: OptionButton

func _ready() -> void:
	_init_team_info()
	_generate_agent_pool()
	_setup_filters()
	_update_ui()

func _setup_filters() -> void:
	var available_panel = $SafeArea/MainVBox/HSplit/AvailablePanel
	var filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 10)
	available_panel.add_child(filter_bar)
	available_panel.move_child(filter_bar, 1) # Поставить под Label
	
	role_option = OptionButton.new()
	role_option.add_item("Все роли", 0)
	role_option.add_item("Entry", 1)
	role_option.add_item("AWPer", 2)
	role_option.add_item("Support", 3)
	role_option.add_item("Lurker", 4)
	role_option.add_item("IGL", 5)
	filter_bar.add_child(role_option)
	role_option.item_selected.connect(_on_filter_changed)
	
	sort_option = OptionButton.new()
	sort_option.add_item("Сорт: Умолч", 0)
	sort_option.add_item("Скилл (Убыв)", 1)
	sort_option.add_item("Скилл (Возр)", 2)
	sort_option.add_item("Потенциал", 3)
	filter_bar.add_child(sort_option)
	sort_option.item_selected.connect(_on_filter_changed)

func _on_filter_changed(_idx: int) -> void:
	_update_ui()

func _init_team_info() -> void:
	var td = GameManager.player_team_data
	var team_name = td.get("name", "Unknown")
	var logo_path = td.get("logo", "res://icon.svg")
	
	# Если логотип - это путь, ставим иконку-заменитель, иначе эмодзи
	if logo_path.begins_with("res://"):
		team_info.text = "🛡️ " + team_name
	else:
		team_info.text = logo_path + " " + team_name
		
	budget_label.text = "$" + str(EconomyManager.get_budget())

func _generate_agent_pool() -> void:
	var full_pool = AgentPool.generate_starting_pool()
	available_agents = full_pool.slice(0, AGENT_LIMIT)
	_populate_available_grid()

func _populate_available_grid() -> void:
	for child in available_grid.get_children(): child.queue_free()
	
	var r_sel = role_option.selected if role_option else 0
	var role_filter = ""
	match r_sel:
		1: role_filter = "entry"
		2: role_filter = "awper"
		3: role_filter = "support"
		4: role_filter = "lurker"
		5: role_filter = "igl"
		
	var sort_mode = sort_option.selected if sort_option else 0
	
	var visible_agents = []
	for agent in available_agents:
		if _is_selected(agent.get("id", "")): continue
		if role_filter != "" and agent.get("role", "") != role_filter: continue
		visible_agents.append(agent)
		
	if sort_mode > 0:
		visible_agents.sort_custom(func(a, b):
			var has_analyst = StaffManager.has_analyst()
			if sort_mode == 1:
				return Scouting.get_perceived_overall(a, has_analyst) > Scouting.get_perceived_overall(b, has_analyst)
			elif sort_mode == 2:
				return Scouting.get_perceived_overall(a, has_analyst) < Scouting.get_perceived_overall(b, has_analyst)
			elif sort_mode == 3:
				var p_a = Scouting.get_visible_skills(a, has_analyst).get("potential", {}).get("value", 0)
				var p_b = Scouting.get_visible_skills(b, has_analyst).get("potential", {}).get("value", 0)
				if typeof(p_a) == TYPE_STRING or typeof(p_b) == TYPE_STRING:
					return a.get("potential", 0) > b.get("potential", 0)
				return p_a > p_b
			return true
		)
		
	for agent in visible_agents:
		var card = AgentMiniCardScene.instantiate()
		available_grid.add_child(card)
		card.setup(agent)
		card.mini_card_pressed.connect(_on_agent_clicked)

func _update_ui() -> void:
	_populate_available_grid()
	_update_slots()
	_update_info_panel()
	_update_start_button()

func _update_slots() -> void:
	var slots = slots_container.get_children()
	for i in range(REQUIRED_ROSTER_SIZE):
		var slot = slots[i]
		var label = slot.get_node("Label")
		var remove_btn = slot.get_node("RemoveBtn")
		
		if i < selected_players.size():
			var p = selected_players[i]
			label.text = p["nickname"] + " (" + _get_role_short(p["role"]) + ")"
			label.add_theme_color_override("font_color", Color.WHITE)
			remove_btn.visible = true
			slot.modulate = Color(1, 1, 1, 1)
		else:
			label.text = "ПУСТОЙ СЛОТ"
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 1))
			remove_btn.visible = false
			slot.modulate = Color(0.5, 0.5, 0.5, 0.5)

func _update_info_panel() -> void:
	var count = selected_players.size()
	if count == REQUIRED_ROSTER_SIZE:
		slots_title.text = "СОСТАВ ГОТОВ (5/5)"
		slots_title.add_theme_color_override("font_color", Color.html("#4DFF80"))
	else:
		slots_title.text = "ВАША ОБОЙМА (" + str(count) + "/5)"
		slots_title.add_theme_color_override("font_color", Color.WHITE)

	if signing_total_label == null:
		signing_total_label = Label.new()
		signing_total_label.add_theme_font_size_override("font_size", 14)
		var parent = salary_label.get_parent()
		parent.add_child(signing_total_label)
		parent.move_child(signing_total_label, salary_label.get_index() + 1)
	
	var total_salary := 0
	var total_signing := 0
	var roles: Array[String] = []
	
	for p in selected_players:
		var sal = p.get("contract", {}).get("salary", 0)
		total_salary += sal
		total_signing += int(sal * SIGNING_FEE_RATIO)
		roles.append(_get_role_short(p.get("role", "")))
	
	salary_label.text = "Общие зарплаты: $" + str(total_salary) + "/сез"
	signing_total_label.text = "Сумма подписания: $" + str(total_signing)
	
	if total_signing > EconomyManager.get_budget():
		signing_total_label.add_theme_color_override("font_color", Color.html("#FF6666"))
	else:
		signing_total_label.add_theme_color_override("font_color", Color.html("#FFCC66"))
	
	roles_info.text = "Роли: " + (", ".join(roles) if not roles.is_empty() else "---")

func _on_agent_clicked(data: Dictionary) -> void:
	if selected_players.size() < REQUIRED_ROSTER_SIZE:
		if not _is_selected(data["id"]):
			selected_players.append(data)
			_update_ui()

func _on_remove_pressed(index: int) -> void:
	if index < selected_players.size():
		selected_players.remove_at(index)
		_update_ui()

func _is_selected(pid: String) -> bool:
	for p in selected_players:
		if p.get("id", "") == pid: return true
	return false

func _update_start_button() -> void:
	var total_fee := 0
	for p in selected_players:
		total_fee += int(p.get("contract", {}).get("salary", 0) * SIGNING_FEE_RATIO)
	
	var count = selected_players.size()
	if count < REQUIRED_ROSTER_SIZE:
		start_button.text = "НУЖНО ЕЩЕ " + str(REQUIRED_ROSTER_SIZE - count) + " ИГРОКА"
	elif total_fee > EconomyManager.get_budget():
		start_button.text = "НЕДОСТАТОЧНО СРЕДСТВ"
	else:
		start_button.text = "НАЧАТЬ СЕЗОН"
	start_button.disabled = (count != REQUIRED_ROSTER_SIZE) or (total_fee > EconomyManager.get_budget())

func _on_start_pressed() -> void:
	var total_fee := 0
	for p in selected_players:
		total_fee += int(p.get("contract", {}).get("salary", 0) * SIGNING_FEE_RATIO)
	EconomyManager.spend_money(total_fee, "initial_signing")
	RosterManager.clear_roster()
	for p in selected_players:
		var sal = p.get("contract", {}).get("salary", 500)
		RosterManager.add_player(ContractManager.sign_player(p, STARTING_CONTRACT_SEASONS, sal))
		AgentPool.remove_from_pool(p["id"])
	GameManager.change_state(GameManager.GameState.SEASON)
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")

func _get_role_short(role: String) -> String:
	match role:
		"entry": return "ENT"
		"awper": return "AWP"
		"support": return "SUP"
		"lurker": return "LRK"
		"igl": return "IGL"
		_: return role.left(3).to_upper()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/team_setup.tscn")
