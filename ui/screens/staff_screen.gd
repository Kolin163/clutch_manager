# ============================================================================
# STAFF SCREEN — Улучшенные подсказки и сброс данных
# ============================================================================
extends Control

const ROLE_ICONS := {0: "📋", 1: "🔍", 2: "🧠", 3: "📊"}
const ROLE_NAMES := {0: "Тренер", 1: "Аналитик", 2: "Психолог", 3: "Менеджер"}
const ROLE_COLORS := {0: "#FF994D", 1: "#4DB8FF", 2: "#B34DFF", 3: "#4DFF80"}

@onready var slots_lbl: Label = $SafeArea/MainVBox/Header/TitleVBox/SlotsLabel
@onready var budget_lbl: Label = $SafeArea/MainVBox/Header/Budget
@onready var hired_list: VBoxContainer = $SafeArea/MainVBox/ContentHBox/LeftPanel/HiredSection/HiredList
@onready var market_list: VBoxContainer = $SafeArea/MainVBox/ContentHBox/LeftPanel/MarketSection/Scroll/MarketList
@onready var refresh_btn: Button = $SafeArea/MainVBox/ContentHBox/LeftPanel/MarketSection/Header/RefreshBtn

# Detail nodes
@onready var det_icon: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/RoleIcon
@onready var det_name: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/Name
@onready var det_role: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/RoleName
@onready var det_skill: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/Stats/Skill
@onready var det_contract: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/Stats/Contract
@onready var det_bonus: Label = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/BonusText
@onready var action_btn: Button = $SafeArea/MainVBox/ContentHBox/RightPanel/DetailVBox/ActionBtn

var available_staff: Array = []
var selected_staff: Dictionary = {}
var is_selected_hired: bool = false
var has_refreshed_at_start: bool = false
var has_refreshed_at_mid: bool = false

func _ready() -> void:
	if available_staff.is_empty():
		_generate_market()
	_update_ui()

func _update_ui() -> void:
	budget_lbl.text = "$" + str(EconomyManager.get_budget())
	slots_lbl.text = "Свободных мест: %d/%d" % [StaffManager.get_hired_count(), StaffManager.get_max_slots()]
	
	_update_refresh_button()
	_build_lists()
	
	if selected_staff.is_empty(): _clear_detail()
	else: _show_detail(selected_staff, is_selected_hired)

func _update_refresh_button() -> void:
	var day = LeagueManager.current_match_day
	var can_refresh = false
	if day == 0 and not has_refreshed_at_start: can_refresh = true
	elif day >= 7 and not has_refreshed_at_mid: can_refresh = true
	refresh_btn.disabled = not can_refresh
	refresh_btn.modulate.a = 1.0 if can_refresh else 0.4

func _build_lists() -> void:
	for child in hired_list.get_children(): child.queue_free()
	for child in market_list.get_children(): child.queue_free()
	for s in StaffManager.get_all(): hired_list.add_child(_create_card(s, true))
	for s in available_staff: market_list.add_child(_create_card(s, false))

