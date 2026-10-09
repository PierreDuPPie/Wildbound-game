import os

creatures = [
    ("aardvark", "Aardvark", "Earth-digging insectivore.", "Earth", "Defiance", 48, 45, 50, 40, 30, 45),
    ("lionet", "Lionet", "A proud feline of the savannah.", "Solar", "Defiance", 60, 55, 45, 45, 30, 50),
    ("cheetan", "Cheetan", "The fastest sprinter in the plains.", "Solar", "Sentry", 40, 45, 30, 70, 30, 40),
    ("elephunt", "Elephunt", "A massive, powerful giant.", "Stone", "Armor", 80, 60, 60, 20, 20, 30),
    ("rhinorex", "Rhinorex", "Armored tank of the bush.", "Stone", "Armor", 70, 65, 75, 25, 20, 35),
    ("hippotam", "Hippotam", "Heavy river dweller with powerful jaws.", "Earth", "Armor", 75, 60, 55, 25, 20, 35),
    ("zebrafly", "Zebrafly", "A striped runner of the plains.", "Solar", "Sentry", 50, 45, 40, 60, 30, 45),
    ("giraffid", "Giraffid", "Tall browser with a sweeping neck.", "Earth", "Sentry", 65, 50, 45, 45, 30, 35),
    ("crocodyl", "Crocodyl", "Lurking reptile with a crushing bite.", "Stone", "Armor", 60, 70, 65, 30, 20, 50),
    ("ostrichy", "Ostrichy", "A giant bird that runs at incredible speeds.", "Solar", "Sentry", 50, 50, 35, 65, 25, 45),
    ("hyenox", "Hyenox", "A laughing scavenger that bites hard.", "Earth", "Defiance", 55, 55, 50, 45, 30, 55),
    ("warthusk", "Warthusk", "A tough, bristly boar.", "Earth", "Defiance", 55, 50, 55, 40, 25, 50),
    ("baboonic", "Baboonic", "A clever, troop-minded primate.", "Earth", "Sentry", 50, 50, 45, 50, 35, 45),
    ("gorilox", "Gorilox", "A mountain-dwelling powerhouse.", "Stone", "Armor", 70, 70, 65, 35, 25, 40),
    ("chimpaz", "Chimpaz", "Agile and highly intelligent.", "Earth", "Defiance", 45, 45, 40, 55, 45, 45),
    ("leopaws", "Leopaws", "A stealthy spotted predator.", "Solar", "Sentry", 50, 60, 40, 60, 35, 50),
    ("buffalox", "Buffalox", "A relentless herd beast.", "Stone", "Armor", 75, 65, 60, 35, 25, 45),
    ("jackalin", "Jackalin", "A small, cunning predator.", "Earth", "Sentry", 45, 40, 35, 55, 30, 40),
    ("vulturon", "Vulturon", "A circling scavenger of the skies.", "Solar", "Sentry", 45, 45, 40, 50, 30, 55),
    ("pythonis", "Pythonis", "A constricting snake of immense size.", "Earth", "Armor", 60, 55, 50, 40, 30, 40),
    ("mambara", "Mambara", "A highly venomous, fast slitherer.", "Solar", "Sentry", 35, 60, 30, 70, 35, 50),
    ("monitorz", "Monitorz", "A tough-scaled lizard.", "Stone", "Armor", 55, 50, 60, 40, 25, 40),
    ("servalyn", "Servalyn", "A leaping cat with huge ears.", "Solar", "Sentry", 40, 50, 35, 65, 30, 45),
    ("caraclaw", "Caraclaw", "A tufted-eared cat of the scrub.", "Solar", "Sentry", 45, 55, 35, 60, 30, 45),
    ("gazellor", "Gazellor", "An elegant, leaping antelope.", "Solar", "Sentry", 45, 35, 30, 65, 30, 40),
    ("springer", "Springer", "A bouncing antelope that pronks.", "Solar", "Sentry", 45, 35, 35, 65, 30, 40),
    ("wildebot", "Wildebot", "A roaming beast of the great migration.", "Earth", "Armor", 60, 50, 50, 45, 25, 40)
]

template = """[gd_resource type="Resource" script_class="CreatureSpecies" load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/data/creature_species.gd" id="1_species"]
[ext_resource type="Resource" path="res://data/aspects/{aspect_lower}.tres" id="2_aspect"]
[ext_resource type="Resource" path="res://data/instincts/{instinct_lower}.tres" id="3_instinct"]
[ext_resource type="Resource" path="res://data/moves/scrap_swipe.tres" id="4_move"]
[ext_resource type="Script" path="res://scripts/data/aspect_data.gd" id="5_aspect_type"]
[ext_resource type="Script" path="res://scripts/data/move_data.gd" id="6_move_type"]

[resource]
script = ExtResource("1_species")
species_id = &"{species_id}"
atlas_number = {atlas}
display_name = "{display_name}"
short_description = "{desc}"
rarity = &"common"
animal_inspiration = "African Animal"
habitat_tags = Array[StringName]([&"savannah"])
temperament_tags = Array[StringName]([&"wild"])
aspects = Array[ExtResource("5_aspect_type")]([ExtResource("2_aspect")])
instinct = ExtResource("3_instinct")
base_vitality = {vit}
base_power = {pow}
base_guard = {grd}
base_agility = {agi}
base_focus = {foc}
base_instinct = {ins}
growth_curve = &"steady"
base_bond_difficulty = 50
learnset = Array[ExtResource("6_move_type")]([ExtResource("4_move")])
"""

out_dir = "c:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.2.0-dev/data/creatures"

atlas_start = 4
for i, c in enumerate(creatures):
    sid = c[0]
    display = c[1]
    desc = c[2]
    aspect = c[3].lower()
    instinct = c[4].lower()
    content = template.format(
        species_id=sid,
        atlas=atlas_start + i,
        display_name=display,
        desc=desc,
        aspect_lower=aspect,
        instinct_lower=instinct,
        vit=c[5],
        pow=c[6],
        grd=c[7],
        agi=c[8],
        foc=c[9],
        ins=c[10]
    )
    with open(f"{out_dir}/{sid}.tres", "w") as f:
        f.write(content)
    print(f"Created {sid}.tres")

print("Done generating 27 creatures!")
