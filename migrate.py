import os, re

moves_dir = 'data/moves'
for fname in os.listdir(moves_dir):
    if not fname.endswith('.tres'): continue
    filepath = os.path.join(moves_dir, fname)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    modified = False
    
    aspect_match = re.search(r'\[ext_resource type="Resource" path="res://data/aspects/([^.]+)\.tres" id="([^"]+)"\]', content)
    if aspect_match:
        aspect_name = aspect_match.group(1)
        aspect_id = aspect_match.group(2)
        content = re.sub(rf'aspect = ExtResource\("{aspect_id}"\)', f'aspect_id = &"{aspect_name}"', content)
        content = re.sub(rf'\[ext_resource type="Resource" path="res://data/aspects/[^.]+\.tres" id="{aspect_id}"\]\n', '', content)
        content = re.sub(r'load_steps=3', 'load_steps=2', content)
        modified = True

    c_replacements = [
        ('category = "attack"', 'category = 0'),
        ('category = "status"', 'category = 2'),
        ('effect_id = &"priority"', 'priority = 1\nstamina_cost = 0\nhook_id = &"damage_basic"'),
        ('effect_id = &"none"', 'priority = 0\nstamina_cost = 0\nhook_id = &"damage_basic"'),
        ('effect_id = &"drop_agility"', 'priority = 0\nstamina_cost = 0\nhook_id = &"drop_agility"'),
        ('effect_id = &"buff_guard"', 'priority = 0\nstamina_cost = 0\nhook_id = &"guard_boost"'),
        ('effect_id = &"heal_self_40"', 'priority = 0\nstamina_cost = 0\nhook_id = &"heal_self_40"'),
        ('effect_id = &"buff_power"', 'priority = 0\nstamina_cost = 0\nhook_id = &"power_boost"')
    ]
    for old, new in c_replacements:
        if old in content:
            content = content.replace(old, new)
            modified = True
            
    if 'animation_key = ' in content:
        content = re.sub(r'animation_key = .*\n?', '', content)
        modified = True

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Migrated {fname}")
