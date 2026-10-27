class_name EnemyTypes
extends RefCounted

enum Type { HOPPER, HEAVY, SICKLE_SNAKE, HEALYZARD }

const BASE_WEIGHTS := {
	Type.HOPPER: 50,
	Type.HEAVY: 20,
	Type.SICKLE_SNAKE: 20,
	Type.HEALYZARD: 10,
}
const NAMES := {
	Type.HOPPER: "Hopper",
	Type.HEAVY: "Heavy",
	Type.SICKLE_SNAKE: "Sickle Snake",
	Type.HEALYZARD: "Healyzard",
}
const MAX_HP := {
	Type.HOPPER: 3,
	Type.HEAVY: 6,
	Type.SICKLE_SNAKE: 3,
	Type.HEALYZARD: 3,
}
const SPEED_MULTIPLIERS := {
	Type.HOPPER: 1.0,
	Type.HEAVY: 0.7,
	Type.SICKLE_SNAKE: 2.0,
	Type.HEALYZARD: 0.0,
}

static func valid_type(value: int) -> bool:
	return value >= Type.HOPPER and value <= Type.HEALYZARD

static func max_hp(type: int) -> int:
	return int(MAX_HP.get(type, MAX_HP[Type.HOPPER]))

static func speed(type: int, hopper_speed: float) -> float:
	return hopper_speed * float(SPEED_MULTIPLIERS.get(type, 1.0))

static func display_name(type: int) -> String:
	return str(NAMES.get(type, NAMES[Type.HOPPER]))

static func uses_hop(type: int) -> bool:
	return type == Type.HOPPER
