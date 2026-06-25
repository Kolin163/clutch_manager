# ============================================================================
# PLAYER GENERATOR — Точка входа для генерации игрока
# ============================================================================
# Собирает всё вместе: имя, внешность, скиллы.
# Возвращает готовый Dictionary с данными игрока.
# ============================================================================

class_name PlayerGenerator
extends RefCounted

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const ROLES := ["entry", "awper", "support", "lurker", "igl"]


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
static func generate_player(params: Dictionary = {}) -> Dictionary:
	# Параметры (опциональные)
	var nationality_id: String = params.get("nationality", "")
	var role: String = params.get("role", "")
	var age: int = params.get("age", 0)
	var potential: int = params.get("potential", 0)
	
	# Генерируем недостающее
	if nationality_id.is_empty():
		nationality_id = NameGenerator.get_random_nationality_id()
	
	if role.is_empty():
		role = ROLES[randi() % ROLES.size()]
	
	if age <= 0:
		age = SkillRoller.roll_age()
	
	if potential <= 0:
		potential = SkillRoller.roll_potential()
	
	# Генерируем компоненты
	var name_data := NameGenerator.generate_name(nationality_id)
	var appearance := AppearanceBuilder.build_appearance(nationality_id)
	var skills := SkillRoller.roll_all_skills(age, potential, role)
	
	# Генерируем уникальный ID
	var player_id := _generate_player_id()
	
	# Собираем игрока
	var player := {
		"id": player_id,
		"first_name": name_data["first_name"],
		"last_name": name_data["last_name"],
		"nickname": name_data["nickname"],
		"nationality": nationality_id,
		"region": NameGenerator.get_nationality_region(nationality_id),
		"age": age,
		"potential": potential,
		"role": role,
		"combat_skills": skills["combat"],
		"mental_skills": skills["mental"],
		"popularity": _calculate_initial_popularity(age, potential),
		"appearance": appearance,
		"contract": {
			"salary": _calculate_initial_salary(age, potential, skills),
			"seasons_left": 0  # Свободный агент
		},
		"stats": {
			"matches_played": 0,
			"rounds_played": 0,
			"kills": 0,
			"deaths": 0,
			"clutches_won": 0,
			"clutches_total": 0
		}
	}
	
	return player


static func generate_random_player() -> Dictionary:
	return generate_player({})


static func generate_player_for_role(role: String) -> Dictionary:
	return generate_player({"role": role})


static func generate_young_talent() -> Dictionary:
	return generate_player({
		"age": randi_range(16, 19),
		"potential": randi_range(70, 100)
	})


static func generate_veteran() -> Dictionary:
	return generate_player({
		"age": randi_range(28, 32),
		"potential": randi_range(40, 70)
	})


static func generate_roster(count: int = 5) -> Array:
	# Генерируем состав с разными ролями
	var roster: Array = []
	var roles_to_fill := ROLES.duplicate()
	
	for i in range(count):
		var role: String
		if i < roles_to_fill.size():
			role = roles_to_fill[i]
		else:
			role = ROLES[randi() % ROLES.size()]
		
		roster.append(generate_player({"role": role}))
	
	return roster


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
static func _generate_player_id() -> String:
	var timestamp := Time.get_unix_time_from_system()
	var random_part := randi_range(1000, 9999)
	return "player_%d_%d" % [int(timestamp), random_part]


static func _calculate_initial_popularity(age: int, potential: int) -> int:
	# Начальная популярность: 0-10, зависит от возраста и потенциала
	var base := 0
	
	if age > 25 and potential > 70:
		base = randi_range(3, 8)
	elif potential > 80:
		base = randi_range(1, 5)
	else:
		base = randi_range(0, 3)
	
	return base


static func _calculate_initial_salary(age: int, potential: int, skills: Dictionary) -> int:
	# Базовая зарплата: 500-5000
	var combat: Dictionary = skills.get("combat", {})
	var avg_combat := 0.0
	
	for skill_value in combat.values():
		avg_combat += float(skill_value)
	
	if combat.size() > 0:
		avg_combat /= combat.size()
	
	# Факторы
	var skill_factor := avg_combat / 100.0
	var potential_factor := potential / 100.0
	var age_factor := 1.0
	
	if age < 20:
		age_factor = 0.7
	elif age > 28:
		age_factor = 0.85
	
	var salary := 500 + int(4500 * skill_factor * potential_factor * age_factor)
	
	# Округляем до 50
	salary = (salary / 50) * 50
	
	return clampi(salary, 500, 10000)


# ----------------------------------------------------------------------------
# DEBUG
# ----------------------------------------------------------------------------
static func get_role_display_name(role: String) -> String:
	match role:
		"entry":
			return "Entry Fragger"
		"awper":
			return "AWPer"
		"support":
			return "Support"
		"lurker":
			return "Lurker"
		"igl":
			return "IGL"
		_:
			return role.capitalize()
