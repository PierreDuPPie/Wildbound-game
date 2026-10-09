extends RefCounted
## The host's session ledger. This never reads or writes the solo economy.
## All commands carry intent; inventory, ownership, confirmations and damage
## are derived from this ledger rather than supplied by clients.

const GOODS: Array[String] = ["wood", "stone", "fiber"]
const ZONES: Array[String] = ["route_01_3d", "route_02_3d", "sanctuary_town"]
const MAX_PLAYERS: int = 4
const MAX_GOODS: int = 999
const MAX_ANIMALS: int = 12
const INTERACTION_RANGE: float = 30.0

var players: Dictionary = {}
var trades: Dictionary = {}
var battles: Dictionary = {}
var _sequence: int = 0
var _presence_times: Dictionary = {}
var _zone_times: Dictionary = {}

func add_player(peer_id: int, player_name: String) -> bool:
	if peer_id < 1 or players.has(peer_id) or players.size() >= MAX_PLAYERS:
		return false
	players[peer_id] = {
		"id": peer_id, "name": player_name, "position": Vector3(5, 0, 5),
		"yaw": 0.0, "zone": "route_01_3d", "wins": 0,
		"goods": {"wood": 24, "stone": 16, "fiber": 12},
		"animals": [
			{"id": "session_%d_pangolet" % peer_id, "species": "pangolet", "name": "Pangolet"},
			{"id": "session_%d_meerkit" % peer_id, "species": "meerkit", "name": "Meerkit"}
		]
	}
	return true

func remove_player(peer_id: int) -> void:
	cancel(peer_id)
	players.erase(peer_id)
	_presence_times.erase(peer_id)
	_zone_times.erase(peer_id)

func accept_presence(peer_id: int, pos: Vector3, yaw: float, zone: String, now: float) -> bool:
	if not players.has(peer_id) or not ZONES.has(zone):
		return false
	if not pos.is_finite() or not is_finite(yaw) or absf(yaw) > 100.0:
		return false
	if absf(pos.x) > 100.0 or absf(pos.z) > 100.0 or pos.y < -5.0 or pos.y > 60.0:
		return false
	var player: Dictionary = players[peer_id]
	if _presence_times.has(peer_id):
		if player.zone == zone:
			var elapsed: float = clampf(now - float(_presence_times[peer_id]), 0.0, 2.0)
			# A visual presence bound, not a claim of server collision simulation.
			if pos.distance_to(player.position) > 45.0 * elapsed + 2.0:
				return false
		elif now - float(_zone_times.get(peer_id, -10.0)) < 1.5:
			return false
	if player.zone != zone:
		cancel(peer_id)
		_zone_times[peer_id] = now
	_presence_times[peer_id] = now
	player.position = pos
	player.yaw = wrapf(yaw, -PI, PI)
	player.zone = zone
	return true

func snapshot(peer_id: int) -> Dictionary:
	var visible_battle: Dictionary = _interaction_for(battles, peer_id).duplicate(true)
	if not visible_battle.is_empty():
		# Selections stay secret until both players lock their moves.
		for fighter: int in visible_battle.choices:
			visible_battle.choices[fighter] = "locked"
	return {
		"players": players.duplicate(true),
		"trade": _interaction_for(trades, peer_id).duplicate(true),
		"battle": visible_battle
	}

func request(kind: String, sender: int, target: int, now: float) -> String:
	if not ["trade", "battle"].has(kind) or sender == target or not players.has(sender) or not players.has(target):
		return "Choose another connected keeper."
	if busy(sender) or busy(target):
		return "One of you already has a pending trade or battle."
	if players[sender].zone != players[target].zone:
		return "Meet in the same region before trading or battling."
	if (players[sender].position as Vector3).distance_to(players[target].position) > INTERACTION_RANGE:
		return "Move closer to your friend first."
	_sequence += 1
	var interaction: Dictionary = {"id": _sequence, "a": sender, "b": target,
		"requested_by": sender, "status": "invited", "expires": now + 30.0}
	if kind == "trade":
		interaction["offers"] = {sender: {"goods": {}, "animal_id": ""}, target: {"goods": {}, "animal_id": ""}}
		interaction["confirmed"] = []
		interaction["version"] = 0
		trades[_sequence] = interaction
	else:
		interaction["hp"] = {sender: 100, target: 100}
		interaction["animals"] = {sender: players[sender].animals[0].duplicate(true), target: players[target].animals[0].duplicate(true)}
		interaction["round"] = 1
		interaction["choices"] = {}
		interaction["burst_used"] = []
		interaction["log"] = ["A friendly battle. Animals return healthy; no goods are wagered."]
		interaction["winner"] = 0
		battles[_sequence] = interaction
	return "Invitation sent."

