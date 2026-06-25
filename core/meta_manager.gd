# ============================================================================
# META MANAGER — Мета, ротация карт, патч-ноты
# ============================================================================
# Хранит активный пресет меты с вариациями. Ротирует карты.
# match_engine и tactic_selector читают модификаторы отсюда.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const ACTIVE_MAP_POOL_SIZE := 8  # Из 15 карт, 8 активны
const MAPS_TO_ROTATE := 2  # Сколько карт меняется при ротации
const VARIATION_MIN := 0.8  # ±20% вариации к пресету
const VARIATION_MAX := 1.2

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var current_preset: Dictionary = {}
var current_preset_id: String = ""
var active_map_pool: Array[Dictionary] = []
var removed_maps: Array[String] = []
var added_maps: Array[String] = []
var previous_preset_id: String = ""

var _all_presets: Array = []
var _all_maps: Array = []
var _data_loaded: bool = false
var _maps_loaded: bool = false


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_load_presets()
	_load_all_maps()
	EventBus.debug("MetaManager ready", "META")


# ----------------------------------------------------------------------------
# PUBLIC API — META
# ----------------------------------------------------------------------------
func get_current_meta() -> Dictionary:
	return current_preset

func get_meta_name() -> String:
	return current_preset.get("name", "Неизвестная мета")

func get_meta_description() -> String:
	return current_preset.get("description", "")

func get_meta_style() -> String:
	return current_preset.get("style", "balanced")


# --- MODIFIERS ---
func get_tactic_modifier(tactic_id: String) -> float:
	var mods: Dictionary = current_preset.get("tactic_modifiers", {})
	return mods.get(tactic_id, 0.0)

func get_role_modifier(role: String) -> int:
	var mods: Dictionary = current_preset.get("role_modifiers", {})
	return mods.get(role, 0)

func get_skill_modifier(skill_name: String) -> float:
	var mods: Dictionary = current_preset.get("skill_modifiers", {})
	return mods.get(skill_name, 0.0)

func get_all_tactic_modifiers() -> Dictionary:
	return current_preset.get("tactic_modifiers", {})

func get_all_role_modifiers() -> Dictionary:
	return current_preset.get("role_modifiers", {})


# --- MAP POOL ---
func get_active_map_pool() -> Array[Dictionary]:
	return active_map_pool

func get_random_active_map() -> Dictionary:
	if active_map_pool.is_empty():
		return {"id": "dust", "name": "Dust", "ct_advantage": 0.0}
	return active_map_pool[randi() % active_map_pool.size()]


# --- META SHIFTS ---
func set_random_meta() -> void:
	_ensure_loaded()
	if _all_presets.is_empty():
		current_preset = {}
		current_preset_id = "balanced"
	else:
		var preset: Dictionary = _all_presets[randi() % _all_presets.size()]
		_apply_preset_with_variation(preset)
	_init_map_pool()


func shift_meta() -> void:
	_ensure_loaded()
	previous_preset_id = current_preset_id
	
	if _all_presets.size() <= 1:
		set_random_meta()
		return
	
	var candidates: Array = []
	for p in _all_presets:
		if p.get("id", "") != current_preset_id:
			candidates.append(p)
	
	if candidates.is_empty():
		set_random_meta()
		return
	
	var preset: Dictionary = candidates[randi() % candidates.size()]
	_apply_preset_with_variation(preset)
	_rotate_map_pool()
	
	EventBus.meta_shifted.emit(current_preset)
	EventBus.debug("Meta shifted to: " + get_meta_name(), "META")


