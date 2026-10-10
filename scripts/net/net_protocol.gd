extends RefCounted
class_name NetProtocol
## JSON message envelope for CozyBlocks house multiplayer.

const PROTO_VERSION := 1

# Client → server
const C_HELLO := "hello"
const C_ENTER_OWN := "enter_own_house"
const C_JOIN_INVITE := "join_invite"
const C_LEAVE_HOUSE := "leave_house"
const C_MOVE := "move"
const C_FURN_PLACE := "furn_place"
const C_FURN_MOVE := "furn_move"
const C_FURN_ROTATE := "furn_rotate"
const C_FURN_REMOVE := "furn_remove"
const C_SET_COLLAB := "set_collab"
const C_SET_HOUSE_SIZE := "set_house_size"
const C_REQUEST_INVITE := "request_invite"
const C_REVOKE_INVITE := "revoke_invite"
const C_ROTATE_INVITE := "rotate_invite"
const C_SET_OWNER := "set_owner" ## always rejected — ownership is server-bound
const C_PING := "ping"

# Server → client
const S_WELCOME := "welcome"
const S_ERROR := "error"
const S_HOUSE_STATE := "house_state"
const S_PLAYER_JOINED := "player_joined"
const S_PLAYER_LEFT := "player_left"
const S_PLAYER_MOVE := "player_move"
const S_FURN_UPSERT := "furn_upsert"
const S_FURN_REMOVED := "furn_removed"
const S_COLLAB_CHANGED := "collab_changed"
const S_HOUSE_SIZE_CHANGED := "house_size_changed"
const S_INVITE := "invite"
const S_PONG := "pong"
const S_LEFT_HOUSE := "left_house"


static func pack(type: String, payload: Dictionary = {}, op_id: String = "") -> String:
	var msg := {
		"v": PROTO_VERSION,
		"t": type,
		"p": payload,
	}
	if op_id != "":
		msg["op"] = op_id
	return JSON.stringify(msg)


static func unpack(text: String) -> Dictionary:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if int(data.get("v", 0)) != PROTO_VERSION:
		return {}
	if not data.has("t"):
		return {}
	if typeof(data.get("p", {})) != TYPE_DICTIONARY:
		data["p"] = {}
	return data