func respond(kind: String, peer_id: int, accept: bool, now: float) -> String:
	var collection: Dictionary = trades if kind == "trade" else battles
	var interaction: Dictionary = _interaction_for(collection, peer_id)
	if interaction.is_empty() or interaction.status != "invited" or interaction.requested_by == peer_id:
		return "There is no incoming invitation."
	if not accept:
		collection.erase(interaction.id)
		return "Invitation declined."
	if float(interaction.expires) <= now:
		collection.erase(interaction.id)
		return "That invitation expired."
	interaction.status = "active"
	interaction.expires = now + 120.0
	return "Trade opened." if kind == "trade" else "Friendly battle started."

func offer(peer_id: int, goods: Dictionary, animal_id: String, now: float) -> String:
	var trade: Dictionary = _interaction_for(trades, peer_id)
	if trade.is_empty() or trade.status != "active":
		return "Accept a trade invitation first."
	if float(trade.expires) <= now:
		trades.erase(trade.id)
		return "Trade expired."
	if not _valid_offer(peer_id, goods, animal_id):
		return "Invalid offer: use goods you own and keep at least one animal."
	trade.offers[peer_id] = {"goods": goods.duplicate(true), "animal_id": animal_id}
	trade.confirmed.clear()
	trade.version = int(trade.version) + 1
	trade.expires = now + 120.0
	return "Offer updated. Both keepers must confirm the new offer."

func confirm(peer_id: int, expected_version: int, now: float) -> String:
	var trade: Dictionary = _interaction_for(trades, peer_id)
	if trade.is_empty() or trade.status != "active":
		return "No active trade."
	if int(trade.version) != expected_version:
		return "The offer changed. Review it before confirming again."
	if float(trade.expires) <= now:
		trades.erase(trade.id)
		return "Trade expired."
	if not trade.confirmed.has(peer_id):
		trade.confirmed.append(peer_id)
	trade.expires = now + 120.0
	if trade.confirmed.size() < 2:
		return "Confirmed. Waiting for the other keeper."
	var a: int = int(trade.a)
	var b: int = int(trade.b)
	var a_offer: Dictionary = trade.offers[a]
	var b_offer: Dictionary = trade.offers[b]
	if not _valid_offer(a, a_offer.goods, a_offer.animal_id) or not _valid_offer(b, b_offer.goods, b_offer.animal_id):
		trade.confirmed.clear()
		return "Inventory changed; the trade was not completed."
	# Validate both resulting balances/capacities before changing either ledger.
	for item: String in GOODS:
		var a_after: int = int(players[a].goods[item]) - int(a_offer.goods.get(item, 0)) + int(b_offer.goods.get(item, 0))
		var b_after: int = int(players[b].goods[item]) - int(b_offer.goods.get(item, 0)) + int(a_offer.goods.get(item, 0))
		if a_after < 0 or a_after > MAX_GOODS or b_after < 0 or b_after > MAX_GOODS:
			trade.confirmed.clear()
			return "Trade exceeds an inventory limit."
	if not _capacity_valid(a, a_offer.animal_id, b_offer.animal_id) or not _capacity_valid(b, b_offer.animal_id, a_offer.animal_id):
		trade.confirmed.clear()
		return "A keeper cannot receive more than twelve session animals."
	for item: String in GOODS:
		var difference: int = int(b_offer.goods.get(item, 0)) - int(a_offer.goods.get(item, 0))
		players[a].goods[item] += difference
		players[b].goods[item] -= difference
	var animal_a: Dictionary = _take_animal(a, a_offer.animal_id)
	var animal_b: Dictionary = _take_animal(b, b_offer.animal_id)
	if not animal_a.is_empty():
		players[b].animals.append(animal_a)
	if not animal_b.is_empty():
		players[a].animals.append(animal_b)
	trades.erase(trade.id)
	return "Trade complete. Session goods and animals exchanged."

