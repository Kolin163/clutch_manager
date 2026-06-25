# ============================================================================
# MATCH EVENT — Система ивентов матча
# ============================================================================
extends Node

var _events_data: Dictionary = {}
var _data_loaded: bool = false

func _ready() -> void:
	_load_events()
	EventBus.debug("MatchEvent ready", "MATCH")

func get_random_event(round_type: String, player_side: String) -> Dictionary:
	_ensure_loaded()
	var candidates: Array[Dictionary] = []
	var roster = RosterManager.get_roster()
	var roster_roles := _get_roster_roles(roster)
	
	for event in _events_data.get("events", []):
		var round_types: Array = event.get("round_types", [])
		if not round_type in round_types and not "normal" in round_types:
			continue
		
		var required_roles: Array = event.get("required_roles", [])
		var has_roles := true
		for role in required_roles:
			if not role in roster_roles:
				has_roles = false
				break
		if not has_roles:
			continue
		
		var trigger: String = event.get("trigger_condition", "")
		if not _check_trigger_condition(trigger):
			continue
		
		var probability: float = event.get("probability", 1.0)
		if probability < 1.0 and randf() > probability:
			continue
		
		candidates.append(event)
	
	if candidates.is_empty():
		return {}
	
	return candidates[randi() % candidates.size()]

func get_event_by_id(event_id: String) -> Dictionary:
	_ensure_loaded()
	for event in _events_data.get("events", []):
		if event.get("id", "") == event_id:
			return event
	return {}

func get_all_events() -> Array:
	_ensure_loaded()
	return _events_data.get("events", [])

func _check_trigger_condition(condition: String) -> bool:
	if condition.is_empty():
		return true
	
	var player_score: int = MatchEngine.player_score
	var enemy_score: int = MatchEngine.enemy_score
	
	match condition:
		"win_streak_3":
			return _check_win_streak(3)
		"lose_streak_3":
			return _check_lose_streak(3)
		"close_score":
			return abs(player_score - enemy_score) <= 2
		"match_point":
			return player_score == 12 or enemy_score == 12
		"behind":
			return player_score < enemy_score
		"ahead":
			return player_score > enemy_score
		_:
			return true

func _check_win_streak(count: int) -> bool:
	var history: Array = MatchEngine.round_history
	if history.size() < count:
		return false
	for i in range(count):
		var idx := history.size() - 1 - i
		if history[idx].get("winner", "") != "player":
			return false
	return true

func _check_lose_streak(count: int) -> bool:
	var history: Array = MatchEngine.round_history
	if history.size() < count:
		return false
	for i in range(count):
		var idx := history.size() - 1 - i
		if history[idx].get("winner", "") != "enemy":
			return false
	return true

func _find_choice(event: Dictionary, choice_id: String) -> Dictionary:
	for choice in event.get("choices", []):
		if choice.get("id", "") == choice_id:
			return choice
	return {}

func _get_roster_roles(roster: Array) -> Array[String]:
	var roles: Array[String] = []
	for player in roster:
		var role: String = player.get("role", "")
		if not role.is_empty() and not role in roles:
			roles.append(role)
	return roles

func _ensure_loaded() -> void:
	if not _data_loaded:
		_load_events()

func _load_events() -> void:
	var file := FileAccess.open("res://data/events/match_events.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK:
			_events_data = json.data
			_data_loaded = true
