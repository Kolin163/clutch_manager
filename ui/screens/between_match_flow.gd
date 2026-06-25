extends Control

const PHASES := ["result", "event", "finance", "preparation"]

@onready var phase_title: Label = $SafeArea/MainVBox/PhasesContainer/Center/PhasePanel/Margin/PhaseVBox/PhaseTitle
@onready var phase_body: RichTextLabel = $SafeArea/MainVBox/PhasesContainer/Center/PhasePanel/Margin/PhaseVBox/PhaseBody
@onready var next_button: Button = $SafeArea/MainVBox/Footer/NextButton
@onready var subtitle: RichTextLabel = $SafeArea/MainVBox/Header/Subtitle
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var phase_panel: PanelContainer = $SafeArea/MainVBox/PhasesContainer/Center/PhasePanel

var _phase_index: int = 0
var _finance_result: Dictionary = {}

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_color = Color(0.3, 0.8, 0.4)
	phase_panel.add_theme_stylebox_override("panel", style)
	
	_finance_result = EconomyManager.process_match_day_finances(LeagueManager.current_match_day)
	_update_phase()

func _on_next_pressed() -> void:
	if _phase_index >= PHASES.size() - 1:
		_finish_flow()
		return
	_transition_to_next_phase()

func _on_skip_pressed() -> void:
	_finish_flow()

func _transition_to_next_phase() -> void:
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.15)
	tween.tween_callback(func():
		_phase_index += 1
		_update_phase()
	)
	tween.tween_property(transition_overlay, "color:a", 0.0, 0.15)

func _update_phase() -> void:
	var phase = PHASES[_phase_index]
	var parent := phase_body.get_parent()
	for child in parent.get_children():
		if child is Button: child.queue_free()
		
	var active_color = "[color=#80CCFF]"
	var inactive_color = "[color=#666666]"
	var phases_text = []
	for i in range(PHASES.size()):
		var p_name = ""
		match PHASES[i]:
			"result": p_name = "Результат"
			"event": p_name = "Ивент"
			"finance": p_name = "Финансы"
			"preparation": p_name = "Подготовка"
		if i == _phase_index:
			phases_text.append(active_color + p_name + "[/color]")
		else:
			phases_text.append(inactive_color + p_name + "[/color]")
	subtitle.text = ""
	subtitle.text = "[center]" + " -> ".join(phases_text) + "[/center]"
	
	match phase:
		"result":
			_build_result_phase()
		"event":
			_build_event_phase()
		"finance":
			_build_finance_phase()
		"preparation":
			_build_prep_phase()

func _build_result_phase() -> void:
	phase_panel.get_theme_stylebox("panel").border_color = Color("4dff80")
	phase_title.text = "ИТОГИ МАТЧА"
	var result = GameManager.last_match_result
	var winner = result.get("winner", "enemy")
	var p_score = result.get("player_score", 0)
	var e_score = result.get("enemy_score", 0)
	
	var text := "[center][font_size=48]" + str(p_score) + " : " + str(e_score) + "[/font_size][/center]\n\n"
	
	if winner == "player":
		text += "[center][color=#4DFF80]ПОБЕДА[/color][/center]\n"
		text += "[center]Команда получает очки и улучшает мораль.[/center]\n\n"
	else:
		text += "[center][color=#FF6666]ПОРАЖЕНИЕ[/color][/center]\n"
		text += "[center]Команда теряет очки. Игроки могут словить тильт.[/center]\n\n"
		
	# MVP Mock
	var roster = RosterManager.get_roster()
	if not roster.is_empty():
		var mvp = roster[randi() % roster.size()]
		text += "[center][color=#FFCC4D]⭐ MVP Матча: " + mvp.get("nickname", "Player") + "[/color][/center]"
		
	phase_body.text = text
	next_button.text = "СОБЫТИЯ →"

