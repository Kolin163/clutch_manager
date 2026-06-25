# ============================================================================
# ECONOMY MANAGER — Управление бюджетом
# ============================================================================
# Бюджет команды, доходы, расходы, проверка банкротства.
# Синглтон — добавить в Autoload.
# ============================================================================

extends Node

# ----------------------------------------------------------------------------
# CONSTANTS
# ----------------------------------------------------------------------------
const STARTING_BUDGET := 500000
const BANKRUPTCY_THRESHOLD := -5000  # Допускаем небольшой долг

# ----------------------------------------------------------------------------
# STATE
# ----------------------------------------------------------------------------
var budget: int = STARTING_BUDGET
var last_processed_match_day: int = 0

# История транзакций (для отладки и UI)
var transaction_history: Array[Dictionary] = []
const MAX_HISTORY_SIZE := 50


# ----------------------------------------------------------------------------
# LIFECYCLE
# ----------------------------------------------------------------------------
func _ready() -> void:
	_connect_signals()
	EventBus.debug("EconomyManager ready, budget: $" + str(budget), "ECONOMY")


func _connect_signals() -> void:
	EventBus.season_ended.connect(_on_season_ended)
	EventBus.match_ended.connect(_on_match_ended)


# ----------------------------------------------------------------------------
# PUBLIC API — BALANCE
# ----------------------------------------------------------------------------
func get_budget() -> int:
	return budget


func set_budget(amount: int) -> void:
	var old := budget
	budget = amount
	EventBus.money_changed.emit(old, budget)
	EventBus.debug("Budget set: $" + str(budget), "ECONOMY")


func add_money(amount: int, source: String = "unknown") -> void:
	if amount <= 0:
		return
	
	var old := budget
	budget += amount
	
	_add_transaction("income", amount, source)
	EventBus.money_changed.emit(old, budget)
	EventBus.income_received.emit(source, amount)
	EventBus.debug("Income: +$" + str(amount) + " (" + source + ")", "ECONOMY")


func spend_money(amount: int, reason: String = "unknown") -> bool:
	if amount <= 0:
		return true
	
	if not can_afford(amount):
		EventBus.debug("Cannot afford: $" + str(amount) + " (" + reason + ")", "WARN")
		return false
	
	var old := budget
	budget -= amount
	
	_add_transaction("expense", amount, reason)
	EventBus.money_changed.emit(old, budget)
	EventBus.expense_paid.emit(reason, amount)
	EventBus.debug("Expense: -$" + str(amount) + " (" + reason + ")", "ECONOMY")
	
	_check_bankruptcy()
	return true


func can_afford(amount: int) -> bool:
	return budget >= amount


func is_bankrupt() -> bool:
	return budget < BANKRUPTCY_THRESHOLD


# ----------------------------------------------------------------------------
# REGULAR EXPENSES
# ----------------------------------------------------------------------------
func pay_salaries() -> int:
	"""Выплачивает зарплаты игрокам и персоналу. Возвращает общую сумму."""
	var player_salaries = RosterManager.get_total_salaries()
	var staff_salaries := _get_staff_salaries()
	var total = player_salaries + staff_salaries
	
	if total > 0:
		spend_money(total, "salaries")
	
	return total


func pay_base_maintenance() -> int:
	"""Оплата содержания базы. Возвращает сумму."""
	var maintenance: int = 500
	if maintenance > 0:
		spend_money(maintenance, "base_maintenance")
	return maintenance


func process_match_day_finances(match_day: int) -> Dictionary:
	"""Применяет регулярные доходы и расходы за игровой день один раз."""
	if match_day <= 0 or match_day <= last_processed_match_day:
		return {}
	
	var position = LeagueManager.get_player_position()
	var popularity: int = GameManager.player_team_data.get("popularity", 0)
	
	var sponsor_bonus = StaffManager.get_sponsor_bonus()
	var sponsor_income: int = int(150.0 * (1.0 + sponsor_bonus))
	var merch_income: int = PopularityManager.get_merch_income()
	var stream_income: int = BaseManager.get_stream_income()
	
	var total_salary: int = RosterManager.get_total_salaries()
	var salary_slice: int = int(ceil(float(total_salary) / 14.0))
	var staff_slice: int = int(ceil(float(_get_staff_salaries()) / 14.0))
	var base_slice: int = 40
	
	add_money(sponsor_income, "daily_sponsor")
	add_money(merch_income, "daily_merch")
	if stream_income > 0:
		add_money(stream_income, "daily_streams")
	
	if salary_slice > 0:
		spend_money(salary_slice, "daily_salaries")
	if staff_slice > 0:
		spend_money(staff_slice, "daily_staff")
	if base_slice > 0:
		spend_money(base_slice, "daily_base")
	
	last_processed_match_day = match_day
	
	return {
		"match_day": match_day,
		"income": sponsor_income + merch_income + stream_income,
		"expense": salary_slice + staff_slice + base_slice,
		"sponsor": sponsor_income,
		"merch": merch_income,
		"streams": stream_income,
		"salaries": salary_slice,
		"staff": staff_slice,
		"base": base_slice,
		"net": sponsor_income + merch_income + stream_income - salary_slice - staff_slice - base_slice
	}


