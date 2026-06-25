extends PanelContainer

signal action_requested(room_id: String, action: String)

const ROOM_ICONS := {
	"training_room": "🎮",
	"server_room": "🖥️",
	"stream_room": "📹",
	"rest_zone": "☕",
	"manager_office": "💼",
	"meeting_room": "🤝",
	"garage": "🚗"
}

const EMPTY_ICON := "➕"
const LOCKED_ICON := "🔒"

@onready var icon_label: Label = $MarginContainer/VBox/Icon
@onready var name_label: Label = $MarginContainer/VBox/NameLabel
@onready var level_label: Label = $MarginContainer/VBox/LevelLabel
@onready var effect_label: Label = $MarginContainer/VBox/EffectLabel
@onready var action_button: Button = $MarginContainer/VBox/ActionButton

var _room_id: String = ""
var _mode: String = "empty"  # empty, locked, built, upgradeable


func setup_empty(slot_index: int) -> void:
	_mode = "empty"
	_room_id = ""
	icon_label.text = EMPTY_ICON
	name_label.text = "Пустой слот"
	level_label.text = "Слот #" + str(slot_index + 1)
	effect_label.text = "Нажмите чтобы построить"
	action_button.text = "Построить..."
	action_button.disabled = false
	_apply_style(Color.html("#1A2233"), Color.html("#334455"))


func setup_locked() -> void:
	_mode = "locked"
	_room_id = ""
	icon_label.text = LOCKED_ICON
	name_label.text = "Заблокировано"
	level_label.text = ""
	effect_label.text = "Нужен переезд"
	action_button.text = "Недоступно"
	action_button.disabled = true
	_apply_style(Color.html("#111118"), Color.html("#222233"))


func setup_built(room: Room) -> void:
	_room_id = room.id
	icon_label.text = ROOM_ICONS.get(room.id, "🏗️")
	name_label.text = room.get_room_name()
	level_label.text = "Уровень " + str(room.current_level) + "/" + str(room.get_max_level())
	
	var level_data := room.get_level_data(room.current_level)
	effect_label.text = level_data.get("description", "")
	
	if room.can_upgrade():
		_mode = "upgradeable"
		var cost := room.get_upgrade_cost()
		var can_pay = EconomyManager.can_afford(cost)
		action_button.text = "⬆ Апгрейд $" + str(cost)
		action_button.disabled = not can_pay
		_apply_style(Color.html("#1A2E1A"), Color.html("#33663A"))
	else:
		_mode = "built"
		action_button.text = "Макс. уровень"
		action_button.disabled = true
		_apply_style(Color.html("#1A2E2E"), Color.html("#338080"))


func _on_action_pressed() -> void:
	match _mode:
		"empty":
			action_requested.emit("", "build_menu")
		"upgradeable":
			action_requested.emit(_room_id, "upgrade")


func _apply_style(bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
