# ============================================================================
# NAME GENERATOR — Генерация имени, фамилии и ника
# ============================================================================
# Выбирает имя/фамилию из пула национальности.
# Ник: из пула нации ИЛИ генерируется по шаблонам.
# ============================================================================
class_name NameGenerator
extends RefCounted

# ----------------------------------------------------------------------------
# CACHED DATA
# ----------------------------------------------------------------------------
static var nationalities_data: Dictionary = {}
static var nickname_templates: Dictionary = {}
static var data_loaded: bool = false

# ----------------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------------
static func generate_name(nationality_id: String) -> Dictionary:
	ensure_data_loaded()
	
	var nation_data := get_nationality_data(nationality_id)
	
	if nation_data.is_empty():
		EventBus.debug("Unknown nationality: " + nationality_id, "WARN")
		nation_data = get_nationality_data("russian")  # fallback
	
	var first_name: String = pick_random(nation_data.get("first_names", ["Unknown"]))
	var last_name: String = pick_random(nation_data.get("last_names", ["Player"]))
	var nickname: String = generate_nickname(nation_data)
	
	return {
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname
	}

static func get_all_nationality_ids() -> Array:
	ensure_data_loaded()
	var ids: Array = []
	for nation in nationalities_data.get("nationalities", []):
		ids.append(nation["id"])
	return ids

static func get_random_nationality_id() -> String:
	var ids := get_all_nationality_ids()
	if ids.is_empty():
		return "russian"
	return ids[randi() % ids.size()]

static func get_nationality_display_name(nationality_id: String, lang: String = "ru") -> String:
	ensure_data_loaded()
	var nation_data := get_nationality_data(nationality_id)
	
	if lang == "ru":
		return nation_data.get("name_ru", nationality_id)
	else:
		return nation_data.get("name_en", nationality_id)

static func get_nationality_region(nationality_id: String) -> String:
	ensure_data_loaded()
	var nation_data := get_nationality_data(nationality_id)
	return nation_data.get("region", "UNKNOWN")

static func get_nationality_flag(nationality_id: String) -> String:
	var flags := {
		"russian": "🇷🇺",
		"ukrainian": "🇺🇦",
		"kazakh": "🇰🇿",
		"belarusian": "🇧🇾",
		"swedish": "🇸🇪",
		"danish": "🇩🇰",
		"french": "🇫🇷",
		"german": "🇩🇪",
		"polish": "🇵🇱",
		"brazilian": "🇧🇷",
		"argentinian": "🇦🇷",
		"chinese": "🇨🇳",
		"korean": "🇰🇷",
		"turkish": "🇹🇷",
		"saudi": "🇸🇦"
	}
	return flags.get(nationality_id, "🏳️")

# ----------------------------------------------------------------------------
# NICKNAME GENERATION
# ----------------------------------------------------------------------------
static func generate_nickname(nation_data: Dictionary) -> String:
	# 60% из пула нации, 40% генерируем
	if randf() < 0.6:
		var nation_nicks: Array = nation_data.get("nicknames", [])
		if not nation_nicks.is_empty():
			return pick_random(nation_nicks)
	
	return generate_template_nickname()

static func generate_template_nickname() -> String:
	var templates: Array = nickname_templates.get("templates", [])
	if templates.is_empty():
		return "Player" + str(randi_range(1, 999))
	
	var template: Dictionary = templates[randi() % templates.size()]
	var nick: String = ""
	
	match template.get("type", ""):
		"noun":
			nick = pick_random(template.get("words", ["Ghost"]))
		"adjective_noun":
			var adj: String = pick_random(template.get("adjectives", ["Dark"]))
			var noun: String = pick_random(template.get("nouns", ["Star"]))
			nick = adj + noun
		"leet_name":
			nick = pick_random(template.get("patterns", ["n00b"]))
		"short":
			nick = pick_random(template.get("words", ["Nex"]))
		_:
			nick = "Player"
	
	# Иногда добавляем суффикс
	if randf() < 0.25:
		var suffixes: Array = nickname_templates.get("number_suffixes", [""])
		nick += pick_random(suffixes)
	
	return nick

# ----------------------------------------------------------------------------
# DATA LOADING
# ----------------------------------------------------------------------------
static func ensure_data_loaded() -> void:
	if data_loaded:
		return
	
	load_nationalities()
	load_nickname_templates()
	data_loaded = true

static func load_nationalities() -> void:
	var file := FileAccess.open("res://data/player_generation/nationalities.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			nationalities_data = json.data
		else:
			EventBus.debug("Failed to parse nationalities.json", "ERROR")
	else:
		EventBus.debug("Failed to load nationalities.json", "ERROR")

static func load_nickname_templates() -> void:
	var file := FileAccess.open("res://data/player_generation/nickname_templates.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK:
			nickname_templates = json.data
		else:
			EventBus.debug("Failed to parse nickname_templates.json", "ERROR")
	else:
		EventBus.debug("Failed to load nickname_templates.json", "ERROR")

static func get_nationality_data(nationality_id: String) -> Dictionary:
	for nation in nationalities_data.get("nationalities", []):
		if nation.get("id", "") == nationality_id:
			return nation
	return {}

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
static func pick_random(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]
