import os
import re

creature_ids = [
    "aardvark", "lionet", "cheetan", "elephunt", "rhinorex", "hippotam", "zebrafly",
    "giraffid", "crocodyl", "ostrichy", "hyenox", "warthusk", "baboonic", "gorilox",
    "chimpaz", "leopaws", "buffalox", "jackalin", "vulturon", "pythonis", "mambara",
    "monitorz", "servalyn", "caraclaw", "gazellor", "springer", "wildebot"
]

pm_path = "c:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.2.0-dev/scripts/core/party_manager.gd"

with open(pm_path, "r") as f:
    content = f.read()

# Add constants
const_lines = []
for cid in creature_ids:
    const_name = cid.upper()
    const_lines.append(f'const {const_name}: CreatureSpecies = preload("res://data/creatures/{cid}.tres")')

const_block = "\n".join(const_lines)

# Find where to inject constants
# Inject right after "const PANGOLET: CreatureSpecies = preload("res://data/creatures/pangolet.tres")"
content = re.sub(
    r'(const PANGOLET: CreatureSpecies = preload\("res://data/creatures/pangolet.tres"\))',
    r'\1\n' + const_block,
    content
)

# Add to lookup
lookup_lines = []
for cid in creature_ids:
    const_name = cid.upper()
    lookup_lines.append(f'\t\t&"{cid}": {const_name},')

lookup_block = "\n".join(lookup_lines)

# Inject right after &"pangolet": PANGOLET,
content = re.sub(
    r'(&"pangolet": PANGOLET,)',
    r'\1\n' + lookup_block,
    content
)

# Optional: Ensure class_name is back if it helps Godot resolve it immediately without a cache clear?
# Actually, the user's issue might be fixed with `.godot` deletion. But adding class_name doesn't hurt.
if "class_name PartyManager" not in content:
    content = "class_name PartyManager\n" + content

with open(pm_path, "w") as f:
    f.write(content)

print("Updated party_manager.gd")