func _apply_preset_with_variation(preset: Dictionary) -> void:
	"""Применяет пресет с рандомными вариациями ±10-20%."""
	current_preset = preset.duplicate(true)
	current_preset_id = preset.get("id", "")
	
	# Варьируем тактические модификаторы
	var tactic_mods: Dictionary = current_preset.get("tactic_modifiers", {})
	for key in tactic_mods.keys():
		var base_val: float = tactic_mods[key]
		if base_val != 0.0:
			tactic_mods[key] = base_val * randf_range(VARIATION_MIN, VARIATION_MAX)
	current_preset["tactic_modifiers"] = tactic_mods
	
	# Варьируем модификаторы ролей
	var role_mods: Dictionary = current_preset.get("role_modifiers", {})
	for key in role_mods.keys():
		var base_val: int = role_mods[key]
		if base_val != 0:
			var variation := randi_range(-2, 2)
			role_mods[key] = base_val + variation
	current_preset["role_modifiers"] = role_mods
	
	# Варьируем модификаторы скиллов
	var skill_mods: Dictionary = current_preset.get("skill_modifiers", {})
	for key in skill_mods.keys():
		var base_val: float = skill_mods[key]
		if base_val != 0.0:
			skill_mods[key] = base_val * randf_range(VARIATION_MIN, VARIATION_MAX)
	current_preset["skill_modifiers"] = skill_mods
	
	EventBus.debug("Meta set with variations: " + get_meta_name(), "META")


# ----------------------------------------------------------------------------
# MAP ROTATION
# ----------------------------------------------------------------------------
func _init_map_pool() -> void:
	"""Начальная инициализация пула карт."""
	_ensure_maps_loaded()
	removed_maps.clear()
	added_maps.clear()
	
	if _all_maps.is_empty():
		return
	
	var shuffled := _all_maps.duplicate()
	shuffled.shuffle()
	
	active_map_pool.clear()
	for i in range(mini(ACTIVE_MAP_POOL_SIZE, shuffled.size())):
		active_map_pool.append(shuffled[i].duplicate(true))


func _rotate_map_pool() -> void:
	"""Ротация: убрать 2-3 карты, добавить 2-3 новых."""
	_ensure_maps_loaded()
	removed_maps.clear()
	added_maps.clear()
	
	if active_map_pool.size() < 4 or _all_maps.size() <= ACTIVE_MAP_POOL_SIZE:
		return
	
	var rotate_count := randi_range(MAPS_TO_ROTATE, MAPS_TO_ROTATE + 1)
	
	# Собираем ID карт НЕ в пуле
	var active_ids: Array[String] = []
	for m in active_map_pool:
		active_ids.append(m.get("id", ""))
	
	var inactive: Array[Dictionary] = []
	for m in _all_maps:
		if not m.get("id", "") in active_ids:
			inactive.append(m)
	
	if inactive.is_empty():
		return
	
	inactive.shuffle()
	
	# Убираем карты из пула
	var pool_copy := active_map_pool.duplicate()
	pool_copy.shuffle()
	
	for i in range(mini(rotate_count, pool_copy.size())):
		var removed_map: Dictionary = pool_copy[i]
		var removed_id: String = removed_map.get("id", "")
		removed_maps.append(removed_map.get("name", removed_id))
		
		# Убираем из active
		for j in range(active_map_pool.size()):
			if active_map_pool[j].get("id", "") == removed_id:
				active_map_pool.remove_at(j)
				break
	
	# Добавляем новые
	for i in range(mini(rotate_count, inactive.size())):
		var new_map: Dictionary = inactive[i].duplicate(true)
		active_map_pool.append(new_map)
		added_maps.append(new_map.get("name", new_map.get("id", "")))
	
	EventBus.debug("Map rotation: removed " + str(removed_maps) + ", added " + str(added_maps), "META")


