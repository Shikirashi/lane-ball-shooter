class_name MagazineState
extends RefCounted

signal changed(loaded_identity: int, next_identity: int)

var loaded_identity: int = TeamData.Identity.RED
var next_identity: int = TeamData.Identity.BLUE
var _random := RandomNumberGenerator.new()

func _init() -> void:
	_random.seed = 0x1A2B3C4D

func swap() -> void:
	var previous_loaded := loaded_identity
	loaded_identity = next_identity
	next_identity = previous_loaded
	changed.emit(loaded_identity, next_identity)

func consume_loaded() -> int:
	var fired_identity := loaded_identity
	loaded_identity = next_identity
	next_identity = _fresh_identity(loaded_identity)
	changed.emit(loaded_identity, next_identity)
	return fired_identity

func _fresh_identity(avoid_identity: int) -> int:
	var result := _random.randi_range(0, TeamData.COUNT - 1)
	# Keeping the preview distinct makes the placeholder magazine easier to read.
	if result == avoid_identity:
		result = (result + 1 + _random.randi_range(0, TeamData.COUNT - 2)) % TeamData.COUNT
	return result