func choose(peer_id: int, action: String, now: float) -> String:
	var battle: Dictionary = _interaction_for(battles, peer_id)
	if battle.is_empty() or battle.status != "active":
		return "No active battle."
	if float(battle.expires) <= now:
		battles.erase(battle.id)
		return "Battle expired."
	if not ["attack", "guard", "burst"].has(action):
		return "Choose Attack, Guard or Burst."
	if battle.choices.has(peer_id):
		return "Your move is locked. Waiting for the other keeper."
	if action == "burst" and battle.burst_used.has(peer_id):
		return "Burst can be used only once per battle."
	battle.choices[peer_id] = action
	battle.expires = now + 120.0
	if battle.choices.size() < 2:
		return "Move locked. Waiting for the other keeper."
	var a: int = int(battle.a)
	var b: int = int(battle.b)
	var damage_a: int = _damage(battle.choices[b], battle.choices[a])
	var damage_b: int = _damage(battle.choices[a], battle.choices[b])
	battle.hp[a] = maxi(0, int(battle.hp[a]) - damage_a)
	battle.hp[b] = maxi(0, int(battle.hp[b]) - damage_b)
	for fighter: int in [a, b]:
		if battle.choices[fighter] == "burst":
			battle.burst_used.append(fighter)
	battle.log.append("Round %d: %s used %s (%d damage); %s used %s (%d damage)." % [battle.round,
		players[a].name, battle.choices[a], damage_b, players[b].name, battle.choices[b], damage_a])
	if battle.log.size() > 12:
		battle.log.pop_front()
	battle.choices.clear()
	if int(battle.hp[a]) == 0 or int(battle.hp[b]) == 0 or int(battle.round) >= 20:
		battle.status = "finished"
		if int(battle.hp[a]) != int(battle.hp[b]):
			battle.winner = a if int(battle.hp[a]) > int(battle.hp[b]) else b
			players[battle.winner].wins += 1
			battle.log.append("%s wins the friendly battle." % players[battle.winner].name)
		else:
			battle.log.append("A draw. Well played, keepers!")
		battle.expires = now + 30.0
		return "Friendly battle complete."
	battle.round = int(battle.round) + 1
	return "Round resolved. Choose your next move."

func cancel(peer_id: int) -> bool:
	var removed: bool = false
	for collection: Dictionary in [trades, battles]:
		var interaction: Dictionary = _interaction_for(collection, peer_id)
		if not interaction.is_empty():
			collection.erase(interaction.id)
			removed = true
	return removed

func expire(now: float) -> bool:
	var removed: bool = false
	for collection: Dictionary in [trades, battles]:
		for key: int in collection.keys():
			if float(collection[key].expires) <= now:
				collection.erase(key)
				removed = true
	return removed

func busy(peer_id: int) -> bool:
	return not _interaction_for(trades, peer_id).is_empty() or not _interaction_for(battles, peer_id).is_empty()

func _interaction_for(collection: Dictionary, peer_id: int) -> Dictionary:
	for entry: Dictionary in collection.values():
		if int(entry.a) == peer_id or int(entry.b) == peer_id:
			return entry
	return {}

func _valid_offer(peer_id: int, goods: Dictionary, animal_id: String) -> bool:
	if not players.has(peer_id) or goods.size() > GOODS.size() or animal_id.length() > 64:
		return false
	for item: Variant in goods:
		if not item is String or not GOODS.has(item) or not goods[item] is int:
			return false
		var amount: int = int(goods[item])
		if amount < 0 or amount > MAX_GOODS or amount > int(players[peer_id].goods[item]):
			return false
	if not animal_id.is_empty():
		if players[peer_id].animals.size() <= 1:
			return false
		for animal: Dictionary in players[peer_id].animals:
			if animal.id == animal_id:
				return true
		return false
	return true

func _capacity_valid(peer_id: int, outgoing: String, incoming: String) -> bool:
	return players[peer_id].animals.size() - int(not outgoing.is_empty()) + int(not incoming.is_empty()) <= MAX_ANIMALS

func _take_animal(peer_id: int, animal_id: String) -> Dictionary:
	for index: int in range(players[peer_id].animals.size()):
		if players[peer_id].animals[index].id == animal_id:
			var animal: Dictionary = players[peer_id].animals[index]
			players[peer_id].animals.remove_at(index)
			return animal
	return {}

func _damage(attack: String, defense: String) -> int:
	if attack == "guard":
		return 0
	var amount: int = 34 if attack == "burst" else 22
	return maxi(1, int(amount / 3.0)) if defense == "guard" else amount
