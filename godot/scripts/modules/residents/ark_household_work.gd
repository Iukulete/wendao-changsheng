extends RefCounted

## Owns only repeatable work intent/progress. Scene adapters own arrival and
## facility checks; Economy owns stock. No node, clock or inventory is kept here.
const PREPARE_SECONDS := 3.0
const REPAIR_SECONDS := 3.0
const MAX_STEP := 0.1
const MAX_COMPLETIONS := 1000000
var enabled := false
var phase := "idle"
var part := ""
var prepare_elapsed := 0.0
var repair_elapsed := 0.0
var completed := 0
var last_part := ""

func active() -> bool:
	return phase != "idle"

func begin(target_part: String) -> bool:
	if not enabled or active() or completed >= MAX_COMPLETIONS or not target_part in ["raft_edge", "shelter_roof"]:
		return false
	part = target_part
	phase = "prepare"
	return true

func advance(delta: float) -> bool:
	if not enabled or not active() or not is_finite(delta) or delta <= 0.0:
		return false
	var step := minf(delta, MAX_STEP)
	if phase == "prepare":
		prepare_elapsed = minf(PREPARE_SECONDS, prepare_elapsed + step)
		if prepare_elapsed >= PREPARE_SECONDS:
			phase = "repair"
			return true
	else:
		repair_elapsed = minf(REPAIR_SECONDS, repair_elapsed + step)
	return false

func ready() -> bool:
	return phase == "repair" and repair_elapsed == REPAIR_SECONDS

func operation_id() -> String:
	return "home_work:repair:%d" % (completed + 1)

func finish() -> bool:
	if not ready():
		return false
	completed += 1
	last_part = part
	cancel()
	return true

func cancel() -> void:
	phase = "idle"
	part = ""
	prepare_elapsed = 0.0
	repair_elapsed = 0.0

func snapshot() -> Dictionary:
	return {"enabled": enabled, "phase": phase, "part": part, "prepare_elapsed": prepare_elapsed, "repair_elapsed": repair_elapsed, "completed": completed, "last_part": last_part}

func restore(saved: Dictionary) -> bool:
	if saved.size() != 7 or not saved.get("enabled") is bool or not saved.get("phase") is String or not saved.get("part") is String or not saved.get("last_part") is String:
		return false
	for key in ["prepare_elapsed", "repair_elapsed", "completed"]:
		var value: Variant = saved.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	if float(saved.completed) != floor(float(saved.completed)) or float(saved.completed) > MAX_COMPLETIONS or float(saved.prepare_elapsed) > PREPARE_SECONDS or float(saved.repair_elapsed) > REPAIR_SECONDS:
		return false
	if not saved.phase in ["idle", "prepare", "repair"] or (saved.completed == 0 and saved.last_part != "") or (saved.completed > 0 and not saved.last_part in ["raft_edge", "shelter_roof"]):
		return false
	if saved.phase == "idle":
		if saved.part != "" or saved.prepare_elapsed != 0 or saved.repair_elapsed != 0:
			return false
	elif not saved.part in ["raft_edge", "shelter_roof"] or saved.completed >= MAX_COMPLETIONS:
		return false
	elif saved.phase == "prepare" and (saved.prepare_elapsed >= PREPARE_SECONDS or saved.repair_elapsed != 0):
		return false
	elif saved.phase == "repair" and saved.prepare_elapsed != PREPARE_SECONDS:
		return false
	enabled = saved.enabled
	phase = saved.phase
	part = saved.part
	prepare_elapsed = float(saved.prepare_elapsed)
	repair_elapsed = float(saved.repair_elapsed)
	completed = int(saved.completed)
	last_part = saved.last_part
	return true

func matches_economy(receipts: Dictionary) -> bool:
	var count := 0
	for id in receipts:
		if not str(id).begins_with("home_work:repair:"):
			continue
		var suffix := str(id).trim_prefix("home_work:repair:")
		if not suffix.is_valid_int() or str(int(suffix)) != suffix or int(suffix) < 1 or int(suffix) > completed or receipts[id] != true:
			return false
		count += 1
	return count == completed
