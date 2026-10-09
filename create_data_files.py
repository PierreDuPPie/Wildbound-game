import os

data_dir = r"c:\Users\pierr\OneDrive\wildbound game\WILDBOUND_v0.3.0-dev\data"

# Ensure directories exist
os.makedirs(os.path.join(data_dir, "moves"), exist_ok=True)
os.makedirs(os.path.join(data_dir, "instincts"), exist_ok=True)
os.makedirs(os.path.join(data_dir, "creatures"), exist_ok=True)

# Generate Strike Move
strike_res = """[gd_resource type="Resource" script_class="MoveData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/move_data.gd" id="1_move"]
[ext_resource type="Resource" path="res://data/aspects/earth.tres" id="2_asp"]

[resource]
script = ExtResource("1_move")
move_id = &"strike"
display_name = "Strike"
aspect = ExtResource("2_asp")
power = 40
accuracy = 100
category = "attack"
effect_id = &"none"
animation_key = &"melee_strike"
"""
with open(os.path.join(data_dir, "moves/strike.tres"), "w") as f:
    f.write(strike_res)


# 12 New Moves
moves = {
    "solar_flare": {"name": "Solar Flare", "type": "solar", "pwr": 75, "acc": 85, "cat": "attack", "eff": "none", "anim": "solar_beam"},
    "heat_wave": {"name": "Heat Wave", "type": "solar", "pwr": 55, "acc": 95, "cat": "attack", "eff": "none", "anim": "solar_beam"},
    "sun_beam": {"name": "Sun Beam", "type": "solar", "pwr": 60, "acc": 90, "cat": "attack", "eff": "none", "anim": "solar_beam"},
    "morning_light": {"name": "Morning Light", "type": "solar", "pwr": 0, "acc": 100, "cat": "status", "eff": "heal_self_40", "anim": "stat_up"},
    "ground_slam": {"name": "Ground Slam", "type": "earth", "pwr": 60, "acc": 90, "cat": "attack", "eff": "none", "anim": "earth_quake"},
    "burrow": {"name": "Burrow", "type": "earth", "pwr": 50, "acc": 100, "cat": "attack", "eff": "priority", "anim": "earth_quake"},
    "mud_sling": {"name": "Mud Sling", "type": "earth", "pwr": 35, "acc": 100, "cat": "attack", "eff": "drop_agility", "anim": "earth_quake"},
    "howl": {"name": "Howl", "type": "earth", "pwr": 0, "acc": 100, "cat": "status", "eff": "buff_power", "anim": "stat_up"},
    "boulder_bash": {"name": "Boulder Bash", "type": "stone", "pwr": 70, "acc": 85, "cat": "attack", "eff": "none", "anim": "stone_bash"},
    "fossil_fang": {"name": "Fossil Fang", "type": "stone", "pwr": 55, "acc": 95, "cat": "attack", "eff": "none", "anim": "stone_bash"},
    "stone_wall": {"name": "Stone Wall", "type": "stone", "pwr": 0, "acc": 100, "cat": "status", "eff": "buff_guard", "anim": "stat_up"},
    "pebble_pellet": {"name": "Pebble Pellet", "type": "stone", "pwr": 30, "acc": 100, "cat": "attack", "eff": "priority", "anim": "stone_bash"},
}

for m_id, m in moves.items():
    res = f"""[gd_resource type="Resource" script_class="MoveData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/move_data.gd" id="1_move"]
[ext_resource type="Resource" path="res://data/aspects/{m['type']}.tres" id="2_asp"]

[resource]
script = ExtResource("1_move")
move_id = &"{m_id}"
display_name = "{m['name']}"
aspect = ExtResource("2_asp")
power = {m['pwr']}
accuracy = {m['acc']}
category = "{m['cat']}"
effect_id = &"{m['eff']}"
animation_key = &"{m['anim']}"
"""
    with open(os.path.join(data_dir, f"moves/{m_id}.tres"), "w") as f:
        f.write(res)

# 6 New Instincts
instincts = {
    "pursuit": {"name": "Pursuit", "desc": "Gains +25% Agility and +15% Critical Strike when opponent is below 50% HP.", "cond": "enemy_hp_under_50", "pwr": 0.0, "grd": 0.0},
    "grit": {"name": "Grit", "desc": "Survives fatal hit with 1 HP once. +35% Guard.", "cond": "none", "pwr": 0.0, "grd": 0.35},
    "flight_instinct": {"name": "Flight Instinct", "desc": "High evasion when below 40% HP.", "cond": "hp_under_40", "pwr": 0.0, "grd": 0.0},
    "opportunist": {"name": "Opportunist", "desc": "Deals +30% damage to debuffed opponents.", "cond": "enemy_debuffed", "pwr": 0.3, "grd": 0.0},
    "pack_pressure": {"name": "Pack Pressure", "desc": "+20% Power per conscious ally.", "cond": "allies_alive", "pwr": 0.2, "grd": 0.0},
    "pride": {"name": "Pride", "desc": "+30% Power and +20% Guard when at 100% HP.", "cond": "vitality_full", "pwr": 0.3, "grd": 0.2},
}

