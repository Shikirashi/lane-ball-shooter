class_name MatchProgression
extends RefCounted

signal state_changed(score: int, combo_count: int, tier: int, fever_active: bool, window_ratio: float)
signal match_resolved(result: Dictionary)

const COMBO_WINDOW := 3.0
const FEVER_COMBO := 4
const BASE_MATCH_SIZE := 3
const BASE_POINTS := 100
const EXTRA_BALL_POINTS := 50

var score := 0
var combo_count := 0
var tier := 0
var fever_active := false
var time_remaining := 0.0
var last_result: Dictionary = {}

func reset_run() -> void:
	score = 0
	combo_count = 0
	tier = 0
	fever_active = false
	time_remaining = 0.0
	last_result.clear()
	_emit_state()

func register_match(identity: int, group_size: int) -> Dictionary:
	if group_size < BASE_MATCH_SIZE:
		return {}
	if combo_count > 0 and time_remaining > 0.0:
		combo_count += 1
	else:
		combo_count = 1
	tier = mini(combo_count, 3)
	fever_active = combo_count >= FEVER_COMBO
	time_remaining = COMBO_WINDOW
	var points := BASE_POINTS + (group_size - BASE_MATCH_SIZE) * EXTRA_BALL_POINTS
	score += points
	last_result = {
		"identity": posmod(identity, TeamData.COUNT),
		"group_size": group_size,
		"combo_count": combo_count,
		"tier": tier,
		"fever": fever_active,
		"points": points,
	}
	match_resolved.emit(last_result.duplicate(true))
	_emit_state()
	return last_result.duplicate(true)

func update(delta: float) -> void:
	if combo_count == 0:
		return
	time_remaining = maxf(0.0, time_remaining - maxf(delta, 0.0))
	if time_remaining <= 0.0:
		combo_count = 0
		tier = 0
		fever_active = false
	_emit_state()

func window_ratio() -> float:
	return clampf(time_remaining / COMBO_WINDOW, 0.0, 1.0)

func publish_state() -> void:
	_emit_state()

func _emit_state() -> void:
	state_changed.emit(score, combo_count, tier, fever_active, window_ratio())
