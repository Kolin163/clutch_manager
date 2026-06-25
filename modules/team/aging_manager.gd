# ============================================================================
# AGING MANAGER — Старение, пик, спад, тильт
# ============================================================================
# Обрабатывает возрастные изменения между сезонами.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const AGE_PEAK_START := 23
const AGE_PEAK_END := 26
const AGE_DECLINE_START := 27

# Спад: вероятность потери скилла за сезон для каждого скилла
const DECLINE_CHANCE_BY_AGE := {
	27: 0.15,
	28: 0.25,
	29: 0.40,
	30: 0.55,
	31: 0.70,
	32: 0.80
}
const DECLINE_AMOUNT_MIN := 1
const DECLINE_AMOUNT_MAX := 3

# Мотивация спадает с возрастом
const MOTIVATION_DECLINE_BY_AGE := {
	27: 1,
	28: 2,
	29: 3,
	30: 4,
	31: 5,
	32: 6
}

# Тильт
const TILT_LOSE_STREAK_THRESHOLD := 3
const TILT_SKILL_PENALTY := 5
const TILT_RECOVERY_BASE := 10
const MAX_TILT_LEVEL := 3  # 0=нормально, 1=лёгкий, 2=средний, 3=тильт

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
# Отслеживание тильта
var tilt_levels: Dictionary = {}  # player_id -> int (0-3)

# Снэпшот скиллов прошлого сезона для стрелок
var previous_season_skills: Dictionary = {}  # player_id -> {aim: X, ...}

# Текущая серия поражений
var current_lose_streak: int = 0


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	EventBus.match_ended.connect(_on_match_ended)
	EventBus.debug("AgingManager ready", "AGING")


# ----------------------------------------------------------------------------
# SEASON TRANSITION
# ----------------------------------------------------------------------------
func process_end_of_season(roster: Array) -> Dictionary:
	"""Вызывается между сезонами. Возвращает отчёт."""
	var report := {
		"aged": [],
		"declined": [],
		"motivation_lost": [],
		"retired_candidates": []
	}
	
	# Сохраняем снэпшот скиллов ДО изменений
	_save_skill_snapshot(roster)
	
	for player in roster:
		var player_id: String = player.get("id", "")
		var old_age: int = player.get("age", 20)
		
		# +1 год
		player["age"] = old_age + 1
		var new_age: int = player["age"]
		
		report["aged"].append({"id": player_id, "nickname": player.get("nickname", "?"), "age": new_age})
		
		# Спад скиллов
		if new_age >= AGE_DECLINE_START:
			var declined_skills := _apply_skill_decline(player, new_age)
			if not declined_skills.is_empty():
				report["declined"].append({"id": player_id, "nickname": player.get("nickname", "?"), "skills": declined_skills})
			
			# Мотивация
			var mot_loss := _apply_motivation_decline(player, new_age)
			if mot_loss > 0:
				report["motivation_lost"].append({"id": player_id, "nickname": player.get("nickname", "?"), "loss": mot_loss})
		
		# Кандидат на уход (33+)
		if new_age >= 33:
			report["retired_candidates"].append({"id": player_id, "nickname": player.get("nickname", "?"), "age": new_age})
	
	# Сбрасываем тильт между сезонами
	_reset_all_tilt()
	current_lose_streak = 0
	
	EventBus.debug("Season aging done: " + str(report["aged"].size()) + " aged, " + str(report["declined"].size()) + " declined", "AGING")
	return report


func _apply_skill_decline(player: Dictionary, age: int) -> Dictionary:
	"""Применяет спад скиллов. Возвращает {skill: amount_lost}."""
	var chance: float = DECLINE_CHANCE_BY_AGE.get(age, 0.0)
	if age > 32:
		chance = 0.85
	
	var declined: Dictionary = {}
	var combat: Dictionary = player.get("combat_skills", {})
	
	for skill in combat.keys():
		if randf() < chance:
			var loss := randi_range(DECLINE_AMOUNT_MIN, DECLINE_AMOUNT_MAX)
			var old_val: int = combat[skill]
			combat[skill] = clampi(old_val - loss, 15, 100)
			if combat[skill] < old_val:
				declined[skill] = old_val - combat[skill]
	
	player["combat_skills"] = combat
	return declined


func _apply_motivation_decline(player: Dictionary, age: int) -> int:
	"""Снижает мотивацию. Возвращает количество потерянного."""
	var loss: int = MOTIVATION_DECLINE_BY_AGE.get(age, 0)
	if age > 32:
		loss = 7
	
	if loss <= 0:
		return 0
	
	var mental: Dictionary = player.get("mental_skills", {})
	var old_mot: int = mental.get("motivation", 50)
	mental["motivation"] = clampi(old_mot - loss, 10, 100)
	player["mental_skills"] = mental
	
	return loss


# ----------------------------------------------------------------------------
# TILT SYSTEM
# ----------------------------------------------------------------------------
func get_tilt_level(player_id: String) -> int:
	return tilt_levels.get(player_id, 0)


func is_tilted(player_id: String) -> bool:
	return get_tilt_level(player_id) > 0


func get_tilt_penalty(player_id: String) -> int:
	"""Штраф к скиллам от тильта."""
	var level := get_tilt_level(player_id)
	return level * TILT_SKILL_PENALTY


