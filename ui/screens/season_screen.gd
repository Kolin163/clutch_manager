# ============================================================================
# SEASON SCREEN — Главный хаб сезона (Исправлено лого)
# ============================================================================
extends Control

@onready var season_label: Label = $SafeArea/MainVBox/Header/TitleVBox/SeasonLabel
@onready var team_name_label: Label = $SafeArea/MainVBox/ContentHBox/LeftPanel/TeamCard/VBox/TeamName
@onready var team_logo_rect: TextureRect = $SafeArea/MainVBox/ContentHBox/LeftPanel/TeamCard/VBox/Logo
@onready var league_val: Label = $SafeArea/MainVBox/ContentHBox/LeftPanel/TeamCard/VBox/StatsGrid/LeagueVal
@onready var budget_val: Label = $SafeArea/MainVBox/ContentHBox/LeftPanel/TeamCard/VBox/StatsGrid/BudgetVal
@onready var power_val: Label = $SafeArea/MainVBox/ContentHBox/LeftPanel/TeamCard/VBox/StatsGrid/PowerVal
@onready var pop_val: Label = null # UI removed this node

func _ready() -> void:
	EventBus.money_changed.connect(func(_o, _n): _update_ui())
	_check_league_init()
	_update_ui()

func _check_league_init() -> void:
	if LeagueManager.league_teams.is_empty():
		LeagueManager.init_league(GameManager.player_team_data.get("league", "Open"))

func _update_ui() -> void:
	var td := GameManager.player_team_data
	
	season_label.text = "СЕЗОН %d | ТУР %d/14" % [GameManager.current_season, LeagueManager.current_match_day]
	
	team_name_label.text = td.get("name", "---").to_upper()
	
	# ПРОВЕРКА ЛОГО (Текст или Картинка)
	var logo_path = td.get("logo", "res://icon.svg")
	if logo_path.begins_with("res://"):
		team_logo_rect.texture = load(logo_path)
	
	var pos = LeagueManager.get_player_position()
	var pos_text := " (#" + str(pos) + ")" if pos > 0 else ""
	league_val.text = td.get("league", "Open") + pos_text
	
	budget_val.text = "$" + str(EconomyManager.get_budget())
	power_val.text = str(RosterManager.get_team_overall())
	if pop_val:
		pop_val.text = str(td.get("popularity", 0))

func _on_league_table_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/league_table.tscn")

func _on_training_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/training_screen.tscn")

func _on_roster_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/roster_screen.tscn")

func _on_base_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/base_screen.tscn")

func _on_staff_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/staff_screen.tscn")

func _on_sponsors_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/sponsor_screen.tscn")

func _on_save_pressed() -> void:
	EventBus.save_requested.emit()

func _on_back_pressed() -> void:
	GameManager.return_to_menu()
