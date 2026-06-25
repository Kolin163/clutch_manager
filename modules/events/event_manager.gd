# ============================================================================
# EVENT MANAGER — Триггер ивентов между матчами
# ============================================================================
# Выбирает подходящий ивент, проверяет условия, передаёт в event_resolver.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

var _events_data: Array = []
var _data_loaded: bool = false
var _events_this_season: int = 0
var last_event: Dictionary = {}

const MAX_EVENTS_PER_SEASON := 6


func _ready() -> void:
	_load_events()
	EventBus.debug("EventManager ready", "EVENT")


func reset_season() -> void:
	_events_this_season = 0
	last_event = {}


func try_trigger_event() -> Dictionary:
	"""Пытается вызвать ивент. Возвращает ивент или пустой Dictionary."""
	_ensure_loaded()
	
	if _events_this_season >= MAX_EVENTS_PER_SEASON:
		return {}
	
	# Базовый шанс ~40% что вообще будет ивент
	if randf() > 0.4:
		return {}
	
	var candidates: Array = []
	for event in _events_data:
		var trigger: String = event.get("trigger", "any")
		if not _check_trigger(trigger):
			continue
		
		var prob: float = event.get("probability", 0.1)
		if randf() < prob:
			candidates.append(event)
	
	if candidates.is_empty():
		return {}
	
	var chosen: Dictionary = candidates[randi() % candidates.size()].duplicate(true)
	last_event = chosen
	_events_this_season += 1
	
	EventBus.random_event_triggered.emit(chosen)
	EventBus.debug("Event triggered: " + chosen.get("id", "?"), "EVENT")
	return chosen


func _check_trigger(trigger: String) -> bool:
	match trigger:
		"any":
			return true
		"roster_full":
			return RosterManager.get_roster_size() >= 5
		"has_server_room":
			return BaseManager.get_room("server_room") != null and BaseManager.get_room("server_room").is_built
		"has_stream_room":
			return BaseManager.get_room("stream_room") != null and BaseManager.get_room("stream_room").is_built
		"has_analyst":
			return StaffManager.has_analyst()
		"popularity_above_20":
			return GameManager.player_team_data.get("popularity", 0) >= 20
		"win_streak_2":
			return AgingManager.current_lose_streak <= -2  # Отрицательный = серия побед (упрощённо)
		"lose_streak_2":
			return AgingManager.current_lose_streak >= 2
		"league_top_3":
			return LeagueManager.get_player_position() <= 3 and LeagueManager.get_player_position() > 0
		_:
			return true


func _ensure_loaded() -> void:
	if not _data_loaded:
		_load_events()


func _load_events() -> void:
	var file := FileAccess.open("res://data/events/offmatch_events.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_events_data = json.data.get("events", [])
			_data_loaded = true
		file.close()
	else:
		EventBus.debug("Failed to load offmatch_events.json", "ERROR")


func to_dict() -> Dictionary:
	return {"events_this_season": _events_this_season}

func from_dict(data: Dictionary) -> void:
	_events_this_season = data.get("events_this_season", 0)
