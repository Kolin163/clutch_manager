extends Control

@onready var bg: ColorRect = $BG
@onready var hair_bg_rect: TextureRect = $HairBg
@onready var body_rect: TextureRect = $Body
@onready var jersey_rect: TextureRect = $Jersey
@onready var head_rect: TextureRect = $Head
@onready var ears_rect: TextureRect = $Ears
@onready var misc_line_rect: TextureRect = $MiscLine
@onready var smile_line_rect: TextureRect = $SmileLine
@onready var mouth_rect: TextureRect = $Mouth
@onready var eye_line_rect: TextureRect = $EyeLine
@onready var eyes_rect: TextureRect = $Eyes
@onready var eyebrows_rect: TextureRect = $Eyebrows
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

func setup(app_data: Dictionary, role: String = "entry") -> void:
	if _config.is_empty():
		_load_config()
		
	var skin_color = Color.html(AppearanceBuilder.get_skin_tone_color(app_data.get("skin_tone", 1)))
	var hair_color = Color.WHITE
	if app_data.get("hair_color", -1) >= 0:
		hair_color = Color.html(AppearanceBuilder.get_hair_color(app_data.get("hair_color", 0)))
		
	# 1. Сначала отключаем ВСЕ слои (прячем их)
	for child in get_children():
		if child is TextureRect:
			child.texture = null
			child.visible = false
			
	# 2. Рендерим только Body, Jersey, Head
	var b_item = _apply_texture(body_rect, "bodies", app_data.get("body", -1), skin_color)
	if not b_item.is_empty(): body_rect.visible = true
	
	var j_item = _apply_texture(jersey_rect, "jerseys", app_data.get("jersey", 0))
	if not j_item.is_empty(): jersey_rect.visible = true
	
	var h_item = _apply_texture(head_rect, "face_shapes", app_data.get("face_shape", -1), skin_color)
	if not h_item.is_empty(): head_rect.visible = true

func _apply_texture(rect: TextureRect, category: String, idx: int, mod_color: Color = Color.WHITE) -> Dictionary:
	if idx < 0:
		rect.texture = null
		return {}
		
	var items = _config.get(category, [])
	if items.is_empty(): 
		rect.texture = null
		return {}
		
	var safe_idx = clampi(idx, 0, items.size() - 1)
	var item = items[safe_idx]
	var path = "res://assets/avatars/" + _get_folder(category) + "/" + item["file"]
	
	if FileAccess.file_exists(path):
		rect.texture = load(path)
		rect.modulate = mod_color
	else:
		rect.texture = null
		
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
		"smile_lines": return "smileLine"
		"misc_lines": return "miscLine"
	return ""
