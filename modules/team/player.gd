# ============================================================================
# PLAYER — Класс игрока
# ============================================================================
# Resource-класс для хранения данных игрока.
# Может сериализоваться в Dictionary для сохранения.
# ============================================================================

class_name Player
extends Resource

# ----------------------------------------------------------------------------
# IDENTITY
# ----------------------------------------------------------------------------
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var nickname: String = ""
@export var nationality: String = ""
@export var region: String = ""

# ----------------------------------------------------------------------------
# ATTRIBUTES
# ----------------------------------------------------------------------------
@export var age: int = 18
@export var potential: int = 50  # Скрытый, 1-100
@export var role: String = "entry"  # entry, awper, support, lurker, igl

# ----------------------------------------------------------------------------
# COMBAT SKILLS (1-100)
# ----------------------------------------------------------------------------
@export var aim: int = 50
@export var utility: int = 50
@export var clutch: int = 50
@export var game_sense: int = 50

# ----------------------------------------------------------------------------
# MENTAL SKILLS (1-100)
# ----------------------------------------------------------------------------
@export var tilt_resistance: int = 50
@export var motivation: int = 50
@export var communication: int = 50
@export var pressure: int = 50
@export var discipline: int = 50

# ----------------------------------------------------------------------------
# STATUS
# ----------------------------------------------------------------------------
@export var popularity: int = 0
@export var morale: int = 75  # Текущее настроение, 0-100
@export var fatigue: int = 0  # Усталость, 0-100

# ----------------------------------------------------------------------------
# CONTRACT
# ----------------------------------------------------------------------------
@export var salary: int = 1000
@export var contract_seasons_left: int = 0  # 0 = свободный агент

# ----------------------------------------------------------------------------
# APPEARANCE
# ----------------------------------------------------------------------------
@export var appearance: Dictionary = {}

# ----------------------------------------------------------------------------
# STATS
# ----------------------------------------------------------------------------
@export var matches_played: int = 0
@export var rounds_played: int = 0
@export var kills: int = 0
@export var deaths: int = 0
@export var clutches_won: int = 0
@export var clutches_total: int = 0


# ----------------------------------------------------------------------------
# STATIC FACTORY
# ----------------------------------------------------------------------------
static func from_dict(data: Dictionary) -> Player:
	var player := Player.new()
	
	# Identity
	player.id = data.get("id", "")
	player.first_name = data.get("first_name", "")
	player.last_name = data.get("last_name", "")
	player.nickname = data.get("nickname", "")
	player.nationality = data.get("nationality", "")
	player.region = data.get("region", "")
	
	# Attributes
	player.age = data.get("age", 18)
	player.potential = data.get("potential", 50)
	player.role = data.get("role", "entry")
	
	# Combat skills
	var combat: Dictionary = data.get("combat_skills", {})
	player.aim = combat.get("aim", 50)
	player.utility = combat.get("utility", 50)
	player.clutch = combat.get("clutch", 50)
	player.game_sense = combat.get("game_sense", 50)
	
	# Mental skills
	var mental: Dictionary = data.get("mental_skills", {})
	player.tilt_resistance = mental.get("tilt_resistance", 50)
	player.motivation = mental.get("motivation", 50)
	player.communication = mental.get("communication", 50)
	player.pressure = mental.get("pressure", 50)
	player.discipline = mental.get("discipline", 50)
	
	# Status
	player.popularity = data.get("popularity", 0)
	player.morale = data.get("morale", 75)
	player.fatigue = data.get("fatigue", 0)
	
	# Contract
	var contract: Dictionary = data.get("contract", {})
	player.salary = contract.get("salary", 1000)
	player.contract_seasons_left = contract.get("seasons_left", 0)
	
	# Appearance
	player.appearance = data.get("appearance", {})
	
	# Stats
	var stats: Dictionary = data.get("stats", {})
	player.matches_played = stats.get("matches_played", 0)
	player.rounds_played = stats.get("rounds_played", 0)
	player.kills = stats.get("kills", 0)
	player.deaths = stats.get("deaths", 0)
	player.clutches_won = stats.get("clutches_won", 0)
	player.clutches_total = stats.get("clutches_total", 0)
	
	return player


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"nickname": nickname,
		"nationality": nationality,
		"region": region,
		"age": age,
		"potential": potential,
		"role": role,
		"combat_skills": {
			"aim": aim,
			"utility": utility,
			"clutch": clutch,
			"game_sense": game_sense
		},
		"mental_skills": {
			"tilt_resistance": tilt_resistance,
			"motivation": motivation,
			"communication": communication,
			"pressure": pressure,
			"discipline": discipline
		},
		"popularity": popularity,
		"morale": morale,
		"fatigue": fatigue,
		"contract": {
			"salary": salary,
			"seasons_left": contract_seasons_left
		},
		"appearance": appearance,
		"stats": {
			"matches_played": matches_played,
			"rounds_played": rounds_played,
			"kills": kills,
			"deaths": deaths,
			"clutches_won": clutches_won,
			"clutches_total": clutches_total
		}
	}


# ----------------------------------------------------------------------------
# COMPUTED PROPERTIES
# ----------------------------------------------------------------------------
func get_full_name() -> String:
	return first_name + " \"" + nickname + "\" " + last_name


func get_display_name() -> String:
	return nickname


func get_overall_combat() -> int:
	return (aim + utility + clutch + game_sense) / 4


func get_overall_mental() -> int:
	return (tilt_resistance + motivation + communication + pressure + discipline) / 5


func get_overall_rating() -> int:
	return (get_overall_combat() * 2 + get_overall_mental()) / 3


func get_kd_ratio() -> float:
	if deaths == 0:
		return float(kills)
	return float(kills) / float(deaths)


func is_free_agent() -> bool:
	return contract_seasons_left <= 0


func get_role_display() -> String:
	return PlayerGenerator.get_role_display_name(role)


func get_nationality_display(lang: String = "ru") -> String:
	return NameGenerator.get_nationality_display_name(nationality, lang)


# ----------------------------------------------------------------------------
# STATE MODIFIERS
# ----------------------------------------------------------------------------
func add_fatigue(amount: int) -> void:
	fatigue = clampi(fatigue + amount, 0, 100)


func rest(amount: int) -> void:
	fatigue = clampi(fatigue - amount, 0, 100)


func change_morale(amount: int) -> void:
	morale = clampi(morale + amount, 0, 100)


func age_up() -> void:
	age += 1
	# TODO: возрастное падение скиллов
