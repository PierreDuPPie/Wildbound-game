extends Node
## Shared presentation preferences; never changes game data or save schema.
signal settings_changed
const PATH := "user://mobile_settings.cfg"
var quality: String = "auto"
var follow_smoothing: float = 5.0
var _original_msaa: int
var _original_max_fps: int
var _preview: bool

func _ready() -> void:
	_preview = "--mobile-preview" in OS.get_cmdline_user_args()
	_original_msaa = get_viewport().msaa_3d
	_original_max_fps = Engine.max_fps
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		quality = str(config.get_value("graphics", "quality", "auto"))
		if quality not in ["auto", "low", "medium", "high"]: quality = "auto"
		follow_smoothing = clampf(float(config.get_value("camera", "follow_smoothing", 5.0)), 3.0, 12.0)
	get_tree().node_added.connect(_on_node_added)
	apply_quality.call_deferred()

func effective_quality() -> String:
	if quality != "auto": return quality
	return "medium" if OS.has_feature("android") or OS.has_feature("ios") or _preview else "original"

func set_quality(value: String) -> void:
	if value not in ["auto", "low", "medium", "high"]: return
	quality = value
	_save()
	apply_quality()
	settings_changed.emit()

func set_follow_smoothing(value: float) -> void:
	follow_smoothing = clampf(value, 3.0, 12.0)
	_save()
	settings_changed.emit()

func _save() -> void:
	if _preview: return
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("camera", "follow_smoothing", follow_smoothing)
	if config.save(PATH) != OK: push_warning("Could not save display preferences.")

func apply_quality() -> void:
	var preset := effective_quality()
	get_viewport().msaa_3d = _original_msaa if preset == "original" else Viewport.MSAA_2X if preset == "high" else Viewport.MSAA_DISABLED
	Engine.max_fps = _original_max_fps if preset == "original" else 60 if preset == "high" else 30
	_apply_branch(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D or node is WorldEnvironment or node is MultiMeshInstance3D:
		_apply_node.call_deferred(node)

func _apply_branch(node: Node) -> void:
	_apply_node(node)
	for child in node.get_children(): _apply_branch(child)

func _apply_node(node: Node) -> void:
	if not is_instance_valid(node): return
	var preset := effective_quality()
	if node is DirectionalLight3D:
		if not node.has_meta("rc1_shadow"):
			node.set_meta("rc1_shadow", node.shadow_enabled)
			node.set_meta("rc1_shadow_distance", node.directional_shadow_max_distance)
		node.shadow_enabled = bool(node.get_meta("rc1_shadow")) and preset != "low"
		node.directional_shadow_max_distance = 32.0 if preset == "medium" else float(node.get_meta("rc1_shadow_distance"))
	elif node is MultiMeshInstance3D and node.is_in_group("quality_grass") and node.multimesh != null:
		if not node.has_meta("rc1_grass_count"):
			node.set_meta("rc1_grass_count", node.multimesh.visible_instance_count)
		var count: int = node.multimesh.instance_count
		node.multimesh.visible_instance_count = int(count * (0.4 if preset == "low" else 0.7)) if preset in ["low", "medium"] else int(node.get_meta("rc1_grass_count"))
	elif node is WorldEnvironment and node.environment != null:
		if not node.has_meta("rc1_environment"):
			# Keep the original untouched; only this world's private copy is adjusted.
			node.set_meta("rc1_environment", node.environment)
			node.environment = node.environment.duplicate()
		var original: Environment = node.get_meta("rc1_environment")
		node.environment.ssao_enabled = original.ssao_enabled and preset in ["original", "high"]
		node.environment.glow_enabled = original.glow_enabled and preset != "low"
