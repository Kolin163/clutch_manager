# ============================================================================
# TRANSPORT — Управление транспортом
# ============================================================================
# Транспорт влияет на выездные матчи: штраф к ментальным скиллам и усталость.
# Маршрутка → Минивэн → Автобус → Чартер
# ============================================================================

class_name Transport
extends RefCounted

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var current_id: String = "minibus"
var current_level: int = 0
var _transport_data: Array = []
var _data_loaded: bool = false


# ----------------------------------------------------------------------------
# INIT
# ----------------------------------------------------------------------------
func _init() -> void:
	_load_data()


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_current() -> Dictionary:
	"""Возвращает данные текущего транспорта."""
	for t in _transport_data:
		if t.get("id", "") == current_id:
			return t
	return {}


func get_transport_name() -> String:
	return get_current().get("name", "Маршрутка")


func get_mental_penalty() -> int:
	"""Штраф к ментальным скиллам на выезде."""
	return get_current().get("mental_penalty", -10)


func get_fatigue_penalty() -> int:
	"""Добавление усталости на выезде."""
	return get_current().get("fatigue_penalty", 15)


func get_next_upgrade() -> Dictionary:
	"""Возвращает данные следующего уровня транспорта."""
	var next_level := current_level + 1
	for t in _transport_data:
		if t.get("level", -1) == next_level:
			return t
	return {}


func get_upgrade_cost() -> int:
	"""Стоимость следующего апгрейда."""
	var next := get_next_upgrade()
	return next.get("cost", 0)


func can_upgrade() -> bool:
	"""Можно ли апгрейдить."""
	return not get_next_upgrade().is_empty()


func upgrade() -> bool:
	"""Апгрейдит транспорт. Возвращает успех."""
	var next := get_next_upgrade()
	if next.is_empty():
		return false
	
	current_id = next.get("id", current_id)
	current_level = next.get("level", current_level + 1)
	
	EventBus.transport_upgraded.emit(current_id)
	EventBus.debug("Transport upgraded to: " + get_transport_name(), "BASE")
	return true


func apply_away_penalties(roster: Array) -> Array:
	"""Применяет штрафы выезда к составу. Возвращает модифицированный состав."""
	var mental_pen := get_mental_penalty()
	var fatigue_pen := get_fatigue_penalty()
	
	if mental_pen == 0 and fatigue_pen == 0:
		return roster
	
	var modified: Array = []
	
	for player_data in roster:
		var p = player_data.duplicate(true)
		var mental: Dictionary = p.get("mental_skills", {})
		
		# Применяем штраф ко всем ментальным скиллам
		for skill in mental.keys():
			mental[skill] = clampi(mental[skill] + mental_pen, 1, 100)
		p["mental_skills"] = mental
		
		# Добавляем усталость
		var fatigue: int = p.get("fatigue", 0)
		p["fatigue"] = clampi(fatigue + fatigue_pen, 0, 100)
		
		modified.append(p)
	
	EventBus.debug("Away penalties applied: mental " + str(mental_pen) + ", fatigue +" + str(fatigue_pen), "BASE")
	return modified


func get_all_transport() -> Array:
	"""Возвращает все уровни транспорта."""
	return _transport_data


# ----------------------------------------------------------------------------
# DATA
# ----------------------------------------------------------------------------
func _load_data() -> void:
	if _data_loaded:
		return
	
	var file := FileAccess.open("res://data/items/transport.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_transport_data = json.data.get("transport", [])
			_data_loaded = true
		file.close()


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"id": current_id,
		"level": current_level
	}


func load_from_dict(data: Dictionary) -> void:
	current_id = data.get("id", "minibus")
	current_level = data.get("level", 0)