# ----------------------------------------------------------------------------
# PATCH NOTES
# ----------------------------------------------------------------------------
func get_patch_notes() -> Array[String]:
	var notes: Array[String] = []
	notes.append("=== ПАТЧ " + str(GameManager.current_season) + ": " + get_meta_name() + " ===")
	notes.append("")
	notes.append(get_meta_description())
	notes.append("")
	
	# Тактики
	var tactic_mods: Dictionary = current_preset.get("tactic_modifiers", {})
	if not tactic_mods.is_empty():
		notes.append("[ТАКТИКИ]")
		for tactic_id in tactic_mods.keys():
			var val: float = tactic_mods[tactic_id]
			var sign := "+" if val > 0 else ""
			var tactic_name = TacticSelector.get_tactic_display_name(tactic_id)
			notes.append("  %s: %s%.0f%%" % [tactic_name, sign, val * 100])
		notes.append("")
	
	# Роли
	var role_mods: Dictionary = current_preset.get("role_modifiers", {})
	if not role_mods.is_empty():
		notes.append("[РОЛИ]")
		for role_id in role_mods.keys():
			var val: int = role_mods[role_id]
			var sign := "+" if val > 0 else ""
			var role_name := PlayerGenerator.get_role_display_name(role_id)
			notes.append("  %s: %s%d к скиллам" % [role_name, sign, val])
		notes.append("")
	
	# Скиллы
	var skill_mods: Dictionary = current_preset.get("skill_modifiers", {})
	if not skill_mods.is_empty():
		notes.append("[СКИЛЛЫ]")
		for skill_id in skill_mods.keys():
			var val: float = skill_mods[skill_id]
			notes.append("  %s: +%.0f%% влияние" % [skill_id.capitalize(), val * 100])
		notes.append("")
	
	# Ротация карт
	if not removed_maps.is_empty() or not added_maps.is_empty():
		notes.append("[РОТАЦИЯ КАРТ]")
		for map_name in removed_maps:
			notes.append("  ❌ " + map_name + " убрана из пула")
		for map_name in added_maps:
			notes.append("  ✅ " + map_name + " добавлена в пул")
		notes.append("")
	
	# Активный пул
	notes.append("[АКТИВНЫЕ КАРТЫ]")
	var map_names: Array[String] = []
	for m in active_map_pool:
		map_names.append(m.get("name", "?"))
	notes.append("  " + ", ".join(map_names))
	
	return notes


# ----------------------------------------------------------------------------
# DATA
# ----------------------------------------------------------------------------
func _ensure_loaded() -> void:
	if not _data_loaded:
		_load_presets()

func _ensure_maps_loaded() -> void:
	if not _maps_loaded:
		_load_all_maps()

func _load_presets() -> void:
	var file := FileAccess.open("res://data/meta_presets/meta_presets.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_all_presets = json.data.get("presets", [])
			_data_loaded = true
		file.close()
	else:
		EventBus.debug("Failed to load meta_presets.json", "ERROR")

func _load_all_maps() -> void:
	var file := FileAccess.open("res://data/maps/maps.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_all_maps = json.data.get("maps", [])
			_maps_loaded = true
		file.close()
	else:
		EventBus.debug("Failed to load maps.json", "ERROR")


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"preset_id": current_preset_id,
		"preset": current_preset,
		"previous_preset_id": previous_preset_id,
		"active_map_pool": active_map_pool.duplicate(true),
		"removed_maps": removed_maps.duplicate(),
		"added_maps": added_maps.duplicate()
	}

func from_dict(data: Dictionary) -> void:
	current_preset_id = data.get("preset_id", "")
	current_preset = data.get("preset", {})
	previous_preset_id = data.get("previous_preset_id", "")
	active_map_pool.clear()
	for m in data.get("active_map_pool", []):
		active_map_pool.append(m)
	removed_maps.clear()
	for r in data.get("removed_maps", []):
		removed_maps.append(r)
	added_maps.clear()
	for a in data.get("added_maps", []):
		added_maps.append(a)
	
	if current_preset.is_empty() and not current_preset_id.is_empty():
		_ensure_loaded()
		for p in _all_presets:
			if p.get("id", "") == current_preset_id:
				current_preset = p.duplicate(true)
				break
	
	if active_map_pool.is_empty():
		_init_map_pool()
	
	EventBus.debug("Meta loaded: " + get_meta_name(), "META")
