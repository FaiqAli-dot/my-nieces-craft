extends Node
## Milestone C — walls, windows, doors, garden and their persistence.

const HOUSE_SCENE := "res://scenes/house/house.tscn"

var runner: Node
var _tag := ""


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[structure] " + msg)


func run() -> void:
	_tag = str(Time.get_ticks_usec())
	_test_defaults()
	_test_migration_and_sanitize()
	_test_interior_wall_build_remove()
	_test_perimeter_edits()
	_test_rejections()
	_test_last_exit()
	_test_furniture_rules()
	_test_resize()
	_test_door_toggle()
	_test_store_round_trip()
	_test_server_permissions()
	await _test_view()
	await _test_build_controller()
	await _test_offline_house_world()


func _table_at(x: int, z: int, iid: String = "t1") -> Dictionary:
	return {"instance_id": iid, "def_id": "table", "cell_x": x, "cell_z": z, "rotation": 0}


func _test_defaults() -> void:
	var p := HouseStructure.pieces({}, 12)
	check(p.size() == 48, "default 12×12 perimeter has 48 pieces (%d)" % p.size())
	check(p.get("v:12:5", "") == HouseStructure.DOOR and p.get("v:12:6", "") == HouseStructure.DOOR, "default east double door")
	check(p.get("h:3:0", "") == HouseStructure.WINDOW and p.get("h:8:0", "") == HouseStructure.WINDOW, "default north windows")
	check(HouseStructure.exit_count({}, 12) == 2, "two default exits")
	check(HouseStructure.kind_at({}, "v:6:3", 12) == HouseStructure.NONE, "interior edges empty by default")
	check(HouseStructure.pieces({}, 16).size() == 64, "medium house perimeter scales")


func _test_migration_and_sanitize() -> void:
	var old := HouseLayout.from_dict({"schema": 2, "house_id": "h_old", "owner_id": "o", "size_tier": "small"})
	check(old.walls.is_empty(), "schema-2 save loads with no wall overrides")
	check(HouseStructure.kind_at(old.walls, "v:12:5", old.cells()) == HouseStructure.DOOR, "migrated house gets default door")
	check(int(old.to_dict()["schema"]) == 3, "re-saved at schema 3")
	var raw := {"v:6:3": "wall", "h:99:0": "wall", "bogus": "door", "v:2:2": "lava", "h:2:0": "open"}
	var clean := HouseStructure.sanitize(raw, 12)
	check(clean.size() == 2 and clean.has("v:6:3") and clean.has("h:2:0"), "sanitize drops bad keys/kinds (%s)" % str(clean))
	check(HouseStructure.sanitize("nope", 12).is_empty(), "sanitize rejects non-dictionary")
	var loaded := HouseLayout.from_dict({"schema": 3, "house_id": "h", "owner_id": "o", "size_tier": "small", "walls": raw})
	check(loaded.walls == clean, "from_dict sanitizes untrusted walls")


func _test_interior_wall_build_remove() -> void:
	var w := {}
	check(HouseStructure.validate_edit(w, 12, [], "v:6:3", "wall") == HouseStructure.Reason.OK, "interior wall allowed")
	HouseStructure.apply_edit(w, 12, "v:6:3", "wall")
	check(w.get("v:6:3", "") == "wall", "interior wall stored")
	check(HouseStructure.validate_edit(w, 12, [], "v:6:3", "") == HouseStructure.Reason.OK, "interior wall removable")
	HouseStructure.apply_edit(w, 12, "v:6:3", "")
	check(w.is_empty(), "removing interior wall leaves no override")
	HouseStructure.apply_edit(w, 12, "h:4:4", "door")
	check(HouseStructure.kind_at(w, "h:4:4", 12) == HouseStructure.DOOR, "interior door built")
	HouseStructure.apply_edit(w, 12, "h:5:4", "window")
	check(HouseStructure.kind_at(w, "h:5:4", 12) == HouseStructure.WINDOW, "interior window built")


