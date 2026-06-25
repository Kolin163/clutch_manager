# ============================================================================
# TRAINING MANAGER — Тренировки игроков
# ============================================================================
# Типы тренировок, формула роста, выбор кто тренируется.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const TRAINING_TYPES := {
	"aim": {
		"name": "Тренировка Aim",
		"icon": "🎯",
		"skills": ["aim"],
		"base_gain": 2.0,
		"description": "Фокус на точности стрельбы"
	},
	"utility": {
		"name": "Тренировка Утилит",
		"icon": "💣",
		"skills": ["utility"],
		"base_gain": 2.0,
		"description": "Гранаты, молотовы, флешки"
	},
	"game_sense": {
		"name": "Тактическая тренировка",
		"icon": "🧠",
		"skills": ["game_sense", "clutch"],
		"base_gain": 1.5,
		"description": "Чтение игры и клатч-ситуации"
	},
	"mental": {
		"name": "Ментальная тренировка",
		"icon": "😤",
		"skills": ["tilt_resistance", "pressure", "discipline"],
		"base_gain": 1.5,
		"description": "Стрессоустойчивость и дисциплина"
	},
	"team": {
		"name": "Командная тренировка",
		"icon": "🤝",
		"skills": ["communication"],
		"base_gain": 2.5,
		"description": "Коммуникация и координация. Тренирует всех сразу.",
		"affects_all": true
	}
}

# Рост от матча (автоматический)
const MATCH_GAIN_BASE := 0.5

# Профильные скиллы ролей для матчевого роста
const ROLE_MATCH_SKILLS := {
	"entry": ["aim", "clutch"],
	"awper": ["aim", "game_sense"],
	"support": ["utility", "communication"],
	"lurker": ["game_sense", "clutch"],
	"igl": ["game_sense", "discipline"]
}


# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var last_training: Dictionary = {}  # {player_id: training_type}
var trained_this_round: Dictionary = {}  # {player_id: true} — кто уже тренировался
var team_trained_this_round: bool = false
var _matches_since_team_training: int = 0  # Командная доступна каждые 2 матча
var _preview_cache: Dictionary = {}  # Кэш preview для стабильности


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.debug("TrainingManager ready", "TRAINING")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_training_types() -> Dictionary:
	return TRAINING_TYPES


func get_training_type(type_id: String) -> Dictionary:
	return TRAINING_TYPES.get(type_id, {})


func preview_training(player_data: Dictionary, training_type: String) -> Dictionary:
	"""Предпросмотр прироста. Кэшируется для стабильности."""
	var cache_key: String = player_data.get("id", "") + "_" + training_type
	if _preview_cache.has(cache_key):
		return _preview_cache[cache_key]
	
	var training = TRAINING_TYPES.get(training_type, {})
	if training.is_empty():
		return {}
	
	var skills: Array = training.get("skills", [])
	var base_gain: float = training.get("base_gain", 1.0)
	var result: Dictionary = {}
	
	for skill_name in skills:
		var gain := _calculate_gain(player_data, skill_name, base_gain)
		result[skill_name] = gain
	
	_preview_cache[cache_key] = result
	return result


func can_train_player(player_id: String) -> bool:
	return not trained_this_round.has(player_id)


func can_train_team() -> bool:
	return not team_trained_this_round and _matches_since_team_training >= 2


func reset_round_training() -> void:
	"""Сбрасывает ограничения тренировок (вызывать после каждого матча)."""
	trained_this_round.clear()
	_matches_since_team_training += 1
	if team_trained_this_round:
		_matches_since_team_training = 0
	team_trained_this_round = false
	_preview_cache.clear()


func train_player(player_data: Dictionary, training_type: String) -> Dictionary:
	"""Тренирует игрока. Возвращает {skill: gain} фактических приростов."""
	var player_id: String = player_data.get("id", "")
	if not can_train_player(player_id):
		EventBus.debug("Player already trained this round: " + player_id, "WARN")
		return {}
	
	var training = TRAINING_TYPES.get(training_type, {})
	if training.is_empty():
		return {}
	
	var skills: Array = training.get("skills", [])
	var base_gain: float = training.get("base_gain", 1.0)
	var gains: Dictionary = {}
	
	for skill_name in skills:
		var gain := _calculate_gain(player_data, skill_name, base_gain)
		
		if gain <= 0.0:
			continue
		
		# Определяем тип скилла
		var combat: Dictionary = player_data.get("combat_skills", {})
		var mental: Dictionary = player_data.get("mental_skills", {})
		
		if combat.has(skill_name):
			var old_val: int = combat[skill_name]
			var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
			combat[skill_name] = new_val
			gains[skill_name] = new_val - old_val
		elif mental.has(skill_name):
			var old_val: int = mental[skill_name]
			var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
			mental[skill_name] = new_val
			gains[skill_name] = new_val - old_val
		
		player_data["combat_skills"] = combat
		player_data["mental_skills"] = mental
	
	# Записываем последнюю тренировку и ограничение
	last_training[player_id] = training_type
	trained_this_round[player_id] = true
	
	EventBus.training_completed.emit(player_id, training_type, gains)
	EventBus.debug("Trained " + player_data.get("nickname", "?") + ": " + str(gains), "TRAINING")
	
	return gains


