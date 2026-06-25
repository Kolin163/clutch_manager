# ============================================================================
# SPONSOR MANAGER — Спонсоры (50 вымышленных брендов + проверка дубликатов)
# ============================================================================
extends Node

const MAX_ACTIVE_SPONSORS := 3

# Список из 50 вымышленных брендов
const SPONSOR_NAMES := [
	"CyberStream", "BitNexus", "CoreLogic", "ZenFrame", "WarpDrive",
	"VoltEdge", "NanoChip", "PixelPulse", "QuantumBit", "SiliconSly",
	"ThunderGulp", "ZeroFizz", "NitroFuel", "PlasmaPunch", "HydraBoost",
	"StormDew", "PowerUp", "ManaGlug", "ChillBrew", "SurgeSip",
	"FragWear", "StealthKit", "ApexThread", "ProWrap", "NeonGrip",
	"TitanCase", "GlitchGear", "NovaArmor", "ShadowStitch", "Velocity",
	"CloudLink", "DataHive", "MetaSphere", "ByteBite", "CryptoVault",
	"EchoWeb", "SyncNet", "VoidPoint", "ZenZone", "StarBase",
	"GoldGamble", "BetForge", "CoinShift", "LuckLock", "CreditKey",
	"PrizePool", "WinWire", "RiskReward", "FundFlow", "StackUp"
]

const CONDITION_TYPES := {
	"top_n": {"text": "Финишировать в топ-%d", "param_range": [3, 5]},
	"win_count": {"text": "Выиграть минимум %d матчей", "param_range": [5, 10]},
	"no_last": {"text": "Не занять последнее место", "param_range": []},
	"any": {"text": "Без условий", "param_range": []}
}

var active_sponsors: Array[Dictionary] = []
var available_offers: Array[Dictionary] = []
var rerolls_this_season: int = 0
const MAX_REROLLS_PER_SEASON := 1

func _ready() -> void:
	EventBus.debug("SponsorManager ready with 50 fictional brands", "SPONSOR")

func generate_offers(count: int = 3) -> Array[Dictionary]:
	available_offers.clear()
	
	# 1. Собираем имена, которые уже заняты (активные спонсоры)
	var forbidden_names: Array[String] = []
	for s in active_sponsors:
		forbidden_names.append(s.get("name", ""))
	
	# 2. Создаем пул доступных имен для этого конкретного набора предложений
	var current_pool := []
	for n in SPONSOR_NAMES:
		if not n in forbidden_names:
			current_pool.append(n)
	
	current_pool.shuffle()
	
	var manager_bonus := StaffManager.get_sponsor_bonus()
	
	# 3. Генерируем предложения, следя, чтобы они не повторялись внутри списка
	for i in range(mini(count, current_pool.size())):
		var sponsor_name = current_pool[i]
		
		var cond_keys := CONDITION_TYPES.keys()
		var cond_key: String = cond_keys[randi() % cond_keys.size()]
		var cond_data: Dictionary = CONDITION_TYPES[cond_key]
		var param: int = 0
		var param_range: Array = cond_data.get("param_range", [])
		if not param_range.is_empty():
			param = randi_range(param_range[0], param_range[1])
		
		var base_payment := randi_range(500, 3000)
		var payment := int(float(base_payment) * (1.0 + manager_bonus))
		payment = (payment / 50) * 50
		
		var seasons := randi_range(1, 3)
		var penalty := int(float(payment) * 0.5)
		
		var cond_text: String = cond_data.get("text", "Без условий")
		if cond_text.find("%d") != -1:
			cond_text = cond_text % param
		
		available_offers.append({
			"id": "sponsor_" + str(Time.get_unix_time_from_system()) + "_" + str(randi_range(100, 999)),
			"name": sponsor_name,
			"condition_type": cond_key,
			"condition_param": param,
			"condition_text": cond_text,
			"payment": payment,
			"seasons_total": seasons,
			"seasons_left": seasons,
			"penalty": penalty,
			"active": false
		})
	
	return available_offers

# ... (остальные методы accept/decline/to_dict остаются без изменений)
func accept_offer(offer_id: String) -> bool:
	if active_sponsors.size() >= MAX_ACTIVE_SPONSORS: return false
	for i in range(available_offers.size()):
		if available_offers[i].get("id", "") == offer_id:
			var offer := available_offers[i].duplicate(true)
			offer["active"] = true
			active_sponsors.append(offer)
			available_offers.remove_at(i)
			EventBus.sponsor_signed.emit(offer)
			return true
	return false

func process_season_end(season_data: Dictionary) -> Dictionary:
	var report := {"paid": [], "failed": [], "expired": []}
	var position = season_data.get("position", 4)
	var wins = season_data.get("wins", 0)
	var to_remove = []
	for i in range(active_sponsors.size()):
		var s = active_sponsors[i]
		if _check_condition(s["condition_type"], s["condition_param"], position, wins):
			EconomyManager.add_money(s["payment"], "sponsor_" + s["name"])
			report["paid"].append({"name": s["name"], "amount": s["payment"]})
			s["seasons_left"] -= 1
			if s["seasons_left"] <= 0: report["expired"].append({"name": s["name"]}); to_remove.append(i)
		else:
			EconomyManager.spend_money(s["penalty"], "sponsor_penalty_" + s["name"])
			report["failed"].append({"name": s["name"], "penalty": s["penalty"]})
			to_remove.append(i)
	to_remove.sort(); to_remove.reverse()
	for idx in to_remove: active_sponsors.remove_at(idx)
	return report

func _check_condition(type, p, pos, w):
	match type:
		"top_n": return pos <= p
		"win_count": return w >= p
		"no_last": return pos < 8
		"any": return true
	return true

func get_active_sponsors(): return active_sponsors
func get_offers(): return available_offers
func get_total_sponsor_income():
	var t = 0
	for s in active_sponsors: t += s["payment"]
	return t
func to_dict(): return {"active": active_sponsors, "offers": available_offers, "rerolls": rerolls_this_season}
func from_dict(data):
	active_sponsors = data.get("active", []); available_offers = data.get("offers", [])
	rerolls_this_season = data.get("rerolls", 0)
func reset_season_rerolls(): rerolls_this_season = 0
