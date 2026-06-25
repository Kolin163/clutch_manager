# ============================================================================
# PICK/BAN SCREEN — Экран выбора карт для Мажора
# ============================================================================
extends Control

@onready var match_title: Label = $SafeArea/MainVBox/Header/MatchTitle
@onready var matchup_label: Label = $SafeArea/MainVBox/Header/MatchupLabel
@onready var current_action_label: Label = $SafeArea/MainVBox/Header/CurrentAction
@onready var maps_grid: GridContainer = $SafeArea/MainVBox/MapsGrid
@onready var start_btn: Button = $SafeArea/MainVBox/Footer/StartMatchBtn

var team_a: Dictionary = {}
var team_b: Dictionary = {}
var is_bo3: bool = false

var available_maps: Array[Dictionary] = []
var banned_maps: Array[String] = []
var picked_maps: Array[Dictionary] = []

var turn_sequence: Array[String] = [] # "ban_a", "ban_b", "pick_a", "pick_b", ...
var current_turn_idx: int = 0
var is_player_turn: bool = false
var player_is_a: bool = false

func _ready() -> void:
	start_btn.visible = false
	_load_maps()
	# TODO: Setup Match (from MatchEngine or MajorManager)

func setup(t_a: Dictionary, t_b: Dictionary, bo3: bool) -> void:
	team_a = t_a
	team_b = t_b
	is_bo3 = bo3
	player_is_a = t_a.get("id") == "player"
	
	matchup_label.text = "%s vs %s" % [t_a.get("name", "A"), t_b.get("name", "B")]
	match_title.text = "МАТЧ МАЖОРА (Bo3)" if bo3 else "МАТЧ МАЖОРА (Bo1)"
	
	if bo3:
		turn_sequence = ["ban_a", "ban_b", "pick_a", "pick_b", "ban_a", "ban_b", "pick_decider"]
	else:
		turn_sequence = ["ban_a", "ban_b", "ban_a", "ban_b", "ban_a", "ban_b", "pick_decider"]
		
	current_turn_idx = 0
	_process_turn()
	_update_grid()

func _load_maps() -> void:
	var file = FileAccess.open("res://data/maps/maps.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var all_maps = json.data.get("maps", [])
			available_maps = all_maps.slice(0, 7) # Active duty pool (7 maps)
		file.close()

func _process_turn() -> void:
	if current_turn_idx >= turn_sequence.size():
		_finish_draft()
		return
		
	var turn = turn_sequence[current_turn_idx]
	var team_turn_is_a = turn.ends_with("_a")
	var is_ban = turn.begins_with("ban")
	
	is_player_turn = (team_turn_is_a and player_is_a) or (not team_turn_is_a and not player_is_a)
	
	if turn == "pick_decider":
		is_player_turn = false # Автоматический пик последней карты
		var last_map = _get_last_available_map()
		if not last_map.is_empty():
			picked_maps.append(last_map)
		_finish_draft()
		return

	var current_team_name = team_a["name"] if team_turn_is_a else team_b["name"]
	var action_text = "ЗАБАНИТЬ" if is_ban else "ПИКНУТЬ"
	var color = "#FF6666" if is_ban else "#4DFF80"
	
	if is_player_turn:
		current_action_label.text = "ВАШ ХОД: [color=%s]%s[/color] карту" % [color, action_text]
	else:
		current_action_label.text = "Ход ИИ (%s): %s карту..." % [current_team_name, action_text]
		
	current_action_label.text = current_action_label.text.replace("[color=", "").replace("[/color]", "") # RichText fallback
	
	if not is_player_turn:
		get_tree().create_timer(1.0).timeout.connect(_ai_make_move.bind(is_ban))

func _get_last_available_map() -> Dictionary:
	for m in available_maps:
		if m["id"] not in banned_maps and not _is_picked(m["id"]):
			return m
	return available_maps[0]

func _update_grid() -> void:
	for child in maps_grid.get_children(): child.queue_free()
	
	for m in available_maps:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(150, 100)
		btn.text = m["name"].to_upper()
		
		var is_banned = m["id"] in banned_maps
		var is_picked = _is_picked(m["id"])
		
		if is_banned:
			btn.disabled = true
			btn.modulate = Color(1, 0.4, 0.4, 0.5)
			btn.text += "\n(BANNED)"
		elif is_picked:
			btn.disabled = true
			btn.modulate = Color(0.4, 1, 0.4, 1.0)
			btn.text += "\n(PICKED)"
		else:
			btn.disabled = not is_player_turn
			btn.pressed.connect(_on_map_clicked.bind(m))
			
		maps_grid.add_child(btn)

func _is_picked(map_id: String) -> bool:
	for p in picked_maps:
		if p["id"] == map_id: return true
	return false

func _on_map_clicked(map_data: Dictionary) -> void:
	if not is_player_turn: return
	
	var is_ban = turn_sequence[current_turn_idx].begins_with("ban")
	if is_ban:
		banned_maps.append(map_data["id"])
	else:
		picked_maps.append(map_data)
		
	current_turn_idx += 1
	_process_turn()
	_update_grid()

func _ai_make_move(is_ban: bool) -> void:
	var valid_maps = []
	for m in available_maps:
		if m["id"] not in banned_maps and not _is_picked(m["id"]):
			valid_maps.append(m)
			
	if valid_maps.is_empty(): return
	
	var chosen = valid_maps[randi() % valid_maps.size()] # TODO: Умный пик
	
	if is_ban: banned_maps.append(chosen["id"])
	else: picked_maps.append(chosen)
	
	current_turn_idx += 1
	_process_turn()
	_update_grid()

func _finish_draft() -> void:
	current_action_label.text = "ВЫБОР КАРТ ЗАВЕРШЕН!"
	current_action_label.add_theme_color_override("font_color", Color.GOLD)
	is_player_turn = false
	_update_grid()
	
	start_btn.visible = true
	start_btn.text = "ИГРАТЬ: " + picked_maps[0]["name"].to_upper()
	start_btn.grab_focus()

func _on_start_match_pressed() -> void:
	# Назначаем карту и стартуем
	var map_data = picked_maps[0]
	var opponent = team_b if player_is_a else team_a
	GameManager.player_team_data["current_opponent"] = opponent
	
	GameManager.start_match({"map": map_data, "opponent": opponent, "is_major": true})
	MatchEngine.start_match(map_data, opponent)
	
	get_tree().change_scene_to_file("res://ui/screens/match_screen.tscn")
