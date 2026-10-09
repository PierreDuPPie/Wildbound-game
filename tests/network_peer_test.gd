extends SceneTree
## Launch twice with -- host PORT / -- client PORT. Uses real ENet traffic.

var manager: Node
var role: String = ""
var port: int = 27849
var start_time: int = 0
var phase: int = 0
var offered: bool = false
var confirmed: bool = false
var accepted_trade: bool = false
var accepted_battle: bool = false
var last_round: int = 0
var completed_battle: bool = false
var replay_trade_id: int = 0
var invalid_sent: bool = false
var finished_at: int = 0
var bootstrap: Node
var hud: CanvasLayer
var _tick_busy: bool = false
var _failed: bool = false
var _snapshot_packets: int = 0
var _solo_save_path: String = ""
var _solo_save_text: String = ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["host", "client"]:
		push_error("Usage: -- host|client PORT")
		quit(2)
		return
	role = args[0]
	port = int(args[1])
	manager = root.get_node("NetworkManager")
	manager.notice.connect(func(message: String): print(role, " NOTICE: ", message))
	manager.session_changed.connect(func(_snapshot: Dictionary): _snapshot_packets += 1)
	# The real game creates the same Friends form used by a player. Save paths
	# are unique fixtures, and never reference either participant's adventure.
	root.get_node("SaveManager").save_path = "res://.qa/network_hud_%s_%d.json" % [role, OS.get_process_id()]
	# A --script SceneTree is parsed before autoload identifiers are registered;
	# load the game scene only now, after the real autoloads have entered root.
	bootstrap = load("res://scenes/bootstrap.tscn").instantiate()
	root.add_child(bootstrap)
	_solo_save_path = root.get_node("SaveManager").save_path
	_solo_save_text = FileAccess.get_file_as_string(_solo_save_path)
	var exploration: Node3D = bootstrap.active_scene.get_node("Exploration")
	hud = exploration.hud
	hud.open_friends()
	if hud.current_modal != "friends" or exploration.player.movement_enabled:
		_fail("Actual Friends panel did not open and lock world movement")
		return
	# Drive known presence coordinates ourselves while the real Friends form
	# remains connected to real manager snapshots and all game UI callbacks.
	exploration.set_process(false)
	hud.name_field.text = "HostTest" if role == "host" else "FriendTest"
	hud.address_field.text = "127.0.0.1"
	hud.port_field.get_line_edit().clear()
	hud.port_field.get_line_edit().insert_text_at_caret(str(port))
	hud.port_field.apply()
	if int(hud.port_field.value) != port:
		_fail("Typed connection port was not applied")
		return
	if not _press("HOST" if role == "host" else "JOIN"):
		return
	print("[PASS] ", role, " starts a real private session through Friends HUD controls")
	start_time = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < 30000:
		await process_frame
		if _failed:
			return
		var state: Dictionary = manager.get_snapshot()
		if not state.connected:
			continue
		manager.publish_presence(Vector3(5, 0, 5) if role == "host" else Vector3(7, 1, 5), 0.4, "route_01_3d")
		if _tick_busy:
			continue
		if role == "host":
			_host_tick(state)
		else:
			_client_tick(state)
	_fail("Timed out at phase " + str(phase))

