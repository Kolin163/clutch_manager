# ============================================================================
# BASE MANAGER — Управление базой команды
# ============================================================================
# Уровни базы: Гараж(1) → Квартира(2) → Офис(3) → Штаб(4)
# Каждый уровень открывает больше слотов комнат.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const BASE_LEVELS := {
	1: {"name": "Гараж", "name_en": "Garage", "max_rooms": 2, "upgrade_cost": 0},
	2: {"name": "Квартира", "name_en": "Apartment", "max_rooms": 4, "upgrade_cost": 5000},
	3: {"name": "Офис", "name_en": "Office", "max_rooms": 6, "upgrade_cost": 15000},
	4: {"name": "Штаб", "name_en": "HQ", "max_rooms": 7, "upgrade_cost": 40000}
}

const MAX_BASE_LEVEL := 4

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var base_level: int = 1
var rooms: Array[Room] = []
var transport: Transport = Transport.new()

var _rooms_config: Array = []
var _data_loaded: bool = false


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_load_rooms_config()
	EventBus.debug("BaseManager ready, level: " + str(base_level), "BASE")


# ----------------------------------------------------------------------------
# PUBLIC API — BASE
# ----------------------------------------------------------------------------
func get_base_level() -> int:
	return base_level


func get_base_name() -> String:
	return BASE_LEVELS.get(base_level, {}).get("name", "Гараж")


func get_max_rooms() -> int:
	return BASE_LEVELS.get(base_level, {}).get("max_rooms", 2)


func get_built_rooms_count() -> int:
	var count: int = 0
	for room in rooms:
		if room.is_built:
			count += 1
	return count


func has_room_slots() -> bool:
	return get_built_rooms_count() < get_max_rooms()


func get_base_upgrade_cost() -> int:
	var next := base_level + 1
	return BASE_LEVELS.get(next, {}).get("upgrade_cost", 0)


func can_upgrade_base() -> bool:
	return base_level < MAX_BASE_LEVEL


func upgrade_base() -> bool:
	"""Переезд на следующий уровень базы."""
	if not can_upgrade_base():
		EventBus.debug("Base already max level", "WARN")
		return false
	
	var cost := get_base_upgrade_cost()
	if not EconomyManager.can_afford(cost):
		EventBus.debug("Cannot afford base upgrade: $" + str(cost), "WARN")
		return false
	
	EconomyManager.spend_money(cost, "base_upgrade")
	base_level += 1
	GameManager.player_team_data["base_level"] = base_level
	
	EventBus.base_upgraded.emit(base_level)
	EventBus.debug("Base upgraded to: " + get_base_name() + " (level " + str(base_level) + ")", "BASE")
	return true


# ----------------------------------------------------------------------------
# PUBLIC API — ROOMS
# ----------------------------------------------------------------------------
func get_all_rooms_config() -> Array:
	"""Все конфиги комнат из JSON."""
	_ensure_data_loaded()
	return _rooms_config


func get_room(room_id: String) -> Room:
	"""Возвращает комнату по ID (или null)."""
	for room in rooms:
		if room.id == room_id:
			return room
	return null


func get_built_rooms() -> Array[Room]:
	"""Все построенные комнаты."""
	var result: Array[Room] = []
	for room in rooms:
		if room.is_built:
			result.append(room)
	return result


func get_available_to_build() -> Array[Dictionary]:
	"""Комнаты которые можно построить."""
	_ensure_data_loaded()
	var result: Array[Dictionary] = []
	
	for config in _rooms_config:
		var room_id: String = config.get("id", "")
		var existing := get_room(room_id)
		
		if existing != null and existing.is_built:
			continue
		
		var min_base: int = config.get("min_base_level", 1)
		if base_level >= min_base:
			result.append(config)
	
	return result


func build_room(room_id: String) -> bool:
	"""Строит комнату. Возвращает успех."""
	if not has_room_slots():
		EventBus.debug("No room slots available", "WARN")
		return false
	
	var config := _get_room_config(room_id)
	if config.is_empty():
		EventBus.debug("Unknown room: " + room_id, "ERROR")
		return false
	
	# Проверяем уровень базы
	var min_base: int = config.get("min_base_level", 1)
	if base_level < min_base:
		EventBus.debug("Base level too low for: " + room_id, "WARN")
		return false
	
	# Проверяем не построена ли уже
	var existing := get_room(room_id)
	if existing != null and existing.is_built:
		EventBus.debug("Room already built: " + room_id, "WARN")
		return false
	
	# Проверяем деньги
	var room := Room.create(config)
	var cost := room.get_build_cost()
	
	if not EconomyManager.can_afford(cost):
		EventBus.debug("Cannot afford room: $" + str(cost), "WARN")
		return false
	
	# Строим
	EconomyManager.spend_money(cost, "build_" + room_id)
	room.build()
	
	# Добавляем или заменяем
	if existing != null:
		var idx := rooms.find(existing)
		rooms[idx] = room
	else:
		rooms.append(room)
	
	EventBus.room_built.emit(room_id)
	EventBus.debug("Room built: " + room.get_room_name() + " ($" + str(cost) + ")", "BASE")
	return true


