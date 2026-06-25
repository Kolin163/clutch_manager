# ============================================================================
# MATCH SCOREBOARD — UI компонент табло матча
# ============================================================================
extends PanelContainer

@onready var location_label: Label = $MarginContainer/VBox/Header/Location
@onready var my_team_label: Label = $MarginContainer/VBox/TeamsHBox/MyTeam
@onready var score_label: Label = $MarginContainer/VBox/TeamsHBox/Score
@onready var enemy_team_label: Label = $MarginContainer/VBox/TeamsHBox/EnemyTeam
@onready var result_label: Label = $MarginContainer/VBox/ResultLabel

func set_match_data(result: Dictionary) -> void:
	var my_team := GameManager.player_team_data
	var opponent: Dictionary = result.get("enemy", {})
	var is_home: bool = result.get("is_home", true)
	
	var player_score: int = result.get("player_score", 0)
	var enemy_score: int = result.get("enemy_score", 0)
	var winner: String = result.get("winner", "enemy")
	var is_ot: bool = result.get("is_overtime", false)
	
	my_team_label.text = my_team.get("logo", "🎮") + " " + my_team.get("name", "My Team")
	enemy_team_label.text = opponent.get("logo", "🤖") + " " + opponent.get("name", "Enemy")
	
	var score_text := str(player_score) + " : " + str(enemy_score)
	if is_ot:
		score_text += " (OT)"
	score_label.text = score_text
	location_label.text = "Дома" if is_home else "На выезде"
	
	if winner == "player":
		result_label.text = "ПОБЕДА"
		result_label.add_theme_color_override("font_color", Color.html("#4DFF80"))
	else:
		result_label.text = "ПОРАЖЕНИЕ"
		result_label.add_theme_color_override("font_color", Color.html("#FF6666"))
