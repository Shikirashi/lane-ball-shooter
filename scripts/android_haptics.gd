class_name AndroidHaptics
extends RefCounted

const DURATION_MS := 500
const AMPLITUDE := 1.0
const LOG_PREFIX := "[LBS_HAPTIC]"

## Central Android haptic boundary shared by gameplay and diagnostic controls.
## The engine API is fire-and-forget, so true means only that a request was
## handed to the native bridge (or injected test double), never that the motor
## was physically felt.
static func request(source: StringName, lane_identity: int, android_gate: bool, requester := Callable()) -> bool:
	var route := "blocked"
	if android_gate and requester.is_valid():
		route = "injected"
	elif android_gate and OS.has_feature("android"):
		route = "native"
	print("%s request source=%s lane=%s duration_ms=%d amplitude=%.1f android_gate=%s route=%s" % [
		LOG_PREFIX,
		str(source),
		str(lane_identity) if lane_identity >= 0 else "none",
		DURATION_MS,
		AMPLITUDE,
		str(android_gate).to_lower(),
		route,
	])
	if route == "injected":
		requester.call(DURATION_MS, AMPLITUDE)
		return true
	if route != "native":
		return false
	Input.vibrate_handheld(DURATION_MS, AMPLITUDE)
	return true
