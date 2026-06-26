extends Control

@onready var bg: ColorRect = $BG
@onready var hair_bg_rect: TextureRect = $HairBg
@onready var body_rect: TextureRect = $Body
@onready var jersey_rect: TextureRect = $Jersey
@onready var head_rect: TextureRect = $Head

@onready var ear_l: TextureRect = $EarL
@onready var ear_r: TextureRect = $EarR

@onready var misc_line_rect: TextureRect = $MiscLine
@onready var mouth_rect: TextureRect = $Mouth

@onready var eye_line: TextureRect = $EyeLine

@onready var eye_l: TextureRect = $EyeL
@onready var eye_r: TextureRect = $EyeR

@onready var eyebrow_l: TextureRect = $EyebrowL
@onready var eyebrow_r: TextureRect = $EyebrowR

@onready var nose_rect: TextureRect = $Nose
@onready var facial_hair_rect: TextureRect = $FacialHair
@onready var hair_rect: TextureRect = $Hair
@onready var glasses_rect: TextureRect = $Glasses

var _config: Dictionary = {}

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	var file = FileAccess.open("res://data/player_generation/appearance_config.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_config = json.data
		file.close()

func setup(app_data: Dictionary, role: String = "entry", team_color_hex: String = "") -> void:
	if _config.is_empty():
		_load_config()
		
	var skin_color = Color.html(AppearanceBuilder.get_skin_tone_color(app_data.get("skin_tone", 1)))
	var hair_color = Color.WHITE
	if app_data.get("hair_color", -1) >= 0:
		hair_color = Color.html(AppearanceBuilder.get_hair_color(app_data.get("hair_color", 0)))
		
	var team_color = Color.WHITE
	if team_color_hex != "":
		team_color = Color.html(team_color_hex)
		
	# 1. Отключаем ВСЕ слои (очищаем редакторские заглушки)
	for child in get_children():
		if child is TextureRect:
			child.texture = null
			child.visible = false
			
	# 2. Рендерим базу
	_apply_texture_multi([body_rect], "bodies", app_data.get("body", -1), skin_color)
	_apply_texture_multi([jersey_rect], "jerseys", app_data.get("jersey", 0), team_color)
	_apply_texture_multi([head_rect], "face_shapes", app_data.get("face_shape", -1), skin_color)
	
	# 3. Глаза и Уши (Дублируются на L и R)
	_apply_texture_multi([ear_l, ear_r], "ears", app_data.get("ears", -1), skin_color)
	_apply_texture_multi([eye_l, eye_r], "eyes", app_data.get("eyes", -1))
	if eye_line != null:
		_apply_texture_multi([eye_line], "eye_lines", app_data.get("eye_line", -1))
		
	# 4. Нос и Мимические Линии
	_apply_texture_multi([nose_rect], "noses", app_data.get("nose", -1), skin_color)
	if misc_line_rect != null:
		_apply_texture_multi([misc_line_rect], "misc_lines", app_data.get("misc_line", -1))
		
	# Обработка заднего фона волос (HairBg)
	if hair_bg_rect != null:
		hair_bg_rect.texture = null
		hair_bg_rect.visible = false
		
		var hair_idx = app_data.get("hairstyle", -1)
		if hair_idx >= 0:
			var hair_items = _config.get("hairstyles", [])
			if hair_idx < hair_items.size():
				var hair_item = hair_items[hair_idx]
				if hair_item.has("name"):
					var hair_name = hair_item["name"]
					var bg_items = _config.get("hair_bgs", [])
					for bg_item in bg_items:
						if bg_item["name"] == hair_name:
							var path = "res://assets/avatars/hairBg/" + bg_item["file"]
							if FileAccess.file_exists(path):
								var tex = load(path)
								hair_bg_rect.texture = tex
								hair_bg_rect.modulate = hair_color
								hair_bg_rect.visible = true
							break

func _apply_texture_multi(rects: Array, category: String, idx: int, mod_color: Color = Color.WHITE) -> Dictionary:
	if idx < 0:
		for r in rects:
			if r != null:
				r.texture = null
				r.visible = false
		return {}
		
	var items = _config.get(category, [])
	if items.is_empty(): 
		for r in rects:
			if r != null:
				r.texture = null
				r.visible = false
		return {}
		
	var safe_idx = clampi(idx, 0, items.size() - 1)
	var item = items[safe_idx]
	var path = "res://assets/avatars/" + _get_folder(category) + "/" + item["file"]
	
	var tex = null
	if FileAccess.file_exists(path):
		tex = load(path)
		
	for r in rects:
		if r != null:
			r.texture = tex
			r.modulate = mod_color
			if tex:
				r.visible = true
			
	return item

func _get_folder(category: String) -> String:
	match category:
		"bodies": return "body"
		"face_shapes": return "head"
		"ears": return "ear"
		"eyes": return "eye"
		"noses": return "nose"
		"mouths": return "mouth"
		"hairstyles": return "hair"
		"hair_bgs": return "hairBg"
		"facial_hair": return "facialHair"
		"eyebrows": return "eyebrow"
		"glasses": return "glasses"
		"jerseys": return "jersey"
		"eye_lines": return "eyeLine"
		"misc_lines": return "miscLine"
	return ""
