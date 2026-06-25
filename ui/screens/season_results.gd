# ============================================================================
# SEASON RESULTS — Торжественные итоги сезона
# ============================================================================
extends Control

@onready var subtitle: Label = $CenterContainer/MainPanel/Header/Subtitle
@onready var place_lbl: Label = $CenterContainer/MainPanel/PlaceCard/PlaceLabel
@onready var place_card: PanelContainer = $CenterContainer/MainPanel/PlaceCard
@onready var win_val: Label = $CenterContainer/MainPanel/StatsGrid/WinVal
@onready var prize_val: Label = $CenterContainer/MainPanel/StatsGrid/PrizeVal
@onready var move_val: Label = $CenterContainer/MainPanel/StatsGrid/MoveVal
@onready var next_info: Label = $CenterContainer/MainPanel/NextSeasonInfo

func _ready() -> void:
	update_ui()

func update_ui() -> void:
	var summary = GameManager.season_results_data
	if summary.is_empty():
		summary = {
			"old_league": "Open", "new_league": "Rising", 
			"position": 1, "wins": 14, "losses": 0, "prize_money": 2000, 
			"movement": "promoted"
		}
	
	subtitle.text = "%s League — Сезон %d" % [summary["old_league"], GameManager.current_season]
	
	# МЕСТО И СТИЛЬ КАРТОЧКИ
	var pos = summary["position"]
	place_lbl.text = str(pos) + " МЕСТО"
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	
	if pos == 1:
		place_lbl.text = "🏆 " + place_lbl.text
		style.bg_color = Color(0.3, 0.25, 0.1, 1) # Золотистый
		style.border_color = Color.GOLD
	elif pos == 8:
		style.bg_color = Color(0.3, 0.1, 0.1, 1) # Красный (вылет)
		style.border_color = Color.html("#FF6666")
	else:
		style.bg_color = Color(0.15, 0.18, 0.25, 1) # Стандарт
		style.border_color = Color.html("#4D80CC")
		
	place_card.add_theme_stylebox_override("panel", style)
	
	# СТАТИСТИКА
	win_val.text = "%d - %d" % [summary.get("wins", 0), summary.get("losses", 0)]
	prize_val.text = "+$" + str(summary.get("prize_money", 0))
	
	match summary["movement"]:
		"promoted":
			move_val.text = "ПОВЫШЕНИЕ 🔺"
			move_val.add_theme_color_override("font_color", Color.html("#4DFF80"))
		"relegated":
			move_val.text = "ПОНИЖЕНИЕ 🔻"
			move_val.add_theme_color_override("font_color", Color.html("#FF6666"))
		_:
			move_val.text = "ЛИГА СОХРАНЕНА"
			move_val.add_theme_color_override("font_color", Color.WHITE)
			
	next_info.text = "Следующий этап: " + summary["new_league"] + " League"

func _on_menu_pressed(): get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn")

func _on_next_season_pressed():
	# Логика перехода к Мажору или новому сезону (как в прошлом фиксе)
	var league: String = GameManager.player_team_data.get("league", "Open")
	var position = LeagueManager.get_player_position()
	
	var qualifies_directly = (league == "Champions" and position <= 6) or (league == "Elite" and position <= 2)
	var can_try_major = qualifies_directly or league in ["Champions", "Elite", "Pro"]
	
	if can_try_major:
		get_tree().change_scene_to_file("res://ui/screens/major_screen.tscn")
	else:
		MajorManager.start_major()
		MajorManager.simulate_group_stage()
		MajorManager.simulate_playoff()
		GameManager.end_major(MajorManager.get_major_results())
		GameManager.start_next_season()
		get_tree().change_scene_to_file("res://ui/screens/patch_notes.tscn")