func train_team(training_type: String) -> Dictionary:
	"""Тренирует всех (командная). Один раз за раунд.
	Не блокирует индивидуальные тренировки после себя."""
	if not can_train_team():
		EventBus.debug("Team already trained this round", "WARN")
		return {}
	
	team_trained_this_round = true
	var results: Dictionary = {}
	var roster = RosterManager.get_roster()
	var training = TRAINING_TYPES.get(training_type, {})
	var skills: Array = training.get("skills", [])
	var base_gain: float = training.get("base_gain", 1.0)
	
	for player in roster:
		var player_id: String = player.get("id", "")
		var gains: Dictionary = {}
		for skill_name in skills:
			var gain := _calculate_gain(player, skill_name, base_gain)
			if gain <= 0.0:
				continue
			var combat: Dictionary = player.get("combat_skills", {})
			var mental: Dictionary = player.get("mental_skills", {})
			if combat.has(skill_name):
				var old_val: int = combat[skill_name]
				var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
				combat[skill_name] = new_val
				gains[skill_name] = new_val - old_val
			elif mental.has(skill_name):
				var old_val: int = mental[skill_name]
				var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
				mental[skill_name] = new_val
				gains[skill_name] = new_val - old_val
			player["combat_skills"] = combat
			player["mental_skills"] = mental
		if not gains.is_empty():
			results[player_id] = gains
	
	return results


func apply_match_growth(roster: Array, match_result: Dictionary) -> Dictionary:
	"""Применяет рост от матча. Возвращает {player_id: {skill: gain}}."""
	var results: Dictionary = {}
	
	for player in roster:
		var player_id: String = player.get("id", "")
		var role: String = player.get("role", "entry")
		var role_skills: Array = ROLE_MATCH_SKILLS.get(role, ["aim"])
		
		var gains: Dictionary = {}
		
		for skill_name in role_skills:
			var gain := _calculate_gain(player, skill_name, MATCH_GAIN_BASE)
			
			if gain <= 0.0:
				continue
			
			var combat: Dictionary = player.get("combat_skills", {})
			var mental: Dictionary = player.get("mental_skills", {})
			
			if combat.has(skill_name):
				var old_val: int = combat[skill_name]
				var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
				combat[skill_name] = new_val
				gains[skill_name] = new_val - old_val
			elif mental.has(skill_name):
				var old_val: int = mental[skill_name]
				var new_val: int = clampi(old_val + int(round(gain)), 1, 100)
				mental[skill_name] = new_val
				gains[skill_name] = new_val - old_val
			
			player["combat_skills"] = combat
			player["mental_skills"] = mental
		
		if not gains.is_empty():
			results[player_id] = gains
	
	return results


# ----------------------------------------------------------------------------
# GROWTH FORMULA
# ----------------------------------------------------------------------------
func _calculate_gain(player_data: Dictionary, skill_name: String, base_gain: float) -> float:
	"""
	Формула:
	gain = base × room_modifier × (motivation/100) × (potential - skill) / potential × age_modifier
	"""
	var potential: int = player_data.get("potential", 50)
	var age: int = player_data.get("age", 20)
	
	# Получаем текущее значение скилла
	var current_value: int = 50
	var combat: Dictionary = player_data.get("combat_skills", {})
	var mental: Dictionary = player_data.get("mental_skills", {})
	
	if combat.has(skill_name):
		current_value = combat[skill_name]
	elif mental.has(skill_name):
		current_value = mental[skill_name]
	
	# Потенциал ограничивает рост: чем ближе к потенциалу, тем медленнее
	var potential_factor: float = 0.0
	if potential > 0:
		potential_factor = clampf(float(potential - current_value) / float(potential), 0.0, 1.0)
	
	if potential_factor <= 0.0:
		return 0.0
	
	# Мотивация
	var motivation: int = mental.get("motivation", 50)
	var motivation_mod: float = float(motivation) / 100.0
	
	# Модификатор тренировочной комнаты + тренер
	var room_mod: float = 1.0 + BaseManager.get_training_speed_bonus() + StaffManager.get_coach_training_bonus()
	
	# Качество тренировок (серверная)
	var quality_mod: float = 1.0 + BaseManager.get_training_quality_bonus()
	
	# Возрастной модификатор
	var age_mod: float = _get_age_modifier(age)
	
	# Итоговый расчёт
	var gain: float = base_gain * room_mod * quality_mod * motivation_mod * potential_factor * age_mod
	
	# Лёгкий рандом
	gain *= randf_range(0.8, 1.2)
	
	return maxf(gain, 0.0)


func _get_age_modifier(age: int) -> float:
	"""Молодые растут быстрее, ветераны — медленнее."""
	if age <= 18:
		return 1.4
	elif age <= 22:
		return 1.2
	elif age <= 25:
		return 1.0
	elif age <= 28:
		return 0.7
	elif age <= 30:
		return 0.4
	else:
		return 0.2


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_match_ended(result: Dictionary) -> void:
	# Автоматический рост от матча
	var roster = RosterManager.get_roster()
	var gains := apply_match_growth(roster, result)
	
	if not gains.is_empty():
		EventBus.debug("Match growth applied to " + str(gains.size()) + " players", "TRAINING")
	
	# Сбрасываем ограничения тренировок для нового межматчевого периода
	reset_round_training()


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"last_training": last_training.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	last_training = data.get("last_training", {}).duplicate()
