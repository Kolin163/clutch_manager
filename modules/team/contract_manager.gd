# ============================================================================
# CONTRACT MANAGER — Управление контрактами
# ============================================================================
# Контракты игроков и персонала: сроки, зарплаты, продление, истечение.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const MIN_CONTRACT_SEASONS := 1
const MAX_CONTRACT_SEASONS := 3
const DEFAULT_CONTRACT_SEASONS := 2

# Множители зарплаты при продлении
const RENEWAL_MULTIPLIER_MIN := 1.0
const RENEWAL_MULTIPLIER_MAX := 1.3


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.season_ended.connect(_on_season_ended)
	EventBus.debug("ContractManager ready", "CONTRACT")


# ----------------------------------------------------------------------------
# PUBLIC API — PLAYERS
# ----------------------------------------------------------------------------
func sign_player(player_data: Dictionary, seasons: int, salary: int) -> Dictionary:
	"""Подписывает игрока на контракт, возвращает обновлённые данные."""
	var updated := player_data.duplicate(true)
	
	seasons = clampi(seasons, MIN_CONTRACT_SEASONS, MAX_CONTRACT_SEASONS)
	
	updated["contract"] = {
		"salary": salary,
		"seasons_left": seasons,
		"signed_season": GameManager.current_season
	}
	
	EventBus.contract_renewed.emit(updated.get("id", ""), updated["contract"])
	EventBus.debug("Contract signed: " + updated.get("nickname", "?") + " for " + str(seasons) + " seasons", "CONTRACT")
	
	return updated


func renew_contract(player_data: Dictionary, additional_seasons: int) -> Dictionary:
	"""Продлевает контракт, увеличивает зарплату."""
	var updated := player_data.duplicate(true)
	var contract: Dictionary = updated.get("contract", {})
	
	var current_salary: int = contract.get("salary", 1000)
	var multiplier: float = randf_range(RENEWAL_MULTIPLIER_MIN, RENEWAL_MULTIPLIER_MAX)
	var new_salary: int = int(float(current_salary) * multiplier)
	new_salary = (new_salary / 50) * 50  # Округление до 50
	
	contract["salary"] = new_salary
	contract["seasons_left"] = contract.get("seasons_left", 0) + additional_seasons
	contract["renewed_season"] = GameManager.current_season
	
	updated["contract"] = contract
	
	EventBus.contract_renewed.emit(updated.get("id", ""), contract)
	EventBus.debug("Contract renewed: " + updated.get("nickname", "?") + ", new salary: $" + str(new_salary), "CONTRACT")
	
	return updated


func terminate_contract(player_data: Dictionary) -> Dictionary:
	"""Расторгает контракт, игрок становится свободным агентом."""
	var updated := player_data.duplicate(true)
	
	updated["contract"] = {
		"salary": 0,
		"seasons_left": 0
	}
	
	EventBus.contract_expired.emit(updated.get("id", ""))
	EventBus.debug("Contract terminated: " + updated.get("nickname", "?"), "CONTRACT")
	
	return updated


func get_contract_status(player_data: Dictionary) -> String:
	"""Возвращает статус контракта: 'active', 'expiring', 'expired'."""
	var contract: Dictionary = player_data.get("contract", {})
	var seasons_left: int = contract.get("seasons_left", 0)
	
	if seasons_left <= 0:
		return "expired"
	elif seasons_left == 1:
		return "expiring"
	else:
		return "active"


func is_free_agent(player_data: Dictionary) -> bool:
	var contract: Dictionary = player_data.get("contract", {})
	return contract.get("seasons_left", 0) <= 0


func get_seasons_left(player_data: Dictionary) -> int:
	var contract: Dictionary = player_data.get("contract", {})
	return contract.get("seasons_left", 0)


func get_salary(player_data: Dictionary) -> int:
	var contract: Dictionary = player_data.get("contract", {})
	return contract.get("salary", 0)


# ----------------------------------------------------------------------------
# SALARY CALCULATION
# ----------------------------------------------------------------------------
func calculate_fair_salary(player_data: Dictionary) -> int:
	"""Рассчитывает справедливую зарплату на основе скиллов."""
	var combat: Dictionary = player_data.get("combat_skills", {})
	var age: int = player_data.get("age", 20)
	var potential: int = player_data.get("potential", 50)
	
	# Средний скилл
	var avg_skill: float = 0.0
	for value in combat.values():
		avg_skill += float(value)
	if combat.size() > 0:
		avg_skill /= float(combat.size())
	
	# Базовая зарплата
	var base: float = 500.0 + (avg_skill * 50.0)
	
	# Модификатор возраста
	var age_mod: float = 1.0
	if age < 20:
		age_mod = 0.7
	elif age > 28:
		age_mod = 0.85
	elif age >= 23 and age <= 26:
		age_mod = 1.15  # Пиковый возраст
	
	# Модификатор потенциала
	var potential_mod: float = 0.8 + (float(potential) / 100.0 * 0.4)
	
	var discount = BaseManager.get_contract_discount()
	
	var salary: int = int(base * age_mod * potential_mod * (1.0 - discount))
	salary = (salary / 50) * 50  # Округление
	
	return clampi(salary, 500, 15000)


func calculate_renewal_salary(player_data: Dictionary) -> int:
	"""Рассчитывает зарплату для продления (выше текущей)."""
	var current: int = get_salary(player_data)
	var fair: int = calculate_fair_salary(player_data)
	
	# Берём максимум + 10-20%
	var base: int = maxi(current, fair)
	var multiplier: float = randf_range(1.1, 1.25)
	
	var new_salary: int = int(float(base) * multiplier)
	new_salary = (new_salary / 50) * 50
	
	return clampi(new_salary, current, 20000)


# ----------------------------------------------------------------------------
# SEASON END PROCESSING
# ----------------------------------------------------------------------------
func _on_season_ended(_season: int, _results: Dictionary) -> void:
	_process_contracts()


func _process_contracts() -> void:
	"""Уменьшает оставшиеся сезоны у всех контрактов."""
	var roster = RosterManager.get_roster()
	var expiring_players: Array[String] = []
	
	for i in range(roster.size()):
		var player: Dictionary = roster[i]
		var contract: Dictionary = player.get("contract", {})
		var seasons_left: int = contract.get("seasons_left", 0)
		
		if seasons_left > 0:
			seasons_left -= 1
			contract["seasons_left"] = seasons_left
			player["contract"] = contract
			roster[i] = player
			
			if seasons_left == 0:
				expiring_players.append(player.get("nickname", "Unknown"))
				EventBus.contract_expired.emit(player.get("id", ""))
	
	if not expiring_players.is_empty():
		EventBus.debug("Contracts expired: " + ", ".join(expiring_players), "CONTRACT")


# ----------------------------------------------------------------------------
# BULK OPERATIONS
# ----------------------------------------------------------------------------
func get_expiring_contracts() -> Array[Dictionary]:
	"""Возвращает игроков с истекающими контрактами (1 сезон)."""
	var expiring: Array[Dictionary] = []
	
	for player in RosterManager.get_roster():
		if get_contract_status(player) == "expiring":
			expiring.append(player)
	
	return expiring


func get_total_salaries() -> int:
	"""Общая сумма зарплат команды."""
	return RosterManager.get_total_salaries()
