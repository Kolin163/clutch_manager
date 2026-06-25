# ============================================================================
# LEAGUE TABLE — Улучшенная таблица (Высокие строки + Акцентная подсветка)
# ============================================================================
extends Control

@onready var league_selector: OptionButton = $SafeArea/MainVBox/Header/LeagueSelector
@onready var match_day_label: Label = $SafeArea/MainVBox/Header/MatchDayLabel
@onready var table_container: VBoxContainer = $SafeArea/MainVBox/TablePanel/VBox/Scroll/TableContainer
@onready var next_match_label: Label = $SafeArea/MainVBox/Footer/NextMatchLabel
@onready var simulate_button: Button = $SafeArea/MainVBox/Footer/SimulateDayButton
@onready var play_match_button: Button = $SafeArea/MainVBox/Footer/PlayMatchButton

var _selected_league: String = ""

func _ready() -> void:
	EventBus.league_table_updated.connect(_on_table_updated)
	_check_league_init()
	_build_league_selector()
	if _selected_league.is_empty():
		_selected_league = LeagueManager.current_league
	update_ui()

func _check_league_init() -> void:
	if not AIWorld.initialized:
		AIWorld.init_world(GameManager.player_team_data.get("league", "Open"))
	if LeagueManager.league_teams.is_empty():
		LeagueManager.init_league(GameManager.player_team_data.get("league", "Open"))

func _build_league_selector() -> void:
	league_selector.clear()
	var leagues = AIWorld.LEAGUES
	for i in range(leagues.size()):
		league_selector.add_item(leagues[i] + " League")
		if leagues[i] == LeagueManager.current_league:
			league_selector.select(i)
			_selected_league = leagues[i]

func update_ui() -> void:
	var is_p_league = (_selected_league == LeagueManager.current_league)
	var day = LeagueManager.current_match_day if is_p_league else AIWorld.get_league_match_day(_selected_league)
	match_day_label.text = "ТУР " + str(day) + " / 14"
	_update_table()
	_update_next_match()
	_update_buttons()

func _update_table() -> void:
	for child in table_container.get_children(): child.queue_free()
	var is_p_league = (_selected_league == LeagueManager.current_league)
	var standings = LeagueManager.get_standings() if is_p_league else AIWorld.get_league_standings(_selected_league)
	for i in range(standings.size()):
		table_container.add_child(_create_row(i + 1, standings[i]))

