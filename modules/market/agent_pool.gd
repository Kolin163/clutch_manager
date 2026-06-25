# ============================================================================
# AGENT POOL — Пул свободных агентов
# ============================================================================
# Генерирует и хранит пул доступных для найма игроков.
# Обновляется каждый сезон.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const POOL_SIZE_MIN := 15
const POOL_SIZE_MAX := 20
const STARTING_POOL_SIZE := 12  # Для стартового выбора (слабые)

# Параметры для стартового пула (слабые игроки)
const STARTING_POOL_PARAMS := {
	"age_min": 17,
	"age_max": 24,
	"potential_min": 35,
	"potential_max": 65,
	"skill_penalty": 15  # Вычитаем из скиллов
}

# Параметры для обычного пула
const REGULAR_POOL_PARAMS := {
	"age_min": 16,
	"age_max": 30,
	"potential_min": 30,
	"potential_max": 90
}

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var agent_pool: Array[Dictionary] = []


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.season_started.connect(_on_season_started)
	EventBus.debug("AgentPool ready", "MARKET")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_pool() -> Array[Dictionary]:
	return agent_pool


func get_pool_size() -> int:
	return agent_pool.size()


func get_agent_by_id(player_id: String) -> Dictionary:
	for agent in agent_pool:
		if agent.get("id", "") == player_id:
			return agent
	return {}


func remove_from_pool(player_id: String) -> bool:
	"""Убирает игрока из пула (после найма)."""
	for i in range(agent_pool.size()):
		if agent_pool[i].get("id", "") == player_id:
			agent_pool.remove_at(i)
			EventBus.agent_pool_updated.emit(agent_pool)
			EventBus.debug("Removed from pool: " + player_id, "MARKET")
			return true
	return false


func add_to_pool(player_data: Dictionary) -> void:
	"""Добавляет игрока в пул (уволенные)."""
	# Сбрасываем контракт
	var updated := player_data.duplicate(true)
	updated["contract"] = {"salary": 0, "seasons_left": 0}
	
	agent_pool.append(updated)
	EventBus.agent_pool_updated.emit(agent_pool)
	EventBus.debug("Added to pool: " + updated.get("nickname", "?"), "MARKET")


func clear_pool() -> void:
	agent_pool.clear()
	EventBus.agent_pool_updated.emit(agent_pool)


# ----------------------------------------------------------------------------
# GENERATION
# ----------------------------------------------------------------------------
func generate_starting_pool() -> Array[Dictionary]:
	"""Генерирует стартовый пул слабых агентов для выбора команды."""
	clear_pool()
	
	var params := STARTING_POOL_PARAMS
	
	for i in range(STARTING_POOL_SIZE):
		var player := _generate_weak_player(params)
		agent_pool.append(player)
	
	# Убеждаемся что есть все роли
	_ensure_all_roles_present()
	
	EventBus.agent_pool_updated.emit(agent_pool)
	EventBus.debug("Starting pool generated: " + str(agent_pool.size()) + " agents", "MARKET")
	
	return agent_pool


func generate_season_pool() -> Array[Dictionary]:
	"""Генерирует обычный пул на новый сезон. ДОБАВЛЯЕТ к пулу, не очищая его."""
	# Очистка уже произошла в GameManager.start_next_season() ДО того как ИИ уволил своих.
	
	var pool_size := randi_range(POOL_SIZE_MIN, POOL_SIZE_MAX)
	var params := REGULAR_POOL_PARAMS
	
	for i in range(pool_size):
		var age := randi_range(params["age_min"], params["age_max"])
		var potential := randi_range(params["potential_min"], params["potential_max"])
		
		var player := PlayerGenerator.generate_player({
			"age": age,
			"potential": potential
		})
		
		agent_pool.append(player)
	
	# Добавляем несколько молодых талантов
	for i in range(randi_range(1, 3)):
		var talent := PlayerGenerator.generate_young_talent()
		agent_pool.append(talent)
	
	EventBus.agent_pool_updated.emit(agent_pool)
	EventBus.debug("Season pool generated: " + str(agent_pool.size()) + " agents", "MARKET")
	
	return agent_pool


func _generate_weak_player(params: Dictionary) -> Dictionary:
	"""Генерирует слабого игрока для стартового пула."""
	var age := randi_range(params["age_min"], params["age_max"])
	var potential := randi_range(params["potential_min"], params["potential_max"])
	
	var player := PlayerGenerator.generate_player({
		"age": age,
		"potential": potential
	})
	
	# Понижаем скиллы
	var penalty: int = params.get("skill_penalty", 10)
	var combat: Dictionary = player.get("combat_skills", {})
	for skill in combat.keys():
		combat[skill] = maxi(15, combat[skill] - penalty)
	player["combat_skills"] = combat
	
	# Уменьшаем зарплату
	var contract: Dictionary = player.get("contract", {})
	contract["salary"] = maxi(300, contract.get("salary", 500) - 200)
	player["contract"] = contract
	
	return player


func _ensure_all_roles_present() -> void:
	"""Убеждается что в пуле есть минимум по 1 игроку каждой роли."""
	var roles_present: Dictionary = {}
	
	for agent in agent_pool:
		var role: String = agent.get("role", "")
		roles_present[role] = true
	
	var missing_roles: Array[String] = []
	for role in ["entry", "awper", "support", "lurker", "igl"]:
		if not roles_present.has(role):
			missing_roles.append(role)
	
	# Добавляем недостающие роли
	for role in missing_roles:
		var player := _generate_weak_player(STARTING_POOL_PARAMS)
		player["role"] = role
		agent_pool.append(player)


# ----------------------------------------------------------------------------
# FILTERING
# ----------------------------------------------------------------------------
func get_agents_by_role(role: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for agent in agent_pool:
		if agent.get("role", "") == role:
			result.append(agent)
	return result


func get_agents_by_age_range(min_age: int, max_age: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for agent in agent_pool:
		var age: int = agent.get("age", 0)
		if age >= min_age and age <= max_age:
			result.append(agent)
	return result


func get_agents_sorted_by_skill() -> Array[Dictionary]:
	var sorted := agent_pool.duplicate()
	sorted.sort_custom(_compare_by_overall)
	return sorted


func _compare_by_overall(a: Dictionary, b: Dictionary) -> bool:
	var a_overall := _get_overall(a)
	var b_overall := _get_overall(b)
	return a_overall > b_overall


func _get_overall(player: Dictionary) -> int:
	var combat: Dictionary = player.get("combat_skills", {})
	var total: int = 0
	for v in combat.values():
		total += v
	if combat.size() > 0:
		return total / combat.size()
	return 0


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_season_started(_season: int) -> void:
	# Обновляем пул каждый сезон (кроме первого)
	if _season > 1:
		generate_season_pool()


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"pool": agent_pool.duplicate(true)
	}


func from_dict(data: Dictionary) -> void:
	agent_pool.clear()
	for agent in data.get("pool", []):
		agent_pool.append(agent)
	EventBus.debug("Agent pool loaded: " + str(agent_pool.size()), "MARKET")
