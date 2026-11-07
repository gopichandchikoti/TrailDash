class_name RunModel
extends RefCounted

enum State { BOOT, MAIN_MENU, TUTORIAL, COUNTDOWN, RUNNING, PAUSED, HIT, GAME_OVER, RESULTS }

const MAX_SPEED: float = 26.0
const TRANSITIONS: Dictionary = {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.TUTORIAL, State.COUNTDOWN],
	State.TUTORIAL: [State.MAIN_MENU, State.COUNTDOWN],
	State.COUNTDOWN: [State.RUNNING, State.PAUSED, State.MAIN_MENU],
	State.RUNNING: [State.PAUSED, State.HIT],
	State.PAUSED: [State.RUNNING, State.COUNTDOWN, State.MAIN_MENU],
	State.HIT: [State.GAME_OVER],
	State.GAME_OVER: [State.RESULTS],
	State.RESULTS: [State.COUNTDOWN, State.MAIN_MENU]
}

var state: State = State.BOOT
var resume_state: State = State.RUNNING
var distance: float = 0.0
var elapsed: float = 0.0
var tokens: int = 0
var combo: int = 0
var best_combo: int = 0
var token_score: int = 0


func transition(next: State) -> bool:
	if not next in TRANSITIONS[state]:
		return false
	if next == State.PAUSED:
		resume_state = state
	state = next
	return true


func reset() -> void:
	distance = 0.0
	elapsed = 0.0
	tokens = 0
	combo = 0
	best_combo = 0
	token_score = 0


func advance(delta: float) -> void:
	if state != State.RUNNING or delta <= 0.0:
		return
	elapsed += delta
	distance += speed() * delta


func speed() -> float:
	return minf(12.0 + elapsed * 0.075, MAX_SPEED)


func band() -> int:
	return mini(int(distance / 500.0), 4)


func collect() -> void:
	if state != State.RUNNING:
		return
	tokens += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	token_score += 25 * multiplier()


func multiplier() -> int:
	return mini(1 + int(combo / 5.0), 4)


func score() -> int:
	return int(distance) + token_score