func _create_row(pos: int, data: Dictionary) -> PanelContainer:
	var team = data["team"]
	var is_player = team.get("is_player", false)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	
	# ЛОГИКА ПОДСВЕТКИ С УЧЕТОМ ПОЗИЦИИ ИГРОКА
	if pos == 1:
		if is_player:
			style.bg_color = Color(0.15, 0.45, 0.2, 1.0) # Ярко-зеленый для игрока-лидера
			style.set_border_width_all(2)
			style.border_color = Color.GOLD
		else:
			style.bg_color = Color(0.1, 0.25, 0.15, 0.8) # Стандартный зеленый для ИИ
	elif pos == 8:
		if is_player:
			style.bg_color = Color(0.5, 0.1, 0.1, 1.0) # Ярко-красный для игрока на дне
			style.set_border_width_all(2)
			style.border_color = Color("ff9999")
		else:
			style.bg_color = Color(0.25, 0.1, 0.1, 0.8) # Стандартный красный для ИИ
	elif is_player:
		style.bg_color = Color(0.2, 0.35, 0.5, 1.0) # Обычный синий для игрока
		style.border_width_left = 4
		style.border_color = Color("80ccff")
	else:
		style.bg_color = Color(1, 1, 1, 0.03) # Обычная строка
	
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.custom_minimum_size.y = 60
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)
	
	_add_lbl(hbox, str(pos), 60, true)
	
	var t_hbox := HBoxContainer.new()
	t_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_hbox.add_theme_constant_override("separation", 15)
	t_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_child(t_hbox)
	
	var logo_path = team.get("logo", "res://icon.svg")
	if logo_path.begins_with("res://"):
		var rect := TextureRect.new()
		rect.texture = load(logo_path)
		rect.custom_minimum_size = Vector2(32, 32)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t_hbox.add_child(rect)
	else:
		var l_icon := Label.new()
		l_icon.text = logo_path
		l_icon.add_theme_font_size_override("font_size", 24)
		t_hbox.add_child(l_icon)
		
	var name_lbl := Label.new()
	name_lbl.text = team["name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	if is_player: name_lbl.add_theme_color_override("font_color", Color("80ccff"))
	t_hbox.add_child(name_lbl)
	
	_add_lbl(hbox, str(data["played"]), 60)
	_add_lbl(hbox, str(data["wins"]), 60, false, Color("80ff80"))
	_add_lbl(hbox, str(data["losses"]), 60, false, Color("ff8080"))
	
	var diff = data.get("round_diff", 0)
	var diff_color = Color("4dff80") if diff > 0 else (Color("ff6666") if diff < 0 else Color.WHITE)
	_add_lbl(hbox, ("+" if diff > 0 else "") + str(diff), 80, false, diff_color)
	
	_add_lbl(hbox, str(data["points"]), 100, true, Color.GOLD)
	
	return panel

func _add_lbl(parent: HBoxContainer, text: String, width: int, bold: bool = false, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	if bold: l.add_theme_font_size_override("font_size", 20)
	else: l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)

func _update_next_match() -> void:
	if _selected_league != LeagueManager.current_league:
		next_match_label.text = "Просмотр другой лиги"
		return
	var next = LeagueManager.get_next_player_match()
	if next.is_empty(): next_match_label.text = "Сезон завершён"
	else: 
		var is_h = next["home_team"].get("id") == "player"
		var opp = next["away_team"] if is_h else next["home_team"]
		next_match_label.text = "СЛЕДУЮЩИЙ: vs %s" % opp["name"]

func _update_buttons() -> void:
	var is_p = (_selected_league == LeagueManager.current_league)
	var ready = RosterManager.is_complete()
	var complete = LeagueManager.is_season_complete()
	simulate_button.visible = is_p and not complete
	simulate_button.disabled = not ready
	play_match_button.visible = is_p
	play_match_button.text = "ИТОГИ СЕЗОНА" if complete else "ИГРАТЬ МАТЧ"

func _on_simulate_day_pressed() -> void:
	if LeagueManager.is_season_complete(): _go_to_results(); return
	var p_match = LeagueManager.get_next_player_match()
	if p_match.is_empty(): return
	
	if LeagueManager.current_match_day < p_match["match_day"]:
		LeagueManager.advance_match_day()
		AIWorld.simulate_world_match_day(LeagueManager.current_match_day)
		LeagueManager.simulate_ai_matches()
	
	var is_h = p_match["home_team"]["id"] == "player"
	var opp = p_match["away_team"] if is_h else p_match["home_team"]
	
	# Симулируем матч игрока вручную, чтобы LeagueManager корректно обработал его через сигнал
	var p_pow = float(RosterManager.get_team_overall()) + randf_range(-5, 5)
	var e_pow = opp.get("strength_val", 50.0) + randf_range(-5, 5)
	
	var p_wins = randf() < (p_pow / (p_pow + e_pow))
	var p_score = 13 if p_wins else randi_range(0, 11)
	var e_score = 13 if not p_wins else randi_range(0, 11)
	
	var formatted_res = {
		"winner": "player" if p_wins else "enemy",
		"player_score": p_score,
		"enemy_score": e_score,
		"opponent": opp
	}
	
	# Это вызовет event match_ended, обновит тренировки и таблицу лиги
	GameManager.end_match(formatted_res)
	
	# Начисляем финансы (в обычном флоу это делается на экране between_match_flow)
	EconomyManager.process_match_day_finances(LeagueManager.current_match_day)
	
	update_ui()

func _on_play_match_pressed() -> void:
	if LeagueManager.is_season_complete(): _go_to_results(); return
	var m = LeagueManager.get_next_player_match()
	if m.is_empty(): return
	if LeagueManager.current_match_day < m["match_day"]:
		LeagueManager.advance_match_day()
		AIWorld.simulate_world_match_day(LeagueManager.current_match_day)
		LeagueManager.simulate_ai_matches()
	var is_h = m["home_team"]["id"] == "player"
	var opponent = m["away_team"] if is_h else m["home_team"]
	GameManager.player_team_data["current_opponent"] = opponent
	
	# Получаем карту (заглушка, если нет)
	var map_data = MetaManager.get_random_active_map()
	
	# Инициализируем State Machine Матча ПЕРЕД переходом на экран
	MatchEngine.start_match(map_data, opponent)
	
	get_tree().change_scene_to_file("res://ui/screens/match_screen.tscn")

func _go_to_results() -> void:
	var s = LeagueManager.finalize_season()
	GameManager.season_results_data = s
	get_tree().change_scene_to_file("res://ui/screens/season_results.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/season_screen.tscn")

func _on_league_selected(i: int) -> void:
	_selected_league = AIWorld.LEAGUES[i]
	update_ui()

func _on_table_updated(_s: Array) -> void:
	update_ui()
