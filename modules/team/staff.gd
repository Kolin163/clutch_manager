# ============================================================================
# STAFF — Класс персонала
# ============================================================================
# Тренер, Аналитик, Психолог, Менеджер.
# Каждый даёт бонусы к определённым аспектам игры.
# ============================================================================

class_name Staff
extends Resource

# ----------------------------------------------------------------------------
# ENUMS
# ----------------------------------------------------------------------------
enum StaffRole {
	COACH,      # Тренер — бонус тренировок, продвинутые тактики
	ANALYST,    # Аналитик — скиллы соперников, точнее скаутинг
	PSYCHOLOGIST, # Психолог — буст ментала, снижение тильта
	MANAGER     # Менеджер — лучше спонсоры, скидки на найм
}

# ----------------------------------------------------------------------------
# PROPERTIES
# ----------------------------------------------------------------------------
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var role: StaffRole = StaffRole.COACH
@export var skill_level: int = 50  # 1-100, влияет на силу эффектов
@export var salary: int = 500
@export var contract_seasons_left: int = 0

# ----------------------------------------------------------------------------
# STATIC DATA
# ----------------------------------------------------------------------------
const ROLE_NAMES := {
	StaffRole.COACH: "Тренер",
	StaffRole.ANALYST: "Аналитик",
	StaffRole.PSYCHOLOGIST: "Психолог",
	StaffRole.MANAGER: "Менеджер"
}

const ROLE_NAMES_EN := {
	StaffRole.COACH: "Coach",
	StaffRole.ANALYST: "Analyst",
	StaffRole.PSYCHOLOGIST: "Psychologist",
	StaffRole.MANAGER: "Manager"
}

const ROLE_DESCRIPTIONS := {
	StaffRole.COACH: "Ускоряет тренировки, открывает продвинутые тактики",
	StaffRole.ANALYST: "Показывает скиллы соперников, улучшает скаутинг",
	StaffRole.PSYCHOLOGIST: "Восстанавливает ментал, снижает тильт",
	StaffRole.MANAGER: "Улучшает спонсорские сделки, скидки на найм"
}

# Имена для генерации
# Раздельные пулы чтобы имя+фамилия стыковались по языку
const RU_FIRST := ["Александр", "Михаил", "Дмитрий", "Андрей", "Сергей", "Владимир", "Николай", "Павел", "Игорь", "Олег"]
const RU_LAST := ["Петров", "Сидоров", "Козлов", "Новиков", "Морозов", "Волков", "Соловьёв", "Васильев", "Кузнецов", "Попов"]
const EN_FIRST := ["John", "Michael", "David", "James", "Robert", "William", "Thomas", "Daniel", "Chris", "Mark"]
const EN_LAST := ["Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson", "Anderson", "Taylor"]


# ----------------------------------------------------------------------------
# STATIC FACTORY
# ----------------------------------------------------------------------------
static func generate(staff_role: StaffRole, skill_range: Vector2i = Vector2i(30, 70)) -> Staff:
	var staff := Staff.new()
	
	staff.id = "staff_%d_%d" % [Time.get_unix_time_from_system(), randi_range(1000, 9999)]
	# Выбираем имя+фамилию из одного языкового пула
	if randf() < 0.5:
		staff.first_name = RU_FIRST[randi() % RU_FIRST.size()]
		staff.last_name = RU_LAST[randi() % RU_LAST.size()]
	else:
		staff.first_name = EN_FIRST[randi() % EN_FIRST.size()]
		staff.last_name = EN_LAST[randi() % EN_LAST.size()]
	staff.role = staff_role
	staff.skill_level = randi_range(skill_range.x, skill_range.y)
	staff.salary = staff._calculate_salary()
	staff.contract_seasons_left = 0  # Свободный агент
	
	return staff


static func generate_random(skill_range: Vector2i = Vector2i(30, 70)) -> Staff:
	var roles := [StaffRole.COACH, StaffRole.ANALYST, StaffRole.PSYCHOLOGIST, StaffRole.MANAGER]
	var random_role: StaffRole = roles[randi() % roles.size()]
	return generate(random_role, skill_range)


# ----------------------------------------------------------------------------
# INSTANCE METHODS
# ----------------------------------------------------------------------------
func get_role_name(lang: String = "ru") -> String:
	if lang == "en":
		return ROLE_NAMES_EN.get(role, "Unknown")
	return ROLE_NAMES.get(role, "Неизвестно")


func get_role_description() -> String:
	return ROLE_DESCRIPTIONS.get(role, "")


func get_full_name() -> String:
	return first_name + " " + last_name


func get_display_name() -> String:
	return last_name


func is_free_agent() -> bool:
	return contract_seasons_left <= 0


func _calculate_salary() -> int:
	# Базовая зарплата зависит от уровня скилла
	var base: int = 300 + (skill_level * 8)
	base = (base / 50) * 50  # Округление до 50
	return clampi(base, 300, 2000)


# ----------------------------------------------------------------------------
# EFFECTS
# ----------------------------------------------------------------------------
func get_training_bonus() -> float:
	"""Бонус к скорости тренировок (только тренер)."""
	if role != StaffRole.COACH:
		return 0.0
	return float(skill_level) / 100.0 * 0.5  # До +50%


func get_scouting_bonus() -> float:
	"""Бонус к точности скаутинга (только аналитик)."""
	if role != StaffRole.ANALYST:
		return 0.0
	return float(skill_level) / 100.0 * 0.5  # До +50% точности


func get_mental_recovery_bonus() -> float:
	"""Бонус к восстановлению ментала (только психолог)."""
	if role != StaffRole.PSYCHOLOGIST:
		return 0.0
	return float(skill_level) / 100.0 * 0.5  # До +50%


func get_sponsor_bonus() -> float:
	"""Бонус к спонсорским сделкам (только менеджер)."""
	if role != StaffRole.MANAGER:
		return 0.0
	return float(skill_level) / 100.0 * 0.3  # До +30%


func get_hire_discount() -> float:
	"""Скидка на найм (только менеджер)."""
	if role != StaffRole.MANAGER:
		return 0.0
	return float(skill_level) / 100.0 * 0.2  # До -20%


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"role": role,
		"skill_level": skill_level,
		"salary": salary,
		"contract_seasons_left": contract_seasons_left
	}


static func from_dict(data: Dictionary) -> Staff:
	var staff := Staff.new()
	staff.id = data.get("id", "")
	staff.first_name = data.get("first_name", "")
	staff.last_name = data.get("last_name", "")
	staff.role = data.get("role", StaffRole.COACH)
	staff.skill_level = data.get("skill_level", 50)
	staff.salary = data.get("salary", 500)
	staff.contract_seasons_left = data.get("contract_seasons_left", 0)
	return staff
