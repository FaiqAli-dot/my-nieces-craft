extends Node
## Milestone A — house reconnect loop, session reuse, duplicate state.

const CLOSED_PORT := 19399
const SERVER_PORT := 19187
const HOUSE_SCENE := "res://scenes/house/house.tscn"

var runner: Node
var _saved := {}
var _tmp_tag := ""


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[net] " + msg)


func run() -> void:
	_tmp_tag = str(Time.get_ticks_usec())
	_save_net()
	await _test_failed_attempts_back_off_and_stop()
	await _test_connect_is_idempotent()
	_test_identity_is_stable()
	await _test_repeated_offline_house_entry()
	await _test_online_reconnect_rejoins_same_house()
	_restore_net()


func _save_net() -> void:
	_saved = {
		"host": NetClient.host,
		"port": NetClient.port,
		"base": NetClient.retry_base_ms,
		"max": NetClient.max_failed_attempts,
		"identity_path": NetClient.identity_path,
		"dev_identity": NetClient.dev_identity,
		"env_data": OS.get_environment("COZY_HOUSE_DATA"),
		"env_port": OS.get_environment("COZY_NET_PORT"),
	}
	NetClient.host = "127.0.0.1"
	NetClient.retry_base_ms = 40.0
	NetClient.max_failed_attempts = 3
	NetClient.identity_path = "user://test_identity_%s.cfg" % _tmp_tag
	NetClient.dev_identity = ""


func _restore_net() -> void:
	NetClient.disconnect_from_server()
	NetClient.host = _saved["host"]
	NetClient.port = _saved["port"]
	NetClient.retry_base_ms = _saved["base"]
	NetClient.max_failed_attempts = _saved["max"]
	NetClient.identity_path = _saved["identity_path"]
	NetClient.dev_identity = _saved["dev_identity"]
	OS.set_environment("COZY_HOUSE_DATA", _saved["env_data"])
	OS.set_environment("COZY_NET_PORT", _saved["env_port"])


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _wait_seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _net_listener_count() -> int:
	return (
		NetClient.house_state.get_connections().size()
		+ NetClient.disconnected.get_connections().size()
		+ NetClient.connection_failed.get_connections().size()
		+ NetClient.gave_up.get_connections().size()
		+ NetClient.welcomed.get_connections().size()
	)


func _test_failed_attempts_back_off_and_stop() -> void:
	NetClient.disconnect_from_server()
	NetClient.port = CLOSED_PORT
	var fails: Array = []
	var gave := [0]
	var on_fail := func(attempt: int, next: float): fails.append([attempt, next])
	var on_gave := func(): gave[0] += 1
	NetClient.connection_failed.connect(on_fail)
	NetClient.gave_up.connect(on_gave)
	var before := NetClient.connect_attempts
	NetClient.connect_to_server()
	var stopped := await _wait_until(func(): return gave[0] > 0, 4.0)
	check(stopped, "unreachable server stops retrying (gave_up)")
	check(NetClient.connect_attempts - before == 3, "exactly max_failed_attempts socket attempts (got %d)" % (NetClient.connect_attempts - before))
	check(fails.size() == 3, "one connection_failed per attempt")
	if fails.size() == 3:
		check(fails[1][1] > fails[0][1], "backoff grows between attempts")
		check(fails[2][1] < 0.0, "last failure reports no further retry")
	check(NetClient.connection_status() == "offline", "status offline after giving up")
	var settled := NetClient.connect_attempts
	await _wait_seconds(0.5)
	check(NetClient.connect_attempts == settled, "no attempts after giving up")
	check(gave[0] == 1, "gave_up emitted once")
	NetClient.connection_failed.disconnect(on_fail)
	NetClient.gave_up.disconnect(on_gave)
	# Manual retry restarts a bounded cycle.
	var before_retry := NetClient.connect_attempts
	NetClient.retry_now()
	await _wait_until(func(): return NetClient.connection_status() == "offline" and NetClient.connect_attempts - before_retry >= 3, 4.0)
	await _wait_seconds(0.3)
	check(NetClient.connect_attempts - before_retry == 3, "retry_now runs one bounded cycle")
	NetClient.disconnect_from_server()


func _test_connect_is_idempotent() -> void:
	NetClient.disconnect_from_server()
	NetClient.port = CLOSED_PORT
	var before := NetClient.connect_attempts
	for _i in 5:
		NetClient.connect_to_server()
	check(NetClient.connect_attempts - before == 1, "connect_to_server x5 while connecting opens one socket")
	NetClient.disconnect_from_server()
	await get_tree().process_frame
	check(NetClient.connection_status() == "idle", "teardown returns to idle")


func _test_identity_is_stable() -> void:
	var a := NetClient.resolved_identity()
	var b := NetClient.resolved_identity()
	check(a != "" and a == b, "guest identity stable across connects")
	check(a.begins_with("guest_"), "guest identity format")
	check(FileAccess.file_exists(NetClient.identity_path), "identity persisted")
	NetClient.dev_identity = "dev_override"
	check(NetClient.resolved_identity() == "dev_override", "COZY_DEV_IDENTITY overrides")
	NetClient.dev_identity = ""


