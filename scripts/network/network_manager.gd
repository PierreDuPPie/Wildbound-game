extends Node
## Private ENet sessions. The host owns all session inventory and battle state.
## Joining never imports remote resources or modifies the player's solo save.

signal session_changed(snapshot: Dictionary)
signal notice(message: String)

const SessionState = preload("res://scripts/network/session_state.gd")
const PROTOCOL: int = 1
const DEFAULT_PORT: int = 27840
const MAX_COMMAND_BYTES: int = 2048
const SNAPSHOT_INTERVAL: float = 0.10

var _ledger = SessionState.new()
var _peer: ENetMultiplayerPeer
var _hosting: bool = false
var _connected: bool = false
var _player_name: String = "Keeper"
var _snapshot: Dictionary = {}
var _pending: Dictionary = {}
var _rate_windows: Dictionary = {}
var _dirty: bool = false
var _snapshot_elapsed: float = 0.0
var _join_started: float = 0.0
var _presence_sent_at: float = -1.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Prevent Variant packets from instantiating network-supplied objects.
	if multiplayer is SceneMultiplayer:
		(multiplayer as SceneMultiplayer).allow_object_decoding = false
	_reset_snapshot()

func host_session(player_name: String, port: int = DEFAULT_PORT) -> Error:
	if not _valid_name(player_name) or port < 1024 or port > 65535:
		notice.emit("Use a keeper name (1–24 letters/numbers/spaces) and port 1024–65535.")
		return ERR_INVALID_PARAMETER
	leave_session()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(port, SessionState.MAX_PLAYERS - 1, 2)
	if error != OK:
		_peer = null
		notice.emit("Could not host. That UDP port may already be in use.")
		return error
	multiplayer.multiplayer_peer = _peer
	_player_name = player_name.strip_edges()
	_hosting = true
	_connected = true
	_ledger.add_player(1, _player_name)
	_broadcast()
	notice.emit("Private session ready on UDP %d. Share your LAN IP with a friend." % port)
	return OK

