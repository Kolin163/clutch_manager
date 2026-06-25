# ============================================================================
# STAFF MANAGER — Управление персоналом команды
# ============================================================================
# Хранит нанятый персонал, предоставляет бонусы другим системам.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var hired_staff: Array[Dictionary] = []  # Массив staff.to_dict()


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.season_ended.connect(_on_season_ended)
	EventBus.debug("StaffManager ready", "STAFF")


# ----------------------------------------------------------------------------
# HIRE / FIRE
# ----------------------------------------------------------------------------
func hire(staff_data: Dictionary, seasons: int = 2) -> bool:
	"""Нанимает персонал. Проверяет слоты и бюджет."""
	if hired_staff.size() >= get_max_slots():
		EventBus.debug("No staff slots available", "WARN")
		return false

	var role_id: int = staff_data.get("role", 0)
	if has_role(role_id):
		EventBus.debug("Already have this role", "WARN")
		return false

	var salary: int = staff_data.get("salary", 500)
	var discount := get_hire_discount()
	var cost: int = int(float(salary) * (1.0 - discount))

	if not EconomyManager.can_afford(cost):
		EventBus.debug("Cannot afford staff hire: $" + str(cost), "WARN")
		return false

	EconomyManager.spend_money(cost, "staff_hire")

	var entry := staff_data.duplicate(true)
	entry["contract_seasons_left"] = seasons
	hired_staff.append(entry)

	EventBus.staff_hired.emit(entry)
	EventBus.debug("Staff hired: " + entry.get("last_name", "?") + " (" + _role_name(role_id) + ")", "STAFF")
	return true


func fire(staff_id: String) -> bool:
	for i in range(hired_staff.size()):
		if hired_staff[i].get("id", "") == staff_id:
			var removed := hired_staff[i]
			hired_staff.remove_at(i)
			EventBus.staff_fired.emit(staff_id)
			EventBus.debug("Staff fired: " + removed.get("last_name", "?"), "STAFF")
			return true
	return false


func has_role(role_id: int) -> bool:
	for s in hired_staff:
		if s.get("role", -1) == role_id:
			return true
	return false


func get_by_role(role_id: int) -> Dictionary:
	for s in hired_staff:
		if s.get("role", -1) == role_id:
			return s
	return {}


func get_all() -> Array[Dictionary]:
	return hired_staff


func get_hired_count() -> int:
	return hired_staff.size()


func get_max_slots() -> int:
	return BaseManager.get_staff_slots()


# ----------------------------------------------------------------------------
# BONUS QUERIES — другие системы вызывают эти методы
# ----------------------------------------------------------------------------

# --- ТРЕНЕР (COACH = 0) ---
func has_coach() -> bool:
	return has_role(0)


func get_coach_training_bonus() -> float:
	"""Бонус к скорости тренировок от тренера."""
	var coach := get_by_role(0)
	if coach.is_empty():
		return 0.0
	return float(coach.get("skill_level", 50)) / 100.0 * 0.5


func has_advanced_tactics() -> bool:
	"""Тренер разблокирует продвинутые тактики если skill >= 60."""
	var coach := get_by_role(0)
	if coach.is_empty():
		return false
	return coach.get("skill_level", 0) >= 60


# --- АНАЛИТИК (ANALYST = 1) ---
func has_analyst() -> bool:
	return has_role(1)


func get_scouting_accuracy() -> float:
	"""Точность скаутинга. 0.0 = базовая, до 0.5 = почти точная."""
	var analyst := get_by_role(1)
	if analyst.is_empty():
		return 0.0
	return float(analyst.get("skill_level", 50)) / 100.0 * 0.5


func get_opponent_reveal_count() -> int:
	"""Сколько скиллов соперника раскрывается перед матчем."""
	var analyst := get_by_role(1)
	if analyst.is_empty():
		return 0
	var skill: int = analyst.get("skill_level", 0)
	if skill >= 80:
		return 4
	elif skill >= 60:
		return 3
	elif skill >= 40:
		return 2
	return 1


# --- ПСИХОЛОГ (PSYCHOLOGIST = 2) ---
func has_psychologist() -> bool:
	return has_role(2)


func get_mental_recovery_bonus() -> float:
	"""Бонус к восстановлению ментала от психолога."""
	var psych := get_by_role(2)
	if psych.is_empty():
		return 0.0
	return float(psych.get("skill_level", 50)) / 100.0 * 0.5


func get_tilt_reduction() -> int:
	"""Сколько уровней тильта снимает психолог после поражения."""
	var psych := get_by_role(2)
	if psych.is_empty():
		return 0
	var skill: int = psych.get("skill_level", 0)
	if skill >= 70:
		return 2
	elif skill >= 40:
		return 1
	return 0


# --- МЕНЕДЖЕР (MANAGER = 3) ---
func has_manager() -> bool:
	return has_role(3)


func get_sponsor_bonus() -> float:
	"""Бонус к доходам от спонсоров."""
	var mgr := get_by_role(3)
	if mgr.is_empty():
		return 0.0
	return float(mgr.get("skill_level", 50)) / 100.0 * 0.3


func get_hire_discount() -> float:
	"""Скидка на найм агентов и персонала."""
	var mgr := get_by_role(3)
	if mgr.is_empty():
		return 0.0
	return float(mgr.get("skill_level", 50)) / 100.0 * 0.2


# ----------------------------------------------------------------------------
# TOTAL SALARIES
# ----------------------------------------------------------------------------
func get_total_salaries() -> int:
	var total: int = 0
	for s in hired_staff:
		total += s.get("salary", 0)
	return total


# ----------------------------------------------------------------------------
# STAFF MARKET — генерация доступных для найма
# ----------------------------------------------------------------------------
func generate_available_staff(count: int = 6) -> Array[Dictionary]:
	"""Генерирует список доступных для найма сотрудников."""
	var result: Array[Dictionary] = []
	var roles := [0, 0, 1, 1, 2, 2, 3, 3]  # По 2 кандидата на роль
	roles.shuffle()

	for i in range(mini(count, roles.size())):
		var staff := Staff.generate(roles[i] as Staff.StaffRole, Vector2i(30, 80))
		result.append(staff.to_dict())

	return result


# ----------------------------------------------------------------------------
# SEASON END
# ----------------------------------------------------------------------------
func _on_season_ended(_season: int, _results: Dictionary) -> void:
	_process_contracts()


func _process_contracts() -> void:
	var expired: Array[String] = []

	for s in hired_staff:
		var left: int = s.get("contract_seasons_left", 0)
		if left > 0:
			s["contract_seasons_left"] = left - 1
			if left - 1 <= 0:
				expired.append(s.get("last_name", "?"))

	if not expired.is_empty():
		EventBus.debug("Staff contracts expired: " + ", ".join(expired), "STAFF")


func get_expiring_staff() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in hired_staff:
		if s.get("contract_seasons_left", 0) <= 1:
			result.append(s)
	return result


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
func _role_name(role_id: int) -> String:
	match role_id:
		0: return "Тренер"
		1: return "Аналитик"
		2: return "Психолог"
		3: return "Менеджер"
		_: return "?"


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"staff": hired_staff.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	hired_staff.clear()
	for s in data.get("staff", []):
		hired_staff.append(s)
	EventBus.debug("Staff loaded: " + str(hired_staff.size()), "STAFF")