func _test_repeated_offline_house_entry() -> void:
	NetClient.disconnect_from_server()
	NetClient.port = CLOSED_PORT
	OS.set_environment("COZY_HOUSE_DATA", "user://test_offline_house_%s" % _tmp_tag)
	var baseline := _net_listener_count()
	var scene: PackedScene = load(HOUSE_SCENE)
	for entry in 3:
		var attempts_before := NetClient.connect_attempts
		var house = scene.instantiate()
		house.offline_probe_sec = 0.2
		runner.add_child(house)
		var label := "entry %d" % (entry + 1)
		check(_net_listener_count() > baseline, label + ": house listens to NetClient")
		var gave := await _wait_until(func(): return NetClient.connection_status() == "offline" and not NetClient._wanted, 4.0)
		check(gave, label + ": retries stop without a server")
		check(NetClient.connect_attempts - attempts_before == 3, label + ": bounded attempts (%d)" % (NetClient.connect_attempts - attempts_before))
		check(house.offline_entries == 1, label + ": offline mode entered once (%d)" % house.offline_entries)
		check(house.placement.can_decorate, label + ": offline decorating enabled")
		if entry == 0:
			house._place_furniture_local("chair", Vector2i(2, 2), 0)
		check(house._furniture.size() == 1, label + ": furniture persisted, not duplicated (%d)" % house._furniture.size())
		# Later failures / probe must not rebuild or teleport.
		var marker := Vector3(3.3, house.player.global_position.y, 4.4)
		house.player.global_position = marker
		house._on_net_connection_failed(2, 1.0)
		house._on_offline_probe()
		house._on_net_gave_up()
		var p: Vector3 = house.player.global_position
		check(Vector2(p.x, p.z).distance_to(Vector2(marker.x, marker.z)) < 0.05, label + ": player not teleported by repeat failures")
		check(house.offline_entries == 1, label + ": still one offline entry after repeats")
		check(house._remotes.is_empty(), label + ": no phantom remote players")
		NetClient.disconnect_from_server()
		house.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		check(_net_listener_count() == baseline, label + ": listeners released on exit")


func _test_online_reconnect_rejoins_same_house() -> void:
	NetClient.disconnect_from_server()
	var data_dir := "user://test_online_house_%s" % _tmp_tag
	OS.set_environment("COZY_HOUSE_DATA", data_dir)
	OS.set_environment("COZY_NET_PORT", str(SERVER_PORT))
	NetClient.port = SERVER_PORT
	NetClient.max_failed_attempts = 6
	var server := GameServer.new()
	runner.add_child(server)
	await get_tree().process_frame
	var scene: PackedScene = load(HOUSE_SCENE)
	var house = scene.instantiate()
	house.offline_probe_sec = 30.0
	runner.add_child(house)
	var joined := await _wait_until(func(): return not NetClient.current_house.is_empty(), 4.0)
	check(joined, "online: entered own house")
	var hid1 := str(NetClient.current_house.get("house_id", ""))
	check(house.offline_entries == 0, "online: no offline fallback when server is up")
	var rev := NetClient.revision
	NetClient.place_furniture("chair", Vector2i(2, 2), 0)
	await _wait_until(func(): return NetClient.revision > rev, 3.0)
	check(house._furniture.size() == 1, "online: chair placed")
	var listeners := _net_listener_count()

	# Drop the server; the client must notice once and reconnect after it returns.
	var lost := [0]
	var on_lost := func(): lost[0] += 1
	NetClient.disconnected.connect(on_lost)
	server.queue_free()
	await _wait_until(func(): return lost[0] > 0, 4.0)
	check(lost[0] == 1, "online: one disconnected event for a dropped server")
	var attempts_at_drop := NetClient.connect_attempts
	server = GameServer.new()
	runner.add_child(server)
	var rejoined := await _wait_until(func(): return not NetClient.current_house.is_empty(), 6.0)
	check(rejoined, "online: reconnected after server restart")
	check(str(NetClient.current_house.get("house_id", "")) == hid1, "online: same private house after reconnect")
	check(NetClient.connect_attempts - attempts_at_drop <= 4, "online: bounded reconnect attempts (%d)" % (NetClient.connect_attempts - attempts_at_drop))
	await _wait_seconds(0.3)
	check(house._furniture.size() == 1, "online: furniture not duplicated after reconnect (%d)" % house._furniture.size())
	check(house._remotes.is_empty(), "online: no duplicate self as remote player")
	NetClient.disconnected.disconnect(on_lost)
	check(_net_listener_count() == listeners, "online: no duplicate listeners after reconnect")

	# Re-enter the house scene twice: one connection per entry, same house.
	for entry in 2:
		NetClient.disconnect_from_server()
		house.queue_free()
		await get_tree().process_frame
		var before := NetClient.connect_attempts
		house = scene.instantiate()
		house.offline_probe_sec = 30.0
		runner.add_child(house)
		var ok := await _wait_until(func(): return not NetClient.current_house.is_empty(), 4.0)
		check(ok and str(NetClient.current_house.get("house_id", "")) == hid1, "online re-entry %d: same house" % (entry + 1))
		await _wait_seconds(0.4)
		check(NetClient.connect_attempts - before == 1, "online re-entry %d: exactly one connection" % (entry + 1))
		check(house._furniture.size() == 1, "online re-entry %d: furniture not duplicated" % (entry + 1))

	NetClient.disconnect_from_server()
	house.queue_free()
	server.queue_free()
	NetClient.max_failed_attempts = 3
	await get_tree().process_frame
