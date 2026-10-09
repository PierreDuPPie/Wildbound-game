# WILDBOUND 0.1 — Execution Status

Historical checklist for the earlier 2D milestone. Current implemented behavior, verified results and outstanding online-service boundaries are recorded in [HOMESTEAD_AND_FRIENDS.md](HOMESTEAD_AND_FRIENDS.md).

## Step 2 — Ratelit Face
- [x] `defiance_activated` signal in BattleManager
- [x] `battle_effects.gd` shake/flash/Defiance spectacle
- [x] Rebuilt battle UI: HP bars, creature panels, 3x2 command grid
- [x] Code-drawn original portraits for Ratelit, Meerkit, Pangolet

## Step 3 — Route 01
- [x] `route_01.tscn` with `TileMapLayer`
- [x] `Camera2D` on player
- [x] bootstrap loads Route 01
- [x] three grass encounter zones
- [x] runtime-generated ground tile, route dressing, obstacles

## Step 4 — Wildbond + Save
- [x] `party_manager.gd`
- [x] `save_manager.gd`
- [x] `CreatureInstance.from_save_dict()`
- [x] Wildbond probability/resolution in BattleManager
- [x] bootstrap save/load wiring
- [x] captured creatures persist in party

## Step 5 — Creatures + Ending
- [x] Solar and Stone Aspects
- [x] Sentry and Armor Instincts
- [x] Meerkit/Pangolet moves
- [x] Meerkit/Pangolet species
- [x] weighted encounter table: 50/35/15
- [x] demo ending scene
- [x] end-to-end bootstrap wiring
