extends Node
## GameManager (autoload singleton)
## Tracks "Gains" (currency), the current round, kill count, and global run state.
## Access from anywhere as: GameManager.add_gains(50)

signal gains_changed(new_amount: int)
signal round_changed(new_round: int)
signal kills_changed(new_amount: int)
signal player_died

var gains: int = 500
var round_number: int = 1
var kills: int = 0
var is_game_over: bool = false


func add_gains(amount: int) -> void:
	gains += amount
	gains_changed.emit(gains)


func try_spend_gains(amount: int) -> bool:
	if gains >= amount:
		gains -= amount
		gains_changed.emit(gains)
		return true
	return false


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func start_next_round() -> void:
	round_number += 1
	round_changed.emit(round_number)


func report_player_death() -> void:
	if is_game_over:
		return
	is_game_over = true
	player_died.emit()


func reset_run() -> void:
	gains = 500
	round_number = 1
	kills = 0
	is_game_over = false
	gains_changed.emit(gains)
	round_changed.emit(round_number)
	kills_changed.emit(kills)
