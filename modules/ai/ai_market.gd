# ============================================================================
# AI MARKET — Управление рынком ИИ-команд
# ============================================================================
# Обрабатывает найм/увольнение/старение для ВСЕХ ИИ-команд мира.
# Пополняет общий пул агентов уволенными и молодыми талантами.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const YOUNG_TALENTS_PER_SEASON := 5  # Новых молодых на рынке каждый сезон
const MAX_POOL_SIZE := 40  # Ограничение пула


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.debug("AIMarket ready", "AI")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func process_all_teams_season_end() -> Dictionary:
	"""Обрабатывает конец сезона для всех ИИ-команд мира.
	Возвращает отчёт: {fired: [], hired: [], aged_out: []}."""
	
	var report := {
		"fired": [],
		"hired": [],
		"aged_out": [],
		"teams_processed": 0
	}
	
	if not AIWorld.initialized:
		EventBus.debug("AIWorld not initialized, skipping AI market", "AI")
		return report
	
	# 1. Обрабатываем каждую лигу
	for league_name in AIWorld.LEAGUES:
		var state: Dictionary = AIWorld.world_leagues.get(league_name, {})
		if state.is_empty():
			continue
		
		var teams: Array = state.get("teams", [])
		var standings: Array = state.get("standings", [])
		
		for i in range(teams.size()):
			var team: Dictionary = teams[i]
			
			# Пропускаем команду игрока
			if team.get("is_player", false):
				continue
			
			# Обрабатываем конец сезона
			var result := AITeam.process_team_season_end(team, league_name)
			teams[i] = result
			
			# Уволенные идут в пул
			var fired: Array = result.get("fired", [])
			for player in fired:
				_add_to_pool(player)
				report["fired"].append({
					"player": player.get("nickname", "?"),
					"team": team.get("name", "?"),
					"league": league_name
				})
			
			# Пенсионеры
			var aged_out: Array = result.get("aged_out", [])
			for player in aged_out:
				report["aged_out"].append({
					"player": player.get("nickname", "?"),
					"age": player.get("age", 0),
					"team": team.get("name", "?")
				})
			
			# Убираем временные поля
			result.erase("fired")
			result.erase("aged_out")
			teams[i] = result
			
			report["teams_processed"] += 1
		
		state["teams"] = teams
		
		# Обновляем standings с новыми данными команд
		for j in range(standings.size()):
			var team_idx: int = standings[j].get("team_idx", -1)
			if team_idx >= 0 and team_idx < teams.size():
				standings[j]["team"] = teams[team_idx]
		
		state["standings"] = standings
		AIWorld.world_leagues[league_name] = state
	
	# 2. Добавляем молодых талантов
	_generate_young_talents()
	
	# 3. ИИ-команды нанимают из пула
	var hire_report := _process_hiring()
	report["hired"] = hire_report
	
	EventBus.debug("AI Market: fired " + str(report["fired"].size()) + ", hired " + str(report["hired"].size()) + ", aged out " + str(report["aged_out"].size()), "AI")
	
	return report


# ----------------------------------------------------------------------------
# HIRING
# ----------------------------------------------------------------------------
func _process_hiring() -> Array:
	"""ИИ-команды нанимают из общего пула."""
	var hired_report: Array = []
	var pool = AgentPool.get_pool()
	
	for league_name in AIWorld.LEAGUES:
		var state: Dictionary = AIWorld.world_leagues.get(league_name, {})
		if state.is_empty():
			continue
		
		var teams: Array = state.get("teams", [])
		
		for i in range(teams.size()):
			var team: Dictionary = teams[i]
			if team.get("is_player", false):
				continue
			
			var roster: Array = team.get("roster", [])
			if roster.size() >= 5:
				continue
			
			# Пытаемся нанять
			var result := AITeam.try_hire_from_pool(team, pool, league_name)
			teams[i] = result["updated_team"]
			
			var hired: Array = result.get("hired", [])
			for player in hired:
				# Убираем из пула
				_remove_from_pool(player.get("id", ""))
				hired_report.append({
					"player": player.get("nickname", "?"),
					"team": team.get("name", "?"),
					"league": league_name
				})
			
			# Подписываем контракты тем у кого нет
			teams[i] = AITeam.sign_contracts_for_expiring(teams[i])
		
		state["teams"] = teams
		AIWorld.world_leagues[league_name] = state
	
	return hired_report


# ----------------------------------------------------------------------------
# POOL MANAGEMENT
# ----------------------------------------------------------------------------
func _add_to_pool(player: Dictionary) -> void:
	"""Добавляет уволенного игрока в пул агентов."""
	var updated := player.duplicate(true)
	updated["contract"] = {"salary": updated.get("contract", {}).get("salary", 500), "seasons_left": 0}
	
	AgentPool.add_to_pool(updated)


func _remove_from_pool(player_id: String) -> void:
	AgentPool.remove_from_pool(player_id)


func _generate_young_talents() -> void:
	"""Генерирует молодых талантов в пул."""
	for _i in range(YOUNG_TALENTS_PER_SEASON):
		var talent := PlayerGenerator.generate_young_talent()
		AgentPool.add_to_pool(talent)
	
	# Ограничиваем размер пула
	_trim_pool()
	
	EventBus.debug("Added " + str(YOUNG_TALENTS_PER_SEASON) + " young talents to pool", "AI")


func _trim_pool() -> void:
	"""Убирает старых/слабых из пула если он слишком большой."""
	var pool = AgentPool.get_pool()
	
	if pool.size() <= MAX_POOL_SIZE:
		return
	
	# Сортируем: слабые и старые первые
	pool.sort_custom(func(a, b):
		var a_score := _pool_priority(a)
		var b_score := _pool_priority(b)
		return a_score < b_score
	)
	
	# Убираем лишних
	while pool.size() > MAX_POOL_SIZE:
		pool.pop_front()


func _pool_priority(player: Dictionary) -> float:
	"""Чем выше приоритет, тем дольше остаётся в пуле."""
	var age: int = player.get("age", 25)
	var combat: Dictionary = player.get("combat_skills", {})
	var avg := 0.0
	for v in combat.values():
		avg += float(v)
	if combat.size() > 0:
		avg /= float(combat.size())
	
	# Молодые + сильные = высокий приоритет
	var age_factor := maxf(0.0, 1.0 - float(age - 16) / 16.0)
	return avg + age_factor * 20.0
