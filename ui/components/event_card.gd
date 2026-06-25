# ============================================================================
# EVENT CARD — Карточка ивента матча
# ============================================================================

extends PanelContainer

signal choice_made(choice_id: String)
signal timer_expired

const DECISION_TIME := 8.0
const TYPE_ICONS := {
	"combat": "⚔️",
	"clutch": "🎯",
	"tactical": "🧠",
	"economy": "💰",
	"mental": "😤"
}

@onready var type_icon: Label = $Margin/VBox/HeaderHBox/TypeIcon
@onready var title: Label = $Margin/VBox/HeaderHBox/Title
@onready var timer_label: Label = $Margin/VBox/HeaderHBox/TimerLabel
@onready var desc_text: RichTextLabel = $Margin/VBox/DescText
@onready var choices_vbox: VBoxContainer = $Margin/VBox/ChoicesVBox

var _time_left: float = DECISION_TIME
var _is_active: bool = false
var _event_data: Dictionary = {}

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 1.0)
	style.border_width_bottom = 4
	style.border_color = Color(1.0, 0.8, 0.4, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", style)
	set_process(false)

func setup(data: Dictionary) -> void:
	_event_data = data
	_time_left = DECISION_TIME
	_is_active = true
	
	var e_type = data.get("type", "combat")
	type_icon.text = TYPE_ICONS.get(e_type, "⚡")
	title.text = data.get("title", "СИТУАЦИЯ")
	desc_text.text = data.get("text", "...")
	
	for child in choices_vbox.get_children():
		child.queue_free()
		
	var choices = data.get("choices", [])
	for choice in choices:
		var btn := Button.new()
		var risk = choice.get("risk", 0.5)
		var chance = int((1.0 - risk) * 100)
		btn.text = choice.get("text", "Выбор") + " (" + str(chance) + "%)"
		btn.custom_minimum_size = Vector2(0, 45)
		btn.pressed.connect(_on_choice_pressed.bind(choice.get("id", "")))
		
		if risk > 0.6:
			btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		elif risk < 0.3:
			btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			
		choices_vbox.add_child(btn)
		
	set_process(true)

func _process(delta: float) -> void:
	if not _is_active: return
	
	_time_left -= delta
	timer_label.text = "%.1f" % max(0.0, _time_left)
	
	if _time_left <= 3.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	
	if _time_left <= 0.0:
		_is_active = false
		set_process(false)
		timer_expired.emit()

func _on_choice_pressed(choice_id: String) -> void:
	if not _is_active: return
	_is_active = false
	set_process(false)
	choice_made.emit(choice_id)
