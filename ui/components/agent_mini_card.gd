# ============================================================================
# AGENT MINI CARD — С поддержкой состояния выбора и скаутинга
# ============================================================================
extends Button

signal mini_card_pressed(data: Dictionary)

@onready var portrait = $Margin/HBox/Portrait/AvatarPortrait
@onready var nick_lbl: Label = $Margin/HBox/Info/TopLine/Nickname
@onready var over_lbl: Label = $Margin/HBox/Info/TopLine/Overall
@onready var sub_lbl: Label = $Margin/HBox/Info/SubLine
@onready var fee_lbl: Label = $Margin/HBox/Info/Fee
@onready var sal_lbl: Label = $Margin/HBox/Info/Salary

var player_data: Dictionary = {}

func _ready() -> void:
	self.pressed.connect(_on_self_pressed)
	set_selected(false)

func setup(data: Dictionary) -> void:
	player_data = data
	nick_lbl.text = data.get("nickname", "???")
	
	var has_analyst = StaffManager.has_analyst()
	var display_avg = Scouting.get_perceived_overall(data, has_analyst)
	var prefix = "" if has_analyst else "~"
	
	over_lbl.text = prefix + str(display_avg)
	over_lbl.add_theme_color_override("font_color", _get_skill_color(display_avg))
	
	var flag = NameGenerator.get_nationality_flag(data.get("nationality", ""))
	var role = PlayerGenerator.get_role_display_name(data.get("role", "")).to_upper()
	sub_lbl.text = flag + " | " + role
	
	var salary = data.get("contract", {}).get("salary", 500)
	fee_lbl.text = "БОНУС: $" + str(int(salary * 0.5))
	sal_lbl.text = "ЗАРПЛАТА: $" + str(salary) + "/СЕЗ"
	
	var app = data.get("appearance", {})
	if portrait:
		portrait.setup(app, data.get("role", "entry"))

func set_selected(is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.2, 0.3, 0.45, 1)
		style.border_color = Color(0.5, 0.8, 1, 1)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.12, 0.15, 0.2, 1)
		style.border_color = Color(0.3, 0.4, 0.5, 1)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)

func _on_self_pressed() -> void:
	mini_card_pressed.emit(player_data)

func _get_skill_color(val: int) -> Color:
	if val >= 70: return Color.html("#4DFF80")
	elif val >= 50: return Color.html("#FFFF80")
	else: return Color.html("#FF6666")