func _build_event_phase() -> void:
	phase_panel.get_theme_stylebox("panel").border_color = Color("ffcc4d")
	phase_title.text = "СОБЫТИЯ В КОМАНДЕ"
	var event = OffMatchEventManager.try_trigger_event()
	
	if event.is_empty():
		phase_body.text = "[center]Неделя прошла спокойно.[/center]\n\nМенеджер занимается рутиной, игроки отдыхают."
		next_button.text = "ФИНАНСЫ →"
	elif event.get("type", "") == "unmanaged":
		var result = EventResolver.resolve_unmanaged_event(event)
		var details: Array = result.get("details", [])
		var text = "[center][color=#FFCC4D]" + event.get("text", "") + "[/color][/center]\n\n"
		for d in details:
			text += "[center]" + d + "[/center]\n"
		phase_body.text = text
		next_button.text = "ФИНАНСЫ →"
	else:
		phase_body.text = "[center][color=#FFCC4D]" + event.get("text", "") + "[/color][/center]\n\n"
		var choices: Array = event.get("choices", [])
		var parent := phase_body.get_parent()
		for choice in choices:
			var btn := Button.new()
			btn.text = choice.get("text", "?")
			btn.custom_minimum_size = Vector2(0, 45)
			btn.pressed.connect(_on_event_choice.bind(event, choice.get("id", "")))
			parent.add_child(btn)
		next_button.text = "ПРОПУСТИТЬ →"

func _build_finance_phase() -> void:
	phase_panel.get_theme_stylebox("panel").border_color = Color("80ccff")
	phase_title.text = "ФИНАНСОВЫЙ ОТЧЕТ"
	
	var income = _finance_result.get("income", 0)
	var expense = _finance_result.get("expense", 0)
	var net = _finance_result.get("net", 0)
	
	var text = "[table=2]"
	text += "[cell][color=#80FF80]Доходы (Спонсоры, Призовые):[/color][/cell][cell][color=#80FF80]+$" + str(income) + "[/color][/cell]"
	text += "[cell][color=#FF8080]Расходы (Зарплаты, База):[/color][/cell][cell][color=#FF8080]-$" + str(expense) + "[/color][/cell]"
	text += "[/table]\n\n"
	
	text += "[center]Итого за период: "
	if net >= 0:
		text += "[color=#4DFF80]+$" + str(net) + "[/color][/center]"
	else:
		text += "[color=#FF6666]-$" + str(abs(net)) + "[/color][/center]"
		
	text += "\n[center]Текущий бюджет: [b]$" + str(EconomyManager.get_budget()) + "[/b][/center]"
	
	phase_body.text = text
	next_button.text = "ПОДГОТОВКА →"

func _build_prep_phase() -> void:
	phase_panel.get_theme_stylebox("panel").border_color = Color("ffffff")
	phase_title.text = "ПОДГОТОВКА"
	var next_match = LeagueManager.get_next_player_match()
	if next_match.is_empty():
		phase_body.text = "[center]Регулярный сезон завершён.[/center]\n\nПереходим к итогам сезона."
		next_button.text = "К ИТОГАМ СЕЗОНА →"
	else:
		var home: Dictionary = next_match.get("home_team", {})
		var away: Dictionary = next_match.get("away_team", {})
		var is_home = home.get("is_player", false)
		var opponent := away if is_home else home
		
		phase_body.text = "[center]Следующий соперник:[/center]\n\n[center][font_size=24]" + opponent.get("logo", "🤖") + " " + opponent.get("name", "Opponent") + "[/font_size][/center]\n\n[center]Тур " + str(next_match.get("match_day", LeagueManager.current_match_day + 1)) + " из 14.[/center]"
		next_button.text = "ЗАВЕРШИТЬ →"

func _on_event_choice(event: Dictionary, choice_id: String) -> void:
	var result = EventResolver.resolve_managed_event(event, choice_id)
	var details: Array = result.get("details", [])
	
	var text := "[center][color=#4DFF80]Решение принято![/color][/center]\n\n"
	for d in details:
		text += "[center]" + d + "[/center]\n"
	if details.is_empty():
		text += "[center]Принято.[/center]"
	
	phase_body.text = text
	var parent := phase_body.get_parent()
	for child in parent.get_children():
		if child is Button and child != next_button:
			child.queue_free()
	
	next_button.text = "ФИНАНСЫ →"

func _finish_flow() -> void:
	if GameManager.last_match_result.get("is_major", false):
		GameManager.last_match_result["major_match"] = true
		get_tree().change_scene_to_file("res://ui/screens/major_screen.tscn")
		return
		
	var next_match = LeagueManager.get_next_player_match()
	var all_played = LeagueManager.is_season_complete() or next_match.is_empty()
	
	if all_played:
		while not LeagueManager.is_season_complete():
			LeagueManager.advance_match_day()
			LeagueManager.simulate_current_match_day(false)
		
		var summary = LeagueManager.finalize_season()
		GameManager.complete_season(summary)
		get_tree().change_scene_to_file("res://ui/screens/season_results.tscn")
		return
	
	EventBus.save_requested.emit()
	get_tree().call_deferred("change_scene_to_file", "res://ui/screens/season_screen.tscn")
