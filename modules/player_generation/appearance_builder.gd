# ============================================================================
# APPEARANCE BUILDER — Сборка внешности игрока
# ============================================================================
class_name AppearanceBuilder
extends RefCounted

static var _appearance_config: Dictionary = {}
static var _nationalities_data: Dictionary = {}
static var _data_loaded: bool = false

static func build_appearance(nationality_id: String) -> Dictionary:
	_ensure_data_loaded()
	
	var nation_data := _get_nationality_data(nationality_id)
	
	# Тон кожи и форма лица
	var skin_weights: Array = nation_data.get("skin_weights", [1.0])
	var skin_tone_id := _weighted_random(skin_weights)
	
	var face_weights: Array = nation_data.get("face_weights", [1.0])
	var face_shape_id := _weighted_random(face_weights)
	
	# Общие пулы
	var eyes_count: int = _appearance_config.get("eyes", []).size()
	var noses_count: int = _appearance_config.get("noses", []).size()
	var mouths_count: int = _appearance_config.get("mouths", []).size()
	var hairstyles_count: int = _appearance_config.get("hairstyles", []).size()
	var hair_colors_count: int = _appearance_config.get("hair_colors", []).size()
	
	var ears_count: int = _appearance_config.get("ears", []).size()
	var eye_lines_count: int = _appearance_config.get("eye_lines", []).size()
	var misc_lines_count: int = _appearance_config.get("misc_lines", []).size()
	var glasses_count: int = _appearance_config.get("glasses", []).size()
	var jerseys_count: int = _appearance_config.get("jerseys", []).size()
	var eyebrows_count: int = _appearance_config.get("eyebrows", []).size()
	var facial_hair_count: int = _appearance_config.get("facial_hair", []).size()
	var bodies_count: int = _appearance_config.get("bodies", []).size()
	
	# Обязательные детали
	var eyes_id := randi() % maxi(eyes_count, 1)
	var nose_id := randi() % maxi(noses_count, 1)
	var mouth_id := randi() % maxi(mouths_count, 1)
	var hairstyle_id := randi() % maxi(hairstyles_count, 1)
	var eyebrow_id := randi() % maxi(eyebrows_count, 1)
	var body_id := randi() % maxi(bodies_count, 1)
	var ear_id := randi() % maxi(ears_count, 1)
	var jersey_id := randi() % maxi(jerseys_count, 1)
	
	# Опциональные элементы (шансы)
	var facial_hair_id := -1
	if randf() < 0.35: facial_hair_id = randi() % maxi(facial_hair_count, 1)
	
	var eye_line_id := -1
	if randf() < 0.4: eye_line_id = randi() % maxi(eye_lines_count, 1)
	
	var misc_line_id := -1
	if randf() < 0.4: misc_line_id = randi() % maxi(misc_lines_count, 1)
	
	var glasses_id := -1
	if randf() < 0.05: glasses_id = randi() % maxi(glasses_count, 1)
	
	var hair_color_id := randi() % maxi(hair_colors_count, 1)
	
	# Проверяем, применим ли цвет волос
	var hairstyle_data := _get_hairstyle_data(hairstyle_id)
	if not hairstyle_data.get("color_applicable", true):
		hair_color_id = -1
	
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
	return "#FFCD94"

static func get_hair_color(hair_color_id: int) -> String:
	_ensure_data_loaded()
	var hair_colors: Array = _appearance_config.get("hair_colors", [])
	if hair_color_id >= 0 and hair_color_id < hair_colors.size():
		return hair_colors[hair_color_id].get("color", "#3D2314")
	return "#3D2314"

static func _ensure_data_loaded() -> void:
	if _data_loaded: return
	
	var file1 = FileAccess.open("res://data/player_generation/appearance_config.json", FileAccess.READ)
	if file1:
		var json1 = JSON.new()
		if json1.parse(file1.get_as_text()) == OK:
			_appearance_config = json1.data
		file1.close()
		
	var file2 = FileAccess.open("res://data/player_generation/nationalities.json", FileAccess.READ)
	if file2:
		var json2 = JSON.new()
		if json2.parse(file2.get_as_text()) == OK:
			var nats: Array = json2.data.get("nationalities", [])
			for n in nats:
				_nationalities_data[n["id"]] = n
		file2.close()
		
	_data_loaded = true

static func _get_nationality_data(id: String) -> Dictionary:
	return _nationalities_data.get(id, _nationalities_data.get("usa", {}))

static func _get_hairstyle_data(id: int) -> Dictionary:
	_ensure_data_loaded()
	var hairstyles: Array = _appearance_config.get("hairstyles", [])
	if id >= 0 and id < hairstyles.size():
		return hairstyles[id]
	return {}

static func _weighted_random(weights: Array) -> int:
	var total: float = 0.0
	for w in weights: total += w
	var roll := randf() * total
	var current: float = 0.0
	for i in range(weights.size()):
		current += weights[i]
		if roll <= current:
			return i
	return weights.size() - 1
