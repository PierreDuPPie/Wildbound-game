import os
import re

base = "c:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.2.0-dev/scripts/"

def repl(path, pattern, replacement):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    new_content = re.sub(pattern, replacement, content)
    if new_content != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Updated {path}")

repl(base + "core/party_manager.gd", r'for creature_data in', r'for creature_data: Variant in')
repl(base + "data/creature_instance.gd", r'for move_id_value in', r'for move_id_value: Variant in')
repl(base + "ui/backpack_ui.gd", r'for item in items:', r'for item: Variant in items:')
repl(base + "world/route_01.gd", r'for pos in', r'for pos: Vector2 in')
repl(base + "world/route_01.gd", r'signal demo_end_requested\n', r'')
repl(base + "core/bootstrap.gd", r'\s*route\.demo_end_requested\.connect\(_show_demo_ending\)\n', r'\n')
repl(base + "world/sanctuary_town.gd", r'for pos in', r'for pos: Vector2 in')
repl(base + "world/sanctuary_town.gd", r'for l_pos in', r'for l_pos: Vector2 in')
repl(base + "battle/battle_arena.gd", r'func\(\):', r'func() -> void:')

print("Done fixing warnings")
