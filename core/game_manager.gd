# ============================================================================
# GAME MANAGER — Стейт-машина игры
# ============================================================================
# Управляет глобальным состоянием игры.
# Состояния: MENU, SEASON, MATCH, MAJOR, RESULTS
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# ENUMS
# ----------------------------------------------------------------------------
enum GameState {
	NONE,
	MENU,
	SEASON,
	MATCH,
	MAJOR,
	RESULTS
}

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var current_state: GameState = GameState.NONE
var previous_state: GameState = GameState.NONE

# Данные текущей сессии
var current_season: int = 1
var current_match_day: int = 0
var is_major_active: bool = false

# Данные команды игрока (будут заполняться при старте/загрузке)
var player_team_data: Dictionary = {}
var last_match_result: Dictionary = {}
var season_results_data: Dictionary = {}


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_connect_signals()
	# Начинаем с меню
	change_state(GameState.MENU)


func _connect_signals() -> void:
	# Подписываемся на события от UI
	EventBus.screen_change_requested.connect(_on_screen_change_requested)
	EventBus.load_completed.connect(_on_load_completed)


# ----------------------------------------------------------------------------
# STATE MACHINE
# ----------------------------------------------------------------------------
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	previous_state = current_state
	var old_state_name := state_to_string(current_state)
	var new_state_name := state_to_string(new_state)
	
	# Выход из старого состояния
	_exit_state(current_state)
	
	# Вход в новое состояние
	current_state = new_state
	_enter_state(new_state)
	
	# Уведомляем все модули
	EventBus.game_state_changed.emit(old_state_name, new_state_name)
	EventBus.debug("State: " + old_state_name + " -> " + new_state_name, "GAME")


func _exit_state(state: GameState) -> void:
	match state:
		GameState.MENU:
			pass
		GameState.SEASON:
			pass
		GameState.MATCH:
			pass
		GameState.MAJOR:
			is_major_active = false
		GameState.RESULTS:
			pass


func _enter_state(state: GameState) -> void:
	match state:
		GameState.MENU:
			_on_enter_menu()
		GameState.SEASON:
			_on_enter_season()
		GameState.MATCH:
			_on_enter_match()
		GameState.MAJOR:
			_on_enter_major()
		GameState.RESULTS:
			_on_enter_results()


# ----------------------------------------------------------------------------
# STATE HANDLERS
# ----------------------------------------------------------------------------
func _on_enter_menu() -> void:
	EventBus.screen_change_requested.emit("main_menu")
	# Не меняем сцену здесь — она меняется из вызывающего кода


func _on_enter_season() -> void:
	# НЕ эмитим season_started здесь — это делается явно при start_next_season
	EventBus.screen_change_requested.emit("season")


func _on_enter_match() -> void:
	EventBus.screen_change_requested.emit("match")


func _on_enter_major() -> void:
	is_major_active = true
	EventBus.major_started.emit({
		"season": current_season
	})
	EventBus.screen_change_requested.emit("major")


func _on_enter_results() -> void:
	EventBus.screen_change_requested.emit("results")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func init_new_game() -> void:
	"""Инициализирует данные для новой игры (перед экраном создания команды)."""
	player_team_data = {
		"name": "",
		"logo_id": 0,
		"logo": "🎮",
		"league": "Open",
		"popularity": 0,
		"staff": [],
		"base_level": 1,
		"rooms": [],
		"transport": "minibus"
	}
	current_season = 1
	current_match_day = 0
	last_match_result = {}
	season_results_data = {}
	
	# Сбрасываем все модули
	EconomyManager.set_budget(EconomyManager.STARTING_BUDGET)
	EconomyManager.reset_for_new_season()
	RosterManager.clear_roster()
	AgentPool.clear_pool()
	Scouting.clear_scouting_data()
	LeagueManager.league_teams.clear()
	LeagueManager.schedule.clear()
	LeagueManager.standings.clear()
	LeagueManager.match_results.clear()
	LeagueManager.current_match_day = 0
	LeagueManager.season_finalized = false
	LeagueManager.season_summary = {}
	AIWorld.reset_world()
	MetaManager.set_random_meta()
	
	EventBus.debug("New game initialized (full reset)", "GAME")


func start_new_game(team_name: String, logo_id: int) -> void:
	"""Устаревший метод, используйте init_new_game + team_setup flow."""
	init_new_game()
	player_team_data["name"] = team_name
	player_team_data["logo_id"] = logo_id
	change_state(GameState.SEASON)


func continue_game() -> void:
	EventBus.load_requested.emit()


func end_season() -> void:
	EventBus.season_ended.emit(current_season, {})
	change_state(GameState.RESULTS)


func start_next_season() -> void:
	"""Запускает новый сезон."""
	# Старение игроков перед новым сезоном
	var roster = RosterManager.get_roster()
	if not roster.is_empty():
		AgingManager.process_end_of_season(roster)
	
	# Очищаем рынок свободных агентов ОТ СТАРОГО СЕЗОНА
	AgentPool.clear_pool()
	
	# ИИ-менеджмент: старение, увольнения, найм.
	# Уволенные ИИ игроки попадут уже в чистый пустой пул.
	AIMarket.process_all_teams_season_end()
	
	current_season += 1
	current_match_day = 0
	last_match_result = {}
	season_results_data = {}
	EconomyManager.reset_for_new_season()
	OffMatchEventManager.reset_season()
	SponsorManager.reset_season_rerolls()
	LeagueManager.init_league(player_team_data.get("league", "Open"))
	MetaManager.shift_meta()
	EventBus.season_started.emit(current_season)
	current_state = GameState.NONE
	change_state(GameState.SEASON)


