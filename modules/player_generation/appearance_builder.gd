# ============================================================================
# APPEARANCE BUILDER — Сборка внешности игрока
# ============================================================================
# Собирает слои внешности в Dictionary на основе национальности.
# Каждый слой — индекс/ID который потом рендерится в UI.
# ============================================================================

class_name AppearanceBuilder
extends RefCounted

# ----------------------------------------------------------------------------
# CACHED DATA
# ----------------------------------------------------------------------------
static var _appearance_config: Dictionary = {}
static var _nationalities_data: Dictionary = {}
static var _data_loaded: bool = false


# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
static func build_appearance(nationality_id: String) -> Dictionary:
	_ensure_data_loaded()
	
	var nation_data := _get_nationality_data(nationality_id)
	
	# Тон кожи по весам национальности
	var skin_weights: Array = nation_data.get("skin_weights", [1.0])
	var skin_tone_id := _weighted_random(skin_weights)
	
	# Форма лица по весам национальности
	var face_weights: Array = nation_data.get("face_weights", [1.0])
	var face_shape_id := _weighted_random(face_weights)
	
	# Остальное — рандом из общих пулов
	var eyes_count: int = _appearance_config.get("eyes", []).size()
	var noses_count: int = _appearance_config.get("noses", []).size()
	var mouths_count: int = _appearance_config.get("mouths", []).size()
	var hairstyles_count: int = _appearance_config.get("hairstyles", []).size()
	var hair_colors_count: int = _appearance_config.get("hair_colors", []).size()
	
	var eyes_id := randi() % maxi(eyes_count, 1)
	var nose_id := randi() % maxi(noses_count, 1)
	var mouth_id := randi() % maxi(mouths_count, 1)
	var hairstyle_id := randi() % maxi(hairstyles_count, 1)
	
	var eyebrows_count: int = _appearance_config.get("eyebrows", []).size()
	var facial_hair_count: int = _appearance_config.get("facial_hair", []).size()
	var bodies_count: int = _appearance_config.get("bodies", []).size()
	var ears_count: int = _appearance_config.get("ears", []).size()
	var eye_lines_count: int = _appearance_config.get("eye_lines", []).size()
	var smile_lines_count: int = _appearance_config.get("smile_lines", []).size()
	var misc_lines_count: int = _appearance_config.get("misc_lines", []).size()
	var glasses_count: int = _appearance_config.get("glasses", []).size()
	var jerseys_count: int = _appearance_config.get("jerseys", []).size()
	
	var eyebrow_id := randi() % maxi(eyebrows_count, 1)
	var body_id := randi() % maxi(bodies_count, 1)
	var ear_id := randi() % maxi(ears_count, 1)
	var jersey_id := randi() % maxi(jerseys_count, 1)
	
	# Опциональные элементы (шансы)
	var facial_hair_id := -1
	if randf() < 0.35: facial_hair_id = randi() % maxi(facial_hair_count, 1)
	
	var eye_line_id := -1
	if randf() < 0.4: eye_line_id = randi() % maxi(eye_lines_count, 1)
	
	var smile_line_id := -1
	if randf() < 0.4: smile_line_id = randi() % maxi(smile_lines_count, 1)
	
	var misc_line_id := -1
	if randf() < 0.4: misc_line_id = randi() % maxi(misc_lines_count, 1)
	
	var glasses_id := -1
	if randf() < 0.05: glasses_id = randi() % maxi(glasses_count, 1)
	var hair_color_id := randi() % maxi(hair_colors_count, 1)
	
	# Проверяем, применим ли цвет волос (лысый = нет)
	var hairstyle_data := _get_hairstyle_data(hairstyle_id)
	if not hairstyle_data.get("color_applicable", true):
		hair_color_id = -1  # Нет цвета для лысых
	
	return {
		"skin_tone": skin_tone_id,
		"face_shape": face_shape_id,
		"eyes": eyes_id,
		"nose": nose_id,
		"mouth": mouth_id,
		"hairstyle": hairstyle_id,
		"eyebrows": eyebrow_id,
		"facial_hair": facial_hair_id,
		"body": body_id,
		"ears": ear_id,
		"eye_line": eye_line_id,
		"smile_line": smile_line_id,
		"misc_line": misc_line_id,
		"glasses": glasses_id,
		"jersey": jersey_id,
		"hair_color": hair_color_id
	}


static func get_skin_tone_color(skin_tone_id: int) -> String:
	_ensure_data_loaded()
	var skin_tones: Array = _appearance_config.get("skin_tones", [])
	
	if skin_tone_id >= 0 and skin_tone_id < skin_tones.size():
		return skin_tones[skin_tone_id].get("color", "#FFCD94")
	
	return "#FFCD94"  # default


static func get_hair_color(hair_color_id: int) -> String:
	_ensure_data_loaded()
	var hair_colors: Array = _appearance_config.get("hair_colors", [])
	
	if hair_color_id >= 0 and hair_color_id < hair_colors.size():
		return hair_colors[hair_color_id].get("color", "#3D2314")
	
	return "#3D2314"  # default dark brown


static func get_face_shape_name(face_shape_id: int) -> String:
	_ensure_data_loaded()
	var face_shapes: Array = _appearance_config.get("face_shapes", [])
	
	if face_shape_id >= 0 and face_shape_id < face_shapes.size():
		return face_shapes[face_shape_id].get("name", "oval")
	
	return "oval"


static func get_hairstyle_name(hairstyle_id: int) -> String:
	_ensure_data_loaded()
	var hairstyles: Array = _appearance_config.get("hairstyles", [])
	
	if hairstyle_id >= 0 and hairstyle_id < hairstyles.size():
		return hairstyles[hairstyle_id].get("name", "short")
	
	return "short"


# ----------------------------------------------------------------------------
# DATA LOADING
# ----------------------------------------------------------------------------
static func _ensure_data_loaded() -> void:
	if _data_loaded:
		return
	
	_load_appearance_config()
	_load_nationalities()
	_data_loaded = true


static func _load_appearance_config() -> void:
	var file := FileAccess.open("res://data/player_generation/appearance_config.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			_appearance_config = json.data
		else:
			EventBus.debug("Failed to parse appearance_config.json", "ERROR")
	else:
		EventBus.debug("Failed to load appearance_config.json", "ERROR")


static func _load_nationalities() -> void:
	var file := FileAccess.open("res://data/player_generation/nationalities.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			_nationalities_data = json.data
		else:
			EventBus.debug("Failed to parse nationalities.json", "ERROR")
	else:
		EventBus.debug("Failed to load nationalities.json", "ERROR")


static func _get_nationality_data(nationality_id: String) -> Dictionary:
	for nation in _nationalities_data.get("nationalities", []):
		if nation.get("id", "") == nationality_id:
			return nation
	return {}


static func _get_hairstyle_data(hairstyle_id: int) -> Dictionary:
	var hairstyles: Array = _appearance_config.get("hairstyles", [])
	if hairstyle_id >= 0 and hairstyle_id < hairstyles.size():
		return hairstyles[hairstyle_id]
	return {}


# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
static func _weighted_random(weights: Array) -> int:
	if weights.is_empty():
		return 0
	
	var total: float = 0.0
	for w in weights:
		total += float(w)
	
	if total <= 0:
		return 0
	
	var roll := randf() * total
	var cumulative: float = 0.0
	
	for i in range(weights.size()):
		cumulative += float(weights[i])
		if roll <= cumulative:
			return i
	
	return weights.size() - 1
