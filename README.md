# WILDBOUND — Homestead & Friends

A playable expansion of the existing Godot 3D game. Explore the bushveld, bond with wildlife, gather materials, build a camp, and travel on your companions. The original party, backpack, sanctuary, evolution and turn-based battle systems remain part of the game.

## Play

Double-click **Play Wildbound.cmd** in the parent `wildbound game` folder. It uses the bundled Godot 4.7.2 engine and opens a 1280×720 window. To edit the game, import this folder's `project.godot` into Godot 4.7.2 and press F5. The main scene is `scenes/bootstrap.tscn`.

## Mobile preview

Double-click **Play Wildbound Mobile Preview.cmd** in the parent folder to try the touch interface with your mouse. Mobile play requires landscape. Resizing to portrait pauses the game and shows a rotate-phone notice; returning to landscape resumes the same session. It uses your normal game save. The preview does not change your saved control preference.

The left pad steers; the right buttons handle interaction, jumping, sprinting, riding and flight. **Camp**, **Friends**, **Pack** and **Menu** remain accessible at the top. Menus, dialogue and battle choices adapt to the available landscape screen. **Menu → Touch Controls → Auto / On / Off** selects the mode in the regular game.

The browser export uses single-threaded Godot compatibility rendering, a compressed engine download and browser-local saves. The browser playtest and its physical-phone limits are documented in [mobile controls and verification](docs/MOBILE_CONTROLS.md).

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| Shift | Sprint; gallop or fly faster when mounted |
| Space | Jump; rise while flying |
| Ctrl | Descend while flying |
| E | Gather nearby materials, talk, rest, or deliberately search tall grass |
| C | Open construction and crafting |
| T / Enter | Rotate / place the selected building |
| Escape | Cancel placement or close the current panel; open system menu |
| R | Ride / dismount a conscious bonded land companion |
| F | Fly / land on a conscious bonded Vulturon |
| Q | Creature backpack |
| M | Friends: host, join, challenge and trade |
| F2 | Toggle perspective / overhead camera |

During solo battles: Z Strike, X Skills, C Guard, V Wildbond, A Creatures, B Run. Inspect learned moves in the Skills panel. Guard/Power support moves, Morning Light healing, Mud Sling slowing, and the authored Opportunist/Pursuit instincts now resolve in actual combat.

## Build your homestead

1. Pick up wood, stone, fiber and crystals with E. The visible sites regrow after 45 seconds of game time.
2. Press C and choose a Ranger Hut. Position its translucent preview on clear, level ground. T rotates it; Enter builds it. Red previews explain why placement is blocked. Escape cancels without spending materials.
3. Add a house, campfire, fences, creature stable or flight perch. Huts, houses, fires and stables let you rest and heal your party with E.
4. A stable unlocks the Riding Saddle. Craft it, bond with a suitable land animal, then press R on safe ground. Gazellor is one option.
5. A flight perch unlocks the Flight Harness. Bond with the Vulturon in Riverine Woodland, craft the harness and press F. Space rises, Ctrl descends and F requests a safe landing.

Buildings have physical walls and open entrances; huts and houses have interiors. Construction checks terrain, obstacles, other buildings, region boundaries and travel lanes before spending anything. Flight stays within the current maps' perimeter walls. Ownership, equipment and conscious companions are checked before travel.

Riding and flight continue across ordinary region borders with the same companion and safe altitude. Loading a save or returning from battle starts on safe ground. Wildlife encounters come from visible animals or deliberately pressing E in tall grass; walking through grass no longer starts random battles. Entering a region or leaving battle gives eight seconds of playable recovery time, and construction, menus and flying avoid ground encounters.

The [gameplay recording review](docs/GAMEPLAY_REVIEW_2026-10-08.md) documents the latest fixes and rendered verification.

## Saving

Gathering, construction, crafting, resting and region changes save automatically; exploration also saves every 30 seconds. The HUD says **SAVED** only after a confirmed disk write. In the system menu you can save, reload or explicitly start a new game.

Windows save: `%APPDATA%\Godot\app_userdata\WILDBOUND v0.4.0 3D\wildbound_v04_save.json`. The application data name remains unchanged for compatibility. Earlier v0.4 saves load with an empty homestead; previous project versions use their own files.

Writes use a temporary file and retain a `.bak` recovery copy. Damaged primary saves fall back to a valid backup; the damaged bytes are preserved separately. If both copies are unreadable, automatic saving pauses so the original progress is retained. Explicit New Game also preserves the previous file before replacing it. Airborne saves use the last safe ground position.

## Multiplayer scope

Four players can join a **direct friend session**, hosted by one player's game. Open M, enter a keeper name and Host. Friends enter the host address and the same UDP port (default 27840), then Join. Use `127.0.0.1` for two copies on one computer, or the host's LAN address on a reachable network.

Same-region keeper avatars, consent-based friendly battles, and goods/animal trading work over actual ENet traffic. Trade offers are staged with **Update My Offer** and transfer together only after both players confirm the same offer. Revised offers clear confirmations; invalid, stale and replayed commands are rejected.

**Session goods and animals are temporary and separate from solo progress.** Every session supplies its own Pangolet, Meerkit and materials. Shared construction, persistent animal transfers, account login and public matchmaking are not implemented. Direct internet play requires a reachable host; this build does not provide a relay or configure routers/firewalls. Loopback has been tested; two physical devices and public internet reachability have not been verified. See [docs/MULTIPLAYER.md](docs/MULTIPLAYER.md).

A release for anyone online needs a hosted authoritative service, identity, matchmaking/relay and persistent transactional inventories. No hosting service has been provisioned and nothing has been published.

## Verification and source

See [tests/README.md](tests/README.md) for reproducible checks and [docs/HOMESTEAD_AND_FRIENDS.md](docs/HOMESTEAD_AND_FRIENDS.md) for implementation boundaries and evidence. Screenshots in `.qa` come from the running Godot renderer. Tests use isolated save files and leave the user's save alone.

The expansion is implemented inside this latest `WILDBOUND_v0.4.0-3D-dev` folder. Older game folders remain as prior versions. A source backup is in `.upgrade-backup/before-homestead-2026-10-08.zip`.