func join_session(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	if not _valid_name(player_name) or not _valid_address(address) or port < 1024 or port > 65535:
		notice.emit("Enter a valid host IP/address, keeper name and port.")
		return ERR_INVALID_PARAMETER
	leave_session()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(address.strip_edges(), port, 2)
	if error != OK:
		_peer = null
		notice.emit("Could not start a connection to that host.")
		return error
	_player_name = player_name.strip_edges()
	multiplayer.multiplayer_peer = _peer
	_join_started = _now()
	notice.emit("Connecting to %s:%d…" % [address.strip_edges(), port])
	return OK

func leave_session() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_hosting = false
	_connected = false
	_ledger = SessionState.new()
	_pending.clear()
	_rate_windows.clear()
	_join_started = 0.0
	_presence_sent_at = -1.0
	_dirty = false
	_reset_snapshot()

func is_active() -> bool:
	return _connected

func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func get_local_inventory() -> Dictionary:
	var local_id: int = int(_snapshot.get("local_id", 0))
	var player: Dictionary = _snapshot.get("players", {}).get(local_id, {})
	return {"goods": player.get("goods", {}).duplicate(true), "animals": player.get("animals", []).duplicate(true)}

func publish_presence(pos: Vector3, yaw: float, zone: String) -> void:
	if not is_active() or _now() - _presence_sent_at < 0.08:
		return
	_presence_sent_at = _now()
	if _hosting:
		if _ledger.accept_presence(1, pos, yaw, zone, _now()):
			_dirty = true
	else:
		_submit_presence.rpc_id(1, pos, yaw, zone)

func request_battle(peer_id: int) -> void:
	_send("request_battle", {"target": peer_id})

func respond_battle(accept: bool) -> void:
	_send("respond_battle", {"accept": accept, "id": int(_snapshot.get("battle", {}).get("id", -1))})

func battle_action(action: String) -> void:
	var battle: Dictionary = _snapshot.get("battle", {})
	_send("battle_action", {"action": action, "id": int(battle.get("id", -1)), "round": int(battle.get("round", -1))})

func request_trade(peer_id: int) -> void:
	_send("request_trade", {"target": peer_id})

func respond_trade(accept: bool) -> void:
	_send("respond_trade", {"accept": accept, "id": int(_snapshot.get("trade", {}).get("id", -1))})

func set_trade_offer(goods: Dictionary, animal_id: String = "") -> void:
	_send("trade_offer", {"goods": goods, "animal_id": animal_id, "id": int(_snapshot.get("trade", {}).get("id", -1))})

func confirm_trade() -> void:
	var trade: Dictionary = _snapshot.get("trade", {})
	_send("trade_confirm", {"version": int(trade.get("version", -1)), "id": int(trade.get("id", -1))})

func cancel_interaction() -> void:
	var interaction: Dictionary = _snapshot.get("trade", {})
	if interaction.is_empty():
		interaction = _snapshot.get("battle", {})
	_send("cancel", {"id": int(interaction.get("id", -1))})

func _send(operation: String, payload: Dictionary) -> void:
	if not is_active():
		notice.emit("Host or join a private session first.")
		return
	if _hosting:
		_handle_command(1, operation, payload)
	else:
		_submit_command.rpc_id(1, operation, payload)

@rpc("any_peer", "call_remote", "reliable", 0)
func _register(protocol: int, player_name: String) -> void:
	if not _hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _pending.has(sender):
		return
	if protocol != PROTOCOL or not _valid_name(player_name) or not _ledger.add_player(sender, player_name.strip_edges()):
		_receive_notice.rpc_id(sender, "This session uses a different version or is full.")
		_peer.disconnect_peer(sender)
		_pending.erase(sender)
		return
	_pending.erase(sender)
	_broadcast()
	notice.emit("%s joined the session." % player_name.strip_edges())

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_presence(pos: Vector3, yaw: float, zone: String) -> void:
	if not _hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _ledger.players.has(sender) or zone.length() > 32 or not _rate_allowed(sender, "presence", 25):
		return
	if _ledger.accept_presence(sender, pos, yaw, zone, _now()):
		_dirty = true

@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_command(operation: String, payload: Dictionary) -> void:
	if not _hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _ledger.players.has(sender) or not _rate_allowed(sender, "command", 15):
		return
	_handle_command(sender, operation, payload)

func _handle_command(sender: int, operation: String, payload: Dictionary) -> void:
	if not _valid_command(operation, payload):
		_tell(sender, "Invalid session command rejected.")
		return
	if not operation.begins_with("request_"):
		var current: Dictionary = _ledger.snapshot(sender)
		var interaction: Dictionary = current.trade if operation.begins_with("trade_") or operation == "respond_trade" else current.battle
		if operation == "cancel" and interaction.is_empty():
			interaction = current.trade
		if interaction.is_empty() or int(interaction.id) != int(payload.id):
			_tell(sender, "That interaction ended or changed. Review the current invitation.")
			return
		if operation == "battle_action" and int(interaction.round) != int(payload.round):
			_tell(sender, "That battle round already ended.")
			return
	var message: String = ""
	match operation:
		"request_trade", "request_battle":
			message = _ledger.request("trade" if operation == "request_trade" else "battle", sender, int(payload.target), _now())
		"respond_trade", "respond_battle":
			message = _ledger.respond("trade" if operation == "respond_trade" else "battle", sender, bool(payload.accept), _now())
		"trade_offer":
			message = _ledger.offer(sender, payload.goods, payload.animal_id, _now())
		"trade_confirm":
			var existing: Dictionary = _ledger.snapshot(sender).trade
			var other: int = int(existing.get("b", 0)) if int(existing.get("a", 0)) == sender else int(existing.get("a", 0))
			message = _ledger.confirm(sender, int(payload.version), _now())
			if message.begins_with("Trade complete") and other > 0:
				_tell(other, message)
		"battle_action":
			message = _ledger.choose(sender, payload.action, _now())
		"cancel":
			_ledger.cancel(sender)
			message = "Interaction closed."
	_tell(sender, message)
	_broadcast()

@rpc("authority", "call_remote", "reliable", 0)
func _receive_snapshot(data: Dictionary) -> void:
	if _hosting or multiplayer.get_remote_sender_id() != 1:
		return
	if data.size() != 3 or not data.get("players") is Dictionary or not data.get("trade") is Dictionary or not data.get("battle") is Dictionary:
		return
	if data.players.size() > SessionState.MAX_PLAYERS or var_to_bytes(data).size() > 32768:
		return
	_snapshot = data
	_snapshot["local_id"] = multiplayer.get_unique_id()
	_snapshot["hosting"] = false
	_snapshot["connected"] = true
	_connected = true
	_join_started = 0.0
	session_changed.emit(get_snapshot())

@rpc("authority", "call_remote", "reliable", 0)
func _receive_notice(message: String) -> void:
	if multiplayer.get_remote_sender_id() == 1 and message.length() <= 240:
		notice.emit(message)

func _broadcast() -> void:
	if not _hosting:
		return
	_snapshot = _ledger.snapshot(1)
	_snapshot["local_id"] = 1
	_snapshot["hosting"] = true
	_snapshot["connected"] = true
	session_changed.emit(get_snapshot())
	for peer_id: int in _ledger.players:
		if peer_id != 1:
			_receive_snapshot.rpc_id(peer_id, _ledger.snapshot(peer_id))
	_dirty = false

func _tell(peer_id: int, message: String) -> void:
	if peer_id == 1:
		notice.emit(message)
	elif _ledger.players.has(peer_id):
		_receive_notice.rpc_id(peer_id, message)

func _process(delta: float) -> void:
	if _hosting:
		_snapshot_elapsed += delta
		if _ledger.expire(_now()):
			_dirty = true
		for peer_id: int in _pending.keys():
			if _now() - float(_pending[peer_id]) > 10.0:
				_peer.disconnect_peer(peer_id)
				_pending.erase(peer_id)
		if _dirty and _snapshot_elapsed >= SNAPSHOT_INTERVAL:
			_snapshot_elapsed = 0.0
			_broadcast()
	elif _peer != null and _join_started > 0.0 and _now() - _join_started > 10.0:
		leave_session()
		notice.emit("Connection timed out. Check the host address and UDP port.")

func _on_peer_connected(peer_id: int) -> void:
	if _hosting:
		_pending[peer_id] = _now()

func _on_peer_disconnected(peer_id: int) -> void:
	if not _hosting:
		return
	var player: Dictionary = _ledger.players.get(peer_id, {})
	_ledger.remove_player(peer_id)
	_pending.erase(peer_id)
	_rate_windows.erase(peer_id)
	_broadcast()
	if not player.is_empty():
		notice.emit("%s left. Their pending trade or battle was cancelled." % player.name)

func _on_connected() -> void:
	_register.rpc_id(1, PROTOCOL, _player_name)

func _on_connection_failed() -> void:
	leave_session()
	notice.emit("Connection failed. Check that your friend is hosting at that address.")

func _on_server_disconnected() -> void:
	leave_session()
	notice.emit("The host disconnected. Session progress has ended; your solo save is safe.")

func _reset_snapshot() -> void:
	_snapshot = {"connected": false, "hosting": false, "local_id": 0, "players": {}, "trade": {}, "battle": {}}
	session_changed.emit(get_snapshot())

func _rate_allowed(peer_id: int, category: String, limit: int) -> bool:
	if not _rate_windows.has(peer_id):
		_rate_windows[peer_id] = {}
	var counters: Dictionary = _rate_windows[peer_id]
	var window: Dictionary = counters.get(category, {"start": _now(), "count": 0})
	if _now() - float(window.start) >= 1.0:
		window = {"start": _now(), "count": 0}
	window.count = int(window.count) + 1
	counters[category] = window
	return int(window.count) <= limit

func _valid_command(operation: String, payload: Dictionary) -> bool:
	if operation.length() > 24 or payload.size() > 3 or var_to_bytes(payload).size() > MAX_COMMAND_BYTES:
		return false
	match operation:
		"request_trade", "request_battle":
			return payload.size() == 1 and payload.get("target") is int and int(payload.target) > 0
		"respond_trade", "respond_battle":
			return payload.size() == 2 and payload.get("accept") is bool and payload.get("id") is int
		"trade_offer":
			if payload.size() != 3 or not payload.get("goods") is Dictionary or not payload.get("animal_id") is String or not payload.get("id") is int:
				return false
			if payload.goods.size() > 3 or payload.animal_id.length() > 64:
				return false
			for key: Variant in payload.goods:
				if not key is String or key.length() > 12 or not payload.goods[key] is int:
					return false
			return true
		"trade_confirm":
			return payload.size() == 2 and payload.get("version") is int and int(payload.version) >= 0 and payload.get("id") is int
		"battle_action":
			return payload.size() == 3 and payload.get("action") is String and ["attack", "guard", "burst"].has(payload.action) and payload.get("id") is int and payload.get("round") is int
		"cancel":
			return payload.size() == 1 and payload.get("id") is int
	return false

func _valid_name(value: String) -> bool:
	var trimmed: String = value.strip_edges()
	if value.length() > 32 or trimmed.is_empty() or trimmed.length() > 24:
		return false
	for character: String in trimmed:
		var code: int = character.unicode_at(0)
		if code < 32 or character in ["[", "]", "<", ">", "\\", "/"]:
			return false
	return true

func _valid_address(value: String) -> bool:
	if value.is_empty() or value.length() > 128 or value != value.strip_edges():
		return false
	for character: String in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:":
			return false
	return true

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
