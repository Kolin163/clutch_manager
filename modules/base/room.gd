# ============================================================================
# ROOM — Класс комнаты на базе
# ============================================================================
# Комната имеет уровень, стоимость апгрейда и эффект.
# Эффекты применяются через EventBus.
# ============================================================================

class_name Room
extends Resource

# ----------------------------------------------------------------------------
# PROPERTIES
# ----------------------------------------------------------------------------
@export var id: String = ""
@export var current_level: int = 0  # 0 = не построена
@export var is_built: bool = false

# Данные из JSON (кэшируются при создании)
var config: Dictionary = {}


# ----------------------------------------------------------------------------
# STATIC FACTORY
# ----------------------------------------------------------------------------
static func create(room_config: Dictionary, built_level: int = 0) -> Room:
	var room := Room.new()
	room.id = room_config.get("id", "")
	room.config = room_config
	room.current_level = built_level
	room.is_built = built_level > 0
	return room


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
func get_room_name() -> String:
	return config.get("name", id)


func get_room_description() -> String:
	return config.get("description", "")


func get_effect_type() -> String:
	return config.get("effect_type", "")


func get_max_level() -> int:
	var levels: Array = config.get("levels", [])
	return levels.size()


func get_min_base_level() -> int:
	return config.get("min_base_level", 1)


func get_current_effect_value():
	"""Возвращает текущее значение эффекта (зависит от уровня)."""
	if not is_built or current_level <= 0:
		return 0
	
	var levels: Array = config.get("levels", [])
	var idx := current_level - 1
	
	if idx >= 0 and idx < levels.size():
		return levels[idx].get("effect_value", 0)
	
	return 0


func get_level_data(level: int) -> Dictionary:
	"""Возвращает данные уровня."""
	var levels: Array = config.get("levels", [])
	var idx := level - 1
	
	if idx >= 0 and idx < levels.size():
		return levels[idx]
	
	return {}


func get_build_cost() -> int:
	"""Стоимость постройки (первый уровень)."""
	return get_upgrade_cost(1)


func get_upgrade_cost(to_level: int = 0) -> int:
	"""Стоимость апгрейда до указанного уровня (или следующего)."""
	if to_level <= 0:
		to_level = current_level + 1
	
	var level_data := get_level_data(to_level)
	return level_data.get("cost", 0)


func get_next_level_description() -> String:
	"""Описание следующего уровня."""
	var next := current_level + 1
	var level_data := get_level_data(next)
	return level_data.get("description", "Максимальный уровень")


func can_upgrade() -> bool:
	"""Можно ли апгрейдить."""
	return is_built and current_level < get_max_level()


func can_build(base_level: int) -> bool:
	"""Можно ли построить при текущем уровне базы."""
	return not is_built and base_level >= get_min_base_level()


# ----------------------------------------------------------------------------
# ACTIONS
# ----------------------------------------------------------------------------
func build() -> void:
	"""Строит комнату (уровень 1)."""
	current_level = 1
	is_built = true
	apply_effect()


func upgrade() -> bool:
	"""Апгрейдит на следующий уровень. Возвращает успех."""
	if not can_upgrade():
		return false
	
	current_level += 1
	apply_effect()
	return true


func apply_effect() -> void:
	"""Применяет эффект комнаты через EventBus."""
	if not is_built:
		return
	
	var effect_type := get_effect_type()
	var effect_value = get_current_effect_value()
	
	EventBus.room_built.emit(effect_type)
	EventBus.debug("Room effect: " + id + " lv" + str(current_level) + " -> " + effect_type + " = " + str(effect_value), "BASE")


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"id": id,
		"current_level": current_level,
		"is_built": is_built
	}


static func from_dict(data: Dictionary, room_config: Dictionary) -> Room:
	var room := Room.new()
	room.id = data.get("id", "")
	room.config = room_config
	room.current_level = data.get("current_level", 0)
	room.is_built = data.get("is_built", false)
	return room