func _test_perimeter_edits() -> void:
	var w := {}
	HouseStructure.apply_edit(w, 12, "h:5:12", "")
	check(w.get("h:5:12", "") == HouseStructure.OPEN, "knocked-out perimeter stored as open")
	check(HouseStructure.kind_at(w, "h:5:12", 12) == HouseStructure.NONE, "open perimeter reads empty")
	check(HouseStructure.exit_count(w, 12) == 3, "opening adds an exit")
	HouseStructure.apply_edit(w, 12, "h:5:12", "wall")
	check(w.is_empty(), "rebuilding default wall clears override")
	HouseStructure.apply_edit(w, 12, "v:0:4", "window")
	check(HouseStructure.kind_at(w, "v:0:4", 12) == HouseStructure.WINDOW, "perimeter window")
	HouseStructure.apply_edit(w, 12, "v:0:4", "door")
	check(HouseStructure.exit_count(w, 12) == 3, "new perimeter door is an exit")


func _test_rejections() -> void:
	var R := HouseStructure.Reason
	check(HouseStructure.validate_edit({}, 12, [], "v:13:0", "wall") == R.OUT_OF_BOUNDS, "outside house rejected")
	check(HouseStructure.validate_edit({}, 12, [], "garbage", "wall") == R.OUT_OF_BOUNDS, "malformed edge rejected")
	check(HouseStructure.validate_edit({}, 12, [], "v:6:3", "lava") == R.BAD_KIND, "unknown piece rejected")
	check(HouseStructure.validate_edit({}, 12, [], "h:2:0", "wall") == R.NO_CHANGE, "same piece is no-op")
	check(HouseStructure.validate_edit({}, 12, [], "v:12:5", "door") == R.NO_CHANGE, "door over door is no-op")
	check(HouseStructure.validate_edit({"v:12:5": "door_open"}, 12, [], "v:12:5", "door") == R.NO_CHANGE, "door over open door is no-op")
	check(HouseStructure.reason_text(R.LAST_EXIT) != "", "reasons have friendly text")


func _test_last_exit() -> void:
	var w := {}
	check(HouseStructure.validate_edit(w, 12, [], "v:12:5", "wall") == HouseStructure.Reason.OK, "can wall one of two doors")
	HouseStructure.apply_edit(w, 12, "v:12:5", "wall")
	check(HouseStructure.validate_edit(w, 12, [], "v:12:6", "wall") == HouseStructure.Reason.LAST_EXIT, "last exit can't be walled")
	check(HouseStructure.validate_edit(w, 12, [], "v:12:6", "window") == HouseStructure.Reason.LAST_EXIT, "last exit can't be windowed")
	HouseStructure.apply_edit(w, 12, "h:0:0", "door")
	check(HouseStructure.validate_edit(w, 12, [], "v:12:6", "wall") == HouseStructure.Reason.OK, "allowed once another door exists")


func _test_furniture_rules() -> void:
	var R := HouseStructure.Reason
	var furn := [_table_at(3, 3)]
	var occ := FurnitureValidator.build_occupied_map(furn)
	check(occ.has("3,3") and occ.has("4,3"), "table covers 2×2")
	check(HouseStructure.validate_edit({}, 12, furn, "v:4:3", "wall") == R.FURNITURE_IN_WAY, "wall can't cut furniture")
	check(HouseStructure.validate_edit({}, 12, furn, "v:5:3", "wall") == R.OK, "wall beside furniture ok")
	check(HouseStructure.validate_edit({}, 12, furn, "v:5:3", "door") == R.DOORWAY_BLOCKED, "door next to furniture blocked")
	var fv := FurnitureValidator
	var rmin := Vector2i(0, 0)
	var rmax := Vector2i(11, 11)
	check(fv.validate_placement("chair", Vector2i(11, 5), 0, rmin, rmax, {}, "", {}, 12) == fv.Reason.DOORWAY, "chair in doorway rejected")
	check(fv.validate_placement("chair", Vector2i(11, 3), 0, rmin, rmax, {}, "", {}, 12) == fv.Reason.OK, "chair by a wall ok")
	var w := {"v:4:3": "wall"}
	check(fv.validate_placement("table", Vector2i(3, 3), 0, rmin, rmax, {}, "", w, 12) == fv.Reason.WALL_IN_WAY, "table across wall rejected")
	check(fv.validate_placement("table", Vector2i(3, 3), 0, rmin, rmax, {}, "", w, 0) == fv.Reason.OK, "cells=0 keeps old behaviour")