func _create_card(data: Dictionary, is_hired: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var is_sel = selected_staff.get("id") == data["id"]
	style.bg_color = Color(0.18, 0.22, 0.28, 1) if is_sel else Color(0.1, 0.12, 0.15, 1)
	style.border_width_left = 4
	style.border_color = Color.html(ROLE_COLORS.get(data["role"], "#FFFFFF"))
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 65
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	panel.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	var icon := Label.new()
	icon.text = ROLE_ICONS.get(data["role"], "👤")
	icon.add_theme_font_size_override("font_size", 24)
	hbox.add_child(icon)
	var v_info := VBoxContainer.new()
	v_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_info.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(v_info)
	var name_lbl := Label.new()
	name_lbl.text = data["last_name"].to_upper()
	v_info.add_child(name_lbl)
	var role_lbl := Label.new()
	role_lbl.text = ROLE_NAMES.get(data["role"], "").to_upper()
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	v_info.add_child(role_lbl)
	var v_skill := VBoxContainer.new()
	v_skill.custom_minimum_size.x = 70
	v_skill.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(v_skill)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 4
	bar.show_percentage = false
	bar.value = data["skill_level"]
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color.html(ROLE_COLORS.get(data["role"]))
	bar.add_theme_stylebox_override("fill", bar_style)
	v_skill.add_child(bar)
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(_show_detail.bind(data, is_hired))
	panel.add_child(btn)
	return panel

func _show_detail(data: Dictionary, is_hired: bool) -> void:
	selected_staff = data
	is_selected_hired = is_hired
	action_btn.visible = true
	det_icon.text = ROLE_ICONS.get(data["role"], "👤")
	det_name.text = data["first_name"] + " " + data["last_name"]
	det_role.text = ROLE_NAMES.get(data["role"], "").to_upper()
	det_role.add_theme_color_override("font_color", Color.html(ROLE_COLORS.get(data["role"])))
	det_skill.text = "Уровень мастерства: " + str(data["skill_level"])
	det_contract.text = "Контракт: " + str(data["contract_seasons_left"]) + " сез." if is_hired else "Зарплата: $" + str(data["salary"]) + "/сез"
	det_bonus.text = _get_bonus_description(data["role"], data["skill_level"])
	
	if is_hired:
		action_btn.text = "УВОЛИТЬ СПЕЦИАЛИСТА"
		action_btn.modulate = Color.html("#FF6666")
		action_btn.disabled = false
	else:
		var cost = int(data["salary"] * (1.0 - StaffManager.get_hire_discount()))
		var max_slots = StaffManager.get_max_slots()
		var hired_count = StaffManager.get_hired_count()
		
		# ПРОВЕРКА СЛОТОВ И ОФИСА
		if max_slots <= 0:
			action_btn.text = "НУЖЕН ОФИС МЕНЕДЖЕРА"
			action_btn.disabled = true
		elif hired_count >= max_slots:
			action_btn.text = "НЕТ СВОБОДНЫХ СЛОТОВ"
			action_btn.disabled = true
		elif StaffManager.has_role(data["role"]):
			action_btn.text = "РОЛЬ УЖЕ ЗАНЯТА"
			action_btn.disabled = true
		elif not EconomyManager.can_afford(cost):
			action_btn.text = "НЕДОСТАТОЧНО СРЕДСТВ"
			action_btn.disabled = true
		else:
			action_btn.text = "НАНЯТЬ ЗА $" + str(cost)
			action_btn.disabled = false
			action_btn.modulate = Color.html("#4DFF80")
	
	_build_lists()

func _clear_detail() -> void:
	det_name.text = "Выберите специалиста"
	det_role.text = ""
	det_skill.text = ""
	det_contract.text = ""
	det_bonus.text = "Кликните на карточку слева для просмотра бонусов."
	action_btn.visible = false

func _get_bonus_description(role: int, skill: int) -> String:
	var pct = float(skill) / 100.0
	match role:
		0: return "• Опыт за тренировки: +%d%%\n• Доступ к расширенным тактикам" % (pct * 50)
		1: return "• Точность скаутов: +%d%%\n• Анализ силы соперников в реальном времени" % (pct * 50)
		2: return "• Восстановление настроя: +%d%%\n• Стабилизация игроков в тильте" % (pct * 50)
		3: return "• Выгода от спонсоров: +%d%%\n• Бонус при переговорах: -%d%%" % [(pct * 30), (pct * 20)]
		_: return ""

func _generate_market() -> void:
	available_staff = StaffManager.generate_available_staff(5)

func _on_refresh_pressed() -> void:
	if LeagueManager.current_match_day == 0: has_refreshed_at_start = true
	else: has_refreshed_at_mid = true
	# СБРОС ВЫБОРА ПРИ ОБНОВЛЕНИИ
	selected_staff = {}
	_generate_market()
	_update_ui()

func _on_action_pressed() -> void:
	if is_selected_hired:
		StaffManager.fire(selected_staff["id"])
	else:
		StaffManager.hire(selected_staff, 2)
		available_staff.erase(selected_staff)
	selected_staff = {}
	_update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
