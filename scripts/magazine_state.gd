class_name MagazineState
extends RefCounted

signal changed(loaded_identity: int, next_identity: int)

const DEFAULT_SEED := 0x1A2B3C4D

var loaded_identity: int
var next_identity: int
var draw_count := 0
var generated_history: Array[int] = []

var _random := RandomNumberGenerator.new()
var _bag: Array[int] = []

func _init(seed_value := DEFAULT_SEED) -> void:
	_random.seed = seed_value
	loaded_identity = _draw_identity()
	next_identity = _draw_identity()

func swap() -> void:
	var previous_loaded := loaded_identity
	loaded_identity = next_identity
	next_identity = previous_loaded
	changed.emit(loaded_identity, next_identity)

func consume_loaded() -> int:
	var fired_identity := loaded_identity
	loaded_identity = next_identity
	next_identity = _draw_identity()
	changed.emit(loaded_identity, next_identity)
	return fired_identity

func bag_remaining() -> Array[int]:
	return _bag.duplicate()

func _draw_identity() -> int:
	if _bag.is_empty():
		_refill_bag()
	var result: int = _bag.pop_back()
	draw_count += 1
	generated_history.append(result)
	return result

func _refill_bag() -> void:
	_bag.clear()
	for identity in range(TeamData.COUNT):
		_bag.append(identity)
	for index in range(_bag.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var held := _bag[index]
		_bag[index] = _bag[swap_index]
		_bag[swap_index] = held

