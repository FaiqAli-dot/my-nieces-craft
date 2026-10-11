extends Node
class_name BuildController
## Wall / window / door / remove tool for the house. Aims at the nearest cell
## edge under the crosshair (or mouse) and previews validity with the same
## HouseStructure rules the server uses.

signal build_requested(edge: String, kind: String)
signal build_cancelled

const PREVIEW_H := 2.7

var active := false
var tool: String = HouseStructure.WALL
var camera: Camera3D
var preview_parent: Node3D
var walls: Dictionary = {}
var cells: int = 12
## Returns the current furniture instance list (Array of Dictionaries).
var furniture_provider: Callable

var _preview: MeshInstance3D
var _mat_ok: StandardMaterial3D
var _mat_remove: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _edge := ""
var _reason: int = HouseStructure.Reason.OUT_OF_BOUNDS


func _ready() -> void:
	_mat_ok = _ghost(Color(0.15, 0.95, 0.35, 0.55))
	_mat_remove = _ghost(Color(1.0, 0.72, 0.2, 0.55))
	_mat_bad = _ghost(Color(0.98, 0.15, 0.15, 0.55))


func _ghost(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func tool_label(kind: String) -> String:
	match kind:
		HouseStructure.WALL:
			return "Wall"
		HouseStructure.WINDOW:
			return "Window"
		HouseStructure.DOOR:
			return "Door"
		_:
			return "Remove"


func begin(kind: String) -> void:
	tool = kind
	active = true
	if _preview == null and preview_parent != null:
		_preview = MeshInstance3D.new()
		_preview.name = "BuildPreview"
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, PREVIEW_H, 0.3)
		_preview.mesh = bm
		preview_parent.add_child(_preview)
	if _preview:
		_preview.visible = false
	GameState.toast(tool_label(kind) + " — aim at a wall line, click or Place")


func cancel() -> void:
	var was := active
	active = false
	_edge = ""
	if _preview:
		_preview.visible = false
	if was:
		build_cancelled.emit()


func target_edge() -> String:
	return _edge


func is_valid() -> bool:
	return _reason == HouseStructure.Reason.OK


func last_reason() -> int:
	return _reason


## Aim at a specific edge (tests / touch nudges).
func aim_edge(edge: String) -> void:
	_edge = edge
	_evaluate()


func confirm() -> bool:
	if not active:
		return false
	if _edge == "" or not is_valid():
		GameState.toast(HouseStructure.reason_text(_reason))
		return false
	build_requested.emit(_edge, tool)
	return true


func _physics_process(_delta: float) -> void:
	if not active or camera == null:
		return
	var p := _aim_point()
	if p == Vector3.INF:
		_edge = ""
		_reason = HouseStructure.Reason.OUT_OF_BOUNDS
		if _preview:
			_preview.visible = false
		return
	_edge = HouseStructure.edge_near(p)
	_evaluate()


func _evaluate() -> void:
	var furn: Array = furniture_provider.call() if furniture_provider.is_valid() else []
	_reason = HouseStructure.validate_edit(walls, cells, furn, _edge, tool)
	if _preview == null:
		return
	if not HouseStructure.in_bounds(_edge, cells):
		_preview.visible = false
		return
	_preview.visible = true
	var c := HouseStructure.edge_center(_edge)
	_preview.global_position = c + Vector3(0, PREVIEW_H * 0.5, 0)
	_preview.rotation.y = PI * 0.5 if HouseStructure.parse(_edge)["axis"] == "v" else 0.0
	if not is_valid():
		_preview.material_override = _mat_bad
	elif tool == HouseStructure.NONE:
		_preview.material_override = _mat_remove
	else:
		_preview.material_override = _mat_ok


func _aim_point() -> Vector3:
	var vp := camera.get_viewport()
	var mouse := vp.get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse = vp.get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0)
	q.collision_mask = 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var n: Node = hit["collider"]
		while n != null:
			if n.has_meta("edge"):
				return HouseStructure.edge_center(str(n.get_meta("edge")))
			if n.has_meta("door_edge"):
				return HouseStructure.edge_center(str(n.get_meta("door_edge")))
			n = n.get_parent()
		return hit["position"]
	if absf(dir.y) < 0.001:
		return Vector3.INF
	var t := -from.y / dir.y
	return from + dir * t if t > 0.0 else Vector3.INF
