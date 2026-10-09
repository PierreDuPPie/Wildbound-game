import re

file_path = "c:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.2.0-dev/scripts/battle/battle_arena.gd"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add CVIS_SCENE and change portrait types
content = content.replace(
    "var player_portrait: CreaturePortrait",
    "var player_portrait: CreatureVisual"
)
content = content.replace(
    "var enemy_portrait: CreaturePortrait",
    "var enemy_portrait: CreatureVisual\nconst CVIS_SCENE: PackedScene = preload(\"res://scenes/battle/creature_visual.tscn\")"
)

# 2. Update instantiation
old_inst = """	enemy_portrait = CreaturePortrait.new()
	enemy_portrait.position = Vector2(595, 92)
	enemy_portrait.size = Vector2(250, 170)
	add_child(enemy_portrait)

	player_portrait = CreaturePortrait.new()
	player_portrait.position = Vector2(120, 260)
	player_portrait.size = Vector2(250, 180)
	add_child(player_portrait)"""

new_inst = """	enemy_portrait = CVIS_SCENE.instantiate() as CreatureVisual
	enemy_portrait.position = Vector2(720, 180)
	add_child(enemy_portrait)

	player_portrait = CVIS_SCENE.instantiate() as CreatureVisual
	player_portrait.position = Vector2(240, 350)
	add_child(player_portrait)"""

content = content.replace(old_inst, new_inst)

# 3. Update set_creature -> setup
content = content.replace(
    "player_portrait.set_creature(player_creature.species.species_id, false)",
    "player_portrait.setup(player_creature.species, false)"
)
content = content.replace(
    "enemy_portrait.set_creature(enemy_creature.species.species_id, true)",
    "enemy_portrait.setup(enemy_creature.species, true)"
)

# 4. Remove BattleEffects usage for creatures directly and call CreatureVisual methods instead
# Hit
content = content.replace("effects.play_hit(player_portrait)", "player_portrait.play_hit()")
content = content.replace("effects.play_hit(enemy_portrait)", "enemy_portrait.play_hit()")
# Attack
content = content.replace("effects.play_attack(player_portrait, Vector2(1, 0))", "player_portrait.play_attack()")
content = content.replace("effects.play_attack(enemy_portrait, Vector2(-1, 0))", "enemy_portrait.play_attack()")
# Faint (Wait, did they have play_faint? Let's check)

# Defiance
# old: 
# var portrait := player_portrait if side == &"player" else enemy_portrait
# effects.play_defiance(portrait)
content = re.sub(
    r'effects\.play_defiance\(portrait\)',
    r'portrait.play_instinct(&"defiance")',
    content
)

# Other instinct
# old:
# effects.play_instinct_spectacle(portrait, creature.display_name(), creature.species.instinct.display_name, text)
content = re.sub(
    r'effects\.play_instinct_spectacle\(portrait, creature\.display_name\(\), creature\.species\.instinct\.display_name, text\)',
    r'portrait.play_instinct(creature.species.instinct.instinct_id)',
    content
)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated battle_arena.gd")