func apply_tilt_to_skills(player_data: Dictionary) -> Dictionary:
	"""Возвращает модифицированные скиллы с учётом тильта."""
	var player_id: String = player_data.get("id", "")
	var penalty := get_tilt_penalty(player_id)
	
	if penalty <= 0:
		return player_data
	
	var modified := player_data.duplicate(true)
	var combat: Dictionary = modified.get("combat_skills", {})
	var mental: Dictionary = modified.get("mental_skills", {})
	
	for skill in combat.keys():
		combat[skill] = clampi(combat[skill] - penalty, 1, 100)
	
	# Тильт бьёт по pressure и discipline сильнее
	mental["pressure"] = clampi(mental.get("pressure", 50) - penalty * 2, 1, 100)
	mental["discipline"] = clampi(mental.get("discipline", 50) - penalty, 1, 100)
	
	modified["combat_skills"] = combat
	modified["mental_skills"] = mental
	return modified


func _check_tilt_after_match(is_win: bool) -> void:
	"""Проверяет и обновляет тильт после матча."""
	if is_win:
		current_lose_streak = 0
		# Победа снижает тильт у всех
		_recover_tilt_all(1)
		return
	
	current_lose_streak += 1
	
	if current_lose_streak >= TILT_LOSE_STREAK_THRESHOLD:
		_increase_tilt_all()


func _increase_tilt_all() -> void:
	"""Повышает тильт у всего состава."""
	var roster = RosterManager.get_roster()
	
	for player in roster:
		var player_id: String = player.get("id", "")
		var mental: Dictionary = player.get("mental_skills", {})
		var tilt_res: int = mental.get("tilt_resistance", 50)
		
		# Чем выше tilt_resistance, тем меньше шанс тильта
		var tilt_chance: float = 1.0 - (float(tilt_res) / 100.0 * 0.7)
		
		if randf() < tilt_chance:
			var current = tilt_levels.get(player_id, 0)
			tilt_levels[player_id] = mini(current + 1, MAX_TILT_LEVEL)
			EventBus.debug(player.get("nickname", "?") + " tilted! Level: " + str(tilt_levels[player_id]), "AGING")


func _recover_tilt_all(amount: int) -> void:
	"""Снижает тильт у всех."""
	var rest_bonus = BaseManager.get_mental_recovery_bonus() + StaffManager.get_mental_recovery_bonus()
	var effective_amount = amount + int(float(amount) * rest_bonus) + StaffManager.get_tilt_reduction()
	
	var to_remove: Array[String] = []
	
	for player_id in tilt_levels.keys():
		tilt_levels[player_id] = maxi(tilt_levels[player_id] - effective_amount, 0)
		if tilt_levels[player_id] <= 0:
			to_remove.append(player_id)
	
	for pid in to_remove:
		tilt_levels.erase(pid)


func recover_player_tilt(player_id: String, amount: int = 1) -> void:
	"""Ручное восстановление тильта (психолог)."""
	if not tilt_levels.has(player_id):
		return
	
	var rest_bonus = BaseManager.get_mental_recovery_bonus()
	var effective := amount + int(float(amount) * rest_bonus)
	
	tilt_levels[player_id] = maxi(tilt_levels[player_id] - effective, 0)
	if tilt_levels[player_id] <= 0:
		tilt_levels.erase(player_id)


func _reset_all_tilt() -> void:
	tilt_levels.clear()


# ----------------------------------------------------------------------------
# SKILL SNAPSHOTS (для стрелок на карточке)
# ----------------------------------------------------------------------------
func _save_skill_snapshot(roster: Array) -> void:
	"""Сохраняет текущие скиллы для сравнения в следующем сезоне."""
	previous_season_skills.clear()
	
	for player in roster:
		var player_id: String = player.get("id", "")
		var combat: Dictionary = player.get("combat_skills", {})
		previous_season_skills[player_id] = combat.duplicate()


func get_skill_change(player_id: String, skill_name: String, current_value: int) -> int:
	"""Возвращает изменение скилла с прошлого сезона. +/- или 0."""
	var prev: Dictionary = previous_season_skills.get(player_id, {})
	if prev.is_empty():
		return 0
	
	var old_value: int = prev.get(skill_name, current_value)
	return current_value - old_value


# ----------------------------------------------------------------------------
# AGE HELPERS
# ----------------------------------------------------------------------------
static func get_age_phase(age: int) -> String:
	"""Возвращает фазу: young, growing, peak, declining, veteran."""
	if age <= 19:
		return "young"
	elif age <= 22:
		return "growing"
	elif age <= 26:
		return "peak"
	elif age <= 30:
		return "declining"
	else:
		return "veteran"


static func get_age_phase_display(age: int) -> Dictionary:
	"""Возвращает {text, color} для отображения фазы."""
	var phase := get_age_phase(age)
	match phase:
		"young":
			return {"text": "🌱 Молодой", "color": "#80E6FF"}
		"growing":
			return {"text": "📈 Растёт", "color": "#4DFF80"}
		"peak":
			return {"text": "⭐ Пик", "color": "#FFCC4D"}
		"declining":
			return {"text": "📉 Спад", "color": "#FF9933"}
		"veteran":
			return {"text": "🔻 Ветеран", "color": "#FF6666"}
		_:
			return {"text": "—", "color": "#999999"}


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_match_ended(result: Dictionary) -> void:
	var is_win: bool = result.get("winner", "") == "player"
	_check_tilt_after_match(is_win)


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"tilt_levels": tilt_levels.duplicate(),
		"previous_season_skills": previous_season_skills.duplicate(true),
		"current_lose_streak": current_lose_streak
	}


func from_dict(data: Dictionary) -> void:
	tilt_levels = data.get("tilt_levels", {}).duplicate()
	previous_season_skills = data.get("previous_season_skills", {}).duplicate(true)
	current_lose_streak = data.get("current_lose_streak", 0)