func go_to_next_season() -> void:
	"""Безопасный переход к новому сезону: логика, потом патч-ноты."""
	start_next_season()
	get_tree().change_scene_to_file("res://ui/screens/patch_notes.tscn")


func _change_scene_safe(scene_path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene_path)


func start_match(match_data: Dictionary) -> void:
	last_match_result = match_data.duplicate() # Сохраняем флаги типа is_major
	EventBus.match_started.emit(match_data)
	change_state(GameState.MATCH)


func end_match(result: Dictionary) -> void:
	# Мержим результаты в last_match_result, чтобы не потерять флаг is_major
	for k in result.keys():
		last_match_result[k] = result[k]
	EventBus.match_ended.emit(result)
	current_match_day = LeagueManager.current_match_day
	change_state(GameState.SEASON)


func complete_season(results: Dictionary) -> void:
	"""Завершает сезон. Вызывающий код ДОЛЖЕН САМ менять сцену."""
	season_results_data = results.duplicate(true)
	current_state = GameState.NONE
	change_state(GameState.RESULTS)


func start_major() -> void:
	change_state(GameState.MAJOR)


func end_major(results: Dictionary) -> void:
	EventBus.major_ended.emit(results)
	change_state(GameState.RESULTS)


func return_to_menu() -> void:
	get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn")
	change_state(GameState.MENU)


func get_current_state_name() -> String:
	return state_to_string(current_state)


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_screen_change_requested(screen_name: String) -> void:
	# Логируем переход экрана
	EventBus.debug("Screen requested: " + screen_name, "UI")


func _on_load_completed(success: bool, data: Dictionary) -> void:
	if success and not data.is_empty():
		# Загружаем данные команды
		player_team_data = data.get("team", {})
		current_season = data.get("season", 1)
		current_match_day = data.get("match_day", 0)
		
		# Загружаем состав
		var roster_data: Dictionary = data.get("roster", {})
		RosterManager.from_dict(roster_data)
		
		# Загружаем экономику
		var economy_data: Dictionary = data.get("economy", {})
		EconomyManager.from_dict(economy_data)
		
		# Загружаем пул агентов
		var pool_data: Dictionary = data.get("agent_pool", {})
		AgentPool.from_dict(pool_data)
		
		# Загружаем данные скаутинга
		var scouting_data: Dictionary = data.get("scouting", {})
		Scouting.from_dict(scouting_data)
		
		# Загружаем лигу
		var league_data: Dictionary = data.get("league", {})
		if not league_data.is_empty():
			LeagueManager.from_dict(league_data)
		
		# Загружаем базу
		var base_data: Dictionary = data.get("base", {})
		if not base_data.is_empty():
			BaseManager.from_dict(base_data)
		
		# Загружаем тренировки
		var training_data: Dictionary = data.get("training", {})
		if not training_data.is_empty():
			TrainingManager.from_dict(training_data)
		
		# Загружаем aging
		var aging_data: Dictionary = data.get("aging", {})
		if not aging_data.is_empty():
			AgingManager.from_dict(aging_data)
		
		# Загружаем персонал
		var staff_data: Dictionary = data.get("staff", {})
		if not staff_data.is_empty():
			StaffManager.from_dict(staff_data)
		
		# Загружаем спонсоров
		var sponsor_data: Dictionary = data.get("sponsors", {})
		if not sponsor_data.is_empty():
			SponsorManager.from_dict(sponsor_data)
		
		# Загружаем мету
		var meta_data: Dictionary = data.get("meta", {})
		if not meta_data.is_empty():
			MetaManager.from_dict(meta_data)
		
		# Загружаем мажор
		var major_data: Dictionary = data.get("major", {})
		if not major_data.is_empty():
			MajorManager.from_dict(major_data)
		
		# Загружаем ивенты
		var event_mgr_data: Dictionary = data.get("offmatch_events", {})
		if not event_mgr_data.is_empty():
			OffMatchEventManager.from_dict(event_mgr_data)
		
		# Загружаем мировой ИИ
		var ai_world_data: Dictionary = data.get("ai_world", {})
		if not ai_world_data.is_empty():
			AIWorld.from_dict(ai_world_data)
		
		last_match_result = data.get("last_match_result", {})
		season_results_data = data.get("season_results", {})
		var saved_state: String = data.get("state", "SEASON")
		
		EventBus.debug("Game loaded: " + player_team_data.get("name", "?"), "SAVE")
		
		# Принудительно сбрасываем state чтобы change_state точно сработал
		current_state = GameState.NONE
		
		# Определяем куда перейти
		var target_scene: String
		
		if saved_state == "RESULTS" and not season_results_data.is_empty():
			change_state(GameState.RESULTS)
			target_scene = "res://ui/screens/season_results.tscn"
		elif LeagueManager.is_season_complete() and not LeagueManager.season_finalized:
			change_state(GameState.SEASON)
			target_scene = "res://ui/screens/league_table.tscn"
		else:
			change_state(GameState.SEASON)
			target_scene = "res://ui/screens/season_screen.tscn"
		
		EventBus.debug("Navigating to: " + target_scene, "SAVE")
		get_tree().call_deferred("change_scene_to_file", target_scene)
	else:
		EventBus.debug("No save found or load failed", "SAVE")


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
func state_to_string(state: GameState) -> String:
	match state:
		GameState.NONE:
			return "NONE"
		GameState.MENU:
			return "MENU"
		GameState.SEASON:
			return "SEASON"
		GameState.MATCH:
			return "MATCH"
		GameState.MAJOR:
			return "MAJOR"
		GameState.RESULTS:
			return "RESULTS"
		_:
			return "UNKNOWN"