func _test_resize() -> void:
	var h := HouseLayout.from_dict({"schema": 3, "house_id": "h_rs", "owner_id": "o", "size_tier": "medium"})
	check(h.cells() == 16, "medium is 16 cells")
	HouseStructure.apply_edit(h.walls, 16, "v:14:2", "wall")
	check(HouseStructure.blocks_resize(h.walls, 12), "wall in extra space blocks shrink")
	check(h.can_apply_size_tier(HouseLayout.SIZE_SMALL) != "", "shrink refused with wall outside")
	HouseStructure.apply_edit(h.walls, 16, "v:14:2", "")
	check(h.can_apply_size_tier(HouseLayout.SIZE_SMALL) == "", "shrink ok once removed")
	var small := {"v:12:5": "door_open", "h:3:12": "open", "v:6:3": "wall"}
	var grown := HouseStructure.on_resize(small, 12, 16)
	check(grown == {"v:6:3": "wall"}, "growing drops old perimeter tweaks (%s)" % str(grown))
	var big := HouseLayout.from_dict({"schema": 3, "house_id": "h_rs2", "owner_id": "o", "size_tier": "small", "walls": {"v:6:3": "wall"}})
	big.apply_size_tier(HouseLayout.SIZE_LARGE)
	check(big.walls.get("v:6:3", "") == "wall", "interior wall survives growth")
	check(HouseStructure.exit_count(big.walls, big.cells()) == 2, "grown house has its own double door")


func _test_door_toggle() -> void:
	var w := {}
	check(HouseStructure.toggle_door(w, 12, "v:12:5") == HouseStructure.DOOR_OPEN, "door opens")
	check(w.get("v:12:5", "") == HouseStructure.DOOR_OPEN, "open state stored")
	check(HouseStructure.toggle_door(w, 12, "v:12:5") == HouseStructure.DOOR, "door closes")
	check(w.is_empty(), "closed default door clears override")
	check(HouseStructure.toggle_door(w, 12, "h:2:0") == "", "window is not a door")
	check(HouseStructure.toggle_door(w, 12, "v:6:3") == "", "empty edge is not a door")


func _test_store_round_trip() -> void:
	var store := HouseStore.new("user://test_struct_store_%s" % _tag)
	var h := store.ensure_house_for_owner("owner_rt", "Rt")
	HouseStructure.apply_edit(h.walls, 12, "v:6:3", "wall")
	HouseStructure.toggle_door(h.walls, 12, "v:12:6")
	store.save_house(h)
	var back := HouseStore.new("user://test_struct_store_%s" % _tag).load_house(h.house_id)
	check(back != null and back.walls == h.walls, "walls + door state persist through HouseStore")


func _test_server_permissions() -> void:
	var store := HouseStore.new("user://test_struct_srv_%s" % _tag)
	var h := store.ensure_house_for_owner("owner_srv", "Srv")
	var rev := h.revision
	var denied := GameServer.apply_struct_for_test(store, h.house_id, "stranger", "v:6:3", "wall")
	check(not bool(denied["ok"]) and str(denied["reason"]) == "no_permission", "visitor can't build")
	var ok := GameServer.apply_struct_for_test(store, h.house_id, "owner_srv", "v:6:3", "wall")
	check(bool(ok["ok"]), "owner builds")
	var back := store.load_house(h.house_id)
	check(back.revision == rev + 1 and back.walls.get("v:6:3", "") == "wall", "server edit saved with revision bump")
	var bad := GameServer.apply_struct_for_test(store, h.house_id, "owner_srv", "v:12:5", "lava")
	check(not bool(bad["ok"]) and store.load_house(h.house_id).revision == rev + 1, "invalid edit leaves house untouched")


func _test_view() -> void:
	var view := HouseStructureView.new()
	add_child(view)
	view.apply({}, 12, false)
	check(view.doors.size() == 2, "view builds two door leaves")
	check(view.piece_kind("h:3:0") == HouseStructure.WINDOW, "view tracks window")
	check(not view.is_door_open("v:12:5"), "doors start closed")
	var shape: CollisionShape3D = view.doors["v:12:5"]["shape"]
	var leaf_root := view.get_child_count()
	view.apply({"v:12:5": "door_open"}, 12, false)
	await get_tree().physics_frame
	check(view.is_door_open("v:12:5"), "door opened in place")
	check(view.get_child_count() == leaf_root and is_instance_valid(shape), "door toggle doesn't rebuild")
	check(shape.disabled, "open door stops colliding")
	view.apply({}, 12, false)
	await get_tree().physics_frame
	check(not shape.disabled, "closed door collides again")
	check(view.nearest_door(Vector3(11.4, 0, 5.4)) == "v:12:5", "nearest door found")
	check(view.nearest_door(Vector3(2, 0, 2)) == "", "no door when far away")
	view.apply({"v:6:3": "wall"}, 12, false)
	check(view.piece_kind("v:6:3") == HouseStructure.WALL, "new wall rebuilds view")
	view.queue_free()
	await get_tree().process_frame


