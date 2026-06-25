# ============================================================================
# MATCH SCREEN — Экран матча
# ============================================================================

extends Control

const EventCardScene = preload("res://ui/components/event_card.tscn")

@onready var team_name: Label = $SafeArea/MainVBox/TopBar/TeamPanel/Margin/TeamHBox/TeamVBox/TeamName
@onready var player_logo: TextureRect = $SafeArea/MainVBox/TopBar/TeamPanel/Margin/TeamHBox/PlayerLogo
@onready var team_side: Label = $SafeArea/MainVBox/TopBar/TeamPanel/Margin/TeamHBox/TeamVBox/TeamSide

@onready var player_score_label: Label = $SafeArea/MainVBox/TopBar/ScorePanel/ScoreHBox/PlayerScore
@onready var enemy_score_label: Label = $SafeArea/MainVBox/TopBar/ScorePanel/ScoreHBox/EnemyScore

@onready var enemy_name: Label = $SafeArea/MainVBox/TopBar/EnemyPanel/Margin/EnemyHBox/EnemyVBox/EnemyName
@onready var enemy_logo: TextureRect = $SafeArea/MainVBox/TopBar/EnemyPanel/Margin/EnemyHBox/EnemyLogo
@onready var enemy_side: Label = $SafeArea/MainVBox/TopBar/EnemyPanel/Margin/EnemyHBox/EnemyVBox/EnemySide

@onready var map_label: Label = $SafeArea/MainVBox/InfoBar/MapLabel
@onready var round_label: Label = $SafeArea/MainVBox/InfoBar/RoundLabel
@onready var half_label: Label = $SafeArea/MainVBox/InfoBar/HalfLabel

@onready var tactics_container: VBoxContainer = $SafeArea/MainVBox/ContentHBox/LeftPanel/Margin/TacticsVBox/TacticsContainer
@onready var log_text: RichTextLabel = $SafeArea/MainVBox/ContentHBox/RightPanel/Margin/LogVBox/LogScroll/LogText

@onready var next_round_button: Button = $SafeArea/MainVBox/BottomBar/NextRoundButton
@onready var status_label: Label = $SafeArea/MainVBox/BottomBar/StatusLabel
@onready var skip_button: Button = $SafeArea/MainVBox/BottomBar/SkipButton

@onready var events_overlay: ColorRect = $EventsLayer/Overlay
@onready var event_container: CenterContainer = $EventsLayer/Overlay/EventCardContainer
@onready var result_overlay: ColorRect = $EventsLayer/ResultOverlay
@onready var result_title: Label = $EventsLayer/ResultOverlay/ResultVBox/ResultTitle
@onready var result_score: Label = $EventsLayer/ResultOverlay/ResultVBox/ResultScore

var _status_tween: Tween
var _final_result: Dictionary = {}

func _ready() -> void:
	_connect_signals()
	_init_ui()
	
	if MatchEngine.current_state != MatchEngine.MatchState.INIT:
		_on_match_started(MatchEngine.current_map, MatchEngine.enemy_team)
		if MatchEngine.current_state == MatchEngine.MatchState.TACTIC_SELECTION:
			_on_tactic_requested(MatchEngine.player_side)

func _connect_signals() -> void:
	MatchEngine.match_started.connect(_on_match_started)
	MatchEngine.tactic_requested.connect(_on_tactic_requested)
	MatchEngine.simulation_started.connect(_on_simulation_started)
	MatchEngine.event_triggered.connect(_on_event_triggered)
	MatchEngine.event_resolved.connect(_on_event_resolved)
	MatchEngine.round_ended.connect(_on_round_ended)
	MatchEngine.half_ended.connect(_on_half_ended)
	MatchEngine.match_ended.connect(_on_match_ended)

func _init_ui() -> void:
	events_overlay.hide()
	result_overlay.hide()
	log_text.text = "[font_size=13]"
	status_label.text = "Матч загружается..."
	next_round_button.disabled = true
	skip_button.disabled = true
	
	for child in tactics_container.get_children():
		child.queue_free()

func _log(msg: String) -> void:
	log_text.text += msg + "\n"

func _on_match_started(map_data: Dictionary, enemy_data: Dictionary) -> void:
	var td = GameManager.player_team_data
	team_name.text = td.get("name", "Моя Команда")
	
	var p_logo_path = td.get("logo", "res://icon.svg")
	if p_logo_path.begins_with("res://"):
		player_logo.texture = load(p_logo_path)
		
	enemy_name.text = enemy_data.get("name", "Противник")
	var e_logo_path = enemy_data.get("logo", "res://icon.svg")
	if e_logo_path.begins_with("res://"):
		enemy_logo.texture = load(e_logo_path)
		
	map_label.text = "Карта: " + map_data.get("name", "Unknown")
	
	player_score_label.text = "0"
	enemy_score_label.text = "0"
	half_label.text = "Тайм 1"
	
	_update_sides()
	MatchEngine.proceed_to_next_round()

