# WILDBOUND — First Expedition

An original cozy 3D wildlife adventure: explore the bushveld, form Wildbonds, discover companion abilities, and build a sanctuary. Chapter 1 follows Ranger Dan and the unruly honey badger Ratelit through **Something in the Wild**.

## Play and share

**[Play First Expedition](https://wildbound-first-expedition.pierre-dupie2007.chatgpt.site/)**

The browser edition is a single-player alpha. No account is required. Every player has their own browser-local adventure. Phones support portrait and landscape; you can rotate while playing. Actual phone performance still needs device testing.

**[Playtest guide and feedback](https://wildbound-first-expedition.pierre-dupie2007.chatgpt.site/feedback.html)** provides a short route and a downloadable field report. Reports stay local until the player downloads and shares them.

## Your first expedition

1. Speak to Ranger Dan beside the west road at Acacia Outpost.
2. Enter Route 01, approach wildlife or deliberately search tall grass, and form your first Wildbond.
3. Follow the objective to Riverine Woodland. Help the injured Pangolet, inspect tracks, and use a companion ability to investigate the rockfall.
4. Report back, gather materials, and build a Creature Shelter at the outpost.
5. Care for your companions and investigate the resonance stone. Your sanctuary remains playable after Chapter 1.

Field Notes record your discoveries. The Atlas contains the playable Wildbound roster plus reference catalogs; catalog entries do not mean every listed animal can be caught in this alpha.

## Controls

| Input | Action |
| --- | --- |
| WASD / arrows | Move |
| Shift | Sprint or gallop |
| Space / Ctrl | Jump or rise / descend while flying |
| E | Talk, gather, interact, or search tall grass |
| C | Camp, construction, and crafting |
| R / T / mouse wheel during placement | Rotate building |
| Enter / E / left click during placement | Place building |
| Escape / right click during placement | Cancel placement |
| Q / B in exploration | Backpack |
| G | Companion abilities |
| X in exploration | Wild Atlas |
| R with a conscious owned companion and saddle | Ride / dismount |
| F with a conscious owned Vulturon and harness | Fly / request safe landing |
| F2 | Camera view |
| Escape | Close panel / open system menu |

In solo battles: Z Strike, X Skills, C Guard, V Wildbond, A Creatures, B Run. Solar Charm and Grit Stone apply their advertised battle-only bonuses; repeated identical boosts preserve the unused item.

Touch controls use a left steering pad and right action buttons. Menu opens Camp, Pack, abilities, Atlas, and settings. Rotation releases held touches; backgrounding preserves the independent lifecycle pause.

## Saves and multiplayer

Gathering, construction, crafting, resting, progression, and region changes save automatically. Exploration also saves periodically. SAVED appears only after a confirmed write. Menu provides Save, Reload, and a confirmed New Game action.

Browser saves stay in the same browser profile and site origin. Private browsing or clearing site data can remove them. The public site retains its existing origin for returning testers.

Native saves keep the existing `Godot/app_userdata/WILDBOUND v0.4.0 3D` directory and `wildbound_v04_save.json`. Temporary writes and validated backups protect progress. Unreadable originals are preserved; saving pauses if neither copy can be recovered. Creature records are validated before replacing Party and Reserve together. Six active slots, safe overflow to Wild Reserve, existing IDs, and nicknames are retained.

Direct ENet friend sessions are experimental native-only features with separate temporary inventories. Loopback integration is tested; separate-device and public-internet play are not established. The browser explains this limitation instead of offering unsupported host/join controls.

## Development and verification

Open `project.godot` in **Godot 4.7.2**, main scene `scenes/bootstrap.tscn`. The parent folder's Play Wildbound commands use the bundled Windows engine. Older project folders are historical checkpoints.

From this project directory:

```powershell
& tools/audit_game.ps1
& tests/network_integration.ps1
& tools/audit_game.ps1 -Rendered
```

The audit isolates APPDATA and writes logs, results, and source fingerprints under `.qa/audit-2026-10-27`. Run rendered fixtures separately. A source change during a run invalidates its release checkpoint.

The Web preset uses `.tools/web-templates/web_nothreads_release.zip`:

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release Web
node tools/prepare_web_release.mjs
```

Preparation verifies compressed-engine integrity, copies the feedback page, enforces host file limits, and records source/pack hashes in `build-info.json`. The GitHub workflow verifies core behavior and prepares a downloadable web artifact; hosted publication uses the existing Sites project.

See [the audit report](docs/AUDIT_2026-10-29.md) for findings, evidence, and remaining physical-device limits.