func _test_build_controller() -> void:
	var bc := BuildController.new()
	add_child(bc)
	bc.cells = 12
	bc.walls = {}
	bc.begin(HouseStructure.WALL)
	bc.aim_edge("v:6:3")
	check(bc.is_valid(), "aiming inside: valid wall")
	var got := []
	bc.build_requested.connect(func(e, k): got.append([e, k]))
	check(bc.confirm() and got == [["v:6:3", "wall"]], "confirm emits build request")
	bc.aim_edge("v:20:0")
	check(not bc.is_valid() and not bc.confirm(), "out-of-house aim rejected")
	bc.furniture_provider = func(): return [_table_at(3, 3)]
	bc.aim_edge("v:4:3")
	check(bc.last_reason() == HouseStructure.Reason.FURNITURE_IN_WAY, "preview reports furniture conflict")
	bc.cancel()
	check(not bc.active, "build mode cancels")
	bc.queue_free()
	await get_tree().process_frame


func _test_offline_house_world() -> void:
	NetClient.disconnect_from_server()
	var data_dir := "user://test_struct_world_%s" % _tag
	var prev_auto := OS.get_environment("COZY_NET_AUTOSTART")
	var prev_data := OS.get_environment("COZY_HOUSE_DATA")
	OS.set_environment("COZY_NET_AUTOSTART", "0")
	OS.set_environment("COZY_HOUSE_DATA", data_dir)
	var scene: PackedScene = load(HOUSE_SCENE)
	var house = scene.instantiate()
	runner.add_child(house)
	await get_tree().process_frame
	await get_tree().process_frame
	check(house.is_offline_mode(), "offline house world")
	check(house.space.find_child("MeadowGate", true, false) != null, "garden has a meadow gate")
	check(house.space.garden_size_meters() >= 5.0, "garden band around the house is roomy")
	check(house.space.structure.doors.size() == 2, "house world shows the front door")
	house.player.global_position = Vector3(6, house.player.global_position.y, 6)
	await get_tree().process_frame
	house.ui.show_toast("")
	house.player.global_position = Vector3(11.3, house.player.global_position.y, 6.5)
	await get_tree().process_frame
	check(house.ui.toast_label.text == house.ui.door_hint_text(), "closed door shows open hint")
	house.ui.show_toast("")
	await get_tree().process_frame
	check(house.ui.toast_label.text == "", "hint shows once per approach")
	house._on_build_req("v:6:3", "wall")
	check(house.space.structure.piece_kind("v:6:3") == HouseStructure.WALL, "offline wall built")
	house._on_build_req("v:12:5", "wall")
	house._on_build_req("v:12:6", "wall")
	check(house.space.structure.piece_kind("v:12:6") == HouseStructure.DOOR, "offline last exit protected")
	house.player.global_position = Vector3(11.3, house.player.global_position.y, 6.5)
	check(house.nearest_door() == "v:12:6", "player finds nearest door")
	check(house.toggle_nearest_door(), "player opens door")
	check(house.space.structure.is_door_open("v:12:6"), "door is open")
	# The gate signal fires for the player body; keep this world from leaving.
	house.space.meadow_gate_entered.disconnect(house._on_meadow_gate)
	var gate_hits := [0]
	house.space.meadow_gate_entered.connect(func(): gate_hits[0] += 1)
	house.space._on_gate_body_entered(house.player)
	var prop := StaticBody3D.new()
	house.space._on_gate_body_entered(prop)
	prop.free()
	check(gate_hits[0] == 1, "meadow gate reacts to the player only")
	house.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var house2 = scene.instantiate()
	runner.add_child(house2)
	await get_tree().process_frame
	await get_tree().process_frame
	var s: HouseStructureView = house2.space.structure
	check(s.piece_kind("v:6:3") == HouseStructure.WALL, "wall reloads after re-entering")
	check(s.piece_kind("v:12:5") == HouseStructure.WALL, "walled door reloads")
	check(s.is_door_open("v:12:6"), "open door reloads")
	house2.queue_free()
	await get_tree().process_frame
	OS.set_environment("COZY_NET_AUTOSTART", prev_auto)
	OS.set_environment("COZY_HOUSE_DATA", prev_data)
