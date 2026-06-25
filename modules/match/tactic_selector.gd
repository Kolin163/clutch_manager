# ============================================================================
# TACTIC SELECTOR — Управление тактиками
# ============================================================================
# Загружает тактики из JSON, фильтрует по стороне и доступности.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var _tactics_data: Dictionary = {}
var _data_loaded: bool = false


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_load_tactics()
	EventBus.debug("TacticSelector ready", "MATCH")


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_all_tactics() -> Array[Dictionary]:
	"""Возвращает все тактики."""
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for tactic in _tactics_data.get("tactics", []):
		result.append(tactic)
	return result


func get_tactic(tactic_id: String) -> Dictionary:
	"""Возвращает тактику по ID."""
	_ensure_loaded()
	for tactic in _tactics_data.get("tactics", []):
		if tactic.get("id", "") == tactic_id:
			return tactic
	return {}


func get_tactics_for_side(side: String) -> Array[Dictionary]:
	"""Возвращает тактики для стороны (attack/defense)."""
	_ensure_loaded()
	var result: Array[Dictionary] = []
	
	for tactic in _tactics_data.get("tactics", []):
		var tactic_type: String = tactic.get("type", "")
		var unlocked: bool = tactic.get("unlocked", true)
		
		# Проверяем доступность
		if not unlocked:
			# TODO: проверять наличие тренера
			continue
		
		# Фильтруем по типу
		if side == "attack" and tactic_type == "attack":
			result.append(tactic)
		elif side == "defense" and tactic_type == "defense":
			result.append(tactic)
	
	return result


func get_unlocked_tactics() -> Array[Dictionary]:
	"""Возвращает разблокированные тактики."""
	_ensure_loaded()
	var result: Array[Dictionary] = []
	
	for tactic in _tactics_data.get("tactics", []):
		if tactic.get("unlocked", true):
			result.append(tactic)
		elif _check_unlock_condition(tactic):
			result.append(tactic)
	
	return result


func is_tactic_effective_against(tactic_id: String, enemy_tactic_id: String) -> int:
	"""Возвращает эффективность: 1 = сильнее, -1 = слабее, 0 = нейтрально."""
	var tactic := get_tactic(tactic_id)
	
	var strong: Array = tactic.get("strong_against", [])
	var weak: Array = tactic.get("weak_against", [])
	
	if enemy_tactic_id in strong:
		return 1
	elif enemy_tactic_id in weak:
		return -1
	
	return 0


func get_tactic_display_name(tactic_id: String) -> String:
	"""Возвращает отображаемое имя тактики."""
	var tactic := get_tactic(tactic_id)
	return tactic.get("name_ru", tactic.get("name", tactic_id))


func get_tactic_description(tactic_id: String) -> String:
	"""Возвращает описание тактики."""
	var tactic := get_tactic(tactic_id)
	return tactic.get("description", "")


# ----------------------------------------------------------------------------
# META BONUSES
# ----------------------------------------------------------------------------
func calculate_meta_bonus(tactic_id: String, current_meta: String) -> float:
	"""Рассчитывает бонус от меты."""
	var tactic := get_tactic(tactic_id)
	var meta_condition: String = tactic.get("meta_bonus_condition", "")
	
	if meta_condition.is_empty() or meta_condition != current_meta:
		return 0.0
	
	return tactic.get("meta_bonus", 0.0)


# ----------------------------------------------------------------------------
# DATA LOADING
# ----------------------------------------------------------------------------
func _ensure_loaded() -> void:
	if not _data_loaded:
		_load_tactics()


func _load_tactics() -> void:
	var file := FileAccess.open("res://data/tactics/tactics.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			_tactics_data = json.data
			_data_loaded = true
		else:
			EventBus.debug("Failed to parse tactics.json", "ERROR")
	else:
		EventBus.debug("Failed to load tactics.json", "ERROR")


func _check_unlock_condition(tactic: Dictionary) -> bool:
	"""Проверяет условие разблокировки тактики."""
	if tactic.get("requires_coach", false):
		return StaffManager.has_advanced_tactics()
	return true
