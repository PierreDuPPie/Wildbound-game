# WILDBOUND 0.1 — Subsystem Architecture

Historical architecture for the earlier 2D milestone. For the current 3D expansion, managers, networking and persistence, use [HOMESTEAD_AND_FRIENDS.md](HOMESTEAD_AND_FRIENDS.md) and the project README.

## 1. Overview
WILDBOUND 0.1 is architected on a strict data-driven model that separates immutable definitions (Resources) from live mutable states (RefCounted instances and Node controllers).

---

## 2. Core Singletons & Managers (`scripts/core/`)
* **`SaveManager`** (`res://scripts/core/save_manager.gd`):
  * Handles single-slot deterministic JSON disk serialization to `user://wildbound_01_save.json`.
  * Persists player position, party roster, HP, levels, XP, and demo completion state.
* **`PartyManager`** (`res://scripts/core/party_manager.gd`):
  * Manages the player's active party (up to 6 creatures).
  * Provides active battle lead selection, conscious creature tracking, party healing, and save/load mapping.
* **`Bootstrap`** (`res://scripts/core/bootstrap.gd`):
  * Central game controller managing scene transitions between Route 01, Battle Arena, and Demo Ending.

---

## 3. Data Contracts (`scripts/data/`)
* **`CreatureSpecies`**: Static resource definition (`display_name`, `atlas_number`, `aspects`, `instinct`, `learnset`, base stats).
* **`CreatureInstance`**: Live mutable creature instance (`instance_id`, `current_vitality`, `level`, `learned_moves`, `is_guarding`).
* **`MoveData`**: Combat actions (`power`, `accuracy`, `category`, `priority`, `aspect_id`).
* **`AspectData`**: Natural affinities (`earth`, `solar`, `stone`) and type match-up relationships.
* **`InstinctData`**: Survival traits (`defiance`, `sentry`, `armor`) with trigger thresholds and modifiers.
* **`EncounterTable`**: Weighted random encounter tables for routes.

---

## 4. Combat & Presentation Subsystems (`scripts/battle/` & `scripts/ui/`)
* **`BattleManager`**:
  * Owns the combat state machine (`INTRO`, `PLAYER_TURN`, `RESOLVING`, `ENEMY_TURN`, `VICTORY`, `DEFEAT`, `BONDED`, `ESCAPED`, `ENDED`).
  * Resolves damage calculations, aspect multipliers, instinct activations, voluntary/forced switching, and Wildbond capture probability.
* **`BattleArena`**:
  * Responsive 3×2 Grid UI for commands, skills, and party switching.
  * Real-time HP synchronization without redundant damage shakes on initial load.
* **`BattleEffects`**:
  * Visual impact lunges, hit flashes, screen shakes (configurable toggle), and instinct spectacles.
* **`CreaturePortrait`**:
  * Procedural vector rendering for Ratelit, Meerkit, and Pangolet with dynamic defiance auras.
* **`BackpackUI`**:
  * Overworld dossier overlay for inspecting party statistics, learned skills, active battle lead reassignment, and Wildkeeper field gear.
