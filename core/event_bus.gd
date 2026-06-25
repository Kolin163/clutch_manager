# ============================================================================
# EVENT BUS — Глобальная шина сигналов
# ============================================================================
# Все модули общаются через этот синглтон, не напрямую друг с другом.
# Подписка: EventBus.player_hired.connect(_on_player_hired)
# Вызов: EventBus.player_hired.emit(player_data)
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# GAME STATE
# ----------------------------------------------------------------------------
signal game_state_changed(old_state: String, new_state: String)
signal game_ready
signal game_paused
signal game_resumed

# ----------------------------------------------------------------------------
# SAVE / LOAD
# ----------------------------------------------------------------------------
signal save_requested
signal save_completed(success: bool)
signal load_requested
signal load_completed(success: bool, data: Dictionary)

# ----------------------------------------------------------------------------
# SEASON / LEAGUE
# ----------------------------------------------------------------------------
signal season_started(season_number: int)
signal season_ended(season_number: int, results: Dictionary)
signal match_day_started(day: int)
signal match_day_ended(day: int)
signal league_table_updated(table: Array)

# ----------------------------------------------------------------------------
# MATCH
# ----------------------------------------------------------------------------
signal match_started(match_data: Dictionary)
signal match_ended(result: Dictionary)
signal round_started(round_number: int)
signal round_ended(round_number: int, winner: String)
signal tactic_selected(tactic: String)
signal match_event_triggered(event_data: Dictionary)
signal match_event_resolved(event_id: String, choice: String, outcome: Dictionary)

# ----------------------------------------------------------------------------
# TEAM / ROSTER
# ----------------------------------------------------------------------------
signal player_hired(player_data: Dictionary)
signal player_fired(player_id: String)
signal player_stats_changed(player_id: String, stats: Dictionary)
signal roster_updated(roster: Array)
signal contract_expired(player_id: String)
signal contract_renewed(player_id: String, terms: Dictionary)

# ----------------------------------------------------------------------------
# STAFF
# ----------------------------------------------------------------------------
signal staff_hired(staff_data: Dictionary)
signal staff_fired(staff_id: String)

# ----------------------------------------------------------------------------
# TRAINING
# ----------------------------------------------------------------------------
signal training_started(player_id: String, skill: String)
signal training_completed(player_id: String, skill: String, gain: float)

# ----------------------------------------------------------------------------
# BASE
# ----------------------------------------------------------------------------
signal room_built(room_type: String)
signal room_upgraded(room_type: String, level: int)
signal base_upgraded(base_level: int)
signal transport_upgraded(transport_type: String)

# ----------------------------------------------------------------------------
# ECONOMY
# ----------------------------------------------------------------------------
signal money_changed(old_amount: int, new_amount: int)
signal income_received(source: String, amount: int)
signal expense_paid(reason: String, amount: int)
signal sponsor_signed(sponsor_data: Dictionary)
signal sponsor_expired(sponsor_id: String)

# ----------------------------------------------------------------------------
# MARKET
# ----------------------------------------------------------------------------
signal agent_pool_updated(agents: Array)
signal scouting_completed(player_id: String, revealed_stats: Dictionary)

# ----------------------------------------------------------------------------
# MAJOR
# ----------------------------------------------------------------------------
signal major_started(major_data: Dictionary)
signal major_ended(results: Dictionary)
signal pick_ban_started(opponent: String)
signal map_picked(team: String, map: String)
signal map_banned(team: String, map: String)

# ----------------------------------------------------------------------------
# EVENTS (игровые ивенты вне матча)
# ----------------------------------------------------------------------------
signal random_event_triggered(event_data: Dictionary)
signal random_event_resolved(event_id: String, choice: String, outcome: Dictionary)

# ----------------------------------------------------------------------------
# POPULARITY
# ----------------------------------------------------------------------------
signal popularity_changed(old_value: int, new_value: int)
signal viral_moment(player_id: String, boost: int)

# ----------------------------------------------------------------------------
# META
# ----------------------------------------------------------------------------
signal meta_shifted(changes: Dictionary)
signal patch_notes_available(notes: Array)

# ----------------------------------------------------------------------------
# UI
# ----------------------------------------------------------------------------
signal screen_change_requested(screen_name: String)
signal popup_requested(popup_type: String, data: Dictionary)
signal popup_closed(popup_type: String)
signal notification_requested(message: String, type: String)

# ----------------------------------------------------------------------------
# DEBUG (для веб-редактора, т.к. print не работает)
# ----------------------------------------------------------------------------
signal debug_message(message: String, category: String)


func _ready() -> void:
	# EventBus готов
	pass


# Хелпер для дебага — отправляет сообщение в UI
func debug(message: String, category: String = "INFO") -> void:
	debug_message.emit(message, category)
