# ============================================================================
# PLAYER CARD — UI компонент (с поддержкой скаутинга)
# ============================================================================
extends PanelContainer

@onready var portrait = $Margin/VBox/Header/PortraitPlaceholder/AvatarPortrait
@onready var nickname: Label = $Margin/VBox/Header/NameVBox/Nickname
@onready var full_name: Label = $Margin/VBox/Header/NameVBox/FullName
@onready var aim_bar: ProgressBar = $Margin/VBox/Tabs/Навыки/SkillsGrid/AimBar
@onready var utility_bar: ProgressBar = $Margin/VBox/Tabs/Навыки/SkillsGrid/UtilityBar
@onready var gs_bar: ProgressBar = $Margin/VBox/Tabs/Навыки/SkillsGrid/GSBar
@onready var overall_lbl: Label = $Margin/VBox/Tabs/Навыки/Overall
@onready var potential_lbl: Label = $Margin/VBox/Tabs/Навыки/Potential
@onready var contract_lbl: Label = $Margin/VBox/Tabs/Контракт/ContractLabel

# Флаг: если true, показываем реальные данные (для своего ростера)
var show_exact: bool = false

func set_player_data(data: Dictionary) -> void:
	nickname.text = data.get("nickname", "---")
	full_name.text = data.get("first_name", "") + " " + data.get("last_name", "")
	
	if show_exact:
		# СВОИ ИГРОКИ - Видим всё
		_set_exact_skill(aim_bar, data["combat_skills"].get("aim", 50))
		_set_exact_skill(utility_bar, data["combat_skills"].get("utility", 50))
		_set_exact_skill(gs_bar, data["combat_skills"].get("game_sense", 50))
		
		var combat = data.get("combat_skills", {})
		var avg: float = 0.0
		for v in combat.values(): avg += v
		avg = avg / maxi(combat.size(), 1)
		
		overall_lbl.text = "РЕЙТИНГ: " + str(int(avg))
		potential_lbl.text = "ПОТЕНЦИАЛ: " + str(data.get("potential", 0))
	else:
		# РЫНОК - Используем систему скаутинга
		var has_analyst = StaffManager.has_analyst()
		var visible_data = Scouting.get_visible_skills(data, has_analyst)
		
		_set_skill_line(aim_bar, visible_data["combat"].get("aim", {}))
		_set_skill_line(utility_bar, visible_data["combat"].get("utility", {}))
		_set_skill_line(gs_bar, visible_data["combat"].get("game_sense", {}))
		
		var avg = Scouting.get_perceived_overall(data, has_analyst)
		overall_lbl.text = "РЕЙТИНГ: ~" + str(int(avg))
		
		var pot_info = visible_data.get("potential", {})
		potential_lbl.text = "ПОТЕНЦИАЛ: " + str(pot_info.get("value", "???"))
	
	# Контракт (всегда виден)
	var con = data.get("contract", {})
	contract_lbl.text = "Зарплата: $%d/сез\nСрок: %d сез.\nНация: %s" % [
		con.get("salary", 0),
		con.get("seasons_left", 0),
		NameGenerator.get_nationality_flag(data.get("nationality", "")) + " " + data.get("nationality", "").to_upper()
	]
	
	if portrait:
		portrait.setup(data.get("appearance", {}), data.get("role", "entry"))

func _set_exact_skill(bar: ProgressBar, val: int) -> void:
	bar.value = val
	var label_node_name = str(bar.name).replace("Bar", "")
	var label = bar.get_parent().get_node_or_null(label_node_name)
	if label:
		label.text = label_node_name + ": " + str(val)
	bar.modulate = Color(1, 1, 1, 1)

func _set_skill_line(bar: ProgressBar, info: Dictionary) -> void:
	var label_node_name = str(bar.name).replace("Bar", "")
	var label = bar.get_parent().get_node_or_null(label_node_name)
	
	if label == null: return
	
	if info.get("hidden", false):
		bar.value = 0
		label.text = label_node_name + ": ??"
		bar.modulate = Color(0.3, 0.3, 0.3, 1)
	else:
		var val = info.get("value", 50)
		bar.value = val
		var prefix = "~" if not info.get("accurate", false) else ""
		label.text = label_node_name + ": " + prefix + str(val)
		bar.modulate = Color(1, 1, 1, 1)