func _host_tick(state: Dictionary) -> void:
	var friend_id: int = 0
	for peer_id: int in state.players:
		if peer_id != 1:
			friend_id = peer_id
	if phase == 0 and friend_id > 0:
		var friend: Dictionary = state.players[friend_id]
		if (friend.position as Vector3).distance_to(Vector3(7, 1, 5)) < 0.01 and absf(float(friend.yaw) - 0.4) < 0.01:
			print("[PASS] Host receives actual ENet remote avatar position and yaw")
			phase = 1
			_press("TRADE")
	elif phase == 1 and not state.trade.is_empty() and state.trade.status == "active":
		if not offered:
			replay_trade_id = int(state.trade.id)
			_tick_busy = true
			if not await _edit_and_submit_offer("wood", 5):
				return
			offered = true
			_tick_busy = false
		elif int(state.trade.version) == 2 and not confirmed:
			confirmed = true
			_press("CONFIRM THIS EXCHANGE")
	elif phase == 1 and offered and state.trade.is_empty():
		if state.players[1].goods.wood != 19 or state.players[1].goods.stone != 19:
			_fail("Atomic goods exchange mismatch on host")
			return
		if state.players[1].animals[1].id != "session_%d_pangolet" % friend_id:
			_fail("Animal identity did not reach host")
			return
		print("[PASS] Real two-peer confirmed goods and animal exchange reaches host ledger")
		phase = 2
		_press("CHALLENGE")
	elif phase == 2 and not state.battle.is_empty() and state.battle.status == "active":
		var round_number: int = int(state.battle.round)
		if round_number != last_round:
			last_round = round_number
			_press("BURST" if round_number == 1 else "ATTACK")
	elif phase == 2 and not state.battle.is_empty() and state.battle.status == "finished":
		if int(state.battle.winner) != 1 or state.players[1].wins != 1:
			_fail("Battle did not resolve expected host-authoritative winner")
			return
		print("[PASS] Real two-peer battle consent, simultaneous actions and winner resolution")
		finished_at = Time.get_ticks_msec()
		phase = 3
	elif phase == 3 and Time.get_ticks_msec() - finished_at > 800:
		phase = 4
		_press("RETURN TO LOBBY")
		_press("TRADE")
	elif phase == 4 and friend_id == 0:
		if not state.trade.is_empty() or not state.battle.is_empty() or state.players.size() != 1:
			_fail("Disconnect left stale participants or interactions")
			return
		print("[PASS] Actual peer disconnect removes avatar and pending trade")
		_press("LEAVE")
		if not _assert_solo_unchanged():
			return
		print("NETWORK ENET HOST: PASS")
		quit(0)

func _client_tick(state: Dictionary) -> void:
	var own_id: int = int(state.local_id)
	if not state.players.has(own_id) or not state.players.has(1):
		return
	if phase == 0 and (state.players[1].position as Vector3).distance_to(Vector3(5, 0, 5)) < 0.01:
		print("[PASS] Client receives host session and avatar presence")
		phase = 1
	if phase == 1 and not state.trade.is_empty():
		if state.trade.status == "invited" and not accepted_trade:
			accepted_trade = true
			_press("ACCEPT")
		elif state.trade.status == "active":
			# Wait for the host's offer so the editing stability check spans only
			# presence updates, rather than a legitimate changed trade version.
			if not offered and int(state.trade.version) == 1:
				replay_trade_id = int(state.trade.id)
				# An actual hostile RPC cannot mint or offer goods it does not own.
				manager._submit_command.rpc_id(1, "trade_offer", {"id": replay_trade_id,
					"goods": {"wood": 999}, "animal_id": "res://scripts/core/bootstrap.gd"})
				invalid_sent = true
				_tick_busy = true
				if not await _edit_and_submit_offer("stone", 3):
					return
				offered = true
				_tick_busy = false
			elif int(state.trade.version) == 2 and not confirmed:
				confirmed = true
				_press("CONFIRM THIS EXCHANGE")
	elif phase == 1 and offered and state.trade.is_empty():
		if state.players[own_id].goods.wood != 29 or state.players[own_id].goods.stone != 13:
			_fail("Client goods mismatch or hostile offer mutated ledger")
			return
		if state.players[own_id].animals[1].id != "session_1_pangolet":
			_fail("Animal identity did not reach friend")
			return
		print("[PASS] Client sees committed goods/animals; invalid remote offer caused no mutation")
		manager._submit_command.rpc_id(1, "trade_confirm", {"id": replay_trade_id, "version": 2})
		phase = 2
	if phase == 2 and not state.battle.is_empty():
		if state.battle.status == "invited" and not accepted_battle:
			accepted_battle = true
			_press("ACCEPT")
		elif state.battle.status == "active":
			var round_number: int = int(state.battle.round)
			if round_number != last_round:
				last_round = round_number
				_press("GUARD" if round_number <= 2 else "ATTACK")
		elif state.battle.status == "finished":
			completed_battle = true
	if phase == 2 and completed_battle and state.battle.is_empty() and not state.trade.is_empty():
		if state.players[own_id].goods.wood != 29 or state.players[own_id].goods.stone != 13:
			_fail("Battle or replay changed session balances")
			return
		print("[PASS] Client sees battle result and replayed old trade cannot duplicate goods")
		_press("LEAVE")
		if not _assert_solo_unchanged():
			return
		print("NETWORK ENET CLIENT: PASS")
		quit(0)

