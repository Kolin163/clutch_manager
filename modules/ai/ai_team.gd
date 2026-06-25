# ============================================================================
# AI TEAM — Логика менеджмента одной ИИ-команды
# ============================================================================
# Найм, увольнение, бюджет, контракты.
# Используется AIMarket для обработки всех команд разом.
# ============================================================================

class_name AITeam
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const MIN_ROSTER_SIZE := 5
const CONTRACT_SEASONS_MIN := 1
const CONTRACT_SEASONS_MAX := 3

const BUDGET_BY_LEAGUE := {
	"Open": 12000,
	"Rising": 25000,
	"Pro": 50000,
	"Elite": 100000,
	"Champions": 200000
}

const SALARY_BUDGET_RATIO := 0.6  # Максимум 60% бюджета на зарплаты
const FIRE_SKILL_THRESHOLD := 0.6  # Увольняем если скилл < 60% от среднего команды
const HIRE_MIN_SKILL_RATIO := 0.8  # Нанимаем если скилл >= 80% от среднего

# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------

static func process_team_season_end(team: Dictionary, league_name: String) -> Dictionary:
	"""Обрабатывает конец сезона для ИИ-команды. Возвращает обновлённые данные."""
	var updated := team.duplicate(true)
	var roster: Array = updated.get("roster", [])
	var budget: int = updated.get("budget", BUDGET_BY_LEAGUE.get(league_name, 20000))
	
	# 1. Старение всех игроков
	var aged_out: Array = []
	for player in roster:
		player["age"] = player.get("age", 20) + 1
		
		# Спад скиллов для ветеранов
		if player["age"] >= 27:
			_apply_decline(player)
		
		# Мотивация падает
		if player["age"] >= 28:
			var mental: Dictionary = player.get("mental_skills", {})
			mental["motivation"] = maxi(mental.get("motivation", 50) - randi_range(1, 4), 10)
			player["mental_skills"] = mental
		
		# Уход на пенсию (33+)
		if player["age"] >= 33 and randf() < 0.5:
			aged_out.append(player)
	
	# 2. Убираем пенсионеров
	for old_player in aged_out:
		roster.erase(old_player)
	
	# 3. Контракты — уменьшаем
	var expired: Array = []
	for player in roster:
		var contract: Dictionary = player.get("contract", {})
		var left: int = contract.get("seasons_left", 0)
		if left > 0:
			left -= 1
			contract["seasons_left"] = left
			player["contract"] = contract
		
		if left <= 0:
			expired.append(player)
	
	# 4. Решаем кого уволить из expired
	var avg_skill := _get_avg_combat(roster)
	var fired: Array = []
	
	for player in expired:
		var player_skill := _get_player_combat_avg(player)
		# Увольняем слабых или с шансом если средние
		if player_skill < avg_skill * FIRE_SKILL_THRESHOLD or randf() < 0.3:
			fired.append(player)
	
	for player in fired:
		roster.erase(player)
	
	# 5. Обновляем бюджет
	var league_budget: int = BUDGET_BY_LEAGUE.get(league_name, 20000)
	budget = int(budget * 0.5) + int(league_budget * 0.5)  # Средняя между текущим и базовым
	
	updated["roster"] = roster
	updated["budget"] = budget
	updated["fired"] = fired
	updated["aged_out"] = aged_out
	updated["strength"] = _calc_strength(roster)
	
	return updated