func reset_for_new_season() -> void:
	last_processed_match_day = 0


func _get_staff_salaries() -> int:
	return StaffManager.get_total_salaries()


# ----------------------------------------------------------------------------
# INCOME SOURCES
# ----------------------------------------------------------------------------
func receive_prize_money(place: int, league: String) -> int:
	"""Призовые за место в лиге."""
	var prizes := _get_league_prizes(league)
	var amount: int = prizes.get(place, 0)
	
	if amount > 0:
		add_money(amount, "prize_" + league + "_" + str(place))
	
	return amount


func receive_match_bonus(is_win: bool, is_home: bool) -> int:
	"""Бонус за матч."""
	var amount: int = 0
	
	if is_win:
		amount = 200
	else:
		amount = 50  # Утешительные
	
	if is_home:
		amount += 100  # Домашний бонус
	
	if amount > 0:
		add_money(amount, "match_bonus")
	
	return amount


func receive_sponsor_payment(sponsor_name: String, amount: int) -> void:
	add_money(amount, "sponsor_" + sponsor_name)


func receive_merch_income(amount: int) -> void:
	add_money(amount, "merch")


func receive_stream_income(amount: int) -> void:
	add_money(amount, "streams")


func _get_league_prizes(league: String) -> Dictionary:
	# Призовые по местам для разных лиг
	match league:
		"Open":
			return {1: 2000, 2: 1000, 3: 500, 4: 500}
		"Rising":
			return {1: 4000, 2: 2000, 3: 1000, 4: 1000}
		"Pro":
			return {1: 8000, 2: 4000, 3: 2000, 4: 2000}
		"Elite":
			return {1: 15000, 2: 8000, 3: 4000, 4: 4000}
		"Champions":
			return {1: 30000, 2: 15000, 3: 8000, 4: 8000}
		_:
			return {1: 1000, 2: 500}


# ----------------------------------------------------------------------------
# PROJECTIONS
# ----------------------------------------------------------------------------
func get_monthly_expenses() -> Dictionary:
	"""Прогноз регулярных расходов."""
	return {
		"salaries": RosterManager.get_total_salaries(),
		"staff": _get_staff_salaries(),
		"base": 500,  # TODO: из BaseManager
		"total": RosterManager.get_total_salaries() + _get_staff_salaries() + 500
	}


func get_seasons_until_bankrupt() -> int:
	"""Сколько сезонов до банкротства при текущих расходах."""
	var expenses := get_monthly_expenses()
	var per_season: int = expenses["total"]
	
	if per_season <= 0:
		return 999
	
	var remaining: int = budget - BANKRUPTCY_THRESHOLD
	return maxi(0, remaining / per_season)


# ----------------------------------------------------------------------------
# BANKRUPTCY
# ----------------------------------------------------------------------------
func _check_bankruptcy() -> void:
	if is_bankrupt():
		EventBus.debug("BANKRUPTCY! Budget: $" + str(budget), "ERROR")
		# TODO: триггер события банкротства


# ----------------------------------------------------------------------------
# TRANSACTION HISTORY
# ----------------------------------------------------------------------------
func _add_transaction(type: String, amount: int, description: String) -> void:
	transaction_history.append({
		"type": type,
		"amount": amount,
		"description": description,
		"timestamp": Time.get_unix_time_from_system(),
		"season": GameManager.current_season,
		"balance_after": budget
	})
	
	while transaction_history.size() > MAX_HISTORY_SIZE:
		transaction_history.pop_front()


func get_recent_transactions(count: int = 10) -> Array:
	var start := maxi(0, transaction_history.size() - count)
	return transaction_history.slice(start)


# ----------------------------------------------------------------------------
# SIGNAL HANDLERS
# ----------------------------------------------------------------------------
func _on_season_ended(_season: int, _results: Dictionary) -> void:
	EventBus.debug("Season economy closed", "ECONOMY")


func _on_match_ended(result: Dictionary) -> void:
	var is_win: bool = result.get("winner", "") == "player"
	var is_home: bool = result.get("is_home", true)
	receive_match_bonus(is_win, is_home)


# ----------------------------------------------------------------------------
# SERIALIZATION
# ----------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"budget": budget,
		"history": transaction_history.duplicate(),
		"last_processed_match_day": last_processed_match_day
	}


func from_dict(data: Dictionary) -> void:
	budget = data.get("budget", STARTING_BUDGET)
	last_processed_match_day = data.get("last_processed_match_day", 0)
	transaction_history.clear()
	for t in data.get("history", []):
		transaction_history.append(t)
	EventBus.debug("Economy loaded, budget: $" + str(budget), "ECONOMY")