for i_id, inst in instincts.items():
    res = f"""[gd_resource type="Resource" script_class="InstinctData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/instinct_data.gd" id="1_inst"]

[resource]
script = ExtResource("1_inst")
instinct_id = &"{i_id}"
display_name = "{inst['name']}"
description = "{inst['desc']}"
condition_stat = &"{inst['cond']}"
power_modifier_percent = {inst['pwr']}
guard_modifier_percent = {inst['grd']}
grants_fear_immune = false
"""
    with open(os.path.join(data_dir, f"instincts/{i_id}.tres"), "w") as f:
        f.write(res)

# 6 New Creatures
creatures = {
    "cheetan": {"num": 4, "name": "Cheetan", "desc": "A fast predator of the riverbanks.", "animal": "Cheetah", "type": "solar", "inst": "pursuit", "v": 12, "p": 16, "g": 10, "a": 25, "f": 12, "moves": ["strike", "heat_wave", "solar_flare", "sun_beam"]},
    "warthusk": {"num": 5, "name": "Warthusk", "desc": "Stubborn and resilient.", "animal": "Warthog", "type": "earth", "inst": "grit", "v": 25, "p": 18, "g": 20, "a": 8, "f": 10, "moves": ["strike", "ground_slam", "mud_sling", "boulder_bash"]},
    "gazellor": {"num": 6, "name": "Gazellor", "desc": "Elegant and evasive.", "animal": "Gazelle", "type": "solar", "inst": "flight_instinct", "v": 15, "p": 12, "g": 10, "a": 22, "f": 14, "moves": ["strike", "morning_light", "sun_beam", "heat_wave"]},
    "jackalin": {"num": 7, "name": "Jackalin", "desc": "Cunning pack hunter.", "animal": "Jackal", "type": "earth", "inst": "opportunist", "v": 14, "p": 15, "g": 12, "a": 16, "f": 18, "moves": ["strike", "mud_sling", "burrow", "howl"]},
    "hyenox": {"num": 8, "name": "Hyenox", "desc": "Ruthless and relentless.", "animal": "Hyena", "type": "earth", "inst": "pack_pressure", "v": 18, "p": 20, "g": 15, "a": 15, "f": 12, "moves": ["strike", "ground_slam", "burrow", "howl"]},
    "lionet": {"num": 9, "name": "Lionet", "desc": "Proud and powerful.", "animal": "Lion", "type": "solar", "inst": "pride", "v": 22, "p": 24, "g": 18, "a": 18, "f": 15, "moves": ["strike", "solar_flare", "sun_beam", "morning_light"]},
}

for c_id, c in creatures.items():
    deps = [
        f'[ext_resource type="Script" path="res://scripts/data/creature_species.gd" id="1_crea"]',
        f'[ext_resource type="Resource" path="res://data/aspects/{c["type"]}.tres" id="2_asp"]',
        f'[ext_resource type="Resource" path="res://data/instincts/{c["inst"]}.tres" id="3_inst"]',
        f'[ext_resource type="Script" path="res://scripts/data/aspect_data.gd" id="10_aspect_type"]',
        f'[ext_resource type="Script" path="res://scripts/data/move_data.gd" id="11_move_type"]'
    ]
    learnset = []
    for i, m_id in enumerate(c["moves"]):
        dep_id = f"4_m{i}"
        deps.append(f'[ext_resource type="Resource" path="res://data/moves/{m_id}.tres" id="{dep_id}"]')
        learnset.append(f'ExtResource("{dep_id}")')
    
    learnset_str = "Array[ExtResource(\"11_move_type\")]([" + ", ".join(learnset) + "])"
    aspect_str = f'Array[ExtResource("10_aspect_type")]([ExtResource("2_asp")])'
    
    res = f"""[gd_resource type="Resource" script_class="CreatureSpecies" load_steps={len(deps)+1} format=3]

{"\n".join(deps)}

[resource]
script = ExtResource("1_crea")
species_id = &"{c_id}"
atlas_number = {c['num']}
display_name = "{c['name']}"
short_description = "{c['desc']}"
rarity = &"uncommon"
animal_inspiration = "{c['animal']}"
habitat_tags = Array[StringName]([&"river", &"savannah"])
temperament_tags = Array[StringName]([&"wild"])
aspects = {aspect_str}
instinct = ExtResource("3_inst")
base_vitality = {c['v']}
base_power = {c['p']}
base_guard = {c['g']}
base_agility = {c['a']}
base_focus = {c['f']}
base_instinct = 40
growth_curve = &"standard"
base_bond_difficulty = 40
learnset = {learnset_str}
"""
    with open(os.path.join(data_dir, f"creatures/{c_id}.tres"), "w") as f:
        f.write(res)

print("Created 12 moves, 6 instincts, 6 creatures, and strike move!")
