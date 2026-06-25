# ============================================================================
# MAJOR SCREEN — Экран Мажора (С поддержкой ручных матчей)
# ============================================================================
extends Control

@onready var phase_label: Label = $MainVBox/Header/PhaseLabel
@onready var player_status: Label = $MainVBox/Header/PlayerStatus
@onready var group_a_list: VBoxContainer = $MainVBox/ContentHBox/GroupAPanel/GroupAVBox/GroupAScroll/GroupAList
@onready var group_b_list: VBoxContainer = $MainVBox/ContentHBox/GroupBPanel/GroupBVBox/GroupBScroll/GroupBList
@onready var bracket_list: VBoxContainer = $MainVBox/ContentHBox/BracketPanel/BracketVBox/BracketScroll/BracketList
@onready var sim_groups_btn: Button = $MainVBox/Footer/SimulateGroupsButton
@onready var sim_playoff_btn: Button = $MainVBox/Footer/SimulatePlayoffButton
@onready var continue_btn: Button = $MainVBox/Footer/ContinueButton

func _ready() -> void:
	if not MajorManager.is_major_active:
		MajorManager.start_major()
	
	# Если мы вернулись сюда после победы/поражения в матче мажора
	if GameManager.last_match_result.has("major_match"):
		var res = GameManager.last_match_result
		_apply_manual_result(res)
		GameManager.last_match_result.erase("major_match")
		
	update_ui()

func update_ui() -> void:
	_update_header()
	_update_groups()
	_update_bracket()
	_update_buttons()

func _update_header() -> void:
	var phase = MajorManager.major_phase
	match phase:
		2: # GROUPS
			phase_label.text = "Групповой этап"
		3, 4, 5: # PLAYOFFS
			phase_label.text = "Плей-офф"
		6: # FINISHED
			phase_label.text = "Турнир завершён"
		_:
			phase_label.text = "Подготовка"
	
	if MajorManager.player_in_major:
		player_status.text = "✅ Ваша команда в игре!"
		player_status.add_theme_color_override("font_color", Color.html("#4DFF80"))
	else:
		player_status.text = "❌ Вы не квалифицировались"
		player_status.add_theme_color_override("font_color", Color.html("#FF6666"))

func _update_groups() -> void:
	for child in group_a_list.get_children(): child.queue_free()
	for child in group_b_list.get_children(): child.queue_free()
	
	var groups = MajorManager.get_group_stage_data()
	if groups.size() >= 2:
		_fill_group_list(group_a_list, groups[0])
		_fill_group_list(group_b_list, groups[1])

func _fill_group_list(container: VBoxContainer, group_data: Dictionary) -> void:
	var standings = group_data["standings"]
	for i in range(standings.size()):
		var s = standings[i]
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		
		# Цветовая индикация зоны выхода в плей-офф
		if i < 4: style.bg_color = Color(0.1, 0.25, 0.15)
		else: style.bg_color = Color(0.15, 0.15, 0.15)
		
		if s["team"].get("is_player", false):
			style.border_color = Color.GOLD
			style.set_border_width_all(2)
			
		panel.add_theme_stylebox_override("panel", style)
		var hbox := HBoxContainer.new()
		
		var name_lbl := Label.new()
		name_lbl.text = "%d. %s %s" % [i+1, s["team"].get("logo", ""), s["team"]["name"]]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var score_lbl := Label.new()
		score_lbl.text = "%d-%d (%d pts)" % [s["wins"], s["losses"], s["points"]]
		hbox.add_child(score_lbl)
		
		panel.add_child(hbox)
		container.add_child(panel)

func _update_bracket() -> void:
	for child in bracket_list.get_children(): child.queue_free()
	var bracket = MajorManager.get_playoff_bracket()
	
	if bracket.is_empty():
		var lbl := Label.new()
		lbl.text = "Сетка формируется..."
		bracket_list.add_child(lbl)
		return

	for m in bracket:
		var panel := PanelContainer.new()
		var vbox := VBoxContainer.new()
		
		var round_lbl := Label.new()
		round_lbl.text = m["round"].to_upper() + " (Bo" + str(m["bo"]) + ")"
		round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(round_lbl)
		
		var match_lbl := Label.new()
		var score = m["result"].get("score", "vs")
		match_lbl.text = "%s  %s  %s" % [m["team_a"]["name"], score, m["team_b"]["name"]]
		match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(match_lbl)
		
		panel.add_child(vbox)
		bracket_list.add_child(panel)