func upgrade_room(room_id: String) -> bool:
	"""Апгрейдит комнату. Возвращает успех."""
	var room := get_room(room_id)
	if room == null or not room.is_built:
		EventBus.debug("Room not built: " + room_id, "WARN")
		return false
	
	if not room.can_upgrade():
		EventBus.debug("Room at max level: " + room_id, "WARN")
		return false
	
	var cost := room.get_upgrade_cost()
	if not EconomyManager.can_afford(cost):
		EventBus.debug("Cannot afford upgrade: $" + str(cost), "WARN")
		return false
	
	EconomyManager.spend_money(cost, "upgrade_" + room_id)
	room.upgrade()
	
	EventBus.room_upgraded.emit(room_id, room.current_level)
	EventBus.debug("Room upgraded: " + room.get_room_name() + " -> lv" + str(room.current_level), "BASE")
	return true


# ----------------------------------------------------------------------------
# PUBLIC API — TRANSPORT
# ----------------------------------------------------------------------------
func get_transport() -> Transport:
	return transport


func upgrade_transport() -> bool:
	"""Улучшает транспорт."""
	# Нужен гараж
	var garage := get_room("garage")
	if garage == null or not garage.is_built:
		EventBus.debug("Build garage first", "WARN")
		return false
	
	if not transport.can_upgrade():
		EventBus.debug("Transport at max level", "WARN")
		return false
	
	var cost := transport.get_upgrade_cost()
	if not EconomyManager.can_afford(cost):
		EventBus.debug("Cannot afford transport: $" + str(cost), "WARN")
		return false
	
	EconomyManager.spend_money(cost, "transport_upgrade")
	transport.upgrade()
	GameManager.player_team_data["transport"] = transport.current_id
	return true


# ----------------------------------------------------------------------------
# EFFECT QUERIES
# ----------------------------------------------------------------------------
func get_training_speed_bonus() -> float:
	var room := get_room("training_room")
	if room == null or not room.is_built:
		return 0.0
	return room.get_current_effect_value()


func get_training_quality_bonus() -> float:
	var room := get_room("server_room")
	if room == null or not room.is_built:
		return 0.0
	return room.get_current_effect_value()


func get_stream_income() -> int:
	var room := get_room("stream_room")
	if room == null or not room.is_built:
		return 0
	return room.get_current_effect_value()


func get_mental_recovery_bonus() -> float:
	var room := get_room("rest_zone")
	if room == null or not room.is_built:
		return 0.0
	return room.get_current_effect_value()


func get_staff_slots() -> int:
	var room := get_room("manager_office")
	if room == null or not room.is_built:
		return 0
	return room.get_current_effect_value()


func get_contract_discount() -> float:
	var room := get_room("meeting_room")
	if room == null or not room.is_built:
		return 0.0
	return room.get_current_effect_value()


func has_garage() -> bool:
	var room := get_room("garage")
	return room != null and room.is_built


# ----------------------------------------------------------------------------
# DATA LOADING
# ----------------------------------------------------------------------------
func _ensure_data_loaded() -> void:
	if not _data_loaded:
		_load_rooms_config()


func _load_rooms_config() -> void:
	var file := FileAccess.open("res://data/items/rooms.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_rooms_config = json.data.get("rooms", [])
			_data_loaded = true
		file.close()
	else:
		EventBus.debug("Failed to load rooms.json", "ERROR")


func _get_room_config(room_id: String) -> Dictionary:
	_ensure_data_loaded()
	for config in _rooms_config:
		if config.get("id", "") == room_id:
			return config
	return {}


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var rooms_data: Array = []
	for room in rooms:
		rooms_data.append(room.to_dict())
	
	return {
		"base_level": base_level,
		"rooms": rooms_data,
		"transport": transport.to_dict()
	}


func from_dict(data: Dictionary) -> void:
	_ensure_data_loaded()
	
	base_level = data.get("base_level", 1)
	
	rooms.clear()
	for room_data in data.get("rooms", []):
		var room_id: String = room_data.get("id", "")
		var config := _get_room_config(room_id)
		if not config.is_empty():
			var room := Room.from_dict(room_data, config)
			rooms.append(room)
	
	var transport_data: Dictionary = data.get("transport", {})
	if not transport_data.is_empty():
		transport.load_from_dict(transport_data)
	
	EventBus.debug("Base loaded: " + get_base_name() + ", rooms: " + str(get_built_rooms_count()), "BASE")
