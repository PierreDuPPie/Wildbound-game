# Private friend sessions

WILDBOUND now has a four-player ENet prototype for sharing keeper presence, friendly animal battles and confirmed goods/animal trades. It is a private session hosted by one player's game. The host must remain connected.

Open the in-game Friends panel, enter a keeper name and choose **Host**. A friend runs the same project version, enters the host's LAN IP and chooses **Join**. The default port is **UDP 27840**. Two copies on the same computer can use `127.0.0.1` and different keeper names. On a LAN, share the hosting computer's LAN address. Direct internet connections require a reachable host address and appropriate router/firewall configuration; the game does not configure your router, change firewall rules or provide NAT traversal. A private network/VPN with reachable addresses is another option. LAN reachability and internet hosting have not been certified by the local automated test.

Players see each other's keeper avatars when in the same region. Each computer runs its own single-player world, wildlife and buildings. Shared construction, shared capture encounters and a shared persistent world are not part of this version.

## Session inventory

The host grants every participant a separate session inventory: 24 wood, 16 stone, 12 fiber, a Pangolet and a Meerkit. These animals have unique session identities. The panel exposes these session inventories for trades and battles. These supplies and animals are a temporary sandbox: leaving/rejoining starts a fresh session inventory and there is no account identity or progression economy. They never import from or export into the solo backpack, party, construction inventory or save file. Nothing in a private session is a real-money item.

This separation deliberately avoids trusting a friend's editable local save or creating duplicate permanent animals. Persistent animal trading needs authenticated accounts, a canonical server inventory and durable transactions before it can be released.

## Trading

1. Meet in the same region within 30 world units, choose another keeper and invite them to trade.
2. The invited keeper accepts or declines. No inventory moves when an invitation is sent.
3. Each keeper enters wood, stone and/or fiber quantities they own, optionally selects one session animal, then chooses **Update My Offer**. Typing stays local until that button is used. Offering the last animal is rejected.
4. Both keepers review and confirm. Changing either offer clears both confirmations.
5. The host rechecks both inventories and commits the entire exchange together. Old confirmation packets cannot repeat a completed trade or confirm a different trade.

An invitation expires after 30 seconds. An active trade expires after 120 seconds without an accepted offer/confirmation. Cancellation, a region change, or either keeper disconnecting cancels an open trade without exchanging anything.

## Friendly battles

The other keeper must accept a battle invitation. Each side starts at 100 vitality using their first session animal. This first version uses equal combat stats and three moves:

| Move | Result |
| --- | --- |
| Attack | Deals 22 damage. |
| Guard | Deals no damage and reduces incoming damage to one third. |
| Burst | Deals 34 damage; available once per battle. |

Both sides lock a move before the host resolves the round simultaneously. Snapshots reveal only that the opponent locked a move, so clients cannot inspect the move early through the normal protocol. Moves carry the battle identity and round number to reject packets from an old battle or turn. Battles finish when vitality reaches zero, or after 20 rounds. A simultaneous knockout or equal vitality at the round limit is a draw. No solo animals are injured and no goods are wagered. Wins last for this session only. A disconnected keeper cancels their battle.

## Authority and scope

`NetworkManager` sends intent to the host. `session_state.gd` owns participant inventories, animal ownership, offer revisions, both confirmations, combat damage and outcomes. Clients cannot supply an inventory, animal resource, arbitrary resource path, winner or damage amount. RPC object decoding is disabled. Names, addresses, command types, dictionary sizes, serialized command size, ownership, quantities, capacity and rates are checked. Presence is bounded for finite coordinates, whitelisted regions and plausible speed; it is a cosmetic proxy, not server-simulated collision or anti-cheat movement.

ENet is used through Godot's [high-level multiplayer API](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html). This private prototype has no login, encrypted identity verification, moderation, public lobby directory, relay service, persistent database, host migration or protection against a dishonest host. It should not be presented as a secure public economy or public matchmaking service. Public online play requires a dedicated authoritative backend, authenticated accounts, matchmaking/relay, moderation and abuse controls, operational monitoring, and transactional persistent inventories.

## Verification

From the project directory in PowerShell:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.tools\godot\editor_data'
& '.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/network_state_test.gd
& tests\network_integration.ps1
```

The state test covers ownership/quantity validation, last-animal protection, offer changes and stale confirmation rejection, atomic transfers, hidden battle choices, burst limits, invitation expiry and disconnect cleanup.

The integration test launches **two real Godot processes using ENet over loopback**, without a mocked transport. Both instantiate the actual Bootstrap and Friends panel with isolated solo saves. It drives actual Host/Join buttons, invitations and consent, typed quantities, animal selection, Update My Offer, confirmations, battle actions/results, returning and leaving. Typed digits and form identity survive multiple live presence snapshots, and exact committed balances prove the quantity editor is applied. It also checks host/client position and yaw replication, an actual hostile over-offer RPC rejection, replayed confirmation rejection, disconnect cleanup and byte-identical solo saves. Output is written to `tests/network_host_output.log` and `tests/network_client_output.log` with explicit PASS markers. The harness exits unsuccessfully if either process fails or times out.

Verified locally on Godot 4.7.2: 48 state checks pass and the real two-process loopback/Friends test passes. GUI verification in that integration uses real controls/callbacks in headless Godot; it does not claim native mouse testing on two devices. The sandboxed local engine emits a root certificate store warning even though the ENet test succeeds; ENet loopback does not use TLS. This result does not certify public internet access, Android multiplayer permissions or two physical devices.
