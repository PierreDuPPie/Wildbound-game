# WILDBOUND v0.2.0 RC1 — Five Acceptance Playtest Runs

Use this checklist to perform the final manual playtest verification in Godot 4.x before freezing `WILDBOUND_v0.2.0`.

---

## 🦡 Run 1: The Ratelit Mascot Run (Defiance Verification)
**Goal**: Verify natural Defiance activation, full audiovisual spectacle, audio playback, and clean return to baseline state.

1. Launch `res://scenes/bootstrap.tscn` (or press **F5**).
2. Explore Route 01 grass until encountering a wild **Ratelit** (15% encounter weight).
3. Whittle Ratelit's HP down below 30% of maximum (e.g. `< 16/52 HP`).
4. **Observe the Spectacle Sequence**:
   - [ ] Screen overlay darkens (`0.7` alpha).
   - [ ] Ratelit sprite scales up sharply (`1.15x`).
   - [ ] Aggressive screen shake triggers.
   - [ ] 24-particle gold burst fires upward.
   - [ ] Banner appears in Gold (`#FFD700`) & Deep Red (`#8B0000`): **"Ratelit's Defiance AWAKENS!"**
   - [ ] Audio plays: Low impact thud -> deep sub-bass pulse -> gravel growl (`defiance.wav`).
   - [ ] 1.5-second cinematic hold before returning to combat.
5. Continue battling.
   - [ ] Verify Ratelit snaps back to baseline scale and position with **zero visual drift**.
   - [ ] Verify Ratelit's attacks now deal +25% boosted power.
   - [ ] Weaken and press `[V]` to successfully Wildbond with Ratelit.

---

## ⚡ Run 2: The Three-Instinct Run (All Presentation Paths)
**Goal**: Verify Defiance, Armor, and Sentry (including mid-battle switch-in) trigger independently with distinct audiovisual identity.

1. **Armor Verification (Pangolet)**:
   - Enter combat with Pangolet as lead.
   - Take damage until HP drops below 50%.
   - Verify: 3-beat visual pulse (*CHK—CHK—CHK* scale click), slate/steel blue palette, guard symbol flash, downward defensive shimmer, and audio playback (`armor.wav`).
2. **Sentry Opening Verification (Meerkit)**:
   - Put Meerkit in battle lead and walk into combat.
   - Verify Turn 1 opening: 5px upward sprite snap (*ears alert*), yellow/white flash, `+2 PRIORITY` indicator, yellow spark burst, and alert chime audio (`sentry.wav`).
3. **Sentry Mid-Battle Switch-in Verification**:
   - Start battle with Ratelit or Pangolet.
   - On Turn 2+, press `[A] CREATURES` and switch to Meerkit.
   - **Verify**: Sentry triggers cleanly on Meerkit's entrance even though it is not global turn 1.

---

## 🛡️ Run 3: Battle Stress & UI Lock Run
**Goal**: Verify input locking prevents race conditions, state desyncs, or corrupted turns during animations.

1. Enter battle.
2. Select **[Z] STRIKE** or a move in **[X] SKILLS**.
3. **Hammer keyboard and mouse buttons repeatedly** during:
   - The attack lunge animation.
   - The white hit flash and screen shake.
   - The enemy's counter-attack turn.
   - Instinct spectacle sequences.
4. **Verify**:
   - [ ] All UI grids (`command_grid`, `skills_grid`, `party_grid`) remain strictly disabled.
   - [ ] No double-actions, phantom strikes, or skipped turns occur.
   - [ ] Once the resolution coroutine finishes, control unlocks smoothly for the next decision.
5. Faint your active creature and verify the forced replacement modal (`1-6` or `B` to flee) locks until a valid selection is made.

---

## 📦 Run 4: Wild Reserve & Persistence Run
**Goal**: Fill party to 6, bond creature #7, verify reserve storage, safe-zone swapping at Acacia Outpost, and disk serialization.

1. Bond wild creatures on Route 01 until your active party reaches maximum capacity (6 creatures).
2. Encounter and Wildbond creature #7:
   - [ ] Verify message confirms creature was sent to **Wild Reserve Storage**.
3. Press `[Q]` to open Backpack -> **Reserve Tab**:
   - [ ] Verify creature #7 is visible in the storage grid with accurate stats and location.
4. Attempt to swap on Route 01:
   - [ ] Verify swap is blocked outside safe zones.
5. Walk East through the gate into **Acacia Outpost (Sanctuary Town)**:
   - [ ] Open Backpack -> Reserve Tab.
   - [ ] Select creature #7 and click **Swap Into Party**.
   - [ ] Choose a party member to swap in the swap modal.
   - [ ] Confirm the party and reserve arrays swap accurately.
6. Open Menu (`[ESC]`) -> **Save Game**.
7. Close Godot and relaunch with **F5** -> select **Load Game** (or automatic auto-load):
   - [ ] Verify party composition, reserve contents, HP, and player position are 100% intact.

---

## 🗺️ Run 5: Presentation & World Flow Run
**Goal**: Verify visual transitions, dialogue, and environment rendering across the full loop.

1. Walk across Route 01:
   - [ ] Inspect acacia tree drop shadows, dirt path edge accents, and Ranger Hut details.
   - [ ] Trigger an encounter: verify clean white flash transition without camera popping.
   - [ ] Flee or finish battle: verify return coordinates and smooth camera tracking.
2. Travel East to **Acacia Outpost**:
   - [ ] Verify cobblestone rendering, building awnings, lantern glow, and fountain ripple animation.
   - [ ] Visit **Care Clinic**: talk to Caretaker Sanna and confirm smooth green flash party heal.
   - [ ] Visit **Rest Cabin**: rest in bed and confirm cozy dark fade auto-save sequence.
   - [ ] Talk to Dr. Moyo and Scout: verify dialogue boxes dismiss cleanly without overlapping area cards.
3. Open Backpack (`[Q]`):
   - [ ] Verify colored stat bars (Vitality/Green, Power/Red, Guard/Blue, Agility/Yellow, Focus/Purple).
   - [ ] Verify production sprites render cleanly in the SubViewport preview.

---

## ✅ Sign-Off Criteria for Freezing v0.2.0
- All 5 runs pass with **zero crashes, zero visual drift, zero input locks, and zero audio errors**.
- Once verified, tag/freeze `WILDBOUND_v0.2.0` and branch into `WILDBOUND_v0.3.0-dev` (The Progression Pass).
