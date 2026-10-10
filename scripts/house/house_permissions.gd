extends RefCounted
class_name HousePermissions
## Role checks for house access and furniture mutation.

enum Role {
	NONE,
	VISITOR,
	COLLABORATOR,
	OWNER,
}


static func role_for(house: HouseLayout, player_id: String, granted_collab: bool = false) -> int:
	if house == null or player_id == "":
		return Role.NONE
	if player_id == house.owner_id:
		return Role.OWNER
	if granted_collab and house.collaboration_enabled:
		return Role.COLLABORATOR
	# Presence in the house room implies visitor once invite was accepted.
	return Role.VISITOR


static func can_enter(house: HouseLayout, player_id: String, via_invite: bool) -> bool:
	if house == null or player_id == "":
		return false
	if player_id == house.owner_id:
		return true
	return via_invite


static func can_decorate(house: HouseLayout, player_id: String) -> bool:
	if house == null:
		return false
	if player_id == house.owner_id:
		return true
	return house.collaboration_enabled


static func can_toggle_collab(house: HouseLayout, player_id: String) -> bool:
	return house != null and player_id == house.owner_id


static func can_manage_invite(house: HouseLayout, player_id: String) -> bool:
	return house != null and player_id == house.owner_id


static func can_set_house_size(house: HouseLayout, player_id: String) -> bool:
	## Expanding / shrinking the room is owner-only (not collaborators).
	return house != null and player_id == house.owner_id


static func role_name(role: int) -> String:
	match role:
		Role.OWNER:
			return "Owner"
		Role.COLLABORATOR:
			return "Collaborator"
		Role.VISITOR:
			return "Visitor"
		_:
			return "None"
