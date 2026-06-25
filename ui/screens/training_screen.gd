# ============================================================================
# TRAINING SCREEN — Профессиональный интерфейс подготовки
# ============================================================================
extends Control

@onready var room_bonus_lbl: Label = $MainVBox/Header/RoomBonus
@onready var training_list: VBoxContainer = $MainVBox/ContentHBox/TypesPanel/TrainingList
@onready var player_list: VBoxContainer = $MainVBox/ContentHBox/RosterPanel/Scroll/PlayerList
@onready var preview_list: VBoxContainer = $MainVBox/ContentHBox/PreviewPanel/Margin/VBox/PreviewScroll/PreviewList
@onready var train_button: Button = $MainVBox/ContentHBox/PreviewPanel/Margin/VBox/TrainButton

var selected_type: String = ""
var selected_players: Array[String] = []

func _ready() -> void:
	_update_ui()

func _update_room_bonus() -> void:
	var bonus = (BaseManager.get_training_speed_bonus() + StaffManager.get_coach_training_bonus()) * 100
	room_bonus_lbl.text = "БОНУС БАЗЫ: +%d%%" % bonus

func _build_training_types() -> void:
	for child in training_list.get_children(): child.queue_free()
	var types = TrainingManager.get_training_types()
	
	for id in types.keys():
		var data = types[id]
		var is_team = data.get("affects_all", false)
		var btn := Button.new()
		btn.text = data["icon"] + " " + data["name"].to_upper()
		btn.custom_minimum_size = Vector2(0, 52)
		
		# Стилизация кнопок
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		if id == selected_type:
			style.bg_color = Color(0.2, 0.4, 0.6, 1) # Активный синий
			style.border_width_left = 4
			style.border_color = Color.GOLD
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0.15, 0.15, 0.2, 1)
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
		
		if is_team and not TrainingManager.can_train_team():
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.4)
			btn.text += " (КД)"
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		btn.pressed.connect(_on_type_selected.bind(id))
		training_list.add_child(btn)

func _build_player_list() -> void:
	for child in player_list.get_children(): child.queue_free()
	for p in RosterManager.get_roster():
		player_list.add_child(_create_player_row(p))

func _create_player_row(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var is_sel = data["id"] in selected_players
	var can_train = TrainingManager.can_train_player(data["id"])
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	if is_sel:
		style.bg_color = Color(0.1, 0.3, 0.4, 1)
		style.set_border_width_all(2)
		style.border_color = Color(0.4, 0.8, 1, 1)
	else:
		style.bg_color = Color(0.1, 0.12, 0.16, 1)
		style.set_border_width_all(1)
		style.border_color = Color(0.2, 0.25, 0.3, 1)
	
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 85
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	panel.add_child(margin)
	
	var hbox := HBoxContainer.new()
	margin.add_child(hbox)
	
	# Ник
	var name_lbl := Label.new()
	name_lbl.text = data["nickname"].to_upper()
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not can_train: name_lbl.modulate = Color(0.5, 0.5, 0.5, 1)
	hbox.add_child(name_lbl)
	
	# Инфо: Скилл и Потенциал
	var mid_vbox := VBoxContainer.new()
	mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mid_vbox)
	
	var role_lbl := Label.new()
	role_lbl.text = PlayerGenerator.get_role_display_name(data["role"])
	role_lbl.add_theme_color_override("font_color", Color.html("#80CCFF"))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_vbox.add_child(role_lbl)
	
	# ОВЕРРОЛЛ И ПОТЕНЦИАЛ
	var combat = data.get("combat_skills", {})
	var avg: float = 0.0
	for v in combat.values(): avg += float(v)
	avg = avg / float(maxi(combat.size(), 1))
	
	var stats_lbl := Label.new()
	stats_lbl.text = "Скилл: %d | Потенциал: %d" % [int(avg), data["potential"]]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color.html("#BBBBCC"))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_vbox.add_child(stats_lbl)
	
	# Статус
	var status_lbl := Label.new()
	status_lbl.custom_minimum_size.x = 100
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not can_train:
		status_lbl.text = "DONE"
		status_lbl.modulate = Color(0.5, 0.5, 0.5, 1)
	elif is_sel:
		status_lbl.text = "SELECTED"
		status_lbl.add_theme_color_override("font_color", Color.html("#4DFF80"))
	else:
		status_lbl.text = "READY"
	hbox.add_child(status_lbl)
	
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	if can_train:
		btn.pressed.connect(_on_player_toggled.bind(data["id"]))
	panel.add_child(btn)
	
	return panel

func _update_ui() -> void:
	_update_room_bonus()
	_build_training_types()
	_build_player_list()
	_update_preview()

func _update_preview() -> void:
	for child in preview_list.get_children(): child.queue_free()
	
	if selected_type == "":
		_add_preview_msg("ВЫБЕРИТЕ ПРОГРАММУ")
		train_button.disabled = true
		return
		
	var type_data = TrainingManager.get_training_type(selected_type)
	var is_team = type_data.get("affects_all", false)
	
	if is_team:
		for p in RosterManager.get_roster(): _add_growth_card(p)
		train_button.disabled = not TrainingManager.can_train_team()
		train_button.text = "НАЧАТЬ КОМАНДНУЮ СЕССИЮ"
	elif selected_players.is_empty():
		_add_preview_msg("ВЫБЕРИТЕ ИГРОКОВ")
		train_button.disabled = true
	else:
		for id in selected_players:
			var p = RosterManager.get_player_by_id(id)
			_add_growth_card(p)
		train_button.disabled = false
		train_button.text = "ТРЕНИРОВАТЬ (%d)" % selected_players.size()

func _add_growth_card(player: Dictionary) -> void:
	var preview = TrainingManager.preview_training(player, selected_type)
	
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.2, 1)
	style.border_width_left = 3
	style.border_color = Color.html("#4DFF80")
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)
	preview_list.add_child(card)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	var nick := Label.new()
	nick.text = player["nickname"].to_upper()
	nick.add_theme_font_size_override("font_size", 13)
	nick.add_theme_color_override("font_color", Color.html("#80CCFF"))
	vbox.add_child(nick)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	vbox.add_child(grid)
	
	for skill in preview.keys():
		var s_lbl := Label.new()
		s_lbl.text = skill.capitalize()
		s_lbl.add_theme_font_size_override("font_size", 11)
		s_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		grid.add_child(s_lbl)
		
		var val_lbl := Label.new()
		val_lbl.text = "»  +%.1f" % preview[skill]
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color.html("#4DFF80"))
		grid.add_child(val_lbl)

func _add_preview_msg(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Color(0.5, 0.5, 0.6, 1)
	preview_list.add_child(lbl)

func _on_type_selected(id: String) -> void:
	selected_type = id
	if TrainingManager.get_training_type(id).get("affects_all", false):
		selected_players.clear()
	_update_ui()

func _on_player_toggled(id: String) -> void:
	if id in selected_players:
		selected_players.erase(id)
	else:
		var type_data = TrainingManager.get_training_type(selected_type)
		if not type_data.get("affects_all", false):
			selected_players.append(id)
	_update_ui()

func _on_train_pressed() -> void:
	var type_data = TrainingManager.get_training_type(selected_type)
	if type_data.get("affects_all", false):
		TrainingManager.train_team(selected_type)
	else:
		for id in selected_players:
			var p = RosterManager.get_player_by_id(id)
			TrainingManager.train_player(p, selected_type)
	selected_players.clear()
	_update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")
