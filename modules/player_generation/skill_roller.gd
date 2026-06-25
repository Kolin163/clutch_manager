# ============================================================================
# SKILL ROLLER — Генерация скиллов игрока
# ============================================================================
# Рандомит боевые и ментальные скиллы на основе возраста, потенциала и роли.
# ============================================================================

class_name SkillRoller
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const SKILL_MIN := 1
const SKILL_MAX := 100

# Роли и их профильные скиллы (буст при генерации)
const ROLE_SKILL_BOOSTS := {
	"entry": {"aim": 15, "clutch": 10},
	"awper": {"aim": 20, "game_sense": 10},
	"support": {"utility": 20, "communication": 15},
	"lurker": {"game_sense": 15, "clutch": 15},
	"igl": {"game_sense": 20, "discipline": 15}
}

# Возрастные модификаторы
const AGE_YOUNG := 16  # Минимальный возраст
const AGE_PEAK_START := 23
const AGE_PEAK_END := 26
const AGE_DECLINE_START := 27
const AGE_OLD := 32  # Максимальный возраст


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
static func roll_all_skills(age: int, potential: int, role: String) -> Dictionary:
	var combat := roll_combat_skills(age, potential, role)
	var mental := roll_mental_skills(age, potential, role)
	
	return {
		"combat": combat,
		"mental": mental
	}


static func roll_combat_skills(age: int, potential: int, role: String) -> Dictionary:
	var base_range := _get_base_range_for_age(age, potential)
	var role_boosts: Dictionary = ROLE_SKILL_BOOSTS.get(role, {})
	
	return {
		"aim": _roll_skill(base_range, role_boosts.get("aim", 0)),
		"utility": _roll_skill(base_range, role_boosts.get("utility", 0)),
		"clutch": _roll_skill(base_range, role_boosts.get("clutch", 0)),
		"game_sense": _roll_skill(base_range, role_boosts.get("game_sense", 0))
	}


static func roll_mental_skills(age: int, potential: int, role: String) -> Dictionary:
	var base_range := _get_mental_range_for_age(age)
	var role_boosts: Dictionary = ROLE_SKILL_BOOSTS.get(role, {})
	
	return {
		"tilt_resistance": _roll_skill(base_range, 0),
		"motivation": _roll_skill(base_range, 0),
		"communication": _roll_skill(base_range, role_boosts.get("communication", 0)),
		"pressure": _roll_skill(base_range, 0),
		"discipline": _roll_skill(base_range, role_boosts.get("discipline", 0))
	}


static func roll_potential() -> int:
	# Потенциал: редко высокий
	# 40-60: 50%, 61-80: 35%, 81-100: 15%
	var roll := randf()
	
	if roll < 0.50:
		return randi_range(40, 60)
	elif roll < 0.85:
		return randi_range(61, 80)
	else:
		return randi_range(81, 100)


static func roll_age() -> int:
	# Возраст: молодые чаще
	# 16-20: 35%, 21-25: 40%, 26-30: 20%, 31-32: 5%
	var roll := randf()
	
	if roll < 0.35:
		return randi_range(16, 20)
	elif roll < 0.75:
		return randi_range(21, 25)
	elif roll < 0.95:
		return randi_range(26, 30)
	else:
		return randi_range(31, 32)


# ----------------------------------------------------------------------------
# PRIVATE HELPERS
# ----------------------------------------------------------------------------
static func _get_base_range_for_age(age: int, potential: int) -> Dictionary:
	# Молодой: низкие скиллы, но могут расти
	# Пик: высокие скиллы
	# Старый: высокие, но падают
	
	var potential_factor := potential / 100.0
	
	if age < 20:
		# Молодой талант: 20-50 базово, потенциал добавляет до +20
		var bonus := int(potential_factor * 20)
		return {"min": 20, "max": 50 + bonus}
	elif age < AGE_PEAK_START:
		# Растущий: 35-65, потенциал до +25
		var bonus := int(potential_factor * 25)
		return {"min": 35, "max": 65 + bonus}
	elif age <= AGE_PEAK_END:
		# Пик: 50-80, потенциал до +20
		var bonus := int(potential_factor * 20)
		return {"min": 50, "max": 80 + bonus}
	elif age < 30:
		# Начало спада: 45-75
		return {"min": 45, "max": 75}
	else:
		# Ветеран: 40-70
		return {"min": 40, "max": 70}


static func _get_mental_range_for_age(age: int) -> Dictionary:
	# Ментальные скиллы растут с опытом
	if age < 20:
		return {"min": 25, "max": 55}
	elif age < 24:
		return {"min": 35, "max": 65}
	elif age < 28:
		return {"min": 45, "max": 75}
	else:
		return {"min": 50, "max": 80}


static func _roll_skill(base_range: Dictionary, boost: int) -> int:
	var value := randi_range(base_range["min"], base_range["max"])
	value += boost
	return clampi(value, SKILL_MIN, SKILL_MAX)
