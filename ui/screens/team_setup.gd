# ============================================================================
# TEAM SETUP — Экран создания команды
# ============================================================================
extends Control

const LOGO_TEXTURE = preload("res://icon.svg")
const LOGO_COUNT = 8

@onready var name_input: LineEdit = $SafeArea/MainVBox/Center/NameBox/NameInput
@onready var logo_grid: GridContainer = $SafeArea/MainVBox/Center/LogoBox/LogoGrid
@onready var next_button: Button = $SafeArea/MainVBox/Footer/NextButton
@onready var error_label: Label = null # UI removed this node, but we'll handle gracefully

var selected_logo_index: int = 0
var logo_buttons: Array[Button] = []

func _ready() -> void:
	_setup_logo_grid()
	_update_selection()
	_validate_input()
	if error_label:
		error_label.text = ""

func _setup_logo_grid() -> void:
	# Очищаем старые кнопки если были
	for child in logo_grid.get_children():
		child.queue_free()
	logo_buttons.clear()
	
	for i in range(LOGO_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.toggle_mode = true
		
		# Контейнер для иконки внутри кнопки
		var tex := TextureRect.new()
		tex.texture = LOGO_TEXTURE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		btn.add_child(tex)
		
		btn.pressed.connect(_on_logo_pressed.bind(i))
		logo_grid.add_child(btn)
		logo_buttons.append(btn)

func _on_logo_pressed(index: int) -> void:
	selected_logo_index = index
	_update_selection()

func _update_selection() -> void:
	for i in range(logo_buttons.size()):
		var btn = logo_buttons[i]
		btn.button_pressed = (i == selected_logo_index)
		# Подсвечиваем выбранный
		if i == selected_logo_index:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			btn.modulate = Color(0.6, 0.6, 0.6, 0.8)

func _on_name_changed(new_text: String) -> void:
	_validate_input()

func _validate_input() -> void:
	var team_name = name_input.text.strip_edges()
	var is_valid = team_name.length() >= 3
	next_button.disabled = not is_valid
	
	if team_name.length() > 0 and team_name.length() < 3:
		if error_label:
			error_label.text = "Минимум 3 символа"
	else:
		if error_label:
			error_label.text = ""

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/screens/main_menu.tscn")

func _on_next_pressed() -> void:
	GameManager.player_team_data["name"] = name_input.text.strip_edges()
	GameManager.player_team_data["logo"] = "res://icon.svg" # Пока одна иконка на всех
	GameManager.player_team_data["color"] = "#1E88E5" # Синий цвет по умолчанию для команды игрока
	get_tree().change_scene_to_file("res://ui/screens/roster_select.tscn")