static func try_hire_from_pool(team: Dictionary, pool: Array, league_name: String) -> Dictionary:
	"""Пытается нанять игроков из пула для заполнения состава. Возвращает {hired: [], updated_team: Dictionary}."""
	var roster: Array = team.get("roster", [])
	var budget: int = team.get("budget", 10000)
	var hired: Array = []
	
	if roster.size() >= MIN_ROSTER_SIZE:
		return {"hired": [], "updated_team": team}
	
	var needed := MIN_ROSTER_SIZE - roster.size()
	var max_salary := int(float(budget) * SALARY_BUDGET_RATIO / float(maxi(needed, 1)))
	
	# Собираем нужные роли
	var has_roles: Array = []
	for player in roster:
		has_roles.append(player.get("role", ""))
	
	var missing_roles: Array = []
	for role in ["entry", "awper", "support", "lurker", "igl"]:
		if not role in has_roles:
			missing_roles.append(role)
	
	# Ищем кандидатов
	var candidates := pool.duplicate()
	candidates.sort_custom(func(a, b):
		return _get_player_combat_avg(a) > _get_player_combat_avg(b)
	)
	
	for _i in range(needed):
		var best_candidate: Dictionary = {}
		var best_idx := -1
		
		for j in range(candidates.size()):
			var candidate: Dictionary = candidates[j]
			var contract: Dictionary = candidate.get("contract", {})
			var salary: int = contract.get("salary", 500)
			
			if salary > max_salary:
				continue
			
			# Приоритет: нужная роль
			var role: String = candidate.get("role", "")
			if not missing_roles.is_empty() and role in missing_roles:
				best_candidate = candidate
				best_idx = j
				break
			
			# Берём лучшего доступного
			if best_candidate.is_empty():
				best_candidate = candidate
				best_idx = j
		
		if best_idx >= 0:
			# Подписываем
			var new_player := best_candidate.duplicate(true)
			var contract: Dictionary = new_player.get("contract", {})
			contract["seasons_left"] = randi_range(CONTRACT_SEASONS_MIN, CONTRACT_SEASONS_MAX)
			new_player["contract"] = contract
			
			roster.append(new_player)
			hired.append(new_player)
			candidates.remove_at(best_idx)
			
			var role: String = new_player.get("role", "")
			missing_roles.erase(role)
			
			budget -= contract.get("salary", 500)
	
	var updated := team.duplicate(true)
	updated["roster"] = roster
	updated["budget"] = budget
	updated["strength"] = _calc_strength(roster)
	
	return {"hired": hired, "updated_team": updated}


static func sign_contracts_for_expiring(team: Dictionary) -> Dictionary:
	"""Продлевает контракты оставшимся игрокам без контракта."""
	var updated := team.duplicate(true)
	var roster: Array = updated.get("roster", [])
	
	for player in roster:
		var contract: Dictionary = player.get("contract", {})
		if contract.get("seasons_left", 0) <= 0:
			contract["seasons_left"] = randi_range(CONTRACT_SEASONS_MIN, CONTRACT_SEASONS_MAX)
			# Небольшой рост зарплаты
			var salary: int = contract.get("salary", 500)
			contract["salary"] = int(salary * randf_range(1.0, 1.2))
			player["contract"] = contract
	
	updated["roster"] = roster
	return updated


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
static func _apply_decline(player: Dictionary) -> void:
	var age: int = player.get("age", 20)
	var chance: float = 0.0
	if age == 27: chance = 0.15
	elif age == 28: chance = 0.25
	elif age == 29: chance = 0.40
	elif age == 30: chance = 0.55
	elif age >= 31: chance = 0.70
	
	var combat: Dictionary = player.get("combat_skills", {})
	for skill in combat.keys():
		if randf() < chance:
			combat[skill] = clampi(combat[skill] - randi_range(1, 3), 15, 100)
	player["combat_skills"] = combat


static func _get_player_combat_avg(player: Dictionary) -> float:
	var combat: Dictionary = player.get("combat_skills", {})
	if combat.is_empty():
		return 0.0
	var total := 0.0
	for v in combat.values():
		total += float(v)
	return total / float(combat.size())


static func _get_avg_combat(roster: Array) -> float:
	if roster.is_empty():
		return 50.0
	var total := 0.0
	for player in roster:
		total += _get_player_combat_avg(player)
	return total / float(roster.size())


static func _calc_strength(roster: Array) -> float:
	return _get_avg_combat(roster)