func _update_sides() -> void:
	var is_atk = (MatchEngine.player_side == "attack")
	team_side.text = "Атака" if is_atk else "Защита"
	team_side.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4) if is_atk else Color(0.4, 0.6, 0.9))
	
	enemy_side.text = "Защита" if is_atk else "Атака"
	enemy_side.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9) if is_atk else Color(0.8, 0.4, 0.4))

func _on_tactic_requested(side: String) -> void:
	status_label.text = "ВЫБЕРИТЕ ТАКТИКУ НА РАУНД"
	round_label.text = "Раунд " + str(MatchEngine.current_round) + " / " + str(MatchEngine.ROUNDS_PER_HALF * 2)
	next_round_button.disabled = true
	skip_button.disabled = false
	
	if _status_tween:
		_status_tween.kill()
	_status_tween = create_tween().set_loops()
	status_label.add_theme_constant_override("outline_size", 0)
	status_label.add_theme_color_override("font_outline_color", Color(0.8, 0.8, 0.3, 1))
	_status_tween.tween_method(
		func(val: int): status_label.add_theme_constant_override("outline_size", val),
		0, 8, 0.6
	).set_trans(Tween.TRANS_SINE)
	_status_tween.tween_method(
		func(val: int): status_label.add_theme_constant_override("outline_size", val),
		8, 0, 0.6
	).set_trans(Tween.TRANS_SINE)
	
	for child in tactics_container.get_children():
		child.queue_free()
		
	var tactics = TacticSelector.get_tactics_for_side(side)
	if tactics.is_empty():
		tactics = [{"id": "default", "name_ru": "Дефолт"}]
		
	for t in tactics:
		var btn := Button.new()
		btn.text = t.get("name_ru", t.get("name", t.get("id", "ТАКТИКА")))
		btn.custom_minimum_size = Vector2(0, 45)
		btn.pressed.connect(func(): MatchEngine.confirm_tactic(t.get("id", "default")))
		tactics_container.add_child(btn)

func _on_simulation_started() -> void:
	if _status_tween:
		_status_tween.kill()
	status_label.add_theme_constant_override("outline_size", 0)
	status_label.text = "Идет симуляция раунда..."
	skip_button.disabled = true
	for btn in tactics_container.get_children():
		btn.disabled = true

func _on_event_triggered(event_data: Dictionary) -> void:
	status_label.text = "Ожидание решения..."
	for child in event_container.get_children():
		child.queue_free()
		
	var card = EventCardScene.instantiate()
	event_container.add_child(card)
	
	card.choice_made.connect(_on_choice_made.bind(card))
	card.timer_expired.connect(_on_timer_expired.bind(card))
	
	card.setup(event_data)
	events_overlay.show()
	_log("[color=orange]⚡ " + event_data.get("text", "Ситуация!") + "[/color]")

func _on_choice_made(choice_id: String, card: Node) -> void:
	events_overlay.hide()
	card.queue_free()
	MatchEngine.resolve_event(choice_id)

func _on_timer_expired(card: Node) -> void:
	events_overlay.hide()
	card.queue_free()
	_log("  [color=#FF6666]-> Время вышло! Штраф к силе.[/color]")
	MatchEngine.resolve_event("timeout")

func _on_event_resolved(success: bool) -> void:
	if success:
		_log("  [color=#4DFF80]-> Успешный исход! Команда получила бонус.[/color]")
	else:
		_log("  [color=#FF6666]-> Неудача. Команда потеряла преимущество.[/color]")

func _on_round_ended(round_num: int, winner: String, player_score: int, enemy_score: int) -> void:
	player_score_label.text = str(player_score)
	enemy_score_label.text = str(enemy_score)
	
	var t_name = TacticSelector.get_tactic_display_name(MatchEngine.player_tactic)
	_log("[color=#AAAAAA]Тактика: " + t_name + "[/color]")
	
	if winner == "player":
		_log("[color=#4DFF80]Раунд " + str(round_num) + " выигран![/color]")
	else:
		_log("[color=#FF6666]Раунд " + str(round_num) + " проигран.[/color]")
		
	_log("")
	status_label.text = "Раунд завершен."
	next_round_button.disabled = false
	next_round_button.grab_focus()

func _on_half_ended(half: int, player_score: int, enemy_score: int) -> void:
	_log("[color=yellow]=== СМЕНА СТОРОН ===[/color]")
	half_label.text = "Тайм 2"
	_update_sides()

func _on_match_ended(result: Dictionary) -> void:
	_final_result = result
	next_round_button.disabled = true
	skip_button.disabled = true
	
	var is_win = result["winner"] == "player"
	result_title.text = "ПОБЕДА!" if is_win else "ПОРАЖЕНИЕ"
	result_title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4) if is_win else Color(0.8, 0.3, 0.3))
	result_score.text = str(result["player_score"]) + " : " + str(result["enemy_score"])
	
	result_overlay.show()

func _on_next_round_pressed() -> void:
	MatchEngine.proceed_to_next_round()

func _on_skip_pressed() -> void:
	MatchEngine.confirm_tactic("default")

func _on_continue_pressed() -> void:
	GameManager.end_match(_final_result)
	get_tree().change_scene_to_file("res://ui/screens/between_match_flow.tscn")