func _fail(message: String) -> void:
	_failed = true
	push_error(role + " NETWORK ENET FAILED: " + message)
	quit(1)

func _press(label: String) -> bool:
	var button: Button = _find_button(hud.modal_content, label)
	if button == null or button.disabled or not button.is_inside_tree():
		_fail("Friends HUD control is absent or disabled: " + label)
		return false
	button.pressed.emit()
	return true

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label:
		return node
	for child: Node in node.get_children():
		var match_button: Button = _find_button(child, label)
		if match_button != null:
			return match_button
	return null

func _quantity_fields(node: Node, fields: Array[SpinBox]) -> void:
	if node is SpinBox:
		fields.append(node)
	for child: Node in node.get_children():
		_quantity_fields(child, fields)

func _animal_options(node: Node) -> OptionButton:
	if node is OptionButton:
		return node
	for child: Node in node.get_children():
		var options: OptionButton = _animal_options(child)
		if options != null:
			return options
	return null

func _edit_and_submit_offer(resource_id: String, amount: int) -> bool:
	var fields: Array[SpinBox] = []
	_quantity_fields(hud.lobby_content, fields)
	if fields.size() != 3:
		_fail("Actual trade form is missing its three quantity controls")
		return false
	var spin: SpinBox = fields[0 if resource_id == "wood" else 1]
	var line: LineEdit = spin.get_line_edit()
	var current_version: int = int(manager.get_snapshot().trade.version)
	var form_id: int = spin.get_instance_id()
	var packets_before: int = _snapshot_packets
	line.grab_focus()
	await process_frame
	line.clear()
	line.insert_text_at_caret("1")
	await create_timer(0.25).timeout
	if not is_instance_valid(spin) or spin.get_instance_id() != form_id or line.text != "1":
		_fail("First typed digit was lost during actual ENet presence updates")
		return false
	line.insert_text_at_caret("2")
	await create_timer(0.25).timeout
	if not is_instance_valid(spin) or not spin.is_inside_tree() or line.text != "12" or int(manager.get_snapshot().trade.version) != current_version or _snapshot_packets - packets_before < 2:
		_fail("Presence-only snapshots rebuilt the form or prematurely submitted typed quantity")
		return false
	print("[PASS] ", role, " types multiple digits across live presence packets without a form rebuild or offer mutation")
	line.clear()
	line.insert_text_at_caret(str(amount))
	var animals: OptionButton = _animal_options(hud.lobby_content)
	if animals == null or animals.item_count < 2:
		_fail("Actual trade form has no offered-animal selector")
		return false
	animals.select(1)
	if not _press("UPDATE MY OFFER"):
		return false
	var submit_started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - submit_started < 2000:
		var snapshot: Dictionary = manager.get_snapshot()
		var own_id: int = int(snapshot.local_id)
		var own_offer: Dictionary = snapshot.trade.get("offers", {}).get(own_id, {})
		if int(own_offer.get("goods", {}).get(resource_id, -1)) == amount and not str(own_offer.get("animal_id", "")).is_empty():
			print("[PASS] ", role, " Update My Offer callback applies uncommitted SpinBox text and selected animal")
			return true
		await process_frame
	_fail("Update My Offer did not deliver typed quantity and animal to the real ledger")
	return false

func _assert_solo_unchanged() -> bool:
	if _solo_save_text.is_empty() or FileAccess.get_file_as_string(_solo_save_path) != _solo_save_text:
		_fail("Friends session changed the actual saved solo adventure")
		return false
	print("[PASS] ", role, " actual solo save stays unchanged after real HUD trade, battle and leave")
	return true
