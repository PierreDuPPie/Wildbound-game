# WILDBOUND 0.1 RC1 Smoke Test & Acceptance Checklist

## 🎯 Target Playtest Runs

### Run 1 — Fresh Player Journey
1. Launch game from `bootstrap.tscn` (or press **F5** in Godot).
2. Listen to Ranger briefing at the Route 01 Supply Hut.
3. Walk along the dirt path into a grass patch and encounter a **Meerkit**.
4. Weaken Meerkit with Strike / Skills, then press **[V] Wildbond** to form a bond.
5. Return to the Ranger Supply Hut at the upper-left.
6. Watch the narrative cutscene with the food-stealing Ratelit and Title Card.
7. Click **Continue Exploring**.

### Run 2 — Honey Badger Test (Defiance Verification)
1. Start a New Game.
2. Explore Route 01 until encountering a wild **Ratelit** (15% encounter rate).
3. Whittle Ratelit's HP down below 30% (e.g. under 19/64 HP).
4. Verify the **RATELIT'S DEFIANCE AWAKENS** spectacle: dramatic pause, darkened overlay, golden eyes & aura, screen shake, and banner message.
5. Verify Ratelit deals +25% increased damage on subsequent strikes.
6. Weaken Ratelit further and form a Wildbond.

### Run 3 — Persistence & Party Switch Test
1. Press **[Q]** in the overworld to open your Backpack.
2. Select your newly bonded Ratelit (Slot 2) and click **★ SET AS ACTIVE BATTLE LEAD**.
3. Close Backpack (**Q** / **ESC**) and walk into grass.
4. Verify Ratelit enters combat as your active fighter.
5. In battle, press **[A] CREATURES** and switch to Pangolet.
6. Quit the game completely.
7. Relaunch with **F5** — verify party roster, Lead creature, and coordinates are restored from `user://wildbound_01_save.json`.
8. Walk near the Ranger — verify the demo ending does **NOT** incorrectly re-trigger.
