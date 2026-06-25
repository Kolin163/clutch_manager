# ============================================================================
# ROSTER SCREEN — Обновленное управление составом (Исправленная подсветка)
# ============================================================================
extends Control

@onready var budget_lbl: Label = $MainVBox/Header/Budget
@onready var roster_list: VBoxContainer = $MainVBox/ContentHBox/RightPanel/Scroll/RosterList
@onready var player_card = $MainVBox/ContentHBox/LeftPanel/PlayerCard
@onready var compare_btn: Button = $MainVBox/ButtonBar/CompareBtn

var selected_for_compare: Array[String] = []
var current_player_id: String = ""

func _ready() -> void:
	_update_ui()

func _update_ui() -> void:
	budget_lbl.text = "$" + str(EconomyManager.get_budget())
	
	var roster = RosterManager.get_roster()
	if not roster.is_empty() and current_player_id == "":
		current_player_id = roster[0]["id"]
	
	_build_list()
	
	if current_player_id != "":
		var data = RosterManager.get_player_by_id(current_player_id)
		if not data.is_empty():
			player_card.show_exact = true
			player_card.set_player_data(data)

func _build_list() -> void:
	for child in roster_list.get_children(): child.queue_free()
	
	# Добавляем заголовок таблицы
	_create_list_header()
	
	for p in RosterManager.get_roster():
		var row := _create_player_row(p)
		roster_list.add_child(row)

func _create_list_header() -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size.y = 24
	
	var cb_space := Control.new()
	cb_space.custom_minimum_size.x = 24
	hbox.add_child(cb_space)
	
	var name_lbl := Label.new()
	name_lbl.text = "ИМЯ ИГРОКА"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(name_lbl)
	
	var role_lbl := Label.new()
	role_lbl.text = "РОЛЬ"
	role_lbl.custom_minimum_size.x = 100
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(role_lbl)
	
	var skill_lbl := Label.new()
	skill_lbl.text = "СКИЛ"
	skill_lbl.custom_minimum_size.x = 40
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_lbl.add_theme_font_size_override("font_size", 11)
	skill_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(skill_lbl)
	
	var pot_lbl := Label.new()
	pot_lbl.text = "ПОТ"
	pot_lbl.custom_minimum_size.x = 40
	pot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_lbl.add_theme_font_size_override("font_size", 11)
	pot_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(pot_lbl)
	
	var m_lbl := Label.new()
	m_lbl.text = "МОРАЛЬ"
	m_lbl.custom_minimum_size.x = 80
	m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_lbl.add_theme_font_size_override("font_size", 11)
	m_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(m_lbl)
	
	var f_lbl := Label.new()
	f_lbl.text = "УСТАЛ"
	f_lbl.custom_minimum_size.x = 80
	f_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f_lbl.add_theme_font_size_override("font_size", 11)
	f_lbl.modulate = Color(0.6, 0.6, 0.7, 1)
	hbox.add_child(f_lbl)
	
	roster_list.add_child(hbox)
	
	var sep := HSeparator.new()
	roster_list.add_child(sep)

func _create_player_row(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var is_current = data["id"] == current_player_id
	
	if is_current:
		style.bg_color = Color(0.2, 0.3, 0.4, 1)
		style.border_color = Color(0.5, 0.8, 1, 1)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.1, 0.12, 0.15, 1)
		style.border_color = Color(0.2, 0.2, 0.2, 1)
		style.set_border_width_all(1)
		
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	
	var check := CheckBox.new()
	check.button_pressed = data["id"] in selected_for_compare
	check.toggled.connect(_on_compare_toggled.bind(data["id"]))
	hbox.add_child(check)
	
	var btn := Button.new()
	btn.text = data["nickname"]
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_player_selected.bind(data["id"]))
	hbox.add_child(btn)
	
	var role := Label.new()
	role.text = PlayerGenerator.get_role_display_name(data["role"])
	role.custom_minimum_size = Vector2(100, 0)
	role.add_theme_font_size_override("font_size", 12)
	hbox.add_child(role)
	
	# Добавляем Скилл
	var combat = data.get("combat_skills", {})
	var avg: float = 0.0
	for v in combat.values(): avg += float(v)
	avg = avg / float(maxi(combat.size(), 1))
	
	var skill_lbl := Label.new()
	skill_lbl.text = str(int(avg))
	skill_lbl.custom_minimum_size = Vector2(40, 0)
	skill_lbl.add_theme_font_size_override("font_size", 14)
	skill_lbl.add_theme_color_override("font_color", Color("4DFF80") if avg >= 70 else (Color("FFFF80") if avg >= 50 else Color("FF6666")))
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(skill_lbl)
	
	# Добавляем Потенциал
	var pot_lbl := Label.new()
	pot_lbl.text = str(data.get("potential", 0))
	pot_lbl.custom_minimum_size = Vector2(40, 0)
	pot_lbl.add_theme_font_size_override("font_size", 12)
	pot_lbl.add_theme_color_override("font_color", Color("BBBBCC"))
	pot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(pot_lbl)
	
	var m_bar := ProgressBar.new()
	m_bar.custom_minimum_size = Vector2(80, 10)
	m_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m_bar.show_percentage = false
	m_bar.value = data.get("morale", 75)
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color.html("#4DFF80")
	m_bar.add_theme_stylebox_override("fill", m_style)
	hbox.add_child(m_bar)
	
	var f_bar := ProgressBar.new()
	f_bar.custom_minimum_size = Vector2(80, 10)
	f_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f_bar.show_percentage = false
	f_bar.value = data.get("fatigue", 0)
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color.html("#FF6666")
	f_bar.add_theme_stylebox_override("fill", f_style)
	hbox.add_child(f_bar)
	
	return panel

func _on_player_selected(id: String) -> void:
	current_player_id = id
	_update_ui() # Перерисовываем всё для обновления подсветки

func _on_compare_toggled(pressed: bool, id: String) -> void:
	if pressed:
		if selected_for_compare.size() < 2:
			selected_for_compare.append(id)
	else:
		selected_for_compare.erase(id)
	
	compare_btn.disabled = selected_for_compare.size() != 2
	compare_btn.text = "СРАВНИТЬ (" + str(selected_for_compare.size()) + "/2)"
	if selected_for_compare.size() == 2:
		compare_btn.add_theme_color_override("font_color", Color.html("#FFFF80"))
	else:
		compare_btn.remove_theme_color_override("font_color")

func _on_compare_pressed() -> void:
	if selected_for_compare.size() == 2:
		var p1 = RosterManager.get_player_by_id(selected_for_compare[0])
		var p2 = RosterManager.get_player_by_id(selected_for_compare[1])
		
		var comp_scene = load("res://ui/screens/compare_screen.tscn")
		var comp_instance = comp_scene.instantiate()
		
		# Добавляем на текущую сцену, чтобы не потерять контекст
		add_child(comp_instance)
		comp_instance.setup(p1, p2)

func _on_market_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/market_screen.tscn")

func _on_fire_pressed() -> void:
	if current_player_id != "":
		RosterManager.remove_player(current_player_id)
		current_player_id = ""
		_update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
