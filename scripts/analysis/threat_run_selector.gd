class_name ThreatRunSelector
extends RefCounted

const ARM_BOOSTS := {
	"baseline": 0.0,
	"mild": 0.5,
	"moderate": 1.5,
	"strong": 3.0,
}
const THREAT_CEILING := 15.0
const THREAT_SPAN := 12.0
const MAX_RECORDED_EVENTS := 512

var arm := "baseline"
var boost := 0.0
var threat_snapshot: Array[float] = [INF, INF, INF, INF]
var selection_events: Array[Dictionary] = []
var selection_count := 0
var active_threat_count := 0
var intervention_count := 0
var urgent_unavailable_count := 0
var urgent_selected_count := 0
var chosen_counts: Array[int] = [0, 0, 0, 0]
var chain_model: ChainModel
var paired_run_lengths: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _pending: Dictionary = {}
var _baseline_length_chain: ChainModel

func _init(arm_value := "baseline", seed_value := 1, baseline_chain_seed := 0) -> void:
	arm = arm_value if ARM_BOOSTS.has(arm_value) else "baseline"
	boost = float(ARM_BOOSTS[arm])
	_rng.seed = seed_value if seed_value != 0 else 1
	if baseline_chain_seed != 0:
		_baseline_length_chain = ChainModel.new()
		_baseline_length_chain.set_fresh_seed(baseline_chain_seed)

func set_threat_snapshot(values: Array) -> void:
	for identity in range(TeamData.COUNT):
		threat_snapshot[identity] = float(values[identity]) if identity < values.size() else INF

func urgency_for_ttd(ttd: float) -> float:
	if is_inf(ttd) or is_nan(ttd):
		return 0.0
	return clampf((THREAT_CEILING - ttd) / THREAT_SPAN, 0.0, 1.0)

func choose(legal: Array, _previous: int, _time: float, baseline_choice: int) -> int:
	_pending.clear()
	var urgencies: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var maximum_urgency := 0.0
	var desired := -1
	var desired_ttd := INF
	for identity in range(TeamData.COUNT):
		urgencies[identity] = urgency_for_ttd(threat_snapshot[identity])
		maximum_urgency = maxf(maximum_urgency, urgencies[identity])
		if urgencies[identity] > 0.0 and threat_snapshot[identity] < desired_ttd:
			desired_ttd = threat_snapshot[identity]
			desired = identity
	_pending = {
		"urgencies": urgencies,
		"desired": desired,
		"desired_available": desired >= 0 and legal.has(desired),
		"rng_roll": -1.0,
	}
	# Zero bias and no-threat moments take the exact old bag candidate without a
	# bias RNG draw. This makes both baseline and the no-threat ablation exact.
	if boost <= 0.0 or maximum_urgency <= 0.0:
		return baseline_choice
	var total_weight := 0.0
	for identity_value in legal:
		total_weight += 1.0 + boost * urgencies[int(identity_value)]
	var roll := _rng.randf() * total_weight
	_pending.rng_roll = roll
	var cumulative := 0.0
	for identity_value in legal:
		var identity := int(identity_value)
		cumulative += 1.0 + boost * urgencies[identity]
		if roll <= cumulative:
			return identity
	return int(legal[-1])

func observe(event: Dictionary) -> void:
	selection_count += 1
	var chosen := int(event.chosen)
	chosen_counts[chosen] += 1
	var urgencies: Array = _pending.get("urgencies", _current_urgencies())
	var maximum_urgency := 0.0
	for urgency in urgencies:
		maximum_urgency = maxf(maximum_urgency, float(urgency))
	var active := maximum_urgency > 0.0
	var desired := int(_pending.get("desired", _most_urgent_identity()))
	var desired_available := bool(_pending.get("desired_available", desired >= 0 and event.legal.has(desired)))
	if active:
		active_threat_count += 1
		if not desired_available:
			urgent_unavailable_count += 1
		if desired_available and chosen == desired:
			urgent_selected_count += 1
	if chosen != int(event.baseline_choice):
		intervention_count += 1
	if selection_events.size() < MAX_RECORDED_EVENTS:
		selection_events.append({
			"time": float(event.time),
			"legal": event.legal.duplicate(),
			"previous": int(event.previous),
			"baseline_choice": int(event.baseline_choice),
			"chosen": chosen,
			"ttd": threat_snapshot.duplicate(),
			"urgencies": urgencies.duplicate(),
			"active_threat": active,
			"desired": desired,
			"desired_available": desired_available,
			"rng_roll": float(_pending.get("rng_roll", -1.0)),
			"first_uid": int(chain_model._next_ball_id) if chain_model != null else -1,
		})
	_pending.clear()

func choose_paired_run_length(drawn_length: int, _run_index: int, _time: float) -> int:
	if _baseline_length_chain == null:
		paired_run_lengths.append(drawn_length)
		return drawn_length
	while _baseline_length_chain._fresh_run_remaining > 0:
		_baseline_length_chain._draw_fresh_identity()
	_baseline_length_chain._draw_fresh_identity()
	var paired_length := _baseline_length_chain._fresh_run_remaining + 1
	paired_run_lengths.append(paired_length)
	return paired_length

func summary() -> Dictionary:
	return {
		"arm": arm,
		"boost": boost,
		"selections": selection_count,
		"active_threat_selections": active_threat_count,
		"interventions": intervention_count,
		"urgent_unavailable": urgent_unavailable_count,
		"urgent_selected": urgent_selected_count,
		"chosen_counts": chosen_counts.duplicate(),
	}

func _current_urgencies() -> Array[float]:
	var result: Array[float] = []
	for ttd in threat_snapshot:
		result.append(urgency_for_ttd(ttd))
	return result

func _most_urgent_identity() -> int:
	var result := -1
	var best := INF
	for identity in range(TeamData.COUNT):
		if urgency_for_ttd(threat_snapshot[identity]) > 0.0 and threat_snapshot[identity] < best:
			best = threat_snapshot[identity]
			result = identity
	return result
