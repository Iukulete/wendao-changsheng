extends RefCounted

## Scene-facing port. The native world owns work state; this mirror serves UI
## and schema37 serialization. Economy and actual arrival remain scene commands.
## The pure reference model is also the fallback and the save-validation oracle.
const Reference = preload("res://scripts/modules/residents/ark_household_work.gd")
const PREPARE_SECONDS = Reference.PREPARE_SECONDS
const REPAIR_SECONDS = Reference.REPAIR_SECONDS
const MAX_STEP = Reference.MAX_STEP
const MAX_COMPLETIONS = Reference.MAX_COMPLETIONS
const RESIDENT_ID := 1 # Stable sailmaker work identity, never a Flecs entity handle.
const PARTS := ["", "raft_edge", "shelter_roof"]
const PHASES := ["idle", "prepare", "repair"]
var _mirror = Reference.new()
var _kernel: RefCounted
var _backend := "reference"
var _reason := "原生库未构建；参考模拟"
var _healthy := true

var enabled: bool:
	get: return _mirror.enabled
	set(value):
		if _kernel != null: _command(1, [float(value)])
		else: _mirror.enabled = value
var phase: String:
	get: return _mirror.phase
var part: String:
	get: return _mirror.part
var prepare_elapsed: float:
	get: return _mirror.prepare_elapsed
var repair_elapsed: float:
	get: return _mirror.repair_elapsed
var completed: int:
	get: return _mirror.completed
var last_part: String:
	get: return _mirror.last_part

func _init(mode: String = "auto", extension_override: String = "") -> void:
	if mode == "reference":
		_reason = "显式参考模拟（测试 / 对照）"
		return
	var descriptor := extension_override if not extension_override.is_empty() else OS.get_environment("ARK_SIMULATION_EXTENSION")
	if descriptor.is_empty():
		var bundled := OS.get_executable_path().get_base_dir().path_join("native/ark_simulation.gdextension")
		descriptor = bundled if FileAccess.file_exists(bundled) else ProjectSettings.globalize_path("res://").path_join("../.local/native/ark_simulation/ark_simulation.gdextension").simplify_path()
	if not descriptor.is_absolute_path() or not FileAccess.file_exists(descriptor):
		return
	var status := GDExtensionManager.LOAD_STATUS_ALREADY_LOADED if GDExtensionManager.is_extension_loaded(descriptor) else GDExtensionManager.load_extension(descriptor)
	if not status in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED] or not ClassDB.class_exists("ArkSimulationKernel"):
		_reason = "原生库加载失败；参考模拟"
		return
	_kernel = ClassDB.instantiate("ArkSimulationKernel") as RefCounted
	if _kernel == null or not _kernel.has_method("dispatch") or not _command(0):
		_kernel = null
		_reason = "原生内核握手失败；参考模拟"
		return
	_backend = "native-flecs"
	_reason = "C++ / Flecs 4.1.6；主线程命令边界"

func backend_status() -> Dictionary:
	return {"backend": _backend, "reason": _reason, "resident_id": RESIDENT_ID, "healthy": _healthy}

func _protocol_failure() -> bool:
	_healthy = false
	_reason = "原生协议错误；暂停工作，不扣材料"
	push_warning(_reason)
	return false

func _command(op: int, values: Array = []) -> bool:
	if not _healthy: return false
	var packet := PackedFloat64Array([1.0, float(op), float(RESIDENT_ID)])
	for value in values: packet.append(float(value))
	var response: PackedFloat64Array = _kernel.call("dispatch", packet)
	if response.size() != 10 or response[0] != 1.0:
		return _protocol_failure()
	for index in range(1, 10):
		if not is_finite(response[index]): return _protocol_failure()
	for index in [1, 2, 3, 4, 5, 8, 9]:
		var maximum := 1 if index in [1, 2, 3] else MAX_COMPLETIONS if index == 8 else 2
		if response[index] < 0 or response[index] > maximum or response[index] != floor(response[index]): return _protocol_failure()
	var state := {"enabled": response[3] == 1.0, "phase": PHASES[int(response[4])], "part": PARTS[int(response[5])], "prepare_elapsed": response[6], "repair_elapsed": response[7], "completed": response[8], "last_part": PARTS[int(response[9])]}
	var valid: bool = _mirror.restore(state)
	if not valid: return _protocol_failure()
	return response[2] == 1.0 if op == 3 else response[1] == 1.0

func active() -> bool: return _healthy and _mirror.active()
func ready() -> bool: return _healthy and _mirror.ready()
func operation_id() -> String: return _mirror.operation_id()
func snapshot() -> Dictionary: return _mirror.snapshot()
func matches_economy(receipts: Dictionary) -> bool: return _mirror.matches_economy(receipts)

func begin(target_part: String) -> bool:
	return _command(2, [PARTS.find(target_part)]) if _kernel != null else _mirror.begin(target_part)

func advance(delta: float) -> bool:
	return _command(3, [delta]) if _kernel != null else _mirror.advance(delta)

func finish() -> bool:
	return _command(4) if _kernel != null else _mirror.finish()

func cancel() -> void:
	if _kernel != null: _command(5)
	else: _mirror.cancel()

func restore(saved: Dictionary) -> bool:
	# Validate a detached candidate: never change an active native world to probe a save.
	var candidate = Reference.new()
	if not candidate.restore(saved): return false
	if _kernel == null: return _mirror.restore(saved)
	return _command(6, [float(saved.enabled), PHASES.find(saved.phase), PARTS.find(saved.part), saved.prepare_elapsed, saved.repair_elapsed, saved.completed, PARTS.find(saved.last_part)])
