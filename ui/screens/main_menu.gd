# ============================================================================
# MAIN MENU — Главное меню
# ============================================================================
extends Control

@onready var continue_button: Button = $MainLayout/ButtonsHBox/ContinueBox/ContinueButton
@onready var continue_icon: TextureRect = $MainLayout/ButtonsHBox/ContinueBox/ContinueIcon
@onready var new_game_icon: TextureRect = $MainLayout/ButtonsHBox/NewGameBox/NewGameIcon
@onready var title_image: TextureRect = $MainLayout/TitleImage

func _ready() -> void:
	_update_continue_button()

func _update_continue_button() -> void:
	continue_button.disabled = true
	# Изначально задаем нормальный цвет
	continue_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) 
	
	# Проверяем наличие сохранений
	SaveManager.check_save_exists(Callable(self, "_on_check_save_result"))

func _on_check_save_result(exists: bool) -> void:
	continue_button.disabled = not exists
	
	if not exists:
		# Делаем иконку бледной
		continue_icon.modulate.a = 0.3
	else:
		continue_icon.modulate.a = 1.0

func _on_start_pressed() -> void:
	GameManager.init_new_game()
	get_tree().change_scene_to_file("res://ui/screens/team_setup.tscn")

func _on_continue_pressed() -> void:
	GameManager.continue_game()