func _update_buttons() -> void:
	var phase = MajorManager.major_phase
	
	if MajorManager.player_in_major and _has_pending_player_match():
		sim_groups_btn.visible = true
		sim_groups_btn.text = "ИГРАТЬ МАТЧ"
		sim_groups_btn.modulate = Color.html("#4DFF80")
		
		sim_playoff_btn.visible = false
		continue_btn.visible = false
		return
		
	sim_groups_btn.text = "СИМУЛИРОВАТЬ ГРУППЫ"
	sim_groups_btn.modulate = Color.WHITE
	
	sim_groups_btn.visible = (phase == 2) # Phase.GROUPS
	sim_playoff_btn.visible = (phase >= 3 and phase <= 5) # QF to FINAL
	continue_btn.visible = (phase == 6) # Phase.FINISHED

func _has_pending_player_match() -> bool:
	if MajorManager.major_phase == 2:
		# Проверяем, есть ли несыгранные матчи в группе с игроком
		var groups = MajorManager.get_group_stage_data()
		for g in groups:
			if g["complete"]: continue
			var has_player = false
			var player_team = {}
			for t in g["teams"]:
				if t.get("is_player", false):
					has_player = true
					player_team = t
					break
			if has_player:
				var st = g["standings"]
				var p_wins = 0
				var p_losses = 0
				for s in st:
					if s["team"]["name"] == player_team["name"]:
						p_wins = s["wins"]
						p_losses = s["losses"]
				# Каждый должен сыграть со всеми (5 матчей)
				if (p_wins + p_losses) < 5:
					return true
	elif MajorManager.major_phase >= 3 and MajorManager.major_phase <= 5:
		var matches = MajorManager._get_current_round_matches()
		for m in matches:
			if not m["played"]:
				if m["team_a"].get("is_player", false) or m["team_b"].get("is_player", false):
					return true
	return false

func _on_simulate_groups_pressed() -> void:
	if MajorManager.player_in_major and _has_pending_player_match():
		_launch_player_match()
		return
		
	MajorManager.simulate_group_stage()
	update_ui()

func _on_simulate_playoff_pressed() -> void:
	if MajorManager.player_in_major and _has_pending_player_match():
		_launch_player_match()
		return
		
	MajorManager.simulate_playoff()
	update_ui()

func _launch_player_match() -> void:
	# Ищем оппонента
	var opponent = {}
	var bo3 = false
	var is_playoff = false
	
	if MajorManager.major_phase == 2:
		# Найти соперника в группе, с кем еще не играли
		var groups = MajorManager.get_group_stage_data()
		for g in groups:
			if g["complete"]: continue
			var p_team = {}
			for t in g["teams"]:
				if t.get("is_player", false): p_team = t
			if not p_team.is_empty():
				for t in g["teams"]:
					if t.get("is_player", false): continue
					# Проверить, играли ли мы уже (упрощенно - рандом из оставшихся)
					opponent = t
					break
	else:
		is_playoff = true
		var matches = MajorManager._get_current_round_matches()
		for m in matches:
			if not m["played"]:
				if m["team_a"].get("is_player", false):
					opponent = m["team_b"]
					bo3 = m["bo"] > 1
					break
				elif m["team_b"].get("is_player", false):
					opponent = m["team_a"]
					bo3 = m["bo"] > 1
					break
					
	if not opponent.is_empty():
		var pickban = preload("res://ui/screens/pick_ban_screen.tscn").instantiate()
		get_tree().root.add_child(pickban)
		var p_team = {"name": GameManager.player_team_data["name"], "id": "player"}
		pickban.setup(p_team, opponent, bo3)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = pickban

func _apply_manual_result(res: Dictionary) -> void:
	# Эта логика должна быть в MajorManager, мы вызываем специальный метод
	var winner = "a" if res["winner"] == "player" else "b"
	MajorManager.apply_manual_match_result(winner, res)

func _on_continue_pressed() -> void:
	GameManager.end_major(MajorManager.get_major_results())
	GameManager.go_to_next_season()
