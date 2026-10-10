extends RefCounted
class_name HouseStore
## JSON file persistence for houses. Survives process restarts.

var root_dir: String = "user://houses"


func _init(p_root: String = "") -> void:
	if p_root != "":
		root_dir = p_root
	DirAccess.make_dir_recursive_absolute(root_dir)
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("by_owner"))
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("invites"))


func _house_path(house_id: String) -> String:
	return root_dir.path_join("%s.json" % house_id)


func _owner_index_path(owner_id: String) -> String:
	return root_dir.path_join("by_owner").path_join("%s.txt" % owner_id.uri_encode())


func _invite_path(code: String) -> String:
	return root_dir.path_join("invites").path_join("%s.txt" % code.to_upper())


func save_house(house: HouseLayout) -> bool:
	house.updated_at = int(Time.get_unix_time_from_system())
	if house.created_at == 0:
		house.created_at = house.updated_at
	var path := _house_path(house.house_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(house.to_dict()))
	# owner index
	var of := FileAccess.open(_owner_index_path(house.owner_id), FileAccess.WRITE)
	if of:
		of.store_string(house.house_id)
	# invite index
	if house.invite_code != "":
		var inv := FileAccess.open(_invite_path(house.invite_code), FileAccess.WRITE)
		if inv:
			inv.store_string(house.house_id)
	return true


func load_house(house_id: String) -> HouseLayout:
	var path := _house_path(house_id)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return HouseLayout.from_dict(data)


func get_house_id_for_owner(owner_id: String) -> String:
	var path := _owner_index_path(owner_id)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


func get_house_id_for_invite(code: String) -> String:
	var path := _invite_path(code.strip_edges().to_upper())
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


func ensure_house_for_owner(owner_id: String, display_name: String = "") -> HouseLayout:
	var existing_id := get_house_id_for_owner(owner_id)
	if existing_id != "":
		var existing := load_house(existing_id)
		if existing != null:
			return existing
	var house := HouseLayout.new()
	house.house_id = _new_id("house")
	house.owner_id = owner_id
	house.invite_code = _new_invite_code()
	house.display_name = display_name if display_name != "" else "House of %s" % owner_id
	house.created_at = int(Time.get_unix_time_from_system())
	house.updated_at = house.created_at
	save_house(house)
	return house


func rotate_invite(house: HouseLayout) -> void:
	var old := house.invite_code
	if old != "":
		var old_path := _invite_path(old)
		if FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(old_path)
	house.invite_code = _new_invite_code()
	house.invite_revoked = false
	house.invite_expires_at = 0
	save_house(house)


func revoke_invite(house: HouseLayout) -> void:
	house.invite_revoked = true
	if house.invite_code != "":
		var path := _invite_path(house.invite_code)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save_house(house)


func clear_invite_index(code: String) -> void:
	var path := _invite_path(code)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _new_id(prefix: String) -> String:
	return "%s_%s_%d" % [prefix, _rand_token(8), Time.get_ticks_usec()]


func _new_invite_code() -> String:
	# Short kid-friendly code, uppercase alnum without ambiguous chars
	const ALPH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 6:
		code += ALPH[randi() % ALPH.length()]
	return code


func _rand_token(n: int) -> String:
	const ALPH := "abcdefghijklmnopqrstuvwxyz0123456789"
	var s := ""
	for i in n:
		s += ALPH[randi() % ALPH.length()]
	return s
